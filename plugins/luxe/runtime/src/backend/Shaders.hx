package backend;

import luxe.Resources;
import haxe.io.Path;

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

    inline public function setTexture(shader:Shader, name:String, texture:Image):Void {
        
        (shader:phoenix.Shader).set_texture(name, texture);

    } //setTexture

    /*
    TODO
    inline public function setMatrix4(shader:Shader, name:String, matrix4:ceramic.Matrix3D):Void {
        
        (shader:phoenix.Shader).set_matrix4(name, matrix4)

    } //setMatrix4
    */

} //Textures