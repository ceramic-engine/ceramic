package shaders;

class Fxaa extends Shader<Fxaa_Vert, Fxaa_Frag> {}

class Fxaa_Vert extends Vert {

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

class Fxaa_Frag extends Frag {

    @param var mainTex:Sampler2D;
    @param var resolution:Vec2;

    @in var tcoord:Vec2;
    @in var color:Vec4;

    inline static final FXAA_REDUCE_MIN:Float = 1.0 / 128.0;
    inline static final FXAA_REDUCE_MUL:Float = 1.0 / 8.0;
    inline static final FXAA_SPAN_MAX:Float = 8.0;

    // Texture coordinate outputs from texcoords function
    var v_rgbNW:Vec2;
    var v_rgbNE:Vec2;
    var v_rgbSW:Vec2;
    var v_rgbSE:Vec2;
    var v_rgbM:Vec2;

    // Optimized version for mobile, where dependent
    // texture reads can be a bottleneck
    function fxaa(fragCoord:Vec2):Vec4 {

        var inverseVP:Vec2 = vec2(1.0 / resolution.x, 1.0 / resolution.y);
        var rgbNW:Vec3 = texture(mainTex, v_rgbNW).xyz;
        var rgbNE:Vec3 = texture(mainTex, v_rgbNE).xyz;
        var rgbSW:Vec3 = texture(mainTex, v_rgbSW).xyz;
        var rgbSE:Vec3 = texture(mainTex, v_rgbSE).xyz;
        var texColor:Vec4 = texture(mainTex, v_rgbM);
        var rgbM:Vec3 = texColor.xyz;
        var luma:Vec3 = vec3(0.299, 0.587, 0.114);
        var lumaNW:Float = dot(rgbNW, luma);
        var lumaNE:Float = dot(rgbNE, luma);
        var lumaSW:Float = dot(rgbSW, luma);
        var lumaSE:Float = dot(rgbSE, luma);
        var lumaM:Float = dot(rgbM, luma);
        var lumaMin:Float = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
        var lumaMax:Float = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

        var dir:Vec2 = vec2(
            -((lumaNW + lumaNE) - (lumaSW + lumaSE)),
            (lumaNW + lumaSW) - (lumaNE + lumaSE)
        );

        var dirReduce:Float = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                              (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);

        var rcpDirMin:Float = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
        dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
                  max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
                  dir * rcpDirMin)) * inverseVP;

        var rgbA:Vec3 = 0.5 * (
            texture(mainTex, fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +
            texture(mainTex, fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);
        var rgbB:Vec3 = rgbA * 0.5 + 0.25 * (
            texture(mainTex, fragCoord * inverseVP + dir * -0.5).xyz +
            texture(mainTex, fragCoord * inverseVP + dir * 0.5).xyz);

        var lumaB:Float = dot(rgbB, luma);
        if ((lumaB < lumaMin) || (lumaB > lumaMax)) {
            return vec4(rgbA, texColor.a);
        } else {
            return vec4(rgbB, texColor.a);
        }

    }

    function texcoords(fragCoord:Vec2):Void {

        var inverseVP:Vec2 = vec2(1.0) / resolution.xy;
        v_rgbNW = (fragCoord + vec2(-1.0, -1.0)) * inverseVP;
        v_rgbNE = (fragCoord + vec2(1.0, -1.0)) * inverseVP;
        v_rgbSW = (fragCoord + vec2(-1.0, 1.0)) * inverseVP;
        v_rgbSE = (fragCoord + vec2(1.0, 1.0)) * inverseVP;
        v_rgbM = fragCoord * inverseVP;

    }

    function apply(fragCoord:Vec2):Vec4 {

        // Compute the texture coords
        texcoords(fragCoord);

        // Compute FXAA
        return fxaa(fragCoord);

    }

    function main():Vec4 {

        var fragCoord:Vec2 = tcoord * resolution;

        var texcolor:Vec4 = apply(fragCoord);

        return color * texcolor;

    }

}
