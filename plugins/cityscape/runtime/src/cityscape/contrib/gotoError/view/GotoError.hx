// Ported from vscode src/vs/editor/contrib/gotoError/browser/gotoError.ts and
// markerNavigationService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoError.view;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.EditorContextKeys;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.platform.markers.common.MarkerService;
import cityscape.platform.markers.common.Markers;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.EditorExtensions;

class MarkerCoordinate {
    public final marker:IMarker;
    public final index:Int;
    public final total:Int;

    public function new(marker:IMarker, index:Int, total:Int) {
        this.marker = marker;
        this.index = index;
        this.total = total;
    }
}

/**
 * The markers navigated by F8, sorted by resource, severity and position
 * (Monaco's `MarkerList`, with VS Code's default `problems.sortOrder`
 * `severity`).
 */
class MarkerList implements IDisposable {

    final _onDidChange = new VoidEmitter();
    public final onDidChange:VoidEvent;

    final _resourceFilter:Null<(uri:Uri) -> Bool>;
    final _dispoables = new DisposableStore();

    var _markers:Array<IMarker> = [];
    var _nextIdx:Int = -1;

    static function markerRange(m:IMarker):Range {
        return new Range(m.startLineNumber, m.startColumn, m.endLineNumber, m.endColumn);
    }

    static function compareStrings(a:String, b:String):Int {
        return a < b ? -1 : (a > b ? 1 : 0);
    }

    public function new(resourceFilter:Null<Uri>, markerService:IMarkerService) {
        this.onDidChange = _onDidChange.event;
        if (resourceFilter != null) {
            final key = resourceFilter.toString();
            this._resourceFilter = uri -> uri.toString() == key;
        }
        else {
            this._resourceFilter = null;
        }

        final compareMarker = (a:IMarker, b:IMarker) -> {
            var res = compareStrings(a.resource.toString(), b.resource.toString());
            if (res == 0) {
                res = MarkerSeverityUtils.compare(a.severity, b.severity);
                if (res == 0) {
                    res = Range.compareRangesUsingStarts(markerRange(a), markerRange(b));
                }
            }
            return res;
        };

        final updateMarker = () -> {
            final read = resourceFilter != null
                ? markerService.read({resource: resourceFilter, severities: (MarkerSeverity.Error : Int) | (MarkerSeverity.Warning : Int) | (MarkerSeverity.Info : Int)})
                : markerService.read({severities: (MarkerSeverity.Error : Int) | (MarkerSeverity.Warning : Int) | (MarkerSeverity.Info : Int)});
            haxe.ds.ArraySort.sort(read, compareMarker);
            this._markers = read;
        };
        updateMarker();

        this._dispoables.add(markerService.onMarkerChanged(uris -> {
            var matches = this._resourceFilter == null;
            if (!matches) {
                for (uri in uris) {
                    if (this._resourceFilter(uri)) {
                        matches = true;
                        break;
                    }
                }
            }
            if (matches) {
                updateMarker();
                this._nextIdx = -1;
                this._onDidChange.fire();
            }
        }));
    }

    public function dispose():Void {
        this._dispoables.dispose();
        this._onDidChange.dispose();
    }

    public function matches(uri:Null<Uri>):Bool {
        if (this._resourceFilter == null && uri == null) {
            return true;
        }
        if (this._resourceFilter == null || uri == null) {
            return false;
        }
        return this._resourceFilter(uri);
    }

    public var selected(get, never):Null<MarkerCoordinate>;
    function get_selected():Null<MarkerCoordinate> {
        if (this._nextIdx < 0 || this._nextIdx >= this._markers.length) {
            return null;
        }
        return new MarkerCoordinate(this._markers[this._nextIdx], this._nextIdx + 1, this._markers.length);
    }

    function _initIdx(model:ITextModel, position:Position, fwd:Bool):Void {
        var found = false;
        final uri = model.uri.toString();
        var idx = -1;
        for (i in 0...this._markers.length) {
            if (this._markers[i].resource.toString() == uri) {
                idx = i;
                break;
            }
        }
        if (idx < 0) {
            // binarySearch by resource: the insertion point
            idx = 0;
            while (idx < this._markers.length && compareStrings(this._markers[idx].resource.toString(), uri) < 0) {
                idx++;
            }
        }

        for (i in idx...this._markers.length) {
            var range = markerRange(this._markers[i]);

            if (range.isEmpty()) {
                final word = model.getWordAtPosition(range.getStartPosition());
                if (word != null) {
                    range = new Range(range.startLineNumber, word.startColumn, range.startLineNumber, word.endColumn);
                }
            }

            if (position != null && (range.containsPosition(position) || position.isBeforeOrEqual(range.getStartPosition()))) {
                this._nextIdx = i;
                found = true;
                break;
            }

            if (this._markers[i].resource.toString() != uri) {
                break;
            }
        }

        if (!found) {
            // after the last change
            this._nextIdx = fwd ? 0 : this._markers.length - 1;
        }
        if (this._nextIdx < 0) {
            this._nextIdx = this._markers.length - 1;
        }
    }

    public function resetIndex():Void {
        this._nextIdx = -1;
    }

    public function move(fwd:Bool, model:ITextModel, position:Position):Bool {
        if (this._markers.length == 0) {
            return false;
        }

        final oldIdx = this._nextIdx;
        if (this._nextIdx == -1) {
            this._initIdx(model, position, fwd);
        }
        else if (fwd) {
            this._nextIdx = (this._nextIdx + 1) % this._markers.length;
        }
        else {
            this._nextIdx = (this._nextIdx - 1 + this._markers.length) % this._markers.length;
        }

        return oldIdx != this._nextIdx;
    }

    public function find(uri:Uri, position:Position):Null<MarkerCoordinate> {
        final key = uri.toString();
        var idx = -1;
        for (i in 0...this._markers.length) {
            if (this._markers[i].resource.toString() == key) {
                idx = i;
                break;
            }
        }
        if (idx < 0) {
            return null;
        }
        while (idx < this._markers.length) {
            if (markerRange(this._markers[idx]).containsPosition(position)) {
                return new MarkerCoordinate(this._markers[idx], idx + 1, this._markers.length);
            }
            idx++;
        }
        return null;
    }
}

/**
 * Navigates between the markers (Monaco's `MarkerController`). Monaco shows
 * the marker in a peek zone widget below its line; Cityscape moves the
 * cursor to the marker like Monaco and shows the marker in the content
 * hover (message, severity, source and code, quick fixes, and the position
 * of the marker among the problems).
 */
class MarkerController implements IEditorContribution {

    public static inline final ID = 'editor.contrib.markerController';

    public static final CONTEXT_MARKERS_NAVIGATION_VISIBLE = new RawContextKey<Bool>('markersNavigationVisible', false);

    public static function get(editor:ICodeEditor):Null<MarkerController> {
        return editor.getContribution(MarkerController.ID);
    }

    final _editor:ICodeEditor;
    final _widgetVisible:IContextKey<Bool>;
    final _sessionDispoables = new DisposableStore();
    var _model:Null<MarkerList> = null;
    var _shown:Null<MarkerCoordinate> = null;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this._widgetVisible = CONTEXT_MARKERS_NAVIGATION_VISIBLE.bindTo(editor.contextKeyService);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this._cleanUp();
        this._sessionDispoables.dispose();
    }

    function _cleanUp():Void {
        this._widgetVisible.reset();
        this._sessionDispoables.clear();
        this._model = null;
        this._shown = null;
    }

    /**
     * The marker shown by the last navigation with its index among the
     * problems (null when none shows).
     */
    public function getShownMarker():Null<MarkerCoordinate> {
        return _shown;
    }

    function _getOrCreateModel(uri:Null<Uri>):MarkerList {

        if (this._model != null && this._model.matches(uri)) {
            return this._model;
        }
        var reusePosition = false;
        if (this._model != null) {
            reusePosition = true;
            this._cleanUp();
        }

        final model = new MarkerList(uri, this._editor.context.markerService);
        this._model = model;
        if (reusePosition) {
            model.move(true, this._editor.getModel(), this._editor.getPosition());
        }

        this._sessionDispoables.add(model);

        // follow cursor
        this._sessionDispoables.add(this._editor.onDidChangeCursorPosition(e -> {
            final selected = this._model != null ? this._model.selected : null;
            if (selected == null || !new Range(selected.marker.startLineNumber, selected.marker.startColumn, selected.marker.endLineNumber, selected.marker.endColumn).containsPosition(e.position)) {
                if (this._model != null) {
                    this._model.resetIndex();
                }
                // the cursor left the marker: the marker no longer shows
                this._shown = null;
                this._widgetVisible.reset();
            }
        }));

        this._sessionDispoables.add(this._editor.onDidChangeModel(_ -> this._cleanUp()));

        return model;
    }

    public function close(focusEditor:Bool = true):Void {
        this._cleanUp();
        final hover = ContentHoverController.get(this._editor);
        if (hover != null) {
            hover.hideContentHover();
        }
        if (focusEditor) {
            this._editor.focus();
        }
    }

    public function showAtMarker(marker:IMarker):Void {
        if (this._editor.hasModel()) {
            final model = this._getOrCreateModel(this._editor.getModel().uri);
            model.resetIndex();
            model.move(true, this._editor.getModel(), new Position(marker.startLineNumber, marker.startColumn));
            final selected = model.selected;
            if (selected != null) {
                this._show(selected);
            }
        }
    }

    /**
     * Monaco's `MarkerNavigationWidget.showAtMarker`: the cursor goes to the
     * marker (unless it is inside it already), the line is revealed near
     * the top, and the marker shows in the hover.
     */
    function _show(selected:MarkerCoordinate):Void {
        _shown = selected;
        final marker = selected.marker;
        final range = new Range(marker.startLineNumber, marker.startColumn, marker.endLineNumber, marker.endColumn);
        final editorPosition = this._editor.getPosition();
        final position = editorPosition != null && range.containsPosition(editorPosition) ? editorPosition : range.getStartPosition();
        this._editor.setSelection(new Range(position.lineNumber, position.column, position.lineNumber, position.column));
        this._editor.revealPositionNearTop(position, ScrollType.Smooth);
        this._editor.focus();
        // the navigation moved the cursor: keep the index
        _shown = selected;
        this._widgetVisible.set(true);
        final hover = ContentHoverController.get(this._editor);
        if (hover != null) {
            hover.showContentHover(new Range(position.lineNumber, position.column, position.lineNumber, position.column), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
        }
    }

    /**
     * Goes to the next or previous marker (Monaco's `nagivate`): with
     * `multiFile`, a marker of another resource is opened through the
     * context's `codeEditorService.openCodeEditor` (the host's open handler).
     */
    public function nagivate(next:Bool, multiFile:Bool):Void {
        if (this._editor.hasModel()) {
            final model = this._getOrCreateModel(multiFile ? null : this._editor.getModel().uri);
            model.move(next, this._editor.getModel(), this._editor.getPosition());
            final selected = model.selected;
            if (selected == null) {
                return;
            }
            if (selected.marker.resource.toString() != this._editor.getModel().uri.toString()) {
                // show in different editor
                this._cleanUp();
                final marker = selected.marker;
                this._editor.context.codeEditorService.openCodeEditor({
                    resource: marker.resource,
                    options: {pinned: false, revealIfOpened: true, selection: new Range(marker.startLineNumber, marker.startColumn, marker.endLineNumber, marker.endColumn)}
                }, this._editor, false, otherEditor -> {
                    if (otherEditor != null) {
                        final controller = MarkerController.get(otherEditor);
                        if (controller != null) {
                            controller.close();
                            controller.nagivate(next, multiFile);
                        }
                    }
                });
            }
            else {
                // show in this editor
                this._show(selected);
            }
        }
    }

}

class MarkerNavigationAction extends EditorAction {

    final _next:Bool;
    final _multiFile:Bool;

    public function new(next:Bool, multiFile:Bool, opts:IActionOptions) {
        super(opts);
        this._next = next;
        this._multiFile = multiFile;
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        if (editor.hasModel()) {
            final controller = MarkerController.get(editor);
            if (controller != null) {
                controller.nagivate(this._next, this._multiFile);
            }
        }
    }
}

class NextMarkerAction extends MarkerNavigationAction {
    public static inline final ID = 'editor.action.marker.next';

    public function new(r:EditorExtensionsRegistry) {
        final label = r.localize('markerAction.next.label', "Go to Next Problem (Error, Warning, Info)");
        super(true, false, {
            id: NextMarkerAction.ID,
            label: label,
            alias: 'Go to Next Problem (Error, Warning, Info)',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.Alt | KeyCode.F8,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }
}

class PrevMarkerAction extends MarkerNavigationAction {
    public static inline final ID = 'editor.action.marker.prev';

    public function new(r:EditorExtensionsRegistry) {
        final label = r.localize('markerAction.previous.label', "Go to Previous Problem (Error, Warning, Info)");
        super(false, false, {
            id: PrevMarkerAction.ID,
            label: label,
            alias: 'Go to Previous Problem (Error, Warning, Info)',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.Shift | KeyMod.Alt | KeyCode.F8,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }
}

class NextMarkerInFilesAction extends MarkerNavigationAction {
    public function new(r:EditorExtensionsRegistry) {
        super(true, true, {
            id: 'editor.action.marker.nextInFiles',
            label: r.localize('markerAction.nextInFiles.label', "Go to Next Problem in Files (Error, Warning, Info)"),
            alias: 'Go to Next Problem in Files (Error, Warning, Info)',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.F8,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarGoMenu',
                title: r.localize('miGotoNextProblem', "Next &&Problem"),
                group: '6_problem_nav',
                order: 1
            }
        });
    }
}

class PrevMarkerInFilesAction extends MarkerNavigationAction {
    public function new(r:EditorExtensionsRegistry) {
        super(false, true, {
            id: 'editor.action.marker.prevInFiles',
            label: r.localize('markerAction.previousInFiles.label', "Go to Previous Problem in Files (Error, Warning, Info)"),
            alias: 'Go to Previous Problem in Files (Error, Warning, Info)',
            precondition: null,
            kbOpts: {
                kbExpr: EditorContextKeys.focus,
                primary: KeyMod.Shift | KeyCode.F8,
                weight: KeybindingWeight.EditorContrib
            },
            menuOpts: {
                menuId: 'MenubarGoMenu',
                title: r.localize('miGotoPreviousProblem', "Previous &&Problem"),
                group: '6_problem_nav',
                order: 2
            }
        });
    }
}

/**
 * The registration of gotoError.ts (its module level code).
 */
class GotoErrorRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(MarkerController.ID, editor -> new MarkerController(editor), EditorContributionInstantiation.Lazy);
        r.registerEditorAction(new NextMarkerAction(r));
        r.registerEditorAction(new PrevMarkerAction(r));
        r.registerEditorAction(new NextMarkerInFilesAction(r));
        r.registerEditorAction(new PrevMarkerInFilesAction(r));

        r.registerEditorCommand(new ContributionCommand<MarkerController>(MarkerController.get, {
            id: 'closeMarkersNavigation',
            precondition: MarkerController.CONTEXT_MARKERS_NAVIGATION_VISIBLE,
            handler: (x, _) -> x.close(),
            kbOpts: {
                weight: KeybindingWeight.EditorContrib + 50,
                kbExpr: EditorContextKeys.focus,
                primary: KeyCode.Escape,
                secondary: [KeyMod.Shift | KeyCode.Escape]
            }
        }));
    }

}
