// Ported from gpui-kit 0.8.1: crates/component/src/button/button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-003 (icon button with a dropdown caret). See docs/DEVIATIONS.md.
package glaze.kit.button;

import glaze.AnyElement;
import glaze.App;
import glaze.Background;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Listeners;
import glaze.Corners;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoBackground;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.ComponentTraits;
import glaze.kit.base.GlobalState;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.ThemeStyled.FocusLine;
import glaze.kit.button.ButtonIcon;
import glaze.kit.select.Caret;
import glaze.kit.theme.Theme;
import glaze.kit.tooltip.Tooltip.ManagedTooltip;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.A11y.RoleOverrideTools;
using glaze.kit.base.StyledExt;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;
using glaze.kit.theme.Colorize;

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

    @:allow(glaze.kit.button)
    var colorValue:Hsla;

    @:allow(glaze.kit.button)
    var foregroundValue:Hsla;

    @:allow(glaze.kit.button)
    var shadowValue:Bool;

    @:allow(glaze.kit.button)
    var hoverValue:Hsla;

    @:allow(glaze.kit.button)
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
@:using(glaze.kit.button.Button.ButtonVariantTools)
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
@:allow(glaze.kit.button, tests)
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

    @:allow(glaze.kit, tests)
    static inline function noPadding(self:ButtonVariant):Bool {
        return isLink(self) || isText(self);
    }

    @:allow(glaze.kit, tests)
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

    @:allow(glaze.kit, tests)
    static function normal(self:ButtonVariant, outline:Bool, cx:App):ButtonVariantStyle {
        final bg = bgColor(self, outline, cx);
        final border = borderColor(self, outline, cx);
        final fg = textColor(self, outline, cx);
        return new ButtonVariantStyle(bg, border, fg, underline(self, cx), shadow(self, outline, cx));
    }

    @:allow(glaze.kit, tests)
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

    @:allow(glaze.kit, tests)
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

    @:allow(glaze.kit, tests)
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

    @:allow(glaze.kit, tests)
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
 * `tooltipShowDelay`) are managed tooltips (`glaze.kit.tooltip`).
 */
class Button extends Component implements Styled implements ParentElement implements Sizable implements Selectable implements Disableable implements FocusableExt {

    /** The mouse down listener of an enabled button (shared, it captures nothing) */
    static final MOUSE_DOWN:(glaze.MouseDownEvent, Window, App) -> Void = (_, window, cx) -> {
        // Avoid focus on mouse down.
        window.preventDefault();

        // Pressing a button must not start the window-level text selection.
        GlobalState.suppressTextSelection(cx);
    };

    /** The mouse down listener of a loading button */
    static final LOADING_MOUSE_DOWN:(glaze.MouseDownEvent, Window, App) -> Void = (_, _, cx) -> cx.stopPropagation();

    /** The click listener of a loading button */
    static final STOP_CLICK:(ClickEvent, Window, App) -> Void = (_, _, cx) -> cx.stopPropagation();

    /** Ink of the focus line a filled button draws inside its fill. */
    static inline final FOCUS_LINE_OPACITY:Float = 0.6;

    final id:ElementId;

    @:allow(glaze.kit, tests)
    var base:glaze.kit.base.Button;

    @:allow(glaze.kit, tests)
    @prop var icon:Null<ButtonIcon> = null;

    /**
     * Set label to the Button, if no label is set, the button will be in Icon Button mode.
     */
    @:allow(glaze.kit, tests)
    @prop var label:Null<String> = null;

    /**
     * Set the name a screen reader announces, when the visible content is not
     * it (an icon-only button, a row-shaped button). It replaces the announced
     * name without adding anything to the screen.
     */
    @:allow(glaze.kit, tests)
    @prop var accessibilityLabel:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    @:allow(glaze.kit, tests)
    @prop var disabled:Bool = false;

    @:allow(glaze.kit, tests)
    @prop var selected:Bool = false;

    /**
     * Held by the popover, menu or dropdown this button triggers, for as long
     * as it is open. Kept apart from `selected` because the two states mean
     * different things, even though they paint the same today.
     */
    @prop var open:Bool = false;

    /**
     * Expose this button as a toggle button to assistive technology, with
     * `toggled` as its pressed state.
     *
     * Only affects accessibility metadata. Use `selected` for the selected
     * styling, and call this in addition when the button really is a toggle,
     * otherwise the button stays an ordinary push button.
     */
    @:allow(glaze.kit, tests)
    @prop var toggled:Null<Bool> = null;

    @prop var role:RoleOverride = Implicit;

    @:allow(glaze.kit, tests)
    var variantValue:ButtonVariant = Default;

    @:allow(glaze.kit, tests)
    @prop var rounded:ButtonRounded = Medium;

    @:allow(glaze.kit, tests)
    var outlineValue:Bool = false;

    /** Replaced, never changed in place (`withBorderCorners`) */
    var borderCorners:Array<Bool> = ALL_SIDES;

    /** Replaced, never changed in place (`withBorderEdges`) */
    var borderEdges:Array<Bool> = ALL_SIDES;

    /** Every corner or edge (shared by the buttons that keep them all) */
    static final ALL_SIDES:Array<Bool> = [true, true, true, true];

    /**
     * Set to show a dropdown caret icon at the end of the button.
     */
    @:allow(glaze.kit, tests)
    @prop var dropdownCaret:Bool = false;

    var hoverGroupValue:Null<String> = null;

    var hoverGroupHeldValue:Bool = false;

    @:allow(glaze.kit, tests)
    var sizeValue:Size = Medium;

    var contentStyleValue:StyleRefinement = new StyleRefinement();

    var iconSize:Null<Size> = null;

    @:allow(glaze.kit, tests)
    var compactValue:Bool = false;

    @:allow(glaze.kit, tests)
    var tooltipValue:Null<String> = null;

    /** The action whose key binding the tooltip shows (Rust: the second half of `tooltip`). */
    var tooltipActionValue:Null<{action:glaze.Action, context:Null<String>}> = null;

    /**
     * Prefer a side for the tooltip, falling back when it does not fit.
     *
     * Applies to `tooltip` and `tooltipWithAction`. Omitting placement keeps
     * automatic positioning.
     */
    @prop var tooltipPlacement:Null<glaze.kit.base.Geometry.Placement> = null;

    var tooltipBuilder:Null<(Window, App) -> glaze.AnyView> = null;

    /**
     * Overrides how long the pointer must rest before the tooltip shows, in seconds.
     */
    @:allow(glaze.kit, tests)
    @prop var tooltipShowDelay:Null<Float> = null;

    @prop var onClick:Null<(ClickEvent, Window, App) -> Void> = null;

    /**
     * Add hover handler, the bool parameter indicates whether the mouse is hovering.
     */
    @prop var onHover:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Set true to show the loading indicator.
     */
    @:allow(glaze.kit, tests)
    @prop var loading:Bool = false;

    @prop var loadingIcon:Null<Icon> = null;

    @prop var focusRing:Bool = true;

    /**
     * Use a caller-owned focus handle instead of the one the button keeps for
     * itself, so the application can focus the button and restore focus to it.
     *
     * The handle drives the focus ring, Enter and Space activation and the
     * accessibility focus state alike.
     */
    @:allow(glaze.kit, tests)
    @prop var trackFocus:Null<FocusHandle> = null;

    /**
     * Set the tab index of the button, it will be used to focus the button by tab key.
     *
     * Default is 0.
     */
    @:allow(glaze.kit, tests)
    @prop var tabIndex:Int = 0;

    /**
     * Set the tab stop of the button, if true, the button will be focusable by tab key.
     *
     * Default is true.
     */
    @:allow(glaze.kit, tests)
    @prop var tabStop:Bool = true;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        this.base = glaze.kit.base.Button.component(id);
    }

    /**
     * Uses a behavior primitive supplied by a compound Base control.
     */
    @:allow(glaze.kit, tests)
    function withBase(base:glaze.kit.base.Button):Button {
        this.base = base;
        return this;
    }

    @:allow(glaze.kit, tests)
    function variant():ButtonVariant {
        return variantValue;
    }

    @:allow(glaze.kit, tests)
    function isCompact():Bool {
        return compactValue;
    }

    /**
     * Presentation supplied by a styled compound control. Standalone buttons
     * retain their normal size-derived content style.
     */
    @:allow(glaze.kit, tests)
    function contentStyle(style:StyleRefinement, iconSize:Size):Button {
        contentStyleValue = style;
        this.iconSize = iconSize;
        return this;
    }

    @:allow(glaze.kit, tests)
    function buttonSize():Size {
        return sizeValue;
    }

    @:allow(glaze.kit, tests)
    function isDisabled():Bool {
        return disabled;
    }

    @:allow(glaze.kit, tests)
    function isOutline():Bool {
        return outlineValue;
    }

    /**
     * Whether the button shows only its icon.
     */
    @:allow(glaze.kit, tests)
    function isIconOnly():Bool {
        return icon != null && label == null && childElements.length == 0;
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Button {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Button {
        for (child in children) if (child != null) childElements.push(child);
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
        this.rounded = rounded;
        return this;
    }

    /**
     * Set the border corners side of the Button (top left, top right,
     * bottom right, bottom left).
     */
    @:allow(glaze.kit, tests)
    function withBorderCorners(topLeft:Bool, topRight:Bool, bottomRight:Bool, bottomLeft:Bool):Button {
        borderCorners = [topLeft, topRight, bottomRight, bottomLeft];
        return this;
    }

    /**
     * Set the border edges of the Button (top, right, bottom, left).
     */
    @:allow(glaze.kit, tests)
    function withBorderEdges(top:Bool, right:Bool, bottom:Bool, left:Bool):Button {
        borderEdges = [top, right, bottom, left];
        return this;
    }

    /**
     * Join a hover group: while any member is hovered, an idle member shows
     * its hover surface at half strength, so a composite such as a split
     * button reads as one control with the hovered part emphasized.
     */
    @:allow(glaze.kit, tests)
    function hoverGroup(group:String):Button {
        hoverGroupValue = group;
        return this;
    }

    /**
     * Keep the hover group's idle surface up without a pointer, for as long as
     * the group is held engaged, such as while a sibling's menu is open.
     */
    @:allow(glaze.kit, tests)
    function hoverGroupHeld(held:Bool):Button {
        hoverGroupHeldValue = held;
        return this;
    }

    /**
     * Set the icon of the button, if the Button have no label, the button well in Icon Button mode.
     */
    public function icon(icon:IntoButtonIcon):Button {
        this.icon = icon;
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
     * Set the tooltip of the button with action to show keybinding.
     */
    public function tooltipWithAction(tooltip:String, action:glaze.Action, context:Null<String>):Button {
        tooltipValue = tooltip;
        tooltipActionValue = {action: action, context: context};
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
     * Add click handler. Also written `onClick(() -> ...)` or
     * `onClick(event -> ...)` (`glaze.Listeners.ClickListener`).
     */
    public function onClick(handler:ClickListener):Button {
        this.onClick = handler;
        return this;
    }

    /**
     * Add a mouse down listener (Rust `InteractiveElement::on_mouse_down`
     * on the Base button's interactivity).
     */
    public function onMouseDown(button:glaze.MouseButton, listener:(glaze.MouseDownEvent, Window, App) -> Void):Button {
        base.onMouseDown(button, listener);
        return this;
    }

    /**
     * Set the loading icon of the button, it will be used when loading is true.
     *
     * Default is a spinner icon.
     */
    public function loadingIcon(icon:IntoIcon):Button {
        this.loadingIcon = icon;
        return this;
    }

    /**
     * Whether the button paints its selected styling, which is what both a
     * caller-set selection and an open popup look like today.
     */
    @:allow(glaze.kit, tests)
    inline function showsSelectedStyle():Bool {
        return selected || open;
    }

    /**
     * Whether the button responds to the pointer at all.
     *
     * A loading button is as inert as a disabled one, it just keeps looking
     * like itself instead of taking the disabled styling.
     */
    @:allow(glaze.kit, tests)
    inline function interactive():Bool {
        return !(disabled || loading);
    }

    @:allow(glaze.kit, tests)
    inline function hoverable():Bool {
        return interactive() && onHover != null;
    }

    /// Disableable

    public function setDisabled(disabled:Bool):Void {
        this.disabled = disabled;
    }

    /// FocusableExt

    public function setFocusRing(enabled:Bool):Void {
        focusRing = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusRing;
    }

    /// Selectable

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    public function setOpen(open:Bool):Void {
        this.open = open;
    }

    public function isOpen():Bool {
        return open;
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
        final disabled = this.disabled;
        final selected = showsSelectedStyle();
        final loading = this.loading;
        final hoverGroup = hoverGroupValue;
        final hoverGroupHeld = hoverGroupHeldValue;
        final base = this.base;
        final children = childElements;
        final instanceStyle = base.style().clone();
        final normalStyle = style.normal(outlineValue, cx);
        // The state styles are only read by the base button while their
        // state is on (`base.Button.resolvedStyle`): computed only then
        final selectedStyle = selected ? style.selected(outlineValue, cx) : null;
        final disabledStyle = disabled ? style.disabled(outlineValue, cx) : null;
        final iconSize:Size = this.iconSize != null ? this.iconSize : switch size {
            case Size(v): Size(v * 0.75);
            case _: size;
        }
        final hasContent = icon != null || label != null || children.length > 0;
        // Only borderless variants use this; the others tint their border.
        final focusLine:FocusLine = if (style.noPadding()) {
            Outside;
        } else if (style.isGhost()) {
            Edge;
        } else {
            Inside(normalStyle.fg.opacity(FOCUS_LINE_OPACITY));
        }

        final focusHandle:FocusHandle = trackFocus != null ? trackFocus : window.useKeyedState(id, cx, _ -> cx.focusHandle()).read(cx).value;
        final isFocused = focusHandle.isFocused(window);

        final rounding:Pixels = switch rounded {
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
            // Initial port deviation DEV-003: an icon with a dropdown caret does
            // not fit the icon square, size it like a normal button.
            if (label == null && children.length == 0 && !(icon != null && dropdownCaret)) {
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
        // One length for the four corners (lengths are immutable values)
        final roundingLength:glaze.AbsoluteLength = glaze.AbsoluteLength.Pixels(rounding);
        if (borderCorners[0]) root.roundedTl(roundingLength);
        if (borderCorners[1]) root.roundedTr(roundingLength);
        if (borderCorners[3]) root.roundedBl(roundingLength);
        if (borderCorners[2]) root.roundedBr(roundingLength);
        if (variantValue.isDefault() || outlineValue) {
            if (borderEdges[3]) root.borderL1();
            if (borderEdges[1]) root.borderR1();
            if (borderEdges[0]) root.borderT1();
            if (borderEdges[2]) root.borderB1();
        }
        final outline = outlineValue;
        if (!this.disabled && !selected) {
            root.borderColor(normalStyle.border).bg(normalStyle.bg).textColor(normalStyle.fg);
            if (normalStyle.underline) root.textDecoration1();
            // A loading button keeps its normal colors, but must not react
            // to the pointer, it is not waiting for another click.
            if (interactive) {
                final activeStyle = style.active(outline, cx);
                // `root.active(s -> s.bg(..).borderColor(..).textColor(..))` without the closure
                root.base.setActiveRefinement(new StyleBuilder().bg(activeStyle.bg).borderColor(activeStyle.border).textColor(activeStyle.fg).style());
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
        // `root.hover(s -> ...)` without the closure (an empty refinement without a hover style)
        root.base.setHoverRefinement(hoverStyle == null
            ? new StyleRefinement()
            : new StyleBuilder().bg(hoverStyle.bg).borderColor(hoverStyle.border).textColor(hoverStyle.fg).style());
        root.lineHeight(glaze.Prelude.relative(1.25)).refineStyle(instanceStyle);

        // The explicit name wins: it exists precisely for the cases where the
        // visible content is not what a listener needs to hear.
        final accessibilityLabel = this.accessibilityLabel != null ? this.accessibilityLabel : label;
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
        if (icon != null) {
            content.child(icon.loadingIcon(loadingIcon).loading(this.loading).withSize(iconSize));
        }
        if (label != null) {
            content.child(div().minW0().whitespaceNowrap().textEllipsis().child(label));
        }
        for (child in children) content.child(child);
        if (dropdownCaret) {
            if (hasContent) content.justifyBetween();
            content.child(Caret.component(size).textColor(normalStyle.fg.opacity(0.75)));
        }

        // `role.resolve(() -> ...)` without a closure per render
        final resolvedRole = switch role {
            case Implicit: variantValue.isLink() ? Role.Link : Role.Button;
            case _: role.resolve(null);
        }
        root.role(resolvedRole != null ? Explicit(resolvedRole) : Presentational)
            .selected(selected)
            .disabled(disabled);
        // Base layers semantic states over the builder chain, so the caller's
        // own style is replayed inside each state to keep it the closest layer.
        if (selectedStyle != null) {
            root.styles(styles -> styles
                .selected(s -> s
                    .bg(selectedStyle.bg)
                    .borderColor(selectedStyle.border)
                    .textColor(selectedStyle.fg)
                    .refineStyle(instanceStyle)));
        }
        if (disabledStyle != null) {
            root.styles(styles -> styles
                .disabled(s -> s
                    .bg(disabledStyle.bg)
                    .textColor(disabledStyle.fg)
                    .borderColor(disabledStyle.border)
                    .shadowNone()
                    .refineStyle(instanceStyle)));
        }
        if (accessibilityLabel != null) root.accessibilityLabel(accessibilityLabel);
        if (toggled != null) root.a11y.toggled = toggled ? Toggled.True : Toggled.False;
        root.trackFocus(focusHandle).tabIndex(tabIndex).tabStop(tabStop).child(content);
        // Fade the whole button while loading, so every variant is dimmed by
        // the same amount. Fading `bg`, `border` and `fg` one by one instead
        // only shows up on variants that have a background to begin with:
        // `Ghost`, `Link` and `Text` are transparent, so an alpha on their
        // background changes nothing.
        if (loading && !disabled) root.opacity(0.8);
        if (!disabled) {
            root.onMouseDown(Left, loading ? LOADING_MOUSE_DOWN : MOUSE_DOWN);
        }
        final onClick = this.onClick;
        if (onClick != null) {
            // While loading, the click stops there
            root.onClick(loading ? STOP_CLICK : onClick);
        }
        if (loading) {
            root.onClick(STOP_CLICK);
        }
        final onHover = this.onHover;
        if (onHover != null && hoverable) {
            root.onHover(onHover);
        }
        final tooltipPlacement = this.tooltipPlacement;
        final tooltipShowDelay = this.tooltipShowDelay;
        final tooltipBuilder = this.tooltipBuilder;
        final tooltip = tooltipValue;
        final tooltipAction = tooltipActionValue;
        if (tooltipBuilder != null) {
            ManagedTooltip.managedTooltipOn(root, root.base, tooltipPlacement, tooltipShowDelay, (window, cx) -> tooltipBuilder(window, cx));
        }
        else if (tooltip != null) {
            ManagedTooltip.managedTooltipOn(root, root.base, tooltipPlacement, tooltipShowDelay, (window, cx) -> {
                final view = new glaze.kit.tooltip.Tooltip(tooltip);
                if (tooltipAction != null) {
                    view.action(tooltipAction.action, tooltipAction.context);
                }
                return view.build(window, cx);
            });
        }
        if (isFocused && focusRing) {
            root.focusStyle(focusLine, window, cx);
        }
        return root;
    }

}
