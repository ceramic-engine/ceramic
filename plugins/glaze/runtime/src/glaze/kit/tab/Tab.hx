// Ported from gpui-kit 0.8.1: crates/component/src/tab/tab.rs (Tab)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: initial port deviations DEV-013 (icon-only tab width) and DEV-014 (disabled selected tab). See docs/DEVIATIONS.md.
// Additions without upstream equivalent (KIT-001, KIT-002 in docs/DEVIATIONS.md): the caller's style replayed last,
// `TabVariant.Custom`, `labelMaxWidth`, `hover`, `group`, `onHover`, `onDragMove`, `contextMenu`.
package glaze.kit.tab;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.ElementId;
import glaze.IntoBackground;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Path.FillOptions;
import glaze.PathBuilder;
import glaze.PathBuilder.PathStyle;
import glaze.Point;
import glaze.Pixels;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.base.animation.Easings;
import glaze.kit.base.animation.Lerp;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.tab.TabVariant;
import glaze.kit.tab.TabVariant.FolderTabConstants;
import glaze.kit.tab.TabVariant.FolderTabMetrics;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A Tab element for the `TabBar`.
 */
class Tab extends Component implements Styled implements ParentElement implements Sizable implements Selectable {

    @:allow(glaze.kit.tab)
    var ix:Int = 0;

    final base:glaze.kit.base.Tabs.BaseTab = new glaze.kit.base.Tabs.BaseTab(0);

    /** Set label for the tab. */
    @:allow(glaze.kit.tab)
    @prop var label:Null<String> = null;

    /** Set the accessible label for the tab. */
    @prop var ariaLabel:Null<String> = null;

    /** Set icon for the tab. */
    @:allow(glaze.kit.tab)
    @prop var icon:Null<Icon> = null;

    @prop var prefix:Null<AnyElement> = null;

    @:allow(glaze.kit.tab)
    var tabBarPrefixValue:Null<Bool> = null;

    @prop var suffix:Null<AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    var variant:TabVariant = TabVariant.defaultValue();

    var size:Size = Medium;

    /** Set disabled state to the tab, default false. */
    @:allow(glaze.kit.tab)
    @prop var disabled:Bool = false;

    @:allow(glaze.kit.tab)
    @prop var selected:Bool = false;

    @:allow(glaze.kit.tab)
    var indicatorActive:Bool = false;

    @:allow(glaze.kit.tab)
    var indicatorReady:Bool = true;

    /**
     * Animation epoch of the `TabBar` indicator; increments on every tab
     * switch. Used to key the selected tab's text color fade so it restarts
     * in sync with the indicator slide.
     */
    @:allow(glaze.kit.tab)
    var indicatorEpoch:Int = 0;

    /** Whether a `TabVariant.Folder` tab draws the divider after it. */
    @:allow(glaze.kit.tab)
    var separator:Bool = false;

    /**
     * Whether the `TabBar` reports the pointer over this tab. Kept there
     * rather than in a hover group, which would replace the caller's.
     */
    @:allow(glaze.kit.tab)
    var hovered:Bool = false;

    @:allow(glaze.kit.tab)
    var maxWidthValue:Null<Pixels> = null;

    @:allow(glaze.kit.tab)
    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    /**
     * The caller's style. Kept apart from the element's own so that `render`
     * replays it last, like `Button`: the caller's height, text size,
     * background, corners win over the variant's.
     */
    final userStyle:StyleRefinement = new StyleRefinement();

    /** The geometry of `TabVariant.Custom`, the bar's when `null`. */
    @:allow(glaze.kit.tab)
    var appearanceValue:Null<TabAppearance> = null;

    /** The maximum width of the label alone, the bar's when `null`. */
    @:allow(glaze.kit.tab)
    var labelMaxWidthValue:Null<Pixels> = null;

    var userHover:Null<(StyleBuilder) -> StyleBuilder> = null;

    var labelStyleValue:Null<(StyleBuilder) -> StyleBuilder> = null;

    var contextMenuBuilder:Null<glaze.kit.menu.ContextMenu.MenuBuilder> = null;

    /** Create a new tab. */
    public function new() {
        super();
    }

    /** `Tab::from(label)`. */
    public static function fromLabel(label:String):Tab {
        return glaze.kit.tab.Tab.component().label(label);
    }

    /** `Tab::from(icon)`. */
    public static function fromIcon(icon:Icon):Tab {
        return glaze.kit.tab.Tab.component().icon(icon);
    }

    function a11yLabel():Null<String> {
        return ariaLabel != null ? ariaLabel : label;
    }

    /** Set Tab Variant. */
    public function withVariant(variant:TabVariant):Tab {
        this.variant = variant;
        return this;
    }

    public function pill():Tab {
        variant = Pill;
        return this;
    }

    public function outline():Tab {
        variant = Outline;
        return this;
    }

    public function segmented():Tab {
        variant = Segmented;
        return this;
    }

    public function underline():Tab {
        variant = Underline;
        return this;
    }

    public function folder():Tab {
        variant = Folder;
        return this;
    }

    /**
     * Sets `TabVariant.Custom`: a rectangular tab colored by the tab tokens of
     * the theme, with the geometry of `appearance` (that of `TabVariant.Tab`
     * when omitted). Inside a `TabBar` the bar's variant applies, and the
     * bar's appearance unless the tab has its own.
     */
    public function custom(?appearance:TabAppearance):Tab {
        variant = Custom;
        if (appearance != null) appearanceValue = appearance;
        return this;
    }

    /**
     * Sets the maximum width of the label alone: a longer label is truncated
     * with an ellipsis, while the prefix, the suffix and the paddings keep
     * their size (`TabBar.maxWidth` caps the whole tab instead). Does not
     * apply to icon-only tabs.
     */
    public function labelMaxWidth(maxWidth:Null<Pixels>):Tab {
        labelMaxWidthValue = maxWidth;
        return this;
    }

    /**
     * A style for the label alone (a color, a strikethrough, a weight): the
     * prefix, the suffix and the children keep the style of the tab
     * (addition, KIT-012). `null`, the default, leaves the label as it is.
     */
    public function labelStyle(f:Null<(StyleBuilder) -> StyleBuilder>):Tab {
        labelStyleValue = f;
        return this;
    }

    /**
     * A style applied while the pointer is over the tab, after the variant's
     * own hover style.
     */
    public function hover(f:(StyleBuilder) -> StyleBuilder):Tab {
        userHover = f;
        return this;
    }

    /**
     * Names the hover group of the tab, so that a child (a close button in
     * the suffix for example) can style itself with `groupHover(name, ...)`
     * while the pointer is over the tab.
     */
    public function group(name:String):Tab {
        base.base.group(name);
        return this;
    }

    /** Reports the pointer entering (`true`) and leaving (`false`) the tab. */
    public function onHover(listener:(Bool, Window, App) -> Void):Tab {
        base.base.onHover(listener);
        return this;
    }

    /**
     * Reports every move of a drag of type `type`, over this tab or not: the
     * event carries the bounds of the tab and the pointer position, which
     * tells on which half of the tab an insertion line goes.
     */
    public function onDragMove<T>(type:Class<T>, listener:(glaze.DragMoveEvent<T>, Window, App) -> Void):Tab {
        base.base.onDragMove(type, listener);
        return this;
    }

    /**
     * Opens the menu `builder` fills on a right click (or a long press) on
     * the tab. Unlike the `contextMenu` extension, the tab stays a `Tab`, so
     * it can be given to a `TabBar`.
     */
    public function contextMenu(builder:(glaze.kit.menu.PopupMenu, Window, glaze.Context<glaze.kit.menu.PopupMenu>) -> glaze.kit.menu.PopupMenu):Tab {
        contextMenuBuilder = builder;
        return this;
    }

    /** Set the left side of the tab */
    public function prefix(prefix:IntoElement):Tab {
        this.prefix = prefix;
        return this;
    }

    /** Set the right side of the tab */
    public function suffix(suffix:IntoElement):Tab {
        this.suffix = suffix;
        return this;
    }

    /** Set the click handler for the tab. */
    public function onClick(onClick:(ClickEvent, Window, App) -> Void):Tab {
        onClickHandler = onClick;
        return this;
    }

    /** Set index to the tab. */
    @:allow(glaze.kit)
    function withIx(ix:Int):Tab {
        this.ix = ix;
        base.id(ix);
        return this;
    }

    /** Set if the tab bar has a prefix. */
    @:allow(glaze.kit)
    function tabBarPrefix(tabBarPrefix:Bool):Tab {
        tabBarPrefixValue = tabBarPrefix;
        return this;
    }

    /** Set the maximum width of the tab, see `TabBar.maxWidth`. */
    @:allow(glaze.kit.tab)
    function maxWidth(maxWidth:Null<Pixels>):Tab {
        maxWidthValue = maxWidth;
        return this;
    }

    // Rust `InteractiveElement` / `StatefulInteractiveElement` for Tab, whose
    // interactivity is the base tab's element.

    /** Rust `debug_selector`: like `Div.debugSelector`, it records nothing. */
    public function debugSelector(f:() -> String):Tab {
        base.base.debugSelector(f);
        return this;
    }

    /** A mouse down listener. */
    public function onMouseDown(button:glaze.MouseButton, listener:(glaze.MouseDownEvent, Window, App) -> Void):Tab {
        base.onMouseDown(button, listener);
        return this;
    }

    /** A mouse up listener. */
    public function onMouseUp(button:glaze.MouseButton, listener:(glaze.MouseUpEvent, Window, App) -> Void):Tab {
        base.base.onMouseUp(button, listener);
        return this;
    }

    /** Starts a drag of `value` from this tab, previewed by the view `constructor` builds. */
    public function onDrag<T>(value:T, constructor:(T, Point, Window, App) -> glaze.AnyView):Tab {
        base.base.onDrag(value, constructor);
        return this;
    }

    /** The style applied while a drag of type `type` is over this tab. */
    public function dragOver<S>(type:Class<S>, f:(StyleBuilder, S, Window, App) -> StyleBuilder):Tab {
        base.base.dragOver(type, f);
        return this;
    }

    /** Drops of type `type` on this tab. */
    public function onDrop<T>(type:Class<T>, listener:(T, Window, App) -> Void):Tab {
        base.base.onDrop(type, listener);
        return this;
    }

    /** Whether a drop should be dispatched to this tab. */
    public function canDrop(predicate:(Dynamic, Window, App) -> Bool):Tab {
        base.base.canDrop(predicate);
        return this;
    }

    /** A tooltip shown while the pointer rests on the tab. */
    public function tooltip(buildTooltip:(Window, App) -> glaze.AnyView):Tab {
        base.base.tooltip(buildTooltip);
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public inline function style():StyleRefinement {
        return userStyle;
    }

    public function withSize(size:IntoSize):Tab {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    var topAccentValue:Null<glaze.Hsla> = null;

    var topAccentWidth:Float = 2.;

    /**
     * Draws a line of `color`, `width` px thick (2 by default), along the
     * top of the tab while it is selected, over its whole width (addition,
     * KIT-039): the accent of an application on its active tab, or the edge
     * of a tab over a strip that has none. Null, the default, draws none.
     */
    public function topAccent(color:Null<glaze.Hsla>, width:Float = 2.):Tab {
        topAccentValue = color;
        topAccentWidth = width;
        return this;
    }

    var selectedForegroundValue:Null<glaze.Hsla> = null;

    /**
     * Draws the label of the tab in `color` while it is selected, instead of
     * the color of its variant (addition, KIT-053): the active tab of a
     * group that does not have the focus. Null, the default, keeps the
     * color of the variant.
     */
    public function selectedForeground(color:Null<glaze.Hsla>):Tab {
        selectedForegroundValue = color;
        return this;
    }

    var firstKeepsLeftBorderValue:Bool = false;

    /**
     * Keeps the left border of the tab when it is the first of its bar
     * (addition, KIT-058). A first tab drops it by default: the edge of what
     * holds the bar is expected to draw that line.
     */
    public function firstKeepsLeftBorder(keeps:Bool):Tab {
        firstKeepsLeftBorderValue = keeps;
        return this;
    }

    var selectedBackgroundValue:Null<glaze.Hsla> = null;

    /**
     * Gives the tab the ground `color` while it is selected, instead of
     * the one of its variant (addition, KIT-057): a tab that takes the
     * ground of what it shows. Null, the default, keeps the ground of the
     * variant.
     */
    public function selectedBackground(color:Null<glaze.Hsla>):Tab {
        selectedBackgroundValue = color;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final normalStyle = variant.normal(cx);
        final selectedStyle = variant.selected(cx);
        if (selectedForegroundValue != null) selectedStyle.fg = selectedForegroundValue;
        if (selectedBackgroundValue != null) selectedStyle.bg = selectedBackgroundValue;
        final disabledStyle = variant.disabled(this.selected, cx);
        var hoverStyle = variant.hovered(this.selected, cx);
        if (this.disabled) {
            hoverStyle = variant.disabled(this.selected, cx);
        }
        final tabBarPrefix = tabBarPrefixValue != null ? tabBarPrefixValue : false;
        final custom = variant == Custom;
        final appearance:Null<TabAppearance> = custom ? appearanceValue : null;
        if (appearance != null && !appearance.sideBordersValue) {
            for (style in [normalStyle, selectedStyle, disabledStyle, hoverStyle]) {
                style.borders = new glaze.Edges(style.borders.top, 0., style.borders.bottom, 0.);
            }
        }
        if (!tabBarPrefix) {
            if (ix == 0 && !firstKeepsLeftBorderValue && (variant == TabVariant.Tab || custom)) {
                for (style in [normalStyle, selectedStyle, disabledStyle, hoverStyle]) {
                    style.borders = new glaze.Edges(style.borders.top, style.borders.right, style.borders.bottom, 0.);
                }
            }
        }
        final tabStyle = this.disabled ? disabledStyle : (this.selected ? selectedStyle : normalStyle);
        final radius = variant.radius(size, cx);
        final innerRadius = variant.innerRadius(size, cx);
        final innerPaddings:glaze.Edges = appearance != null && appearance.paddingsValue != null ? appearance.paddingsValue : variant.innerPaddings(size);
        final innerMargins = variant.innerMargins(size);
        final height:Pixels = appearance != null && appearance.heightValue != null ? appearance.heightValue : variant.height(size);
        // A custom height keeps the two pixels `TabVariant.Tab` leaves around its content.
        final innerHeight:Pixels = appearance != null && appearance.heightValue != null
            ? Math.max(f32(appearance.heightValue - 2.), 0.)
            : variant.innerHeight(size);
        final topRadius:Float = appearance != null ? appearance.topRadiusValue : 0.;
        final labelMaxWidth = this.icon == null ? labelMaxWidthValue : null;
        // The caller's own corners are not reset by the hover style.
        final userCorners = topRadius > 0.
            || userStyle.cornerRadiusTopLeft != null || userStyle.cornerRadiusTopRight != null
            || userStyle.cornerRadiusBottomLeft != null || userStyle.cornerRadiusBottomRight != null;
        final userHover = this.userHover;
        final ariaLabel = a11yLabel();
        final folder = variant == Folder;
        final metrics = new FolderTabMetrics(size, cx);
        final hasPrefix = prefix != null;

        final segmentedIndicatorActive = variant == Segmented && indicatorActive;
        final hasInlineInnerBg = this.selected && segmentedIndicatorActive && !indicatorReady;
        final inlineInnerBg = tabStyle.innerBg;
        var innerBg:IntoBackground;
        var hoverInnerBg:IntoBackground;
        // Deviation DEV-014: a disabled selected tab has no indicator under it
        // (see TabBar) and keeps its own inner background.
        if (segmentedIndicatorActive && indicatorReady && !(this.selected && this.disabled)) {
            innerBg = theme.transparent;
            hoverInnerBg = theme.transparent;
        } else if (hasInlineInnerBg) {
            innerBg = inlineInnerBg;
            hoverInnerBg = inlineInnerBg;
        } else {
            innerBg = tabStyle.innerBg;
            hoverInnerBg = hoverStyle.innerBg;
        }
        final innerShadow = tabStyle.shadow && !segmentedIndicatorActive;

        // When a sliding indicator is active and ready, it alone represents the
        // selected state. Suppress the selected tab's own active background/border
        // so the two don't overlap during the switch animation (Segmented already
        // does this for its `inner_bg` above). Skip disabled tabs so a
        // disabled-selected tab keeps its dimmed styling instead of the
        // full-strength indicator color.
        final suppressActiveVisual = this.selected && !this.disabled && indicatorActive && indicatorReady;
        // Pill paints its active state via the outer `bg`.
        final selectedOuterBg:IntoBackground = suppressActiveVisual && variant == Pill ? (theme.transparent : IntoBackground) : selectedStyle.bg;
        // Underline paints its active state via the bottom `border_color`.
        final selectedOuterBorderColor = suppressActiveVisual && variant == Underline ? theme.transparent : selectedStyle.borderColor;

        // For Pill, the newly selected tab's text color (`primary_foreground`)
        // would otherwise snap to white instantly while the indicator is still
        // sliding into place. Fade it from the normal color in sync with the
        // indicator slide (keyed on the indicator epoch so it restarts on each
        // switch). `epoch == 0` is the initial layout (no slide), so we skip it.
        final animateFg = this.selected && !this.disabled && variant == Pill && indicatorActive && indicatorReady && indicatorEpoch > 0;
        final fgFrom = variant.normal(cx).fg;
        final fgTo = tabStyle.fg;
        // Icon-only tabs are fixed-size and exempt from `max_width`.
        final maxWidth = this.icon == null ? maxWidthValue : null;

        final innerContent = hFlex()
            .flex1()
            .h(innerHeight)
            .lineHeight(glaze.Prelude.relative(1.25))
            .whitespaceNowrap()
            .itemsCenter()
            .justifyCenter()
            .overflowHidden()
            .margins(glaze.Prelude.px(innerMargins.top), glaze.Prelude.px(innerMargins.right), glaze.Prelude.px(innerMargins.bottom), glaze.Prelude.px(innerMargins.left));
        // Normally the label decides the tab width, so it never shrinks. With
        // `max_width` it is the one part that gives way.
        if (maxWidth != null) innerContent.flexAuto() else innerContent.flexShrink0();
        if (this.icon != null) {
            final icon = this.icon;
            switch size {
                case XSmall: icon.size2p5();
                case Small: icon.size3p5();
                case Large: icon.size4();
                case _: icon.size4();
            }
            // Deviation DEV-013: `flex1()` above gave the box a zero basis, so
            // it shrank to the icon and ignored the width below. An icon-only
            // tab keeps that width.
            innerContent.flexNone().w(innerHeight * 1.25).child(icon);
        } else {
            innerContent.paddingsEdges(innerPaddings);
            if (label != null) {
                // Text always takes its natural width, so it needs a box
                // that is allowed to shrink to ellipsize inside of.
                // Addition (KIT-012): the caller's style of the label alone
                final labelRefinement = labelStyleValue != null ? labelStyleValue(new StyleBuilder()).style() : null;
                if (maxWidth != null) {
                    final labelBox = div().minW0().whitespaceNowrap().textEllipsis();
                    if (labelMaxWidth != null) labelBox.maxW(labelMaxWidth);
                    if (labelRefinement != null) labelBox.refineStyle(labelRefinement);
                    innerContent.child(labelBox.child(label));
                } else if (labelMaxWidth != null) {
                    // The label alone is capped: the tab keeps its natural
                    // width around it.
                    final labelBox = div().minW0().maxW(labelMaxWidth).whitespaceNowrap().textEllipsis();
                    if (labelRefinement != null) labelBox.refineStyle(labelRefinement);
                    innerContent.child(labelBox.child(label));
                } else if (labelRefinement != null) {
                    innerContent.child(div().flexNone().refineStyle(labelRefinement).child(label));
                } else {
                    innerContent.child(label);
                }
            }
            innerContent.extend(childElements);
            // With the prefix's gap, 8px between icon and title, as in a Button.
            if (folder && hasPrefix) innerContent.pl(glaze.Prelude.px(4.));
        }
        innerContent.bg(innerBg).rounded(innerRadius);
        if (innerShadow) innerContent.shadowXs();
        innerContent.hover(s -> s.bg(hoverInnerBg).rounded(innerRadius));

        final innerElement:AnyElement = if (animateFg) {
            innerContent.withAnimation(
                ElementId.NamedInteger('tab-fg', indicatorEpoch),
                new glaze.Animation(0.2).withEasing(Easings.easeInOutCubic),
                (this_, delta) -> this_.textColor(Lerp.hsla(fgFrom, fgTo, delta))
            ).intoAnyElement();
        } else {
            innerContent.intoAnyElement();
        }

        final selectedStyleValue = selectedStyle;
        base.id(ix)
            .selected(this.selected)
            .disabled(this.disabled);
        if (ariaLabel != null) base.accessibilityLabel(ariaLabel);
        base.styles(styles -> styles
            .selected(style -> style
                .textColor(selectedStyleValue.fg)
                .bg(selectedOuterBg)
                .borderL(glaze.Prelude.px(selectedStyleValue.borders.left))
                .borderR(glaze.Prelude.px(selectedStyleValue.borders.right))
                .borderT(glaze.Prelude.px(selectedStyleValue.borders.top))
                .borderB(glaze.Prelude.px(selectedStyleValue.borders.bottom))
                .borderColor(selectedOuterBorderColor))
            .disabled(style -> style
                .textColor(disabledStyle.fg)
                .bg(disabledStyle.bg)
                .borderL(glaze.Prelude.px(disabledStyle.borders.left))
                .borderR(glaze.Prelude.px(disabledStyle.borders.right))
                .borderT(glaze.Prelude.px(disabledStyle.borders.top))
                .borderB(glaze.Prelude.px(disabledStyle.borders.bottom))
                .borderColor(disabledStyle.borderColor)));
        base.relative().flex();
        // Wrapping would move the overflow onto a clipped second line instead
        // of letting the label shrink, so a capped tab lays out on one line.
        if (maxWidth != null) base.flexNowrap().maxW(maxWidth) else base.flexWrap();
        base.gap1().itemsCenter().flexShrink0().h(height);
        // A folder tab's curves reach past its bounds.
        if (!folder) base.overflowHidden();
        switch size {
            case XSmall: base.textXs();
            case Large: base.textBase();
            case _: base.textSm();
        }
        base.rounded(radius);
        if (appearance != null && appearance.textSizeValue != null) base.textSize(glaze.Prelude.px(appearance.textSizeValue));
        if (topRadius > 0.) base.roundedTl(glaze.Prelude.px(topRadius)).roundedTr(glaze.Prelude.px(topRadius));
        if (folder) base.px(metrics.paddingX).pb(metrics.topPadding);
        if (!this.selected && !this.disabled) {
            base.textColor(normalStyle.fg)
                .bg(normalStyle.bg)
                .borderL(glaze.Prelude.px(normalStyle.borders.left))
                .borderR(glaze.Prelude.px(normalStyle.borders.right))
                .borderT(glaze.Prelude.px(normalStyle.borders.top))
                .borderB(glaze.Prelude.px(normalStyle.borders.bottom))
                .borderColor(normalStyle.borderColor);
        }
        final selected = this.selected;
        final disabled = this.disabled;
        base.hover(s -> {
            // Always register the hover style: GPUI only refreshes the cached
            // hover state while one is present. If the selected tab skipped it,
            // the stale state would keep hover colors after unselecting.
            if (selected || disabled) {
                return userHover != null && !disabled ? userHover(s) : s;
            }
            s.textColor(hoverStyle.fg)
                .bg(hoverStyle.bg)
                .borderL(glaze.Prelude.px(hoverStyle.borders.left))
                .borderR(glaze.Prelude.px(hoverStyle.borders.right))
                .borderT(glaze.Prelude.px(hoverStyle.borders.top))
                .borderB(glaze.Prelude.px(hoverStyle.borders.bottom))
                .borderColor(hoverStyle.borderColor);
            if (!userCorners) s.rounded(radius);
            return userHover != null ? userHover(s) : s;
        });
        if (folder && this.selected) {
            base.child(folderTabShape(metrics, theme.tokens.tabActive.background));
        }
        // Addition (KIT-039): on the tab itself, not on its content, so that it spans the prefix and the suffix too
        if (topAccentValue != null && this.selected && !this.disabled) {
            base.child(div().absolute().top0().left0().right0().h(glaze.Prelude.px(topAccentWidth)).bg(topAccentValue));
        }
        if (folder && hovered && !this.selected && !this.disabled) {
            base.child(div()
                .absolute()
                .top0()
                .left0()
                .right0()
                .bottom(glaze.Prelude.px(metrics.topPadding))
                .rounded(metrics.radius)
                .bg(theme.tokens.secondary.background));
        }
        // In the gap after the tab, on a whole pixel, level with the content.
        if (folder && separator) {
            base.child(div()
                .absolute()
                .right(glaze.Prelude.px(-(@:privateAccess FolderTabConstants.FOLDER_TAB_GAP / 2.)))
                .top(glaze.Prelude.px((height - metrics.topPadding - metrics.separatorHeight) / 2.))
                .w(glaze.Prelude.px(1.))
                .h(metrics.separatorHeight)
                .bg(theme.border));
        }
        if (hasInlineInnerBg) {
            final layer = div()
                .wFull()
                .h(innerHeight)
                .bg(inlineInnerBg)
                .rounded(innerRadius);
            if (tabStyle.shadow) layer.shadowSm();
            base.child(div()
                .absolute()
                .left0()
                .right0()
                .top0()
                .bottom0()
                .flex()
                .itemsCenter()
                .child(layer));
        }
        // Under `max_width` the label is the only part that gives way, so
        // hold the prefix and suffix (e.g. a close button) at their full size.
        if (prefix != null) {
            final wrapper = div();
            if (maxWidth != null) wrapper.flexShrink0();
            base.child(wrapper.child(prefix));
        }
        base.child(innerElement);
        if (suffix != null) {
            final wrapper = div();
            if (maxWidth != null) wrapper.flexShrink0();
            base.child(wrapper.child(suffix));
        }
        final onClick = onClickHandler;
        if (onClick != null) {
            base.onClick((event, window, cx) -> onClick(event, window, cx));
        }
        // The caller's style goes last, like `Button`'s, except its
        // `flex_shrink`: a tab never shrinks (see `flexShrink0` above).
        @:privateAccess base.finalStyle = userStyle;
        final menuBuilder = contextMenuBuilder;
        if (menuBuilder != null) {
            // One element state per tab: the id carries the tab index.
            return @:privateAccess new glaze.kit.menu.ContextMenu(ElementId.NamedInteger('tab-context-menu', ix), base).menu(menuBuilder);
        }
        return base;
    }


    /**
     * The selected `TabVariant.Folder` tab: rounded on top and curving out at
     * the bottom into the content below, traced after Chrome's tab path.
     */
    static function folderTabShape(metrics:FolderTabMetrics, bg:IntoBackground):IntoElement {
        final curve:Float = metrics.radius;
        return canvas((_, _, _) -> null, (bounds, _, window, _) -> {
            final top = bounds.top();
            final bottom = bounds.bottom();
            final left = bounds.left();
            final right = bounds.right();
            final tabLeft = f32(left + curve);
            final tabRight = f32(right - curve);
            // Like Chrome, keep at least a third of the top flat on narrow tabs.
            final radius = Math.min(Math.max(f32(f32(bounds.size.width - f32(curve * 2.)) / 3.), 0.), curve);

            final path = PathBuilder.fill().withStyle(PathStyle.Fill(new FillOptions(0.02)));
            path.moveTo(point(left, bottom));
            quarterCircleTo(path, point(left, bottom), point(tabLeft, bottom), point(tabLeft, f32(bottom - curve)));
            path.lineTo(point(tabLeft, f32(top + radius)));
            quarterCircleTo(path, point(tabLeft, f32(top + radius)), point(tabLeft, top), point(f32(tabLeft + radius), top));
            path.lineTo(point(f32(tabRight - radius), top));
            quarterCircleTo(path, point(f32(tabRight - radius), top), point(tabRight, top), point(tabRight, f32(top + radius)));
            path.lineTo(point(tabRight, f32(bottom - curve)));
            quarterCircleTo(path, point(tabRight, f32(bottom - curve)), point(tabRight, bottom), point(right, bottom));
            path.close();
            final built = try path.build() catch (e:haxe.Exception) null;
            if (built != null) {
                window.paintPath(built, bg);
            }
        })
            .absolute()
            .top0()
            .bottom0()
            .left(glaze.Prelude.px(-curve))
            .right(glaze.Prelude.px(-curve));
    }

    /** Adds a quarter circle from `from` to `to`, whose tangents meet at `corner`. */
    static function quarterCircleTo(path:PathBuilder, from:Point, corner:Point, to:Point):Void {
        // Control point distance that makes a cubic Bezier a quarter circle.
        final k = f32(0.5522848);
        path.cubicBezierTo(
            to,
            point(f32(from.x + f32(f32(corner.x - from.x) * k)), f32(from.y + f32(f32(corner.y - from.y) * k))),
            point(f32(to.x + f32(f32(corner.x - to.x) * k)), f32(to.y + f32(f32(corner.y - to.y) * k)))
        );
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

}
