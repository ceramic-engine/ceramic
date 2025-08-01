package ceramic;

/**
 * Represents the current loading state of an asset.
 * 
 * Assets transition through these states during their lifecycle:
 * NONE -> LOADING -> READY (success) or BROKEN (failure)
 * 
 * The status is observable, allowing systems to react to asset state changes.
 * 
 * @see Asset.status
 */
enum AssetStatus {
    /**
     * Asset has not been loaded yet.
     * This is the initial state for newly created assets.
     */
    NONE;
    /**
     * Asset is currently being loaded.
     * Set when load() is called and loading is in progress.
     */
    LOADING;
    /**
     * Asset has been successfully loaded and is ready for use.
     * The asset's data (texture, sound, etc.) is available.
     */
    READY;
    /**
     * Asset loading failed or the asset is corrupted.
     * Check logs for specific error details.
     */
    BROKEN;
}
