package ceramic;

@:structInit
class BitmapFontData {
    public var face: String;
    public var pointSize: Float;
    public var baseSize: Float;
    public var chars: Map<Int, BitmapFontCharacter>;
    public var charCount: Int;
    public var pages: Array<{ id : Int, file : String }>;
    public var lineHeight: Float;
    public var kernings: Map< Int, Map<Int, Float> >;
}
