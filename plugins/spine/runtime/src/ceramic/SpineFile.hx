package ceramic;

import spine.support.files.FileHandle;

/**
 * Implementation of Spine's FileHandle interface for Ceramic.
 * 
 * This class provides a simple in-memory file representation that the Spine runtime
 * can use to access file content. It's used internally when loading Spine assets
 * to provide the Spine runtime with access to atlas files and other text-based resources.
 * 
 * The SpineFile acts as an adapter between Ceramic's asset loading system and
 * Spine's file handling expectations, storing file content in memory as a string.
 * 
 * @example
 * ```haxe
 * // This is typically used internally by SpineAsset
 * var atlasContent = assets.text("hero.atlas").content;
 * var spineFile = new SpineFile("hero.atlas", atlasContent);
 * 
 * // The Spine runtime can then use this file handle
 * var atlas = new TextureAtlas(spineFile, ...);
 * ```
 */
class SpineFile implements FileHandle {

    /**
     * The path or identifier of this file.
     * This is typically the asset path or filename, used for identification
     * purposes within the Spine runtime.
     */
    public var path:String;

    /**
     * The text content of the file stored in memory.
     * This contains the actual file data that will be returned when
     * the Spine runtime requests the file content.
     */
    public var content:String;

    /**
     * Gets the content of this file.
     * 
     * This method is required by the FileHandle interface and is called
     * by the Spine runtime when it needs to read the file data.
     * 
     * @return The complete file content as a string
     */
    public function getContent():String {
        return content;
    }

    /**
     * Creates a new SpineFile instance with the specified path and content.
     * 
     * @param path The file path or identifier
     * @param content The text content of the file
     */
    public function new(path:String, content:String) {
        this.path = path;
        this.content = content;
    }

}
