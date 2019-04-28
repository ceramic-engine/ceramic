package ceramic;

class TilesetImage {

    /** The texture used for this image, if loaded and ready to display */
    public var texture:Texture = null;

    /** The image width in points */
    public var width:Int = -1;

    /** The image height in points */
    public var height:Int = -1;

    /** The reference to the tileset image file, if any */
    public var source:String = null;

    public function new() {

    } //new

} //TilesetImage
