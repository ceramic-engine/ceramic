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
varying vec4 darkColor;

void main() {
    // ceramic: multiTexture/if
    vec4 texColor = texture2D(tex0, tcoord);
    gl_FragColor.a = texColor.a * color.a;
    gl_FragColor.rgb = ((texColor.a - 1.0) * darkColor.a + 1.0 - texColor.rgb) * darkColor.rgb + texColor.rgb * color.rgb;
    // ceramic: multiTexture/endif
}