package ceramic;

@:structInit
class BitmapFontData {
    public var face:String;
    public var pointSize:Float;
    public var baseSize:Float;
    public var chars:IntMap<BitmapFontCharacter>;
    public var charCount:Int;
    public var distanceField:Null<BitmapFontDistanceFieldData>;
    public var pages:Array<BitmapFontDataPage>;
    public var lineHeight:Float;
    public var kernings:IntMap<IntFloatMap>;
}

@:structInit
class BitmapFontDataPage {
    public var id:Int;
    public var file:String;
}
