// Ported from gpui-pre 0.3.10: src/svg_renderer.rs (RenderSvgParams)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Parameters of an SVG rendered into the monochrome atlas (Rust
 * `RenderSvgParams`): the asset path and the size in device pixels.
 */
class RenderSvgParams {

    public final path:String;

    public final width:Int;

    public final height:Int;

    public function new(path:String, width:Int, height:Int) {
        this.path = path;
        this.width = width;
        this.height = height;
    }

}
