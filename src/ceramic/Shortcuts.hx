package ceramic;

/** Shortcuts adds convenience identifiers to access ceramic app, screen, ... */
#if !macro
@:autoBuild(ceramic.macros.ShortcutsMacro.build())
#end
interface Shortcuts {}
