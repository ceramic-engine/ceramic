package tools;

enum BuildConfig {
    Build(displayName:String, ?extraArgs:Array<String>);
    Run(displayName:String, ?extraArgs:Array<String>);
    Clean(displayName:String, ?extraArgs:Array<String>);
}

@:structInit
@:using(tools.BuildTargetExtensions)
class BuildTarget {

    public var name:String;

    public var displayName:String;

    public var configs:Array<BuildConfig>;

}
