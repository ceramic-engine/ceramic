// Ported from vscode src/vs/editor/contrib/smartSelect/browser/smartSelect.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.smartSelect.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.SelectionRange;
import cityscape.common.Languages.SelectionRangeProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.contrib.smartSelect.view.BracketSelections.BracketSelectionRangeProvider;
import cityscape.contrib.smartSelect.view.WordSelections.WordSelectionRangeProvider;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

/*
 * Expand and shrink selection (smartSelect.ts), registered by
 * `SmartSelectRegistration.register`.
 *
 * Promises: the providers give their ranges to a callback
 * (`SelectionRangeProvider`), `provideSelectionRanges` and
 * `SmartSelectController.run` call back when done (at once with the
 * built-in providers, later with an asynchronous provider).
 *
 * The `smartSelect` editor option is read from the raw options of the
 * editor and validated here like Monaco's `SmartSelect` option
 * (TODO: move it to the options registry of EditorOptions.hx).
 *
 * Not ported: the `_executeSelectionRangeProvider` command (it resolves a
 * model through `ITextModelService`, which Cityscape has no port of).
 */

/**
 * Monaco's `SelectionRangesOptions` (the `smartSelect` option).
 */
typedef SelectionRangesOptions = {
    var selectLeadingAndTrailingWhitespace:Bool;
    var selectSubwords:Bool;
}

class SelectionRanges {

    public final index:Int;
    public final ranges:Array<Range>;

    public function new(index:Int, ranges:Array<Range>) {
        this.index = index;
        this.ranges = ranges;
    }

    public function mov(fwd:Bool):SelectionRanges {
        final index = this.index + (fwd ? 1 : -1);
        if (index < 0 || index >= this.ranges.length) {
            return this;
        }
        final res = new SelectionRanges(index, this.ranges);
        if (res.ranges[index].equalsRange(this.ranges[this.index])) {
            // next range equals this range, retry with next-next
            return res.mov(fwd);
        }
        return res;
    }

}

class SmartSelectController implements IEditorContribution {

    public static inline final ID = 'editor.contrib.smartSelectController';

    public static function get(editor:ICodeEditor):Null<SmartSelectController> {
        return editor.getContribution(SmartSelectController.ID);
    }

    var _state:Null<Array<SelectionRanges>> = null;
    var _selectionListener:Null<IDisposable> = null;
    var _ignoreSelection:Bool = false;

    final _editor:ICodeEditor;
    final _languageFeaturesService:cityscape.common.services.LanguageFeaturesService;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this._languageFeaturesService = editor.context.languageFeaturesService;
    }

    public function dispose():Void {
        if (this._selectionListener != null) {
            this._selectionListener.dispose();
        }
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * The `smartSelect` option of the editor (Monaco's
     * `editor.getOption(EditorOption.smartSelect)`).
     */
    public static function getSmartSelectOptions(editor:ICodeEditor):SelectionRangesOptions {
        final input:Any = JsValues.field(editor.getRawOptions(), 'smartSelect');
        final defaultValue:SelectionRangesOptions = {
            selectLeadingAndTrailingWhitespace: true,
            selectSubwords: true,
        };
        if (!JsValues.truthy(input) || !JsValues.isObject(input)) {
            return defaultValue;
        }
        return {
            selectLeadingAndTrailingWhitespace: boolean(JsValues.field(input, 'selectLeadingAndTrailingWhitespace'), defaultValue.selectLeadingAndTrailingWhitespace),
            selectSubwords: boolean(JsValues.field(input, 'selectSubwords'), defaultValue.selectSubwords),
        };
    }

    /**
     * editorOptions.ts `boolean(value, defaultValue)`.
     */
    static function boolean(value:Any, defaultValue:Bool):Bool {
        if (JsValues.isUndefined(value)) {
            return defaultValue;
        }
        if (JsValues.isString(value) && (value : String) == 'false') {
            // treat the string 'false' as false
            return false;
        }
        return JsValues.truthy(value);
    }

    /**
     * Expands (`forward`) or shrinks the selections. Monaco returns a
     * promise: `done` is called when the selections are set (or nothing
     * happened).
     */
    public function run(forward:Bool, ?done:() -> Void):Void {
        if (!this._editor.hasModel()) {
            if (done != null) done();
            return;
        }

        final selections = this._editor.getSelections();
        final model = this._editor.getModel();

        final finish = () -> {
            if (this._state == null) {
                // no state
                if (done != null) done();
                return;
            }
            this._state = [for (state in this._state) state.mov(forward)];
            final newSelections:Array<cityscape.common.core.Selection.ISelection> = [for (state in this._state) Selection.fromPositions(state.ranges[state.index].getStartPosition(), state.ranges[state.index].getEndPosition())];
            this._ignoreSelection = true;
            try {
                this._editor.setSelections(newSelections);
            }
            catch (e:Dynamic) {
                this._ignoreSelection = false;
                throw e;
            }
            this._ignoreSelection = false;
            if (done != null) done();
        };

        if (this._state == null) {

            SmartSelect.provideSelectionRanges(this._languageFeaturesService.selectionRangeProvider, model, [for (s in selections) s.getPosition()], getSmartSelectOptions(this._editor), CancellationTokens.None, (ranges) -> {
                if (ranges == null || ranges.length == 0 || ranges.length != selections.length) {
                    // invalid result
                    finish();
                    return;
                }
                if (!this._editor.hasModel() || !selectionsEqual(this._editor.getSelections(), selections)) {
                    // invalid editor state
                    finish();
                    return;
                }

                for (i in 0...ranges.length) {
                    ranges[i] = ranges[i].filter(range -> {
                        // filter ranges inside the selection
                        return range.containsPosition(selections[i].getStartPosition()) && range.containsPosition(selections[i].getEndPosition());
                    });
                    // prepend current selection
                    ranges[i].unshift(selections[i]);
                }

                this._state = [for (r in ranges) new SelectionRanges(0, r)];

                // listen to caret move and forget about state
                if (this._selectionListener != null) {
                    this._selectionListener.dispose();
                }
                this._selectionListener = this._editor.onDidChangeCursorPosition((_) -> {
                    if (!this._ignoreSelection) {
                        if (this._selectionListener != null) {
                            this._selectionListener.dispose();
                        }
                        this._state = null;
                    }
                });
                finish();
            });
            return;
        }

        finish();
    }

    static function selectionsEqual(a:Array<Selection>, b:Array<Selection>):Bool {
        if (a == b) {
            return true;
        }
        if (a == null || b == null || a.length != b.length) {
            return false;
        }
        for (i in 0...a.length) {
            if (!a[i].equalsSelection(b[i])) {
                return false;
            }
        }
        return true;
    }

}

abstract class AbstractSmartSelect extends EditorAction {

    final _forward:Bool;

    public function new(forward:Bool, opts:IActionOptions) {
        super(opts);
        this._forward = forward;
    }

    public function run(_accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = SmartSelectController.get(editor);
        if (controller != null) {
            controller.run(this._forward);
        }
    }

}

class GrowSelectionAction extends AbstractSmartSelect {

    public function new(?r:EditorExtensionsRegistry) {
        super(true, {
            id: 'editor.action.smartSelect.expand',
            label: r != null ? r.localize('smartSelect.expand', "Expand Selection") : "Expand Selection",
            alias: 'Expand Selection',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyMod.Alt | KeyCode.RightArrow,
                mac: {
                    primary: KeyMod.CtrlCmd | KeyMod.WinCtrl | KeyMod.Shift | KeyCode.RightArrow,
                    secondary: [KeyMod.WinCtrl | KeyMod.Shift | KeyCode.RightArrow],
                },
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '1_basic',
                title: r != null ? r.localize('miSmartSelectGrow', "&&Expand Selection") : "&&Expand Selection",
                order: 2
            }
        });
    }

}

class ShrinkSelectionAction extends AbstractSmartSelect {

    public function new(?r:EditorExtensionsRegistry) {
        super(false, {
            id: 'editor.action.smartSelect.shrink',
            label: r != null ? r.localize('smartSelect.shrink', "Shrink Selection") : "Shrink Selection",
            alias: 'Shrink Selection',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.editorTextFocus,
                primary: KeyMod.Shift | KeyMod.Alt | KeyCode.LeftArrow,
                mac: {
                    primary: KeyMod.CtrlCmd | KeyMod.WinCtrl | KeyMod.Shift | KeyCode.LeftArrow,
                    secondary: [KeyMod.WinCtrl | KeyMod.Shift | KeyCode.LeftArrow],
                },
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarSelectionMenu',
                group: '1_basic',
                title: r != null ? r.localize('miSmartSelectShrink', "&&Shrink Selection") : "&&Shrink Selection",
                order: 3
            }
        });
    }

}

/**
 * Module functions of smartSelect.ts.
 */
class SmartSelect {

    /**
     * Monaco's `provideSelectionRanges` (a promise): `callback` gets the
     * ranges once every provider resolved.
     */
    public static function provideSelectionRanges(registry:LanguageFeatureRegistry<SelectionRangeProvider>, model:ITextModel, positions:Array<Position>, options:SelectionRangesOptions, token:CancellationToken, callback:(ranges:Array<Array<Range>>) -> Void):Void {

        final providers:Array<SelectionRangeProvider> = registry.all(model)
            .concat([new WordSelectionRangeProvider(options.selectSubwords)]); // ALWAYS have word based selection range

        if (providers.length == 1) {
            // add word selection and bracket selection when no provider exists
            providers.unshift(new BracketSelectionRangeProvider());
        }

        final allRawRanges:Array<Array<Range>> = [];
        var pending = providers.length;
        var finished = false;

        final complete = () -> {
            if (finished) {
                return;
            }
            finished = true;
            callback(SmartSelect._finishRanges(model, allRawRanges, options));
        };

        for (provider in providers) {
            var resolved = false;
            final onResult = (allProviderRanges:Null<Array<Array<SelectionRange>>>) -> {
                if (resolved) {
                    return;
                }
                resolved = true;
                if (allProviderRanges != null && allProviderRanges.length > 0 && allProviderRanges.length == positions.length) {
                    for (i in 0...positions.length) {
                        if (allRawRanges[i] == null) {
                            allRawRanges[i] = [];
                        }
                        for (oneProviderRanges in allProviderRanges[i]) {
                            if (Range.isIRange(oneProviderRanges.range) && Range.containsPositionStatic(oneProviderRanges.range, positions[i])) {
                                allRawRanges[i].push(Range.lift(oneProviderRanges.range));
                            }
                        }
                    }
                }
                pending--;
                if (pending == 0) {
                    complete();
                }
            };
            try {
                provider.provideSelectionRanges(model, positions, token, onResult);
            }
            catch (e:Dynamic) {
                Errors.onUnexpectedExternalError(e);
                if (!resolved) {
                    resolved = true;
                    pending--;
                    if (pending == 0) {
                        complete();
                    }
                }
            }
        }
    }

    static function _finishRanges(model:ITextModel, allRawRanges:Array<Array<Range>>, options:SelectionRangesOptions):Array<Array<Range>> {
        return [for (oneRawRanges in allRawRanges) {

            if (oneRawRanges == null || oneRawRanges.length == 0) {
                [];
            }
            else {

                // sort all by start/end position
                haxe.ds.ArraySort.sort(oneRawRanges, (a, b) -> {
                    if (Position.isBeforeStatic(a.getStartPosition(), b.getStartPosition())) {
                        return 1;
                    }
                    else if (Position.isBeforeStatic(b.getStartPosition(), a.getStartPosition())) {
                        return -1;
                    }
                    else if (Position.isBeforeStatic(a.getEndPosition(), b.getEndPosition())) {
                        return -1;
                    }
                    else if (Position.isBeforeStatic(b.getEndPosition(), a.getEndPosition())) {
                        return 1;
                    }
                    else {
                        return 0;
                    }
                });

                // remove ranges that don't contain the former range or that are equal to the
                // former range
                final oneRanges:Array<Range> = [];
                var last:Null<Range> = null;
                for (range in oneRawRanges) {
                    if (last == null || (Range.containsRangeStatic(range, last) && !Range.equalsRangeStatic(range, last))) {
                        oneRanges.push(range);
                        last = range;
                    }
                }

                if (!options.selectLeadingAndTrailingWhitespace) {
                    oneRanges;
                }
                else {

                    // add ranges that expand trivia at line starts and ends whenever a range
                    // wraps onto the a new line
                    final oneRangesWithTrivia:Array<Range> = [oneRanges[0]];
                    for (i in 1...oneRanges.length) {
                        final prev = oneRanges[i - 1];
                        final cur = oneRanges[i];
                        if (cur.startLineNumber != prev.startLineNumber || cur.endLineNumber != prev.endLineNumber) {
                            // add line/block range without leading/failing whitespace
                            final rangeNoWhitespace = new Range(prev.startLineNumber, model.getLineFirstNonWhitespaceColumn(prev.startLineNumber), prev.endLineNumber, model.getLineLastNonWhitespaceColumn(prev.endLineNumber));
                            if (rangeNoWhitespace.containsRange(prev) && !rangeNoWhitespace.equalsRange(prev) && cur.containsRange(rangeNoWhitespace) && !cur.equalsRange(rangeNoWhitespace)) {
                                oneRangesWithTrivia.push(rangeNoWhitespace);
                            }
                            // add line/block range
                            final rangeFull = new Range(prev.startLineNumber, 1, prev.endLineNumber, model.getLineMaxColumn(prev.endLineNumber));
                            if (rangeFull.containsRange(prev) && !rangeFull.equalsRange(rangeNoWhitespace) && cur.containsRange(rangeFull) && !cur.equalsRange(rangeFull)) {
                                oneRangesWithTrivia.push(rangeFull);
                            }
                        }
                        oneRangesWithTrivia.push(cur);
                    }
                    oneRangesWithTrivia;
                }
            }
        }];
    }

}

class SmartSelectRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(SmartSelectController.ID, editor -> new SmartSelectController(editor), EditorContributionInstantiation.Lazy);
        r.registerEditorAction(new GrowSelectionAction(r));
        // renamed command id
        r.context.commandsRegistry.registerCommandAlias('editor.action.smartSelect.grow', 'editor.action.smartSelect.expand');
        r.registerEditorAction(new ShrinkSelectionAction(r));
    }

}
