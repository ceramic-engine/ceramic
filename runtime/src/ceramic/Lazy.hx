package ceramic;

/**
 * Lazy allows to mark any property as lazy.
 * Lazy properties are initialized only at first access.
 */
#if (!macro && !completion && !display)
@:autoBuild(ceramic.macros.LazyMacro.build())
#end
interface Lazy {}
