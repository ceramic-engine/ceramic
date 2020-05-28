package ceramic;

import tracker.Model;

class TilemapLayerData extends Model {

    /** The name of the layer */
    @serialize public var name:String = null;

    /** The x position of the layer in tiles */
    @serialize public var x:Int = 0;

    /** The y position of the layer in tiles */
    @serialize public var y:Int = 0;

    /** The width of the layer in tiles */
    @serialize public var width:Int = 0;

    /** The height of the layer in tiles */
    @serialize public var height:Int = 0;

    /** The opacity of the layer */
    @serialize public var opacity:Float = 1;

    /** Whether this layer is visible or not */
    @serialize public var visible:Bool = true;

    /** X offset for this layer in points. */
    @serialize public var offsetX:Int = 0;

    /** Y offset for this layer in points. */
    @serialize public var offsetY:Int = 0;

    /** Tiles */
    @serialize public var tiles:Array<TilemapTile> = null;

}
