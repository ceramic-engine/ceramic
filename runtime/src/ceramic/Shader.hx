package ceramic;

import ceramic.AlphaColor;
import ceramic.Assets;
import ceramic.Color;
import ceramic.Shortcuts.*;
import ceramic.Texture;

using StringTools;

class Shader extends Entity {

/// Static helpers

#if ceramic_shader_vert_frag
    /**
     * Instanciates a shader from source.
     * Although it would expect `GLSL` code in default ceramic backends (luxe backend),
     * Expected shading language could be different in some future backend implementations.
     */
    public static function fromSource(vertSource:String, fragSource:String):Shader {

        var backendItem = app.backend.shaders.fromSource(vertSource, fragSource);
        if (backendItem == null) return null;

        return new Shader(backendItem);

    }
#end

/// Properties

    public var backendItem:backend.Shader;

    public var asset:ShaderAsset;

    public var attributes:ReadOnlyArray<ShaderAttribute>;

    public var customAttributes:ReadOnlyArray<ShaderAttribute>;

    public var customFloatAttributesSize(default, null):Int;

    var textureSlots:IntMap<Texture> = null;

    @:allow(ceramic.App)
    var usedTextures:Array<Texture> = null;

/// Lifecycle

    public function new(backendItem:backend.Shader, ?customAttributes:ReadOnlyArray<ShaderAttribute>) {

        super();

        this.backendItem = backendItem;

        var attributes:Array<ShaderAttribute> = [
            { size: 3, name: 'vertexPosition' },
            { size: 2, name: 'vertexTCoord' },
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

        this.customFloatAttributesSize = app.backend.shaders.customFloatAttributesSize(backendItem);

    }

    override function destroy() {

        super.destroy();

        if (asset != null) asset.destroy();

        app.backend.shaders.destroy(backendItem);
        backendItem = null;
        attributes = null;

    }

    public function clone():Shader {

        var clonedBackendItem = app.backend.shaders.clone(backendItem);
        var cloned = new Shader(clonedBackendItem, customAttributes);

        return cloned;

    }

/// Public API

    inline public function setInt(name:String, value:Int):Void {

        app.backend.shaders.setInt(backendItem, name, value);

    }

    inline public function setFloat(name:String, value:Float):Void {

        app.backend.shaders.setFloat(backendItem, name, value);

    }

    inline public function setColor(name:String, color:Color):Void {

        app.backend.shaders.setColor(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, 1.0);

    }

    inline public function setAlphaColor(name:String, color:AlphaColor):Void {

        app.backend.shaders.setColor(backendItem, name, color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat);

    }

    inline public function setVec2(name:String, x:Float, y:Float):Void {

        app.backend.shaders.setVec2(backendItem, name, x, y);

    }

    inline public function setVec3(name:String, x:Float, y:Float, z:Float):Void {

        app.backend.shaders.setVec3(backendItem, name, x, y, z);

    }

    inline public function setVec4(name:String, x:Float, y:Float, z:Float, w:Float):Void {

        app.backend.shaders.setVec4(backendItem, name, x, y, z, w);

    }

    inline public function setFloatArray(name:String, array:Array<Float>):Void {

        app.backend.shaders.setFloatArray(backendItem, name, array);

    }

    public function setTexture(name:String, slot:Int, texture:Texture):Void {

        if (textureSlots == null) {
            textureSlots = new IntMap();
            usedTextures = [];
        }

        // Remove previous texture (if any) at slot
        final prevTexture = textureSlots.get(slot);
        if (prevTexture != null) {
            usedTextures.splice(usedTextures.indexOf(prevTexture), 1);
        }

        // Add new texture (if any) at slot
        textureSlots.set(slot, texture);
        if (texture != null) {
            usedTextures.push(texture);
        }

        app.backend.shaders.setTexture(backendItem, name, slot, texture?.backendItem);

    }

    inline public function setMat4FromTransform(name:String, transform:Transform):Void {

        app.backend.shaders.setMat4FromTransform(backendItem, name, transform);

    }

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

    }

} //Shader