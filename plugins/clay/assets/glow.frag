
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;

uniform vec2 resolution;
uniform float glowSize; // 0.5
uniform vec3 glowColor; // vec3(0.0, 0.0, 0.0)
uniform float glowIntensity; // 1.0
uniform float glowThreshold; // 0.5

varying vec2 tcoord;
varying vec4 color;

// Shader ported from: https://github.com/kiwipxl/GLSL-shaders/blob/5bcd7ae0d86a04c31a7a081f0c379aa973d3813d/glow.glsl

void main() {
    vec4 pixel;
    pixel = texture2D(tex0, tcoord);
    if (pixel.a <= glowThreshold) {
	
        float uvX = tcoord.x;
        float uvY = tcoord.y;

        float sum = 0.0;
        for (int n = 0; n < 9; ++n) {
            uvY = tcoord.y + (glowSize * (float(n) - 4.0)) / resolution.y;
            float hSum = 0.0;
            hSum += texture2D(tex0, vec2(uvX - (4.0 * glowSize) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX - (3.0 * glowSize) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX - (2.0 * glowSize) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX - glowSize / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + glowSize / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + (2.0 * glowSize) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + (3.0 * glowSize) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + (4.0 * glowSize) / resolution.x, uvY)).a;
            sum += hSum / 9.0;
        }

        float a = (sum / 9.0) * glowIntensity;
        pixel = vec4(a * glowColor, a);
    }
    gl_FragColor = color * pixel;
}