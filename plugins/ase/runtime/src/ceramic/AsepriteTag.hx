package ceramic;

// Mostly taken from: https://github.com/AustinEast/heaps-aseprite/blob/3d9a251265ec41bb64e494ef9ef52041ad218974/src/aseprite/Tag.hx
// Credits to its original authors

@:structInit
class AsepriteTag {
    public var name(default, null):String;
    public var fromFrame(default, null):Int;
    public var toFrame(default, null):Int;
    public var direction(default, null):Int;

    public static function fromChunk(chunk:ase.chunks.TagsChunk.Tag):AsepriteTag {
        return {
            name: chunk.tagName,
            fromFrame: chunk.fromFrame,
            toFrame: chunk.toFrame,
            direction: chunk.animDirection
        };
    }
}
