// Ported from gpui-kit 0.8.1: crates/base/src/tabs.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.Component;
import glaze.Div;
import glaze.ElementIdArg;
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
 * An unstyled tab that owns pointer activation and accessibility behavior.
 *
 * Tabs do not participate in keyboard focus by themselves. A compound tab
 * list may add keyboard navigation when that behavior is introduced.
 *
 * Rust `gpui_base::Tab`, renamed: `glaze.kit.base.Tab` is the Tab key action
 * of `glaze.kit.base.Root`.
 *
 * Interactive styles and listeners go to `base`.
 */
// TODO: Add compound keyboard navigation with roving focus, arrow keys,
// Home/End, and Enter/Space activation before treating Tabs as a complete
// desktop tab-list primitive.
class BaseTab extends Component implements Styled implements ParentElement {

    /** Updates the element identity used when the tab is rendered. */
    @prop var id:ElementIdArg;

    /** The element the tab renders. */
    public final base:Div;

    final tabStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:TabStyles = new TabStyles();

    @prop var selected:Bool = false;

    @prop var disabled:Bool = false;

    final childElements:Array<AnyElement> = [];

    @prop var onClick:Null<(ClickEvent, Window, App) -> Void> = null;

    @prop var accessibilityLabel:Null<String> = null;

    var positionInSet:Null<Int> = null;

    var sizeOfSet:Null<Int> = null;

    /** The accessibility properties the tab exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.Tab);

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
        base = div();
    }

    /**
     * Sets this tab's one-based position and the tab list's total size, so
     * assistive technology can announce "tab 2 of 5".
     */
    public function setPosition(position:Int, size:Int):BaseTab {
        positionInSet = position;
        sizeOfSet = size;
        return this;
    }

    public function styles(build:(TabStyles) -> TabStyles):BaseTab {
        semanticStyles = build(semanticStyles);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (selected) states.push(semanticStyles.selectedStyle);
        if (disabled) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(tabStyle, states);
    }

    public inline function style():StyleRefinement {
        return tabStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** Interactive style while hovered (on `base`). */
    public function hover(f:(StyleBuilder) -> StyleBuilder):BaseTab {
        base.hover(f);
        return this;
    }

    /** A mouse down listener (on `base`). */
    public function onMouseDown(button:MouseButton, listener:(MouseDownEvent, Window, App) -> Void):BaseTab {
        base.onMouseDown(button, listener);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final disabled = this.disabled;
        final style = resolvedStyle();

        final element = base.id(id)
            // Match Button's neutral control geometry: a fixed-size tab
            // centers ordinary content, while callers still own its size,
            // spacing and visual treatment.
            .flex()
            .itemsCenter()
            .justifyCenter()
            .lineHeight(glaze.Prelude.relative(1.));
        if (accessibilityLabel != null) a11y.label = accessibilityLabel;
        a11y.selected = selected;
        if (positionInSet != null) a11y.positionInSet = positionInSet;
        if (sizeOfSet != null) a11y.sizeOfSet = sizeOfSet;
        element.onMouseDown(Left, (_, _, cx) -> cx.stopPropagation());
        final onClick = this.onClick;
        if (!disabled && onClick != null) {
            a11y.clickable = true;
            element.onClick((event, window, cx) -> onClick(event, window, cx));
        }
        element.extend(childElements);
        element.refineStyle(style);
        a11y.disabled = disabled;
        return element;
    }

}

class TabStyles {

    @:allow(glaze.kit.base)
    final selectedStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    public function selected(build:(StateStyle) -> StateStyle):TabStyles {
        selectedStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

    public function disabled(build:(StateStyle) -> StateStyle):TabStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}

/**
 * An unstyled collection root for `BaseTab` elements.
 *
 * Controlled selection and activation are expressed directly by its child
 * tabs. The root supplies collection accessibility without introducing a
 * context hierarchy or new keyboard behavior.
 *
 * Interactive styles and listeners go to `base`.
 */
class Tabs extends Component implements Styled implements ParentElement {

    /** The stateful element the tab list renders. */
    public final base:Div;

    final tabsStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the tab list exports. */
    public final a11y:A11y = new A11y(Role.TabList);

    public function new(id:ElementIdArg) {
        super();
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return tabsStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** The hover group name (on `base`). */
    public function group(name:String):Tabs {
        base.group(name);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        base.extend(childElements);
        return base.refineStyle(tabsStyle);
    }

}
