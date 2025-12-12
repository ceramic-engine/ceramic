package shaders;

// Ported from: https://gist.github.com/Beefster09/7264303ee4b4b2086f372f1e70e8eddd

class PixelArt extends Shader<PixelArt_Vert, PixelArt_Frag> {}

class PixelArt_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    @in var vertexPosition:Vec3;
    @in var vertexTCoord:Vec2;
    @in var vertexColor:Vec4;

    @out var tcoord:Vec2;
    @out var color:Vec4;

    function main():Vec4 {

        tcoord = vertexTCoord;
        color = vertexColor;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class PixelArt_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var resolution:Vec2;
    @param var sharpness:Float;

    @param var gridThickness:Float;
    @param var gridAlpha:Float;
    @param var gridColor:Vec3;

    @param var scanlineIntensity:Float;
    @param var scanlineOffset:Float;
    @param var scanlineCount:Float;
    @param var scanlineShape:Float;

    @param var verticalMaskIntensity:Float;
    @param var verticalMaskOffset:Float;
    @param var verticalMaskCount:Float;

    @param var glowThresholdMin:Float;
    @param var glowThresholdMax:Float;
    @param var glowStrength:Float;

    @param var chromaticAberration:Float;

    @in var tcoord:Vec2;
    @in var color:Vec4;

    function sharpen(px:Float):Float {

        var norm:Float = (fract(px) - 0.5) * 2.0;
        var norm2:Float = norm * norm;
        return floor(px) + norm * pow(norm2, sharpness) / 2.0 + 0.5;

    }

    function sampleSharpened(coord:Vec2):Vec4 {

        return texture(mainTex, vec2(
            sharpen(coord.x * resolution.x) / resolution.x,
            sharpen(coord.y * resolution.y) / resolution.y
        ));

    }

    function grid(gap:Float, uv:Vec2):Float {

        // Compute distance to closest horizontal and vertical line
        var dist:Vec2 = mod(vec2(uv.x + 0.5, uv.y + 0.5), vec2(gap)) - vec2(0.5 * gap);

        // Return min distance to horizontal or vertical line
        return min(abs(dist.x), abs(dist.y));

    }

    function main():Vec4 {

        var texColor:Vec4;

        if (chromaticAberration > 0.0) {
            var aberr:Vec2 = vec2(chromaticAberration, 0.0); // Horizontal offset

            // Apply sharpness to each color channel separately
            var r:Float = sampleSharpened(tcoord + aberr).r;
            var g:Float = sampleSharpened(tcoord).g;
            var b:Float = sampleSharpened(tcoord - aberr).b;

            texColor = vec4(r, g, b, 1.0);
        } else {
            texColor = sampleSharpened(tcoord);
        }

        // --- Grid ---
        if (gridThickness > 0.0) {
            var uv:Vec2 = vec2(
                tcoord.x * resolution.x,
                tcoord.y * resolution.y
            );

            var gap:Float = 1.0;

            // Compute antialiased grid pattern
            var line:Float = grid(gap, uv);
            var aa:Float = smoothstep(0.0, 0.5, gridThickness - line);

            aa *= gridAlpha;

            // Mix grid and background color
            texColor.rgb = mix(texColor.rgb, gridColor, aa);
        }

        // --- Scanlines ---
        var lum:Float = dot(texColor.rgb, vec3(0.2126, 0.7152, 0.0722));
        if (scanlineCount > 0.0) {
            var scanY:Float = sin(((scanlineOffset / scanlineCount) + tcoord.y) * scanlineCount * 3.14159);
            scanY = scanY * 0.5 + 0.5; // Now in [0, 1]
            scanY = pow(scanY, mix(scanlineShape, min(scanlineShape, 1.0), lum)); // Shape the curve
            var scanFactor:Float = mix(scanlineIntensity, 1.0, scanY);
            texColor.rgb *= scanFactor;
        }

        // --- Vertical Shadow Mask ---
        if (verticalMaskCount > 0.0) {
            var scanX:Float = sin(((verticalMaskOffset / verticalMaskCount) + tcoord.x) * verticalMaskCount * 3.14159);
            var maskFactor:Float = mix(verticalMaskIntensity, 1.0, scanX * 0.5 + 0.5);
            texColor.rgb *= maskFactor;
        }

        // --- Bloom / Glow ---
        if (glowStrength > 0.0) {
            var glowFactor:Float = smoothstep(glowThresholdMin, glowThresholdMax, lum);
            if (glowFactor > 0.0) {
                var texel:Vec2 = vec2(1.0) / resolution;
                var blur:Vec3 = texture(mainTex, tcoord + vec2(texel.x, 0.0)).rgb;
                blur += texture(mainTex, tcoord - vec2(texel.x, 0.0)).rgb;
                blur += texture(mainTex, tcoord + vec2(0.0, texel.y)).rgb;
                blur += texture(mainTex, tcoord - vec2(0.0, texel.y)).rgb;
                blur += texColor.rgb;
                blur /= 5.0;
                texColor.rgb = mix(texColor.rgb, blur, glowFactor * glowStrength);
            }
        }

        texColor.a = 1.0;

        return color * texColor;

    }

}
