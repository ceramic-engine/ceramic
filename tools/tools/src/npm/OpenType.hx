package npm;

@:jsRequire('opentype.js')
extern class OpenType {

    static function load(url:String, callback:Dynamic->OpenTypeFont->Void):Void;

    static function parse(buffer:js.node.Buffer):OpenTypeFont;

    static function loadSync(path:String):OpenTypeFont;



} //OpenType

@:jsRequire('opentype.js', 'Font')
extern class OpenTypeFont {

    /** An indexed list of Glyph object */
    var glyphs:Array<OpenTypeGlyph>;

    /** X/Y coordinates in fonts are stored as integers. This value determines the size of the grid. Common values are 2048 and 4096. */
    var unitsPerEm:Float;

    /** Distance from baseline of highest ascender. In font units, not pixels */
    var ascender:Float;

    /** Distance from baseline of highest descender. In font units, not pixels */
    var descender:Float;

    /** Convert the string to a list of glyph objects. Note that there is no strict 1-to-1 correspondence between the string and glyph list due to possible substitutions such as ligatures. The list of returned glyphs can be larger or smaller than the length of the given string. */
    function charToGlyph(char:String):OpenTypeGlyph;

    /** Retrieve the value of the kerning pair between the left glyph and the right glyph. If no kerning pair is found, return 0. The kerning value gets added to the advance width when calculating the spacing between glyphs. */
    function getKerningValue(leftGlyph:OpenTypeGlyph, rightGlyph:OpenTypeGlyph):Float;

    /** Returns the advance width of a text. This is something different than Path.getBoundingBox() as for example a suffixed whitespace increases the advancewidth but not the bounding box or an overhanging letter like a calligraphic 'f' might have a quite larger bounding box than its advance width. */
    function getAdvanceWidth(text:String, fontSize:Int, ?options:{?kerning:Bool, ?features:Dynamic, ?hinting:Bool}):Float;

} //OpenTypeFont

@:jsRequire('opentype.js', 'Glyph')
extern class OpenTypeGlyph {

    /** A reference to the `Font` object. */
    var font:OpenTypeFont;

    /** The glyph name (e.g. "Aring", "five") */
    var name:String;

    /** The primary unicode value of this glyph (can be null). */
    var unicode:String;

    /** The list of unicode values for this glyph (most of the time this will be 1, can also be empty). */
    var unicodes:Array<String>;

    /** The index number of the glyph. */
    var index:Int;

    /** The width to advance the pen when drawing this glyph. */
    var advanceWidth:Float;

    /** The bounding box of the glyph: xMin */
    var xMin:Float;

    /** The bounding box of the glyph: yMin */
    var yMin:Float;

    /** The bounding box of the glyph: xMax */
    var xMax:Float;

    /** The bounding box of the glyph: yMax */
    var yMax:Float;

    /** Calculate the minimum bounding box for the unscaled path of the given glyph. Returns a `BoundingBox` object that contains x1/y1/x2/y2. If the glyph has no points (e.g. a space character), all coordinates will be zero. */
    function getBoundingBox():OpenTypeBoundingBox;

    /** Get a scaled glyph Path object we can draw on a drawing context. */
    function getPath(x:Float, y:Float, fontSize:Int):OpenTypePath;

} //OpenTypeGlyph

@:jsRequire('opentype.js', 'BoundingBox')
extern class OpenTypeBoundingBox {

    var x1:Float;

    var y1:Float;

    var x2:Float;

    var y2:Float;

} //OpenTypeBoundingBox

extern class OpenTypePath {

    var commands:Array<Dynamic>;

    var fill:String;

    var stroke:String;

    var strokeWidth:Float;

    /** Draw the path on the given 2D context. This uses the fill, stroke and strokeWidth properties of the Path object. */
    function draw(ctx:Dynamic):Void;

} //OpenTypePath
