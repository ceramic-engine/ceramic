
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;

uniform vec2 gap;
uniform vec4 lightColor;

varying vec2 tcoord;
varying vec4 color;

void main() {

    vec4 pixel = texture2D(tex0, tcoord);
    vec4 outsidePixel = texture2D(tex0, vec2(tcoord.x + gap.x, tcoord.y + gap.y));

    pixel *= color;

    float lightAlpha = (1.0 - outsidePixel.a) * lightColor.a * pixel.a;

    gl_FragColor = vec4(
        min(1.0, pixel.r + lightColor.r * lightAlpha),
        min(1.0, pixel.g + lightColor.g * lightAlpha),
        min(1.0, pixel.b + lightColor.b * lightAlpha),
        pixel.a
    );
}