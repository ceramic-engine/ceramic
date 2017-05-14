package tools;

@:structInit
class Asset {

    /** Asset name/relative path */
    public var name:String;

    /** Asset full source path */
    public var srcPath:String;

    public function new(name:String, srcPath:String) {

        this.name = name;
        this.srcPath = srcPath;

    } //new

} //Asset
