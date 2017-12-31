package ceramic;

@:structInit
class CustomAssetKind {

    public var kind:String;

    public var add:Assets->String->?AssetOptions->Void;

    public var extensions:Array<String>;

    public var dir:Bool;

    public var types:Array<String>;

} //CustomAssetKind
