package shaders;

// Shader ported from: https://github.com/Jam3/glsl-fast-gaussian-blur

class GaussianBlur extends Shader<GaussianBlur_Vert, GaussianBlur_Frag> {}

class GaussianBlur_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    @in var vertexPosition:Vec3;
    @in var vertexTCoord:Vec2;
    @in var vertexColor:Vec4;

    @out var tcoord:Vec2;
    @out var color:Vec4;

    function main():Vec4 {

        tcoord = vertexTCoord;
        color = vertexColor;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class GaussianBlur_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var resolution:Vec2;
    @param var blurSize:Vec2;

    @in var tcoord:Vec2;
    @in var color:Vec4;

    inline static final PI2:Float = 6.28318530718;
    inline static final DIRECTIONS:Float = 16.0;
    inline static final QUALITY:Float = 4.0;

    function main():Vec4 {

        var radius:Vec2 = blurSize / resolution.xy;

        var pixel:Vec4 = texture(mainTex, tcoord);

        var d:Float = 0.0;
        while (d < PI2) {

            var dir:Vec2 = vec2(cos(d), sin(d)) * radius;

            var i:Float = 1.0 / QUALITY;
            while (i <= 1.0) {
                pixel += texture(mainTex, tcoord + dir * i);
                i += 1.0 / QUALITY;
            }

            d += PI2 / DIRECTIONS;
        }

        // Output to screen
        pixel /= QUALITY * DIRECTIONS;
        return color * pixel;

    }

}
