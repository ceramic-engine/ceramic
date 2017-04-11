package tools.spec;

interface BackendTools {

    /** Get available build configurations for this backend. */
    function getBuildTargets():Array<tools.BuildTarget>;

    /** Get the task to setup the given backend target */
    function getSetupTask(target:tools.BuildTarget):tools.Task;

    /** Get hxml data for the given target */
    function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget):String;

    /** Get hxml working directory used internally by the backend.
        This is needed by tools to then convert hxml data with
        absolute paths, or just change the relative directories. */
    function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget):String;

    /** Get the build task associated to the given target */
    function getBuildTask(target:tools.BuildTarget, configIndex:Int = 0):tools.Task;

    /** Get filtered/transformed assets for the given backend and build target */
    function getAssets(assets:Array<tools.Asset>, target:tools.BuildTarget):Array<tools.Asset>;

} //Tools
