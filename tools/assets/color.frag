#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

varying vec2 tcoord;
varying vec4 color;

void main() {
    gl_FragColor = color;
}