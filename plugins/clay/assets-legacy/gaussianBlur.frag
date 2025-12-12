
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D tex0;

uniform vec2 resolution;
uniform vec2 blurSize;

varying vec2 tcoord;
varying vec4 color;

// Shader ported from: https://github.com/Jam3/glsl-fast-gaussian-blur

void main() {

    float pi2 = 6.28318530718; // Pi*2

    //float directions = 16.0; // BLUR DIRECTIONS (Default 16.0 - More is better but slower)
    //float quality = 3.0; // BLUR QUALITY (Default 4.0 - More is better but slower)
    //float size = 8.0; // BLUR SIZE (Radius)

    vec2 radius = blurSize / resolution.xy;

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = tcoord;

    vec4 pixel = texture2D(tex0, uv);

    // Blur calculations
    for (float d = 0.0; d < /*pi2*/6.28318530718; d += /*pi2*/6.28318530718 / /*directions*/16.0)
    {
        vec2 dir = vec2(cos(d), sin(d)) * radius;
		for (float i = 1.0 / /*quality*/4.0; i <= 1.0; i += 1.0 / /*quality*/4.0)
        {
			pixel += texture2D(tex0, uv + dir * i);
        }
    }

    // Output to screen
    pixel /= /*quality*/4.0 * /*directions*/16.0;
    gl_FragColor = color * pixel;
}