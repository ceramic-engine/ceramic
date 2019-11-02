package ceramic;

import ceramic.Assets;
import ceramic.Color;
import ceramic.AlphaColor;
import ceramic.Texture;
import ceramic.Shortcuts.*;

using StringTools;

class Shader extends Entity {

/// Static helpers

    /** Instanciates a shader from source.
        Although it would expect `GLSL` code in default ceramic backends (luxe backend),
        Expected shading language could be different in some future backend implementations. */
    public static function fromSource(vertSource:String, fragSource:String):Shader {

        var backendItem = app.backend.shaders.fromSource(vertSource, fragSource);
        if (backendItem == null) return null;

        return new Shader(backendItem);

    } //fromSource

/// Properties

    public var backendItem:backend.Shader;

    public var asset:ShaderAsset;

    public var attributes:ImmutableArray<ShaderAttribute>;

    public var customAttributes:ImmutableArray<ShaderAttribute>;

/// Lifecycle

    public function new(backendItem:backend.Shader, ?customAttributes:ImmutableArray<ShaderAttribute>) {

        super();

        this.backendItem = backendItem;

        var attributes:Array<ShaderAttribute> = [
            { size: 4, name: 'vertexPosition' },
            { size: 4, name: 'vertexTCoord' },
            { size: 4, name: 'vertexColor' }
        ];

        if (customAttributes != null) {
            for (i in 0...customAttributes.length) {
                var attribute = customAttributes.unsafeGet(i);
                attributes.push(attribute);
            }
        }

        this.attributes = attributes;
        this.customAttributes = customAttributes;

    } //new

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.shaders.destroy(backendItem);
        backendItem = null;
        attributes = null;

    } //destroy

    public function clone():Shader {

        var clonedBackendItem = app.backend.shaders.clone(backendItem);
        var cloned = new Shader(clonedBackendItem, customAttributes);

        return cloned;

    } //clone

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

    inline public function setFloatArray(name:String, array:Array<Float>):Void {

        app.backend.shaders.setFloatArray(backendItem, name, array);

    } //setFloatArray

    inline public function setTexture(name:String, texture:Texture):Void {

        app.backend.shaders.setTexture(backendItem, name, texture.backendItem);

    } //setTexture

    inline public function setMat4FromTransform(name:String, transform:Transform):Void {

        app.backend.shaders.setMat4FromTransform(backendItem, name, transform);

    } //setTexture

/// Print

    override function toString():String {

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