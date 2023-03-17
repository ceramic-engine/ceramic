package ceramic;

import ase.chunks.PaletteChunk;
import haxe.io.Bytes;

@:structInit
class AsepritePalette {
    public var entries(default, null):IntIntMap;
    public var chunk(default, null):PaletteChunk;

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