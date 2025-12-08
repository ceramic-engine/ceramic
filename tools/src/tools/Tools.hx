package tools;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Helpers;
import tools.macros.ToolsMacros;

using StringTools;

class Tools {

/// Run

    static function run(cwd:String, args:Array<String>, ceramicPath:String) {

        // Initialize internal background runner
        Runner.init();

        // Check windows args paths
        fixWindowsArgsPaths(args);

        // Initialize context with default values
        Helpers.context = {
            project: null,
            colors: true,
            debug: (args.indexOf('--debug') != -1),
            defines: new Map(),
            ceramicToolsPath: ceramicPath,
            ceramicRootPath: Path.normalize(Path.join([ceramicPath, '..'])),
            ceramicRuntimePath: Path.normalize(Path.join([ceramicPath, '../runtime'])),
            ceramicRunnerPath: Path.normalize(Path.join([ceramicPath, '../runner'])),
            ceramicGitDepsPath: Path.normalize(Path.join([ceramicPath, '../git'])),
            defaultPluginsPath: Path.normalize(Path.join([ceramicPath, '../plugins'])),
            projectPluginsPath: Path.normalize(Path.join([cwd, 'plugins'])),
            homeDir: '' + homedir(),
            isLocalDotCeramic: false,
            dotCeramicPath: '' + Path.join([homedir(), '.ceramic']),
            variant: 'standard',
            vscode: false,
            vscodeUriScheme: 'vscode',
            muted: false,
            plugins: new Map(),
            backend: null,
            cwd: cwd,
            args: args,
            tasks: [],
            plugin: null,
            rootTask: null,
            ceramicVersion: null,
            assetsChanged: false,
            assetsTransformers: [],
            tempDirs: [],
            iconsChanged: false,
            printSplitLines: (args.indexOf('--print-split-lines') != -1),
            haxePaths: [],
            haxeLibraries: [],
            shouldExit: false
        };

        // Set version
        context.ceramicVersion = ceramicVersion();

        // Compute .ceramic path (global or local)
        var localDotCeramic = Path.join([context.cwd, '.ceramic']);
        if (FileSystem.exists(localDotCeramic) && FileSystem.isDirectory(localDotCeramic)) {
            context.dotCeramicPath = localDotCeramic;
            context.isLocalDotCeramic = true;
        }
        if (!FileSystem.exists(context.dotCeramicPath)) {
            FileSystem.createDirectory(context.dotCeramicPath);
        }

        // Compute plugins
        computePlugins();

        context.addTask('version', new tools.tasks.Version());
        context.addTask('help', new tools.tasks.Help());

        context.addTask('haxe', new tools.tasks.Haxe());
        context.addTask('haxelib', new tools.tasks.Haxelib());
        context.addTask('neko', new tools.tasks.Neko());

        context.addTask('init', new tools.tasks.Init());
        context.addTask('vscode', new tools.tasks.Vscode());
        context.addTask('link', new tools.tasks.Link());
        context.addTask('unlink', new tools.tasks.Unlink());
        context.addTask('path', new tools.tasks.Path());
        context.addTask('info', new tools.tasks.Info());
        context.addTask('libs', new tools.tasks.Libs());
        context.addTask('hxml', new tools.tasks.Hxml());
        context.addTask('assets', new tools.tasks.Assets());

        context.addTask('haxe server', new tools.tasks.HaxeServer());

        context.addTask('tmp dir', new tools.tasks.TmpDir());

        context.addTask('plugin hxml', new tools.tasks.plugin.PluginHxml());
        context.addTask('plugin list', new tools.tasks.plugin.ListPlugins());

        context.addTask('ide info', new tools.tasks.IdeInfo());

        context.addTask('images export', new tools.tasks.images.ExportImages());

        context.addTask('sdl', new tools.tasks.SDL());
        context.addTask('angle', new tools.tasks.Angle());

        //#end

        // Init plugins
        //
        if (context.plugins != null) {
            for (key in context.plugins.keys()) {
                var plugin = context.plugins.get(key);

                var prevPlugin = context.plugin;
                context.plugin = plugin;

                if (plugin.instance != null) {
                    plugin.instance.init(context);
                }

                context.plugin = prevPlugin;
            }
        }

        // Load args
        //

        // Colors
        var index:Int = args.indexOf('--no-colors');
        if (index != -1) {
            context.colors = false;
            args.splice(index, 1);
        }

        // Custom CWD
        index = args.indexOf('--cwd');
        if (index != -1) {
            if (index + 1 >= args.length) {
                fail('A value is required after --cwd argument.');
            }
            var newCwd = args[index + 1];
            if (!Path.isAbsolute(newCwd)) {
                newCwd = Path.normalize(Path.join([cwd, newCwd]));
            }
            if (!FileSystem.exists(newCwd)) {
                fail('Provided cwd path doesn\'t exist.');
            }
            if (!FileSystem.isDirectory(newCwd)) {
                fail('Provided cwd path exists but is not a directory.');
            }
            cwd = newCwd;
            context.cwd = cwd;
            args.splice(index, 2);
        }

        // Available libraries
        context.haxeLibraries = resolveAvailableHaxeLibraries(cwd);

        // Variant
        index = args.indexOf('--variant');
        if (index != -1) {
            if (index + 1 >= args.length) {
                fail('A value is required after --variant argument.');
            }
            var variant = args[index + 1];
            context.variant = variant;
            context.defines.set('variant', variant);
            if (!context.defines.exists(variant)) {
                context.defines.set(variant, '');
            }
            args.splice(index, 2);
        }

        // Debug
        if (args.indexOf('--debug') != -1) {
            context.debug = true;
            if (!context.defines.exists('debug')) {
                context.defines.set('debug', '');
            }
        }

        // Custom defines
        index = 0;
        while (index < args.length) {
            var arg = args[index];
            if (arg == '-D') {
                index++;
                var name = args[index];
                var equalIndex = name.indexOf('=');
                if (equalIndex == -1) {
                    context.defines.set(name, '');
                }
                else {
                    context.defines.set(name.substr(0, equalIndex), name.substr(equalIndex + 1));
                }
            }
            index++;
        }

        // VSCode
        index = args.indexOf('--vscode-editor');
        if (index != -1) {
            context.vscode = true;
            args.splice(index, 1);
        }

        // VSCode (URI Scheme)
        index = args.indexOf('--vscode-uri-scheme');
        if (index != -1) {
            if (index + 1 >= args.length) {
                fail('A value is required after --vscode-uri-scheme argument.');
            }
            context.vscodeUriScheme = args[index + 1];
            args.splice(index, 2);
        }
        else {
            context.vscodeUriScheme = 'vscode';
        }

        // Load project
        Helpers.context.project = loadProject(cwd, args);

        context.args = args;

        // Run task from args
        //
        if (args.length < 1) {
            fail('Invalid arguments.');
        }
        else {
            var taskName = args[0];
            if (args.length >= 3 && context.hasTask(taskName + ' ' + args[1] + ' ' + args[2])) {
                taskName = taskName + ' ' + args[1] + ' ' + args[2];
            }
            else if (args.length >= 2 && context.hasTask(taskName + ' ' + args[1])) {
                taskName = taskName + ' ' + args[1];
            }

            if (context.hasTask(taskName)) {

                // Get task
                var task = context.task(taskName);

                // Set correct backend
                context.backend = @:privateAccess task.backend;

                // Set correct plugin
                context.plugin = @:privateAccess task.plugin;

                // Extract defines (if any)
                extractDefines(cwd, args);

                // Extract haxe paths (if any)
                extractHaxePaths(cwd, args);

                // Set correct task
                context.rootTask = task;

                // Run task
                task.run(cwd, args);

                // Ceramic end
                Sys.exit(0);

            } else {
                fail('Unknown command: $taskName');
            }
        }

    }

    public static function ceramicVersion():String {
        #if !cppia
        static final fullVersion = '${ToolsMacros.ceramicVersion()}-${ToolsMacros.gitCommitShortHash()}';
        return fullVersion;
        #else
        return null;
        #end
    }

}
