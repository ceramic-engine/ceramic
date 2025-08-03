package ceramic;

import ase.chunks.PaletteChunk;
import haxe.io.Bytes;

/**
 * Represents a color palette from an Aseprite file.
 * 
 * Aseprite supports indexed color mode where each pixel references
 * a color from a palette. This class stores the palette entries
 * and provides utilities for color lookup.
 * 
 * The palette is stored as a map from color indices to ARGB color values,
 * allowing efficient lookup during rendering of indexed color sprites.
 * 
 * @see AsepriteData for the parent data structure
 * @see PaletteChunk for the raw palette data from the file
 */
@:structInit
class AsepritePalette {
    /**
     * Map from palette index to ARGB color value.
     * Keys are palette indices (0-255 for 8-bit indexed color).
     * Values are 32-bit ARGB colors stored as integers.
     */
    public var entries(default, null):IntIntMap;
    
    /**
     * The raw palette chunk data from the Aseprite file.
     * Contains additional metadata like color names if present.
     */
    public var chunk(default, null):PaletteChunk;

    /**
     * Creates an AsepritePalette from raw palette chunk data.
     * 
     * Converts the palette entries from the file format into an efficient
     * integer map for color lookups. Colors are packed as 32-bit ARGB values.
     * 
     * @param chunk The palette chunk from the Aseprite file
     * @return A new AsepritePalette instance with indexed colors
     */
    public static function fromChunk(chunk:PaletteChunk):AsepritePalette {
        var entries = new IntIntMap();
        var color:Bytes = Bytes.alloc(4);
        for (index in chunk.entries.keys()) {
          var entry = chunk.entries[index];
          color.set(0, entry.red);
          color.set(1, entry.green);
          color.set(2, entry.blue);
          color.set(3, entry.alpha);
          entries.set(index, color.getInt32(0));
        }

        return {
            entries: entries,
            chunk: chunk
        };
    }
}