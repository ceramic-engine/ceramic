package shaders;

// Shader ported from: https://github.com/kiwipxl/GLSL-shaders/blob/5bcd7ae0d86a04c31a7a081f0c379aa973d3813d/glow.glsl

class Glow extends Shader<Glow_Vert, Glow_Frag> {}

class Glow_Vert extends Vert {

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

class Glow_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var resolution:Vec2 = vec2(0, 0);
    @param var glowSize:Float = 1234;

    /**
     * The color of the glow?
     */
    @param var glowColor:Vec3;
    @param var glowIntensity:Float = 345.6;
    @param var glowThreshold:Float;

    @in var tcoord:Vec2;
    @in var color:Vec4;

    function main():Vec4 {

        var pixel:Vec4 = texture(mainTex, tcoord);

        if (pixel.a <= glowThreshold) {

            var uvX:Float = tcoord.x;
            var uvY:Float = tcoord.y;

            var sum:Float = 0.0;
            var n:Int = 0;
            while (n < 9) {
                uvY = tcoord.y + (glowSize * (float(n) - 4.0)) / resolution.y;
                var hSum:Float = 0.0;
                hSum += texture(mainTex, vec2(uvX - (4.0 * glowSize) / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX - (3.0 * glowSize) / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX - (2.0 * glowSize) / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX - glowSize / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX, uvY)).a;
                hSum += texture(mainTex, vec2(uvX + glowSize / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX + (2.0 * glowSize) / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX + (3.0 * glowSize) / resolution.x, uvY)).a;
                hSum += texture(mainTex, vec2(uvX + (4.0 * glowSize) / resolution.x, uvY)).a;
                sum += hSum / 9.0;
                n++;
            }

            var a:Float = (sum / 9.0) * glowIntensity;
            pixel = vec4(a * glowColor, a);
        }

        return color * pixel;

    }

}
