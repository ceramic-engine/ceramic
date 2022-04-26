package assets;

import ceramic.Assets;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildLists())
#end
class AllAssets {

    public static function __init__() {

        bind();

    }

    public static function bind() {

        Assets.all = all;
        Assets.allDirs = allDirs;
        Assets.allDirsByName = allDirsByName;
        Assets.allByName = allByName;

    }

}
