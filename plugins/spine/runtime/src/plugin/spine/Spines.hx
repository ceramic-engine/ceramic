package plugin.spine;

import ceramic.AssetId;

#if !macro
@:build(plugin.spine.macros.SpineMacros.buildNames())
#end
class Spines {

    static var _clazz:Class<Dynamic>;

    public static function toAssetId(skeletonName:String):AssetId<Dynamic> {

        if (_clazz == null) _clazz = Type.resolveClass('plugin.spine.Spines');
        return Reflect.field(_clazz, skeletonName);

    } //toAssetId

} //Spines
