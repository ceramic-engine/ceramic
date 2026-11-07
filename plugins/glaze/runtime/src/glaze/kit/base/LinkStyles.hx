// Ported from gpui-kit 0.8.1: crates/base/src/link.rs (LinkStyles)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.StyleRefinement;

/**
 * Semantic-state styles of a `Link`.
 */
class LinkStyles {

    @:allow(glaze.kit.base)
    final disabledStyle:StyleRefinement = new StyleRefinement();

    public function new() {}

    /**
     * Style applied while the link is disabled (resolved after the instance style).
     */
    public function disabled(build:(StateStyle) -> StateStyle):LinkStyles {
        disabledStyle.refine(build(new StateStyle()).intoRefinement());
        return this;
    }

}
