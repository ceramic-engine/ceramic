// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.AtlasTile;
import gpui.PlatformAtlas;

/**
 * A sprite atlas for windows without a GPU. It hands out uniquely identified
 * tiles without storing any pixels, so glyph, SVG, and image painting can
 * run to completion in tests and headless platforms.
 */
class HeadlessAtlas implements PlatformAtlas {

    public final state:AtlasState<HeadlessAtlasBackend> = new AtlasState(new HeadlessAtlasBackend());

    public function new() {}

    public function getOrInsertWith(key:AtlasKey, build:() -> Null<AtlasTileSource>):Null<AtlasTile> {
        return state.getOrInsertWith(key, build);
    }

    public function getGlyph(params:RenderGlyphParams):Null<AtlasTile> {
        return state.getGlyph(params);
    }

    public function remove(key:AtlasKey):Void {
        state.remove(key);
    }

    public function contains(key:AtlasKey):Bool {
        return state.contains(key);
    }

}

class HeadlessAtlasBackend implements AtlasBackend {

    var nextId:Int = 0;

    public function new() {}

    public function insert(kind:AtlasTextureKind, width:Int, height:Int, bytes:haxe.io.Bytes):AtlasTile {
        nextId += 1;
        final textureId = nextId;
        nextId += 1;
        final tileId = nextId;
        return new AtlasTile(new AtlasTextureId(textureId, kind), tileId, 0, new Bounds(new Point(0, 0), new Size(width, height)));
    }

    public function insertTexture(kind:AtlasTextureKind, width:Int, height:Int, texture:ceramic.Texture):AtlasTile {
        return insert(kind, width, height, null);
    }

    public function remove(tile:AtlasTile):Void {}

}
