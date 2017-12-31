package ceramic;

#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('database'))
#end
class Databases {}
