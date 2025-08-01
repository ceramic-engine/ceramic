package ceramic;

// Original: https://github.com/HaxeFlixel/flixel/tree/43a3895d9479f8fdff9296637ef4fab25c473ecb/flixel/util/typeLimit

/**
 * A type that can hold a value of either type T1 or type T2.
 * 
 * Either is useful for function parameters that can accept multiple types
 * while still providing compile-time type hints. At runtime, the value
 * is still Dynamic, so type checking may be necessary.
 * 
 * ## Important Notes
 * 
 * - This does NOT make Dynamic usage type-safe
 * - Runtime type checks with Std.isOfType() are still necessary
 * - The underlying type is Dynamic, so runtime errors are possible
 * - Best used for API clarity rather than type safety
 * 
 * ## Usage Examples
 * 
 * ```haxe
 * // Function accepting String or Int
 * function processValue(value:Either<String, Int>) {
 *     if (Std.isOfType(value, String)) {
 *         trace("String: " + cast(value, String));
 *     } else if (Std.isOfType(value, Int)) {
 *         trace("Int: " + cast(value, Int));
 *     }
 * }
 * 
 * processValue("hello");  // Works
 * processValue(42);       // Works
 * // processValue(true);  // Compile error
 * 
 * // Common pattern with asset loading
 * function loadAsset(id:Either<String, AssetId<String>>):String {
 *     if (Std.isOfType(id, AssetId)) {
 *         return cast(id, AssetId<String>).toString();
 *     }
 *     return cast id;
 * }
 * ```
 * 
 * ## Type Parameters
 * 
 * @param T1 First possible type
 * @param T2 Second possible type
 * 
 * @see ceramic.OneOf For 3+ type alternatives
 */
abstract Either<T1, T2>(Dynamic) from T1 from T2 to T1 to T2 {}
