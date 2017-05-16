package ceramic.internal;

// Substantial portion taken from luxe (https://github.com/underscorediscovery/luxe/blob/4c891772f54b4769c72515146bedde9206a7b986/luxe/importers/bitmapfont/BitmapFontData.hx)

typedef Character = {
    var id: Int;
    var x: Float;
    var y: Float;
    var width: Float;
    var height: Float;
    var xOffset: Float;
    var yOffset: Float;
    var xAdvance: Float;
    var page: Int;
}

typedef BitmapFontData = {
    var face: String;
    var pointSize: Float;
    var baseSize: Float;
    var chars: Map<Int, Character>;
    var charCount: Int;
    var pages: Array<{ id : Int, file : String }>;
    var lineHeight: Float;
    var kernings: Map< Int, Map<Int, Float> >;
}
