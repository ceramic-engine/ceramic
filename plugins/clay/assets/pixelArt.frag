
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

varying vec2 tcoord;
varying vec4 color;

// Ported from: https://gist.github.com/Beefster09/7264303ee4b4b2086f372f1e70e8eddd
float sharpen(float px) {
    float norm = (fract(px) - 0.5) * 2.0;
    float norm2 = norm * norm;
    return floor(px) + norm * pow(norm2, sharpness) / 2.0 + 0.5;
}

float grid(float lineWidth, float gap, vec2 uv) {

    // compute distance to closest horizontal and vertical line
    vec2 dist = mod(vec2(uv.x + 0.5, uv.y + 0.5), gap) - 0.5 * gap;

    // return min distance to horizontal or vertical line
    return min(abs(dist.x), abs(dist.y));
}

void main() {

    vec4 texColor = texture2D(tex0, vec2(
        sharpen(tcoord.x * resolution.x) / resolution.x,
        sharpen(tcoord.y * resolution.y) / resolution.y
    ));

    if (gridThickness != 0.0) {
        vec2 uv = vec2(
            tcoord.x * resolution.x,
            tcoord.y * resolution.y
        );

        float gap = 1.0;//(1.0 / resolution.x);

        // compute antialiased grid pattern
        float line = grid(gridThickness, gap, uv);
        float aa = smoothstep(0.0, 0.5, gridThickness - line); // adjust the "1.5" for different antialiasing sharpness

        aa *= gridAlpha;

        // mix grid and background color
        texColor.rgb = mix(texColor.rgb, gridColor, aa);
    }

    gl_FragColor = color * texColor;

    // To visualize how this makes the grid:
    /*gl_FragColor = vec4(
        fract(sharpen(tcoord.x * resolution.x)),
        fract(sharpen(tcoord.y * resolution.y)),
        0.5, 1.0
    );*/
}
