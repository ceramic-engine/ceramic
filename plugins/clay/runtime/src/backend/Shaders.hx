package backend;

import ceramic.Path;
import ceramic.ReadOnlyArray;
import clay.opengl.GL;

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
     * Sets a color uniform value (vec4) in the shader.
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     * @param a Alpha component (0-1)
     */
    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {

        (shader:ShaderImpl).uniforms.setColor(name, r, g, b, a);

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
     * Sets a 4x4 matrix uniform from a 2D transform.
     * Converts the 2D transform to a 4x4 matrix suitable for GPU usage.
     * 
     * @param shader Target shader program
     * @param name Uniform variable name
     * @param transform 2D transformation to convert
     */
    inline public function setMat4FromTransform(shader:Shader, name:String, transform:ceramic.Transform):Void {

        (shader:ShaderImpl).uniforms.setMatrix4(name, ceramic.Float32Array.fromArray([
            transform.a, transform.b, 0, 0,
            transform.c, transform.d, 0, 0,
            0, 0, 1, 0,
            transform.tx, transform.ty, 0, 1
        ]));

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
     * Tests by compiling shaders with varying numbers of conditionals.
     * 
     * @param maxIfs Starting maximum to test (halves on failure)
     */
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

    /**
     * Generates a series of if-else statements for shader compilation testing.
     * Used to determine GPU conditional complexity limits.
     * 
     * @param maxIfs Number of if-statements to generate
     * @return GLSL code with chained if-else statements
     */
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
