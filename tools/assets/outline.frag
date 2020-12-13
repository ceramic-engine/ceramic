
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;

uniform vec2 resolution;
uniform float outlineThickness; // 1.0
uniform vec3 outlineColor; // vec3(0.0, 0.0, 1.0)
uniform float outlineThreshold; // 0.5

varying vec2 tcoord;
varying vec4 color;

// Shader ported from: https://github.com/kiwipxl/GLSL-shaders/blob/5bcd7ae0d86a04c31a7a081f0c379aa973d3813d/outline.glsl

void main() {
    vec4 pixel;
    pixel = texture2D(tex0, tcoord);
    float thickness = outlineThickness * 0.25;
    if (pixel.a <= outlineThreshold) {
	
        float uvX = tcoord.x;
        float uvY = tcoord.y;

        float sum = 0.0;
        for (int n = 0; n < 9; ++n) {
            uvY = tcoord.y + (thickness * (float(n) - 4.5)) / resolution.y;
            float hSum = 0.0;
            hSum += texture2D(tex0, vec2(uvX - (4.0 * thickness) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX - (3.0 * thickness) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX - (2.0 * thickness) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX - thickness / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + thickness / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + (2.0 * thickness) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + (3.0 * thickness) / resolution.x, uvY)).a;
            hSum += texture2D(tex0, vec2(uvX + (4.0 * thickness) / resolution.x, uvY)).a;
            sum += hSum / 9.0;
        }

        if (sum / 9.0 >= 0.0001) {
            pixel = vec4(outlineColor, 1);
        }
    }
    gl_FragColor = color * pixel;
}