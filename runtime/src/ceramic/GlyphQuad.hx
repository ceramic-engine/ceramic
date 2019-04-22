package ceramic;

class GlyphQuad extends Quad {

    public var char:String = null;

    public var glyph:BitmapFontCharacter = null;

    public var index:Int = -1;

    public var line:Int = -1;

    public var code:Int = -1;

    public var glyphX:Float = -1;

    public var glyphY:Float = -1;

    public var glyphAdvance:Float = -1;

/// Print

    override function toString() {

        return 'GlyphQuad(c=$char,i=$index,l=$line,x=$glyphX,y=$glyphY)';

    } //toString

} //GlyphQuad
