// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.AnyElement;
import gpui.App;
import gpui.Div;
import gpui.ElementIdArg;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.StateStyle;

import gpui.Prelude.*;

using gpui.base.A11y.RoleOverrideTools;
using gpui.base.StyledExt;

/**
 * The foundational input frame.
 *
 * It intentionally owns only input semantics, interaction forwarding, and
 * normal children. Applications remain responsible for all presentation.
 *
 * Interactive styles and listeners go to `base` (the stateful element the
 * frame renders, Rust `InteractiveElement::interactivity`).
 */
class InputBase implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the frame renders. */
    public final base:Div;

    final frameStyle:StyleRefinement = new StyleRefinement();

    var semanticStyles:InputStyles = new InputStyles();

    final childElements:Array<AnyElement> = [];

    var focusedValue:Bool = false;

    var disabledValue:Bool = false;

    var roleValue:RoleOverride = Implicit;

    /** The accessibility properties the frame exports (filled by `render`). */
    public final a11y:A11y = new A11y();

    public function new(id:ElementIdArg) {
        this.base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return frameStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):InputBase {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):InputBase {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function role(role:RoleOverride):InputBase {
        roleValue = role;
        return this;
    }

    public function focused(focused:Bool):InputBase {
        focusedValue = focused;
        return this;
    }

    public function disabled(disabled:Bool):InputBase {
        disabledValue = disabled;
        return this;
    }

    /**
     * Exposes an editor's native semantics through this frame's component ID.
     *
     * This only declares an observation relationship with gpui-kit's
     * `test-support` layer, which is not ported (see `gpui.base.Observe`):
     * like a build without that feature, it changes nothing.
     */
    public function semanticOwner(editor:Int):InputBase {
        return this;
    }

    public function styles(build:(InputStyles) -> InputStyles):InputBase {
        semanticStyles = build(semanticStyles);
        return this;
    }

    public function accessibilityLabel(label:String):InputBase {
        a11y.label = label;
        return this;
    }

    public function trackFocus(focus:FocusHandle):InputBase {
        base.trackFocus(focus);
        return this;
    }

    @:allow(tests)
    function resolvedStyle():StyleRefinement {
        final states = [];
        if (focusedValue) states.push(semanticStyles.focusedStyle);
        if (disabledValue) states.push(semanticStyles.disabledStyle);
        return StateStyle.resolveStyle(frameStyle, states);
    }

    public function render(window:Window, cx:App):IntoElement {
        final style = resolvedStyle();
        // `Role::TextInput` (not declared by `gpui.base.A11y.Role` yet).
        final role = roleValue.resolve(() -> (cast 'textInput' : Role));
        if (role != null) a11y.role = role;
        base.extend(childElements);
        return base.refineStyle(style);
    }

}

/**
 * Semantic root styles supported by `InputBase`.
 */
class InputStyles {

    @:allow(gpui.base.input)
    final focusedStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.base.input)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    public function focused(build:(StateStyle) -> StateStyle):InputStyles {
        focusedStyle.refine(@:privateAccess build(new StateStyle()).intoRefinement());
        return this;
    }

    public function disabled(build:(StateStyle) -> StateStyle):InputStyles {
        disabledStyle.refine(@:privateAccess build(new StateStyle()).intoRefinement());
        return this;
    }

}
