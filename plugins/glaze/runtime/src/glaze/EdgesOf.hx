// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Generic version of `Edges`, for non numeric values
 * (`Edges<Length>`, `Edges<DefiniteLength>`, `Edges<AbsoluteLength>`...).
 *
 * Methods that Rust defines on specific instantiations live in
 * `EdgesOfLength`, `EdgesOfDefiniteLength` and `EdgesOfAbsoluteLength`.
 * Their instance methods (like `toPixels`) are attached with `@:using`.
 *
 * Immutable: every operation returns a new instance.
 */
@:using(glaze.EdgesOfDefiniteLength, glaze.EdgesOfAbsoluteLength)
class EdgesOf<T> {

    /**
     * The value of the top edge.
     */
    public final top:T;

    /**
     * The value of the right edge.
     */
    public final right:T;

    /**
     * The value of the bottom edge.
     */
    public final bottom:T;

    /**
     * The value of the left edge.
     */
    public final left:T;

    public inline function new(top:T, right:T, bottom:T, left:T) {

        this.top = top;
        this.right = right;
        this.bottom = bottom;
        this.left = left;

    }

    /**
     * Edges where all sides are set to the same value.
     */
    public static inline function all<T>(value:T):EdgesOf<T> {

        return new EdgesOf<T>(value, value, value, value);

    }

    /**
     * Returns new edges with `f` applied to each side.
     */
    public inline function map<U>(f:(T) -> U):EdgesOf<U> {

        return new EdgesOf<U>(f(top), f(right), f(bottom), f(left));

    }

    /**
     * Returns numeric edges with `f` applied to each side.
     */
    public inline function mapToEdges(f:(T) -> Float):Edges {

        return new Edges(f(top), f(right), f(bottom), f(left));

    }

    /**
     * Checks if any of the sides satisfies the given predicate.
     */
    public inline function any(predicate:(T) -> Bool):Bool {

        return predicate(top) || predicate(right) || predicate(bottom) || predicate(left);

    }

    /**
     * Structural equality. `eq` compares two values (default: `==`).
     */
    public function equals(other:EdgesOf<T>, ?eq:(T, T) -> Bool):Bool {

        if (other == null) return false;
        if (eq == null) return top == other.top && right == other.right && bottom == other.bottom && left == other.left;
        return eq(top, other.top) && eq(right, other.right) && eq(bottom, other.bottom) && eq(left, other.left);

    }

    public function toString():String {

        return 'Edges(top: $top, right: $right, bottom: $bottom, left: $left)';

    }

}
