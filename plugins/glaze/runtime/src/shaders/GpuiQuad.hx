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
 * custom attributes (see `gpui.ceramic.SceneRenderer` for the layout).
 * All geometry attributes are in scene units (scaled pixels), so the signed
 * distance field and antialiasing work in device pixels like in GPUI.
 *
 * Linear gradients follow GPUI's Metal shader rather than its WGSL one: the
 * WGSL shader converts already sRGB encoded colors with `linear_to_srgb()`
 * before mixing, which darkens the middle of gradients on non sRGB targets.
 * The Metal shader mixes sRGB colors directly (like CSS) and is the one
 * used by the GPUI reference renders on macOS.
 */
class GpuiQuad extends Shader<GpuiQuad_Vert, GpuiQuad_Frag> {}

class GpuiQuad_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /** Unit vertex: (0,0), (1,0), (0,1) or (1,1) */
    @in var vertexTCoord:Vec2;
    /** Solid background color (rgba, not premultiplied) */
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
    /** background tag, color space, gradient angle or pattern height, border style */
    @in var vertexParams:Vec4;
    /** First gradient stop color (rgba) */
    @in var vertexColor0:Vec4;
    /** Second gradient stop color (rgba) */
    @in var vertexColor1:Vec4;
    /** First and second gradient stop percentages */
    @in var vertexStops:Vec2;

    @out var scenePosition:Vec2;
    @out var clipDistances:Vec4;
    @out var bounds:Vec4;
    @out var cornerRadii:Vec4;
    @out var borderWidths:Vec4;
    @out var borderColor:Vec4;
    @out var params:Vec4;
    @out var backgroundSolid:Vec4;
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

        var unitVertex:Vec2 = vertexTCoord;
        var position:Vec2 = unitVertex * vertexBounds.zw + vertexBounds.xy;

        scenePosition = position;

        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        bounds = vertexBounds;
        cornerRadii = vertexCornerRadii;
        borderWidths = vertexBorderWidths;
        borderColor = vertexBorderColor;
        params = vertexParams;
        stops = vertexStops;

        // prepare_fill_color() (Metal)
        backgroundSolid = vertexColor;
        backgroundColor0 = vertexColor0;
        backgroundColor1 = vertexColor1;
        if (vertexParams.x > 0.5 && vertexParams.x < 1.5 && vertexParams.y > 0.5) {
            backgroundColor0 = srgbToOklab(vertexColor0);
            backgroundColor1 = srgbToOklab(vertexColor1);
        }

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class GpuiQuad_Frag extends Frag {

    /**
     * Always 1 (set by `SceneRenderable`). The dash code multiplies some
     * intermediate values by it to fix the evaluation order: on macOS the
     * WebGL shader is compiled by Metal with fast math too (through ANGLE),
     * which reassociates additions, and the compiler cannot see through a
     * product by a uniform (see `dashAlpha()` and `uptoBl`).
     */
    @param var dashOne:Float;

    @in var scenePosition:Vec2;
    @in var clipDistances:Vec4;
    @in var bounds:Vec4;
    @in var cornerRadii:Vec4;
    @in var borderWidths:Vec4;
    @in var borderColor:Vec4;
    @in var params:Vec4;
    @in var backgroundSolid:Vec4;
    @in var backgroundColor0:Vec4;
    @in var backgroundColor1:Vec4;
    @in var stops:Vec2;

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
        return vec4(color.rgb * alpha, alpha);
    }

    function gradientColor(position:Vec2):Vec4 {

        var tag:Float = params.x;
        var backgroundColor:Vec4 = backgroundSolid;
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
            var r1:Float = fract(sin(dot(seed, vec2(12.9898, 78.233))) * 43758.5453);
            var r2:Float = fract(sin(dot(seed, vec2(39.3460, 11.135))) * 24634.6345);
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
            // WGSL mat2x2(cos, -sin, sin, cos) is column-major
            var rotatedX:Float = cos(stripeAngle) * relativePosition.x + sin(stripeAngle) * relativePosition.y;
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
        if (borderWidths.x == 0.0 && borderWidths.w == 0.0 && borderWidths.y == 0.0 && borderWidths.z == 0.0 && unrounded) {
            return blendColor(backgroundColor, 1.0);
        }

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
        if (isWithinInnerStraightBorder && !isNearRoundedCorner) {
            return blendColor(backgroundColor, 1.0);
        }

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

            if (params.w > 0.5) {
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
            color = mix(backgroundColor, blendedBorder, clamp(antialiasThreshold - innerSdf, 0.0, 1.0));
        }

        return blendColor(color, clamp(antialiasThreshold - outerSdf, 0.0, 1.0));

    }

    function main():Vec4 {

        return fragmentColor();

    }

}
