// Ported from gpui-kit 0.8.1: crates/component/src/color_picker.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-011 (the trigger and tooltip hex is rounded). See DEVIATIONS.md.
package glaze.kit.colorpicker;

import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.TextAlign;
import glaze.Window;
import glaze.kit.base.ColorPicker.ColorPickerState;
import glaze.kit.base.ColorPicker.ColorSwatch;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.input.Input;
import glaze.kit.popover.Popover;
import glaze.kit.select.Caret;
import glaze.kit.separator.Separator;
import glaze.kit.slider.Slider;
import glaze.kit.tab.Tab;
import glaze.kit.tab.TabBar;
import glaze.kit.theme.Color;
import glaze.kit.theme.Theme;
import glaze.kit.tooltip.Tooltip;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;
using glaze.kit.theme.Colorize;
using glaze.kit.tooltip.Tooltip.ManagedTooltip;

/**
 * A color picker element.
 *
 * `ColorPickerState` and `ColorPickerEvent` are the Base ones
 * (`glaze.kit.base.ColorPicker`).
 */
class ColorPicker implements RenderOnce implements Styled implements Sizable {

    @:allow(glaze.kit.colorpicker)
    var id:ElementId;

    final pickerStyle:StyleRefinement = new StyleRefinement();

    final state:Entity<ColorPickerState>;

    @:allow(glaze.kit.colorpicker)
    @:allow(tests)
    var featuredColorsValue:Null<Array<Hsla>> = null;

    @:allow(tests)
    var labelValue:Null<String> = null;

    /** The announced name, when the visible label is not it. */
    @:allow(tests)
    var accessibilityLabelValue:Null<String> = null;

    var iconValue:Null<Icon> = null;

    @:allow(glaze.kit.colorpicker)
    @:allow(tests)
    var size:Size = Medium;

    var anchorValue:Anchor = Anchor.TopLeft;

    /** Draws the trigger as a framed field, see `ColorSelect`. */
    @:allow(glaze.kit.colorpicker)
    @:allow(tests)
    var field:Bool = false;

    @:allow(glaze.kit.colorpicker)
    @:allow(tests)
    var placeholderValue:Null<String> = null;

    /** Create a new color picker element with the given `ColorPickerState`. */
    public function new(state:Entity<ColorPickerState>) {
        this.id = ElementId.NamedInteger('color-picker', state.entityId());
        this.state = state;
    }

    /**
     * Deviation DEV-011: the hex shown by the trigger and its tooltip, rounded
     * like the hex field (gpui-base `hex_string`), so the same color reads the
     * same everywhere. `Colorize.toHex` truncates the channels.
     */
    @:allow(glaze.kit.colorpicker)
    @:allow(tests)
    static function displayHex(color:Hsla):String {
        return ColorPickerState.hexString(color);
    }

    @:allow(tests)
    static function colorPalettes():Array<Array<Hsla>> {
        final colors = @:privateAccess Color.shadcnColors();
        function c(name:String):Array<Hsla> {
            final scale = colors.scales.get(name);
            final keys = [for (k in scale.keys()) k];
            keys.sort((a, b) -> a - b);
            return [for (k in keys) scale.get(k)];
        }
        return [c('stone'), c('red'), c('orange'), c('yellow'), c('green'), c('cyan'), c('blue'), c('purple'), c('pink')];
    }

    /**
     * Set the featured colors to be displayed in the color picker.
     *
     * This is used to display a set of colors that the user can quickly select from,
     * for example provided user's last used colors.
     */
    public function featuredColors(colors:Array<Hsla>):ColorPicker {
        featuredColorsValue = colors;
        return this;
    }

    /**
     * Set the icon to the color picker button.
     *
     * If this is set the color picker button will display the icon.
     * Else it will display the square color of the current value.
     */
    public function icon(icon:Icon):ColorPicker {
        iconValue = icon;
        return this;
    }

    /** Set the label to be displayed above the color picker. Default is `null`. */
    public function label(label:String):ColorPicker {
        labelValue = label;
        return this;
    }

    /**
     * Set the name a screen reader announces, when the visible label is not
     * it.
     *
     * A color picker's name comes from its `label` by default. Setting this
     * replaces the announced name without changing the visible label.
     */
    public function accessibilityLabel(label:String):ColorPicker {
        accessibilityLabelValue = label;
        return this;
    }

    /** Set the anchor corner of the color picker. Default is `Anchor.TopLeft`. */
    public function anchor(anchor:Anchor):ColorPicker {
        anchorValue = anchor;
        return this;
    }

    public function withSize(size:IntoSize):ColorPicker {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    /** The picker's focus handle (Rust `Focusable`). */
    public function focusHandle(cx:App):FocusHandle {
        return state.read(cx).focusHandle;
    }

    public inline function style():StyleRefinement {
        return pickerStyle;
    }

    function renderItem(id:ElementId, color:Hsla, cx:App):ColorSwatch {
        final value = state.read(cx).value();
        final selected = value != null && value.equals(color);
        final hoverState = state;
        final clickState = state;

        return new ColorSwatch(id, color)
            .selected(selected)
            .h5()
            .w5()
            .bg(color)
            .border1()
            .borderColor(color.darken(0.1))
            .hover(s -> s.borderColor(color.darken(0.3)).bg(color.lighten(0.1)))
            .active(s -> s.borderColor(color.darken(0.5)).bg(color.darken(0.2)))
            .onHover((color, entered, window, cx) -> {
                if (entered) {
                    hoverState.update(cx, (state, cx) -> state.previewColor(color, window, cx));
                }
            })
            .onClick((color, _, window, cx) -> {
                clickState.update(cx, (state, cx) -> state.selectColor(color, window, cx));
            });
    }

    function renderColors(window:Window, cx:App):IntoElement {
        state.update(cx, (state, cx) -> state.syncPendingValue(window, cx));

        final theme = Theme.global(cx);
        final s = state.read(cx);
        final activeTab = s.activeTab();
        final displayed = s.displayedColor();
        final sliderColor = displayed != null ? displayed : hsla(0., 0., 0., 1.);
        final hoveredColor = s.preview();
        final tabState = state;

        final root = vFlex()
            .p0p5()
            .gap3()
            .child(new TabBar('mode')
                .segmented()
                .selectedIndex(activeTab)
                .onClick((ix, _, cx) -> {
                    tabState.update(cx, (state, cx) -> state.setActiveTab(ix, cx));
                })
                .child(new Tab().flex1().label(I18n.t('ColorPicker.Palette')))
                .child(new Tab().flex1().label(I18n.t('ColorPicker.HSLA'))))
            .child(activeTab == 0 ? renderPalettePanel(cx) : renderSliderTabPanel(sliderColor, cx));
        if (hoveredColor != null) {
            root.child(Separator.horizontal()).child(hFlex()
                .gap2()
                .itemsCenter()
                .child(div()
                    .bg(hoveredColor)
                    .flexShrink0()
                    .border1()
                    .borderColor(hoveredColor.darken(0.2))
                    .size5()
                    .rounded(theme.radius))
                .child(new Input(state.read(cx).hexInput()).small().px2p5()));
        }
        return root;
    }

    @:allow(tests)
    function renderPalettePanel(cx:App):IntoElement {
        final theme = Theme.global(cx);
        final featuredColors = featuredColorsValue != null ? featuredColorsValue : [
            theme.red,
            theme.redLight,
            theme.blue,
            theme.blueLight,
            theme.green,
            theme.greenLight,
            theme.yellow,
            theme.yellowLight,
            theme.cyan,
            theme.cyanLight,
            theme.magenta,
            theme.magentaLight,
        ];

        final featured = hFlex().gap1();
        // Featured slots may contain the same color more than once.
        for (ix in 0...featuredColors.length) {
            featured.child(renderItem(ElementId.NamedInteger('featured-color', ix), featuredColors[ix], cx));
        }
        final rows = vFlex().gap1();
        final palettes = colorPalettes();
        for (ix in 0...palettes.length) {
            final subColors = palettes[ix].copy();
            subColors.reverse();
            final row = hFlex().id(ElementId.NamedInteger('palette-row', ix)).gap1();
            for (color in subColors) {
                row.child(renderItem(ElementId.Name('color-' + color.toHex()), color, cx));
            }
            rows.child(row);
        }
        return vFlex()
            .gap3()
            .child(featured)
            .child(Separator.horizontal())
            .child(rows);
    }

    /** Rust `format!("{:.0}", value)` of an `f32`: rounded half to even. */
    @:allow(tests)
    static function formatInteger(value:Float):String {
        final v = glaze.SpringMath.f32(value);
        var n = Math.ffloor(v);
        final frac = v - n;
        if (frac > 0.5 || (frac == 0.5 && n % 2 != 0)) n += 1;
        final negative = n < 0 || (n == 0 && v < 0);
        final digits = Std.string(Math.abs(n));
        final dot = digits.indexOf('.');
        return (negative ? '-' : '') + (dot >= 0 ? digits.substr(0, dot) : digits);
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    function sliderRow(label:String, track:IntoElement, slider:Slider, valueText:String, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final labelColor = theme.foreground.opacity(0.7);
        return hFlex()
            .gap2()
            .itemsCenter()
            .child(div()
                .minW16()
                .textXs()
                .textColor(labelColor)
                .child(label))
            .child(div()
                .relative()
                .flex()
                .itemsCenter()
                .flex1()
                .h8()
                .child(track)
                .child(slider.flex1().bg(theme.transparent)))
            .child(div()
                .w10()
                .textXs()
                .textColor(labelColor)
                .textAlign(TextAlign.Right)
                .child(valueText));
    }

    function renderSliderTabPanel(sliderColor:Hsla, cx:App):IntoElement {
        final sliders = state.read(cx).sliders();
        final steps = 96;
        final hueColors = [for (ix in 0...steps) hsla(f32(ix / (steps - 1)), 1.0, 0.5, 1.0)];
        final saturationStart = hsla(sliderColor.h, 0.0, sliderColor.l, 1.0);
        final saturationEnd = hsla(sliderColor.h, 1.0, sliderColor.l, 1.0);
        final lightnessColors = [for (ix in 0...steps) hsla(sliderColor.h, 1.0, f32(ix / (steps - 1)), 1.0)];
        final alphaStart = hsla(sliderColor.h, sliderColor.s, sliderColor.l, 0.0);
        final alphaEnd = hsla(sliderColor.h, sliderColor.s, sliderColor.l, 1.0);

        return vFlex()
            .gap2()
            .child(sliderRow(I18n.t('ColorPicker.Hue'), renderSliderTrack(hueColors, cx), new Slider(sliders.hue()), formatInteger(f32(sliderColor.h * 360.)), cx))
            .child(sliderRow(I18n.t('ColorPicker.Saturation'), renderSliderTrackGradient(saturationStart, saturationEnd, cx), new Slider(sliders.saturation()), formatInteger(f32(sliderColor.s * 100.)), cx))
            .child(sliderRow(I18n.t('ColorPicker.Lightness'), renderSliderTrack(lightnessColors, cx), new Slider(sliders.lightness()), formatInteger(f32(sliderColor.l * 100.)), cx))
            .child(sliderRow(I18n.t('ColorPicker.Alpha'), renderSliderTrackGradient(alphaStart, alphaEnd, cx), new Slider(sliders.alpha()), formatInteger(f32(sliderColor.a * 100.)), cx));
    }

    function renderSliderTrack(colors:Array<Hsla>, cx:App):IntoElement {
        return hFlex()
            .absolute()
            .left0()
            .right0()
            .h2_5()
            .overflowHidden()
            .children([for (color in colors) (div().flex1().hFull().bg(color) : IntoElement)]);
    }

    function renderSliderTrackGradient(start:Hsla, end:Hsla, cx:App):IntoElement {
        return div()
            .absolute()
            .left0()
            .right0()
            .h2_5()
            .overflowHidden()
            .bg(linearGradient(90., linearColorStop(start, 0.), linearColorStop(end, 1.)));
    }

    public function render(window:Window, cx:App):IntoElement {
        final s = state.read(cx);
        final value = s.value();
        final displayTitle = value != null ? displayHex(value) : ''; // deviation DEV-011

        final open = s.isOpen();
        final focusHandle = this.focusHandle(cx);
        final focused = focusHandle.isFocused(window);
        final openState = state;
        final popoverState = state;

        final picker = new glaze.kit.base.ColorPicker(id);
        if (field) picker.wFull();
        picker.refineStyle(pickerStyle)
            .open(open)
            .trackFocus(focusHandle);
        final a11yLabel = accessibilityLabelValue != null ? accessibilityLabelValue : labelValue;
        if (a11yLabel != null) picker.accessibilityLabel(a11yLabel);
        picker.onOpenChange((open, _, cx) -> {
            openState.update(cx, (state, cx) -> state.setOpen(open, cx));
        });

        final popover = new Popover('popover')
            .open(open)
            .w72()
            .onOpenChange((open, _, cx) -> {
                popoverState.update(cx, (state, cx) -> state.setOpen(open, cx));
            });
        if (field) {
            popover.triggerStyle(new StyleBuilder(new StyleRefinement()).wFull().style());
        }
        popover.trigger(new ColorPickerButton(
            'trigger',
            size,
            labelValue,
            value,
            displayTitle.length == 0 || field ? null : displayTitle,
            iconValue,
            false,
            field,
            focused,
            placeholderValue
        ));
        // The popover drops its content while closed, so building the
        // palette swatches or slider tracks then is wasted work.
        if (open) popover.child(renderColors(window, cx));
        picker.child(popover);
        return picker;
    }

}

/**
 * A color picker drawn as a framed field, like a `Select`.
 *
 * The field shows a swatch of the current color and its hex value; clicking
 * anywhere on it opens the same popover as `ColorPicker`. Use it in forms,
 * where a control is expected to share the height and frame of the inputs
 * around it; use `ColorPicker` for a compact swatch in a toolbar.
 */
class ColorSelect implements RenderOnce implements Styled implements Sizable {

    @:allow(tests)
    final picker:ColorPicker;

    /** Create a new color select with the given `ColorPickerState`. */
    public function new(state:Entity<ColorPickerState>) {
        picker = new ColorPicker(state);
        picker.id = ElementId.NamedInteger('color-select', state.entityId());
        picker.field = true;
    }

    /** Set the featured colors shown at the top of the palette. */
    public function featuredColors(colors:Array<Hsla>):ColorSelect {
        picker.featuredColors(colors);
        return this;
    }

    /**
     * Set the text shown while no color is selected.
     *
     * Default is the same placeholder as `Select`.
     */
    public function placeholder(placeholder:String):ColorSelect {
        picker.placeholderValue = placeholder;
        return this;
    }

    /** Set the name a screen reader announces. */
    public function accessibilityLabel(label:String):ColorSelect {
        picker.accessibilityLabel(label);
        return this;
    }

    public function withSize(size:IntoSize):ColorSelect {
        picker.withSize(size);
        return this;
    }

    public function setSize(size:Size):Void {
        picker.setSize(size);
    }

    public function focusHandle(cx:App):FocusHandle {
        return picker.focusHandle(cx);
    }

    public inline function style():StyleRefinement {
        return picker.style();
    }

    public function render(window:Window, cx:App):IntoElement {
        return picker.render(window, cx);
    }

}

/**
 * The trigger of a `ColorPicker` (crate private in Rust).
 */
@:noCompletion
class ColorPickerButton implements RenderOnce implements Selectable implements Sizable {

    final id:ElementId;
    var selectedValue:Bool;
    final icon:Null<Icon>;
    final value:Null<Hsla>;
    var size:Size;
    final label:Null<String>;
    final tooltip:Null<String>;
    final field:Bool;
    final focused:Bool;
    final placeholder:Null<String>;

    public function new(id:String, size:Size, label:Null<String>, value:Null<Hsla>, tooltip:Null<String>, icon:Null<Icon>, selected:Bool, field:Bool, focused:Bool, placeholder:Null<String>) {
        this.id = ElementId.Name(id);
        this.size = size;
        this.label = label;
        this.value = value;
        this.tooltip = tooltip;
        this.icon = icon;
        this.selectedValue = selected;
        this.field = field;
        this.focused = focused;
        this.placeholder = placeholder;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function withSize(size:IntoSize):ColorPickerButton {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    /**
     * The framed trigger of a `ColorSelect`: the swatch, the hex value and
     * a caret, laid out like a `Select` trigger.
     */
    function renderField(window:Window, cx:App):AnyElement {
        final theme = Theme.global(cx);
        final colors = @:privateAccess Input.inputStyleColors(false, cx);
        final outlineVisible = selectedValue || focused;

        final row = hFlex()
            .id(id)
            .wFull()
            .gap2()
            .bg(colors.background)
            .textColor(colors.foreground)
            .border1()
            .borderColor(theme.input)
            .rounded(theme.radius)
            .inputSize(size)
            .inputTextSize(size);
        if (outlineVisible) {
            row.borderColor(theme.ring).focusRingStyle(window, cx);
        }
        final swatch = div()
            .id('swatch')
            .flexShrink0()
            .border1()
            .borderColor(theme.input)
            .rounded(theme.radius / 2.);
        switch size {
            case XSmall: swatch.size3();
            case Small: swatch.size3p5();
            case Large: swatch.size5();
            case _: swatch.size4();
        }
        if (value != null) {
            swatch.bg(value).borderColor(value.darken(0.3));
        }
        final text = div()
            .flex1()
            .minW0()
            .overflowHidden()
            .whitespaceNowrap();
        if (value != null) {
            text.child(ColorPicker.displayHex(value)); // deviation DEV-011
        } else {
            text.textColor(theme.mutedForeground).child(placeholder != null ? placeholder : I18n.t('Select.placeholder'));
        }
        return row.child(swatch)
            .child(text)
            .child(new Caret(size).textColor(theme.mutedForeground))
            .intoAnyElement();
    }

    public function render(window:Window, cx:App):IntoElement {
        if (field) {
            return renderField(window, cx);
        }

        final theme = Theme.global(cx);
        final hasIcon = icon != null;
        final row = hFlex()
            .id(id)
            .gap2();
        if (icon != null) row.child(icon);
        if (!hasIcon) {
            final square = div()
                .id('square')
                .bg(theme.tokens.background.background)
                .border1()
                .borderColor(theme.input)
                .rounded(theme.radius)
                .overflowHidden()
                .sizeWith(size);
            if (value != null) {
                square.bg(value).borderColor(value.darken(0.3));
                if (selectedValue) square.border2();
            }
            if (tooltip != null) {
                final text = tooltip;
                square.managedTooltip((window, cx) -> new Tooltip(text).build(window, cx));
            }
            row.child(square);
        }
        if (label != null) row.child(label);
        return row;
    }

}
