// Ported from gpui-pre 0.3.10: src/color.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * The kind of a `Background`. The integer values match the ones read by the shaders.
 */
enum abstract BackgroundTag(Int) to Int {

    var Solid = 0;

    var LinearGradient = 1;

    var PatternSlash = 2;

    var Checkerboard = 3;

    public function toString():String {

        return switch (cast this:BackgroundTag) {
            case Solid: 'Solid';
            case LinearGradient: 'LinearGradient';
            case PatternSlash: 'PatternSlash';
            case Checkerboard: 'Checkerboard';
        }

    }

}
