
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;
uniform vec2 u_resolution;
uniform float u_sharpness;

varying vec2 tcoord;
varying vec4 color;

// Ported from: https://gist.github.com/Beefster09/7264303ee4b4b2086f372f1e70e8eddd
float sharpen(float px) {
    float norm = (fract(px) - 0.5) * 2.0;
    float norm2 = norm * norm;
    return floor(px) + norm * pow(norm2, u_sharpness) / 2.0 + 0.5;
}

void main() {
    vec4 texColor = texture2D(tex0, vec2(
        sharpen(tcoord.x * u_resolution.x) / u_resolution.x,
        sharpen(tcoord.y * u_resolution.y) / u_resolution.y
    ));
    gl_FragColor = color * texColor;
}
