// Ported from gpui-kit 0.8.1: crates/component/src/accordion.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified: deliberate deviation DEV-008 (on_toggle_click reported by the toggled item). See DEVIATIONS.md.
package glaze.kit.accordion;

import glaze.AnyElement;
import glaze.App;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Rems;
import glaze.RenderOnce;
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
class Accordion implements RenderOnce implements Styled implements Sizable {

    final id:ElementId;

    final accordionStyle:StyleRefinement = new StyleRefinement();

    var multipleValue:Bool = false;

    var size:Size = Medium;

    var borderedValue:Bool = true;

    var disabledValue:Bool = false;

    final items:Array<AccordionItem> = [];

    var onToggleClickHandler:Null<(Array<Int>, Window, App) -> Void> = null;

    /**
     * Create a new Accordion with the given ID.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Set whether multiple accordion items can be opened simultaneously, default: false
     */
    public function multiple(multiple:Bool):Accordion {
        multipleValue = multiple;
        return this;
    }

    /**
     * Set whether the accordion items have borders, default: true
     */
    public function bordered(bordered:Bool):Accordion {
        borderedValue = bordered;
        return this;
    }

    /**
     * Set whether the accordion is disabled, default: false
     */
    public function disabled(disabled:Bool):Accordion {
        disabledValue = disabled;
        return this;
    }

    /**
     * Adds an AccordionItem to the Accordion.
     */
    public function item(child:(AccordionItem) -> AccordionItem):Accordion {
        items.push(child(new AccordionItem()));
        return this;
    }

    /**
     * Sets the on_toggle_click callback for the AccordionGroup.
     *
     * The first argument is the indices of the open accordions. Rust collects
     * them from a `HashSet`, whose order is unspecified; the port keeps the
     * order in which they were opened.
     */
    public function onToggleClick(onToggleClick:(Array<Int>, Window, App) -> Void):Accordion {
        onToggleClickHandler = onToggleClick;
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
        final multiple = multipleValue;
        final lastIx = items.length > 0 ? items.length - 1 : 0;
        // Deliberate deviation DEV-008: reported by the item that toggled, not
        // by a click anywhere on the accordion (the original's root `on_click`).
        final onToggle = disabledValue ? null : onToggleClickHandler;

        final root = new glaze.kit.base.Accordion(id)
            .vFlex()
            .sizeFull();
        // The bordered accordion is a single rounded card, the items are
        // joined by their separators.
        if (borderedValue) {
            root.border1()
                .borderColor(theme.border)
                .rounded(theme.radiusLg)
                .overflowHidden();
        }
        root.refineStyle(accordionStyle);
        for (ix in 0...items.length) {
            final accordion = items[ix];
            if (accordion.openValue) {
                if (openIndices.indexOf(ix) == -1) openIndices.push(ix);
            }
            final disabled = disabledValue || accordion.disabledValue;

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
class AccordionItem implements RenderOnce implements Styled implements ParentElement implements Sizable {

    var indexValue:Int = 0;

    var lastValue:Bool = false;

    final itemStyle:StyleRefinement = new StyleRefinement();

    var hoverStyle:Null<StyleRefinement> = null;

    var titleStyleValue:StyleRefinement = new StyleRefinement();

    var contentStyleValue:StyleRefinement = new StyleRefinement();

    var iconValue:Null<Icon> = null;

    var titleValue:AnyElement = ('' : IntoElement);

    final childElements:Array<AnyElement> = [];

    @:allow(glaze.kit.accordion)
    var openValue:Bool = false;

    var size:Size = Medium;

    @:allow(glaze.kit.accordion)
    var disabledValue:Bool = false;

    var onToggleClickHandler:Null<(Bool, Window, App) -> Void> = null;

    /**
     * Create a new AccordionItem.
     */
    public function new() {}

    /**
     * Set the icon for the accordion item.
     */
    public function icon(icon:IntoIcon):AccordionItem {
        iconValue = icon;
        return this;
    }

    /**
     * Set the title for the accordion item.
     */
    public function title(title:IntoElement):AccordionItem {
        titleValue = title;
        return this;
    }

    public function open(open:Bool):AccordionItem {
        openValue = open;
        return this;
    }

    public function disabled(disabled:Bool):AccordionItem {
        disabledValue = disabled;
        return this;
    }

    /**
     * Set extra style for the title row.
     */
    public function titleStyle(style:StyleRefinement):AccordionItem {
        titleStyleValue = style;
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

    /**
     * Set extra style for the content below the title.
     */
    public function contentStyle(style:StyleRefinement):AccordionItem {
        contentStyleValue = style;
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
            openValue ? 1. : 0.,
            theme.motionTokens().springControl,
            window,
            cx
        );
        final trigger = new AccordionTrigger(ElementId.NamedInteger('trigger', indexValue))
            .open(openValue)
            .disabled(disabledValue)
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
        if (openValue) trigger.textColor(theme.foreground);
        trigger.refineStyle(titleStyleValue);
        final title = hFlex()
            .flex1()
            .minW0()
            .itemsCenter();
        switch size {
            case XSmall | Small: title.gap1();
            case _: title.gap2();
        }
        if (iconValue != null) title.child(iconValue.withSize(size));
        title.child(titleValue);
        trigger.child(title);
        if (!disabledValue) {
            final hoverStyle = this.hoverStyle;
            if (hoverStyle != null) {
                trigger.hover(s -> s.refineStyle(hoverStyle));
            }
            trigger.child(new Icon(IconName.ChevronDown)
                .xsmall()
                .flexNone()
                .textColor(theme.mutedForeground)
                .rotate(percentage(openValue ? 0.5 : 0.)));
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
        content.refineStyle(contentStyleValue);
        content.extend(childElements);

        final item = new BaseAccordionItem()
            .open(openValue)
            .disabled(disabledValue)
            .header(new BaseAccordionHeader(trigger)
                .id(ElementId.NamedInteger('header', indexValue))
                .wFull())
            .panel(new BaseAccordionPanel()
                .id(ElementId.NamedInteger('panel', indexValue))
                .open(openValue)
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
