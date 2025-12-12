package shaders;

class Msdf extends Shader<Msdf_Vert, Msdf_Frag> {}

class Msdf_Vert extends Vert {

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

class Msdf_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var texSize:Vec2;
    @param var pxRange:Float;

    @in var tcoord:Vec2;
    @in var color:Vec4;

    function median(r:Float, g:Float, b:Float):Float {

        return max(min(r, g), min(max(r, g), b));

    }

    function main():Vec4 {

        var msdfUnit:Vec2;
        var textureSample:Vec3;

        msdfUnit = vec2(pxRange) / texSize;
        textureSample = texture(mainTex, tcoord).rgb;

        var sigDist:Float = median(textureSample.r, textureSample.g, textureSample.b) - 0.5;
        sigDist *= dot(msdfUnit, vec2(0.5) / fwidth(tcoord));

        var opacity:Float = clamp(sigDist + 0.5, 0.0, 1.0);
        var bgColor:Vec4 = vec4(0.0, 0.0, 0.0, 0.0);

        return mix(bgColor, color, opacity);

    }

}
