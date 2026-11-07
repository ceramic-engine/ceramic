// Ported from gpui-pre-wgpu 0.3.10: src/shaders.wgsl (vs_poly_sprite, fs_poly_sprite),
// gpui-pre-apple 0.3.10: src/shaders.metal (polychrome_sprite_fragment)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.
package shaders;

/**
 * GPUI polychrome sprite primitive: an RGBA image or emoji from an atlas,
 * with rounded corners, opacity and optional grayscale.
 *
 * With `straightAlpha` set (polychrome atlas pages, straight alpha like
 * GPUI's), this is Metal's `polychrome_sprite_fragment`: the straight alpha
 * sample is returned with its alpha multiplied by the opacity and the corner
 * coverage, and the batch blends with `SRC_ALPHA` / `ONE_MINUS_SRC_ALPHA`.
 * Otherwise (texture backed images, premultiplied like every Ceramic
 * texture) the premultiplied sample is scaled as a whole and blended with
 * `ONE` / `ONE_MINUS_SRC_ALPHA`.
 */
class GlazePolySprite extends Shader<GlazePolySprite_Vert, GlazePolySprite_Frag> {}

class GlazePolySprite_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    /** World position (already transformed on the CPU side) */
    @in var vertexPosition:Vec3;
    /** Atlas texture coordinates */
    @in var vertexTCoord:Vec2;
    /** Unused, kept for the standard vertex layout */
    @in var vertexColor:Vec4;
    /** Unit vertex: (0,0), (1,0), (0,1) or (1,1) */
    @in var vertexUnit:Vec2;
    /** origin.xy, size.xy */
    @in var vertexBounds:Vec4;
    /** origin.xy, size.xy */
    @in var vertexContentMask:Vec4;
    /** top left, top right, bottom right, bottom left */
    @in var vertexCornerRadii:Vec4;
    /** grayscale (0 or 1), opacity */
    @in var vertexParams:Vec2;

    @out var tcoord:Vec2;
    @out var scenePosition:Vec2;
    @out var clipDistances:Vec4;
    @out var bounds:Vec4;
    @out var cornerRadii:Vec4;
    @out var params:Vec2;

    function main():Vec4 {

        var position:Vec2 = vertexUnit * vertexBounds.zw + vertexBounds.xy;
        scenePosition = position;

        var tl:Vec2 = position - vertexContentMask.xy;
        var br:Vec2 = vertexContentMask.xy + vertexContentMask.zw - position;
        clipDistances = vec4(tl.x, br.x, tl.y, br.y);

        tcoord = vertexTCoord;
        bounds = vertexBounds;
        cornerRadii = vertexCornerRadii;
        params = vertexParams;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class GlazePolySprite_Frag extends Frag {

    @param var mainTex:Sampler2D;

    /** 1 when the texture holds straight alpha texels, 0 when premultiplied */
    @param var straightAlpha:Float;

    @in var tcoord:Vec2;
    @in var scenePosition:Vec2;
    @in var clipDistances:Vec4;
    @in var bounds:Vec4;
    @in var cornerRadii:Vec4;
    @in var params:Vec2;

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

    function quadSdf(point:Vec2, quadBounds:Vec4, radii:Vec4):Float {
        var halfSize:Vec2 = quadBounds.zw / 2.0;
        var center:Vec2 = quadBounds.xy + halfSize;
        var centerToPoint:Vec2 = point - center;
        var cornerRadius:Float = pickCornerRadius(centerToPoint, radii);
        var cornerToPoint:Vec2 = abs(centerToPoint) - halfSize;
        var cornerCenterToPoint:Vec2 = cornerToPoint + cornerRadius;
        if (cornerRadius == 0.0) {
            return max(cornerCenterToPoint.x, cornerCenterToPoint.y);
        }
        var signedDistanceToInsetQuad:Float =
            length(max(vec2(0.0), cornerCenterToPoint)) +
            min(0.0, max(cornerCenterToPoint.x, cornerCenterToPoint.y));
        return signedDistanceToInsetQuad - cornerRadius;
    }

    /**
     * Fragment color. Kept out of `main()` because shade turns a nested
     * `return` in `main()` into a `fragColor` assignment without leaving it.
     */
    function fragmentColor():Vec4 {

        var texSample:Vec4 = texture(mainTex, tcoord);

        if (clipDistances.x < 0.0 || clipDistances.y < 0.0 || clipDistances.z < 0.0 || clipDistances.w < 0.0) {
            return vec4(0.0);
        }

        var distance:Float = quadSdf(scenePosition, bounds, cornerRadii);

        var color:Vec4 = texSample;
        if (params.x > 0.5) {
            var gray:Float = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
            color = vec4(vec3(gray), texSample.a);
        }

        var coverage:Float = params.y * clamp(0.5 - distance, 0.0, 1.0);
        if (straightAlpha > 0.5) {
            return vec4(color.rgb, color.a * coverage);
        }
        return color * coverage;

    }

    function main():Vec4 {

        return fragmentColor();

    }

}
