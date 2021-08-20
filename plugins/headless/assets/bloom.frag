
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;

uniform vec2 resolution;
uniform float bloomSpread; // 1.0
uniform float bloomIntensity; // 2.0
uniform float bloomThreshold; // 0.5

varying vec2 tcoord;
varying vec4 color;

// Shader ported from: https://github.com/kiwipxl/GLSL-shaders/blob/5bcd7ae0d86a04c31a7a081f0c379aa973d3813d/bloom.glsl

void main() {
    vec4 pixel;

    pixel = texture2D(tex0, tcoord);
    if (pixel.a <= bloomThreshold) {

        float uvX = tcoord.x;
        float uvY = tcoord.y;

        vec4 sum = vec4(0.0, 0.0, 0.0, 0.0);
        for (int n = 0; n < 9; ++n) {
            uvY = tcoord.y + (bloomSpread * (float(n) - 4.0)) / resolution.y;
            vec4 hSum = vec4(0.0, 0.0, 0.0, 0.0);
            hSum += texture2D(tex0, vec2(uvX - (4.0 * bloomSpread) / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX - (3.0 * bloomSpread) / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX - (2.0 * bloomSpread) / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX - bloomSpread / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX, uvY));
            hSum += texture2D(tex0, vec2(uvX + bloomSpread / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX + (2.0 * bloomSpread) / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX + (3.0 * bloomSpread) / resolution.x, uvY));
            hSum += texture2D(tex0, vec2(uvX + (4.0 * bloomSpread) / resolution.x, uvY));
            sum += hSum / 9.0;
        }

        pixel = ((sum / 9.0) * bloomIntensity);
    }

    gl_FragColor = color * pixel;
}