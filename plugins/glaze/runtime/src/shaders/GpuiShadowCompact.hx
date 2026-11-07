// Ported from gpui-pre-wgpu 0.3.10: src/shaders.wgsl (vs_shadow, fs_shadow and helpers)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package shaders;

/**
 * GPUI shadow primitive: analytic gaussian blur of a rounded rectangle,
 * as a drop shadow or an inset shadow.
 *
 * The quad geometry covering the blur (bounds expanded by 3 sigma for a
 * drop shadow, element bounds for an inset shadow) is computed on the CPU
 * side and given as `vertexGeometry`.
 *
 * Compact variant of `GpuiShadow`, used only when the GPU limits are too
 * low for it (see `gpui.platform.SceneRenderable.useCompactShaders`): 8
 * vertex attributes. The unit vertex, inset flag and blur radius travel in
 * `vertexTCoord`; the element bounds of an inset shadow are its geometry.
 */
class GpuiShadowCompact extends Shader<GpuiShadowCompact_Vert, GpuiShadowCompact_Frag> {}

class GpuiShadowCompact_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /**
     * x: unit vertex and inset flag, packed as `unitX + 2 * unitY + 4 * inset`,
     * y: blur radius
     */
    @in var vertexTCoord:Vec2;
    /** Shadow color (rgba, not premultiplied) */
    @in var vertexColor:Vec4;
    /**
     * Drawn area: origin.xy, size.xy. Inset shadows cover their element
     * bounds, which they also use as `elementBounds`.
     */
    @in var vertexGeometry:Vec4;
    /** origin.xy, size.xy */
    @in var vertexContentMask:Vec4;
    /** Shadow bounds: origin.xy, size.xy */
    @in var vertexBounds:Vec4;
    /** top left, top right, bottom right, bottom left */
    @in var vertexCornerRadii:Vec4;
    /** Element corner radii (used by inset shadows) */
    @in var vertexElementCornerRadii:Vec4;

    @out var scenePosition:Vec2;
    @out var clipDistances:Vec4;
    @out var color:Vec4;
    @out var bounds:Vec4;
    @out var cornerRadii:Vec4;
    @out var elementBounds:Vec4;
    @out var elementCornerRadii:Vec4;
    @out var params:Vec2;

    function main():Vec4 {

        // Exact integer arithmetic on small floats
        var code:Float = vertexTCoord.x;
        var pairs:Float = floor(code * 0.5);
        var inset:Float = floor(code * 0.25);
        var unitVertex:Vec2 = vec2(code - 2.0 * pairs, pairs - 2.0 * inset);
        var position:Vec2 = unitVertex * vertexGeometry.zw + vertexGeometry.xy;
        scenePosition = position;

        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        color = vertexColor;
        bounds = vertexBounds;
        cornerRadii = vertexCornerRadii;
        elementBounds = vertexGeometry;
        elementCornerRadii = vertexElementCornerRadii;
        params = vec2(vertexTCoord.y, inset);

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class GpuiShadowCompact_Frag extends Frag {

    @in var scenePosition:Vec2;
    @in var clipDistances:Vec4;
    @in var color:Vec4;
    @in var bounds:Vec4;
    @in var cornerRadii:Vec4;
    @in var elementBounds:Vec4;
    @in var elementCornerRadii:Vec4;
    @in var params:Vec2;

    function gaussian(x:Float, sigma:Float):Float {
        return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * 3.1415926) * sigma);
    }

    /** Approximation of the error function, needed for the gaussian integral */
    function erf(v:Vec2):Vec2 {
        var s:Vec2 = sign(v);
        var a:Vec2 = abs(v);
        var r1:Vec2 = 1.0 + (0.278393 + (0.230389 + (0.000972 + 0.078108 * a) * a) * a) * a;
        var r2:Vec2 = r1 * r1;
        return s - s / (r2 * r2);
    }

    function blurAlongX(x:Float, y:Float, sigma:Float, corner:Float, halfSize:Vec2):Float {
        var delta:Float = min(halfSize.y - corner - abs(y), 0.0);
        var curved:Float = halfSize.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
        var integral:Vec2 = 0.5 + 0.5 * erf((x + vec2(-curved, curved)) * (sqrt(0.5) / sigma));
        return integral.y - integral.x;
    }

    function pickCornerRadius(centerToPoint:Vec2, radii:Vec4):Float {
        if (centerToPoint.x < 0.0) {
            if (centerToPoint.y < 0.0) {
                return radii.x;
            }
            else {
                return radii.w;
            }
        }
        else {
            if (centerToPoint.y < 0.0) {
                return radii.y;
            }
            else {
                return radii.z;
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

    function quadSdf(point:Vec2, quadBounds:Vec4, radii:Vec4):Float {
        var halfSize:Vec2 = quadBounds.zw / 2.0;
        var center:Vec2 = quadBounds.xy + halfSize;
        var centerToPoint:Vec2 = point - center;
        var cornerRadius:Float = pickCornerRadius(centerToPoint, radii);
        var cornerToPoint:Vec2 = abs(centerToPoint) - halfSize;
        var cornerCenterToPoint:Vec2 = cornerToPoint + cornerRadius;
        return quadSdfImpl(cornerCenterToPoint, cornerRadius);
    }

    /**
     * Fragment color. Kept out of `main()` because shade turns a nested
     * `return` in `main()` into a `fragColor` assignment without leaving it.
     */
    function fragmentColor():Vec4 {

        if (clipDistances.x < 0.0 || clipDistances.y < 0.0 || clipDistances.z < 0.0 || clipDistances.w < 0.0) {
            return vec4(0.0);
        }

        var blurRadius:Float = params.x;
        var halfSize:Vec2 = bounds.zw / 2.0;
        var center:Vec2 = bounds.xy + halfSize;
        var centerToPoint:Vec2 = scenePosition - center;

        var cornerRadius:Float = pickCornerRadius(centerToPoint, cornerRadii);

        var alpha:Float = 0.0;
        if (blurRadius == 0.0) {
            var distance:Float = quadSdf(scenePosition, bounds, cornerRadii);
            alpha = clamp(0.5 - distance, 0.0, 1.0);
        }
        else {
            // The signal is only non-zero in a limited range, so don't waste samples
            var low:Float = centerToPoint.y - halfSize.y;
            var high:Float = centerToPoint.y + halfSize.y;
            var start:Float = clamp(-3.0 * blurRadius, low, high);
            var end:Float = clamp(3.0 * blurRadius, low, high);

            // Accumulate samples (we can get away with surprisingly few samples)
            var stepSize:Float = (end - start) / 4.0;
            var y:Float = start + stepSize * 0.5;
            var i:Int = 0;
            while (i < 4) {
                var blur:Float = blurAlongX(centerToPoint.x, centerToPoint.y - y, blurRadius, cornerRadius, halfSize);
                alpha += blur * gaussian(y, blurRadius) * stepSize;
                y += stepSize;
                i++;
            }
        }

        if (params.y > 0.5) {
            alpha = 1.0 - alpha;
            var elementDistance:Float = quadSdf(scenePosition, elementBounds, elementCornerRadii);
            alpha *= clamp(0.5 - elementDistance, 0.0, 1.0);
        }

        // Premultiplied output
        var a:Float = color.a * alpha;
        return vec4(color.rgb * a, a);

    }

    function main():Vec4 {

        return fragmentColor();

    }

}
