// ceramic: multiTexture

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

// ceramic: multiTexture/texture
uniform sampler2D tex0;

varying vec2 tcoord;
varying vec4 color;
// ceramic: multiTexture/textureId

void main() {
    vec4 texColor;
    // ceramic: multiTexture/if
    texColor = texture2D(tex0, tcoord);
    // ceramic: multiTexture/endif
    gl_FragColor = color * texColor;
}