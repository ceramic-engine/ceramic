package spec;

import backend.LoadTextOptions;

/**
 * Backend interface for text file loading operations.
 * 
 * This interface handles loading text files from various sources. Text files
 * are loaded as UTF-8 encoded strings and include any file type marked as
 * text by the backend (txt, json, xml, etc.).
 * 
 * The interface is separate from Binaries to allow backends to optimize
 * text handling differently from binary data, such as applying text-specific
 * caching or encoding conversions.
 * 
 * Used by the TextAsset class and other systems that need text file access.
 */
interface Texts {

    /**
     * Loads a text file from the specified path.
     * 
     * The file is loaded as a UTF-8 string. The path is relative to the
     * assets directory unless it's an absolute path or URL.
     * 
     * @param path The path to the text file to load
     * @param options Optional loading configuration (caching, hot-reload, etc.)
     * @param done Callback invoked with the loaded text content or null on failure
     */
    function load(path:String, ?options:LoadTextOptions, done:String->Void):Void;

    /**
     * Checks if the backend supports hot-reloading of text files.
     * 
     * When true, files can include a `?hot=timestamp` query parameter to
     * bypass caching and force reloading when the file changes during development.
     * This is particularly useful for configuration files and data that changes
     * frequently during development.
     * 
     * @return True if hot-reload paths are supported, false otherwise
     */
    function supportsHotReloadPath():Bool;

}
