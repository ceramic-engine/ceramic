package tools;

import haxe.Json;
import haxe.io.Path;
import npm.Fiber;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Helpers;

using StringTools;

class Tools {

/// Global

    static function main():Void {

        // Expose new Tools(cwd, args).run()
        var module:Dynamic = js.Node.module;
        module.exports = runInFiber;

    }

    static function runInFiber(cwd:String, args:Array<String>, ceramicPath:String) {

        // Wrap execution inside a fiber to allow calling
        // Async code pseudo-synchronously
        Fiber.fiber(function() {
            run(cwd, args, ceramicPath);
        }).run();

    }

/// Run

    static function run(cwd:String, args:Array<String>, ceramicPath:String) {

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
            homeDir: '' + js.Node.require('os').homedir(),
            isLocalDotCeramic: false,
            dotCeramicPath: '' + Path.join([js.Node.require('os').homedir(), '.ceramic']),
            variant: 'standard',
            vscode: false,
            vscodeUriScheme: 'vscode',
            muted: false,
            plugins: new Map(),
            unbuiltPlugins: new Map(),
            backend: null,
            cwd: cwd,
            args: args,
            tasks: new Map(),
            plugin: null,
            rootTask: null,
            isEmbeddedInElectron: false,
            ceramicVersion: null,
            assetsChanged: false,
            iconsChanged: false,
            printSplitLines: (args.indexOf('--print-split-lines') != -1),
            haxePaths: [],
            haxeLibraries: []
        };

        // Check if we are embedded in electron
        var electronPackageFile = Path.join([context.ceramicToolsPath, '../../package.json']);
        if (FileSystem.exists(electronPackageFile)) {
            if (Json.parse(File.getContent(electronPackageFile)).name == 'ceramic') {
                context.isEmbeddedInElectron = true;
                context.ceramicRuntimePath = Path.normalize(Path.join([context.ceramicToolsPath, '../../vendor/ceramic-runtime']));
                context.defaultPluginsPath = Path.normalize(Path.join([context.ceramicToolsPath, '../../vendor/ceramic-plugins']));
            }
        }

        // Compute ceramic version
        var version = js.Node.require(Path.join([context.ceramicToolsPath, 'package.json'])).version;
        var versionPath = Path.join([js.Node.__dirname, 'version']);
        if (FileSystem.exists(versionPath)) {
            version = File.getContent(versionPath);
        }
        if (commandExists('git')) {
            var hash:String = command('git', ['rev-parse', '--short', 'HEAD'], { cwd: context.ceramicToolsPath, mute: true }).stdout.trim();
            if (hash != null && hash != '') {
                version += '-$hash';
            }
        }
        context.ceramicVersion = version;

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

        context.tasks.set('version', new tools.tasks.Version());
        context.tasks.set('help', new tools.tasks.Help());
        context.tasks.set('server', new tools.tasks.Server());
        context.tasks.set('query', new tools.tasks.Query());

        context.tasks.set('init', new tools.tasks.Init());
        context.tasks.set('vscode', new tools.tasks.Vscode());
        context.tasks.set('link', new tools.tasks.Link());
        context.tasks.set('unlink', new tools.tasks.Unlink());
        context.tasks.set('path', new tools.tasks.Path());
        context.tasks.set('info', new tools.tasks.Info());
        context.tasks.set('libs', new tools.tasks.Libs());
        context.tasks.set('hxml', new tools.tasks.Hxml());
        //context.tasks.set('module', new tools.tasks.Module());

        context.tasks.set('font', new tools.tasks.Font());

        context.tasks.set('haxe server', new tools.tasks.HaxeServer());

        context.tasks.set('plugin hxml', new tools.tasks.plugin.PluginHxml());
        context.tasks.set('plugin build', new tools.tasks.plugin.BuildPlugin());
        context.tasks.set('plugin list', new tools.tasks.plugin.ListPlugins());

        context.tasks.set('ide info', new tools.tasks.IdeInfo());

        context.tasks.set('images export', new tools.tasks.images.ExportImages());

        //#end

        // Init plugins
        //
        if (context.plugins != null) {
            for (key in context.plugins.keys()) {
                var plugin = context.plugins.get(key);

                var prevPlugin = context.plugin;
                context.plugin = plugin;

                plugin.init(context);

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
            if (args.length >= 3 && context.tasks.exists(taskName + ' ' + args[1] + ' ' + args[2])) {
                taskName = taskName + ' ' + args[1] + ' ' + args[2];
            }
            else if (args.length >= 2 && context.tasks.exists(taskName + ' ' + args[1])) {
                taskName = taskName + ' ' + args[1];
            }

            if (context.tasks.exists(taskName)) {

                // Get task
                var task = context.tasks.get(taskName);

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
                js.Node.process.exit(0);

            } else {
                fail('Unknown command: $taskName');
            }
        }

    }

}
