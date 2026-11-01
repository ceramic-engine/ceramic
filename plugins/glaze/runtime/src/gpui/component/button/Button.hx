// Ported from gpui-kit 0.8.1: crates/component/src/button/button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-003 (icon button with a dropdown caret). See DEVIATIONS.md.
package gpui.component.button;

import gpui.AnyElement;
import gpui.App;
import gpui.Background;
import gpui.ClickEvent;
import gpui.Corners;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.Hsla;
import gpui.IntoBackground;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.ComponentTraits;
import gpui.base.GlobalState;
import gpui.component.Icon;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.ThemeStyled.FocusLine;
import gpui.component.button.ButtonIcon;
import gpui.component.select.Caret;
import gpui.component.theme.Theme;
import gpui.component.tooltip.Tooltip.ManagedTooltip;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.A11y.RoleOverrideTools;
using gpui.base.StyledExt;
using gpui.component.StyleSized;
using gpui.component.ThemeStyled;
using gpui.component.theme.Colorize;

/**
 * The border radius of a Button (default `Medium`).
 */
enum ButtonRounded {
    None;
    Small;
    Medium;
    Large;
    Size(px:Pixels);
}

/**
 * Rust `impl Into<ButtonRounded>`: a `ButtonRounded`, or pixels for `Size`.
 */
abstract IntoButtonRounded(ButtonRounded) from ButtonRounded to ButtonRounded {

    @:from static inline function fromPixels(value:Pixels):IntoButtonRounded {
        return Size(value);
    }

    @:from static inline function fromFloat(value:Float):IntoButtonRounded {
        return Size(value);
    }

}

/**
 * The colors of a `ButtonVariant.Custom` button.
 */
class ButtonCustomVariant {

    @:allow(gpui.component.button)
    var colorValue:Hsla;

    @:allow(gpui.component.button)
    var foregroundValue:Hsla;

    @:allow(gpui.component.button)
    var shadowValue:Bool;

    @:allow(gpui.component.button)
    var hoverValue:Hsla;

    @:allow(gpui.component.button)
    var activeValue:Hsla;

    public function new(cx:App) {
        final theme = Theme.global(cx);
        colorValue = theme.transparent;
        foregroundValue = theme.foreground;
        hoverValue = theme.transparent;
        activeValue = theme.transparent;
        shadowValue = false;
    }

    /**
     * Set background color, default is transparent.
     */
    public function color(color:Hsla):ButtonCustomVariant {
        colorValue = color;
        return this;
    }

    /**
     * Set foreground color, default is theme foreground.
     */
    public function foreground(color:Hsla):ButtonCustomVariant {
        foregroundValue = color;
        return this;
    }

    /**
     * Set hover background color, default is transparent.
     */
    public function hover(color:Hsla):ButtonCustomVariant {
        hoverValue = color;
        return this;
    }

    /**
     * Set active background color, default is transparent.
     */
    public function active(color:Hsla):ButtonCustomVariant {
        activeValue = color;
        return this;
    }

    /**
     * Set shadow, default is false.
     */
    public function shadow(shadow:Bool):ButtonCustomVariant {
        shadowValue = shadow;
        return this;
    }

}

/**
 * The variant of the Button (default `Default`). Methods are in
 * `ButtonVariantTools`.
 */
@:using(gpui.component.button.Button.ButtonVariantTools)
enum ButtonVariant {
    Default;
    Primary;
    Secondary;
    Danger;
    Info;
    Success;
    Warning;
    Ghost;
    Link;
    Text;
    Custom(style:ButtonCustomVariant);
}

/**
 * The colors of one state of a button variant.
 */
@:allow(gpui.component.button, tests)
class ButtonVariantStyle {

    public final bg:Background;

    public final border:Hsla;

    public final fg:Hsla;

    public final underline:Bool;

    public final shadow:Bool;

    public function new(bg:Background, border:Hsla, fg:Hsla, underline:Bool, shadow:Bool) {
        this.bg = bg;
        this.border = border;
        this.fg = fg;
        this.underline = underline;
        this.shadow = shadow;
    }

}

private enum abstract ButtonStyleState(Int) {
    var Normal;
    var Hovered;
    var Active;
}

/**
 * Methods of `ButtonVariant`: the checks, and the colors of each state.
 */
class ButtonVariantTools {

    public static inline function isLink(self:ButtonVariant):Bool {
        return self.match(Link);
    }

    public static inline function isText(self:ButtonVariant):Bool {
        return self.match(Text);
    }

    public static inline function isGhost(self:ButtonVariant):Bool {
        return self.match(Ghost);
    }

    @:allow(gpui.component, tests)
    static inline function noPadding(self:ButtonVariant):Bool {
        return isLink(self) || isText(self);
    }

    @:allow(gpui.component, tests)
    static inline function isDefault(self:ButtonVariant):Bool {
        return self.match(Default);
    }

    /**
     * Structural equality (Rust `PartialEq`, custom variants compare their colors).
     */
    public static function equals(self:ButtonVariant, other:ButtonVariant):Bool {
        return switch [self, other] {
            case [Custom(a), Custom(b)]:
                a.colorValue.equals(b.colorValue) && a.foregroundValue.equals(b.foregroundValue) && a.shadowValue == b.shadowValue
                    && a.hoverValue.equals(b.hoverValue) && a.activeValue.equals(b.activeValue);
            case [Custom(_), _] | [_, Custom(_)]: false;
            case _: Type.enumIndex(self) == Type.enumIndex(other);
        }
    }

    static function outlineBackground(self:ButtonVariant, state:ButtonStyleState, cx:App):IntoBackground {
        final theme = Theme.global(cx);
        final tokens = theme.tokens;
        return switch [self, state] {
            case [Default, Normal]: theme.inputBackground();
            case [Default, Hovered]: theme.input.mixOklab(theme.transparent, 0.5);
            case [Default, Active]: theme.input.mixOklab(theme.transparent, 0.7);
            case [Primary, Normal]: tokens.primary.background.opacity(0.1);
            case [Primary, Hovered]: tokens.primaryHover.background.opacity(0.2);
            case [Primary, Active]: tokens.primaryActive.background.opacity(0.4);
            case [Secondary, Normal]: tokens.secondary.background.opacity(0.1);
            case [Secondary, Hovered]: tokens.secondaryHover.background.opacity(0.2);
            case [Secondary, Active]: tokens.secondaryActive.background.opacity(0.4);
            case [Danger, Normal]: tokens.danger.background.opacity(0.1);
            case [Danger, Hovered]: tokens.dangerHover.background.opacity(0.2);
            case [Danger, Active]: tokens.dangerActive.background.opacity(0.4);
            case [Warning, Normal]: tokens.warning.background.opacity(0.1);
            case [Warning, Hovered]: tokens.warningHover.background.opacity(0.2);
            case [Warning, Active]: tokens.warningActive.background.opacity(0.4);
            case [Success, Normal]: tokens.success.background.opacity(0.1);
            case [Success, Hovered]: tokens.successHover.background.opacity(0.2);
            case [Success, Active]: tokens.successActive.background.opacity(0.4);
            case [Info, Normal]: tokens.info.background.opacity(0.1);
            case [Info, Hovered]: tokens.infoHover.background.opacity(0.2);
            case [Info, Active]: tokens.infoActive.background.opacity(0.4);
            case [Ghost | Link | Text, _]: theme.transparent;
            case [Custom(colors), _]: colors.colorValue.mixOklab(theme.transparent, 0.2);
        }
    }

    static function bgColor(self:ButtonVariant, outline:Bool, cx:App):IntoBackground {
        if (outline) {
            return outlineBackground(self, Normal, cx);
        }
        final theme = Theme.global(cx);
        final tokens = theme.tokens;
        return switch self {
            case Default: tokens.button.background;
            case Primary: tokens.buttonPrimary.background;
            case Secondary: tokens.buttonSecondary.background;
            case Danger: tokens.buttonDanger.background;
            case Warning: tokens.buttonWarning.background;
            case Success: tokens.buttonSuccess.background;
            case Info: tokens.buttonInfo.background;
            case Ghost | Link | Text: theme.transparent;
            case Custom(colors): colors.colorValue.mixOklab(theme.transparent, 0.2);
        }
    }

    static function textColor(self:ButtonVariant, outline:Bool, cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch self {
            case Default: theme.buttonForeground;
            case Primary: outline ? theme.primary : theme.buttonPrimaryForeground;
            case Secondary: outline ? theme.secondaryForeground : theme.buttonSecondaryForeground;
            case Ghost: theme.secondaryForeground;
            case Danger: outline ? theme.danger : theme.buttonDangerForeground;
            case Warning: outline ? theme.warning : theme.buttonWarningForeground;
            case Success: outline ? theme.success : theme.buttonSuccessForeground;
            case Info: outline ? theme.info : theme.buttonInfoForeground;
            case Link: theme.link;
            case Text: theme.foreground.opacity(0.9);
            case Custom(colors): colors.foregroundValue;
        }
    }

    static function borderColor(self:ButtonVariant, outline:Bool, cx:App):Hsla {
        final theme = Theme.global(cx);
        return switch self {
            case Default: theme.input;
            case Secondary: theme.border;
            case Primary: theme.primary;
            case Danger: outline ? theme.danger.mixOklab(transparentWhite(), 0.4) : theme.buttonDanger;
            case Info: outline ? theme.info.mixOklab(transparentWhite(), 0.4) : theme.buttonInfo;
            case Warning: outline ? theme.warning.mixOklab(transparentWhite(), 0.4) : theme.buttonWarning;
            case Success: outline ? theme.success.mixOklab(transparentWhite(), 0.4) : theme.buttonSuccess;
            case Ghost | Link | Text: theme.transparent;
            case Custom(colors): outline ? colors.colorValue.mixOklab(transparentWhite(), 0.4) : colors.colorValue;
        }
    }

    static function underline(self:ButtonVariant, cx:App):Bool {
        return self.match(Link);
    }

    static function shadow(self:ButtonVariant, outline:Bool, cx:App):Bool {
        return switch self {
            case Custom(c): c.shadowValue;
            case _: false;
        }
    }

    @:allow(gpui.component, tests)
    static function normal(self:ButtonVariant, outline:Bool, cx:App):ButtonVariantStyle {
        final bg = bgColor(self, outline, cx);
        final border = borderColor(self, outline, cx);
        final fg = textColor(self, outline, cx);
        return new ButtonVariantStyle(bg, border, fg, underline(self, cx), shadow(self, outline, cx));
    }

    @:allow(gpui.component, tests)
    static function hovered(self:ButtonVariant, outline:Bool, cx:App):ButtonVariantStyle {
        final theme = Theme.global(cx);
        final tokens = theme.tokens;
        final bg:IntoBackground = switch self {
            case Default: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonHover.background;
            case Primary: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonPrimaryHover.background;
            case Secondary: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonSecondaryHover.background;
            case Danger: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonDangerHover.background;
            case Warning: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonWarningHover.background;
            case Success: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonSuccessHover.background;
            case Info: outline ? outlineBackground(self, Hovered, cx) : tokens.buttonInfoHover.background;
            case Custom(colors): colors.hoverValue;
            case Ghost:
                final accent:Background = tokens.accent.background;
                theme.mode.isDark() ? accent.opacity(0.5) : accent;
            case Link: theme.transparent;
            case Text: theme.transparent;
        }
        final border = borderColor(self, outline, cx);
        final fg = switch self {
            case Link: theme.linkHover;
            case Text: theme.foreground;
            case Ghost: theme.accentForeground;
            case _: textColor(self, outline, cx);
        }
        return new ButtonVariantStyle(bg, border, fg, underline(self, cx), shadow(self, outline, cx));
    }

    @:allow(gpui.component, tests)
    static function active(self:ButtonVariant, outline:Bool, cx:App):ButtonVariantStyle {
        final theme = Theme.global(cx);
        final tokens = theme.tokens;
        final bg:IntoBackground = switch self {
            case Default: outline ? outlineBackground(self, Active, cx) : tokens.buttonActive.background;
            case Primary: outline ? outlineBackground(self, Active, cx) : tokens.buttonPrimaryActive.background;
            case Secondary: outline ? outlineBackground(self, Active, cx) : tokens.buttonSecondaryActive.background;
            case Ghost: tokens.buttonActive.background;
            case Danger: outline ? outlineBackground(self, Active, cx) : tokens.buttonDangerActive.background;
            case Warning: outline ? outlineBackground(self, Active, cx) : tokens.buttonWarningActive.background;
            case Success: outline ? outlineBackground(self, Active, cx) : tokens.buttonSuccessActive.background;
            case Info: outline ? outlineBackground(self, Active, cx) : tokens.buttonInfoActive.background;
            case Custom(colors): colors.activeValue;
            case Link: theme.transparent;
            case Text: theme.transparent;
        }
        final border = borderColor(self, outline, cx);
        final fg = switch self {
            case Link: theme.linkActive;
            case Text: theme.foreground.opacity(0.7);
            case _: textColor(self, outline, cx);
        }
        return new ButtonVariantStyle(bg, border, fg, underline(self, cx), shadow(self, outline, cx));
    }

    @:allow(gpui.component, tests)
    static function selected(self:ButtonVariant, outline:Bool, cx:App):ButtonVariantStyle {
        if (outline) {
            final activeStyle = active(self, outline, cx);
            return new ButtonVariantStyle(activeStyle.bg, activeStyle.border, textColor(self, outline, cx), activeStyle.underline, activeStyle.shadow);
        }

        final theme = Theme.global(cx);
        final tokens = theme.tokens;
        final bg:IntoBackground = switch self {
            case Default: tokens.buttonActive.background;
            case Primary: tokens.buttonPrimaryActive.background;
            case Secondary: tokens.buttonSecondaryActive.background;
            case Ghost: tokens.secondaryActive.background;
            case Danger: tokens.buttonDangerActive.background;
            case Warning: tokens.buttonWarningActive.background;
            case Success: tokens.buttonSuccessActive.background;
            case Info: tokens.buttonInfoActive.background;
            case Link: theme.transparent;
            case Text: theme.transparent;
            case Custom(colors): colors.activeValue;
        }
        final border = borderColor(self, outline, cx);
        final fg = switch self {
            case Link: theme.linkActive;
            case Text: theme.foreground.opacity(0.7);
            case _: textColor(self, false, cx);
        }
        return new ButtonVariantStyle(bg, border, fg, underline(self, cx), shadow(self, outline, cx));
    }

    @:allow(gpui.component, tests)
    static function disabled(self:ButtonVariant, outline:Bool, cx:App):ButtonVariantStyle {
        final theme = Theme.global(cx);
        final tokens = theme.tokens;
        var bg:IntoBackground = switch self {
            case Default | Link | Ghost | Text: theme.transparent;
            case Primary: tokens.buttonPrimary.background.opacity(0.15);
            case Danger: tokens.buttonDanger.background.opacity(0.15);
            case Warning: tokens.buttonWarning.background.opacity(0.15);
            case Success: tokens.buttonSuccess.background.opacity(0.15);
            case Info: tokens.buttonInfo.background.opacity(0.15);
            // DEV-005: 1.5 had no effect (opacity clamps to 1); 0.5 like the
            // other neutral variants (Default, outline)
            case Secondary: tokens.buttonSecondary.background.opacity(0.5);
            case Custom(style): style.colorValue.opacity(0.15);
        }
        final fg = theme.mutedForeground.opacity(0.5);
        var border:Hsla;
        if (outline) {
            bg = (outlineBackground(self, Normal, cx):Background).opacity(0.5);
            border = borderColor(self, true, cx).opacity(0.5);
        } else if (self.match(Default)) {
            bg = theme.inputBackground().opacity(0.5);
            border = theme.input.opacity(0.5);
        } else {
            border = switch self {
                case Primary: theme.buttonPrimary.opacity(0.15);
                case Secondary: theme.buttonSecondary.opacity(0.5); // DEV-005
                case Danger: theme.buttonDanger.opacity(0.15);
                case Warning: theme.buttonWarning.opacity(0.15);
                case Success: theme.buttonSuccess.opacity(0.15);
                case Info: theme.buttonInfo.opacity(0.15);
                case Custom(style): style.colorValue.opacity(0.15);
                case Default | Link | Ghost | Text: theme.transparent;
            }
        }
        return new ButtonVariantStyle(bg, border, fg, underline(self, cx), false);
    }

}

/**
 * A Button element.
 *
 * Builders follow the Rust traits: `ButtonVariants` (`primary()`,
 * `ghost()`, `link()`...), `Sizable`, `Selectable`, `Disableable` and
 * `FocusableExt`. `Styled` methods style the root (they go to the Base
 * button's style), interactive ones go to `base.base`.
 *
 * Tooltips (`tooltip`, `tooltipWithAction`, `tooltipPlacement`,
 * `tooltipShowDelay`) are managed tooltips (`gpui.component.tooltip`).
 */
class Button implements RenderOnce implements Styled implements ParentElement implements Sizable implements Selectable implements Disableable implements FocusableExt {

    /** Ink of the focus line a filled button draws inside its fill. */
    static inline final FOCUS_LINE_OPACITY:Float = 0.6;

    final id:ElementId;

    @:allow(gpui.component, tests)
    var base:gpui.base.Button;

    @:allow(gpui.component, tests)
    var iconValue:Null<ButtonIcon> = null;

    @:allow(gpui.component, tests)
    var labelValue:Null<String> = null;

    /** The announced name, when the visible content is not it. */
    @:allow(gpui.component, tests)
    var accessibilityLabelValue:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    @:allow(gpui.component, tests)
    var disabledValue:Bool = false;

    @:allow(gpui.component, tests)
    var selectedValue:Bool = false;

    /**
     * Held by the popover, menu or dropdown this button triggers, for as long
     * as it is open. Kept apart from `selected` because the two states mean
     * different things, even though they paint the same today.
     */
    var openValue:Bool = false;

    @:allow(gpui.component, tests)
    var toggledValue:Null<Bool> = null;

    var roleValue:RoleOverride = Implicit;

    @:allow(gpui.component, tests)
    var variantValue:ButtonVariant = Default;

    @:allow(gpui.component, tests)
    var roundedValue:ButtonRounded = Medium;

    @:allow(gpui.component, tests)
    var outlineValue:Bool = false;

    var borderCorners:Array<Bool> = [true, true, true, true];

    var borderEdges:Array<Bool> = [true, true, true, true];

    @:allow(gpui.component, tests)
    var dropdownCaretValue:Bool = false;

    var hoverGroupValue:Null<String> = null;

    var hoverGroupHeldValue:Bool = false;

    @:allow(gpui.component, tests)
    var sizeValue:Size = Medium;

    var contentStyleValue:StyleRefinement = new StyleRefinement();

    var iconSize:Null<Size> = null;

    @:allow(gpui.component, tests)
    var compactValue:Bool = false;

    @:allow(gpui.component, tests)
    var tooltipValue:Null<String> = null;

    /** The action whose key binding the tooltip shows (Rust: the second half of `tooltip`). */
    var tooltipActionValue:Null<{action:gpui.Action, context:Null<String>}> = null;

    var tooltipPlacementValue:Null<gpui.base.Geometry.Placement> = null;

    var tooltipBuilder:Null<(Window, App) -> gpui.AnyView> = null;

    @:allow(gpui.component, tests)
    var tooltipShowDelayValue:Null<Float> = null;

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    var onHoverHandler:Null<(Bool, Window, App) -> Void> = null;

    @:allow(gpui.component, tests)
    var loadingValue:Bool = false;

    var loadingIconValue:Null<Icon> = null;

    var focusRingEnabled:Bool = true;

    @:allow(gpui.component, tests)
    var focusHandleValue:Null<FocusHandle> = null;

    @:allow(gpui.component, tests)
    var tabIndexValue:Int = 0;

    @:allow(gpui.component, tests)
    var tabStopValue:Bool = true;

    public function new(id:ElementIdArg) {
        this.id = id;
        this.base = new gpui.base.Button(id);
    }

    /**
     * Uses a behavior primitive supplied by a compound Base control.
     */
    @:allow(gpui.component, tests)
    function withBase(base:gpui.base.Button):Button {
        this.base = base;
        return this;
    }

    @:allow(gpui.component, tests)
    function variant():ButtonVariant {
        return variantValue;
    }

    @:allow(gpui.component, tests)
    function isCompact():Bool {
        return compactValue;
    }

    /**
     * Presentation supplied by a styled compound control. Standalone buttons
     * retain their normal size-derived content style.
     */
    @:allow(gpui.component, tests)
    function contentStyle(style:StyleRefinement, iconSize:Size):Button {
        contentStyleValue = style;
        this.iconSize = iconSize;
        return this;
    }

    @:allow(gpui.component, tests)
    function buttonSize():Size {
        return sizeValue;
    }

    @:allow(gpui.component, tests)
    function isDisabled():Bool {
        return disabledValue;
    }

    @:allow(gpui.component, tests)
    function isOutline():Bool {
        return outlineValue;
    }

    /**
     * Whether the button shows only its icon.
     */
    @:allow(gpui.component, tests)
    function isIconOnly():Bool {
        return iconValue != null && labelValue == null && childElements.length == 0;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Button {
        childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Button {
        for (child in children) childElements.push(child);
        return this;
    }

    public function role(role:RoleOverride):Button {
        roleValue = role;
        return this;
    }

    /**
     * Set the outline style of the Button.
     */
    public function outline():Button {
        outlineValue = true;
        return this;
    }

    /**
     * Set the border radius of the Button.
     */
    public function rounded(rounded:IntoButtonRounded):Button {
        roundedValue = rounded;
        return this;
    }

    /**
     * Set the border corners side of the Button (top left, top right,
     * bottom right, bottom left).
     */
    @:allow(gpui.component, tests)
    function withBorderCorners(topLeft:Bool, topRight:Bool, bottomRight:Bool, bottomLeft:Bool):Button {
        borderCorners = [topLeft, topRight, bottomRight, bottomLeft];
        return this;
    }

    /**
     * Set the border edges of the Button (top, right, bottom, left).
     */
    @:allow(gpui.component, tests)
    function withBorderEdges(top:Bool, right:Bool, bottom:Bool, left:Bool):Button {
        borderEdges = [top, right, bottom, left];
        return this;
    }

    /**
     * Join a hover group: while any member is hovered, an idle member shows
     * its hover surface at half strength, so a composite such as a split
     * button reads as one control with the hovered part emphasized.
     */
    @:allow(gpui.component, tests)
    function hoverGroup(group:String):Button {
        hoverGroupValue = group;
        return this;
    }

    /**
     * Keep the hover group's idle surface up without a pointer, for as long as
     * the group is held engaged, such as while a sibling's menu is open.
     */
    @:allow(gpui.component, tests)
    function hoverGroupHeld(held:Bool):Button {
        hoverGroupHeldValue = held;
        return this;
    }

    /**
     * Set label to the Button, if no label is set, the button will be in Icon Button mode.
     */
    public function label(label:String):Button {
        labelValue = label;
        return this;
    }

    /**
     * Set the name a screen reader announces, when the visible content is not
     * it (an icon-only button, a row-shaped button). It replaces the announced
     * name without adding anything to the screen.
     */
    public function accessibilityLabel(label:String):Button {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Set the icon of the button, if the Button have no label, the button well in Icon Button mode.
     */
    public function icon(icon:IntoButtonIcon):Button {
        iconValue = icon;
        return this;
    }

    /**
     * Set the tooltip of the button.
     */
    public function tooltip(tooltip:String):Button {
        tooltipValue = tooltip;
        tooltipActionValue = null;
        return this;
    }

    /**
     * Prefer a side for the tooltip, falling back when it does not fit.
     *
     * Applies to `tooltip` and `tooltipWithAction`. Omitting placement keeps
     * automatic positioning.
     */
    public function tooltipPlacement(placement:gpui.base.Geometry.Placement):Button {
        tooltipPlacementValue = placement;
        return this;
    }

    /**
     * Set the tooltip of the button with action to show keybinding.
     */
    public function tooltipWithAction(tooltip:String, action:gpui.Action, context:Null<String>):Button {
        tooltipValue = tooltip;
        tooltipActionValue = {action: action, context: context};
        return this;
    }

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    public function tooltipShowDelay(delay:Float):Button {
        tooltipShowDelayValue = delay;
        return this;
    }

    /**
     * Set true to show the loading indicator.
     */
    public function loading(loading:Bool):Button {
        loadingValue = loading;
        return this;
    }

    /**
     * Set the button to compact mode, then padding will be reduced.
     */
    public function compact():Button {
        compactValue = true;
        return this;
    }

    /**
     * Add click handler.
     */
    public function onClick(handler:(ClickEvent, Window, App) -> Void):Button {
        onClickHandler = handler;
        return this;
    }

    /**
     * Add hover handler, the bool parameter indicates whether the mouse is hovering.
     */
    public function onHover(handler:(Bool, Window, App) -> Void):Button {
        onHoverHandler = handler;
        return this;
    }

    /**
     * Add a mouse down listener (Rust `InteractiveElement::on_mouse_down`
     * on the Base button's interactivity).
     */
    public function onMouseDown(button:gpui.MouseButton, listener:(gpui.MouseDownEvent, Window, App) -> Void):Button {
        base.onMouseDown(button, listener);
        return this;
    }

    /**
     * Set the loading icon of the button, it will be used when loading is true.
     *
     * Default is a spinner icon.
     */
    public function loadingIcon(icon:IntoIcon):Button {
        loadingIconValue = icon;
        return this;
    }

    /**
     * Use a caller-owned focus handle instead of the one the button keeps for
     * itself, so the application can focus the button and restore focus to it.
     *
     * The handle drives the focus ring, Enter and Space activation and the
     * accessibility focus state alike.
     */
    public function trackFocus(focusHandle:FocusHandle):Button {
        focusHandleValue = focusHandle;
        return this;
    }

    /**
     * Set the tab index of the button, it will be used to focus the button by tab key.
     *
     * Default is 0.
     */
    public function tabIndex(tabIndex:Int):Button {
        tabIndexValue = tabIndex;
        return this;
    }

    /**
     * Set the tab stop of the button, if true, the button will be focusable by tab key.
     *
     * Default is true.
     */
    public function tabStop(tabStop:Bool):Button {
        tabStopValue = tabStop;
        return this;
    }

    /**
     * Set to show a dropdown caret icon at the end of the button.
     */
    public function dropdownCaret(dropdownCaret:Bool):Button {
        dropdownCaretValue = dropdownCaret;
        return this;
    }

    /**
     * Expose this button as a toggle button to assistive technology, with
     * `toggled` as its pressed state.
     *
     * Only affects accessibility metadata. Use `selected` for the selected
     * styling, and call this in addition when the button really is a toggle,
     * otherwise the button stays an ordinary push button.
     */
    public function toggled(toggled:Bool):Button {
        toggledValue = toggled;
        return this;
    }

    /**
     * Whether the button paints its selected styling, which is what both a
     * caller-set selection and an open popup look like today.
     */
    @:allow(gpui.component, tests)
    inline function showsSelectedStyle():Bool {
        return selectedValue || openValue;
    }

    /**
     * Whether the button responds to the pointer at all.
     *
     * A loading button is as inert as a disabled one, it just keeps looking
     * like itself instead of taking the disabled styling.
     */
    @:allow(gpui.component, tests)
    inline function interactive():Bool {
        return !(disabledValue || loadingValue);
    }

    @:allow(gpui.component, tests)
    inline function hoverable():Bool {
        return interactive() && onHoverHandler != null;
    }

    /// Disableable

    public function disabled(disabled:Bool):Button {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    /// FocusableExt

    public function focusRing(enabled:Bool):Button {
        focusRingEnabled = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusRingEnabled = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRingEnabled;
    }

    /// Selectable

    public function selected(selected:Bool):Button {
        selectedValue = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function open(open:Bool):Button {
        openValue = open;
        return this;
    }

    public function setOpen(open:Bool):Void {
        openValue = open;
    }

    public function isOpen():Bool {
        return openValue;
    }

    /// Sizable

    public function withSize(size:IntoSize):Button {
        this.sizeValue = size;
        return this;
    }

    public function prepareForToolbar():Button {
        return ghost().compact();
    }

    /// ButtonVariants

    public function withVariant(variant:ButtonVariant):Button {
        variantValue = variant;
        return this;
    }

    /** With the primary style for the Button. */
    public inline function primary():Button return withVariant(Primary);

    /** With the secondary style for the Button. */
    public inline function secondary():Button return withVariant(Secondary);

    /** With the danger style for the Button. */
    public inline function danger():Button return withVariant(Danger);

    /** With the warning style for the Button. */
    public inline function warning():Button return withVariant(Warning);

    /** With the success style for the Button. */
    public inline function success():Button return withVariant(Success);

    /** With the info style for the Button. */
    public inline function info():Button return withVariant(Info);

    /** With the ghost style for the Button. */
    public inline function ghost():Button return withVariant(Ghost);

    /** With the link style for the Button. */
    public inline function link():Button return withVariant(Link);

    /** With the text style for the Button, it will no padding look like a normal text. */
    public inline function text():Button return withVariant(Text);

    /** With the custom style for the Button. */
    public inline function custom(style:ButtonCustomVariant):Button return withVariant(Custom(style));

    public function render(window:Window, cx:App):IntoElement {
        final size = sizeValue;
        final theme = Theme.global(cx);
        final style:ButtonVariant = variantValue;
        final interactive = this.interactive();
        final hoverable = this.hoverable();
        final disabled = disabledValue;
        final selected = showsSelectedStyle();
        final loading = loadingValue;
        final hoverGroup = hoverGroupValue;
        final hoverGroupHeld = hoverGroupHeldValue;
        final base = this.base;
        final children = childElements;
        final instanceStyle = base.style().clone();
        final normalStyle = style.normal(outlineValue, cx);
        final selectedStyle = style.selected(outlineValue, cx);
        final disabledStyle = style.disabled(outlineValue, cx);
        final iconSize:Size = this.iconSize != null ? this.iconSize : switch size {
            case Size(v): Size(v * 0.75);
            case _: size;
        }
        final hasContent = iconValue != null || labelValue != null || children.length > 0;
        // Only borderless variants use this; the others tint their border.
        final focusLine:FocusLine = if (style.noPadding()) {
            Outside;
        } else if (style.isGhost()) {
            Edge;
        } else {
            Inside(normalStyle.fg.opacity(FOCUS_LINE_OPACITY));
        }

        final focusHandle:FocusHandle = focusHandleValue != null ? focusHandleValue : window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);

        final rounding:Pixels = switch roundedValue {
            case Small: theme.radius * 0.5;
            case Medium: theme.radius;
            case Large: theme.radius * 2.0;
            case Size(px): px;
            case None: 0.;
        }

        final root = base.cursorDefault().flex().flexShrink0().itemsCenter().justifyCenter().cursorDefault();
        if (interactive && (variantValue.isLink() || variantValue.isText())) root.cursorPointer();
        if (!disabled && theme.shadow && normalStyle.shadow) root.shadowXs();
        if (!style.noPadding()) {
            // Deliberate deviation DEV-003: an icon with a dropdown caret does
            // not fit the icon square, size it like a normal button.
            if (labelValue == null && children.length == 0 && !(iconValue != null && dropdownCaretValue)) {
                // Icon Button
                switch size {
                    case Size(px): root.size(px);
                    case XSmall: root.size5();
                    case Small: root.size6();
                    case Large | Medium: root.size8();
                }
            } else {
                // Normal Button
                switch size {
                    case Size(size): root.px(size * 0.2);
                    case XSmall:
                        root.h5().px1();
                        if (compactValue) root.minW5();
                    case Small:
                        root.h6().px2();
                        if (compactValue) root.minW6().px1p5();
                    case Medium:
                        root.h8().px2p5();
                        if (compactValue) root.minW8().px2();
                    case Large:
                        root.h8().px3();
                        if (compactValue) root.minW8().px2();
                }
            }
        }
        if (borderCorners[0]) root.roundedTl(rounding);
        if (borderCorners[1]) root.roundedTr(rounding);
        if (borderCorners[3]) root.roundedBl(rounding);
        if (borderCorners[2]) root.roundedBr(rounding);
        if (variantValue.isDefault() || outlineValue) {
            if (borderEdges[3]) root.borderL1();
            if (borderEdges[1]) root.borderR1();
            if (borderEdges[0]) root.borderT1();
            if (borderEdges[2]) root.borderB1();
        }
        final outline = outlineValue;
        if (!disabledValue && !selected) {
            root.borderColor(normalStyle.border).bg(normalStyle.bg).textColor(normalStyle.fg);
            if (normalStyle.underline) root.textDecoration1();
            // A loading button keeps its normal colors, but must not react
            // to the pointer, it is not waiting for another click.
            if (interactive) {
                final activeStyle = style.active(outline, cx);
                root.active(s -> s.bg(activeStyle.bg).borderColor(activeStyle.border).textColor(activeStyle.fg));
                if (hoverGroup != null) {
                    final idleBg = style.hovered(outline, cx).bg.opacity(0.5);
                    if (hoverGroupHeld) root.bg(idleBg);
                    root.groupHover(hoverGroup, s -> s.bg(idleBg));
                }
            }
        }
        // Always register the hover style: GPUI only refreshes the cached
        // hover state while one is present. If a selected button skipped it,
        // the stale state would keep hover colors after unselecting.
        final hoverStyle = !interactive || selected ? null : style.hovered(outline, cx);
        root.hover(s -> {
            if (hoverStyle == null) return s;
            return s.bg(hoverStyle.bg).borderColor(hoverStyle.border).textColor(hoverStyle.fg);
        });
        root.lineHeight(gpui.Prelude.relative(1.25)).refineStyle(instanceStyle);

        // The explicit name wins: it exists precisely for the cases where the
        // visible content is not what a listener needs to hear.
        final accessibilityLabel = accessibilityLabelValue != null ? accessibilityLabelValue : labelValue;
        final content = hFlex()
            .id('label')
            .sizeFull()
            .minW0()
            .overflowHidden()
            .whitespaceNowrap()
            .itemsCenter()
            .justifyCenter()
            .buttonTextSize(size);
        switch size {
            case XSmall | Small: content.gap1();
            case _: content.gap2();
        }
        content.refineStyle(contentStyleValue);
        if (iconValue != null) {
            content.child(iconValue.loadingIcon(loadingIconValue).loading(loadingValue).withSize(iconSize));
        }
        if (labelValue != null) {
            content.child(div().minW0().whitespaceNowrap().textEllipsis().child(labelValue));
        }
        for (child in children) content.child(child);
        if (dropdownCaretValue) {
            if (hasContent) content.justifyBetween();
            content.child(new Caret(size).textColor(normalStyle.fg.opacity(0.75)));
        }

        final resolvedRole = roleValue.resolve(() -> variantValue.isLink() ? Role.Link : Role.Button);
        root.role(resolvedRole != null ? Explicit(resolvedRole) : Presentational)
            .selected(selected)
            .disabled(disabled)
            // Base layers semantic states over the builder chain, so the caller's
            // own style is replayed inside each state to keep it the closest layer.
            .styles(styles -> styles
                .selected(s -> s
                    .bg(selectedStyle.bg)
                    .borderColor(selectedStyle.border)
                    .textColor(selectedStyle.fg)
                    .refineStyle(instanceStyle))
                .disabled(s -> s
                    .bg(disabledStyle.bg)
                    .textColor(disabledStyle.fg)
                    .borderColor(disabledStyle.border)
                    .shadowNone()
                    .refineStyle(instanceStyle)));
        if (accessibilityLabel != null) root.accessibilityLabel(accessibilityLabel);
        if (toggledValue != null) root.a11y.toggled = toggledValue ? Toggled.True : Toggled.False;
        root.trackFocus(focusHandle).tabIndex(tabIndexValue).tabStop(tabStopValue).child(content);
        // Fade the whole button while loading, so every variant is dimmed by
        // the same amount. Fading `bg`, `border` and `fg` one by one instead
        // only shows up on variants that have a background to begin with:
        // `Ghost`, `Link` and `Text` are transparent, so an alpha on their
        // background changes nothing.
        if (loading && !disabled) root.opacity(0.8);
        if (!disabled) {
            root.onMouseDown(Left, (_, window, cx) -> {
                if (loading) {
                    cx.stopPropagation();
                    return;
                }

                // Avoid focus on mouse down.
                window.preventDefault();

                // Pressing a button must not start the window-level text selection.
                GlobalState.suppressTextSelection(cx);
            });
        }
        final onClick = onClickHandler;
        if (onClick != null) {
            root.onClick((event, window, cx) -> {
                if (loading) {
                    cx.stopPropagation();
                    return;
                }

                onClick(event, window, cx);
            });
        }
        if (loading) {
            root.onClick((_, _, cx) -> cx.stopPropagation());
        }
        final onHover = onHoverHandler;
        if (onHover != null && hoverable) {
            root.onHover((hovered, window, cx) -> onHover(hovered, window, cx));
        }
        final tooltipPlacement = tooltipPlacementValue;
        final tooltipShowDelay = tooltipShowDelayValue;
        final tooltipBuilder = this.tooltipBuilder;
        final tooltip = tooltipValue;
        final tooltipAction = tooltipActionValue;
        if (tooltipBuilder != null) {
            ManagedTooltip.managedTooltipOn(root, root.base, tooltipPlacement, tooltipShowDelay, (window, cx) -> tooltipBuilder(window, cx));
        }
        else if (tooltip != null) {
            ManagedTooltip.managedTooltipOn(root, root.base, tooltipPlacement, tooltipShowDelay, (window, cx) -> {
                final view = new gpui.component.tooltip.Tooltip(tooltip);
                if (tooltipAction != null) {
                    view.action(tooltipAction.action, tooltipAction.context);
                }
                return view.build(window, cx);
            });
        }
        if (isFocused && focusRingEnabled) {
            root.focusStyle(focusLine, window, cx);
        }
        return root;
    }

}
