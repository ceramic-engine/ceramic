// Ported from vscode src/vs/editor/contrib/gotoSymbol/browser/peek/referencesWidget.ts
// and peek/referencesTree.ts (the rows of the tree)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.gotoSymbol.view.peek;

import cityscape.CityscapeEditor;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Languages.Location;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.model.TextModel;
import cityscape.common.model.TextModel.ModelDecorationOptions;
import cityscape.contrib.gotoSymbol.view.GoToCommands.SymbolNavigation;
import cityscape.contrib.gotoSymbol.view.ReferencesModel;
import cityscape.contrib.peekView.view.PeekView;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model as GlazeModel;
import glaze.MouseButton;
import glaze.Point;
import glaze.Render;
import glaze.Size;
import glaze.Window;
import glaze.kit.IconName;
import glaze.kit.scroll.Scrollable.ScrollableElement;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * The `reference-decoration`s of the references in the preview editor,
 * kept in sync with edits (Monaco's `DecorationsManager`).
 */
class DecorationsManager implements IDisposable {

    static var _decorationOptions:Null<ModelDecorationOptions> = null;

    static function decorationOptions():ModelDecorationOptions {
        if (_decorationOptions == null) {
            _decorationOptions = ModelDecorationOptions.register({
                description: 'reference-decoration',
                stickiness: TrackedRangeStickiness.NeverGrowsWhenTypingAtEdges,
                className: 'reference-decoration'
            });
        }
        return _decorationOptions;
    }

    final _decorations:Map<String, OneReference> = new Map();
    final _decorationIgnoreSet:Map<String, Bool> = new Map();
    final _callOnDispose = new DisposableStore();
    final _callOnModelChange = new DisposableStore();

    final _editor:ICodeEditor;
    final _model:ReferencesModel;

    public function new(editor:ICodeEditor, model:ReferencesModel) {
        this._editor = editor;
        this._model = model;
        this._callOnDispose.add(this._editor.onDidChangeModel(_ -> this._onModelChanged()));
        this._onModelChanged();
    }

    public function dispose():Void {
        this._callOnModelChange.dispose();
        this._callOnDispose.dispose();
        this.removeDecorations();
    }

    function _onModelChanged():Void {
        this._callOnModelChange.clear();
        final model = this._editor.getModel();
        if (model == null) {
            return;
        }
        for (ref in this._model.references) {
            if (ref.uri.toString() == model.uri.toString()) {
                this._addDecorations(ref.parent);
                return;
            }
        }
    }

    function _addDecorations(reference:FileReferences):Void {
        if (!this._editor.hasModel()) {
            return;
        }
        this._callOnModelChange.add(this._editor.getModel().onDidChangeDecorations(_ -> this._onDecorationChanged()));

        final newDecorations:Array<IModelDeltaDecoration> = [];
        final newDecorationsActualIndex:Array<Int> = [];

        for (i in 0...reference.children.length) {
            final oneReference = reference.children[i];
            if (this._decorationIgnoreSet.exists(oneReference.id)) {
                continue;
            }
            if (oneReference.uri.toString() != this._editor.getModel().uri.toString()) {
                continue;
            }
            newDecorations.push({
                range: oneReference.range,
                options: cast decorationOptions()
            });
            newDecorationsActualIndex.push(i);
        }

        this._editor.changeDecorations(changeAccessor -> {
            final decorations = changeAccessor.deltaDecorations([], newDecorations);
            for (i in 0...decorations.length) {
                this._decorations.set(decorations[i], reference.children[newDecorationsActualIndex[i]]);
            }
            return null;
        });
    }

    function _onDecorationChanged():Void {
        final toRemove:Array<String> = [];

        final model = this._editor.getModel();
        if (model == null) {
            return;
        }

        for (decorationId => reference in this._decorations) {

            final newRange = model.getDecorationRange(decorationId);

            if (newRange == null) {
                continue;
            }

            var ignore = false;
            if (Range.equalsRangeStatic(newRange, reference.range)) {
                continue;
            }

            if (Range.spansMultipleLines(newRange)) {
                ignore = true;
            }
            else {
                final lineLength = reference.range.endColumn - reference.range.startColumn;
                final newLineLength = newRange.endColumn - newRange.startColumn;

                if (lineLength != newLineLength) {
                    ignore = true;
                }
            }

            if (ignore) {
                this._decorationIgnoreSet.set(reference.id, true);
                toRemove.push(decorationId);
            }
            else {
                reference.range = newRange;
            }
        }

        for (id in toRemove) {
            this._decorations.remove(id);
        }
        this._editor.removeDecorations(toRemove);
    }

    public function removeDecorations():Void {
        this._editor.removeDecorations([for (k in this._decorations.keys()) k]);
        this._decorations.clear();
    }

}

/**
 * The split ratio and the height of the peek view, kept in the storage
 * (`peekViewLayout`).
 */
class LayoutData {

    public var ratio:Float = 0.7;
    public var heightInLines:Int = 18;

    public function new() {}

    public static function fromJSON(raw:String):LayoutData {
        final result = new LayoutData();
        try {
            final data:Any = haxe.Json.parse(raw);
            final ratio:Any = cityscape.base.common.JsValues.field(data, 'ratio');
            final heightInLines:Any = cityscape.base.common.JsValues.field(data, 'heightInLines');
            if (cityscape.base.common.JsValues.isNumber(ratio) && (ratio : Float) != 0) {
                result.ratio = ratio;
            }
            if (cityscape.base.common.JsValues.isNumber(heightInLines) && (heightInLines : Float) != 0) {
                result.heightInLines = Std.int((heightInLines : Float));
            }
        }
        catch (e:Any) {}
        return result;
    }

    public function toJSON():String {
        return haxe.Json.stringify({ratio: ratio, heightInLines: heightInLines});
    }

}

/**
 * `'goto'`, `'show'`, `'side'` or `'open'`, from `'editor'`, `'tree'` or
 * `'title'` (Monaco's `SelectionEvent`).
 */
typedef SelectionEvent = {
    final kind:String;
    final source:String;
    @:optional final element:Null<Location>;
}

/**
 * A row of the references tree: a file (`FileReferences`) or a reference.
 */
enum ReferencesTreeRow {
    File(file:FileReferences);
    Reference(reference:OneReference);
}

/**
 * Monaco's `ReferenceWidget`, the peek view of the references: a preview
 * editor (on the left, `layoutData.ratio` of the width) and the tree of the
 * references grouped by file (on the right), under a head with the file of
 * the selected reference and the title ("References (3)").
 *
 * Monaco's peek view is a zone widget (a view zone that pushes the lines
 * down); Cityscape shows it in a popup below the line instead (DEVIATIONS.md),
 * as wide as the text area and as high as Monaco's zone (`heightInLines`
 * lines, 18 by default, the head `ceil(lineHeight * 1.2)` high). The tree is
 * a plain list with the rows of referencesTree.ts (the file name, its folder
 * and the count; the line of each reference with the match highlighted).
 */
class ReferenceWidget implements IOverlayWidget implements IDisposable {

    public static inline final ID = 'editor.contrib.referencesWidget';

    public final editor:ICodeEditor;
    public final layoutData:LayoutData;

    final _onDidSelectReference = new Emitter<SelectionEvent>();
    public final onDidSelectReference:Event<SelectionEvent>;

    final _onDidClose = new VoidEmitter();
    public final onDidClose:VoidEvent;

    final _disposeOnNewModel = new DisposableStore();

    var _model:Null<ReferencesModel> = null;
    var _decorationsManager:Null<DecorationsManager> = null;
    var _isClosing:Bool = false;
    var _isVisible:Bool = false;

    /** The position the peek view shows under (Monaco's zone position). */
    public var position(default, null):Null<Position> = null;

    /** `setTitle`: the primary and secondary headings. */
    public var title(default, null):String = '';
    public var secondaryTitle(default, null):String = '';
    /** `setMetaTitle` */
    public var metaTitle(default, null):String = '';
    /** The message shown instead of the results ("No results"), or null. */
    public var message(default, null):Null<String> = null;

    /** The focused reference of the tree. */
    public var focusedReference(default, null):Null<OneReference> = null;
    /** The files expanded in the tree. */
    final _expanded:Map<String, Bool> = new Map();

    /** The model of the preview editor. */
    public var previewModel(default, null):Null<ITextModel> = null;
    var _previewRange:Null<Range> = null;
    var _previewRevealPending:Bool = false;
    var _revealedReference:Null<OneReference> = null;
    var _previewNotAvailableMessage:Null<TextModel> = null;
    var _decorationsAttached:Bool = false;

    /** The preview editor, once created. */
    public var preview(default, null):Null<CityscapeEditor> = null;

    var _view:Null<Entity<ReferenceWidgetView>> = null;
    var _app:Null<App> = null;
    var _pendingTreeFocus:Bool = false;
    var _pendingPreviewFocus:Bool = false;

    public function new(editor:ICodeEditor, layoutData:LayoutData) {
        this.editor = editor;
        this.layoutData = layoutData;
        this.onDidSelectReference = _onDidSelectReference.event;
        this.onDidClose = _onDidClose.event;
        editor.addOverlayWidget(this);
    }

    public var isClosing(get, never):Bool;
    function get_isClosing():Bool {
        return _isClosing;
    }

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return _isVisible;
    }

    public function dispose():Void {
        if (_isClosing) {
            return;
        }
        _isClosing = true;
        this.setModel(null);
        this._disposeOnNewModel.dispose();
        if (this._previewNotAvailableMessage != null) {
            this._previewNotAvailableMessage.dispose();
        }
        _isVisible = false;
        editor.removeOverlayWidget(this);
        _view = null;
        this._onDidClose.fire();
        this._onDidSelectReference.dispose();
        this._onDidClose.dispose();
    }

    /**
     * Shows the peek view under the line of `where`.
     */
    public function show(where:IRange):Void {
        this.position = new Position(where.startLineNumber, where.startColumn);
        _isVisible = true;
        changed();
    }

    /**
     * Hides the peek view (Monaco's zone widget `hide`).
     */
    public function hide():Void {
        _isVisible = false;
        changed();
    }

    public function setTitle(primaryHeading:String, ?secondaryHeading:String):Void {
        this.title = primaryHeading;
        this.secondaryTitle = secondaryHeading != null ? secondaryHeading : '';
        changed();
    }

    public function setMetaTitle(value:String):Void {
        this.metaTitle = value;
        changed();
    }

    public function focusOnReferenceTree():Void {
        _pendingTreeFocus = true;
        changed();
    }

    public function focusOnPreviewEditor():Void {
        if (preview != null) {
            preview.focus();
        }
        else {
            _pendingPreviewFocus = true;
        }
    }

    public function isPreviewEditorFocused():Bool {
        return preview != null && preview.hasTextFocus();
    }

    /**
     * Monaco's `_onTitleClick`: opens the focused reference.
     */
    public function onTitleClick(side:Bool):Void {
        if (preview != null && preview.getModel() != null) {
            final element = _getFocusedReference();
            this._onDidSelectReference.fire({
                element: element != null ? {uri: element.uri, range: element.range} : null,
                kind: side ? 'side' : 'open',
                source: 'title'
            });
        }
    }

    public function setSelection(selection:OneReference):Void {
        this._revealReference(selection, true);
        if (this._model == null) {
            // disposed
            return;
        }
        // show in tree
        this.focusedReference = selection;
        changed();
    }

    public function setModel(newModel:Null<ReferencesModel>):Void {
        // clean up
        this._disposeOnNewModel.clear();
        this._model = newModel;
        this.focusedReference = null;
        this._revealedReference = null;
        this._expanded.clear();
        if (this._model != null) {
            this._onNewModel();
        }
        changed();
    }

    public function getModel():Null<ReferencesModel> {
        return _model;
    }

    function _onNewModel():Void {
        final model = this._model;
        if (model == null) {
            return;
        }

        if (model.isEmpty) {
            this.setTitle('');
            this.message = localize('noResults', "No results");
            return;
        }

        this.message = null;

        // listen on model changes
        this._disposeOnNewModel.add(model.onDidChangeReferenceRange(_ -> changed()));

        // the decorations of the preview editor are made once it exists
        _decorationsAttached = false;
        _attachDecorations();
        for (group in model.groups) {
            group.resolve(uri -> SymbolNavigation.findModel(editor.context, uri));
        }
        this.focusOnReferenceTree();
    }

    function _attachDecorations():Void {
        final model = _model;
        final p = preview;
        if (model == null || p == null || _decorationsAttached || model.isEmpty) {
            return;
        }
        _decorationsAttached = true;
        final previewEditor = p.getEditor();
        this._decorationsManager = new DecorationsManager(previewEditor, model);
        this._disposeOnNewModel.add(this._decorationsManager);
        // listen on editor: a double click opens the focused reference
        this._disposeOnNewModel.add(previewEditor.onMouseDown(e -> {
            if (e.event.detail != 2) {
                return;
            }
            final element = this._getFocusedReference();
            if (element == null || e.target.range == null) {
                return;
            }
            this._onDidSelectReference.fire({
                element: {uri: element.uri, range: e.target.range},
                kind: (e.event.ctrlKey || e.event.metaKey || e.event.altKey) ? 'side' : 'open',
                source: 'editor'
            });
        }));
    }

    function _getFocusedReference():Null<OneReference> {
        if (focusedReference != null) {
            return focusedReference;
        }
        final model = _model;
        if (model != null && model.groups.length > 0 && model.groups[0].children.length > 0) {
            return model.groups[0].children[0];
        }
        return null;
    }

    public function revealReference(reference:OneReference):Void {
        this._revealReference(reference, false);
        this._onDidSelectReference.fire({element: {uri: reference.uri, range: reference.range}, kind: 'goto', source: 'tree'});
    }

    function _revealReference(reference:OneReference, revealParent:Bool):Void {

        // check if there is anything to do...
        if (this._revealedReference == reference) {
            return;
        }
        this._revealedReference = reference;

        // Update widget header
        if (reference.uri.scheme != 'inmemory') {
            this.setTitle(ReferencesModel.basename(reference.uri), dirname(reference.uri));
        }
        else {
            this.setTitle(localize('peekView.alternateTitle', "References"));
        }

        // expand the file of the reference in the tree
        this._expanded.set(reference.parent.uri.toString(), true);
        this.focusedReference = reference;

        if (this._model == null) {
            // disposed
            return;
        }

        // show in editor
        final model = SymbolNavigation.findModel(editor.context, reference.uri);
        if (model != null) {
            this.previewModel = model;
            this._previewRange = Range.collapseToStartStatic(reference.range);
        }
        else {
            if (this._previewNotAvailableMessage == null) {
                this._previewNotAvailableMessage = new TextModel(localize('missingPreviewMessage', "no preview available"), 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, editor.context);
            }
            this.previewModel = this._previewNotAvailableMessage;
            this._previewRange = null;
        }
        _previewRevealPending = true;
        _applyPreview();
        changed();
    }

    function _applyPreview():Void {
        final p = preview;
        if (p == null || !_previewRevealPending) {
            return;
        }
        if (previewModel != null && p.getModel() != previewModel) {
            p.setModel(previewModel);
        }
        _previewRevealPending = false;
        final sel = _previewRange;
        if (sel != null) {
            p.setSelection(sel);
            p.revealRangeInCenter(sel, ScrollType.Immediate);
        }
    }

    /**
     * Called by the view once the preview editor exists.
     */
    @:allow(cityscape.contrib.gotoSymbol.view.peek)
    function previewCreated(e:CityscapeEditor):Void {
        preview = e;
        final widget = e.getEditor();
        // `PeekContext.inPeekEditor` in the embedded editor
        widget.setContextValue('inReferenceSearchEditor', true);
        // the preview editor paints with the colors of the peek view
        // (referencesWidget.css)
        final view = EditorWidgets.viewOf(widget);
        if (view != null) {
            view.theme.remapColor('editor.background', PeekViewColors.peekViewEditorBackground);
            view.theme.remapColor('editorGutter.background', PeekViewColors.peekViewEditorGutterBackground);
        }
        _attachDecorations();
        _applyPreview();
        if (_pendingPreviewFocus) {
            _pendingPreviewFocus = false;
            e.focus();
        }
    }

    /**
     * The rows of the tree: the references of the only file, or the files
     * and the references of the expanded ones.
     */
    public function rows():Array<ReferencesTreeRow> {
        final result:Array<ReferencesTreeRow> = [];
        final model = _model;
        if (model == null || model.isEmpty) {
            return result;
        }
        if (model.groups.length == 1) {
            for (r in model.groups[0].children) {
                result.push(Reference(r));
            }
            return result;
        }
        for (group in model.groups) {
            result.push(File(group));
            if (_expanded.exists(group.uri.toString())) {
                for (r in group.children) {
                    result.push(Reference(r));
                }
            }
        }
        return result;
    }

    public function isExpanded(file:FileReferences):Bool {
        return _expanded.exists(file.uri.toString());
    }

    public function toggleExpanded(file:FileReferences):Void {
        final key = file.uri.toString();
        if (_expanded.exists(key)) {
            _expanded.remove(key);
        }
        else {
            _expanded.set(key, true);
        }
        changed();
    }

    /**
     * The tree opened a reference (Monaco's `onDidOpen` of the tree):
     * `'show'` on a click or a keyboard move, `'goto'` on a double click or
     * Enter, `'side'` with Ctrl/Cmd.
     */
    public function treeOpen(reference:OneReference, kind:String):Void {
        if (kind == 'show') {
            this._revealReference(reference, false);
        }
        this.focusedReference = reference;
        changed();
        this._onDidSelectReference.fire({element: {uri: reference.uri, range: reference.range}, kind: kind, source: 'tree'});
    }

    /**
     * Moves the focus of the tree by `delta` references and shows the
     * reference (`selectionNavigation`).
     */
    public function moveFocus(delta:Int):Void {
        final all = rows();
        if (all.length == 0) {
            return;
        }
        var index = -1;
        for (i in 0...all.length) {
            switch all[i] {
                case Reference(r):
                    if (r == focusedReference) {
                        index = i;
                    }
                case File(_):
            }
        }
        var i = index;
        while (true) {
            i += delta;
            if (i < 0 || i >= all.length) {
                return;
            }
            switch all[i] {
                case Reference(r):
                    treeOpen(r, 'show');
                    return;
                case File(_):
            }
        }
    }

    @:allow(cityscape.contrib.gotoSymbol.view.peek)
    function takeTreeFocusRequest():Bool {
        final p = _pendingTreeFocus;
        _pendingTreeFocus = false;
        return p;
    }

    public function changed():Void {
        final v = _view;
        final app = _app;
        if (v != null && app != null) {
            app.notify(v.entityId());
        }
        else if (!_isClosing) {
            editor.layoutOverlayWidget(this);
        }
    }

    public function localize(key:String, defaultMessage:String, ?args:Array<Any>):String {
        return editor.context.nls.localize(key, defaultMessage, args != null ? args : []);
    }

    public static function dirname(uri:Uri):String {
        final path = uri.path;
        final i = path.lastIndexOf('/');
        return i > 0 ? path.substring(0, i) : '';
    }

    // IOverlayWidget

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        if (_isClosing) {
            return null;
        }
        var v = _view;
        if (v == null) {
            _app = cx;
            v = cx.newEntity((c:Context<ReferenceWidgetView>) -> new ReferenceWidgetView(c, this));
            _view = v;
        }
        return v;
    }

}

/**
 * The Glaze view of the peek view (Monaco's `PeekViewWidget` head and the
 * body of `ReferenceWidget`, styled by peekViewWidget.css and
 * referencesWidget.css: the head 13 pixels, the folder 0.9em with 0.5em on
 * its left, the meta title after a `-` with 0.3em on each side; rows of 22
 * pixels).
 */
class ReferenceWidgetView extends GlazeModel implements Render {

    static inline final ROW_HEIGHT = 22;
    static inline final HEAD_FONT_SIZE = 13;

    final widget:ReferenceWidget;
    final treeFocus:FocusHandle;

    public function new(cx:Context<ReferenceWidgetView>, widget:ReferenceWidget) {
        super();
        this.widget = widget;
        this.treeFocus = cx.app.focusHandle();
    }

    function color(key:String, fallback:Hsla):Hsla {
        return EditorWidgets.color(widget.editor, key, fallback);
    }

    /**
     * Whether the tree has the keyboard focus (tests).
     */
    public function isTreeFocused(window:Window):Bool {
        return treeFocus.isFocused(window);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final editor = widget.editor;
        final position = widget.position;
        if (!widget.isVisible || position == null || !editor.hasModel()) {
            return new Empty();
        }
        final editorBounds = EditorWidgets.editorBounds(editor);
        final lineBounds = EditorWidgets.positionBounds(editor, new Position(position.lineNumber, 1));
        if (editorBounds == null || lineBounds == null) {
            return new Empty();
        }
        final app:App = cx.app;
        if (widget.takeTreeFocusRequest()) {
            treeFocus.focus(window, app);
        }
        final theme = Theme.global(cx);
        final layoutInfo = editor.getOption(EditorOption.layoutInfo);
        final lineHeight:Float = editor.getOption(EditorOption.lineHeight);
        final fontInfo = editor.getOption(EditorOption.fontInfo);

        // zoneWidget.ts: at most max(12, 80% of the lines of the editor)
        final maxHeightInLines = Math.max(12, Math.round(layoutInfo.height / lineHeight * 0.8));
        final heightInLines = Std.int(Math.min(widget.layoutData.heightInLines, maxHeightInLines));
        final height = heightInLines * lineHeight;
        // peekView.ts `_doLayout`
        final headHeight = Math.ceil(lineHeight * 1.2);
        final bodyHeight = Math.round(height - (headHeight + 2));

        final contentLeft = editorBounds.origin.x + layoutInfo.contentLeft;
        final width = Math.max(200, layoutInfo.width - layoutInfo.contentLeft - layoutInfo.verticalScrollbarWidth);

        final border = color(PeekViewColors.peekViewBorder, theme.border);
        final headBackground = color(PeekViewColors.peekViewTitleBackground, theme.popover);
        final titleForeground = color(PeekViewColors.peekViewTitleForeground, theme.popoverForeground);
        final infoForeground = color(PeekViewColors.peekViewTitleInfoForeground, theme.mutedForeground);
        final resultsBackground = color(PeekViewColors.peekViewResultsBackground, theme.popover);

        final title = div()
            .id('cityscape-peek-title')
            .flex()
            .flexRow()
            .itemsCenter()
            .flex1()
            .minW0()
            .overflowHidden()
            .whitespaceNowrap()
            .cursorPointer()
            .onMouseDown(MouseButton.Left, (event, _, cx) -> {
                cx.stopPropagation();
                widget.onTitleClick(event.modifiers.control || event.modifiers.platform || event.modifiers.alt);
            })
            .child(div().textColor(titleForeground).child(widget.title));
        if (widget.secondaryTitle.length > 0) {
            title.child(div().ml(px(HEAD_FONT_SIZE * 0.5)).textColor(infoForeground).textSize(px(HEAD_FONT_SIZE * 0.9)).child(widget.secondaryTitle));
        }
        if (widget.metaTitle.length > 0) {
            title.child(div().px(px(HEAD_FONT_SIZE * 0.3)).textColor(infoForeground).child('-'));
            title.child(div().textColor(infoForeground).child(widget.metaTitle));
        }
        final head = div()
            .id('cityscape-peek-head')
            .flex()
            .flexRow()
            .itemsCenter()
            .h(px(headHeight))
            .pl(px(8))
            .pr(px(2))
            .bg(headBackground)
            .textSize(px(HEAD_FONT_SIZE))
            .child(title)
            .child(div()
                .id('cityscape-peek-close')
                .flexNone()
                .p(px(2))
                .cursorPointer()
                .textColor(titleForeground)
                .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                    cx.stopPropagation();
                    final controller = ReferencesController.get(editor);
                    if (controller != null) {
                        controller.closeWidget();
                    }
                })
                .child(new glaze.kit.Icon(IconName.Close).withSize(16)));

        // peekViewWidget.css: the body has a top border of the frame color
        // (inside its height)
        final body = div().flex().flexRow().h(px(bodyHeight)).minH0().borderT(px(1)).borderColor(border);
        final message = widget.message;
        if (message != null) {
            body.child(div().flex1().flex().itemsCenter().justifyCenter().bg(resultsBackground).textColor(titleForeground).child(message));
        }
        else if (widget.getModel() != null) {
            final previewWidth = Math.round(width * widget.layoutData.ratio);
            final previewEditor = CityscapeEditor.component()
                .at('cityscape-peek-preview')
                .context(editor.context)
                .model(widget.previewModel)
                .options({
                    scrollBeyondLastLine: false,
                    overviewRulerLanes: 2,
                    fixedOverflowWidgets: true,
                    fontSize: fontInfo.fontSize,
                    lineHeight: lineHeight
                })
                .onCreate(e -> widget.previewCreated(e))
                .flex1();
            body.child(div().flex().flexCol().w(px(previewWidth)).hFull().minW0().child(previewEditor));
            body.child(tree(window, app, theme, width - previewWidth, bodyHeight, resultsBackground));
        }

        final surface = div()
            .id('cityscape-peek')
            .flex()
            .flexCol()
            .w(px(width))
            .h(px(height))
            // referencesWidget.css: 1 pixel of frame at the top and the
            // bottom (Monaco's `_doLayout` counts 2)
            .borderT(px(1))
            .borderB(px(1))
            .borderColor(border)
            .overflowHidden()
            .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
            .child(head)
            .child(body);

        final positioner = new ContentWidgetPositioner({
            primary: new Bounds(new Point(contentLeft, lineBounds.origin.y), new Size(1, lineBounds.size.height)),
            secondary: null,
            editor: editorBounds,
            typicalFullwidthCharacterWidth: fontInfo.typicalFullwidthCharacterWidth
        }, false).child(surface);
        return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY).intoAnyElement();
    }

    function tree(window:Window, app:App, theme:Theme, width:Float, height:Float, background:Hsla):IntoElement {
        final fileForeground = color(PeekViewColors.peekViewResultsFileForeground, theme.foreground);
        final lineForeground = color(PeekViewColors.peekViewResultsMatchForeground, theme.foreground);
        final selectionBackground = color(PeekViewColors.peekViewResultsSelectionBackground, theme.accent);
        final selectionForeground = color(PeekViewColors.peekViewResultsSelectionForeground, theme.accentForeground);
        final matchHighlight = color(PeekViewColors.peekViewResultsMatchHighlight, theme.accent);
        final infoForeground = color(PeekViewColors.peekViewTitleInfoForeground, theme.mutedForeground);
        final badgeBackground = color('badge.background', theme.secondary);
        final badgeForeground = color('badge.foreground', theme.secondaryForeground);
        final model = widget.getModel();
        final grouped = model != null && model.groups.length > 1;

        final list = div().flex().flexCol().wFull().textSize(px(HEAD_FONT_SIZE));
        var index = 0;
        for (row in widget.rows()) {
            final i = index++;
            switch row {
                case File(file):
                    final expanded = widget.isExpanded(file);
                    list.child(div()
                        .id('cityscape-peek-file-' + i)
                        .flex()
                        .flexRow()
                        .itemsCenter()
                        .h(px(ROW_HEIGHT))
                        .px(px(4))
                        .cursorPointer()
                        .whitespaceNowrap()
                        .onMouseDown(MouseButton.Left, (_, window, cx) -> {
                            cx.stopPropagation();
                            treeFocus.focus(window, cx);
                            widget.toggleExpanded(file);
                        })
                        .child(new glaze.kit.Icon(expanded ? IconName.ChevronDown : IconName.ChevronRight).withSize(16).textColor(fileForeground))
                        .child(div().ml(px(2)).textColor(fileForeground).child(ReferencesModel.basename(file.uri)))
                        .child(div().ml(px(6)).flex1().minW0().overflowHidden().textColor(infoForeground).textSize(px(HEAD_FONT_SIZE * 0.9)).child(ReferenceWidget.dirname(file.uri)))
                        .child(div().ml(px(6)).px(px(6)).roundedFull().bg(badgeBackground).textColor(badgeForeground).textSize(px(11)).child(Std.string(file.children.length))));
                case Reference(reference):
                    final focused = reference == widget.focusedReference;
                    final filePreview = reference.parent.getPreview(reference);
                    final preview = filePreview != null ? filePreview.preview(reference.range) : null;
                    final rowElement = div()
                        .id('cityscape-peek-ref-' + i)
                        .flex()
                        .flexRow()
                        .itemsCenter()
                        .h(px(ROW_HEIGHT))
                        .pl(px(grouped ? 22 : 6))
                        .pr(px(4))
                        .whitespaceNowrap()
                        .overflowHidden()
                        .cursorPointer()
                        .textColor(focused ? selectionForeground : lineForeground)
                        .onMouseDown(MouseButton.Left, (event, window, cx) -> {
                            cx.stopPropagation();
                            treeFocus.focus(window, cx);
                            if (event.clickCount >= 2) {
                                widget.treeOpen(reference, 'goto');
                            }
                            else if (event.modifiers.control || event.modifiers.platform) {
                                widget.treeOpen(reference, 'side');
                            }
                            else {
                                widget.treeOpen(reference, 'show');
                            }
                        });
                    if (focused) {
                        rowElement.bg(selectionBackground);
                    }
                    if (preview != null) {
                        final value = preview.value;
                        final start = preview.highlight.start;
                        final end = preview.highlight.end;
                        rowElement.child(div().child(value.substring(0, start)));
                        rowElement.child(div().bg(matchHighlight).child(value.substring(start, end)));
                        rowElement.child(div().child(value.substring(end)));
                    }
                    else {
                        rowElement.child(div().child(ReferencesModel.basename(reference.uri) + ':' + reference.range.startLineNumber + ':' + reference.range.startColumn));
                    }
                    list.child(rowElement);
            }
        }

        final scroll = ScrollableElement.overflowYScrollbar(list.maxH(px(height))).id('cityscape-peek-tree-scroll');
        return div()
            .id('cityscape-peek-tree')
            .flex()
            .flexCol()
            .w(px(width))
            .hFull()
            .bg(background)
            .trackFocus(treeFocus)
            .onKeyDown((event, window, cx) -> {
                switch event.keystroke.key {
                    case 'up':
                        widget.moveFocus(-1);
                        cx.stopPropagation();
                    case 'down':
                        widget.moveFocus(1);
                        cx.stopPropagation();
                    case 'enter':
                        final r = widget.focusedReference;
                        if (r != null) {
                            widget.treeOpen(r, event.keystroke.modifiers.control || event.keystroke.modifiers.platform ? 'side' : 'goto');
                        }
                        cx.stopPropagation();
                    case 'escape':
                        final controller = ReferencesController.get(widget.editor);
                        if (controller != null) {
                            controller.closeWidget();
                        }
                        cx.stopPropagation();
                    case _:
                }
            })
            .child(scroll);
    }

}
