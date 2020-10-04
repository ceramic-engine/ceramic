package assets;

import ceramic.AssetId;

import assets.AllAssets;

#if !macro
@:build(ceramic.macros.SpineMacros.buildNames())
#end
@:keep class Spines {

    static var _clazz:Class<Dynamic>;

    public static function toAssetId(skeletonName:String):AssetId<Dynamic> {

        if (_clazz == null) _clazz = Type.resolveClass('ceramic.Spines');
        return Reflect.field(_clazz, skeletonName);

    }

}
