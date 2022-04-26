package assets;

import assets.AllAssets;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('database'))
#end
class Databases {}
