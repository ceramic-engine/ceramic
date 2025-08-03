package ceramic;

import spine.support.graphics.TextureAtlas;
import spine.support.graphics.TextureLoader;

/**
 * Custom texture loader implementation for integrating Spine with Ceramic's asset system.
 * 
 * This class implements Spine's TextureLoader interface to handle texture loading
 * for Spine animations. It acts as a bridge between Spine's texture atlas system
 * and Ceramic's asset management, ensuring textures are loaded through Ceramic's
 * pipeline with proper caching, hot-reloading, and resource management.
 * 
 * The loader is used internally by SpineAsset when parsing texture atlases.
 * It delegates the actual loading work to the SpineAsset instance, which
 * handles the integration with Ceramic's texture loading system.
 * 
 * Key responsibilities:
 * - Loading texture pages (images) referenced in Spine atlases
 * - Managing texture lifecycle (load/unload)
 * - Handling path resolution with optional base paths
 * 
 * @see SpineAsset for the actual texture loading implementation
 */
@:access(ceramic.SpineAsset)
class SpineTextureLoader implements TextureLoader
{
    /**
     * The SpineAsset instance that handles the actual texture loading.
     * This asset manages the integration with Ceramic's asset system.
     */
    private var asset:SpineAsset;

    /**
     * Optional base path prepended to texture paths in the atlas.
     * 
     * This allows atlases to use relative paths while the actual texture
     * files are located in a specific directory. For example, if basePath
     * is "characters/hero/", a texture path "body.png" in the atlas would
     * resolve to "characters/hero/body.png".
     */
    private var basePath:Null<String>;

    /**
     * Creates a new SpineTextureLoader instance.
     * 
     * @param asset The SpineAsset that will handle texture loading operations
     * @param basePath Optional base path to prepend to texture paths in the atlas
     */
    public function new(asset:SpineAsset, ?basePath:String) {

        this.asset = asset;
        this.basePath = basePath;

    }

    /**
     * Loads a texture page (image) for the atlas.
     * 
     * This method is called by the Spine runtime when parsing an atlas file.
     * It delegates to the SpineAsset to load the texture through Ceramic's
     * asset system, ensuring proper caching and resource management.
     * 
     * @param page The AtlasPage to load the texture for. The loader should set
     *             the page's rendererObject to the loaded texture.
     * @param path The path to the texture file as specified in the atlas
     */
    public function loadPage(page:AtlasPage, path:String):Void {

        asset.loadPage(page, path, basePath);

    }

    /**
     * Called after a region is loaded from the atlas.
     * 
     * This method is part of the TextureLoader interface but is not used
     * in Ceramic's implementation. Region setup is handled automatically
     * by the Spine runtime after the page texture is loaded.
     * 
     * @param region The atlas region that was just loaded
     */
    public function loadRegion(region:AtlasRegion):Void {

        // Nothing to do here

    }

    /**
     * Unloads a texture page to free resources.
     * 
     * This method is called when an atlas is being disposed. It delegates
     * to the SpineAsset to properly clean up the texture and remove it
     * from Ceramic's texture cache.
     * 
     * @param page The AtlasPage whose texture should be unloaded
     */
    public function unloadPage(page:AtlasPage):Void {

        asset.unloadPage(page);

    }
}
