// Ported from vscode src/vs/editor/contrib/colorPicker/browser/colorContributions.ts
// (with the color picker parts of contrib/hover/browser/contentHoverController2.ts)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Async;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.contrib.colorPicker.view.ColorDetector.ColorDecorationInjectedTextMarker;
import cityscape.contrib.colorPicker.view.ColorHoverParticipant.ColorPickerSession;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.EditorWidgets;

/**
 * Opens the color picker of a color (Monaco's `ColorContribution`, and the
 * color picker of its content hover): a click on a swatch with
 * `colorDecoratorsActivatedOn` `'click'` or `'clickAndHover'`, the mouse
 * resting on a swatch with `'hover'` or `'clickAndHover'` (the hover
 * enabled, after `hover.delay`), or the mouse resting on the text of a color
 * (the hover enabled, like Monaco's color hover participant). The picker is
 * a popover of its own next to the color (Monaco shows it in the content
 * hover). Escape, a click elsewhere, a scroll or an edit made elsewhere
 * close it; a picker opened by the mouse resting closes when the mouse
 * leaves the color and the picker. The pointer cursor shows over the
 * swatches (`cursor: pointer` of colorPicker.css).
 */
class ColorContribution extends Disposable implements IEditorContribution {

    public static inline final ID:String = 'editor.contrib.colorContribution';

    public static inline final RECOMPUTE_TIME = 1000; // ms

    final _editor:ICodeEditor;
    final _widget:ColorPickerWidget;
    var _session:Null<ColorPickerSession> = null;
    var _activatedByDecoratorClick = false;
    var _activatedByHover = false;
    final _hoverTimer = new TimeoutTimer();
    var _request = 0;
    var _pointerCursorSet = false;
    var _leaveTimer:Null<() -> Void> = null;
    var _mouseInEditor = false;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._widget = new ColorPickerWidget(editor);
        this._widget.onClose = () -> this.hide();
        this._register(_hoverTimer);
        this._register(editor.onMouseDown(e -> this.onMouseDown(e)));
        this._register(editor.onMouseMove(e -> this.onMouseMove(e)));
        this._register(editor.onMouseLeave(e -> this.onMouseLeave()));
        this._register(editor.onKeyDown(e -> {
            if (e.keyCode == KeyCode.Escape && this.isColorPickerVisible) {
                this.hide();
            }
        }));
        this._register(editor.onDidScrollChange(e -> {
            if (e.scrollTopChanged || e.scrollLeftChanged) {
                this.hide();
            }
        }));
        this._register(editor.onDidChangeModel(_ -> this.hide()));
    }

    public static function get(editor:ICodeEditor):Null<ColorContribution> {
        return editor.getContribution(ColorContribution.ID);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    override public function dispose():Void {
        this.hide();
        if (_leaveTimer != null) {
            _leaveTimer();
            _leaveTimer = null;
        }
        if (_pointerCursorSet) {
            EditorWidgets.setMouseCursor(_editor, null);
        }
        _widget.dispose();
        super.dispose();
    }

    /**
     * Whether the color picker shows (Monaco's
     * `ContentHoverController.isColorPickerVisible`).
     */
    public var isColorPickerVisible(get, never):Bool;
    function get_isColorPickerVisible():Bool {
        return _session != null;
    }

    /**
     * The color picker shown (tests): its color, presentations and range.
     */
    public function getSession():Null<ColorPickerSession> {
        return _session;
    }

    public function getWidget():ColorPickerWidget {
        return _widget;
    }

    /**
     * Shows the picker pending after the hover delay now (tests).
     */
    public function _flushHover():Void {
        _hoverTimer.flush();
    }

    static function isOnSwatch(target:MouseTarget):Bool {
        return target.type == MouseTargetType.CONTENT_TEXT
            && target.injectedText != null
            && target.injectedText.options.attachedData == ColorDecorationInjectedTextMarker.INSTANCE;
    }

    function isOnColorText(target:MouseTarget):Bool {
        if (target.type != MouseTargetType.CONTENT_TEXT || target.position == null || target.injectedText != null) {
            return false;
        }
        final detector = ColorDetector.get(_editor);
        if (detector == null) {
            return false;
        }
        final data = detector.getColorData(target.position);
        if (data == null) {
            return false;
        }
        final range = data.colorInfo.range;
        // inside the color (the column before its end)
        return target.position.lineNumber == range.startLineNumber && target.position.column >= range.startColumn && target.position.column < range.endColumn;
    }

    function onMouseDown(mouseEvent:IEditorMouseEvent):Void {
        final target = mouseEvent.target;

        if (this.isColorPickerVisible && !_widget.isStandalone) {
            if (_widget.isMouseOver || _widget.containsPoint(mouseEvent.event.posx, mouseEvent.event.posy)) {
                return;
            }
            // contentHoverController2.ts: a mouse down elsewhere hides the hover
            this.hide();
        }

        final colorDecoratorsActivatedOn = this._editor.getOption(EditorOption.colorDecoratorsActivatedOn);
        if (colorDecoratorsActivatedOn != 'click' && colorDecoratorsActivatedOn != 'clickAndHover') {
            return;
        }

        if (target.type != MouseTargetType.CONTENT_TEXT) {
            return;
        }

        if (target.injectedText == null) {
            return;
        }

        if (target.injectedText.options.attachedData != ColorDecorationInjectedTextMarker.INSTANCE) {
            return;
        }

        if (target.range == null) {
            return;
        }

        if (!this.isColorPickerVisible) {
            final range = new Range(target.range.startLineNumber, target.range.startColumn + 1, target.range.endLineNumber, target.range.endColumn + 1);
            this.showColorPicker(range, true);
        }
    }

    function onMouseMove(mouseEvent:IEditorMouseEvent):Void {
        _mouseInEditor = true;
        final target = mouseEvent.target;
        final onSwatch = isOnSwatch(target);

        // colorPicker.css: `cursor: pointer` over the swatches
        if (onSwatch && !_pointerCursorSet) {
            _pointerCursorSet = true;
            EditorWidgets.setMouseCursor(_editor, glaze.CursorStyle.PointingHand);
        }
        else if (!onSwatch && _pointerCursorSet) {
            _pointerCursorSet = false;
            EditorWidgets.setMouseCursor(_editor, null);
        }

        if (_widget.isMouseOver || _widget.containsPoint(mouseEvent.event.posx, mouseEvent.event.posy)) {
            return;
        }

        final hoverOptions = this._editor.getOption(EditorOption.hover);
        final decoratorActivatedOn = this._editor.getOption(EditorOption.colorDecoratorsActivatedOn);
        final onColorText = !onSwatch && isOnColorText(target);
        final showOnHover = hoverOptions.enabled && (onColorText || (onSwatch && (decoratorActivatedOn == 'hover' || decoratorActivatedOn == 'clickAndHover')));

        if (this.isColorPickerVisible) {
            if (_activatedByHover && !onSwatch && !onColorText) {
                this.hide();
            }
            return;
        }

        if (!showOnHover || target.position == null) {
            _hoverTimer.cancel();
            return;
        }
        final position = target.position;
        final range = new Range(position.lineNumber, position.column, position.lineNumber, position.column + 1);
        _hoverTimer.cancelAndSet(() -> this.showColorPicker(range, false), hoverOptions.delay);
    }

    function onMouseLeave():Void {
        _mouseInEditor = false;
        _hoverTimer.cancel();
        if (_pointerCursorSet) {
            _pointerCursorSet = false;
            EditorWidgets.setMouseCursor(_editor, null);
        }
        if (!_activatedByHover || !this.isColorPickerVisible) {
            return;
        }
        // the picker is drawn above the editor: wait a moment to know
        // whether the mouse went into it (like the content hover)
        if (_leaveTimer != null) {
            _leaveTimer();
        }
        _leaveTimer = Async.setTimeout(() -> {
            _leaveTimer = null;
            if (_mouseInEditor || _widget.isMouseOver) {
                return;
            }
            this.hide();
        }, 50);
    }

    /**
     * Shows the color picker of the color decoration touching `range`
     * (Monaco's `showContentHover` with the color hover participant).
     * `byClick`: opened by a click on a swatch (else by the mouse resting).
     */
    public function showColorPicker(range:Range, byClick:Bool, ?done:() -> Void):Void {
        if (!_editor.hasModel()) {
            return;
        }
        final request = ++_request;
        final lineDecorations = _editor.getModel().getDecorationsInRange(range);
        ColorHoverParticipant.computeColorHover(_editor, lineDecorations).done(colorHover -> {
            if (request != _request || colorHover == null || !_editor.hasModel()) {
                if (done != null) {
                    done();
                }
                return;
            }
            this.hide();
            _request = request;
            _activatedByDecoratorClick = byClick;
            _activatedByHover = !byClick;
            final session = new ColorPickerSession(_editor, colorHover, () -> this.hide());
            _session = session;
            _widget.show(session);
            if (done != null) {
                done();
            }
        });
    }

    public function hide():Void {
        _hoverTimer.cancel();
        _request++;
        final session = _session;
        if (session == null) {
            return;
        }
        _session = null;
        _activatedByDecoratorClick = false;
        _activatedByHover = false;
        session.dispose();
        _widget.hide();
    }
}

/**
 * The module level code of colorContributions.ts, colorDetector.ts,
 * defaultDocumentColorProvider.ts and standaloneColorPickerActions.ts.
 */
class ColorPickerRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        // defaultDocumentColorProvider.ts: `registerEditorFeature`
        r.context.languageFeaturesService.colorProvider.register('*', new DefaultDocumentColorProvider());
        r.registerEditorContribution(ColorDetector.ID, editor -> new ColorDetector(editor), EditorContributionInstantiation.AfterFirstRender);
        r.registerEditorContribution(ColorContribution.ID, editor -> new ColorContribution(editor), EditorContributionInstantiation.BeforeFirstInteraction);
        StandaloneColorPickerActions.StandaloneColorPickerRegistration.register(r);
    }

}
