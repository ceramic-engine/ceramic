// Ported from gpui-pre 0.3.10: src/platform.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.AtlasTile;
import gpui.PlatformAtlas;

/**
 * Tiles by key over a backend that owns the textures: the platform
 * independent part of GPUI's atlases.
 */
class AtlasState<Backend:AtlasBackend> {

    final tilesByKey:Map<String, AtlasTile> = new Map();

    final glyphTiles:GlyphCache<AtlasTile> = new GlyphCache();

    /**
     * The SVG tiles of `tilesByKey` by path, then by size: an SVG painted
     * every frame finds its tile without building its key string. Cleared
     * whenever tiles are forgotten.
     */
    final svgTiles:Map<String, Array<SvgTileEntry>> = new Map();

    public final backend:Backend;

    public function new(backend:Backend) {
        this.backend = backend;
    }

    public function contains(key:AtlasKey):Bool {
        return tilesByKey.exists(key.keyString());
    }

    public function clear(?resetBackend:(Backend) -> Void):Void {
        tilesByKey.clear();
        glyphTiles.clear();
        svgTiles.clear();
        if (resetBackend != null)
            resetBackend(backend);
    }

    public inline function getGlyph(params:RenderGlyphParams):Null<AtlasTile> {
        return glyphTiles.get(params);
    }

    public function getOrInsertWith(key:AtlasKey, build:() -> Null<AtlasTileSource>):Null<AtlasTile> {
        switch key {
            case Svg(path, width, height):
                final entries = svgTiles.get(path);
                if (entries != null) {
                    for (i in 0...entries.length) {
                        final entry = entries[i];
                        if (entry.width == width && entry.height == height)
                            return entry.tile;
                    }
                }
            case _:
        }
        final keyString = key.keyString();
        final existing = tilesByKey.get(keyString);
        if (existing != null)
            return existing;
        final source = build();
        if (source == null)
            return null;
        final tile = if (source.texture != null) {
            backend.insertTexture(key.textureKind(), source.width, source.height, source.texture);
        }
        else if (!source.straightAlpha && source.bytes != null && key.textureKind() == Polychrome) {
            // Polychrome tiles are straight alpha BGRA, like every polychrome
            // tile of GPUI (decoded images, SVG images, emoji): premultiplied
            // sources are converted
            backend.insert(Polychrome, source.width, source.height, unpremultiplied(source.bytes, source.width * source.height));
        }
        else {
            backend.insert(key.textureKind(), source.width, source.height, source.bytes);
        }
        tilesByKey.set(keyString, tile);
        switch key {
            case Glyph(params): glyphTiles.set(params, tile);
            case Svg(path, width, height):
                var entries = svgTiles.get(path);
                if (entries == null) {
                    entries = [];
                    svgTiles.set(path, entries);
                }
                entries.push(new SvgTileEntry(width, height, tile));
            case _:
        }
        return tile;
    }

    /** A straight alpha copy of `pixels` premultiplied 4 byte pixels */
    static function unpremultiplied(bytes:haxe.io.Bytes, pixels:Int):haxe.io.Bytes {
        final result = haxe.io.Bytes.alloc(pixels * 4);
        var i = 0;
        for (_ in 0...pixels) {
            final a = bytes.get(i + 3);
            if (a == 255) {
                result.set(i, bytes.get(i));
                result.set(i + 1, bytes.get(i + 1));
                result.set(i + 2, bytes.get(i + 2));
            }
            else if (a != 0) {
                result.set(i, Std.int(Math.min(255, (bytes.get(i) * 255 + (a >> 1)) / a)));
                result.set(i + 1, Std.int(Math.min(255, (bytes.get(i + 1) * 255 + (a >> 1)) / a)));
                result.set(i + 2, Std.int(Math.min(255, (bytes.get(i + 2) * 255 + (a >> 1)) / a)));
            }
            result.set(i + 3, a);
            i += 4;
        }
        return result;
    }

    /**
     * Forgets every tile of the texture `textureIndex` (Ceramic addition,
     * for atlases that reuse a whole page, see `CeramicAtlas`). The backend
     * is not told: it is the one emptying the page.
     */
    public function forgetTexture(textureIndex:Int):Void {
        svgTiles.clear();
        var keys:Null<Array<String>> = null;
        for (key => tile in tilesByKey) {
            if (tile.textureId.index == textureIndex) {
                if (keys == null) keys = [];
                keys.push(key);
            }
        }
        if (keys != null) {
            for (key in keys) {
                tilesByKey.remove(key);
            }
        }
    }

    public function remove(key:AtlasKey):Void {
        final keyString = key.keyString();
        final tile = tilesByKey.get(keyString);
        if (tile != null) {
            tilesByKey.remove(keyString);
            switch key {
                case Glyph(params): glyphTiles.remove(params);
                case Svg(_, _, _): svgTiles.clear();
                case _:
            }
            backend.remove(tile);
        }
    }

}

/** A tile of `AtlasState.svgTiles` */
private class SvgTileEntry {

    public final width:Int;

    public final height:Int;

    public final tile:AtlasTile;

    public function new(width:Int, height:Int, tile:AtlasTile) {
        this.width = width;
        this.height = height;
        this.tile = tile;
    }

}
