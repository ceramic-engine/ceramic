// Ported from gpui-kit 0.8.1: crates/base/src/progress.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.A11y;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An unstyled progress indicator: a stateful element with the
 * `ProgressIndicator` role and numeric accessibility values (0 to 100, none
 * while indeterminate), hosting a `ProgressTrack` and a `ProgressIndicator`.
 */
class Progress implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the progress renders (Rust delegates `InteractiveElement` to it). */
    public final base:Div;

    final progressStyle:StyleRefinement = new StyleRefinement();

    var valueValue:Float = 0.;

    var indeterminateValue:Bool = false;

    var accessibilityLabelValue:Null<String> = null;

    final childElements:Array<AnyElement> = [];

    /** The accessibility properties the progress exports (filled by `render`). */
    public final a11y:A11y = new A11y(Role.ProgressIndicator);

    public function new(id:ElementIdArg) {
        base = div().id(id);
    }

    /**
     * The value, clamped to 0..100.
     */
    public function value(value:Float):Progress {
        valueValue = value < 0. ? 0. : (value > 100. ? 100. : value);
        return this;
    }

    public function indeterminate(indeterminate:Bool):Progress {
        indeterminateValue = indeterminate;
        return this;
    }

    public function accessibilityLabel(label:String):Progress {
        accessibilityLabelValue = label;
        return this;
    }

    public inline function style():StyleRefinement {
        return progressStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Progress {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        a11y.label = accessibilityLabelValue;
        a11y.minNumericValue = 0.;
        a11y.maxNumericValue = 100.;
        a11y.numericValue = indeterminateValue ? null : valueValue;
        base.extend(childElements);
        return base.refineStyle(progressStyle);
    }

}

/**
 * An unstyled progress track.
 */
class ProgressTrack implements RenderOnce implements Styled implements ParentElement {

    final partStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** The element this part renders. */
    public function intoDiv():Div {
        final element = div();
        element.extend(childElements);
        return element.refineStyle(partStyle);
    }

    public function render(window:Window, cx:App):IntoElement {
        return intoDiv();
    }

}

/**
 * An unstyled progress indicator.
 */
class ProgressIndicator implements RenderOnce implements Styled implements ParentElement {

    final partStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    /** The element this part renders. */
    public function intoDiv():Div {
        final element = div();
        element.extend(childElements);
        return element.refineStyle(partStyle);
    }

    public function render(window:Window, cx:App):IntoElement {
        return intoDiv();
    }

}
