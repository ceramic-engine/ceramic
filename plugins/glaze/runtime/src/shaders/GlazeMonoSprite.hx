// Ported from gpui-pre-wgpu 0.3.10: src/shaders.wgsl (vs_mono_sprite, fs_mono_sprite and gamma helpers)
// and gpui-pre-apple 0.3.10: src/shaders.metal (monochrome_sprite_fragment, the default)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
// Contrast and gamma correction adapted by GPUI from Windows Terminal,
// Copyright (c) Microsoft Corporation, licensed under MIT.
package shaders;

/**
 * GPUI monochrome sprite primitive: a coverage mask from an atlas (glyph or
 * tinted SVG icon), colored with a solid color, with the optional
 * DirectWrite style contrast and gamma correction of GPUI's WGSL shader.
 *
 * Text gamma and contrast: GPUI's Metal shader (`monochrome_sprite_fragment`
 * in gpui-pre-apple's shaders.metal, the renderer of macOS) multiplies the
 * color alpha by the coverage as is, while its WGSL shader applies this
 * correction. The port follows Metal by default: `SceneRenderable` passes
 * `gammaRatios` for a gamma of 1.0 (all zero) and a contrast of 0, which
 * makes `enhanceContrast()` and `applyAlphaCorrection()` return the coverage
 * unchanged. Setting `fontsGamma` / `grayscaleEnhancedContrast` gives the
 * WGSL look.
 *
 * The atlas stores coverage in the alpha channel. Positions (and the
 * optional sprite transformation) are resolved on the CPU side: the vertex
 * gives its world position, its scene position (for the content mask) and
 * its atlas texture coordinates.
 *
 * Paths have their own shader, `GlazePathSprite`.
 */
class GlazeMonoSprite extends Shader<GlazeMonoSprite_Vert, GlazeMonoSprite_Frag> {}

class GlazeMonoSprite_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /** Atlas texture coordinates */
    @in var vertexTCoord:Vec2;
    /** Sprite color (rgba, not premultiplied) */
    @in var vertexColor:Vec4;
    /** Position of this vertex in scene units, after transformation */
    @in var vertexScenePosition:Vec2;
    /** origin.xy, size.xy */
    @in var vertexContentMask:Vec4;

    @out var tcoord:Vec2;
    @out var color:Vec4;
    @out var clipDistances:Vec4;

    function main():Vec4 {

        var position:Vec2 = vertexScenePosition;
        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        tcoord = vertexTCoord;
        color = vertexColor;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class GlazeMonoSprite_Frag extends Frag {

    @param var mainTex:Sampler2D;
    /** See `get_gamma_correction_ratios()` in GPUI's platform.rs */
    @param var gammaRatios:Vec4;
    @param var grayscaleEnhancedContrast:Float;

    @in var tcoord:Vec2;
    @in var color:Vec4;
    @in var clipDistances:Vec4;

    /** REC. 601 luminance coefficients for perceived brightness */
    function colorBrightness(c:Vec3):Float {
        return dot(c, vec3(0.30, 0.59, 0.11));
    }

    function lightOnDarkContrast(enhancedContrast:Float, c:Vec3):Float {
        var brightness:Float = colorBrightness(c);
        var multiplier:Float = clamp(4.0 * (0.75 - brightness), 0.0, 1.0);
        return enhancedContrast * multiplier;
    }

    function enhanceContrast(alpha:Float, k:Float):Float {
        return alpha * (k + 1.0) / (alpha * k + 1.0);
    }

    function applyAlphaCorrection(a:Float, b:Float, g:Vec4):Float {
        var brightnessAdjustment:Float = g.x * b + g.y;
        var correction:Float = brightnessAdjustment * a + (g.z * b + g.w);
        return a + a * (1.0 - a) * correction;
    }

    /**
     * Fragment color. Kept out of `main()` because shade turns a nested
     * `return` in `main()` into a `fragColor` assignment without leaving it.
     */
    function fragmentColor():Vec4 {

        var texel:Vec4 = texture(mainTex, tcoord);
        var texSample:Float = texel.a;

        if (clipDistances.x < 0.0 || clipDistances.y < 0.0 || clipDistances.z < 0.0 || clipDistances.w < 0.0) {
            return vec4(0.0);
        }

        var enhancedContrast:Float = lightOnDarkContrast(grayscaleEnhancedContrast, color.rgb);
        var brightness:Float = colorBrightness(color.rgb);
        var contrasted:Float = enhanceContrast(texSample, enhancedContrast);
        var alphaCorrected:Float = applyAlphaCorrection(contrasted, brightness, gammaRatios);

        // Premultiplied output
        var a:Float = color.a * alphaCorrected;
        return vec4(color.rgb * a, a);

    }

    function main():Vec4 {

        return fragmentColor();

    }

}
