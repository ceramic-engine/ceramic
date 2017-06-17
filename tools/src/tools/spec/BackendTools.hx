package tools.spec;

interface BackendTools {

    var name(default,null):String;

    /** Init backend. This hook allows backend to add
        custom tasks and perform any specific setup. */
    function init(tools:tools.Tools):Void;

    /** Get available build configurations for this backend. */
    function getBuildTargets():Array<tools.BuildTarget>;

    /** Run setup for the given backend target */
    function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, continueOnFail:Bool = false):Void;

    /** Get hxml data for the given target */
    function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String;

    /** Get hxml working directory used internally by the backend.
        This is needed by tools to then convert hxml data with
        absolute paths, or just change the relative directories. */
    function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String;

    /** Get target define specific to this backend and target.*/
    function getTargetDefines(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):Map<String,String>;

    /** Run build for to the given backend target */
    function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, configIndex:Int = 0):Void;

    /** Run backend framework (dependency) update/install **/
    function runUpdate(cwd:String, args:Array<String>):Void;

    /** Transform and get assets for the given backend and build target */
    function transformAssets(cwd:String, assets:Array<tools.Asset>, target:tools.BuildTarget, variant:String, listOnly:Bool):Array<tools.Asset>;

    /** Transform icons */
    function transformIcons(cwd:String, appIcon:String, target:tools.BuildTarget, variant:String):Void;

} //Tools
