// Ported from gpui-kit 0.8.1: crates/base/src/state_style.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.StyleRefinement;
import gpui.Styled;

/**
 * A semantic-state style builder: GPUI's `Styled` methods on a refinement,
 * plus `when`.
 */
class StateStyle implements Styled {

    final refinement:StyleRefinement;

    public function new() {
        refinement = new StyleRefinement();
    }

    public inline function style():StyleRefinement {
        return refinement;
    }

    /**
     * Optionally applies `then` (Rust `FluentBuilder::when`).
     */
    public inline function when(condition:Bool, then:(StateStyle) -> StateStyle):StateStyle {
        return condition ? then(this) : this;
    }

    @:allow(gpui.base)
    function intoRefinement():StyleRefinement {
        return refinement;
    }

    /**
     * Resolves the final style of a control from its instance style and the
     * semantic-state styles that are currently active.
     *
     * The layering order is fixed for every Base control:
     *
     * 1. the instance style supplied through the `Styled` builder chain,
     * 2. value states such as `checked`, `pressed`, `selected`, or `focused`,
     * 3. `disabled`, which is always resolved last.
     *
     * Callers pass their active states in the order above; inactive states
     * are simply omitted.
     */
    public static function resolveStyle(instance:StyleRefinement, activeStates:Array<StyleRefinement>):StyleRefinement {
        final style = new StyleRefinement();
        style.refine(instance);
        for (state in activeStates) {
            style.refine(state);
        }
        return style;
    }

}
