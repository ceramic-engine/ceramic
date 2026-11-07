// Ported from gpui-pre-wgpu 0.3.10: src/shaders.wgsl (vs_underline, fs_underline), with the
// alpha of gpui-pre-apple 0.3.10: src/shaders.metal (underline_fragment)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package shaders;

/**
 * GPUI underline primitive (also used for strikethrough): a straight line,
 * or a wavy line evaluated as a distance field.
 */
class GlazeUnderline extends Shader<GlazeUnderline_Vert, GlazeUnderline_Frag> {}

class GlazeUnderline_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /** Unit vertex: (0,0), (1,0), (0,1) or (1,1) */
    @in var vertexTCoord:Vec2;
    /** Line color (rgba, not premultiplied) */
    @in var vertexColor:Vec4;
    /** origin.xy, size.xy */
    @in var vertexBounds:Vec4;
    /** origin.xy, size.xy */
    @in var vertexContentMask:Vec4;
    /** thickness, wavy (0 or 1) */
    @in var vertexParams:Vec2;

    @out var scenePosition:Vec2;
    @out var clipDistances:Vec4;
    @out var color:Vec4;
    @out var bounds:Vec4;
    @out var params:Vec2;

    function main():Vec4 {

        var position:Vec2 = vertexTCoord * vertexBounds.zw + vertexBounds.xy;
        scenePosition = position;

        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        color = vertexColor;
        bounds = vertexBounds;
        params = vertexParams;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class GlazeUnderline_Frag extends Frag {

    @in var scenePosition:Vec2;
    @in var clipDistances:Vec4;
    @in var color:Vec4;
    @in var bounds:Vec4;
    @in var params:Vec2;

    /**
     * Fragment color. Kept out of `main()` because shade turns a nested
     * `return` in `main()` into a `fragColor` assignment without leaving it.
     */
    function fragmentColor():Vec4 {

        if (clipDistances.x < 0.0 || clipDistances.y < 0.0 || clipDistances.z < 0.0 || clipDistances.w < 0.0) {
            return vec4(0.0);
        }

        // Like GPUI's Metal shader (`underline_fragment`), the renderer of the
        // reference: the color with its own alpha, premultiplied here. The
        // WGSL shader (`blend_color(color, color.a)`) applies the alpha twice,
        // which makes a translucent underline (a link's) lighter than on macOS.
        if (params.y < 0.5) {
            var a:Float = color.a;
            return vec4(color.rgb * a, a);
        }

        var waveFrequency:Float = 2.0;
        var waveHeightRatio:Float = 0.8;

        var thickness:Float = params.x;
        var halfThickness:Float = thickness * 0.5;

        var st:Vec2 = (scenePosition - bounds.xy) / bounds.w - vec2(0.0, 0.5);
        var frequency:Float = 3.1415926 * waveFrequency * thickness / bounds.w;
        var amplitude:Float = (thickness * waveHeightRatio) / bounds.w;

        var sine:Float = sin(st.x * frequency) * amplitude;
        var dSine:Float = cos(st.x * frequency) * amplitude * frequency;
        var distance:Float = (st.y - sine) / sqrt(1.0 + dSine * dSine);
        var distanceInPixels:Float = distance * bounds.w;
        var distanceFromTopBorder:Float = distanceInPixels - halfThickness;
        var distanceFromBottomBorder:Float = distanceInPixels + halfThickness;
        var alpha:Float = clamp(0.5 - max(-distanceFromBottomBorder, distanceFromTopBorder), 0.0, 1.0);

        var wavyAlpha:Float = color.a * alpha;
        return vec4(color.rgb * wavyAlpha, wavyAlpha);

    }

    function main():Vec4 {

        return fragmentColor();

    }

}
