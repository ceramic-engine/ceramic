package haxe;

#if macro

@:coreApi
extern class Resource {
    static function listNames():Array<String>;
    static function getString(name:String):String;
    static function getBytes(name:String):haxe.io.Bytes;
}

#else

/**
 * `haxe.Resource` for the Unity backend.
 *
 * Haxe's C# target reads resources (`--resource file@name`) from the
 * manifest resources of the compiled assembly, but Unity compiles the
 * generated C# itself and embeds none. Ceramic's Unity export copies each
 * resource to `Assets/Ceramic/Resources/haxe_resources/<escaped name>.bytes`
 * (`UnityCSharp.exportResourcesToProject`), read here as a `TextAsset`.
 */
@:coreApi class Resource {

    @:keep static var content:Array<String>;

    public static inline function listNames():Array<String> {
        return content.copy();
    }

    public static function getString(name:String):String {
        final bytes = getBytes(name);
        return bytes != null ? bytes.toString() : null;
    }

    @:access(haxe.io.Path.escape)
    public static function getBytes(name:String):haxe.io.Bytes {
        final path = 'haxe_resources/' + haxe.io.Path.escape(name, true);
        final asset:unityengine.TextAsset = untyped __cs__('UnityEngine.Resources.Load<UnityEngine.TextAsset>({0})', path);
        if (asset == null)
            return null;
        return haxe.io.Bytes.ofData(asset.bytes);
    }

}

#end
