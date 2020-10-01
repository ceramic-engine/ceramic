package ceramic;

#if !ceramic_cppia_host
@:keep
@:keepSub
#end
@:autoBuild(ceramic.macros.CollectionsMacro.build())
interface AutoCollections {}