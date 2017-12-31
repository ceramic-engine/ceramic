package backend;

import luxe.Resources;
import haxe.io.Path;

using StringTools;

class Shaders #if !completion implements spec.Shaders #end {

    public function new() {}

    public function load(path:String, options:LoadShaderOptions, done:Shader->Void):Void {

        path = Path.isAbsolute(path) || path.startsWith('http://') || path.startsWith('https://') ?
            path
        :
            Path.join([ceramic.App.app.settings.assetsPath, path]);

        var dir = path;

        var fragId = options.fragId != null ? options.fragId : 'default';
        var vertId = options.vertId != null ? options.vertId : 'default';

        path += '/[' + fragId + ',' + vertId + ']';

        if (fragId != 'default') {
            fragId = Path.join([dir, fragId]);
        }

        if (vertId != 'default') {
            vertId = Path.join([dir, vertId]);
        }

        if (loadedShaders.exists(path)) {
            loadedShadersRetainCount.set(path, loadedShadersRetainCount.get(path) + 1);
            var existing = Luxe.resources.shader(path);
            if (existing.state == ResourceState.loaded) {
                done(existing);
            } else {
                done(null);
            }
            return;
        }

        Luxe.resources.load_shader(path, {
            frag_id: fragId,
            vert_id: vertId,
            no_default_uniforms: options.noDefaultUniforms
        })
        .then(function(res:phoenix.Shader) {
            done(res);
        },
        function(_) {
            done(null);
        });

    } //load

    inline public function destroy(shader:Shader):Void {

        var id = (shader:phoenix.Shader).id;
        if (loadedShadersRetainCount.get(id) > 1) {
            loadedShadersRetainCount.set(id, loadedShadersRetainCount.get(id) - 1);
        }
        else {
            loadedShaders.remove(id);
            loadedShadersRetainCount.remove(id);
            (shader:phoenix.Shader).destroy(true);
        }

    } //destroy

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

    inline public function setTexture(shader:Shader, name:String, texture:backend.Texture):Void {
        
        (shader:phoenix.Shader).set_texture(name, texture);

    } //setTexture

    /*
    TODO
    inline public function setMatrix4(shader:Shader, name:String, matrix4:ceramic.Matrix3D):Void {
        
        (shader:phoenix.Shader).set_matrix4(name, matrix4)

    } //setMatrix4
    */

/// Internal

    var loadedShaders:Map<String,phoenix.Shader> = new Map();

    var loadedShadersRetainCount:Map<String,Int> = new Map();

} //Textures