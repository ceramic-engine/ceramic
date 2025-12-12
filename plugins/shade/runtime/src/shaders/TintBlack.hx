package shaders;

class TintBlack extends Shader<TintBlack_Vert, TintBlack_Frag> {}

class TintBlack_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    @in var vertexPosition:Vec3;
    @in var vertexTCoord:Vec2;
    @in var vertexColor:Vec4;
    @in @multi var vertexTextureId:Float;
    @in var vertexDarkColor:Vec4;

    @out var tcoord:Vec2;
    @out var color:Vec4;
    @out @multi var textureId:Float;
    @out var darkColor:Vec4;

    function main():Vec4 {

        tcoord = vertexTCoord;
        color = vertexColor;
        @multi textureId = vertexTextureId;
        darkColor = vertexDarkColor;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class TintBlack_Frag extends Frag {

    @param @multi var mainTex:Sampler2D;

    @in var tcoord:Vec2;
    @in var color:Vec4;
    @in @multi var textureId:Float;
    @in var darkColor:Vec4;

    function main():Vec4 {

        var texColor:Vec4 = vec4(0.0);

        @multi {
            texColor = texture(mainTex, tcoord);
        }

        var result:Vec4 = vec4(
            (vec3((texColor.a - 1.0) * darkColor.a + 1.0) - texColor.rgb) * darkColor.rgb + texColor.rgb * color.rgb,
            texColor.a * color.a
        );

        return result;

    }

}
