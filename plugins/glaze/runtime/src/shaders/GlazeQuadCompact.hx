// Ported from gpui-pre-wgpu 0.3.10: src/shaders.wgsl (vs_quad, fs_quad and helpers)
// and gpui-pre-apple 0.3.10: src/shaders.metal (prepare_fill_color, fill_color gradients)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package shaders;

/**
 * GPUI quad primitive: rounded rectangle with per corner radii, per side
 * borders (solid or dashed) and a background (solid, linear gradient,
 * slash pattern or checkerboard), clipped by a content mask.
 *
 * Each quad is drawn as 4 vertices carrying the same per-instance data in
 * custom attributes (see `glaze.ceramic.SceneRenderer` for the layout).
 * All geometry attributes are in scene units (scaled pixels), so the signed
 * distance field and antialiasing work in device pixels like in GPUI.
 *
 * Linear gradients follow GPUI's Metal shader rather than its WGSL one: the
 * WGSL shader converts already sRGB encoded colors with `linear_to_srgb()`
 * before mixing, which darkens the middle of gradients on non sRGB targets.
 * The Metal shader mixes sRGB colors directly (like CSS) and is the one
 * used by the GPUI reference renders on macOS.
 *
 * Compact variant of `GlazeQuad`, used only when the GPU limits are too low
 * for it (see `glaze.platform.SceneRenderable.useCompactShaders`): at most 8
 * vertex attributes and 8 varying rows (GLSL ES 1.0 appendix A packing),
 * the minimum some WebGL configurations give (Firefox with fingerprinting
 * resistance or `webgl.min_capability_mode`). Same math as `GlazeQuad`:
 * the unit vertex and flags travel in `vertexTCoord`, the first gradient
 * stop replaces the solid color, and the second stop and the stop
 * percentages are uniforms (one gradient value per draw call).
 */
class GlazeQuadCompact extends Shader<GlazeQuadCompact_Vert, GlazeQuadCompact_Frag> {}

class GlazeQuadCompact_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;
    /**
     * Second gradient stop color (rgba) of the linear gradient quad of the
     * current draw call (`SceneRenderable` draws at most one gradient quad
     * per draw call). Unused by the other quads.
     */
    @param var gradientColor1:Vec4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /**
     * x: unit vertex and flags, packed as `unitX + 2 * unitY + 4 * flags`
     * (flags: background tag + 4 * color space + 8 * border style),
     * y: gradient angle, pattern height or checkerboard cell size
     */
    @in var vertexTCoord:Vec2;
    /** Solid background color, or first gradient stop color (rgba, not premultiplied) */
    @in var vertexColor:Vec4;
    /** origin.xy, size.xy */
    @in var vertexBounds:Vec4;
    /** origin.xy, size.xy */
    @in var vertexContentMask:Vec4;
    /** top left, top right, bottom right, bottom left */
    @in var vertexCornerRadii:Vec4;
    /** top, right, bottom, left */
    @in var vertexBorderWidths:Vec4;
    /** rgba, not premultiplied */
    @in var vertexBorderColor:Vec4;

    // 8 varying rows (GLSL ES 1.0 appendix A packing), the minimum some
    // WebGL configurations give (Firefox fingerprinting resistance)
    @out var scenePosition:Vec2;
    @out var clipDistances:Vec4;
    @out var bounds:Vec4;
    @out var cornerRadii:Vec4;
    @out var borderWidths:Vec4;
    @out var borderColor:Vec4;
    /** Solid background color, or first gradient stop color */
    @out var backgroundColor0:Vec4;
    @out var backgroundColor1:Vec4;
    /** flags, gradient angle or pattern height or cell size */
    @out var params:Vec2;

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

        // Exact integer arithmetic on small floats
        var code:Float = vertexTCoord.x;
        var pairs:Float = floor(code * 0.5);
        var flags:Float = floor(code * 0.25);
        var unitVertex:Vec2 = vec2(code - 2.0 * pairs, pairs - 2.0 * flags);
        var position:Vec2 = unitVertex * vertexBounds.zw + vertexBounds.xy;

        scenePosition = position;

        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        bounds = vertexBounds;
        cornerRadii = vertexCornerRadii;
        borderWidths = vertexBorderWidths;
        borderColor = vertexBorderColor;
        params = vec2(flags, vertexTCoord.y);

        // prepare_fill_color() (Metal): linear gradient (tag 1) in Oklab
        // (color space 1), with or without dashed border
        backgroundColor0 = vertexColor;
        backgroundColor1 = gradientColor1;
        var styleless:Float = flags - 8.0 * floor(flags * 0.125);
        if (styleless == 5.0) {
            backgroundColor0 = srgbToOklab(vertexColor);
            backgroundColor1 = srgbToOklab(gradientColor1);
        }

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

/**
 * Unity (`shade_unity`): Metal compiles Unity's shaders with fast math, like
 * ANGLE's code of the web build, but with `preserveInvariance` (Unity's
 * vertex shaders declare an invariant position): the compiler then
 * contracts and reassociates other operations than for ANGLE, and the
 * premultiplied output is fused with the blending only when it is the last
 * operation of the shader. Written for Unity so that the bits match the web
 * (measured with Metal kernels and a blending pipeline of both compiled
 * shaders, then on the Unity golden):
 * - one exit: `blendColor()` returns the straight color and `main()`
 *   premultiplies it (with early returns, FXC selects the result with
 *   masks, which keeps Metal from fusing the multiply with the blending:
 *   one level off on translucent fills, like a 0.3 alpha selection);
 * - `mix()` as Metal computes it, `fma(t, b, fma(-t, a, a))`, through HLSL
 *   `mad()`;
 * - the dither noise with `fract()` spelled out and multiplied by `dashOne`
 *   (a barrier against reassociation, see `dashAlpha()`);
 * - the cosine of the slash pattern: the constant ANGLE's compiler folds,
 *   one ulp from the one FXC folds.
 */
class GlazeQuadCompact_Frag extends Frag {

    /**
     * Always 1 (set by `SceneRenderable`). The dash code multiplies some
     * intermediate values by it to fix the evaluation order: on macOS the
     * WebGL shader is compiled by Metal with fast math too (through ANGLE),
     * which reassociates additions, and the compiler cannot see through a
     * product by a uniform (see `dashAlpha()` and `uptoBl`).
     */
    @param var dashOne:Float;
    /**
     * First and second gradient stop percentages of the linear gradient
     * quad of the current draw call (see `GlazeQuadCompact_Vert.gradientColor1`)
     */
    @param var gradientStops:Vec2;

    @in var scenePosition:Vec2;
    @in var clipDistances:Vec4;
    @in var bounds:Vec4;
    @in var cornerRadii:Vec4;
    @in var borderWidths:Vec4;
    @in var borderColor:Vec4;
    @in var backgroundColor0:Vec4;
    @in var backgroundColor1:Vec4;
    @in var params:Vec2;

    function truncf(x:Float):Float {
        return sign(x) * floor(abs(x));
    }

    /** Remainder with the sign of the dividend (WGSL `%` on floats) */
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

    function over(below:Vec4, above:Vec4):Vec4 {
        var alpha:Float = above.a + below.a * (1.0 - above.a);
        var color:Vec3 = (above.rgb * above.a + below.rgb * below.a * (1.0 - above.a)) / alpha;
        return vec4(color, alpha);
    }

    function pickCornerRadius(centerToPoint:Vec2):Float {
        if (centerToPoint.x < 0.0) {
            if (centerToPoint.y < 0.0) {
                return cornerRadii.x;
            }
            else {
                return cornerRadii.w;
            }
        }
        else {
            if (centerToPoint.y < 0.0) {
                return cornerRadii.y;
            }
            else {
                return cornerRadii.z;
            }
        }
    }

    function quadSdfImpl(cornerCenterToPoint:Vec2, cornerRadius:Float):Float {
        if (cornerRadius == 0.0) {
            return max(cornerCenterToPoint.x, cornerCenterToPoint.y);
        }
        else {
            var signedDistanceToInsetQuad:Float =
                length(max(vec2(0.0), cornerCenterToPoint)) +
                min(0.0, max(cornerCenterToPoint.x, cornerCenterToPoint.y));
            return signedDistanceToInsetQuad - cornerRadius;
        }
    }

    function quarterEllipseSdf(point:Vec2, radii:Vec2):Float {
        var circleVec:Vec2 = point / radii;
        var unitCircleSdf:Float = length(circleVec) - 1.0;
        return unitCircleSdf * (radii.x + radii.y) * -0.5;
    }

    function cornerDashVelocity(dv1:Float, dv2:Float):Float {
        if (dv1 == 0.0) {
            return dv2;
        }
        else if (dv2 == 0.0) {
            return dv1;
        }
        else {
            return min(dv1, dv2);
        }
    }

    /**
     * `a / b` as compiled by Metal with fast math (the default of GPUI's
     * shaders): `a * (1 / b)`, the reciprocal correctly rounded (measured on
     * the GPU: `dv_numerator / width` and `max_t / dash_count` match this
     * bit for bit, not the correctly rounded quotient). Used by the dash
     * code, where a one ulp difference changes edge pixels by one level.
     */
    function dashDiv(a:Float, b:Float):Float {
        return a * (1.0 / b);
    }

    function dashAlpha(t:Float, period:Float, dashLength:Float, dashVelocity:Float, antialiasThreshold:Float):Float {
        var halfPeriod:Float = period / 2.0;
        var halfLength:Float = dashLength / 2.0;
        // `fmod(t + half_period - half_length, period) - half_period`, as
        // Metal's fast math compiles it: fmod is `x - period * trunc(x /
        // period)`, the compiler cancels `half_period` and contracts the
        // rest into `fma(-period, n, t - half_length)` (measured with a Metal
        // compute kernel of the same code: this matches GPUI's dash ends,
        // the IEEE evaluation leaves some of them one level off). The fused
        // product is exact here: `period` is split in two halves of 12
        // significant bits, each multiplied by the integer `n` exactly, and
        // the first subtraction is exact (Sterbenz), so the result is
        // rounded once, like the fma.
        var n:Float = truncf(dashDiv(t + halfPeriod - halfLength, period));
        var scale:Float = exp2(11.0 - floor(log2(period)));
        var periodHigh:Float = floor(period * scale) / scale;
        var periodLow:Float = period - periodHigh;
        var centered:Float = ((t - halfLength) * dashOne - periodHigh * n) * dashOne - periodLow * n;
        var signedDistance:Float = abs(centered) - halfLength;
        // Fast math division (see `dashDiv()`)
        return clamp(antialiasThreshold - dashDiv(signedDistance, dashVelocity), 0.0, 1.0);
    }

    /** Premultiplied output, as expected by Ceramic's blending */
    function blendColor(color:Vec4, alphaFactor:Float):Vec4 {
        var alpha:Float = color.a * alphaFactor;
        #if shade_unity
        // Premultiplied once at the end of `main()` (see the class doc)
        return vec4(color.rgb, alpha);
        #else
        return vec4(color.rgb * alpha, alpha);
        #end
    }

    /** Flags of `params.x` rounded (interpolation of a constant) */
    function flags():Float {
        return floor(params.x + 0.5);
    }

    function gradientColor(position:Vec2):Vec4 {

        var allFlags:Float = flags();
        var tag:Float = allFlags - 4.0 * floor(allFlags * 0.25);
        var colorSpace:Float = floor(allFlags * 0.25) - 2.0 * floor(allFlags * 0.125);
        var backgroundColor:Vec4 = backgroundColor0;
        var origin:Vec2 = bounds.xy;
        var size:Vec2 = bounds.zw;

        if (tag > 0.5 && tag < 1.5) {
            // Linear gradient, -90 degrees to match the CSS gradient angle
            var angle:Float = params.y;
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

            t = (t - gradientStops.x) / (gradientStops.y - gradientStops.x);
            t = clamp(t, 0.0, 1.0);

            if (colorSpace < 0.5) {
                #if shade_unity
                backgroundColor = GlazeQuadCompactMad.mad(vec4(t), backgroundColor1, GlazeQuadCompactMad.mad(vec4(-t), backgroundColor0, backgroundColor0));
                #else
                backgroundColor = mix(backgroundColor0, backgroundColor1, t);
                #end
            }
            else {
                #if shade_unity
                backgroundColor = oklabToSrgb(GlazeQuadCompactMad.mad(vec4(t), backgroundColor1, GlazeQuadCompactMad.mad(vec4(-t), backgroundColor0, backgroundColor0)));
                #else
                backgroundColor = oklabToSrgb(mix(backgroundColor0, backgroundColor1, t));
                #end
            }

            // Dither to reduce banding in gradients (triangular noise, like GPUI's Metal shader)
            var seed:Vec2 = position * 0.6180339887;
            #if shade_unity
            var s1:Float = sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453;
            var s2:Float = sin(dot(seed, vec2(39.3460, 11.135))) * 24634.6345;
            var r1:Float = min(s1 - floor(s1), 0.99999994039535522) * dashOne;
            var r2:Float = min(s2 - floor(s2), 0.99999994039535522) * dashOne;
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
            var heightParam:Float = params.y;
            var patternWidth:Float = (heightParam / 65535.0) / 255.0;
            var patternInterval:Float = fmodf(heightParam, 65535.0) / 255.0;
            var patternHeight:Float = patternWidth + patternInterval;
            var stripeAngle:Float = 3.1415926 / 4.0;
            var patternPeriod:Float = patternHeight * sin(stripeAngle);
            var relativePosition:Vec2 = position - origin;
            // WGSL mat2x2(cos, -sin, sin, cos) is column-major
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
            var cell:Float = params.y;
            var relative:Vec2 = position - origin;
            var xIndex:Float = floor(relative.x / cell);
            var yIndex:Float = floor(relative.y / cell);
            var shouldBeColored:Float = fmodf(xIndex + yIndex, 2.0);
            backgroundColor.a *= clamp(shouldBeColored, 0.0, 1.0);
        }

        return backgroundColor;

    }

    /**
     * Fragment color. Kept out of `main()` because shade turns a nested
     * `return` in `main()` into a `fragColor` assignment without leaving it.
     */
    function fragmentColor():Vec4 {

        // Alpha clip first
        if (clipDistances.x < 0.0 || clipDistances.y < 0.0 || clipDistances.z < 0.0 || clipDistances.w < 0.0) {
            return vec4(0.0);
        }

        var position:Vec2 = scenePosition;
        var backgroundColor:Vec4 = gradientColor(position);

        var unrounded:Bool = cornerRadii.x == 0.0 && cornerRadii.w == 0.0 && cornerRadii.y == 0.0 && cornerRadii.z == 0.0;

        // Fast path when the quad is not rounded and doesn't have any border
        #if shade_unity
        // One exit (see the class doc)
        var result:Vec4 = vec4(0.0);
        if (borderWidths.x == 0.0 && borderWidths.w == 0.0 && borderWidths.y == 0.0 && borderWidths.z == 0.0 && unrounded) {
            result = blendColor(backgroundColor, 1.0);
        }
        else {
        #else
        if (borderWidths.x == 0.0 && borderWidths.w == 0.0 && borderWidths.y == 0.0 && borderWidths.z == 0.0 && unrounded) {
            return blendColor(backgroundColor, 1.0);
        }
        #end

        var size:Vec2 = bounds.zw;
        var halfSize:Vec2 = size / 2.0;
        var point:Vec2 = position - bounds.xy;
        var centerToPoint:Vec2 = point - halfSize;

        // Signed distance field threshold for inclusion of pixels
        var antialiasThreshold:Float = 0.5;

        // Radius of the nearest corner
        var cornerRadius:Float = pickCornerRadius(centerToPoint);

        // Width of the nearest borders
        var border:Vec2 = vec2(
            centerToPoint.x < 0.0 ? borderWidths.w : borderWidths.y,
            centerToPoint.y < 0.0 ? borderWidths.x : borderWidths.z
        );

        // 0-width borders are reduced so that inner_sdf >= antialias_threshold
        var reducedBorder:Vec2 = vec2(
            border.x == 0.0 ? -antialiasThreshold : border.x,
            border.y == 0.0 ? -antialiasThreshold : border.y
        );

        // Vector from the corner of the quad bounds to the point, after mirroring
        // the point into the bottom right quadrant
        var cornerToPoint:Vec2 = abs(centerToPoint) - halfSize;

        // Vector from the point to the center of the rounded corner's circle
        var cornerCenterToPoint:Vec2 = cornerToPoint + cornerRadius;

        var isNearRoundedCorner:Bool = cornerCenterToPoint.x >= 0.0 && cornerCenterToPoint.y >= 0.0;

        var straightBorderInnerCornerToPoint:Vec2 = cornerToPoint + reducedBorder;

        var isBeyondInnerStraightBorder:Bool =
            straightBorderInnerCornerToPoint.x > 0.0 || straightBorderInnerCornerToPoint.y > 0.0;

        var isWithinInnerStraightBorder:Bool =
            straightBorderInnerCornerToPoint.x < -antialiasThreshold &&
            straightBorderInnerCornerToPoint.y < -antialiasThreshold;

        // Fast path for points that must be part of the background
        #if shade_unity
        if (isWithinInnerStraightBorder && !isNearRoundedCorner) {
            result = blendColor(backgroundColor, 1.0);
        }
        else {
        #else
        if (isWithinInnerStraightBorder && !isNearRoundedCorner) {
            return blendColor(backgroundColor, 1.0);
        }
        #end

        // Signed distance of the point to the outside edge of the quad's border
        var outerSdf:Float = quadSdfImpl(cornerCenterToPoint, cornerRadius);

        // Approximate signed distance of the point to the inside edge of the border
        var innerSdf:Float = 0.0;
        if (cornerCenterToPoint.x <= 0.0 || cornerCenterToPoint.y <= 0.0) {
            innerSdf = -max(straightBorderInnerCornerToPoint.x, straightBorderInnerCornerToPoint.y);
        }
        else if (isBeyondInnerStraightBorder) {
            innerSdf = -1.0;
        }
        else if (reducedBorder.x == reducedBorder.y) {
            innerSdf = -(outerSdf + reducedBorder.x);
        }
        else {
            var ellipseRadii:Vec2 = max(vec2(0.0), vec2(cornerRadius) - reducedBorder);
            innerSdf = quarterEllipseSdf(cornerCenterToPoint, ellipseRadii);
        }

        var borderSdf:Float = max(innerSdf, outerSdf);

        var color:Vec4 = backgroundColor;
        if (borderSdf < antialiasThreshold) {
            var borderColorValue:Vec4 = borderColor;

            if (flags() > 7.5) {
                // Dashed border
                var t:Float = 0.0;
                var maxT:Float = 0.0;

                var dashLengthPerWidth:Float = 2.0;
                var dashGapPerWidth:Float = 1.0;
                var dashPeriodPerWidth:Float = dashLengthPerWidth + dashGapPerWidth;

                var dashVelocity:Float = 0.0;
                var dvNumerator:Float = 1.0 / dashPeriodPerWidth;

                if (unrounded) {
                    var isHorizontal:Bool = cornerCenterToPoint.x < cornerCenterToPoint.y;
                    var dashedBorder:Vec2 = vec2(
                        max(borderWidths.z, borderWidths.x),
                        max(borderWidths.y, borderWidths.w)
                    );
                    var borderWidth:Float = isHorizontal ? dashedBorder.x : dashedBorder.y;
                    dashVelocity = dashDiv(dvNumerator, borderWidth);
                    t = (isHorizontal ? point.x : point.y) * dashVelocity;
                    maxT = (isHorizontal ? size.x : size.y) * dashVelocity;
                }
                else {
                    var rTr:Float = cornerRadii.y;
                    var rBr:Float = cornerRadii.z;
                    var rBl:Float = cornerRadii.w;
                    var rTl:Float = cornerRadii.x;

                    var wT:Float = borderWidths.x;
                    var wR:Float = borderWidths.y;
                    var wB:Float = borderWidths.z;
                    var wL:Float = borderWidths.w;

                    var dvT:Float = wT <= 0.0 ? 0.0 : dashDiv(dvNumerator, wT);
                    var dvR:Float = wR <= 0.0 ? 0.0 : dashDiv(dvNumerator, wR);
                    var dvB:Float = wB <= 0.0 ? 0.0 : dashDiv(dvNumerator, wB);
                    var dvL:Float = wL <= 0.0 ? 0.0 : dashDiv(dvNumerator, wL);

                    var sT:Float = (size.x - rTl - rTr) * dvT;
                    var sR:Float = (size.y - rTr - rBr) * dvR;
                    var sB:Float = (size.x - rBr - rBl) * dvB;
                    var sL:Float = (size.y - rBl - rTl) * dvL;

                    var cornerDashVelocityTr:Float = cornerDashVelocity(dvT, dvR);
                    var cornerDashVelocityBr:Float = cornerDashVelocity(dvB, dvR);
                    var cornerDashVelocityBl:Float = cornerDashVelocity(dvB, dvL);
                    var cornerDashVelocityTl:Float = cornerDashVelocity(dvT, dvL);

                    var cTr:Float = rTr * (3.1415926 / 2.0) * cornerDashVelocityTr;
                    var cBr:Float = rBr * (3.1415926 / 2.0) * cornerDashVelocityBr;
                    var cBl:Float = rBl * (3.1415926 / 2.0) * cornerDashVelocityBl;
                    var cTl:Float = rTl * (3.1415926 / 2.0) * cornerDashVelocityTl;

                    var uptoTr:Float = sT;
                    var uptoR:Float = uptoTr + cTr;
                    var uptoBr:Float = uptoR + sR;
                    // Metal compiles shaders with fast math, which lets the
                    // compiler reassociate float additions: `upto_b` is only
                    // used by `upto_bl = upto_b + s_b`, and the compiled
                    // shader evaluates `(upto_br + s_b) + c_br` (measured
                    // with Metal compute kernels on 300 random dashed quads:
                    // every intermediate value matches bit for bit with this
                    // order and `dashDiv()`, the IEEE order differs for 1 in 6)
                    var uptoBl:Float = (uptoBr + sB) * dashOne + cBr;
                    var uptoL:Float = uptoBl + cBl;
                    var uptoTl:Float = uptoL + sL;
                    maxT = uptoTl + cTl;

                    if (isNearRoundedCorner) {
                        var rad:Float = atan(cornerCenterToPoint.y, cornerCenterToPoint.x);
                        var cornerT:Float = rad * cornerRadius;

                        if (centerToPoint.x >= 0.0) {
                            if (centerToPoint.y < 0.0) {
                                dashVelocity = cornerDashVelocityTr;
                                t = uptoR - cornerT * dashVelocity;
                            }
                            else {
                                dashVelocity = cornerDashVelocityBr;
                                t = uptoBr + cornerT * dashVelocity;
                            }
                        }
                        else {
                            if (centerToPoint.y >= 0.0) {
                                dashVelocity = cornerDashVelocityBl;
                                t = uptoL - cornerT * dashVelocity;
                            }
                            else {
                                dashVelocity = cornerDashVelocityTl;
                                t = uptoTl + cornerT * dashVelocity;
                            }
                        }
                    }
                    else {
                        var isHorizontalSide:Bool = cornerCenterToPoint.x < cornerCenterToPoint.y;
                        if (isHorizontalSide) {
                            if (centerToPoint.y < 0.0) {
                                dashVelocity = dvT;
                                t = (point.x - rTl) * dashVelocity;
                            }
                            else {
                                dashVelocity = dvB;
                                t = uptoBl - (point.x - rBl) * dashVelocity;
                            }
                        }
                        else {
                            if (centerToPoint.x < 0.0) {
                                dashVelocity = dvL;
                                t = uptoTl - (point.y - rTl) * dashVelocity;
                            }
                            else {
                                dashVelocity = dvR;
                                t = uptoR + (point.y - rTr) * dashVelocity;
                            }
                        }
                    }
                }

                var dashLength:Float = dashLengthPerWidth / dashPeriodPerWidth;

                if (unrounded) {
                    maxT -= dashLength;
                }
                if (maxT >= 1.0) {
                    var dashCount:Float = floor(maxT);
                    var dashPeriod:Float = dashDiv(maxT, dashCount);
                    borderColorValue.a *= dashAlpha(t, dashPeriod, dashLength, dashVelocity, antialiasThreshold);
                }
                else if (unrounded) {
                    var dashGap:Float = maxT - dashLength;
                    if (dashGap > 0.0) {
                        var period:Float = dashLength + dashGap;
                        borderColorValue.a *= dashAlpha(t, period, dashLength, dashVelocity, antialiasThreshold);
                    }
                }
            }

            // Blend the border on top of the background, then linearly
            // interpolate between the two as we slide inside the background
            var blendedBorder:Vec4 = over(backgroundColor, borderColorValue);
            #if shade_unity
            var borderMix:Float = clamp(antialiasThreshold - innerSdf, 0.0, 1.0);
            color = GlazeQuadCompactMad.mad(vec4(borderMix), blendedBorder, GlazeQuadCompactMad.mad(vec4(-borderMix), backgroundColor, backgroundColor));
            #else
            color = mix(backgroundColor, blendedBorder, clamp(antialiasThreshold - innerSdf, 0.0, 1.0));
            #end
        }

        #if shade_unity
        result = blendColor(color, clamp(antialiasThreshold - outerSdf, 0.0, 1.0));
        }
        }
        return result;
        #else
        return blendColor(color, clamp(antialiasThreshold - outerSdf, 0.0, 1.0));
        #end

    }

    function main():Vec4 {

        #if shade_unity
        var color:Vec4 = fragmentColor();
        return vec4(color.rgb * color.a, color.a);
        #else
        return fragmentColor();
        #end

    }

}

#if shade_unity
/**
 * HLSL `mad()`, written `fma()` in the MSL of Unity's Metal shaders: the
 * multiply-adds that Metal's fast math contracts in the GLSL of the web
 * build (ANGLE), spelled out for Unity, whose shaders are compiled with
 * `preserveInvariance` (see `GlazeQuadCompact_Frag`).
 */
extern class GlazeQuadCompactMad {
    static function mad(a:Vec4, b:Vec4, c:Vec4):Vec4;
}
#end
