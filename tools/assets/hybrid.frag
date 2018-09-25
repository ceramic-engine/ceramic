#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;
varying vec2 tcoord;
varying vec4 color;
varying float tflag;

float when_eq(float x, float y) {
    return 1.0 - abs(sign(x - y));
}

void main() {
    vec4 texColor = texture2D(tex0, tcoord);
    float factor = when_eq(tflag, 1.0);
    gl_FragColor = color * (texColor * (1.0 - factor) + factor);
}