package assets;

import assets.AllAssets;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('shader'))
#end
class Shaders {}
