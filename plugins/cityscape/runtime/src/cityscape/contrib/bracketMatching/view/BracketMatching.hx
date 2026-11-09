// Ported from vscode src/vs/editor/contrib/bracketMatching/browser/bracketMatching.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.bracketMatching.view;

import cityscape.Cityscape;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Lifecycle.Disposable;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorContextKeys;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.ThemeService;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

class JumpToBracketAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.jumpToBracket',
            label: r.localize('smartSelect.jumpBracket', "Go to Bracket"),
            alias: 'Go to Bracket',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.Backslash,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = BracketMatchingController.get(editor);
        if (controller != null) {
            controller.jumpToBracket();
        }
    }

}

class SelectToBracketAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.selectToBracket',
            label: r.localize('smartSelect.selectToBracket', "Select to Bracket"),
            alias: 'Select to Bracket',
            precondition: null,
            metadata: {
                description: r.localize('smartSelect.selectToBracketDescription', "Select the text inside and including the brackets or curly braces"),
                args: [{
                    name: 'args'
                }]
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        var selectBrackets = true;
        if (JsValues.truthy(args) && JsValues.strictEquals(JsValues.field(args, 'selectBrackets'), false)) {
            selectBrackets = false;
        }
        final controller = BracketMatchingController.get(editor);
        if (controller != null) {
            controller.selectToBracket(selectBrackets);
        }
    }

}

class RemoveBracketsAction extends EditorAction {

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: 'editor.action.removeBrackets',
            label: r.localize('smartSelect.removeBrackets', "Remove Brackets"),
            alias: 'Remove Brackets',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.CtrlCmd | KeyMod.Alt | KeyCode.Backspace,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = BracketMatchingController.get(editor);
        if (controller != null) {
            controller.removeBrackets(this.id);
        }
    }

}

/**
 * Monaco's `type Brackets = [Range, Range]` is an array of two ranges.
 */
class BracketsData {

    public final position:Position;
    public final brackets:Null<Array<Range>>;
    public final options:ModelDecorationOptions;

    public function new(position:Position, brackets:Null<Array<Range>>, options:ModelDecorationOptions) {
        this.position = position;
        this.brackets = brackets;
        this.options = options;
    }

}

class BracketMatchingController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.bracketMatchingController';

    public static function get(editor:ICodeEditor):Null<BracketMatchingController> {
        return editor.getContribution(ID);
    }

    final _editor:ICodeEditor;

    var _lastBracketsData:Array<BracketsData>;
    var _lastVersionId:Int;
    final _decorations:IEditorDecorationsCollection;
    final _updateBracketsSoon:RunOnceScheduler;
    var _matchBrackets:String;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._lastBracketsData = [];
        this._lastVersionId = 0;
        this._decorations = this._editor.createDecorationsCollection();
        this._updateBracketsSoon = this._register(new RunOnceScheduler(() -> this._updateBrackets(), 50));
        this._matchBrackets = this._editor.getOption(EditorOption.matchBrackets);

        this._updateBracketsSoon.schedule();
        this._register(editor.onDidChangeCursorPosition((e) -> {

            if (this._matchBrackets == 'never') {
                // Early exit if nothing needs to be done!
                // Leave some form of early exit check here if you wish to continue being a cursor position change listener ;)
                return;
            }

            this._updateBracketsSoon.schedule();
        }));
        this._register(editor.onDidChangeModelContent((e) -> {
            this._updateBracketsSoon.schedule();
        }));
        this._register(editor.onDidChangeModel((e) -> {
            this._lastBracketsData = [];
            this._updateBracketsSoon.schedule();
        }));
        this._register(editor.onDidChangeModelLanguageConfiguration((e) -> {
            this._lastBracketsData = [];
            this._updateBracketsSoon.schedule();
        }));
        this._register(editor.onDidChangeConfiguration((e) -> {
            if (e.hasChanged(EditorOption.matchBrackets)) {
                this._matchBrackets = this._editor.getOption(EditorOption.matchBrackets);
                this._decorations.clear();
                this._lastBracketsData = [];
                this._lastVersionId = 0;
                this._updateBracketsSoon.schedule();
            }
        }));

        this._register(editor.onDidBlurEditorWidget(() -> {
            this._updateBracketsSoon.schedule();
        }));

        this._register(editor.onDidFocusEditorWidget(() -> {
            this._updateBracketsSoon.schedule();
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * Runs the pending update of the decorations now (tests; Monaco waits
     * 50 ms).
     */
    public function _flushPendingUpdate():Void {
        this._updateBracketsSoon.flush();
    }

    public function jumpToBracket():Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final model = this._editor.getModel();
        final newSelections:Array<Selection> = this._editor.getSelections().map(selection -> {
            final position = selection.getStartPosition();

            // find matching brackets if position is on a bracket
            final brackets = model.bracketPairs.matchBracket(position);
            var newCursorPosition:Null<Position> = null;
            if (brackets != null) {
                if (brackets[0].containsPosition(position) && !brackets[1].containsPosition(position)) {
                    newCursorPosition = brackets[1].getStartPosition();
                }
                else if (brackets[1].containsPosition(position)) {
                    newCursorPosition = brackets[0].getStartPosition();
                }
            }
            else {
                // find the enclosing brackets if the position isn't on a matching bracket
                final enclosingBrackets = model.bracketPairs.findEnclosingBrackets(position);
                if (enclosingBrackets != null) {
                    newCursorPosition = enclosingBrackets[1].getStartPosition();
                }
                else {
                    // no enclosing brackets, try the very first next bracket
                    final nextBracket = model.bracketPairs.findNextBracket(position);
                    if (nextBracket != null && nextBracket.range != null) {
                        newCursorPosition = nextBracket.range.getStartPosition();
                    }
                }
            }

            if (newCursorPosition != null) {
                return new Selection(newCursorPosition.lineNumber, newCursorPosition.column, newCursorPosition.lineNumber, newCursorPosition.column);
            }
            return new Selection(position.lineNumber, position.column, position.lineNumber, position.column);
        });

        this._editor.setSelections(cast newSelections);
        this._editor.revealRange(newSelections[0]);
    }

    public function selectToBracket(selectBrackets:Bool):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final model = this._editor.getModel();
        final newSelections:Array<Selection> = [];

        for (selection in this._editor.getSelections()) {
            final position = selection.getStartPosition();
            var brackets = model.bracketPairs.matchBracket(position);

            if (brackets == null) {
                brackets = model.bracketPairs.findEnclosingBrackets(position);
                if (brackets == null) {
                    final nextBracket = model.bracketPairs.findNextBracket(position);
                    if (nextBracket != null && nextBracket.range != null) {
                        brackets = model.bracketPairs.matchBracket(nextBracket.range.getStartPosition());
                    }
                }
            }

            var selectFrom:Null<Position> = null;
            var selectTo:Null<Position> = null;

            if (brackets != null) {
                haxe.ds.ArraySort.sort(brackets, Range.compareRangesUsingStarts);
                final open = brackets[0];
                final close = brackets[1];
                selectFrom = selectBrackets ? open.getStartPosition() : open.getEndPosition();
                selectTo = selectBrackets ? close.getEndPosition() : close.getStartPosition();

                if (close.containsPosition(position)) {
                    // select backwards if the cursor was on the closing bracket
                    final tmp = selectFrom;
                    selectFrom = selectTo;
                    selectTo = tmp;
                }
            }

            if (selectFrom != null && selectTo != null) {
                newSelections.push(new Selection(selectFrom.lineNumber, selectFrom.column, selectTo.lineNumber, selectTo.column));
            }
        }

        if (newSelections.length > 0) {
            this._editor.setSelections(cast newSelections);
            this._editor.revealRange(newSelections[0]);
        }
    }

    public function removeBrackets(?editSource:String):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final model = this._editor.getModel();
        for (selection in this._editor.getSelections()) {
            final position = selection.getPosition();

            var brackets = model.bracketPairs.matchBracket(position);
            if (brackets == null) {
                brackets = model.bracketPairs.findEnclosingBrackets(position);
            }
            if (brackets != null) {
                this._editor.pushUndoStop();
                this._editor.executeEdits(
                    editSource,
                    [
                        {range: brackets[0], text: ''},
                        {range: brackets[1], text: ''}
                    ]
                );
                this._editor.pushUndoStop();
            }
        }
    }

    static var _withOverviewRuler:Null<ModelDecorationOptions> = null;
    static function _DECORATION_OPTIONS_WITH_OVERVIEW_RULER():ModelDecorationOptions {
        var _DECORATION_OPTIONS_WITH_OVERVIEW_RULER = _withOverviewRuler;
        if (_DECORATION_OPTIONS_WITH_OVERVIEW_RULER == null) {
            _DECORATION_OPTIONS_WITH_OVERVIEW_RULER = ModelDecorationOptions.register({
                description: 'bracket-match-overview',
                stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                className: 'bracket-match',
                overviewRuler: {
                    color: ThemeService.themeColorFromId(BracketMatchingRegistration.overviewRulerBracketMatchForeground),
                    position: OverviewRulerLane.Center
                }
            });
            _withOverviewRuler = _DECORATION_OPTIONS_WITH_OVERVIEW_RULER;
        }
        return _DECORATION_OPTIONS_WITH_OVERVIEW_RULER;
    }

    static var _withoutOverviewRuler:Null<ModelDecorationOptions> = null;
    static function _DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER():ModelDecorationOptions {
        var _DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER = _withoutOverviewRuler;
        if (_DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER == null) {
            _DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER = ModelDecorationOptions.register({
                description: 'bracket-match-no-overview',
                stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                className: 'bracket-match'
            });
            _withoutOverviewRuler = _DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER;
        }
        return _DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER;
    }

    function _updateBrackets():Void {
        if (this._matchBrackets == 'never') {
            return;
        }
        this._recomputeBrackets();

        final newDecorations:Array<IModelDeltaDecoration> = [];
        for (bracketData in this._lastBracketsData) {
            final brackets = bracketData.brackets;
            if (brackets != null) {
                newDecorations.push({range: brackets[0], options: cast bracketData.options});
                newDecorations.push({range: brackets[1], options: cast bracketData.options});
            }
        }

        this._decorations.set(newDecorations);
    }

    function _recomputeBrackets():Void {
        if (!this._editor.hasModel() || !this._editor.hasWidgetFocus()) {
            // no model or no focus => no brackets!
            this._lastBracketsData = [];
            this._lastVersionId = 0;
            return;
        }

        final selections = this._editor.getSelections();
        if (selections.length > 100) {
            // no bracket matching for high numbers of selections
            this._lastBracketsData = [];
            this._lastVersionId = 0;
            return;
        }

        final model = this._editor.getModel();
        final versionId = model.getVersionId();
        var previousData:Array<BracketsData> = [];
        if (this._lastVersionId == versionId) {
            // use the previous data only if the model is at the same version id
            previousData = this._lastBracketsData;
        }

        final positions:Array<Position> = [];
        for (selection in selections) {
            if (selection.isEmpty()) {
                // will bracket match a cursor only if the selection is collapsed
                positions.push(selection.getStartPosition());
            }
        }

        // sort positions for `previousData` cache hits
        if (positions.length > 1) {
            haxe.ds.ArraySort.sort(positions, Position.compare);
        }

        final newData:Array<BracketsData> = [];
        var previousIndex = 0;
        final previousLen = previousData.length;
        for (position in positions) {

            while (previousIndex < previousLen && previousData[previousIndex].position.isBefore(position)) {
                previousIndex++;
            }

            if (previousIndex < previousLen && previousData[previousIndex].position.equals(position)) {
                newData.push(previousData[previousIndex]);
            }
            else {
                var brackets = model.bracketPairs.matchBracket(position, 20 /* give at most 20ms to compute */);
                var options = _DECORATION_OPTIONS_WITH_OVERVIEW_RULER();
                if (brackets == null && this._matchBrackets == 'always') {
                    brackets = model.bracketPairs.findEnclosingBrackets(position, 20 /* give at most 20ms to compute */);
                    options = _DECORATION_OPTIONS_WITHOUT_OVERVIEW_RULER();
                }
                newData.push(new BracketsData(position, brackets, options));
            }
        }

        this._lastBracketsData = newData;
        this._lastVersionId = versionId;
    }

}

/**
 * The module level code of bracketMatching.ts: the contribution, its
 * actions, its color and the look of `bracket-match` (bracketMatching.css).
 */
class BracketMatchingRegistration {

    public static inline final overviewRulerBracketMatchForeground = 'editorOverviewRuler.bracketMatchForeground';

    public static function register(r:EditorExtensionsRegistry):Void {
        ColorUtils.registerColor(overviewRulerBracketMatchForeground, '#A0A0A0', r.localize('overviewRulerBracketMatchForeground', 'Overview ruler marker color for matching brackets.'));

        // .monaco-editor .bracket-match { background-color: var(--vscode-editorBracketMatch-background); border: 1px solid var(--vscode-editorBracketMatch-border); }
        if (r.context.decorationStyles.get('bracket-match') == null) {
            r.context.registerDecorationStyle('bracket-match', {
                background: {id: 'editorBracketMatch.background'},
                border: {color: {id: 'editorBracketMatch.border'}, width: 1}
            });
        }

        r.registerEditorContribution(BracketMatchingController.ID, editor -> new BracketMatchingController(editor), EditorContributionInstantiation.AfterFirstRender);
        r.registerEditorAction(new SelectToBracketAction(r));
        r.registerEditorAction(new JumpToBracketAction(r));
        r.registerEditorAction(new RemoveBracketsAction(r));

        // Go to menu
        r.appendMenuItem('MenubarGoMenu', {
            group: '5_infile_nav',
            command: {
                id: 'editor.action.jumpToBracket',
                title: r.localize('miGoToBracket', "Go to &&Bracket")
            },
            order: 2
        });
    }

}
