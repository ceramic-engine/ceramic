package spec;

import haxe.io.Bytes;
import backend.LoadBinaryOptions;

/**
 * Backend interface for binary data loading operations.
 * 
 * This interface handles loading raw binary files from various sources (disk, network, embedded).
 * Binary data is returned as Haxe Bytes objects, which provide cross-platform byte array handling.
 * 
 * Used by the BinaryAsset class and other systems that need raw file access.
 */
interface Binaries {

    /**
     * Loads binary data from the specified path.
     * The path is relative to the assets directory unless it's an absolute path or URL.
     * @param path The path to the binary file to load
     * @param options Optional loading configuration (caching, hot-reload, etc.)
     * @param done Callback invoked with the loaded Bytes data or null on failure
     */
    function load(path:String, ?options:LoadBinaryOptions, done:Bytes->Void):Void;

    /**
     * Checks if the backend supports hot-reloading of binary files.
     * When true, files can include a `?hot=timestamp` query parameter to bypass caching
     * and force reloading when the file changes during development.
     * @return True if hot-reload paths are supported, false otherwise
     */
    function supportsHotReloadPath():Bool;

}
