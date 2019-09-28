package backend;

import luxe.Resources;
import ceramic.Path;
import snow.modules.opengl.GL;

using StringTools;

class Shaders implements spec.Shaders {

    public function new() {}

    inline public function fromSource(vertSource:String, fragSource:String, ?customAttributes:ceramic.ImmutableArray<ceramic.ShaderAttribute>):Shader {

        var shader = new backend.impl.CeramicShader({
            id: ceramic.Utils.uniqueId(),
            vert_id: null,
            frag_id: null
        });

        shader.customAttributes = customAttributes;

        if (!shader.from_string(vertSource, fragSource)) {
            return null;
        }

        return shader;

    } //fromSource

    inline public function destroy(shader:Shader):Void {

        (shader:phoenix.Shader).destroy(true);

    } //destroy

    inline public function clone(shader:Shader):Shader {

        var cloned = new backend.impl.CeramicShader({
            id: ceramic.Utils.uniqueId(),
            frag_id: null,
            vert_id: null
        });

        cloned.from_string(
            (shader:backend.impl.CeramicShader).vert_source,
            (shader:backend.impl.CeramicShader).frag_source
        );

        return cloned;

    } //clone

/// Public API

    inline public function setInt(shader:Shader, name:String, value:Int):Void {
        
        (shader:phoenix.Shader).set_int(name, value);

    } //setInt

    inline public function setFloat(shader:Shader, name:String, value:Float):Void {
        
        (shader:phoenix.Shader).set_float(name, value);

    } //setFloat

    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {
        
        (shader:phoenix.Shader).set_color(name, new phoenix.Color(r, g, b, a));

    } //setColor

    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {
        
        (shader:phoenix.Shader).set_vector2(name, new phoenix.Vector(x, y));

    } //setVec2

    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {
        
        (shader:phoenix.Shader).set_vector3(name, new phoenix.Vector(x, y, z));

    } //setVec3

    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {
        
        (shader:phoenix.Shader).set_vector4(name, new phoenix.Vector(x, y, z, w));

    } //setVec4

    inline public function setFloatArray(shader:Shader, name:String, array:Array<Float>):Void {
        
        (shader:phoenix.Shader).set_float_arr(name, ceramic.Float32Array.fromArray(array));

    } //setFloatArray

    inline public function setTexture(shader:Shader, name:String, texture:Texture):Void {
        
        (shader:phoenix.Shader).set_texture(name, texture);

    } //setTexture

    static var _maxIfStatementsByShader:Int = -1;

    inline static function computeMaxIfStatementsByShaderIfNeeded():Void {

        if (_maxIfStatementsByShader == -1) {
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
            var maxIfs = 32;

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
                    _maxIfStatementsByShader = maxIfs;
                    break;
                }
            }

            GL.deleteShader(shader);
        }

    } //computeMaxIfStatementsByShaderIfNeeded

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

    } //generateIfStatements

    public function maxIfStatementsByShader():Int {

        computeMaxIfStatementsByShaderIfNeeded();
        return _maxIfStatementsByShader;

    } //maxIfStatementsByShader

    /*
    TODO
    inline public function setMatrix4(shader:Shader, name:String, matrix4:ceramic.Matrix3D):Void {
        
        (shader:phoenix.Shader).set_matrix4(name, matrix4)

    } //setMatrix4
    */

} //Textures