package ceramic;

/**
 * A compile-time generated class containing constants for all fragment assets.
 * 
 * The AssetsMacro build macro scans the project's fragments directory
 * and generates static string constants for each fragment file found.
 * This provides type-safe, autocomplete-friendly access to fragment names.
 * 
 * Example usage:
 * ```haxe
 * // Instead of using string literals:
 * assets.fragment("myFragment");
 * 
 * // Use generated constants:
 * assets.fragment(Fragments.MY_FRAGMENT);
 * ```
 * 
 * The generated constants follow UPPER_SNAKE_CASE naming convention,
 * derived from the fragment file names.
 * 
 * @see Assets
 * @see FragmentAsset
 * @see Fragment
 */
#if !macro
@:build(ceramic.macros.AssetsMacro.buildNames('fragments'))
#end
class Fragments {}
