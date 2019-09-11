package tools;

/** Current tools execution context */
typedef Context = {

    /** The current project we are working on. */
    var project:Project;

    /** If `true`, the output will get formatted with ANSI colors. */
    var colors:Bool;

    /** If `true`, debug is enabled. */
    var debug:Bool;
    
    /** The defines computed by project and args. */
    var defines:Map<String,String>;

    /** Ceramic git deps absolute path. */
    var ceramicGitDepsPath:String;

    /** Ceramic tools absolute path. */
    var ceramicToolsPath:String;

    /** Ceramic runtime absolute path. */
    var ceramicRuntimePath:String;

    /** Ceramic runner absolute path. */
    var ceramicRunnerPath:String;

    /** Current user's home directory */
    var homeDir:String;

    /** Tells whether current `.ceramic` path is local (current project's cwd) or shared (in user's home directory). */
    var isLocalDotCeramic:Bool;

    /** Tells whether this ceramic is the one executed from whithin and electron app (Ceramic Editor). */
    var isEmbeddedInElectron:Bool;
    
    /** Absolute path to `.ceramic` directory. */
    var dotCeramicPath:String;
    
    /** Default plugins path (embedded with ceramic itself). */
    var defaultPluginsPath:String;
    
    /** Whether we are running a variant configuration or not. */
    var variant:String;

    /** Whether this command is triggered by `Visual Studio Code` or not. */
    var vscode:Bool;

    /** Set to `true` to mute logging. */
    var muted:Bool;

    /** Loaded plugins. */
    var plugins:Map<String,tools.spec.ToolsPlugin>;

    /** Plugins that haven't be built yet */
    var unbuiltPlugins:Map<String,{ path: String }>;

    /** Current related backend (if any). */
    var backend:tools.spec.BackendTools;

    /** Current project's working directory. */
    var cwd:String;

    /** Current execution's args. */
    var args:Array<String>;

    /** Loaded tasks */
    var tasks:Map<String,tools.Task>;

    /** Current plugin (if any) */
    var plugin:tools.spec.ToolsPlugin;

    /** Root triggered task */
    var rootTask:tools.Task;

    /** Current ceramic version */
    var ceramicVersion:String;

    /** A flag to tell whether one asset or more have changed since last asset pass */
    var assetsChanged:Bool;

    /** A flag to tell whether one icon or more have changed since last icon pass */
    var iconsChanged:Bool;

} //Context
