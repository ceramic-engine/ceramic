package backend;

#if !no_backend_docs
/**
 * Unity implementation of the Info backend interface.
 * 
 * Provides platform-specific information about the Unity environment,
 * including storage paths and supported file extensions. This class
 * helps Ceramic understand the capabilities and constraints of the
 * Unity platform.
 * 
 * @see spec.Info The interface this class implements
 * @see backend.Backend Creates and provides this instance
 */
#end
class Info #if !completion implements spec.Info #end {

    #if !no_backend_docs
    /**
     * Cached persistent data path from Unity.
     * This is where save files and persistent data should be stored.
     */
    #end
    var _storageDirectory:String = null;

    #if !no_backend_docs
    /**
     * Creates a new Info instance.
     * Initializes the storage directory from Unity's persistent data path,
     * which varies by platform (e.g., AppData on Windows, Documents on iOS).
     */
    #end
    public function new() {

        #if (cs && unity)
        _storageDirectory = untyped __cs__('UnityEngine.Application.persistentDataPath');
        #end

    }

/// System

    #if !no_backend_docs
    /**
     * Gets the platform-specific persistent storage directory.
     * 
     * This directory is writable and persists between app launches.
     * On different platforms:
     * - Windows: %APPDATA%/CompanyName/ProductName
     * - macOS: ~/Library/Application Support/CompanyName/ProductName
     * - iOS: /var/mobile/Containers/Data/Application/<guid>/Documents
     * - Android: /storage/emulated/0/Android/data/<packagename>/files
     * 
     * @return Path to the persistent storage directory
     */
    #end
    public function storageDirectory():String {

        return _storageDirectory;

    }

/// Assets

    #if !no_backend_docs
    /**
     * Gets supported image file extensions.
     * Unity supports PNG, JPEG formats natively.
     * 
     * @return Array of supported image extensions without dots
     */
    #end
    inline public function imageExtensions():Array<String> {
        return ['png', 'jpg', 'jpeg'];
    }

    #if !no_backend_docs
    /**
     * Gets supported text file extensions.
     * Includes plain text, JSON data, bitmap fonts, and texture atlases.
     * 
     * @return Array of supported text extensions without dots
     */
    #end
    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt', 'atlas'];
    }

    #if !no_backend_docs
    /**
     * Gets supported audio file extensions.
     * Unity supports OGG Vorbis, MP3, and WAV formats.
     * 
     * @return Array of supported audio extensions without dots
     */
    #end
    inline public function soundExtensions():Array<String> {
        return ['ogg', 'mp3', 'wav'];
    }

    #if !no_backend_docs
    /**
     * Gets supported shader file extensions.
     * Custom shader format specific to Ceramic/Unity integration.
     * 
     * @return Array of supported shader extensions without dots
     */
    #end
    inline public function shaderExtensions():Array<String> {
        return ['shader'];
    }

}
