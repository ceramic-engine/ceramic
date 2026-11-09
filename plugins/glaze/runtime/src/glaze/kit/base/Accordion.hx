// Ported from gpui-kit 0.8.1: crates/base/src/accordion.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.ParentElement;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled accordion root for application-owned items.
 *
 * Interactive styles and listeners go to `base` (Rust `InteractiveElement`
 * of the root forwards to it).
 */
class Accordion extends Component implements Styled implements ParentElement {

    /** The stateful element the accordion renders. */
    public final base:Div;

    final accordionStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the accordion exports. */
    public final a11y:A11y = new A11y(Role.Group);

    public function new(id:ElementIdArg) {
        super();
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return accordionStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Accordion {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Accordion {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function trackFocus(handle:FocusHandle):Accordion {
        base.trackFocus(handle);
        return this;
    }

    /** A click listener on the root (on `base`). */
    public function onClick(listener:(ClickEvent, Window, App) -> Void):Accordion {
        base.onClick(listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        base.extend(childElements);
        return base.refineStyle(accordionStyle);
    }

}

/**
 * An unstyled accordion item connecting one trigger with its panel content.
 */
class AccordionItem extends Component implements Styled implements ParentElement {

    final base:Div = div();

    final itemStyle:StyleRefinement = new StyleRefinement();

    @prop var open:Bool = false;

    @prop var disabled:Bool = false;

    @prop var header:Null<AccordionHeader> = null;

    @prop var panel:Null<AccordionPanel> = null;

    final childElements:Array<AnyElement> = [];

    public function new() {
        super();
    }

    public inline function style():StyleRefinement {
        return itemStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AccordionItem {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (header != null) {
            base.child(@:privateAccess header.setOpen(open).setDisabled(disabled));
        }
        if (panel != null) {
            base.child(panel.open(open));
        }
        base.extend(childElements);
        return base.refineStyle(itemStyle);
    }

}

/**
 * An unstyled heading that owns the trigger for one accordion item.
 */
class AccordionHeader extends Component implements Styled implements ParentElement {

    var headerId:Null<ElementId> = null;

    final headerStyle:StyleRefinement = new StyleRefinement();

    @prop var level:Int = 3;

    var trigger:AccordionTrigger;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the header exports (with an id only, filled by `render`). */
    public final a11y:A11y = new A11y();

    public function new(trigger:AccordionTrigger) {
        super();
        this.trigger = trigger;
    }

    public function id(id:ElementIdArg):AccordionHeader {
        headerId = id;
        return this;
    }

    function setOpen(open:Bool):AccordionHeader {
        trigger = trigger.open(open);
        return this;
    }

    function setDisabled(disabled:Bool):AccordionHeader {
        trigger = trigger.disabled(disabled);
        return this;
    }

    public inline function style():StyleRefinement {
        return headerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AccordionHeader {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final content = div()
            .child(trigger);
        content.extend(childElements);
        content.refineStyle(headerStyle);
        if (headerId != null) {
            a11y.role = Role.Heading;
            a11y.level = level;
            return content.id(headerId);
        }
        return content;
    }

}

/**
 * An unstyled accordion panel with controlled mounting.
 */
class AccordionPanel extends Component implements Styled implements ParentElement {

    var panelId:Null<ElementId> = null;

    final panelStyle:StyleRefinement = new StyleRefinement();

    @prop var open:Bool = false;

    @prop var keepMounted:Bool = false;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the panel exports (with an id only, filled by `render`). */
    public final a11y:A11y = new A11y();

    public function new() {
        super();
    }

    public function id(id:ElementIdArg):AccordionPanel {
        panelId = id;
        return this;
    }

    public inline function style():StyleRefinement {
        return panelStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AccordionPanel {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (!open && !keepMounted) {
            return new glaze.Empty();
        }

        final content = div();
        content.extend(childElements);
        content.refineStyle(panelStyle);
        if (panelId != null) {
            a11y.role = Role.Region;
            return content.id(panelId);
        }
        return content;
    }

}

/**
 * An unstyled accordion trigger with controlled expanded state.
 *
 * The application owns the title, disclosure icon, content, layout, and
 * animation. Activating the trigger requests the opposite of `open`.
 *
 * Interactive styles and listeners go to `base`.
 */
class AccordionTrigger extends Component implements Styled implements ParentElement {

    /** The stateful element the trigger renders. */
    public final base:Div;

    final triggerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    @prop var open:Bool = false;

    @prop var disabled:Bool = false;

    /**
     * Handles a requested change to the controlled expanded state.
     */
    @prop var onChange:Null<(Bool, ClickEvent, Window, App) -> Void> = null;

    /** The accessibility properties the trigger exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Button);

    public function new(id:ElementIdArg) {
        super();
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return triggerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AccordionTrigger {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):AccordionTrigger {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function trackFocus(handle:FocusHandle):AccordionTrigger {
        base.trackFocus(handle);
        return this;
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):AccordionTrigger {
        base.hover(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):AccordionTrigger {
        base.onMouseDown(button, listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final nextOpen = !open;

        a11y.expanded = open;
        final onChange = !disabled ? this.onChange : null;
        if (onChange != null) {
            a11y.clickable = true;
            base.onClick((event, window, cx) -> onChange(nextOpen, event, window, cx));
        }
        base.extend(childElements);
        return base.refineStyle(triggerStyle);
    }

}
