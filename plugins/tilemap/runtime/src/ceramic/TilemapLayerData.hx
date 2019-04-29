package ceramic;

class TilemapLayerData extends Entity {

    /** The name of the layer */
    public var name:String = null;

    /** The x position of the layer in tiles */
    public var x:Int = 0;

    /** The y position of the layer in tiles */
    public var y:Int = 0;

    /** The width of the layer in tiles */
    public var width:Int = 0;

    /** The height of the layer in tiles */
    public var height:Int = 0;

    /** The opacity of the layer */
    public var opacity:Float = 1;

    /** Whether this layer is visible or not */
    public var visible:Bool = true;

    /** X offset for this layer in points. */
    public var offsetX:Int = 0;

    /** Y offset for this layer in points. */
    public var offsetY:Int = 0;

    /** Tiles */
    public var tiles:Array<TilemapTile> = null;

    public function new() {

    } //new

} //TilemapLayerData
