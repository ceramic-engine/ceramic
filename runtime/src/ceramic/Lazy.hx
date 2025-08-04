package ceramic;

/**
 * Interface for implementing lazy initialization of properties in Ceramic classes.
 *
 * When a class implements the Lazy interface, properties marked with `@lazy` metadata
 * will be initialized only when first accessed, not when the object is created.
 * This can improve performance by deferring expensive computations or object allocations
 * until they are actually needed.
 *
 * The lazy initialization is implemented through compile-time code generation using
 * the LazyMacro build macro, which transforms lazy properties into getter methods
 * with initialization logic.
 *
 * Example usage:
 * ```haxe
 * class MyClass implements Lazy {
 *
 *     // This heavy texture atlas will only be loaded when first accessed
 *     @lazy public var atlas:TextureAtlas = TextureAtlas.fromTexture(heavyTexture);
 *
 *     // Expensive computation deferred until needed
 *     @lazy public var complexData:Array<Float> = computeExpensiveData();
 * }
 *
 * // Usage:
 * var obj = new MyClass(); // No lazy properties initialized yet
 * var atlas = obj.atlas;   // Now the atlas is loaded
 * var data = obj.complexData; // Now the data is computed
 * ```
 *
 * Benefits:
 * - Faster object creation when not all properties are immediately needed
 * - Reduced memory usage when some properties may never be accessed
 * - Automatic initialization (single initialization guaranteed)
 * - Clean syntax without manual lazy initialization boilerplate
 *
 * Limitations:
 * - Only works with instance properties, not static properties
 * - The initialization expression is evaluated in the context of first access
 * - Cannot be used with properties that have custom getters/setters
 * - Not thread safe: should be used on objects that are tied to a single thread
 *
 * @see ceramic.macros.LazyMacro The macro that implements lazy initialization
 */
#if (!macro && !completion && !display)
@:autoBuild(ceramic.macros.LazyMacro.build())
#end
interface Lazy {}
