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
    // ceramic: multiTexture/if
    vec4 texColor = texture2D(tex0, tcoord);
    gl_FragColor = color * texColor;
    // ceramic: multiTexture/endif
}