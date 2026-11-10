// Ported from vscode src/vs/editor/contrib/colorPicker/browser/colorPickerWidget.ts
// (ColorPickerHeader and colorPicker.css; the body is the Glaze kit's color picker)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.base.common.Color;
import cityscape.base.common.Lifecycle;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.contrib.colorPicker.view.ColorHoverParticipant.ColorPickerSession;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.ColorPicker.ColorPickerEvent;
import glaze.kit.base.ColorPicker.ColorPickerState;
import glaze.kit.base.Slider.SliderEvent;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * The color picker on screen (Monaco's `ColorPickerWidget` in its content
 * hover), an overlay widget whose Glaze view (`ColorPickerView`) places
 * itself next to the color like a content widget.
 */
class ColorPickerWidget implements IOverlayWidget implements IDisposable {

    public static inline final ID = 'editor.contrib.colorPickerWidget';

    final _editor:ICodeEditor;
    final _id:String;
    var _session:Null<ColorPickerSession> = null;
    var _view:Null<Entity<ColorPickerView>> = null;
    var _app:Null<App> = null;
    var _standalone:Bool = false;

    /** Called when the picker asks to close (the close button of the standalone picker). */
    public var onClose:Null<() -> Void> = null;

    /** The window bounds of the picker, from its last layout. */
    public var bounds(default, null):Null<Bounds> = null;

    /** Whether the mouse is over the picker. */
    public var isMouseOver(default, null):Bool = false;

    public function new(editor:ICodeEditor, ?id:String) {
        this._editor = editor;
        this._id = id != null ? id : ID;
        editor.addOverlayWidget(this);
    }

    public function dispose():Void {
        _editor.removeOverlayWidget(this);
        cityscape.view.ViewEntities.release(_view);
        _view = null;
    }

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return _session != null;
    }

    public var isStandalone(get, never):Bool;
    function get_isStandalone():Bool {
        return _standalone;
    }

    public function getSession():Null<ColorPickerSession> {
        return _session;
    }

    public function show(session:ColorPickerSession, standalone:Bool = false):Void {
        _session = session;
        _standalone = standalone;
        bounds = null;
        isMouseOver = false;
        changed();
    }

    public function hide():Void {
        if (_session == null) {
            return;
        }
        _session = null;
        bounds = null;
        isMouseOver = false;
        changed();
    }

    public function changed():Void {
        final v = _view;
        final app = _app;
        if (v != null && app != null) {
            app.notify(v.entityId());
        }
        else {
            _editor.layoutOverlayWidget(this);
        }
    }

    @:allow(cityscape.contrib.colorPicker.view)
    function setBounds(b:Bounds):Void {
        bounds = b;
    }

    @:allow(cityscape.contrib.colorPicker.view)
    function setMouseOver(over:Bool):Void {
        isMouseOver = over;
    }

    public function containsPoint(x:Float, y:Float):Bool {
        final b = bounds;
        return b != null && x >= b.origin.x && x <= b.origin.x + b.size.width && y >= b.origin.y && y <= b.origin.y + b.size.height;
    }

    public function getId():String {
        return _id;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        var v = _view;
        if (v == null) {
            _app = cx;
            v = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<ColorPickerView>) -> new ColorPickerView(this, _editor)), cx);
            _view = v;
        }
        return v;
    }

}

/**
 * The Glaze view of the color picker: Monaco's header (`ColorPickerHeader`,
 * 24 pixels: the picked color with the label of its presentation, a click
 * cycling through the presentations, then the original color on 74 pixels,
 * a click going back to it) above the body of the kit's color picker (its
 * palette and HSLA sliders, in place of Monaco's saturation box and strips),
 * on the surface of the hover (`editorHoverWidget.*` colors, 1 pixel border,
 * 302 pixels wide like Monaco's minimum). A palette or hex color, and the
 * release of a slider, write the color to the model (Monaco's
 * `flushColor` on pointer up).
 */
class ColorPickerView extends Model implements Render {

    /** colorPicker.css */
    public static inline final WIDTH = 302;
    public static inline final HEADER_HEIGHT = 24;
    public static inline final ORIGINAL_COLOR_WIDTH = 74;

    final widget:ColorPickerWidget;
    final editor:ICodeEditor;

    var state:Null<Entity<ColorPickerState>> = null;
    var stateSession:Null<ColorPickerSession> = null;
    final subscriptions:Array<Subscription> = [];
    final modelListeners = new DisposableStore();
    var sliderActive = false;

    public function new(widget:ColorPickerWidget, editor:ICodeEditor) {
        super();
        this.widget = widget;
        this.editor = editor;
    }

    static function toHsla(color:Color):Hsla {
        final rgba = color.rgba;
        return new glaze.Rgba(rgba.r / 255, rgba.g / 255, rgba.b / 255, rgba.a).toHsla();
    }

    static function fromHsla(hsla:Hsla):Color {
        final rgba = glaze.Rgba.fromHsla(hsla);
        return new Color(new RGBA(Math.round(rgba.r * 255), Math.round(rgba.g * 255), Math.round(rgba.b * 255), Math.round(rgba.a * 100) / 100));
    }

    function bindSession(session:ColorPickerSession, window:Window, cx:Context<Dynamic>):Entity<ColorPickerState> {
        for (s in subscriptions) {
            s.dispose();
        }
        subscriptions.resize(0);
        modelListeners.clear();
        sliderActive = false;

        final model = session.colorHover.model;
        final initial = toHsla(model.color);
        final state:Entity<ColorPickerState> = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<ColorPickerState>) -> new ColorPickerState(window, c).defaultValue(initial)), cx.app);
        // the HSLA sliders by default (Monaco's picker has no palette)
        state.update(cx.app, (s, c) -> s.setActiveTab(1, c));
        this.state = state;
        this.stateSession = session;

        final view:Context<ColorPickerView> = cast cx;
        subscriptions.push(view.subscribeIn(state, ColorPickerEvent, window, (this_, _, event, window, cx) -> {
            switch event {
                case Change(color):
                    if (color == null || this_.stateSession != session) {
                        return;
                    }
                    model.color = fromHsla(color);
                    if (!this_.sliderActive) {
                        model.flushColor();
                    }
            }
        }));
        final sliders = state.read(cx.app).sliders();
        for (slider in [sliders.hue(), sliders.saturation(), sliders.lightness(), sliders.alpha()]) {
            subscriptions.push(view.subscribeIn(slider, SliderEvent, window, (this_, _, event, window, cx) -> {
                switch event {
                    case Change(_):
                        this_.sliderActive = true;
                    case Release(_):
                        this_.sliderActive = false;
                        if (this_.stateSession == session) {
                            model.flushColor();
                        }
                }
            }));
        }
        modelListeners.add(model.onDidChangePresentation(_ -> widget.changed()));
        modelListeners.add(model.onDidChangeColor(_ -> widget.changed()));
        return state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final session = widget.getSession();
        if (session == null || !editor.hasModel()) {
            if (session == null && stateSession != null) {
                for (s in subscriptions) {
                    s.dispose();
                }
                subscriptions.resize(0);
                modelListeners.clear();
                state = null;
                stateSession = null;
            }
            return new Empty();
        }
        final range = session.getRange();
        final primaryPosition = new Position(range.startLineNumber, range.startColumn);
        final secondaryPosition = new Position(range.startLineNumber, range.startLineNumber == range.endLineNumber ? range.endColumn : range.startColumn);
        final primary = EditorWidgets.positionBounds(editor, primaryPosition);
        final editorBounds = EditorWidgets.editorBounds(editor);
        if (primary == null || editorBounds == null || !EditorWidgets.isPositionVisible(editor, primaryPosition)) {
            return new Empty();
        }
        final secondary = EditorWidgets.positionBounds(editor, secondaryPosition);

        final state = (this.stateSession == session && this.state != null) ? this.state : bindSession(session, window, cx);
        final app:App = cx.app;
        final theme = Theme.global(cx);
        final background = EditorWidgets.color(editor, 'editorHoverWidget.background', EditorWidgets.color(editor, 'editorWidget.background', theme.popover));
        final foreground = EditorWidgets.color(editor, 'editorHoverWidget.foreground', EditorWidgets.color(editor, 'editor.foreground', theme.popoverForeground));
        final border = EditorWidgets.color(editor, 'editorHoverWidget.border', EditorWidgets.color(editor, 'editorWidget.border', theme.border));
        final fontInfo = editor.getOption(EditorOption.fontInfo);

        final model = session.colorHover.model;
        final color = model.color;
        // `.picked-color.light`: black text on a light color (on the
        // background of the hover when the color is mostly transparent)
        final backgroundColor:Color = {
            final c = editor.context.themeService.getColorTheme().getColor('editorHoverWidget.background');
            c != null ? c : Color.white;
        };
        final light = color.rgba.a < 0.5 ? backgroundColor.isLighter() : color.isLighter();
        final presentation = model.presentation;
        final label = presentation != null ? presentation.label : '';

        final pickerState = state;
        final header = div()
            .id('cityscape-colorpicker-header')
            .flex()
            .flexRow()
            .h(px(HEADER_HEIGHT))
            .child(div()
                .id('cityscape-colorpicker-picked')
                .flex1()
                .flex()
                .itemsCenter()
                .justifyCenter()
                .overflowHidden()
                .whitespaceNowrap()
                .cursorPointer()
                .bg(toHsla(color))
                .textColor(light ? hsla(0, 0, 0, 1) : hsla(0, 0, 1, 1))
                .lineHeight(px(HEADER_HEIGHT))
                .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                    cx.stopPropagation();
                    model.selectNextColorPresentation();
                })
                .child(div().mx(px(5)).child(label)))
            .child(div()
                .id('cityscape-colorpicker-original')
                .w(px(ORIGINAL_COLOR_WIDTH))
                .flexNone()
                .cursorPointer()
                .bg(toHsla(model.originalColor))
                .onMouseDown(MouseButton.Left, (_, window, cx) -> {
                    cx.stopPropagation();
                    model.color = model.originalColor;
                    pickerState.update(cx, (s, c) -> s.setValue(toHsla(model.originalColor), window, c));
                    model.flushColor();
                }));

        if (widget.isStandalone) {
            // the close button of the standalone picker (`.close-button`)
            header.child(div()
                .id('cityscape-colorpicker-close')
                .flexNone()
                .w(px(HEADER_HEIGHT))
                .flex()
                .itemsCenter()
                .justifyCenter()
                .cursorPointer()
                .bg(background)
                .borderL1()
                .borderColor(border)
                .textColor(foreground)
                .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                    cx.stopPropagation();
                    final close = widget.onClose;
                    if (close != null) {
                        close();
                    }
                })
                .child('×'));
        }

        // `.colorpicker-body` (8 pixels of padding) with the kit's picker
        final kitPicker = new glaze.kit.colorpicker.ColorPicker(state);
        final body = div()
            .id('cityscape-colorpicker-body')
            .p(px(8))
            .child(@:privateAccess kitPicker.renderColors(window, app));

        final surface = div()
            .id('cityscape-colorpicker')
            .flex()
            .flexCol()
            .w(px(WIDTH))
            .bg(background)
            .textColor(foreground)
            .textSize(px(fontInfo.fontSize))
            .border1()
            .borderColor(border)
            .rounded(px(3))
            .overflowHidden()
            .onHover(hovered -> widget.setMouseOver(hovered))
            .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
            .onMouseDownOut((_, _, _) -> {
                // a click outside of the picker closes it (Monaco hides its
                // hover on a mouse down elsewhere)
                if (widget.getSession() == session) {
                    final close = widget.onClose;
                    if (close != null) {
                        close();
                    }
                }
            })
            .child(header)
            .child(body);
        final chrome = editor.context.hoverChrome;
        if (chrome != null) {
            chrome(surface);
        }

        final above = editor.getOption(EditorOption.hover).above;
        final positioner = new ContentWidgetPositioner({
            primary: primary,
            secondary: secondary,
            editor: editorBounds,
            typicalFullwidthCharacterWidth: fontInfo.typicalFullwidthCharacterWidth,
            // `overflowWidgetsBounds: 'editor'`: kept inside the editor
            page: EditorWidgets.overflowPage(editor)
        }, above)
            .onPlacement(placement -> widget.setBounds(placement.bounds))
            .child(surface);
        return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY).intoAnyElement();
    }

}
