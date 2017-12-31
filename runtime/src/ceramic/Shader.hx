package ceramic;

import ceramic.Assets;
import ceramic.Color;
import ceramic.AlphaColor;
import ceramic.Texture;
import ceramic.Shortcuts.*;

using StringTools;

class Shader extends Entity {

    public var backendItem:backend.Shader;

    public var asset:ShaderAsset;

/// Lifecycle

    public function new(backendItem:backend.Shader) {

        this.backendItem = backendItem;

    } //new

    public function destroy() {

        if (asset != null) asset.destroy();

        app.backend.shaders.destroy(backendItem);
        backendItem = null;

    } //destroy

/// Public API

    inline public function setInt(name:String, value:Int):Void {

        app.backend.shaders.setInt(backendItem, name, value);

    } //setInt

    inline public function setFloat(name:String, value:Float):Void {

        app.backend.shaders.setFloat(backendItem, name, value);

    } //setFloat

    inline public function setColor(name:String, color:Color):Void {

        app.backend.shaders.setColor(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, 1.0);

    } //setColor

    inline public function setAlphaColor(name:String, color:AlphaColor):Void {

        app.backend.shaders.setColor(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat);

    } //setAlphaColor

    inline public function setVec2(name:String, x:Float, y:Float):Void {

        app.backend.shaders.setVec2(backendItem, name, x, y);

    } //setVec2

    inline public function setVec3(name:String, x:Float, y:Float, z:Float):Void {

        app.backend.shaders.setVec3(backendItem, name, x, y, z);

    } //setVec3

    inline public function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Void {

        app.backend.shaders.setVec4(backendItem, name, x, y, z, w);

    } //setVec4

    inline public function setTexture(name:String, texture:Texture):Void {

        app.backend.shaders.setTexture(backendItem, name, texture.backendItem);

    } //setTexture

/// Print

    function toString():String {

        if (id != null) {
            var name = id;
            if (name.startsWith('shader:')) name = name.substr(7);
            if (asset != null && asset.options.vertId != null || asset.options.fragId != null) {
                var vertId = asset.options.vertId != null ? asset.options.vertId : 'default';
                var fragId = asset.options.fragId != null ? asset.options.fragId : 'default';
                return 'Shader($name $vertId $fragId)';
            }
            else {
                return 'Shader($name)';
            }
        } else {
            return 'Shader()';
        }

    } //toString

} //Shader