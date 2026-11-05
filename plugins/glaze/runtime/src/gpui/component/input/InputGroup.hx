// Ported from gpui-kit 0.8.1: crates/component/src/input/group.rs, crates/component/src/input/group/button_element.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.AnyElement;
import gpui.App;
import gpui.ClickEvent;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.ViewElement;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.ComponentTraits;
import gpui.base.motion.Interpolators;
import gpui.base.motion.Motion;
import gpui.base.motion.Transition;
import gpui.base.motion.TransitionId;
import gpui.component.Icon;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.button.Button.Button;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.AbsoluteLengthTools;
using gpui.base.Observe;
using gpui.base.StyledExt;
using gpui.component.StyleSized;
using gpui.component.ThemeStyled;

/**
 * A shared frame around one text control and any number of explicitly aligned addons.
 *
 * The parts follow shadcn's input group: `InputGroup` is the frame, the
 * ordinary `Input` and `Textarea` are placed in it (Rust aliases
 * `InputGroupInput` and `InputGroupTextarea`), `InputGroupAddon` holds text,
 * icons and buttons on one of its four sides, `InputGroupButton` is a
 * `Button` with compact input-group presentation and `InputGroupText` is
 * muted text. The caller keeps the `InputState` or `TextareaState`; the
 * group owns only composition and the frame, the control keeps every `Input`
 * capability and renders without its own frame. `input` replaces the slot.
 */
class InputGroup implements RenderOnce implements Styled implements Sizable implements FocusableExt {

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    var control:Null<Input> = null;

    final addons:Array<InputGroupAddon> = [];

    var size:Size = Medium;

    var disabledValue:Bool = false;

    var readonlyValue:Bool = false;

    var invalidValue:Bool = false;

    var focusRingValue:Bool = true;

    var ariaLabelValue:Null<String> = null;

    /** The accessibility properties the group declares (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Group);

    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Set the single-line input or textarea, replacing the previous control
     * (an `Input`, or a `Textarea` through `InputGroupControl`).
     */
    public function input(input:InputGroupControl):InputGroup {
        control = input;
        return this;
    }

    /** Append an addon. Addons on the same side retain their insertion order. */
    public function addon(addon:InputGroupAddon):InputGroup {
        addons.push(addon);
        return this;
    }

    /** Prevent editing and interaction throughout this group. */
    public function disabled(disabled:Bool):InputGroup {
        disabledValue = disabled;
        return this;
    }

    /** Prevent editing while preserving selection, copying, and addon actions. */
    public function readonly(readonly:Bool):InputGroup {
        readonlyValue = readonly;
        return this;
    }

    /** Display the caller's validation result. This does not reject text edits. */
    public function invalid(invalid:Bool):InputGroup {
        invalidValue = invalid;
        return this;
    }

    /** Set a name for the group. Name its text control separately with `ariaLabel`. */
    public function ariaLabel(label:String):InputGroup {
        ariaLabelValue = label;
        return this;
    }

    public function withSize(size:IntoSize):InputGroup {
        this.size = size;
        return this;
    }

    public function focusRing(enabled:Bool):InputGroup {
        focusRingValue = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingValue = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingValue;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = control != null ? @:privateAccess control.getState() : null;
        final disabled = disabledValue || (control != null && @:privateAccess control.isDisabled());
        final focused = !disabled && state != null && state.hasSelectionFocus(window, cx);
        final multiline = state != null && state.presentation(cx).isMultiLine();
        function has(alignment:InputGroupAddonAlignment):Bool {
            for (addon in addons) if (addon.alignment == alignment) return true;
            return false;
        }
        final presentation = new GroupPresentation(size, disabled, readonlyValue, has(InlineStart), has(InlineEnd), has(BlockStart),
            has(BlockEnd));
        final inlineStart:Array<IntoElement> = [];
        final inlineEnd:Array<IntoElement> = [];
        final blockStart:Array<IntoElement> = [];
        final blockEnd:Array<IntoElement> = [];
        for (addon in addons) {
            final target = switch addon.alignment {
                case InlineStart: inlineStart;
                case InlineEnd: inlineEnd;
                case BlockStart: blockStart;
                case BlockEnd: blockEnd;
            }
            target.push(addon.renderInGroup(presentation, window, cx));
        }
        final controlElement:Null<IntoElement> = control != null ? renderControl(control, presentation, multiline) : null;
        final theme = Theme.global(cx);
        final appearance = new GroupAppearance(theme, focused, disabled, invalidValue);
        final radius = theme.radius;
        final foreground = theme.foreground;
        final showRing = theme.focusRing && focusRingValue;
        final motion = theme.motionTokens();
        final duration = motion.durationFast;
        final easing = motion.easingMove;
        // The border and background colors transition; the ring outside them
        // changes immediately, like the standalone input's. A color cannot
        // overshoot its target, so the theme curve is clamped.
        final colors = window.withId(id, window -> {
            function transition():Transition {
                return new Transition(duration).ease(progress -> {
                    final sampled = easing.sample(progress);
                    return sampled < 0. ? 0. : (sampled > 1. ? 1. : sampled);
                });
            }
            return {
                border: Motion.transitionOf(("border-color" : TransitionId), appearance.border, Interpolators.HSLA, transition(), window, cx),
                background: Motion.transitionOf(("background-color" : TransitionId), appearance.background, Interpolators.HSLA, transition(), window, cx)
            };
        });
        final border = colors.border;
        final background = colors.background;
        // Rust `.role(Role::Group)` and `.aria_label(..)` on the root: the
        // port's `Div` has no accessibility node, the group keeps them in `a11y`.
        if (ariaLabelValue != null) a11y.label = ariaLabelValue;
        final root = vFlex().id(id).testSupport();
        root.relative().wFull().minW0();
        if (!multiline && !presentation.blockStart && !presentation.blockEnd) root.inputH(size);
        root.rounded(radius)
            .border1()
            .borderColor(border)
            .bg(background)
            .textColor(foreground)
            .inputTextSize(size)
            .shadowNone();
        if (disabled) {
            // Custom addon content must not bypass the group's disabled policy.
            root.captureAnyMouseDown((_, _, cx) -> cx.stopPropagation()).captureKeyDown((event, _, cx) -> {
                if (event.keystroke.key != "tab") {
                    cx.stopPropagation();
                }
            });
        }
        root.refineStyle(groupStyle);
        if (disabled) root.bg(background).opacity(0.5);
        if (appearance.ring != null) root.borderColor(border);
        if (appearance.ring != null && showRing) root.focusRing(window, appearance.ring);
        if (state != null && !disabled) {
            root.onMouseDown(Left, (_, window, cx) -> {
                // Native buttons prevent the default mouse-down focus action.
                // Respect that before focusing the editor from an addon or inset.
                if (!window.defaultPrevented()) {
                    state.focus(window, cx);
                    window.preventDefault();
                }
            });
        }
        root.children(blockStart);
        final row = hFlex().wFull().minW0().itemsCenter();
        if (!multiline && !presentation.blockStart && !presentation.blockEnd) row.hFull();
        row.children(inlineStart);
        if (controlElement != null) row.child(controlElement);
        row.children(inlineEnd);
        root.child(row);
        root.children(blockEnd);
        return root;
    }

    /**
     * The control rendered without its own frame: the group draws the border,
     * background and ring. An inline addon takes over part of the control's
     * horizontal inset, as in shadcn; the caller's own style still wins.
     */
    static function renderControl(input:Input, presentation:GroupPresentation, multiline:Bool):IntoElement {
        final style = @:privateAccess input.takeStyle();
        input.withSize(presentation.size)
            .appearance(false)
            .focusBordered(false)
            .disabled(presentation.disabled)
            .readonly(presentation.readonly);
        input.flex1().minW0();
        if (multiline) input.minH16();
        if (!multiline) {
            if (presentation.inlineStart) input.pl2();
            if (presentation.inlineEnd) input.pr2();
        }
        return input.refineStyle(style);
    }

}

/**
 * Rust `impl Into<InputGroupControl>`: an `Input`, or a `Textarea` (as the
 * `Input` it renders).
 */
abstract InputGroupControl(Input) from Input to Input {

    @:from static inline function fromTextarea(textarea:Textarea):InputGroupControl {
        return cast @:privateAccess textarea.intoInput();
    }

}

/**
 * What the addons and the control need to know about the group they sit in.
 */
@:allow(gpui.component.input)
class GroupPresentation {

    final size:Size;
    final disabled:Bool;
    final readonly:Bool;
    final inlineStart:Bool;
    final inlineEnd:Bool;
    final blockStart:Bool;
    final blockEnd:Bool;

    function new(size:Size, disabled:Bool, readonly:Bool, inlineStart:Bool, inlineEnd:Bool, blockStart:Bool, blockEnd:Bool) {
        this.size = size;
        this.disabled = disabled;
        this.readonly = readonly;
        this.inlineStart = inlineStart;
        this.inlineEnd = inlineEnd;
        this.blockStart = blockStart;
        this.blockEnd = blockEnd;
    }

    /** Rust `GroupPresentation::default()`. */
    static function defaultValue():GroupPresentation {
        return new GroupPresentation(Medium, false, false, false, false, false, false);
    }

}

@:allow(gpui.component.input)
class GroupAppearance {

    final background:Hsla;
    final border:Hsla;
    final ring:Null<Hsla>;

    function new(theme:Theme, focused:Bool, disabled:Bool, invalid:Bool) {
        background = if (disabled) {
            theme.input.opacity(theme.isDark() ? 0.8 : 0.5);
        } else if (theme.isDark()) {
            theme.input.opacity(0.3);
        } else {
            theme.transparent;
        }
        // Validation remains visible when editing is disabled. Focus alone never
        // reactivates a disabled control, and never replaces its validation color.
        if (invalid) {
            border = theme.danger;
            ring = theme.danger.opacity(theme.isDark() ? 0.4 : 0.2);
        } else if (focused && !disabled) {
            border = theme.ring;
            ring = theme.ring.opacity(0.5);
        } else {
            border = theme.input;
            ring = null;
        }
    }

}

/**
 * The logical side of an addon relative to the text control.
 */
enum abstract InputGroupAddonAlignment(Int) {
    var InlineStart = 0;
    var InlineEnd = 1;
    var BlockStart = 2;
    var BlockEnd = 3;
}

/**
 * Text, icons, buttons, or custom content on one side of an input group.
 *
 * Children retain their insertion order. Direct `InputGroupButton` children
 * inherit the group's disabled state. Custom children retain their own semantics.
 */
class InputGroupAddon implements RenderOnce implements Styled implements ParentElement {

    final id:ElementId;

    @:allow(gpui.component.input)
    var alignment:InputGroupAddonAlignment = InlineStart;

    final addonStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public function align(alignment:InputGroupAddonAlignment):InputGroupAddon {
        this.alignment = alignment;
        return this;
    }

    public inline function style():StyleRefinement {
        return addonStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):InputGroupAddon {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):InputGroupAddon {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    @:allow(gpui.component.input)
    function renderInGroup(presentation:GroupPresentation, window:Window, cx:App):IntoElement {
        for (child in childElements) {
            final button = InputGroupButton.fromElement(child);
            if (button != null) {
                button.disable(presentation.disabled);
            }
        }
        final borderTop = addonStyle.borderWidthTop != null && addonStyle.borderWidthTop.toPixels(window.remSize()) > 0.;
        final borderBottom = addonStyle.borderWidthBottom != null && addonStyle.borderWidthBottom.toPixels(window.remSize()) > 0.;
        // An inline addon keeps the same clearance from the frame's edge that
        // a compact button has from its top and bottom; block addons share the
        // control's horizontal inset so a leading icon or a trailing button
        // lines up with the text.
        final blockPx = presentation.size.inputPx();
        final element = hFlex()
            .id(id)
            .testSupport()
            .flexNone()
            .gap2()
            .py1p5();
        switch presentation.size {
            case XSmall | Small: element.py0();
            case _:
        }
        element.justifyCenter()
            .fontMedium()
            .inputTextSize(presentation.size)
            .textColor(Theme.global(cx).mutedForeground)
            .cursorText();
        switch alignment {
            case InlineStart: element.pl1p5();
            case InlineEnd: element.pr1p5();
            case BlockStart:
                element.wFull().justifyStart().px(blockPx).pt2();
                if (borderBottom) element.pb2();
            case BlockEnd:
                element.wFull().justifyStart().px(blockPx).pb2();
                if (borderTop) element.pt2();
        }
        element.refineStyle(addonStyle);
        for (child in childElements) element.child(addonChild(child));
        return element;
    }

    public function render(window:Window, cx:App):IntoElement {
        return renderInGroup(GroupPresentation.defaultValue(), window, cx);
    }

    /**
     * An icon without an explicit size follows the addon's one-rem default;
     * an explicit size stays with the icon.
     */
    @:allow(gpui.component.input)
    static function addonChild(child:AnyElement):IntoElement {
        if (componentOf(child) is Icon) {
            return div().flexNone().textBase().child(child);
        }
        return child;
    }

    /** The component a child renders, if it is one (Rust downcasts the element). */
    @:allow(gpui.component.input)
    static function componentOf(child:AnyElement):Null<RenderOnce> {
        final element = child.element;
        if (element is ViewElement) {
            return @:privateAccess (cast element : ViewElement).component;
        }
        return null;
    }

}

/**
 * A `Button` with compact input-group presentation and disabled inheritance.
 *
 * Ghost and extra-small by default, as in shadcn; `xsmall` and `small` are
 * the two compact sizes, and a button with only an icon is square at either.
 *
 * Rust gives it its own element (`InputGroupButtonElement`) so that an addon
 * can find its direct button children and pass the group's disabled state
 * to them; here the addon finds the component and sets `inheritedDisabled`.
 */
class InputGroupButton implements RenderOnce implements Styled implements Sizable implements Disableable implements Selectable implements ParentElement {

    final button:Button;

    var size:Size = XSmall;

    final buttonStyle:StyleRefinement = new StyleRefinement();

    /** Rust `InputGroupButtonElement::disabled`: the state inherited from the group. */
    var inheritedDisabled:Bool = false;

    public function new(id:ElementIdArg) {
        button = new Button(id).ghost();
    }

    /** The direct `InputGroupButton` child of an addon (Rust `InputGroupButtonElement::from_element`). */
    @:allow(gpui.component.input)
    static function fromElement(child:AnyElement):Null<InputGroupButton> {
        final component = InputGroupAddon.componentOf(child);
        return component is InputGroupButton ? cast component : null;
    }

    @:allow(gpui.component.input)
    function disable(disabled:Bool):Void {
        inheritedDisabled = inheritedDisabled || disabled;
    }

    public function label(label:String):InputGroupButton {
        button.label(label);
        return this;
    }

    public function icon(icon:IntoIcon):InputGroupButton {
        button.icon((icon : Icon));
        return this;
    }

    public function accessibilityLabel(label:String):InputGroupButton {
        button.accessibilityLabel(label);
        return this;
    }

    public function tooltip(tooltip:String):InputGroupButton {
        button.tooltip(tooltip);
        return this;
    }

    public function tooltipShowDelay(delay:Float):InputGroupButton {
        button.tooltipShowDelay(delay);
        return this;
    }

    public function loading(loading:Bool):InputGroupButton {
        button.loading(loading);
        return this;
    }

    public function loadingIcon(icon:IntoIcon):InputGroupButton {
        button.loadingIcon(icon);
        return this;
    }

    public function outline():InputGroupButton {
        button.outline();
        return this;
    }

    public function tabIndex(tabIndex:Int):InputGroupButton {
        button.tabIndex(tabIndex);
        return this;
    }

    public function dropdownCaret(dropdownCaret:Bool):InputGroupButton {
        button.dropdownCaret(dropdownCaret);
        return this;
    }

    public function onClick(handler:(ClickEvent, Window, App) -> Void):InputGroupButton {
        button.onClick(handler);
        return this;
    }

    public function withVariant(variant:gpui.component.button.Button.ButtonVariant):InputGroupButton {
        button.withVariant(variant);
        return this;
    }

    /** Rust `ButtonVariants::primary`. */
    public function primary():InputGroupButton {
        return withVariant(Primary);
    }

    /** Rust `ButtonVariants::ghost`. */
    public function ghost():InputGroupButton {
        return withVariant(Ghost);
    }

    public function disabled(disabled:Bool):InputGroupButton {
        button.disabled(disabled);
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        button.disabled(disabled);
    }

    public function selected(selected:Bool):InputGroupButton {
        button.selected(selected);
        return this;
    }

    public function setSelected(selected:Bool):Void {
        button.selected(selected);
    }

    public function isSelected():Bool {
        return button.isSelected();
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function withSize(size:IntoSize):InputGroupButton {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return buttonStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        button.extend(elements);
    }

    public function child(child:IntoElement):InputGroupButton {
        if (child != null) button.child(child);
        return this;
    }

    function renderInGroup(disabled:Bool, window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final button = this.button;
        final disabled = disabled || @:privateAccess button.isDisabled();
        final selected = button.isSelected();
        final iconOnly = @:privateAccess button.isIconOnly();
        final ghost = @:privateAccess button.variant().match(Ghost) && !@:privateAccess button.isOutline();
        final muted = theme.muted;
        final hover = muted.opacity(theme.isDark() ? 0.5 : 1.);
        final compact = size == XSmall || size == Small;
        final iconSize:Size = switch size {
            case XSmall: Small;
            case Small: Medium;
            case other: other;
        }
        final content = div().textSm().lineHeight(rems(1.25));
        switch size {
            case XSmall: content.gap1();
            case _: content.gap1p5();
        }
        final contentStyle = content.style().clone();
        if (disabled) button.disabled(true);
        if (compact) {
            @:privateAccess button.withSize(Medium).contentStyle(contentStyle, iconSize);
        } else {
            button.withSize(size);
        }
        if (ghost) {
            button.custom(new gpui.component.button.Button.ButtonCustomVariant(cx)
                .color(theme.transparent)
                .foreground(theme.foreground)
                .hover(hover)
                .active(selected ? muted : hover))
                .textColor(theme.foreground);
            if (disabled) button.opacity(0.5);
        }
        if (disabled) button.focusRing(false);
        button.textSm().fontMedium().border1().shadowNone();
        switch [size, iconOnly] {
            case [XSmall, false]: button.h6().px2().rounded(theme.radiusTokens().sm);
            case [XSmall, true]: button.size6().p0().rounded(theme.radiusTokens().sm);
            case [Small, false]: button.h8().px2p5().rounded(theme.radius);
            case [Small, true]: button.size8().p0().rounded(theme.radius);
            case _:
        }
        button.refineStyle(buttonStyle);
        return button.render(window, cx);
    }

    public function render(window:Window, cx:App):IntoElement {
        return renderInGroup(inheritedDisabled, window, cx);
    }

}

/**
 * Muted helper text, optionally combined with icons, inside an input group.
 */
class InputGroupText implements RenderOnce implements Styled implements ParentElement {

    final textStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return textStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):InputGroupText {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):InputGroupText {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final element = hFlex()
            .gap2()
            .textSm()
            .textColor(Theme.global(cx).mutedForeground)
            .refineStyle(textStyle);
        for (child in childElements) element.child(InputGroupAddon.addonChild(child));
        return element;
    }

}
