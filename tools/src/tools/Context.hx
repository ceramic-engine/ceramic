package tools;

import tools.HaxeLibrary;

/** Current tools execution context */
@:structInit
class Context  {

    /** The current project we are working on. */
    public var project:Project;

    /** If `true`, the output will get formatted with ANSI colors. */
    public var colors:Bool;

    /** If `true`, debug is enabled. */
    public var debug:Bool;

    /** The defines computed by project and args. */
    public var defines:Map<String,String>;

    /** Ceramic root absolute path. */
    public var ceramicRootPath:String;

    /** Ceramic git deps absolute path. */
    public var ceramicGitDepsPath:String;

    /** Ceramic tools absolute path. */
    public var ceramicToolsPath:String;

    /** Ceramic runtime absolute path. */
    public var ceramicRuntimePath:String;

    /** Ceramic runner absolute path. */
    public var ceramicRunnerPath:String;

    /** Current user's home directory */
    public var homeDir:String;

    /** Tells whether current `.ceramic` path is local (current project's cwd) or shared (in user's home directory). */
    public var isLocalDotCeramic:Bool;

    /** Tells whether this ceramic is the one executed from whithin and electron app (Ceramic Editor). */
    public var isEmbeddedInElectron:Bool;

    /** Absolute path to `.ceramic` directory. */
    public var dotCeramicPath:String;

    /** Default plugins path (embedded with ceramic itself). */
    public var defaultPluginsPath:String;

    /** Project's plugins path (specific to the current project) */
    public var projectPluginsPath:String;

    /** Whether we are running a variant configuration or not. */
    public var variant:String;

    /** Whether this command is triggered by `Visual Studio Code` or not. */
    public var vscode:Bool;

    /** The VSCode URI scheme to use (might be different depending on which VSCode variant is calling us). */
    public var vscodeUriScheme:String;

    /** Set to `true` to mute logging. */
    public var muted:Bool;

    /** Loaded plugins. */
    public var plugins:Map<String,tools.spec.ToolsPlugin>;

    /** Current related backend (if any). */
    public var backend:tools.spec.BackendTools;

    /** Current project's working directory. */
    public var cwd:String;

    /** Current execution's args. */
    public var args:Array<String>;

    /** Loaded tasks */
    public var tasks:Array<tools.TaskEntry>;

    /** Current plugin (if any) */
    public var plugin:tools.spec.ToolsPlugin;

    /** Root triggered task */
    public var rootTask:tools.Task;

    /** Current ceramic version */
    public var ceramicVersion:String;

    /** A flag to tell whether one asset or more have changed since last asset pass */
    public var assetsChanged:Bool;

    /** Assets transformers, such as converters to transform TTF/OTF to Bitmap font and so on... */
    public var assetsTransformers:Array<tools.spec.TransformAssets>;

    /** List of temporary directories that have been created and not cleaned up automatically */
    public var tempDirs:Array<String>;

    /** A flag to tell whether one icon or more have changed since last icon pass */
    public var iconsChanged:Bool;

    /** If `true`, data will be printed line by line instead of as a single chunk of data.
        This is sometimes needed to prevent some truncated bug (seen in vscode + spawn) */
    public var printSplitLines:Bool;

    /** List of available haxe libraries in the current project */
    public var haxeLibraries:Array<HaxeLibrary>;

    /** List of paths pointing to haxe files with current build settings */
    public var haxePaths:Array<String>;

    public function addTask(key:String, task:Task):Void {
        tasks.push({
            key: key,
            task: task
        });
    }

    public function hasTask(key:String):Bool {
        for (i in 0...tasks.length) {
            if (tasks[i].key == key) return true;
        }
        return false;
    }

    public function task(key:String):Task {
        for (i in 0...tasks.length) {
            final entry = tasks[i];
            if (entry.key == key) return entry.task;
        }
        return null;
    }

}
