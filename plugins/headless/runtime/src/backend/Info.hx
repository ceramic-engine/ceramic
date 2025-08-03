package backend;

/**
 * System information provider for the headless backend.
 * 
 * This class provides information about the platform capabilities
 * and supported file formats. In headless mode, it returns
 * standard file extensions that would typically be supported
 * across platforms.
 * 
 * This information is used by the asset loading system to
 * determine which file formats to attempt loading.
 */
class Info #if !completion implements spec.Info #end {

    /**
     * Creates a new headless info provider.
     */
    public function new() {}

/// System

    /**
     * Gets the platform-specific storage directory for persistent data.
     * 
     * In headless mode, this returns null since no specific storage
     * directory is defined.
     * 
     * @return Always null in headless mode
     */
    inline public function storageDirectory():String {
        return null;
    }

/// Assets

    /**
     * Gets the list of supported image file extensions.
     * 
     * These are the file extensions that the backend claims to support
     * for image loading. In headless mode, this returns common formats
     * even though no actual image processing occurs.
     * 
     * @return Array of supported image extensions
     */
    inline public function imageExtensions():Array<String> {
        return ['png', 'jpg', 'jpeg'];
    }

    /**
     * Gets the list of supported text file extensions.
     * 
     * These are the file extensions that the backend supports
     * for text loading. The headless backend can actually load
     * these on platforms with filesystem access.
     * 
     * @return Array of supported text extensions
     */
    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt', 'atlas'];
    }

    /**
     * Gets the list of supported audio file extensions.
     * 
     * These are the file extensions that the backend claims to support
     * for audio loading. In headless mode, this returns common formats
     * even though no actual audio processing occurs.
     * 
     * @return Array of supported audio extensions
     */
    inline public function soundExtensions():Array<String> {
        return ['ogg', 'wav'];
    }

    /**
     * Gets the list of supported shader file extensions.
     * 
     * These are the file extensions that the backend claims to support
     * for shader loading. In headless mode, this returns common formats
     * even though no actual shader compilation occurs.
     * 
     * @return Array of supported shader extensions
     */
    inline public function shaderExtensions():Array<String> {
        return ['glsl', 'frag', 'vert'];
    }

}
