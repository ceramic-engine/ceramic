package backend;

import haxe.io.Path;

using StringTools;

class Shaders #if !completion implements spec.Shaders #end {

    public function new() {}

    public function load(path:String, options:LoadShaderOptions, done:Shader->Void):Void {

        done(new ShaderImpl());

    } //load

    inline public function destroy(shader:Shader):Void {

        //

    } //destroy

/// Public API

    inline public function setInt(shader:Shader, name:String, value:Int):Void {
        
        //

    } //setInt

    inline public function setFloat(shader:Shader, name:String, value:Float):Void {
        
        //

    } //setFloat

    inline public function setColor(shader:Shader, name:String, r:Float, g:Float, b:Float, a:Float):Void {
        
        //

    } //setColor

    inline public function setVec2(shader:Shader, name:String, x:Float, y:Float):Void {
        
        //

    } //setVec2

    inline public function setVec3(shader:Shader, name:String, x:Float, y:Float, z:Float):Void {
        
        //

    } //setVec3

    inline public function setVec4(shader:Shader, name:String, x:Float, y:Float, z:Float, w:Float):Void {
        
        //

    } //setVec4

    inline public function setTexture(shader:Shader, name:String, texture:backend.Texture):Void {
        
        //

    } //setTexture

} //Shaders
