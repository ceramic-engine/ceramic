
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;

uniform vec2 resolution;
uniform vec2 blurSize; // vec2(0.5, 0.5)

varying vec2 tcoord;
varying vec4 color;

// Shader ported from: https://github.com/kiwipxl/GLSL-shaders/blob/5bcd7ae0d86a04c31a7a081f0c379aa973d3813d/blur.glsl

void main() {
    vec4 pixel;
    pixel = texture2D(tex0, tcoord);

    float uvX = tcoord.x;
    float uvY = tcoord.y;

    vec4 sum = vec4(0.0, 0.0, 0.0, 0.0);
    for (int n = 0; n < 9; ++n) {
        uvY = tcoord.y + (blurSize.y * (float(n) - 4.5)) / resolution.y;
        vec4 hSum = vec4(0.0, 0.0, 0.0, 0.0);
        hSum += texture2D(tex0, vec2(uvX - (4.0 * blurSize.x) / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX - (3.0 * blurSize.x) / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX - (2.0 * blurSize.x) / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX - blurSize.x / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX, uvY));
        hSum += texture2D(tex0, vec2(uvX + blurSize.x / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX + (2.0 * blurSize.x) / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX + (3.0 * blurSize.x) / resolution.x, uvY));
        hSum += texture2D(tex0, vec2(uvX + (4.0 * blurSize.x) / resolution.x, uvY));
        sum += hSum / 9.0;
    }

    pixel = sum / 9.0;

    gl_FragColor = color * pixel;
}