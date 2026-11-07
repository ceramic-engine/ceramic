// Ported from gpui-pre-apple 0.3.10: src/shaders.metal (path_rasterization_fragment,
// path_sprite_fragment, prepare_fill_color, fill_color)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Metal to Haxe for Ceramic. See NOTICE.md.
package shaders;

/**
 * GPUI path primitive: a coverage tile of the atlas (see
 * `glaze.PathRasterizer`) filled with the path's `Background` (solid color,
 * linear gradient, slash pattern or checkerboard).
 *
 * GPUI's Metal renderer runs `path_rasterization_fragment` once per pixel
 * of a 4x MSAA intermediate texture: it computes the background color at
 * the pixel center with `fill_color()` (the same function as quads, with
 * the path bounds clipped by the content mask as bounds), writes the
 * premultiplied color to each covered sample (8 bits per channel), and the
 * texture is resolved (mean of the samples, rounded) then copied by
 * `path_sprite_fragment`. This shader evaluates the same color at the same
 * pixel centers (scene device pixels, like GPUI's intermediate texture) and
 * reproduces the storage and the resolve (`pathColor()`,
 * `pathCurveColor()`).
 *
 * The gradient math is the one of `GlazeQuad` (Metal's `fill_color`).
 *
 * Compact variant of `GlazePathSprite`, used only when the GPU limits are
 * too low for it (see `glaze.platform.SceneRenderable.useCompactShaders`):
 * 8 vertex attributes. The first gradient stop replaces the solid color and
 * the stop percentages travel with the scene position.
 */
class GlazePathSpriteCompact extends Shader<GlazePathSpriteCompact_Vert, GlazePathSpriteCompact_Frag> {}

class GlazePathSpriteCompact_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /** Atlas texture coordinates */
    @in var vertexTCoord:Vec2;
    /** Solid color, or first gradient stop color (rgba, not premultiplied) */
    @in var vertexColor:Vec4;
    /**
     * xy: position of this vertex in scene units, zw: first and second
     * gradient stop percentages
     */
    @in var vertexScenePosition:Vec4;
    /** origin.xy, size.xy */
    @in var vertexContentMask:Vec4;
    /** Path bounds clipped by the content mask: origin.xy, size.xy */
    @in var vertexBounds:Vec4;
    /** background tag, color space, gradient angle or pattern height */
    @in var vertexParams:Vec3;
    /** Second gradient stop color (rgba) */
    @in var vertexColor1:Vec4;

    @out var tcoord:Vec2;
    @out var scenePosition:Vec2;
    @out var clipDistances:Vec4;
    @out var bounds:Vec4;
    @out var params:Vec3;
    /** Solid color, or first gradient stop color */
    @out var backgroundColor0:Vec4;
    @out var backgroundColor1:Vec4;
    @out var stops:Vec2;

    /** Same approximation as GPUI's Metal shader */
    function srgbToLinear(c:Vec3):Vec3 {
        return pow(c, vec3(2.2));
    }

    function srgbToOklab(color:Vec4):Vec4 {
        var lin:Vec3 = srgbToLinear(color.rgb);

        var l:Float = 0.4122214708 * lin.r + 0.5363325363 * lin.g + 0.0514459929 * lin.b;
        var m:Float = 0.2119034982 * lin.r + 0.6806995451 * lin.g + 0.1073969566 * lin.b;
        var s:Float = 0.0883024619 * lin.r + 0.2817188376 * lin.g + 0.6299787005 * lin.b;

        var l_:Float = pow(l, 1.0 / 3.0);
        var m_:Float = pow(m, 1.0 / 3.0);
        var s_:Float = pow(s, 1.0 / 3.0);

        return vec4(
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
            color.a
        );
    }

    function main():Vec4 {

        var position:Vec2 = vertexScenePosition.xy;
        scenePosition = position;

        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        tcoord = vertexTCoord;
        bounds = vertexBounds;
        params = vertexParams;
        stops = vertexScenePosition.zw;

        // prepare_fill_color() (Metal)
        backgroundColor0 = vertexColor;
        backgroundColor1 = vertexColor1;
        if (vertexParams.x > 0.5 && vertexParams.x < 1.5 && vertexParams.y > 0.5) {
            backgroundColor0 = srgbToOklab(vertexColor);
            backgroundColor1 = srgbToOklab(vertexColor1);
        }

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

/**
 * Unity (`shade_unity`): Metal compiles Unity's shaders with fast math, like
 * ANGLE's code of the web build, but with `preserveInvariance` (Unity's
 * vertex shaders declare an invariant position), which changes how the
 * compiler rewrites some expressions. Two spots are written for Unity so
 * that the bits match the web: the dither noise (`fract()` spelled out and
 * multiplied by `min(pathCoverage, 1.0)`, a uniform equal to 1 that the
 * compiler cannot fold, so it keeps the sum of the two noises as written)
 * and the cosine of the slash pattern (the constant ANGLE's compiler folds,
 * one ulp from the one FXC folds). Measured with Metal kernels of both
 * compiled shaders on random inputs, then on the Unity golden.
 */
class GlazePathSpriteCompact_Frag extends Frag {

    @param var mainTex:Sampler2D;
    /**
     * 1 for plain coverage tiles (the mask is the mean of 4 MSAA samples),
     * 2 for paths with Loop-Blinn curves (RGBA tiles, see
     * `glaze.PathRasterizer.rasterizeCurves()`).
     */
    @param var pathCoverage:Float;

    @in var tcoord:Vec2;
    @in var scenePosition:Vec2;
    @in var clipDistances:Vec4;
    @in var bounds:Vec4;
    @in var params:Vec3;
    @in var backgroundColor0:Vec4;
    @in var backgroundColor1:Vec4;
    @in var stops:Vec2;

    function truncf(x:Float):Float {
        return sign(x) * floor(abs(x));
    }

    /** Remainder with the sign of the dividend (Metal `fmod`) */
    function fmodf(a:Float, b:Float):Float {
        return a - b * truncf(a / b);
    }

    /** Same approximation as GPUI's Metal shader */
    function linearToSrgb(c:Vec3):Vec3 {
        return pow(c, vec3(1.0 / 2.2));
    }

    function oklabToSrgb(color:Vec4):Vec4 {
        var l_:Float = color.r + 0.3963377774 * color.g + 0.2158037573 * color.b;
        var m_:Float = color.r - 0.1055613458 * color.g - 0.0638541728 * color.b;
        var s_:Float = color.r - 0.0894841775 * color.g - 1.2914855480 * color.b;

        var l:Float = l_ * l_ * l_;
        var m:Float = m_ * m_ * m_;
        var s:Float = s_ * s_ * s_;

        var lin:Vec3 = vec3(
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        );

        return vec4(linearToSrgb(lin), color.a);
    }

    /** `fill_color()` of GPUI's Metal shader (same code as `GlazeQuad`) */
    function fillColor(position:Vec2):Vec4 {

        var tag:Float = params.x;
        var backgroundColor:Vec4 = backgroundColor0;
        var origin:Vec2 = bounds.xy;
        var size:Vec2 = bounds.zw;

        if (tag > 0.5 && tag < 1.5) {
            // Linear gradient, -90 degrees to match the CSS gradient angle
            var angle:Float = params.z;
            var rad:Float = (fmodf(angle, 360.0) - 90.0) * 3.1415926 / 180.0;
            var direction:Vec2 = vec2(cos(rad), sin(rad));

            // Expand the short side to be the same as the long side
            if (size.x > size.y) {
                direction.y *= size.y / size.x;
            }
            else {
                direction.x *= size.x / size.y;
            }

            var halfSize:Vec2 = size / 2.0;
            var center:Vec2 = origin + halfSize;
            var centerToPoint:Vec2 = position - center;
            var t:Float = dot(centerToPoint, direction) / length(direction);
            if (abs(direction.x) > abs(direction.y)) {
                t = (t + halfSize.x) / size.x;
            }
            else {
                t = (t + halfSize.y) / size.y;
            }

            t = (t - stops.x) / (stops.y - stops.x);
            t = clamp(t, 0.0, 1.0);

            if (params.y < 0.5) {
                backgroundColor = mix(backgroundColor0, backgroundColor1, t);
            }
            else {
                backgroundColor = oklabToSrgb(mix(backgroundColor0, backgroundColor1, t));
            }

            // Dither to reduce banding in gradients (triangular noise, like GPUI's Metal shader)
            var seed:Vec2 = position * 0.6180339887;
            #if shade_unity
            var s1:Float = sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453;
            var s2:Float = sin(dot(seed, vec2(39.3460, 11.135))) * 24634.6345;
            var r1:Float = min(s1 - floor(s1), 0.99999994039535522) * min(pathCoverage, 1.0);
            var r2:Float = min(s2 - floor(s2), 0.99999994039535522) * min(pathCoverage, 1.0);
            #else
            var r1:Float = fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
            var r2:Float = fract(sin(dot(seed, vec2(39.3460, 11.135))) * 24634.6345);
            #end
            var tri:Float = r1 + r2 - 1.0;
            backgroundColor.rgb += vec3(tri * 2.0 / 255.0);
            backgroundColor.a += tri * 3.0 / 255.0;
        }
        else if (tag > 1.5 && tag < 2.5) {
            // Pattern slash
            var heightParam:Float = params.z;
            var patternWidth:Float = (heightParam / 65535.0) / 255.0;
            var patternInterval:Float = fmodf(heightParam, 65535.0) / 255.0;
            var patternHeight:Float = patternWidth + patternInterval;
            var stripeAngle:Float = 3.1415926 / 4.0;
            var patternPeriod:Float = patternHeight * sin(stripeAngle);
            var relativePosition:Vec2 = position - origin;
            // Metal float2x2(c, -s, s, c) is column-major
            #if shade_unity
            var rotatedX:Float = 0.70710676908493042 * relativePosition.x + sin(stripeAngle) * relativePosition.y;
            #else
            var rotatedX:Float = cos(stripeAngle) * relativePosition.x + sin(stripeAngle) * relativePosition.y;
            #end
            var pattern:Float = fmodf(rotatedX, patternPeriod);
            var distance:Float = min(pattern, patternPeriod - pattern) - patternPeriod * (patternWidth / patternHeight) / 2.0;
            backgroundColor.a *= clamp(0.5 - distance, 0.0, 1.0);
        }
        else if (tag > 2.5) {
            // Checkerboard
            var cell:Float = params.z;
            var relative:Vec2 = position - origin;
            var xIndex:Float = floor(relative.x / cell);
            var yIndex:Float = floor(relative.y / cell);
            var shouldBeColored:Float = fmodf(xIndex + yIndex, 2.0);
            backgroundColor.a *= clamp(shouldBeColored, 0.0, 1.0);
        }

        return backgroundColor;

    }

    /**
     * 8-bit storage of the premultiplied color `path_rasterization_fragment`
     * writes to a sample (`alpha` is the Loop-Blinn alpha, 1 elsewhere).
     * Gradients can leave the 0..1 range (dithering): the unorm target
     * saturates.
     */
    function storedColor(c:Vec4, alpha:Float):Vec4 {
        return floor(clamp(vec4(c.rgb * c.a * alpha, alpha * c.a), 0.0, 1.0) * 255.0 + 0.5);
    }

    /**
     * Plain coverage: `coverage` is the mean of the samples, a multiple of
     * 1/4. Each covered sample stores the rounded color, the resolve
     * averages them (rounded to nearest).
     */
    function pathColor(coverage:Float, c:Vec4):Vec4 {

        var quarters:Float = floor(coverage * 4.0 + 0.5);
        var k:Float = coverage;
        if (abs(coverage * 4.0 - quarters) < 0.02) {
            k = quarters * 0.25;
        }
        return floor(storedColor(c, 1.0) * k + 0.5) / 255.0;

    }

    /**
     * Pixel with Loop-Blinn curve samples (see
     * `glaze.PathRasterizer.rasterizeCurves()`): `plain` samples store
     * `round(255 * premultiplied color)`, `curve` samples
     * `round(255 * premultiplied color * alpha)` (the alpha of the pixel
     * center), and the 4 samples are resolved (mean, rounded).
     */
    function pathCurveColor(texel:Vec4, c:Vec4):Vec4 {

        var red:Float = floor(texel.r * 255.0 + 0.5);
        var green:Float = floor(texel.g * 255.0 + 0.5);
        var blue:Float = floor(texel.b * 255.0 + 0.5);
        var high:Float = floor(red / 32.0);
        var counts:Float = red - high * 32.0;
        var curve:Float = floor(counts / 5.0);
        var plain:Float = counts - curve * 5.0;
        var alpha:Float = (high * 65536.0 + green * 256.0 + blue) / 524288.0;
        return floor((storedColor(c, 1.0) * plain + storedColor(c, alpha) * curve) / 4.0 + 0.5) / 255.0;

    }

    /**
     * Fragment color. Kept out of `main()` because shade turns a nested
     * `return` in `main()` into a `fragColor` assignment without leaving it.
     */
    function fragmentColor():Vec4 {

        var texel:Vec4 = texture(mainTex, tcoord);

        if (clipDistances.x < 0.0 || clipDistances.y < 0.0 || clipDistances.z < 0.0 || clipDistances.w < 0.0) {
            return vec4(0.0);
        }

        var color:Vec4 = fillColor(scenePosition);

        if (pathCoverage > 1.5) {
            return pathCurveColor(texel, color);
        }

        return pathColor(texel.a, color);

    }

    function main():Vec4 {

        return fragmentColor();

    }

}
