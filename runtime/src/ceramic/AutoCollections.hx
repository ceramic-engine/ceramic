package ceramic;

/**
 * Interface that enables automatic collection generation for classes.
 * 
 * When a class implements AutoCollections, the CollectionsMacro will
 * automatically generate collection management code for arrays and maps
 * in the class. This includes:
 * - Automatic cleanup of collections on destroy
 * - Observable collection support
 * - Efficient memory management
 * 
 * The macro analyzes the class fields and generates appropriate
 * collection handling code at compile time.
 * 
 * Example usage:
 * ```haxe
 * class MyClass extends Entity implements AutoCollections {
 *     var items:Array<Item> = [];
 *     var lookup:Map<String, Item> = new Map();
 *     // Collections will be automatically managed
 * }
 * ```
 * 
 * @see Collection
 * @see CollectionEntry
 */
#if !ceramic_cppia_host
@:keep
@:keepSub
#end
@:autoBuild(ceramic.macros.CollectionsMacro.build())
interface AutoCollections {}