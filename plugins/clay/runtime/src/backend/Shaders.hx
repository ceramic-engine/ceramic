package backend;

import ceramic.Path;
import ceramic.ReadOnlyArray;
import clay.opengl.GL;

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

        #if ceramic_shader_premultiply_texture
        fragSource = processPremultiplyTextureShader(fragSource);
        #end

        var shouldRemoveExtensions = false;
        var shouldConvertToGLES3 = false;
        #if !(web || ios || tvos || android)
        shouldRemoveExtensions = true;
        #end
        #if web
        if (clay.Clay.app.runtime.webglVersion >= 2) {
            shouldRemoveExtensions = true;
            shouldConvertToGLES3 = true;
        }
        #end

        if (shouldRemoveExtensions) {
            fragSource = removeExtensions(fragSource);
            vertSource = removeExtensions(vertSource);
        }

        if (shouldConvertToGLES3) {
            fragSource = convertToGLES3(fragSource, true);
            vertSource = convertToGLES3(vertSource, false);
        }

        /*
        #if !(ios || tvos || android)
        var isGles3 = false;
        #if web
        if (clay.Clay.app.runtime.webglVersion >= 2) {
        isGles3 = true;
        fragSource = '#version 300 es\n' + fragSource;
        #end
        var fragLines = [];
        for (line in fragSource.split('\n')) {
            if (line.trim().startsWith('#extension GL_OES_') || line.startsWith('#extension OES_')) {
                // Skip line on desktop GL or GLES >= 3
            }
            else if (isGles3 && line.trim().startsWith('attribute ')) {
                fragLines.push('in' + line.trim().substr('attribute'.length));
            }
            else if (isGles3 && line.trim().startsWith('varying ')) {
                fragLines.push('out' + line.trim().substr('varying'.length));
            }
            else {
                fragLines.push(line);
            }
        }
        fragSource = fragLines.join('\n');
        if (isGles3) {
            vertSource = '#version 300 es\n' + vertSource;
            var vertLines = [];
            for (line in vertSource.split('\n')) {
                if (line.trim().startsWith('#extension GL_OES_') || line.startsWith('#extension OES_')) {
                    // Skip line on desktop GL or GLES >= 3
                }
                else if (line.trim().startsWith('attribute ')) {
                    vertLines.push('in' + line.trim().substr('attribute'.length));
                }
                else if (line.trim().startsWith('varying ')) {
                    vertLines.push('out' + line.trim().substr('varying'.length));
                }
                else {
                    vertLines.push(line);
                }
            }
            vertSource = vertLines.join('\n');
        }
        #if web
        }
        #end
        #end
        */

        trace(fragSource);
        trace(vertSource);

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

    static function removeExtensions(source:String):String {

        var lines = [];
        for (line in source.split('\n')) {
            if (line.trim().startsWith('#extension GL_OES_') || line.startsWith('#extension OES_')) {
                // Skip line referencing an extension we want to remove
            }
            else {
                lines.push(line);
            }
        }
        source = lines.join('\n');
        return source;

    }

    static function convertToGLES3(source:String, isFrag:Bool):String {

        var sourceLines = source.split('\n');
        if (sourceLines[0].trim().startsWith('#version 100')) {
            sourceLines.shift();
            source = sourceLines.join('\n');
        }

        if (!source.startsWith('#version ')) {
            source = '#version 300 es\n' + source;

            if (isFrag) {
                source = source.replace('void main(', 'out vec4 fragColor;\nvoid main(');
            }

            source = ceramic.Utils.replaceIdentifier(source, 'attribute', 'in');

            if (isFrag) {
                source = ceramic.Utils.replaceIdentifier(source, 'varying', 'in');
            }
            else {
                source = ceramic.Utils.replaceIdentifier(source, 'varying', 'out');
            }

            source = ceramic.Utils.replaceIdentifier(source, 'texture2D', 'texture');

            source = ceramic.Utils.replaceIdentifier(source, 'gl_FragColor', 'fragColor');
        }

        return source;

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

    #if ceramic_shader_premultiply_texture

    static var RE_VOID_MAIN:EReg = ~/^void\s+main\(\s*\)/;

    static var RE_TEXTURE_2D:EReg = ~/texture2D\s*\(/;

    static function processPremultiplyTextureShader(fragSource:String):String {

        var lines = fragSource.split('\n');
        var newLines:Array<String> = [];

        for (i in 0...lines.length) {
            var line = lines[i];
            if (RE_VOID_MAIN.match(line.trim())) {
                newLines.push('vec4 texture2D_premultiply(sampler2D texture, vec2 tcoord) {');
                newLines.push('    vec4 result = texture2D(texture, tcoord);');
                newLines.push('    result.rgb *= result.a;');
                newLines.push('    return result;');
                newLines.push('}');
                newLines.push('');
                newLines.push(line);
            }
            else {
                newLines.push(RE_TEXTURE_2D.replace(line, 'texture2D_premultiply('));
            }
        }

        return newLines.join('\n');

    }

    #end

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
