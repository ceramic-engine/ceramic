package ceramic;

import ase.chunks.CelChunk;
import ase.chunks.LayerChunk;

@:structInit
class AsepriteFrameLayer {
    public var layer:LayerChunk;
    public var celChunk:CelChunk = null;
    public var pixels:UInt8Array = null;
}