package tools;

import npm.Fiber;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.Json;
import tools.Helpers;
import tools.Helpers.*;

using StringTools;

class Tools {

/// Global

    static function main():Void {

        // Expose new Tools(cwd, args).run()
        var module:Dynamic = js.Node.module;
        module.exports = runInFiber;

    } //main

    static function runInFiber(cwd:String, args:Array<String>, ceramicPath:String) {

        // Wrap execution inside a fiber to allow calling
        // Async code pseudo-synchronously
        Fiber.fiber(function() {
            run(cwd, args, ceramicPath);
        }).run();

    } //runInFiber

/// Run

    static function run(cwd:String, args:Array<String>, ceramicPath:String) {

        // Initialize context with default values
        Helpers.context = {
            colors: true,
            debug: (args.indexOf('--debug') != -1),
            defines: new Map(),
            ceramicToolsPath: ceramicPath,
            ceramicRuntimePath: Path.normalize(Path.join([ceramicPath, '../runtime'])),
            ceramicRunnerPath: Path.normalize(Path.join([ceramicPath, '../runner'])),
            ceramicGitDepsPath: Path.normalize(Path.join([ceramicPath, '../git'])),
            defaultPluginsPath: Path.normalize(Path.join([ceramicPath, '../plugins'])),
            homeDir: '' + js.Node.require('os').homedir(),
            isLocalDotCeramic: false,
            dotCeramicPath: '' + Path.join([js.Node.require('os').homedir(), '.ceramic']),
            variant: 'standard',
            vscode: false,
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
            ceramicVersion: null
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
        context.tasks.set('setup', new tools.tasks.Setup());
        context.tasks.set('link', new tools.tasks.Link());
        context.tasks.set('unlink', new tools.tasks.Unlink());
        context.tasks.set('path', new tools.tasks.Path());
        context.tasks.set('info', new tools.tasks.Info());
        context.tasks.set('libs', new tools.tasks.Libs());

        context.tasks.set('plugin hxml', new tools.tasks.plugin.PluginHxml());
        context.tasks.set('plugin build', new tools.tasks.plugin.BuildPlugin());
        context.tasks.set('plugin list', new tools.tasks.plugin.ListPlugins());

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
            args.splice(index, 2);
        }

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

        // VSCode
        index = args.indexOf('--vscode-editor');
        if (index != -1) {
            context.vscode = true;
            args.splice(index, 1);
        }

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
        
    } //run

} //Tools
