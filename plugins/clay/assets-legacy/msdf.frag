#extension GL_OES_standard_derivatives : enable
#extension OES_standard_derivatives : enable

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;
uniform vec2 texSize;
uniform float pxRange;

varying vec2 tcoord;
varying vec4 color;

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

void main() {
    vec2 msdfUnit;
    vec3 textureSample;
    msdfUnit = pxRange/texSize;
    textureSample = texture2D(tex0, tcoord).rgb;
    float sigDist = median(textureSample.r, textureSample.g, textureSample.b) - 0.5;
    sigDist *= dot(msdfUnit, 0.5/fwidth(tcoord));
    float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
    vec4 bgColor = vec4(0.0, 0.0, 0.0, 0.0);
    gl_FragColor = mix(bgColor, color, opacity);
}