package backend.impl;

import phoenix.Batcher;

import snow.modules.opengl.GL;

class CeramicShader extends phoenix.Shader {

    public var customAttributes:ceramic.ImmutableArray<ceramic.ShaderAttribute> = null;

    override public function link():Bool {

        program = GL.createProgram();

        GL.attachShader(program, vert_shader);
        GL.attachShader(program, frag_shader);

        // Now we want to ensure that our locations are static
        GL.bindAttribLocation(program, Batcher.vert_attribute, 'vertexPosition');
        GL.bindAttribLocation(program, Batcher.tcoord_attribute, 'vertexTCoord');
        GL.bindAttribLocation(program, Batcher.color_attribute, 'vertexColor');

        // Custom attributes from ceramic
        if (customAttributes != null) {
            var n = Batcher.color_attribute + 1;
            for (attr in customAttributes) {
                GL.bindAttribLocation(program, n, attr.name);
                n++;
            }
        }

        GL.linkProgram(program);

        if( GL.getProgramParameter(program, GL.LINK_STATUS) == 0) {
            add_log("\tFailed to link shader program:");
            add_log( format_log(GL.getProgramInfoLog(program)) );
            GL.deleteProgram(program);
            program = #if snow_web null #else 0 #end;
            return false;
        }

            //first bind it
        use();

            //:todo: this is being refactored for the new
            //way more flexible shaders and rendering :}

            if (!no_default_uniforms) {

                proj_attribute = location('projectionMatrix');
                view_attribute = location('modelViewMatrix');

                var maxTextures = ceramic.App.app.backend.textures.maxTexturesByBatch();

                for (i in 0...maxTextures) {
                    var attr = location('tex' + i);
                    if(attr != #if snow_web null #else 0 #end) GL.uniform1i(attr, i);
                }

            }

        return true;

    } //link

/// Internal

    static function glTypeToString(inType:Int):String {

        return switch (inType) {
            case GL.BYTE: 'BYTE';
            case GL.UNSIGNED_BYTE: 'UNSIGNED_BYTE';
            case GL.SHORT: 'SHORT';
            case GL.UNSIGNED_SHORT: 'UNSIGNED_SHORT';
            case GL.INT: 'INT';
            case GL.BOOL: 'BOOL';
            case GL.UNSIGNED_INT: 'UNSIGNED_INT';
            case GL.FLOAT: 'FLOAT';
            case GL.FLOAT_VEC2: 'FLOAT_VEC2';
            case GL.FLOAT_VEC3: 'FLOAT_VEC3';
            case GL.FLOAT_VEC4: 'FLOAT_VEC4';
            case GL.INT_VEC2: 'INT_VEC2';
            case GL.INT_VEC3: 'INT_VEC3';
            case GL.INT_VEC4: 'INT_VEC4';
            case GL.BOOL_VEC2: 'BOOL_VEC2';
            case GL.BOOL_VEC3: 'BOOL_VEC3';
            case GL.BOOL_VEC4: 'BOOL_VEC3';
            case GL.FLOAT_MAT2: 'FLOAT_MAT2';
            case GL.FLOAT_MAT3: 'FLOAT_MAT3';
            case GL.FLOAT_MAT4: 'FLOAT_MAT4';
            case GL.SAMPLER_2D: 'SAMPLER_2D';
            case GL.SAMPLER_CUBE: 'SAMPLER_CUBE';
            default: 'unknown';
        }

    } //glTypeToString

} //CeramicShader
