// ceramic: multiTexture

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;
varying vec2 tcoord;
varying vec4 color;

void main() {
    vec4 texColor = texture2D(tex0, tcoord);
    gl_FragColor = color * texColor;
}