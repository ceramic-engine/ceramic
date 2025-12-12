package shaders;

// Shader ported from: https://github.com/kiwipxl/GLSL-shaders/blob/5bcd7ae0d86a04c31a7a081f0c379aa973d3813d/blur.glsl

class Blur extends Shader<Blur_Vert, Blur_Frag> {}

class Blur_Vert extends Vert {

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

class Blur_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var resolution:Vec2;
    @param var blurSize:Vec2;

    @in var tcoord:Vec2;
    @in var color:Vec4;

    function main():Vec4 {

        var pixel:Vec4 = texture(mainTex, tcoord);

        var uvX:Float = tcoord.x;
        var uvY:Float = tcoord.y;

        var sum:Vec4 = vec4(0.0, 0.0, 0.0, 0.0);
        var n:Int = 0;
        while (n < 9) {
            uvY = tcoord.y + (blurSize.y * (float(n) - 4.0)) / resolution.y;
            var hSum:Vec4 = vec4(0.0, 0.0, 0.0, 0.0);
            hSum += texture(mainTex, vec2(uvX - (4.0 * blurSize.x) / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX - (3.0 * blurSize.x) / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX - (2.0 * blurSize.x) / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX - blurSize.x / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX, uvY));
            hSum += texture(mainTex, vec2(uvX + blurSize.x / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX + (2.0 * blurSize.x) / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX + (3.0 * blurSize.x) / resolution.x, uvY));
            hSum += texture(mainTex, vec2(uvX + (4.0 * blurSize.x) / resolution.x, uvY));
            sum += hSum / 9.0;
            n++;
        }

        pixel = sum / 9.0;

        return color * pixel;

    }

}
