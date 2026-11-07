// Ported from gpui-pre 0.3.10: src/styled.rs (`impl Styled for StyleRefinement`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

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

    /** Changed only by `StyleSized`'s shared builder (`StyleBuilder.over()`) */
    var refinement:StyleRefinement;

    public function new(?refinement:StyleRefinement) {
        this.refinement = refinement != null ? refinement : new StyleRefinement();
    }

    public inline function style():StyleRefinement {
        return refinement;
    }

    /**
     * A builder over `refinement` that is only used right away (one chain of
     * calls): the same object every time. Internal (`StyleSized`).
     */
    @:noCompletion
    public static function over(refinement:StyleRefinement):StyleBuilder {
        var builder = sharedBuilder;
        if (builder == null) {
            builder = new StyleBuilder(refinement);
            sharedBuilder = builder;
        }
        builder.refinement = refinement;
        return builder;
    }

    static var sharedBuilder:Null<StyleBuilder> = null;

    /**
     * Runs `f` on a builder of a new refinement and returns the refinement.
     */
    public static function build(f:(StyleBuilder) -> StyleBuilder):StyleRefinement {
        return f(new StyleBuilder()).style();
    }

}
