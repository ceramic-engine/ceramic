// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.AtlasTile;

/**
 * A sprite atlas (glyphs, SVG icons, images).
 */
interface PlatformAtlas {

    /**
     * Returns the tile of `key`, calling `build` to create its content when
     * it is missing. `build` may return null (nothing to insert): the result
     * is then null. The builder must not re-enter the same atlas.
     */
    function getOrInsertWith(key:AtlasKey, build:() -> Null<AtlasTileSource>):Null<AtlasTile>;

    /**
     * Allocation free lookup of a glyph tile (Haxe addition, used on every
     * painted glyph before falling back to `getOrInsertWith`).
     */
    function getGlyph(params:RenderGlyphParams):Null<AtlasTile>;

    function remove(key:AtlasKey):Void;

    function contains(key:AtlasKey):Bool;

}

/**
 * Stores atlas tiles in textures (`AtlasState` backends).
 */
interface AtlasBackend {

    function insert(kind:AtlasTextureKind, width:Int, height:Int, bytes:haxe.io.Bytes):AtlasTile;

    /**
     * Returns a tile covering a whole texture (`width` x `height` pixels),
     * without copying it (Ceramic addition, for images backed by a texture).
     */
    function insertTexture(kind:AtlasTextureKind, width:Int, height:Int, texture:ceramic.Texture):AtlasTile;

    function remove(tile:AtlasTile):Void;

}
