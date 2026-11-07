// Ported from gpui-pre 0.3.10: src/assets.rs (AssetSource)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.io.Bytes;

/**
 * A source of assets for this app to use (SVG icons, embedded images,
 * fonts). `load()` is synchronous, like in GPUI: on targets without
 * synchronous file access, preload the files first (see `CeramicAssetSource`).
 */
interface AssetSource {

    /**
     * Load the given asset from the source path, or `null` if it doesn't exist.
     */
    function load(path:String):Null<Bytes>;

    /**
     * List the assets at the given path.
     */
    function list(path:String):Array<String>;

}
