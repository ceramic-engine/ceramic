package backend;

import ceramic.ReadOnlyArray;
import clay.opengl.GL;
import ceramic.Path;

using StringTools;

class Shaders implements spec.Shaders {

    static final SHADER_ATTRIBUTES:ReadOnlyArray<String> = ['vertexPosition', 'vertexTCoord', 'vertexColor'];
    static final SHADER_ATTRIBUTES_MULTITEXTURE:ReadOnlyArray<String> = ['vertexPosition', 'vertexTCoord', 'vertexColor', 'vertexTextureId'];

    public function new() {}

    inline public function fromSource(vertSource:String, fragSource:String, ?customAttributes:ceramic.ReadOnlyArray<ceramic.ShaderAttribute>):Shader {

        var isMultiTextureTemplate = false;
        #if !ceramic_no_multitexture
        for (line in fragSource.split('\n')) {
            if (line.trim().replace(' ', '').toLowerCase() == '//ceramic:multitexture') {
                isMultiTextureTemplate = true;
                break;
            }
        }
        #end

        #if !(web || ios || tvos || android)
        var fragLines = [];
        for (line in fragSource.split('\n')) {
            if (line.trim().startsWith('#extension GL_OES_') || line.startsWith('#extension OES_')) {
                // Skip line on desktop GL
            }
            else {
                fragLines.push(line);
            }
        }
        fragSource = fragLines.join('\n');
        #end

        var textures = ['tex0'];

        if (isMultiTextureTemplate) {
            var maxTextures = ceramic.App.app.backend.textures.maxTexturesByBatch();
            var maxIfs = maxIfStatementsByFragmentShader();

            var maxTexturesAndIfs = Std.int(Math.min(maxTextures, maxIfs));
            if (maxTexturesAndIfs > 1) {
                var i = 1;
                while (i <= maxTexturesAndIfs) {
                    textures.push('tex' + i);
                    i++;
                }
            }

            fragSource = processMultiTextureFragTemplate(fragSource, maxTextures, maxIfs);
            vertSource = processMultiTextureVertTemplate(vertSource, maxTextures, maxIfs);
        }

        var shader = new ShaderImpl();

        shader.attributes = isMultiTextureTemplate ? SHADER_ATTRIBUTES_MULTITEXTURE.original : SHADER_ATTRIBUTES.original;
        shader.textures = textures;
        shader.vertSource = vertSource;
        shader.fragSource = fragSource;
        shader.isBatchingMultiTexture = isMultiTextureTemplate;
        shader.customAttributes = customAttributes;

        shader.init();

        return shader;

    }

    static function processMultiTextureVertTemplate(vertSource:String, maxTextures:Int, maxIfs:Int):String {

        var lines = vertSource.split('\n');
        var newLines:Array<String> = [];

        for (i in 0...lines.length) {
            var line = lines[i];
            var cleanedLine = line.trim().replace(' ', '').toLowerCase();
            if (cleanedLine == '//ceramic:multitexture/vertextextureid') {
                newLines.push('attribute float vertexTextureId;');
            }
            else if (cleanedLine == '//ceramic:multitexture/textureid') {
                newLines.push('varying float textureId;');
            }
            else if (cleanedLine == '//ceramic:multitexture/assigntextureid') {
                newLines.push('textureId = vertexTextureId;');
            }
            else {
                newLines.push(line);
            }
        }

        return newLines.join('\n');

    }

    static function processMultiTextureFragTemplate(fragSource:String, maxTextures:Int, maxIfs:Int):String {

        var maxConditions = Std.int(Math.min(maxTextures, maxIfs));

        var lines = fragSource.split('\n');
        var newLines:Array<String> = [];

        var nextLineIsTextureUniform = false;
        var inConditionBody = false;
        var conditionLines:Array<String> = [];

        for (i in 0...lines.length) {
            var line = lines[i];
            var cleanedLine = line.trim().replace(' ', '').toLowerCase();
            if (nextLineIsTextureUniform) {
                nextLineIsTextureUniform = false;
                for (n in 0...maxConditions) {
                    if (n == 0) {
                        newLines.push(line);
                    }
                    else {
                        newLines.push(line.replace('tex0', 'tex' + n));
                    }
                }
            }
            else if (inConditionBody) {
                if (cleanedLine == '//ceramic:multitexture/endif') {
                    inConditionBody = false;
                    if (conditionLines.length > 0) {
                        for (n in 0...maxConditions) {

                            #if ceramic_multitexture_lowerthan
                            if (n == 0) {
                                newLines.push('if (textureId < 0.5) {');
                            }
                            else {
                                newLines.push('else if (textureId < ' + n + '.5) {');
                            }
                            #else
                            if (n == 0) {
                                newLines.push('if (textureId == 0.0) {');
                            }
                            else {
                                newLines.push('else if (textureId == ' + n + '.0) {');
                            }
                            #end

                            for (l in 0...conditionLines.length) {
                                if (n == 0) {
                                    newLines.push(conditionLines[l]);
                                }
                                else {
                                    newLines.push(conditionLines[l].replace('tex0', 'tex' + n));
                                }
                            }

                            newLines.push('}');
                        }
                    }
                }
                else {
                    conditionLines.push(line);
                }
            }
            else if (cleanedLine.startsWith('//ceramic:multitexture')) {
                if (cleanedLine == '//ceramic:multitexture/texture') {
                    nextLineIsTextureUniform = true;
                }
                else if (cleanedLine == '//ceramic:multitexture/textureid') {
                    newLines.push('varying float textureId;');
                }
                else if (cleanedLine == '//ceramic:multitexture/if') {
                    inConditionBody = true;
                }
            }
            else {
                newLines.push(line);
            }
        }

        return newLines.join('\n');
        
    }

    inline public function destroy(shader:Shader):Void {

        (shader:ShaderImpl).destroy();

    }

    inline public function clone(shader:Shader):Shader {

        return (shader:ShaderImpl).clone();

    }

/// Public API

    inline public function setInt(shader:Shader, name:String, value:Int):Void {
        
        (shader:ShaderImpl).uniforms.setInt(name, value);

    }

    inline public function setFloat(shader:Shader, name:String, value:Float):Void {
        
        (shader:ShaderImpl).uniforms.setFloat(name, value);

    }

    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {
        
        (shader:ShaderImpl).uniforms.setColor(name, r, g, b, a);

    }

    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {
        
        (shader:ShaderImpl).uniforms.setVector2(name, x, y);

    }

    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {
        
        (shader:ShaderImpl).uniforms.setVector3(name, x, y, z);

    }

    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {
        
        (shader:ShaderImpl).uniforms.setVector4(name, x, y, z, w);

    }

    inline public function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void {
        
        (shader:ShaderImpl).uniforms.setFloatArray(name, Float32Array.fromArray(array));

    }

    inline public function setTexture(shader:Shader, name:String, slot:Int, texture:backend.Texture):Void {
        
        (shader:ShaderImpl).uniforms.setTexture(name, slot, texture);

    }

    inline public function setMat4FromTransform(shader:Shader, name:String, transform:ceramic.Transform):Void {
        
        (shader:ShaderImpl).uniforms.setMatrix4(name, ceramic.Float32Array.fromArray([
            transform.a, transform.b, 0, 0,
            transform.c, transform.d, 0, 0,
            0, 0, 1, 0,
            transform.tx, transform.ty, 0, 1
        ]));

    }

    inline public function customFloatAttributesSize(shader:ShaderImpl):Int {

        var customFloatAttributesSize = 0;

        var allAttrs = shader.customAttributes;
        if (allAttrs != null) {
            for (ii in 0...allAttrs.length) {
                var attr = allAttrs.unsafeGet(ii);
                customFloatAttributesSize += attr.size;
            }
        }

        return customFloatAttributesSize;

    }

    static var _maxIfStatementsByFragmentShader:Int = -1;

    inline static function computeMaxIfStatementsByFragmentShaderIfNeeded(maxIfs:Int = 32):Void {

        if (_maxIfStatementsByFragmentShader == -1) {
            var fragTpl = "
#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif
varying float test;
void main() {
    {{CONDITIONS}}
    gl_FragColor = vec4(0.0);
}
".trim();
            var shader = GL.createShader(GL.FRAGMENT_SHADER);

            while (maxIfs > 0) {
                var frag = fragTpl.replace('{{CONDITIONS}}', generateIfStatements(maxIfs));

                #if ceramic_debug_shader_if_statements
                trace('COMPILE:');
                trace(frag);
                #end

                GL.shaderSource(shader, frag);
                GL.compileShader(shader);
                
                #if ceramic_debug_shader_if_statements
                trace('LOGS:');
                var logs = GL.getShaderInfoLog(shader);
                trace(logs);
                #end

                if (GL.getShaderParameter(shader, GL.COMPILE_STATUS) == 0) {
                    // That's too many ifs apparently
                    maxIfs = Std.int(maxIfs / 2);
                }
                else {
                    // It works!
                    _maxIfStatementsByFragmentShader = maxIfs;
                    break;
                }
            }

            GL.deleteShader(shader);
        }

    }

    static function generateIfStatements(maxIfs:Int):String {

        var result = new StringBuf();

        for (i in 0...maxIfs) {
            if (i > 0) {
                result.add('\nelse ');
            }

            if (i < maxIfs - 1) {
                result.add('if (test == ${i}.0) {}');
            }
        }

        return result.toString();

    }

    public function maxIfStatementsByFragmentShader():Int {

        computeMaxIfStatementsByFragmentShaderIfNeeded();
        return _maxIfStatementsByFragmentShader;

    }

    public function canBatchWithMultipleTextures(shader:Shader):Bool {

        return (shader:ShaderImpl).isBatchingMultiTexture;
        
    }

}
