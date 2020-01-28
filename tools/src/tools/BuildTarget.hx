package tools;

enum BuildConfig {
    Build(displayName:String);
    Run(displayName:String);
    Clean(displayName:String);
}

@:structInit
@:using(tools.BuildTargetExtensions)
class BuildTarget {

    public var name:String;

    public var displayName:String;

    public var configs:Array<BuildConfig>;

}
