package ceramic;

/**
 * Supported image file formats for loading and exporting images.
 * 
 * ImageType represents the different image formats that Ceramic can work with.
 * These formats are used when loading image assets, exporting render textures,
 * or specifying expected file types for image operations.
 * 
 * The enum is implemented as an abstract over String, allowing:
 * - Direct string conversion for file extensions
 * - Type-safe image format specification
 * - Easy integration with file system operations
 * 
 * @example
 * ```haxe
 * // Loading images with specific types
 * var texture = app.assets.texture('logo.png');
 * 
 * // Exporting render texture
 * renderTexture.exportToFile('screenshot.png', PNG);
 * 
 * // Checking file type
 * var extension = Path.extension(filename);
 * var imageType:ImageType = extension; // Auto-converts from string
 * ```
 * 
 * @see ImageAsset For loading image files
 * @see RenderTexture.exportToFile For saving images
 * @see Texture The loaded image representation
 */
enum abstract ImageType(String) from String to String {

    /**
     * PNG (Portable Network Graphics) format.
     * 
     * Features:
     * - Lossless compression
     * - Full alpha channel support (transparency)
     * - Best for sprites, UI elements, and images requiring transparency
     * - Larger file sizes but perfect quality
     * - Recommended for most game graphics
     * 
     * Use cases:
     * - Character sprites with transparency
     * - UI elements and icons
     * - Pixel art (preserves sharp edges)
     * - Any image requiring alpha channel
     * 
     * @example
     * ```haxe
     * // PNG is ideal for sprites
     * var sprite = app.assets.texture('character.png');
     * ```
     */
    var PNG = 'png';

    /**
     * JPEG (Joint Photographic Experts Group) format.
     * 
     * Features:
     * - Lossy compression with adjustable quality
     * - No alpha channel support
     * - Smaller file sizes than PNG
     * - Best for photographs and backgrounds without transparency
     * - Quality loss increases with compression
     * 
     * Use cases:
     * - Background images
     * - Photographic textures
     * - Large images where file size matters
     * - Images without transparency requirements
     * 
     * @example
     * ```haxe
     * // JPEG for backgrounds without transparency
     * var background = app.assets.texture('landscape.jpeg');
     * ```
     */
    var JPEG = 'jpeg';

    /**
     * GIF (Graphics Interchange Format) format.
     * 
     * Features:
     * - Limited to 256 colors
     * - Supports simple transparency (no alpha gradients)
     * - Can contain animations (though Ceramic loads first frame only)
     * - Lossless compression for limited color palette
     * - Generally not recommended for modern games
     * 
     * Use cases:
     * - Legacy image support
     * - Simple graphics with few colors
     * - When file format compatibility requires GIF
     * 
     * Note: For animated content, consider using sprite sheets
     * or video formats instead of animated GIFs.
     * 
     * @example
     * ```haxe
     * // GIF support for compatibility
     * var icon = app.assets.texture('legacy_icon.gif');
     * ```
     */
    var GIF = 'gif';

}