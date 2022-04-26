package assets;

import assets.AllAssets;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('sound'))
#end
class Sounds {}
