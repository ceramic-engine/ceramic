package tools;

enum BuildConfig {
    Build(displayName:String, description:String);
    Run(displayName:String, description:String);
}

@:structInit
class BuildTarget {

    public var name:String;

    public var displayName:String;

    public var configs:Array<BuildConfig>;

} //BuildConfig
