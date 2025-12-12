package backend;

import ceramic.Path;
import ceramic.ReadOnlyArray;
import clay.Clay;

using StringTools;

/**
 * Clay backend implementation of shader program management.
 * Handles GLSL shader compilation, multi-texture batching, and cross-platform compatibility.
 * 
 * This class processes shader source code to:
 * - Enable multi-texture batching for improved performance
 * - Convert shaders between GLSL ES versions for platform compatibility
 * - Manage shader uniforms and attributes
 * - Handle platform-specific shader requirements
 * 
 * @see ceramic.Shader
 * @see backend.ShaderImpl
 */
class Shaders implements spec.Shaders {

    /** Standard shader vertex attributes: position, texture coordinates, color */
    static final SHADER_ATTRIBUTES:ReadOnlyArray<String> = ['vertexPosition', 'vertexTCoord', 'vertexColor'];
    
    /** Extended attributes for multi-texture batching, includes texture ID per vertex */
    static final SHADER_ATTRIBUTES_MULTITEXTURE:ReadOnlyArray<String> = ['vertexPosition', 'vertexTCoord', 'vertexColor', 'vertexTextureId'];

    public function new() {}

    /**
     * Creates a shader program from vertex and fragment source code.
     * Automatically detects and processes multi-texture shaders for batching optimization.
     * 
     * Multi-texture shaders are identified by the `//ceramic:multitexture` comment directive.
     * The method will:
     * - Generate texture uniforms based on GPU capabilities
     * - Convert between GLSL ES versions as needed
     * - Handle platform-specific shader requirements
     * 
     * @param vertSource Vertex shader GLSL source code
     * @param fragSource Fragment shader GLSL source code
     * @param customAttributes Optional custom vertex attributes beyond the standard ones
     * @return Compiled shader program ready for use
     */
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
        #if !(web || tvos)
        shouldRemoveExtensions = true;
        #if (ios || android || gles_angle)
        shouldConvertToGLES3 = true;
        #end
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

    /**
     * Removes OpenGL ES extension directives from shader source.
     * Used when targeting platforms that don't support or need these extensions.
     * 
     * @param source Shader source code
     * @return Source code with extension directives removed
     */
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

    /**
     * Converts GLSL ES 1.0 shader source to GLSL ES 3.0 syntax.
     * Handles keyword changes and output variable declarations.
     * 
     * Key conversions:
     * - `attribute` → `in` (vertex shaders)
     * - `varying` → `out` (vertex) or `in` (fragment)
     * - `texture2D` → `texture`
     * - `gl_FragColor` → custom `fragColor` output
     * 
     * @param source Original shader source code
     * @param isFrag True for fragment shaders, false for vertex shaders
     * @return Converted GLSL ES 3.0 compatible source
     */
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

    /**
     * Processes vertex shader template for multi-texture support.
     * Replaces ceramic-specific comment directives with actual GLSL code.
     * 
     * Directives:
     * - `//ceramic:multitexture/vertextextureid` → texture ID attribute declaration
     * - `//ceramic:multitexture/textureid` → texture ID varying declaration
     * - `//ceramic:multitexture/assigntextureid` → texture ID assignment
     * 
     * @param vertSource Vertex shader template source
     * @param maxTextures Maximum textures supported by GPU
     * @param maxIfs Maximum if-statements supported by fragment shader
     * @return Processed vertex shader source
     */
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

    /**
     * Processes fragment shader template for multi-texture support.
     * Generates texture sampling code with conditional logic based on texture ID.
     * 
     * Directives:
     * - `//ceramic:multitexture` → marks shader for processing
     * - `//ceramic:multitexture/texture` → generates texture uniform declarations
     * - `//ceramic:multitexture/textureid` → texture ID varying declaration
     * - `//ceramic:multitexture/if` → starts conditional texture sampling block
     * - `//ceramic:multitexture/endif` → ends conditional block
     * 
     * @param fragSource Fragment shader template source
     * @param maxTextures Maximum textures supported by GPU
     * @param maxIfs Maximum if-statements supported by fragment shader
     * @return Processed fragment shader with multi-texture support
     */
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

    /** Regular expression to match main function declaration */
    static var RE_VOID_MAIN:EReg = ~/^void\s+main\(\s*\)/;

    /** Regular expression to match texture2D function calls */
    static var RE_TEXTURE_2D:EReg = ~/texture2D\s*\(/;

    /**
     * Adds texture premultiplication support to fragment shaders.
     * Wraps texture2D calls to multiply RGB by alpha for proper blending.
     * 
     * This is needed when textures are stored with premultiplied alpha
     * but the shader expects straight alpha values.
     * 
     * @param fragSource Fragment shader source code
     * @return Modified source with premultiplication wrapper
     */
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

    /**
     * Destroys a shader program and releases GPU resources.
     * @param shader The shader to destroy
     */
    inline public function destroy(shader:Shader):Void {

        (shader:ShaderImpl).destroy();

    }

    /**
     * Creates a deep copy of a shader program.
     * @param shader The shader to clone
     * @return A new shader instance with the same properties
     */
    inline public function clone(shader:Shader):Shader {

        return (shader:ShaderImpl).clone();

    }

/// Public API

    /**
     * Sets an integer uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param value Integer value to set
     */
    inline public function setInt(shader:Shader, name:String, value:Int):Void {

        (shader:ShaderImpl).uniforms.setInt(name, value);

    }

    /**
     * Sets a float uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param value Float value to set
     */
    inline public function setFloat(shader:Shader, name:String, value:Float):Void {

        (shader:ShaderImpl).uniforms.setFloat(name, value);

    }

    /**
     * Sets a 2D vector uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param x X component
     * @param y Y component
     */
    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {

        (shader:ShaderImpl).uniforms.setVector2(name, x, y);

    }

    /**
     * Sets a 3D vector uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param x X component
     * @param y Y component
     * @param z Z component
     */
    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {

        (shader:ShaderImpl).uniforms.setVector3(name, x, y, z);

    }

    /**
     * Sets a 4D vector uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param x X component
     * @param y Y component
     * @param z Z component
     * @param w W component
     */
    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {

        (shader:ShaderImpl).uniforms.setVector4(name, x, y, z, w);

    }

    /**
     * Sets a float array uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param array Array of float values
     */
    inline public function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void {

        (shader:ShaderImpl).uniforms.setFloatArray(name, Float32Array.fromArray(array));

    }

    /**
     * Sets a texture uniform value in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param slot Texture unit slot (0-based)
     * @param texture Texture to bind
     */
    inline public function setTexture(shader:Shader, name:String, slot:Int, texture:backend.Texture):Void {

        (shader:ShaderImpl).uniforms.setTexture(name, slot, texture);

    }

    /**
     * Sets a 2x2 matrix uniform value in the shader (column-major order).
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     */
    inline public function setMat2(shader:Shader, name:String, m00:Float, m10:Float, m01:Float, m11:Float):Void {

        (shader:ShaderImpl).uniforms.setMatrix2(name, Float32Array.fromArray([m00, m10, m01, m11]));

    }

    /**
     * Sets a 3x3 matrix uniform value in the shader (column-major order).
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m20 Column 0, row 2
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     * @param m21 Column 1, row 2
     * @param m02 Column 2, row 0
     * @param m12 Column 2, row 1
     * @param m22 Column 2, row 2
     */
    inline public function setMat3(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m01:Float, m11:Float, m21:Float, m02:Float, m12:Float, m22:Float):Void {

        (shader:ShaderImpl).uniforms.setMatrix3(name, Float32Array.fromArray([m00, m10, m20, m01, m11, m21, m02, m12, m22]));

    }

    /**
     * Sets a 4x4 matrix uniform value in the shader (column-major order).
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param m00 Column 0, row 0
     * @param m10 Column 0, row 1
     * @param m20 Column 0, row 2
     * @param m30 Column 0, row 3
     * @param m01 Column 1, row 0
     * @param m11 Column 1, row 1
     * @param m21 Column 1, row 2
     * @param m31 Column 1, row 3
     * @param m02 Column 2, row 0
     * @param m12 Column 2, row 1
     * @param m22 Column 2, row 2
     * @param m32 Column 2, row 3
     * @param m03 Column 3, row 0
     * @param m13 Column 3, row 1
     * @param m23 Column 3, row 2
     * @param m33 Column 3, row 3
     */
    inline public function setMat4(shader:Shader, name:String, m00:Float, m10:Float, m20:Float, m30:Float, m01:Float, m11:Float, m21:Float, m31:Float, m02:Float, m12:Float, m22:Float, m32:Float, m03:Float, m13:Float, m23:Float, m33:Float):Void {

        (shader:ShaderImpl).uniforms.setMatrix4(name, Float32Array.fromArray([m00, m10, m20, m30, m01, m11, m21, m31, m02, m12, m22, m32, m03, m13, m23, m33]));

    }

    /**
     * Calculates the total size of custom float attributes for a shader.
     * Used for vertex buffer layout calculations.
     * 
     * @param shader The shader to analyze
     * @return Total number of floats needed for custom attributes
     */
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

    /** Cached maximum if-statements supported by fragment shaders */
    static var _maxIfStatementsByFragmentShader:Int = -1;

    /**
     * Determines the maximum number of if-statements supported by the GPU's fragment shader.
     * Uses Clay.app.graphics.testShaderCompilationLimit() to test shader compilation.
     */
    inline static function computeMaxIfStatementsByFragmentShaderIfNeeded():Void {
        if (_maxIfStatementsByFragmentShader == -1) {
            _maxIfStatementsByFragmentShader = Clay.app.graphics.testShaderCompilationLimit(32);
        }
    }

    /**
     * Returns the maximum number of if-statements supported by fragment shaders.
     * Caches the result after first computation.
     *
     * @return Maximum if-statements supported
     */
    public function maxIfStatementsByFragmentShader():Int {
        computeMaxIfStatementsByFragmentShaderIfNeeded();
        return _maxIfStatementsByFragmentShader;
    }

    /**
     * Checks if a shader supports multi-texture batching.
     * Multi-texture shaders can render multiple textures in a single draw call.
     * 
     * @param shader The shader to check
     * @return True if the shader supports multi-texture batching
     */
    public function canBatchWithMultipleTextures(shader:Shader):Bool {

        return (shader:ShaderImpl).isBatchingMultiTexture;

    }

    /**
     * Indicates whether hot-reloading of shader files is supported.
     * Clay backend supports watching shader files for changes.
     * 
     * @return Always returns true for Clay backend
     */
    inline public function supportsHotReloadPath():Bool {

        return true;

    }

}
