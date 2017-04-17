package tools.spec;

interface BackendTools {

    var name(default,null):String;

    /** Init backend. This hook allows backend to add
        custom tasks and perform any specific setup. */
    function init(tools:tools.Tools):Void;

    /** Get available build configurations for this backend. */
    function getBuildTargets():Array<tools.BuildTarget>;

    /** Run setup for the given backend target */
    function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, fromBuild:Bool = false):Void;

    /** Get hxml data for the given target */
    function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget):String;

    /** Get hxml working directory used internally by the backend.
        This is needed by tools to then convert hxml data with
        absolute paths, or just change the relative directories. */
    function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget):String;

    /** Run build for to the given backend target */
    function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, configIndex:Int = 0):Void;

    /** Get filtered/transformed assets for the given backend and build target */
    function getAssets(assets:Array<tools.Asset>, target:tools.BuildTarget):Array<tools.Asset>;

} //Tools
