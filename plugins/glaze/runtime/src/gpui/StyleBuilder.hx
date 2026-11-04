// Ported from gpui-pre 0.3.10: src/styled.rs (`impl Styled for StyleRefinement`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A `Styled` wrapper around a `StyleRefinement`, given to the closures of
 * `hover()`, `active()`, `focus()`, `groupHover()`, `dragOver()`...
 *
 * GPUI implements `Styled` on `StyleRefinement` itself and passes the
 * refinement by value: `div().hover(|s| s.bg(red()))`. In Haxe the fluent
 * method names (`opacity`, `borderColor`, `flexGrow`...) collide with the
 * fields of `StyleRefinement`, so the closures get this builder instead:
 * `div().hover(s -> s.bg(red()))` reads the same.
 */
class StyleBuilder implements Styled {

    final refinement:StyleRefinement;

    public function new(?refinement:StyleRefinement) {
        this.refinement = refinement != null ? refinement : new StyleRefinement();
    }

    public inline function style():StyleRefinement {
        return refinement;
    }

    /**
     * Runs `f` on a builder of a new refinement and returns the refinement.
     */
    public static function build(f:(StyleBuilder) -> StyleBuilder):StyleRefinement {
        return f(new StyleBuilder()).style();
    }

}
