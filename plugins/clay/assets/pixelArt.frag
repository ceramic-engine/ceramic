#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;
uniform vec2 resolution;
uniform float sharpness; // recommended: 2.0

uniform float gridThickness; // 0.15
uniform float gridAlpha; // 1.0
uniform vec3 gridColor; // vec3(0.0, 0.0, 0.0)

uniform float scanlineIntensity; // 0.75
uniform float scanlineOffset; // 0
uniform float scanlineCount; // resolution.y
uniform float scanlineShape; // 1

uniform float verticalMaskIntensity; // 0.75
uniform float verticalMaskOffset; // 0
uniform float verticalMaskCount; // resolution.x

uniform float glowThresholdMin; // 0.6
uniform float glowThresholdMax; // 0.85
uniform float glowStrength; // 0.5

uniform float chromaticAberration; // 0.002

varying vec2 tcoord;
varying vec4 color;

// Ported from: https://gist.github.com/Beefster09/7264303ee4b4b2086f372f1e70e8eddd
float sharpen(float px) {
    float norm = (fract(px) - 0.5) * 2.0;
    float norm2 = norm * norm;
    return floor(px) + norm * pow(norm2, sharpness) / 2.0 + 0.5;
}

// Helper function to sample texture with sharpness applied
vec4 sampleSharpened(sampler2D tex, vec2 coord) {
    return texture2D(tex, vec2(
        sharpen(coord.x * resolution.x) / resolution.x,
        sharpen(coord.y * resolution.y) / resolution.y
    ));
}

float grid(float lineWidth, float gap, vec2 uv) {
    // compute distance to closest horizontal and vertical line
    vec2 dist = mod(vec2(uv.x + 0.5, uv.y + 0.5), gap) - 0.5 * gap;

    // return min distance to horizontal or vertical line
    return min(abs(dist.x), abs(dist.y));
}

void main() {
    vec4 texColor;
    if (chromaticAberration > 0.0) {
        vec2 aberr = vec2(chromaticAberration, 0.0); // horizontal offset

        // Apply sharpness to each color channel separately
        float r = sampleSharpened(tex0, tcoord + aberr).r;
        float g = sampleSharpened(tex0, tcoord).g;
        float b = sampleSharpened(tex0, tcoord - aberr).b;

        texColor = vec4(r, g, b, 1.0);
    }
    else {
        texColor = sampleSharpened(tex0, tcoord);
    }

    // --- Grid ---
    if (gridThickness > 0.0) {
        vec2 uv = vec2(
            tcoord.x * resolution.x,
            tcoord.y * resolution.y
        );

        float gap = 1.0;

        // compute antialiased grid pattern
        float line = grid(gridThickness, gap, uv);
        float aa = smoothstep(0.0, 0.5, gridThickness - line); // adjust the "1.5" for different antialiasing sharpness

        aa *= gridAlpha;

        // mix grid and background color
        texColor.rgb = mix(texColor.rgb, gridColor, aa);
    }

    // --- Scanlines ---
    float lum = dot(texColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    if (scanlineCount > 0.0) {
        float scanY = sin(((scanlineOffset / scanlineCount) + tcoord.y) * scanlineCount * 3.14159);
        scanY = (scanY * 0.5 + 0.5);           // now in [0, 1]
        scanY = pow(scanY, mix(scanlineShape, min(scanlineShape, 1.0), lum));     // shape the curve
        float scanFactor = mix(scanlineIntensity, 1.0, scanY);
        texColor.rgb *= scanFactor;
    }

    // --- Vertical Shadow Mask ---
    if (verticalMaskCount > 0.0) {
        float scanX = sin(((verticalMaskOffset / verticalMaskCount) + tcoord.x) * verticalMaskCount * 3.14159);
        float maskFactor = mix(verticalMaskIntensity, 1.0, scanX * 0.5 + 0.5);
        texColor.rgb *= maskFactor;
    }

    // --- Bloom / Glow ---
    if (glowStrength > 0.0) {
        float glowFactor = smoothstep(glowThresholdMin, glowThresholdMax, lum);
        if (glowFactor > 0.0) {
            vec2 texel = 1.0 / resolution;
            vec3 blur = texture2D(tex0, tcoord + vec2(texel.x, 0.0)).rgb;
            blur += texture2D(tex0, tcoord - vec2(texel.x, 0.0)).rgb;
            blur += texture2D(tex0, tcoord + vec2(0.0, texel.y)).rgb;
            blur += texture2D(tex0, tcoord - vec2(0.0, texel.y)).rgb;
            blur += texColor.rgb;
            blur /= 5.0;
            texColor.rgb = mix(texColor.rgb, blur, glowFactor * glowStrength);
        }
    }

    texColor.a = 1.0;

    gl_FragColor = color * texColor;
}