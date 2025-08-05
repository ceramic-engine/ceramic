package ceramic;

/**
 * Defines a custom asset type that can be registered with the Assets system.
 * 
 * CustomAssetKind allows you to extend Ceramic's asset system with your own
 * asset types beyond the built-in ones (image, text, sound, etc.). This is
 * useful for game-specific or application-specific asset formats.
 * 
 * When registered, the Assets system will automatically recognize files with
 * the specified extensions and handle them using your custom logic.
 * 
 * ```haxe
 * // Define a custom asset kind for level files
 * var levelAssetKind:CustomAssetKind = {
 *     kind: 'level',
 *     extensions: ['lvl', 'level'],
 *     add: (assets, name, variant, options) -> {
 *         var asset = new LevelAsset(name, variant, options);
 *         assets.addAsset(asset);
 *     },
 *     dir: false,
 *     types: null
 * };
 * 
 * // Register it with the Assets system
 * Assets.customAssetKinds.push(levelAssetKind);
 * 
 * // Now you can load level files like any other asset
 * assets.add('levels/world1');  // Will load world1.lvl or world1.level
 * ```
 * 
 * @see Assets
 * @see Asset
 */
@:structInit
class CustomAssetKind {

    /**
     * The unique identifier for this asset type.
     * This string is used internally by the asset system and should be
     * unique among all registered asset kinds.
     * 
     * Examples: 'level', 'dialog', 'quest', 'particle'
     */
    public var kind:String;

    /**
     * Function called when an asset of this type needs to be added to the Assets collection.
     * 
     * This function should:
     * 1. Create an instance of your custom Asset subclass
     * 2. Configure it with the provided parameters
     * 3. Add it to the assets collection using assets.addAsset()
     * 
     * @param assets The Assets instance to add the asset to
     * @param name The asset name (without extension)
     * @param variant Optional variant suffix (e.g., "@2x" for high-res)
     * @param options Additional loading options
     */
    public var add:(assets:Assets, name:String, variant:String, options:AssetOptions)->Void;

    /**
     * Array of file extensions (without dots) that identify this asset type.
     * 
     * The Assets system uses these extensions to determine which CustomAssetKind
     * to use when loading files. Extensions are case-insensitive.
     * 
     * Examples: ['lvl', 'level'], ['dialog', 'dlg'], ['particle', 'ptc']
     */
    public var extensions:Array<String>;

    /**
     * Whether this asset type represents a directory rather than a file.
     * 
     * Set to true if your asset type loads entire directories (like a folder
     * of images for an animation). Set to false for single file assets.
     * 
     * Default should be false for most custom asset types.
     */
    public var dir:Bool;

    /**
     * Array of additional type identifiers for this asset kind.
     * 
     * This can be used to provide alternative ways to identify the asset type
     * beyond file extensions. Can be null if not needed.
     * 
     * This is primarily used internally by the framework.
     */
    public var types:Array<String>;

}
