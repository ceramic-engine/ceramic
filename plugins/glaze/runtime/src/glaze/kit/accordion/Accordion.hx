// Ported from gpui-kit 0.8.1: crates/component/src/accordion.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-008 (on_toggle_click reported by the toggled item). See docs/DEVIATIONS.md.
package glaze.kit.accordion;

import glaze.AnyElement;
import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Rems;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Accordion.AccordionHeader as BaseAccordionHeader;
import glaze.kit.base.Accordion.AccordionItem as BaseAccordionItem;
import glaze.kit.base.Accordion.AccordionPanel as BaseAccordionPanel;
import glaze.kit.base.Accordion.AccordionTrigger;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.MotionReveal;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Accordion element.
 */
class Accordion extends Component implements Styled implements Sizable {

    final id:ElementId;

    final accordionStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set whether multiple accordion items can be opened simultaneously, default: false
     */
    @prop var multiple:Bool = false;

    var size:Size = Medium;

    /**
     * Set whether the accordion items have borders, default: true
     */
    @prop var bordered:Bool = true;

    /**
     * Set whether the accordion is disabled, default: false
     */
    @prop var disabled:Bool = false;

    final items:Array<AccordionItem> = [];

    /**
     * Sets the on_toggle_click callback for the AccordionGroup.
     *
     * The first argument is the indices of the open accordions. Rust collects
     * them from a `HashSet`, whose order is unspecified; the port keeps the
     * order in which they were opened.
     */
    @prop var onToggleClick:Null<(Array<Int>, Window, App) -> Void> = null;

    /**
     * Create a new Accordion with the given ID.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    /**
     * Adds an AccordionItem to the Accordion.
     */
    public function item(child:(AccordionItem) -> AccordionItem):Accordion {
        items.push(child(AccordionItem.component()));
        return this;
    }

    public function withSize(size:IntoSize):Accordion {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return accordionStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final openIndices:Array<Int> = [];
        final multiple = this.multiple;
        final lastIx = items.length > 0 ? items.length - 1 : 0;
        // Initial port deviation DEV-008: reported by the item that toggled, not
        // by a click anywhere on the accordion (the original's root `on_click`).
        final onToggle = this.disabled ? null : onToggleClick;

        final root = glaze.kit.base.Accordion.component(id)
            .vFlex()
            .sizeFull();
        // The bordered accordion is a single rounded card, the items are
        // joined by their separators.
        if (bordered) {
            root.border1()
                .borderColor(theme.border)
                .rounded(theme.radiusLg)
                .overflowHidden();
        }
        root.refineStyle(accordionStyle);
        for (ix in 0...items.length) {
            final accordion = items[ix];
            if (accordion.openProp) {
                if (openIndices.indexOf(ix) == -1) openIndices.push(ix);
            }
            final disabled = this.disabled || accordion.disabledProp;

            root.child(accordion
                .index(ix)
                .last(ix == lastIx)
                .withSize(size)
                .disabled(disabled)
                .onToggleClick((open, window, cx) -> {
                    if (open) {
                        if (!multiple) {
                            openIndices.resize(0);
                        }
                        if (openIndices.indexOf(ix) == -1) openIndices.push(ix);
                    } else {
                        openIndices.remove(ix);
                    }
                    if (onToggle != null) {
                        onToggle(openIndices.copy(), window, cx);
                    }
                }));
        }
        return root;
    }

}

/**
 * An Accordion is a vertically stacked list of items, each of which can be
 * expanded to reveal the content associated with it.
 */
class AccordionItem extends Component implements Styled implements ParentElement implements Sizable {

    var indexValue:Int = 0;

    var lastValue:Bool = false;

    final itemStyle:StyleRefinement = new StyleRefinement();

    var hoverStyle:Null<StyleRefinement> = null;

    /**
     * Set extra style for the title row.
     */
    @prop var titleStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set extra style for the content below the title.
     */
    @prop var contentStyle:StyleRefinement = new StyleRefinement();

    @prop var icon:Null<Icon> = null;

    @prop var title:AnyElement = ('' : IntoElement);

    final childElements:Array<AnyElement> = [];

    @:allow(glaze.kit.accordion)
    @prop var open:Bool = false;

    var size:Size = Medium;

    @:allow(glaze.kit.accordion)
    @prop var disabled:Bool = false;

    var onToggleClickHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Create a new AccordionItem.
     */
    public function new() {
        super();
    }

    /**
     * Set the icon for the accordion item.
     */
    public function icon(icon:IntoIcon):AccordionItem {
        this.icon = icon;
        return this;
    }

    /**
     * Set the title for the accordion item.
     */
    public function title(title:IntoElement):AccordionItem {
        this.title = title;
        return this;
    }

    /**
     * Set the style of the title row while the mouse is over it.
     *
     * There is no hover style by default. The title row is the part that
     * toggles the item, so the hover feedback belongs there, not on the
     * whole item.
     */
    public function hover(f:(StyleBuilder) -> StyleBuilder):AccordionItem {
        hoverStyle = StyleBuilder.build(f);
        return this;
    }

    @:allow(glaze.kit.accordion)
    function index(index:Int):AccordionItem {
        indexValue = index;
        return this;
    }

    @:allow(glaze.kit.accordion)
    function last(last:Bool):AccordionItem {
        lastValue = last;
        return this;
    }

    @:allow(glaze.kit.accordion)
    function onToggleClick(onToggleClick:(Bool, Window, App) -> Void):AccordionItem {
        onToggleClickHandler = onToggleClick;
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AccordionItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):AccordionItem {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function withSize(size:IntoSize):AccordionItem {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final textSize:Rems = switch size {
            case XSmall: rems(0.75);
            case Large: rems(1.0);
            case _: rems(0.875);
        };
        final progress = Motion.spring(
            TransitionId.named(indexValue, 'accordion-panel'),
            this.open ? 1. : 0.,
            theme.motionTokens().springControl,
            window,
            cx
        );
        final trigger = AccordionTrigger.component(ElementId.NamedInteger('trigger', indexValue))
            .open(this.open)
            .disabled(disabled)
            .hFlex()
            .justifyBetween()
            .gap3()
            .fontMedium();
        switch size {
            case XSmall: trigger.py1().px1p5();
            case Small: trigger.py1p5().px2();
            case Large: trigger.py3().px4();
            case _: trigger.py2().px3();
        }
        if (this.open) trigger.textColor(theme.foreground);
        trigger.refineStyle(titleStyle);
        final title = hFlex()
            .flex1()
            .minW0()
            .itemsCenter();
        switch size {
            case XSmall | Small: title.gap1();
            case _: title.gap2();
        }
        if (icon != null) title.child(icon.withSize(size));
        title.child(this.title);
        trigger.child(title);
        if (!disabled) {
            final hoverStyle = this.hoverStyle;
            if (hoverStyle != null) {
                trigger.hover(s -> s.refineStyle(hoverStyle));
            }
            trigger.child(Icon.component(IconName.ChevronDown)
                .xsmall()
                .flexNone()
                .textColor(theme.mutedForeground)
                .rotate(percentage(this.open ? 0.5 : 0.)));
            final onToggleClick = onToggleClickHandler;
            if (onToggleClick != null) {
                trigger.onChange((open, _, window, cx) -> {
                    onToggleClick(open, window, cx);
                });
            }
        }

        final content = div();
        switch size {
            case XSmall: content.pb1().px1p5();
            case Small: content.pb1p5().px2();
            case Large: content.pb3().px4();
            case _: content.pb2().px3();
        }
        content.refineStyle(contentStyle);
        content.extend(childElements);

        final item = new BaseAccordionItem()
            .open(this.open)
            .disabled(disabled)
            .header(new BaseAccordionHeader(trigger)
                .id(ElementId.NamedInteger('header', indexValue))
                .wFull())
            .panel(new BaseAccordionPanel()
                .id(ElementId.NamedInteger('panel', indexValue))
                .open(this.open)
                // Mounted while the reveal moves; a settled closed panel
                // unmounts, so its content costs no layout or paint. A
                // settled spring returns exactly 0, and `!=` keeps a
                // bouncy theme spring mounted while it dips below 0.
                // Reduced motion reopens straight to full progress, which
                // needs the reveal's height from a mounted frame.
                .keepMounted(progress != 0. || cx.reduceMotion())
                .wFull()
                .child(new MotionReveal(
                    ElementId.NamedInteger('content', indexValue),
                    progress,
                    content
                )))
            .vFlex()
            .wFull()
            .bg(theme.tokens.accordion.background)
            .overflowHidden();
        if (!lastValue) {
            item.borderB1().borderColor(theme.border);
        }
        item.textSize(textSize)
            .refineStyle(itemStyle);

        return div().flex1().child(item);
    }

}
