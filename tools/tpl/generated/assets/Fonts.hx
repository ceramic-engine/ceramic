package assets;

import assets.AllAssets;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('font'))
#end
class Fonts {}
