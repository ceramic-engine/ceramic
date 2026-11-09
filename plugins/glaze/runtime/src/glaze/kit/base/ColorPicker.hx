// Ported from gpui-kit 0.8.1: crates/base/src/color_picker.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Context;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.Render;
import glaze.Rgba;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Slider.SliderEvent;
import glaze.kit.base.Slider.SliderState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.util.MathUtil;

import glaze.Prelude.*;

using glaze.kit.base.A11y.RoleOverrideTools;
using glaze.kit.base.Slider.SliderValueTools;
using glaze.kit.base.StyledExt;

/**
 * Events emitted by a `ColorPickerState`.
 */
enum ColorPickerEvent {
    /** The committed color changed. */
    Change(color:Null<Hsla>);
}

/**
 * The four component sliders owned by a `ColorPickerState`.
 *
 * Applications render these with their own slider presentation; the picker
 * keeps them in sync with the committed color.
 */
class HslaSliders {

    final hueSlider:Entity<SliderState>;
    final saturationSlider:Entity<SliderState>;
    final lightnessSlider:Entity<SliderState>;
    final alphaSlider:Entity<SliderState>;

    @:allow(glaze.kit.base)
    function new(cx:App) {
        final component = (cx:App) -> cx.newEntity(_ -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.));
        hueSlider = component(cx);
        saturationSlider = component(cx);
        lightnessSlider = component(cx);
        alphaSlider = component(cx);
    }

    /** The hue slider, in `0..=1`. */
    public inline function hue():Entity<SliderState> {
        return hueSlider;
    }

    /** The saturation slider, in `0..=1`. */
    public inline function saturation():Entity<SliderState> {
        return saturationSlider;
    }

    /** The lightness slider, in `0..=1`. */
    public inline function lightness():Entity<SliderState> {
        return lightnessSlider;
    }

    /** The alpha slider, in `0..=1`. */
    public inline function alpha():Entity<SliderState> {
        return alphaSlider;
    }

    @:allow(glaze.kit.base)
    function read(cx:App):Hsla {
        return hsla(
            hueSlider.read(cx).value().start(),
            saturationSlider.read(cx).value().start(),
            lightnessSlider.read(cx).value().start(),
            alphaSlider.read(cx).value().start()
        );
    }

    @:allow(glaze.kit.base)
    function write(color:Hsla, window:Window, cx:App):Void {
        final components = [
            {slider: hueSlider, value: color.h},
            {slider: saturationSlider, value: color.s},
            {slider: lightnessSlider, value: color.l},
            {slider: alphaSlider, value: color.a},
        ];
        for (component in components) {
            final value = component.value;
            component.slider.update(cx, (slider, cx) -> slider.setValue(value, window, cx));
        }
    }

}

/**
 * State and interaction model for a color picker.
 *
 * This owns the committed color, the transient preview shown while the user
 * hovers or edits, the controlled open state, the active panel, and the hex
 * field and component sliders that stay in sync with all of them. The
 * application owns the palette, popup, layout, and every visual decision.
 */
class ColorPickerState extends Model implements Render {

    static inline final CONTEXT:String = "ColorPicker";

    /** The hex values this picker's text field accepts while being typed. */
    static inline final HEX_PATTERN:String = '^#[0-9a-fA-F]{0,8}$';

    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("enter", new Confirm(false), CONTEXT),
            new KeyBinding("escape", new Cancel(), CONTEXT),
        ]);
    }

    public final focusHandle:FocusHandle;

    @observe var _value:Null<Hsla> = null;

    @observe var _preview:Null<Hsla> = null;

    @observe var open:Bool = false;

    @observe var _activeTab:Int = 0;

    final _hexInput:Entity<InputState>;

    final _sliders:HslaSliders;

    /**
     * A builder-supplied value cannot reach the sliders without a `Window`,
     * so the first render flushes it through `syncPendingValue`.
     */
    var needsSliderSync:Bool = false;

    final _subscriptions:Array<Subscription>;

    /** Creates an empty, closed picker. */
    public function new(window:Window, cx:Context<ColorPickerState>) {
        super();
        final hexInput = cx.newEntity(cx -> new InputState(window, cx).withPattern(new EReg(HEX_PATTERN, '')));
        final sliders = new HslaSliders(cx.app);
        this._hexInput = hexInput;
        this._sliders = sliders;

        final subscriptions = [
            cx.subscribeIn(hexInput, InputEvent, window, (this_, input, event, window, cx) -> {
                switch event {
                    case Change:
                        final value = input.read(cx).value();
                        if (this_.previewHex(value, window, cx)) {
                            final color = this_._preview;
                            this_._sliders.write(color, window, cx.app);
                        }
                    case PressEnter(_, _):
                        final value = input.read(cx).value();
                        this_.commitHex(value, window, cx);
                    case _:
                }
            }),
        ];

        for (slider in [sliders.hue(), sliders.saturation(), sliders.lightness(), sliders.alpha()]) {
            subscriptions.push(cx.subscribeIn(slider, SliderEvent, window, (this_, _, _, window, cx) -> {
                final color = this_._sliders.read(cx.app);
                this_.updateValueFromSlider(color, window, cx);
            }));
        }

        focusHandle = cx.focusHandle();
        _subscriptions = subscriptions;
    }

    /** Parses `#rgb`, `#rgba`, `#rrggbb`, and `#rrggbbaa`, with or without the `#`. */
    @:allow(glaze)
    @:allow(tests)
    static function parseHex(value:String):Null<Hsla> {
        final value = StringTools.startsWith(value, '#') ? value.substr(1) : value;
        // `from_str_radix` accepts a leading sign, so reject anything that is not
        // purely hexadecimal before slicing components out of it.
        for (i in 0...value.length) {
            final c = value.charCodeAt(i);
            final hex = (c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'f'.code) || (c >= 'A'.code && c <= 'F'.code);
            if (!hex) return null;
        }

        var width:Int;
        var hasAlpha:Bool;
        switch value.length {
            case 3:
                width = 1;
                hasAlpha = false;
            case 4:
                width = 1;
                hasAlpha = true;
            case 6:
                width = 2;
                hasAlpha = false;
            case 8:
                width = 2;
                hasAlpha = true;
            case _:
                return null;
        }

        function component(index:Int):Float {
            final start = index * width;
            var raw = Std.parseInt('0x' + value.substr(start, width));
            // A single digit repeats itself rather than scaling, so `#fff` is white.
            if (width == 1) raw = raw * 0x11;
            return f32(raw / 255.0);
        }

        return Hsla.fromRgba(new Rgba(component(0), component(1), component(2), hasAlpha ? component(3) : 1.0));
    }

    /** Formats a color as `#RRGGBB`, or `#RRGGBBAA` when it is translucent. */
    @:allow(glaze)
    @:allow(tests)
    static function hexString(color:Hsla):String {
        final rgba = Rgba.fromHsla(color);
        function channel(value:Float):String {
            final v = Std.int(MathUtil.round(f32(MathUtil.clamp(value, 0., 1.) * 255.)));
            return StringTools.hex(v < 0 ? 0 : (v > 255 ? 255 : v), 2);
        }
        if (rgba.a < 1.) {
            return '#' + channel(rgba.r) + channel(rgba.g) + channel(rgba.b) + channel(rgba.a);
        }
        return '#' + channel(rgba.r) + channel(rgba.g) + channel(rgba.b);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    /** Sets the initial committed and previewed color. */
    public function defaultValue(value:Hsla):ColorPickerState {
        _value = value;
        _preview = value;
        needsSliderSync = true;
        return this;
    }

    /** Returns the committed color. */
    public inline function value():Null<Hsla> {
        return _value;
    }

    /** Returns the color currently being previewed. */
    public inline function preview():Null<Hsla> {
        return _preview;
    }

    /** Returns the previewed color, falling back to the committed color. */
    public function displayedColor():Null<Hsla> {
        return _preview != null ? _preview : _value;
    }

    /** The hex text field. Render it with an application-owned input element. */
    public inline function hexInput():Entity<InputState> {
        return _hexInput;
    }

    /** The HSLA component sliders. */
    public inline function sliders():HslaSliders {
        return _sliders;
    }

    /** Replaces the committed color without emitting a change. */
    public function setValue(value:Hsla, window:Window, cx:Context<ColorPickerState>):Void {
        updateValue(value, false, window, cx);
    }

    /** Clears the committed color without emitting a change. */
    public function clearValue(window:Window, cx:Context<ColorPickerState>):Void {
        updateValue(null, false, window, cx);
    }

    /**
     * Applies a value supplied to `defaultValue` to the hex field and
     * sliders. Call this from render; it is a no-op once nothing is pending.
     */
    public function syncPendingValue(window:Window, cx:Context<ColorPickerState>):Void {
        if (needsSliderSync) {
            updateValue(_value, false, window, cx);
        }
    }

    /** Updates the transient preview color and the hex field that shows it. */
    public function previewColor(value:Hsla, window:Window, cx:Context<ColorPickerState>):Void {
        _preview = value;
        writeHexInput(value, window, cx.app);
        cx.notify();
    }

    /** Drops the transient preview, restoring the committed color. */
    public function clearPreview(window:Window, cx:Context<ColorPickerState>):Void {
        if (sameColor(_preview, _value)) {
            return;
        }
        _preview = _value;
        writeHexInput(_value, window, cx.app);
        cx.notify();
    }

    /**
     * Parses a hex color into the transient preview.
     *
     * Invalid or incomplete input leaves the current preview unchanged. This
     * does not write the hex field, so it is safe to call while typing in it.
     */
    public function previewHex(value:String, window:Window, cx:Context<ColorPickerState>):Bool {
        final value = parseHex(value);
        if (value == null) {
            return false;
        }
        _preview = value;
        cx.notify();
        return true;
    }

    /** Parses and commits a hex color, closing the picker on success. */
    public function commitHex(value:String, window:Window, cx:Context<ColorPickerState>):Null<Hsla> {
        final value = parseHex(value);
        if (value == null) return null;
        selectColor(value, window, cx);
        return value;
    }

    /** Commits a color and closes the picker, as a palette selection does. */
    public function selectColor(value:Hsla, window:Window, cx:Context<ColorPickerState>):Void {
        open = false;
        updateValue(value, true, window, cx);
    }

    /** Commits a color without changing the open state, as a slider drag does. */
    public function updateColor(value:Hsla, window:Window, cx:Context<ColorPickerState>):Void {
        updateValue(value, true, window, cx);
    }

    /** Sets whether the picker popup is open. */
    public function setOpen(open:Bool, cx:Context<ColorPickerState>):Void {
        if (this.open == open) {
            return;
        }
        this.open = open;
        cx.notify();
    }

    /** Toggles the picker popup. */
    public function toggleOpen(cx:Context<ColorPickerState>):Void {
        open = !open;
        cx.notify();
    }

    /** Returns whether the picker popup is open. */
    public inline function isOpen():Bool {
        return open;
    }

    /** Selects the application-defined picker panel. */
    public function setActiveTab(tab:Int, cx:Context<ColorPickerState>):Void {
        if (_activeTab == tab) {
            return;
        }
        _activeTab = tab;
        cx.notify();
    }

    /** Returns the selected application-defined picker panel. */
    public inline function activeTab():Int {
        return _activeTab;
    }

    static function sameColor(a:Null<Hsla>, b:Null<Hsla>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    function updateValue(value:Null<Hsla>, emit:Bool, window:Window, cx:Context<ColorPickerState>):Void {
        needsSliderSync = false;
        _value = value;
        _preview = value;
        writeHexInput(value, window, cx.app);
        // Drive the sliders from the full-precision color rather than letting
        // the hex round-trip do it.
        if (value != null) {
            _sliders.write(value, window, cx.app);
        }
        if (emit) {
            cx.emit(ColorPickerEvent.Change(value));
        }
        cx.notify();
    }

    function updateValueFromSlider(value:Hsla, window:Window, cx:Context<ColorPickerState>):Void {
        needsSliderSync = false;
        _value = value;
        _preview = value;
        // Write the hex field, but leave the sliders alone: they are the source
        // of this change and rewriting them would fight the drag in progress.
        writeHexInput(value, window, cx.app);
        cx.emit(ColorPickerEvent.Change(value));
        cx.notify();
    }

    /**
     * Writes the hex field. `InputState.setValue` emits no change event,
     * so nothing feeds back, and the next typed edit still previews.
     */
    function writeHexInput(value:Null<Hsla>, window:Window, cx:App):Void {
        final text = value != null ? hexString(value) : '';
        (cast _hexInput : Entity<glaze.kit.base.input.InputBaseState>).update(cx, (input, cx) -> input.setValue(text, window, cx));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return _hexInput;
    }

}

/**
 * An unstyled controlled color-picker root.
 *
 * Applications own the trigger, palette, popup, and every visual decision.
 * This root owns focus, accessibility semantics, and the keyboard behavior
 * that opens and dismisses the picker.
 */
class ColorPicker extends Component implements Styled implements ParentElement {

    /** The stateful element the picker renders. */
    public final base:Div;

    /** Sets the application-controlled open state. */
    @prop var open:Bool = false;

    /** Prevents keyboard interaction and removes the trigger from tab traversal. */
    @prop var disabled:Bool = false;

    /** Supplies the focus handle for the picker trigger. */
    @prop var trackFocus:Null<FocusHandle> = null;

    /** Sets the accessible name exposed by the controlled root. */
    @prop var accessibilityLabel:Null<String> = null;

    final pickerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /**
     * Handles requests to update the controlled open state.
     *
     * Confirm toggles the picker and Cancel dismisses an open one.
     */
    @prop var onOpenChange:Null<(Bool, Window, App) -> Void> = null;

    var keyContextValue:String = @:privateAccess ColorPickerState.CONTEXT;

    /** Overrides the accessibility role. The default is `Role.Button`. */
    @prop var role:RoleOverride = RoleOverride.Implicit;

    /** The accessibility properties the picker exports (filled by `render`). */
    public final a11y:A11y = new A11y();

    public function new(id:ElementIdArg) {
        super();
        base = div().id(id);
    }

    @:noCompletion
    public function keyContext(keyContext:String):ColorPicker {
        keyContextValue = keyContext;
        return this;
    }

    public inline function style():StyleRefinement {
        return pickerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(window:Window, cx:App):IntoElement {
        final open = this.open;
        final disabled = this.disabled;
        final handler = onOpenChange;

        a11y.role = role.resolve(() -> Role.Button);
        a11y.expanded = open;
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        base.keyContext(keyContextValue);
        if (trackFocus != null && !disabled) {
            base.trackFocus(trackFocus.tabStop(true));
        }
        base
            .onAction(Confirm, (_, window, cx) -> {
                if (disabled) {
                    cx.propagate();
                    return;
                }
                if (handler != null) {
                    handler(!open, window, cx);
                }
            })
            .onAction(Cancel, (_, window, cx) -> {
                if (!open) {
                    cx.propagate();
                    return;
                }
                cx.stopPropagation();
                if (handler != null) {
                    handler(false, window, cx);
                }
            });
        base.extend(childElements);
        return base.refineStyle(pickerStyle);
    }

}

/**
 * An unstyled selectable color in a picker's palette.
 *
 * The application paints the color; this part carries the radio semantics,
 * the accessible hex name, and the hover and activation callbacks a picker
 * uses to preview and commit a color.
 *
 * Interactive styles go to `base`.
 */
class ColorSwatch extends Component implements Styled implements ParentElement {

    final id:ElementIdArg;

    /** The stateful element the swatch renders. */
    public final base:Div;

    final colorValue:Hsla;

    /** Marks this swatch as the picker's current color. */
    @prop var selected:Bool = false;

    /** Sets whether pointer and keyboard activation are ignored. */
    @prop var disabled:Bool = false;

    final swatchStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** Overrides the accessible name. The default is the color's hex value. */
    @prop var accessibilityLabel:Null<String> = null;

    /** Handles activation with the swatch's color. */
    @prop var onClick:Null<(Hsla, ClickEvent, Window, App) -> Void> = null;

    /** Handles hover enter and exit with the swatch's color. */
    @prop var onHover:Null<(Hsla, Bool, Window, App) -> Void> = null;

    /** Sets the focus traversal index. The default is `0`. */
    @prop var tabIndex:Int = 0;

    /** Sets whether this swatch participates in keyboard focus traversal. */
    @prop var tabStop:Bool = true;

    /** Overrides the accessibility role. The default is `Role.RadioButton`. */
    @prop var role:RoleOverride = RoleOverride.Implicit;

    /** The accessibility properties the swatch exports (filled by `render`). */
    public final a11y:A11y = new A11y();

    public function new(id:ElementIdArg, color:Hsla) {
        super();
        this.id = id;
        this.base = div().id(id);
        this.colorValue = color;
    }

    /** The color this swatch represents. */
    public inline function color():Hsla {
        return colorValue;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):ColorSwatch {
        base.hover(f);
        return this;
    }

    /** Interactive style while pressed (on `base`). */
    public function active(f:(StyleBuilder) -> StyleBuilder):ColorSwatch {
        base.active(f);
        return this;
    }

    public inline function style():StyleRefinement {
        return swatchStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(window:Window, cx:App):IntoElement {
        final color = colorValue;
        final disabled = this.disabled;
        final selected = this.selected;
        final label = accessibilityLabel != null ? accessibilityLabel : ColorPickerState.hexString(color);
        final focusHandle = window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;

        a11y.role = role.resolve(() -> Role.RadioButton);
        a11y.label = label;
        // A palette color is both "toggled" and "selected"; assistive
        // technology reads one or the other, so state both.
        a11y.toggled = selected ? Toggled.True : Toggled.False;
        a11y.selected = selected;
        if (!disabled) {
            base.trackFocus(focusHandle.tabIndex(tabIndex).tabStop(tabStop));
        }
        final onHover = this.onHover;
        if (!disabled && onHover != null) {
            base.onHover((entered, window, cx) -> onHover(color, entered, window, cx));
        }
        final onClick = this.onClick;
        if (!disabled && onClick != null) {
            a11y.clickable = true;
            base.onClick((event, window, cx) -> onClick(color, event, window, cx));
        }
        base.extend(childElements);
        return base.refineStyle(swatchStyle);
    }

}
