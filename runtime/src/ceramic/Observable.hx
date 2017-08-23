package ceramic;

/** Observable allows to observe properties of an object. */
#if !macro
@:autoBuild(ceramic.macros.ObservableMacro.build())
#end
interface Observable {}
