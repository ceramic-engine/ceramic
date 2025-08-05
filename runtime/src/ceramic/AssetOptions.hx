package ceramic;

/**
 * Asset loading options.
 * 
 * A dynamic type that allows passing asset-specific configuration options.
 * The actual fields depend on the asset type and backend implementation.
 * 
 * Common options include:
 * - `premultiplyAlpha` (Bool) - For images, whether to premultiply alpha channel
 * - `streaming` (Bool) - For sounds, whether to stream from disk
 * - `density` (Float) - Override density detection
 * - Custom backend-specific options
 * 
 * ```haxe
 * assets.addImage('hero', null, {
 *     premultiplyAlpha: true,
 *     generateMipmaps: false
 * });
 * ```
 */
typedef AssetOptions = Dynamic;
