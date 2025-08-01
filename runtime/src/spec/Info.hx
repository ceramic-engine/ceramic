package spec;

/**
 * Backend interface for system and platform information.
 * 
 * This interface provides static information about the platform's capabilities,
 * file system paths, and supported asset formats. It's designed to work both
 * at runtime and compile-time, allowing build tools to query platform capabilities.
 * 
 * Implementations must ensure all methods return consistent values that don't
 * change during the application lifecycle.
 */
interface Info {

/// System

    /**
     * Gets the platform-specific directory for persistent storage.
     * This is where the application can safely write user data, save files,
     * and other persistent information that should survive app updates.
     * 
     * Examples:
     * - iOS/macOS: Application Support directory
     * - Android: Internal app storage
     * - Windows: %APPDATA% directory
     * - Web: Uses localStorage/IndexedDB (returns empty string)
     * 
     * @return The absolute path to the storage directory, or empty string if not available
     */
    function storageDirectory():String;

/// Assets

    /**
     * Gets the list of image file extensions supported by this backend.
     * These are the formats that can be loaded as textures.
     * Extensions should be lowercase without the dot (e.g., ["png", "jpg", "webp"]).
     * @return Array of supported image file extensions
     */
    function imageExtensions():Array<String>;

    /**
     * Gets the list of text file extensions that are treated as text assets.
     * These files will be loaded as UTF-8 strings.
     * Extensions should be lowercase without the dot (e.g., ["txt", "json", "xml"]).
     * @return Array of text file extensions
     */
    function textExtensions():Array<String>;

    /**
     * Gets the list of audio file extensions supported by this backend.
     * These are the formats that can be loaded and played as sounds.
     * Extensions should be lowercase without the dot (e.g., ["ogg", "mp3", "wav"]).
     * @return Array of supported audio file extensions
     */
    function soundExtensions():Array<String>;

    /**
     * Gets the list of shader file extensions supported by this backend.
     * These files contain GPU shader programs (vertex/fragment shaders).
     * Extensions should be lowercase without the dot (e.g., ["glsl", "vert", "frag"]).
     * @return Array of supported shader file extensions
     */
    function shaderExtensions():Array<String>;

}
