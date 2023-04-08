package tools;

import haxe.Json;
import haxe.io.Path;
import js.node.ChildProcess;
import npm.StreamSplitter;
import npm.StripAnsi;
import npm.Yaml;
import sys.FileSystem;
import sys.io.File;
import tools.Project;

using StringTools;
using tools.Colors;

class Helpers {

    public static var context:Context;

    public static function extractDefines(cwd:String, args:Array<String>):Void {

        // Add backend-specific defines
        var target = null;
        if (context.backend != null) {

            var availableTargets = context.backend.getBuildTargets();
            var targetName = getTargetName(args, availableTargets);

            if (targetName != null) {
                // Find target from name
                //
                for (aTarget in availableTargets) {

                    if (aTarget.name == targetName) {
                        target = aTarget;
                        break;
                    }

                }
            }

            context.defines.set('backend', context.backend.name.toLowerCase().replace(' ', '_'));
            context.defines.set(context.backend.name.toLowerCase().replace(' ', '_'), 'backend');
        }

        // Add generic defines
        context.defines.set('ceramic', context.ceramicVersion);
        context.defines.set('assets_path', Path.join([cwd, 'assets']));
        context.defines.set('ceramic_assets_path', Path.join([context.ceramicToolsPath, 'assets']));
        context.defines.set('ceramic_root_path', context.ceramicRootPath);
        context.defines.set('HXCPP_STACK_LINE', '');
        context.defines.set('HXCPP_STACK_TRACE', '');

        if (context.variant != null) {
            context.defines.set('variant', context.variant);
            if (!context.defines.exists(context.variant)) {
                context.defines.set(context.variant, 'variant');
            }
        }

        // Required for crash dumps
        context.defines.set('HXCPP_CHECK_POINTER', '');
        context.defines.set('safeMode', '');

        // To get absolute path in haxe log output
        // Then, we process it to make it more readable, with colors etc...
        context.defines.set('absolute-path', '');

        // Add target defines
        if (target != null && context.backend != null) {
            var extraDefines = context.backend.getTargetDefines(cwd, args, target, context.variant);
            for (key in extraDefines.keys()) {
                if (!context.defines.exists(key)) {
                    context.defines.set(key, extraDefines.get(key));
                }
            }
        }

        // Add extra assets paths (from plugins)
        var project = loadProject(cwd, args);
        var extraAssetsPaths = [];
        if (project != null && project.app != null) {
            var extraAssets:Array<String> = project.app.assets;
            if (extraAssets != null) {
                for (assetPath in extraAssets) {
                    if (extraAssetsPaths.indexOf(assetPath) == -1) {
                        if (!Path.isAbsolute(assetPath)) {
                            assetPath = Path.join([cwd, assetPath]);
                        }
                        extraAssetsPaths.push(assetPath);
                    }
                }
            }
        }
        context.defines.set('ceramic_extra_assets_paths', Json.stringify(Json.stringify(extraAssetsPaths)));

    }

    public static function setVariant(variant:String) {

        var prevVariant = context.variant;

        if (prevVariant != variant) {
            if (context.defines.get(prevVariant) == 'variant') {
                context.defines.remove(prevVariant);
            }
        }

        context.variant = variant;
        context.defines.set('variant', context.variant);
        if (!context.defines.exists(context.variant)) {
            context.defines.set(context.variant, 'variant');
        }

    }

    public static function computePlugins() {

        context.plugins = new Map();
        context.unbuiltPlugins = new Map();

        var plugins:Map<String,{
            name:String, // plugin name
            path:String, // plugin path on disk
            runtime:Dynamic // runtime additional config
        }> = new Map();

        inline function handlePluginProjectPath(pluginsDir:String, pluginProjectPath:String, file:String) {

            if (FileSystem.exists(pluginProjectPath)) {
                // Extract info
                try {
                    var str = File.getContent(pluginProjectPath)
                        .replace('{plugin:cwd}', Path.join([pluginsDir, file]))
                        .replace('{cwd}', context.cwd)
                    ;
                    var info = Yaml.parse(str);
                    if (info != null && info.plugin != null && info.plugin.name != null) {
                        plugins.set((''+info.plugin.name).toLowerCase(), {
                            name: info.plugin.name,
                            path: Path.join([pluginsDir, file]),
                            runtime: info.plugin.runtime
                        });
                    }
                    else {
                        warning('Invalid plugin: ' + pluginProjectPath);
                    }
                }
                catch (e:Dynamic) {
                    error('Failed to parse plugin config: ' + pluginProjectPath);
                }
            }

        }

        // Default plugins
        var files = FileSystem.readDirectory(context.defaultPluginsPath);
        for (file in files) {
            var pluginProjectPath = Path.join([context.defaultPluginsPath, file, 'ceramic.yml']);
            handlePluginProjectPath(context.defaultPluginsPath, pluginProjectPath, file);
        }

        // Project plugins
        if (FileSystem.exists(Path.join([context.cwd, 'ceramic.yml']))) {
            if (FileSystem.exists(context.projectPluginsPath) && FileSystem.isDirectory(context.projectPluginsPath)) {
                var files = FileSystem.readDirectory(context.projectPluginsPath);
                for (file in files) {
                    var pluginProjectPath = Path.join([context.projectPluginsPath, file, 'ceramic.yml']);
                    handlePluginProjectPath(context.projectPluginsPath, pluginProjectPath, file);
                }
            }
        }

        for (key in plugins.keys()) {
            var info = plugins.get(key);
            var name:String = info.name;
            var path:String = info.path;
            var runtime:Dynamic = info.runtime;
            try {
                if (!Path.isAbsolute(path)) path = Path.normalize(Path.join([context.dotCeramicPath, '..', path]));

                var pluginIndexPath = Path.join([path, 'index.js']);
                if (FileSystem.exists(pluginIndexPath)) {
                    var plugin:tools.spec.ToolsPlugin = js.Node.require(pluginIndexPath);
                    plugin.path = Path.directory(js.node.Require.resolve(pluginIndexPath));
                    plugin.name = name;
                    plugin.runtime = runtime;
                    context.plugins.set(name, plugin);
                }
                else {
                    context.unbuiltPlugins.set(name, { path: path, name: name, runtime: runtime });
                }
            }
            catch (e:Dynamic) {
                untyped console.error(e);
                error('Error when loading plugin: ' + path);
            }
        }

    }

    public static function runCeramic(cwd:String, args:Array<String>, mute:Bool = false) {

        if (args == null) {
            args = [];
        }
        var actualArgs = [].concat(args);
        if (!context.colors && actualArgs.indexOf('--no-colors') == -1) {
            actualArgs.push('--no-colors');
        }

        if (Sys.systemName() == 'Windows') {
            return command(Path.join([context.ceramicToolsPath, 'ceramic.cmd']), actualArgs, { cwd: cwd, mute: mute });
        } else {
            return command(Path.join([context.ceramicToolsPath, '../node/node_modules/.bin/node']), [Path.join([context.ceramicToolsPath, 'ceramic'])].concat(actualArgs), { cwd: cwd, mute: mute });
        }

    }

    public static function print(message:String):Void {

        if (context.muted) return;

        var message = '' + message;
        if (context.printSplitLines) {
            var parts = message.split("\n");
            for (part in parts) {
                Sync.run(function(done) {
                    js.Node.setTimeout(done, 0);
                });
                stdoutWrite(part+"\n");
            }
        }
        else {
            stdoutWrite(message+"\n");
        }

    }

    public static function success(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stdoutWrite(''+Colors.green(message)+"\n");
        } else {
            stdoutWrite(''+message+"\n");
        }

    }

    public static function error(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stderrWrite(''+Colors.red(message)+"\n");
        } else {
            stderrWrite(''+message+"\n");
        }

    }

    public static function warning(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stderrWrite(''+Colors.yellow(message)+"\n");
        } else {
            stderrWrite(''+message+"\n");
        }

    }

    public static function stdoutWrite(input:String) {

        if (isElectronProxy()) {
            var parts = (''+input).split("\n");
            var i = 0;
            while (i < parts.length) {
                var part = parts[i];
                part = part.replace("\r", '');
                js.Node.process.stdout.write(new js.node.Buffer(part).toString('base64')+(i + 1 < parts.length ? "\n" : ''), 'ascii');
                i++;
            }
        }
        else {
            js.Node.process.stdout.write(input);
        }

    }

    public static function stderrWrite(input:String) {

        if (isElectronProxy()) {
            var parts = (''+input).split("\n");
            var i = 0;
            while (i < parts.length) {
                var part = parts[i];
                part = part.replace("\r", '');
                js.Node.process.stderr.write(new js.node.Buffer(part).toString('base64')+(i + 1 < parts.length ? "\n" : ''), 'ascii');
                i++;
            }
        }
        else {
            js.Node.process.stderr.write(input);
        }

    }

    public static function fail(message:String):Void {

        error(message);
        js.Node.process.exit(1);

    }

    public static function runningHaxeServerPort():Int {

        var homedir:String = untyped js.Syntax.code("require('os').homedir()");
        var infoPath = Path.join([homedir, '.ceramic-haxe-server']);
        var mtime = Files.getLastModified(infoPath);
        var currentTime = Date.now().getTime() / 1000;
        var timeGap = Math.abs(currentTime - mtime);
        if (timeGap < 2.0) {
            return Std.parseInt(StringTools.trim(File.getContent(infoPath)));
        }
        else {
            return -1;
        }

    }

    public static function haxe(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool }) {

        var haxe = Sys.systemName() == 'Windows' ? 'haxe.cmd' : 'haxe';
        return command(Path.join([context.ceramicToolsPath, haxe]), args, options);

    }

    public static function haxeWithChecksAndLogs(args:Array<String>, ?options:{ ?cwd:String, ?logCwd:String }) {

        var haxe = Sys.systemName() == 'Windows' ? 'haxe.cmd' : 'haxe';
        return commandWithChecksAndLogs(Path.join([context.ceramicToolsPath, haxe]), args, options);

    }

    public static function haxelib(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool }) {

        var haxelib = Sys.systemName() == 'Windows' ? 'haxelib.cmd' : 'haxelib';

        if (options == null) {
            options = {};
        }
        else {
            options = {
                cwd: options.cwd,
                mute: options.mute,
                detached: options.detached
            };
        }

        if (args != null) {
            if (args[0] == 'install') {
                options.mute = true;
                print('Install haxe library: ' + args[1]);
            }
            else if (args[0] == 'dev') {
                options.mute = true;
                print('Link haxe library: ' + args[1]);
            }
        }

        return command(Path.join([context.ceramicToolsPath, haxelib]), args, options);

    }

    public static function haxelibGlobal(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool }) {

        return command('haxelib', args, options);

    }

    public static function node(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool }) {

        var node = Path.join([context.ceramicToolsPath, '../node/node_modules/.bin/node']);
        if (Sys.systemName() == 'Windows')
            node += '.cmd';
        return command(node, args, options);

    }

    public static function commandExists(name:String):Bool {

        return npm.CommandExists.existsSync(name);

    }

    public static function ensureHaxelibDevToCeramicHaxelib(libName:String, haxelibVersion:String, cwd:String) {

        var ceramicHaxelibRepoPath = Path.join([context.ceramicRootPath, '.haxelib']);
        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        var projectLibPath = Path.join([haxelibRepoPath, libName]);
        var devPath = Path.join([projectLibPath, '.dev']);
        var currentPath = Path.join([projectLibPath, '.current']);

        var ceramicHaxelibPath = Path.join([ceramicHaxelibRepoPath, libName, haxelibVersion]);

        if (FileSystem.exists(devPath)) {
            var devContent = File.getContent(devPath).trim();
            if (devContent != ceramicHaxelibPath) {
                File.saveContent(devPath, ceramicHaxelibPath);
            }
        }
        else {
            if (FileSystem.exists(currentPath)) {
                FileSystem.deleteFile(currentPath);
            }
            if (!FileSystem.exists(projectLibPath)) {
                FileSystem.createDirectory(projectLibPath);
            }
            File.saveContent(devPath, ceramicHaxelibPath);
        }

    }

    public static function ensureHaxelibDevToCeramicGit(libName:String, cwd:String, ?intermediateDir:String) {

        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        var projectLibPath = Path.join([haxelibRepoPath, libName]);
        var devPath = Path.join([projectLibPath, '.dev']);
        var currentPath = Path.join([projectLibPath, '.current']);

        var ceramicHaxelibGitPath = Path.join([context.ceramicGitDepsPath, libName]);

        if (intermediateDir != null)
            ceramicHaxelibGitPath = Path.join([ceramicHaxelibGitPath, intermediateDir]);

        if (FileSystem.exists(devPath)) {
            var devContent = File.getContent(devPath).trim();
            if (devContent != ceramicHaxelibGitPath) {
                File.saveContent(devPath, ceramicHaxelibGitPath);
            }
        }
        else {
            if (FileSystem.exists(currentPath)) {
                FileSystem.deleteFile(currentPath);
            }
            if (!FileSystem.exists(projectLibPath)) {
                FileSystem.createDirectory(projectLibPath);
            }
            File.saveContent(devPath, ceramicHaxelibGitPath);
        }

    }

    public static function checkProjectHaxelibSetup(cwd:String, args:Array<String>) {

        var ceramicHaxelibRepoPath = Path.join([context.ceramicRootPath, '.haxelib']);
        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        if (!FileSystem.exists(haxelibRepoPath))
            FileSystem.createDirectory(haxelibRepoPath);

        ensureHaxelibDevToCeramicHaxelib('hxcpp', '4,3,2', cwd);
        ensureHaxelibDevToCeramicHaxelib('hxcs', '4,2,0', cwd);
        ensureHaxelibDevToCeramicGit('hxnodejs-ws', cwd);
        ensureHaxelibDevToCeramicGit('hscript', cwd);
        ensureHaxelibDevToCeramicGit('bind', cwd);
        ensureHaxelibDevToCeramicGit('hxnodejs', cwd);
        ensureHaxelibDevToCeramicGit('format', cwd);
        ensureHaxelibDevToCeramicGit('ase', cwd);
        ensureHaxelibDevToCeramicGit('bin-packing', cwd);
        ensureHaxelibDevToCeramicGit('akifox-asynchttp', cwd);
        ensureHaxelibDevToCeramicGit('tracker', cwd);
        ensureHaxelibDevToCeramicGit('arcade', cwd);
        ensureHaxelibDevToCeramicGit('nape', cwd);
        ensureHaxelibDevToCeramicGit('differ', cwd);
        ensureHaxelibDevToCeramicGit('hsluv', cwd, 'haxe');
        ensureHaxelibDevToCeramicGit('spine-hx', cwd);
        ensureHaxelibDevToCeramicGit('polyline', cwd);
        ensureHaxelibDevToCeramicGit('earcut', cwd);
        ensureHaxelibDevToCeramicGit('poly2tri', cwd);
        ensureHaxelibDevToCeramicGit('generate', cwd);
        ensureHaxelibDevToCeramicGit('format-tiled', cwd);
        ensureHaxelibDevToCeramicGit('imgui-hx', cwd);
        ensureHaxelibDevToCeramicGit('gif', cwd);
        ensureHaxelibDevToCeramicGit('linc_dialogs', cwd);
        ensureHaxelibDevToCeramicGit('linc_rtmidi', cwd);
        ensureHaxelibDevToCeramicGit('fuzzaldrin', cwd);

    }

    public static function installMissingLibsIfNeeded(cwd:String, args:Array<String>, ?project:Project) {

        if (project == null) {
            project = ensureCeramicProject(cwd, args, App);
        }

        var haxelibRepoPath = Path.join([cwd, '.haxelib']);

        var hasMissingLibs = false;

        var appLibs:Array<Dynamic> = project.app.libs;
        for (lib in appLibs) {
            var libName:String = null;
            var libVersion:String = "*";
            if (Std.isOfType(lib, String)) {
                libName = lib;
            } else {
                for (k in Reflect.fields(lib)) {
                    libName = k;
                    libVersion = Reflect.field(lib, k);
                    break;
                }
            }
            if (libVersion.trim() == '' || libVersion == '*') {
                // Any version
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName]))) {
                    hasMissingLibs = true;
                }
            }
            else if (libVersion.startsWith('git:')) {
                // Git
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName, 'git']))) {
                    hasMissingLibs = true;
                }
            }
            else if (libVersion.startsWith('path:')) {
                // Path/Dev
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName, '.dev']))) {
                    hasMissingLibs = true;
                }
            }
            else {
                // Specific version
                if (!FileSystem.exists(Path.join([haxelibRepoPath, libName, libVersion.trim().replace('.',',')]))) {
                    hasMissingLibs = true;
                }
            }
        }

        if (hasMissingLibs) {
            var taskName = 'libs';
            if (context.backend != null) {
                taskName = context.backend.name + ' ' + taskName;
            }
            runTask('libs');
        }

    }

    /** Like `command()`, but will perform additional checks and log formatting,
        compared to a regular `command()` call. Use it to run compilers and run apps.
        @return status code */
    public static function commandWithChecksAndLogs(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?logCwd:String }):Int {

        if (options == null) {
            options = { cwd: null, logCwd: null };
        }
        if (options.cwd == null) options.cwd = context.cwd;
        if (options.logCwd == null) options.logCwd = options.cwd;

        var status = 0;

        var cwd = options.cwd;
        var logCwd = options.logCwd;

        Sync.run(function(done) {

            var proc = null;
            if (args == null) {
                proc = ChildProcess.spawn(name, { cwd: cwd });
            } else {
                proc = ChildProcess.spawn(name, args, { cwd: cwd });
            }

            var out = StreamSplitter.splitter("\n");
            proc.stdout.on('data', function(data:Dynamic) {
                out.write(data);
            });
            proc.on('exit', function(code:Int) {
                status = code;
                if (done != null) {
                    var _done = done;
                    done = null;
                    _done();
                }
            });
            proc.on('close', function(code:Int) {
                status = code;
                if (done != null) {
                    var _done = done;
                    done = null;
                    _done();
                }
            });
            out.encoding = 'utf8';
            out.on('token', function(token:String) {
                token = formatLineOutput(logCwd, token);
                stdoutWrite(token + "\n");
            });
            out.on('done', function() {
            });
            out.on('error', function(err) {
            });

            var err = StreamSplitter.splitter("\n");
            proc.stderr.on('data', function(data:Dynamic) {
                err.write(data);
            });
            err.encoding = 'utf8';
            err.on('token', function(token:String) {
                token = formatLineOutput(logCwd, token);
                stderrWrite(token + "\n");
            });
            err.on('error', function(err) {
            });

        });

        return status;

    }

    public static function command(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool, ?detached:Bool }) {

        if (options == null) {
            options = { cwd: null, mute: false, detached: false };
        }

        if (context.muted) options.mute = true;

        if (options.cwd == null) options.cwd = context.cwd;

        var result = {
            stdout: '',
            stderr: '',
            status: 0
        };

        // Handle Windows, again...
        if (Sys.systemName() == 'Windows') {
            // npm
            if (name == 'npm' || name == 'node' || name == 'ceramic' || name == 'haxe' || name == 'haxelib' || name == 'neko') {
                name = name + '.cmd';
            }
        }

        var spawnOptions:Dynamic = { cwd: options.cwd };

        if (options.detached) {
            //var out = js.node.Fs.openSync('./out.log', 'a');
            //var err = js.node.Fs.openSync('./out.log', 'a');
            spawnOptions.detached = true;
            spawnOptions.stdio = ['ignore', 'ignore', 'ignore'];

            var proc = null;
            if (args == null) {
                proc = ChildProcess.spawn(name, spawnOptions);
            } else {
                proc = ChildProcess.spawn(name, args, spawnOptions);
            }
            proc.unref();
        }
        else {
            // Needed for haxe/haxelib commands
            /*var originalPATH:String = untyped process.env.PATH;
            if (originalPATH != null) {
                spawnOptions.env = { PATH: Path.normalize(context.ceramicToolsPath) + ';' + originalPATH };
            }*/

            Sync.run(function(done) {
                var proc = null;
                if (args == null) {
                    proc = ChildProcess.spawn(name, spawnOptions);
                } else {
                    proc = ChildProcess.spawn(name, args, spawnOptions);
                }

                proc.stdout.on('data', function(input) {
                    result.stdout += input.toString();
                    if (!options.mute) {
                        stdoutWrite(input.toString());
                    }
                });

                proc.stderr.on('data', function(input) {
                    result.stderr += input.toString();
                    if (!options.mute) {
                        stderrWrite(input.toString());
                    }
                });

                proc.on('error', function(err) {
                    error(err + ' (' + options.cwd + ')');
                    fail('Failed to run command: ' + name + (args != null && args.length > 0 ? ' ' + args.join(' ') : ''));
                });

                proc.on('close', function(code) {
                    result.status = code;
                    done();
                });

            });
        }

        return result;

    }

    public static function runTask(taskCommand, ?args:Array<String>, addContextArgs:Bool = true, allowMissingTask:Bool = false):Bool {

        var task = context.tasks.get(taskCommand);
        if (task == null) {
            var err = 'Cannot run task because `ceramic $taskCommand` command doesn\'t exist.';
            if (allowMissingTask) {
                warning(err);
            }
            else {
                fail(err);
            }
            return false;
        }

        // Run with electron runner
        var taskArgs = [];
        if (args != null) {
            taskArgs = [].concat(args);
        }
        taskArgs.push('--cwd');
        taskArgs.push(context.cwd);
        if (context.debug) {
            taskArgs.push('--debug');
        }
        if (context.variant != 'standard') {
            taskArgs.push('--variant');
            taskArgs.push(context.variant);
        }
        task.run(context.cwd, taskArgs);

        return true;

    }

    public static function extractArgValue(args:Array<String>, name:String, remove:Bool = false):String {

        var index = args.indexOf('--$name');

        if (index == -1) {
            return null;
        }

        if (index + 1 >= args.length) {
            fail('A value is required after --$name argument.');
        }

        var value = args[index + 1];

        if (remove) {
            args.splice(index, 2);
        }

        return value;

    }

    public static function extractArgFlag(args:Array<String>, name:String, remove:Bool = false):Bool {

        var index = args.indexOf('--$name');

        if (index == -1) {
            return false;
        }

        if (remove) {
            args.splice(index, 1);
        }

        return true;

    }

    public static function getRelativePath(absolutePath:String, relativeTo:String):String {

        return Files.getRelativePath(absolutePath, relativeTo);

    }

    public static function getTargetName(args:Array<String>, availableTargets:Array<tools.BuildTarget>):String {

        // Compute target from args
        var targetArgIndex = 1;
        if (args.length > 1) {
            if (context.tasks.exists(args[0] + ' ' + args[1])) {
                targetArgIndex++;
            }
        }
        var targetArg = args[targetArgIndex];
        var targetName = null;
        if (targetArg != null && !targetArg.startsWith('--')) {
            targetName = targetArg;
        }

        // Special case
        if (targetName == 'default') return targetName;

        // Return it only if available in targets
        for (target in availableTargets) {
            if (targetName == target.name) {
                return targetName;
            }
        }
        targetName = null;

        // Compute target name from current OS
        //
        var os = Sys.systemName();
        if (os == 'Mac') {
            targetName = 'mac';
        }
        else if (os == 'Windows') {
            targetName == 'windows';
        }
        else if (os == 'Linux') {
            targetName == 'linux';
        }

        // Return it only if available in targets
        for (target in availableTargets) {
            if (targetName == target.name) {
                return targetName;
            }
        }

        // Nothing matched
        return null;

    }

    static var RE_STACK_FILE_LINE = ~/Called\s+from\s+([a-zA-Z0-9_:\.]+)\s+(.+?\.hx)\s+line\s+([0-9]+)$/;
    static var RE_STACK_FILE_LINE_BIS = ~/([a-zA-Z0-9_:\.]+)\s+\((.+?\.hx)\s+line\s+([0-9]+)\)$/;
    static var RE_TRACE_FILE_LINE = ~/(.+?\.hx)::?([0-9]+):?\s+/;
    static var RE_HAXE_ERROR = ~/^(.+)::?(\d+):? (?:lines \d+-(\d+)|character(?:s (\d+)-| )(\d+)) : (?:(Warning) : )?(.*)$/;
    static var RE_JS_FILE_LINE = ~/^(?:\[error\] )?at ([a-zA-Z0-9_\.-]+) \((.+)\)$/;

    public static function isErrorOutput(input:String):Bool {

        // We don't want \r char to mess up everything (windows)
        input = input.replace("\r", '');

        if (input.indexOf(': Warning :') != -1) return false; // This is a warning, not an error

        var result = RE_HAXE_ERROR.match(input);

        return result;

    }

    public static function formatLineOutput(cwd:String, input:String):String {

        if (!context.colors) {
            input = StripAnsi.stripAnsi(input);
        }

        // We don't want \r char to mess up everything (windows)
        input = input.replace("\r", '').rtrim();

        if (RE_HAXE_ERROR.match(input)) {
            var relativePath = RE_HAXE_ERROR.matched(1);
            var lineNumber = RE_HAXE_ERROR.matched(2);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            if (context.vscode) {
                var charsBefore = 'characters ' + RE_HAXE_ERROR.matched(4) + '-' + RE_HAXE_ERROR.matched(5);
                var charsAfter = 'characters ' + (Std.parseInt(RE_HAXE_ERROR.matched(4))#if (haxe_ver < 4) + 1 #end) + '-' + (Std.parseInt(RE_HAXE_ERROR.matched(5))#if (haxe_ver < 4) + 1 #end);
                input = input.replace(charsBefore, charsAfter);
            }
            input = input.replace(relativePath, absolutePath);
            if (context.colors) {
                if (input.indexOf(': Warning :') != -1) {
                    input = '$absolutePath:$lineNumber: '.gray() + input.replace(': Warning :', ':').substr('$absolutePath:$lineNumber:'.length + 1).yellow();
                } else {
                    input = '$absolutePath:$lineNumber: '.gray() + input.substr('$absolutePath:$lineNumber:'.length + 1).red();
                }
            } else {
                input = '$absolutePath:$lineNumber: ' + input.substr('$absolutePath:$lineNumber:'.length + 1);
            }
        }
        else if (RE_STACK_FILE_LINE.match(input)) {
            var symbol = RE_STACK_FILE_LINE.matched(1);
            var relativePath = RE_STACK_FILE_LINE.matched(2);
            var lineNumber = RE_STACK_FILE_LINE.matched(3);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            if (context.colors) {
                input = input.replace(RE_STACK_FILE_LINE.matched(0), '$symbol '.red() + '$absolutePath:$lineNumber'.gray());
            } else {
                input = input.replace(RE_STACK_FILE_LINE.matched(0), '$symbol $absolutePath:$lineNumber');
            }
        }
        else if (RE_STACK_FILE_LINE_BIS.match(input)) {
            var symbol = RE_STACK_FILE_LINE_BIS.matched(1);
            var relativePath = RE_STACK_FILE_LINE_BIS.matched(2);
            var lineNumber = RE_STACK_FILE_LINE_BIS.matched(3);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            if (context.colors) {
                input = input.replace(RE_STACK_FILE_LINE_BIS.matched(0), '$symbol '.red() + '$absolutePath:$lineNumber'.gray());
            } else {
                input = input.replace(RE_STACK_FILE_LINE_BIS.matched(0), '$symbol $absolutePath:$lineNumber');
            }
        }
        else if (RE_TRACE_FILE_LINE.match(input)) {
            var relativePath = RE_TRACE_FILE_LINE.matched(1);
            var lineNumber = RE_TRACE_FILE_LINE.matched(2);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            input = input.replace(RE_TRACE_FILE_LINE.matched(0), '');
            if (context.colors) {
                if (input.startsWith('[info] ')) {
                    input = input.substr(7).cyan();
                } else if (input.startsWith('[debug] ')) {
                    input = input.substr(8).magenta();
                } else if (input.startsWith('[warning] ')) {
                    input = input.substr(10).yellow();
                } else if (input.startsWith('[error] ')) {
                    input = input.substr(8).red();
                } else if (input.startsWith('[success] ')) {
                    input = input.substr(10).green();
                } else if (input.startsWith('characters ')) {
                    input = input.red();
                }
                input += ' $absolutePath:$lineNumber'.gray();
            } else {
                input += ' $absolutePath:$lineNumber';
            }
        }
        else if (RE_JS_FILE_LINE.match(input)) {
            var identifier = RE_JS_FILE_LINE.matched(1);
            var absolutePathWithLine = RE_JS_FILE_LINE.matched(2);
            if (context.colors) {
                input = (identifier + ' ').red() + absolutePathWithLine.gray();
            } else {
                input = identifier + ' ' + absolutePathWithLine;
            }
        }
        else if (context.colors && input.startsWith('Error : ')) {
            input = input.red();
        }
        else if (input.startsWith('[error] ')) {
            if (context.colors) {
                input = input.substring('[error] '.length);
                input = input.red();
            }
        }
        else if (input.startsWith('[warning] ')) {
            if (context.colors) {
                input = input.substring('[warning] '.length);
                input = input.yellow();
            }
        }
        else if (input.startsWith('[success] ')) {
            if (context.colors) {
                input = input.substring('[success] '.length);
                input = input.green();
            }
        }
        else if (input.startsWith('[info] ')) {
            if (context.colors) {
                input = input.substring('[info] '.length);
                input = input.cyan();
            }
        }
        else if (input.startsWith('[debug] ')) {
            if (context.colors) {
                input = input.substring('[debug] '.length);
                input = input.magenta();
            }
        }
        else if (input == '[debug]' || input == '[info]' || input == '[success]' || input == '[warning]' || input == '[error]') {
            input = '';
        }
        else if (context.colors && input.startsWith('Called from hxcpp::')) {
            input = input.red();
        }

        return input;

    }

    public static function loadProject(cwd:String, args:Array<String>):Project {

        var projectPath = Path.join([cwd, 'ceramic.yml']);
        if (!FileSystem.exists(projectPath)) return null;
        var kind = getProjectKind(cwd, args);
        if (kind == null) return null;
        switch (kind) {
            case App:
                var project = new Project();
                project.loadAppFile(projectPath);
                return project;

            case Plugin(_):
                var project = new Project();
                project.loadPluginFile(projectPath);
                return project;
        }
        return null;

    }

    public static function getProjectKind(cwd:String, args:Array<String>):ProjectKind {

        return new Project().getKind(Path.join([cwd, 'ceramic.yml']));

    }

    public static function loadIdeInfo(cwd:String, args:Array<String>):Dynamic {

        var ceramicYamlPath = Path.join([cwd, 'ceramic.yml']);
        if (!FileSystem.exists(ceramicYamlPath)) {
            fail('Cannot load IDE info because ceramic.yml does not exist ($ceramicYamlPath)');
        }

        try {
            var yml = File.getContent(ceramicYamlPath);
            yml = yml.replace('{plugin:cwd}', cwd);
            yml = yml.replace('{cwd}', cwd);
            var data = Yaml.parse(yml);
            if (data == null) {
                fail('Invalid IDE data at path: $ceramicYamlPath');
            }
            if (data.ide == null) {
                return {};
            }
            else {
                return data.ide;
            }
        }
        catch (e:Dynamic) {
            fail('Failed to load yaml data at path: $ceramicYamlPath ; $e');
            return null;
        }

    }

    public static function ensureCeramicProject(cwd:String, args:Array<String>, kind:ProjectKind):Project {

        switch (kind) {
            case App:
                var project = new Project();
                project.loadAppFile(Path.join([cwd, 'ceramic.yml']));
                return project;

            case Plugin(_):
                var project = new Project();
                project.loadPluginFile(Path.join([cwd, 'ceramic.yml']));
                return project;
        }

        fail('Failed to ensure this is a ceramic project.');
        return null;

    }

    public static function runHooks(cwd:String, args:Array<String>, hooks:Array<Hook>, when:String):Void {

        if (hooks == null) return;

        for (hook in hooks) {
            if (hook.when == when) {
                print('Run $when hooks');
                break;
            }
        }

        for (hook in hooks) {
            if (hook.when == when) {

                var cmd = hook.command;
                var res;
                if (cmd == 'ceramic') {
                    res = runCeramic(cwd, hook.args != null ? hook.args : []);
                }
                else {
                    res = command(hook.command, hook.args != null ? hook.args : [], { cwd: cwd });
                }

                if (res.status != 0) {
                    if (res.stderr.trim().length > 0) {
                        warning(res.stderr);
                    }
                    fail('Error when running hook: ' + hook.command + (hook.args != null ? ' ' + hook.args.join(' ') : ''));
                }

            }
        }

    }

    public static function isElectron():Bool {

        return js.Node.process.versions['electron'] != null;

    }

    public static function isElectronProxy():Bool {

        return js.Node.global.isElectronProxy != null;

    }

    static var RE_HXCPP_LINE_MARKER = ~/^(HXLINE|HXDLIN)\([^)]+\)/;

    public static function stripHxcppLineMarkers(cppContent:String):String {

        var cppLines = cppContent.split("\n");

        for (i in 0...cppLines.length) {
            var line = cppLines[i];
            if (RE_HXCPP_LINE_MARKER.match(line.ltrim())) {
                var len = RE_HXCPP_LINE_MARKER.matched(0).length;
                var space = '';
                for (n in 0...len) {
                    space += ' ';
                }
                cppLines[i] = line.replace(RE_HXCPP_LINE_MARKER.matched(0), space);
            }
        }

        return cppLines.join("\n");

    }

    public static function toAssetConstName(input:String):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var canAddSpace = false;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '/') {
                res.add('__');
                canAddSpace = false;
            }
            else if (c == '.') {
                res.add('_');
                canAddSpace = false;
            }
            else if (isAsciiChar(c)) {

                var uc = c.toUpperCase();
                var isUpperCase = (c == uc);

                if (canAddSpace && isUpperCase) {
                    res.add('_');
                    canAddSpace = false;
                }

                res.add(uc);
                canAddSpace = !isUpperCase;
            }
            else {
                res.add('_');
                canAddSpace = false;
            }

            i++;
        }

        var str = res.toString();
        if (str.endsWith('_')) str = str.substr(0, str.length - 1);

        return str;

    }

    public static function isAsciiChar(c:String):Bool {

        var code = c.charCodeAt(0);
        return (code >= '0'.code && code <= '9'.code)
            || (code >= 'A'.code && code <= 'Z'.code)
            || (code >= 'a'.code && code <= 'z'.code);

    }

    public static function compareSemVerAscending(a:String, b:String):Int {

        var partsA = a.split('.');
        var partsB = b.split('.');

        var i = 0;
        while (i < partsA.length && i < partsB.length) {
            var partA = Std.parseInt(partsA[i]);
            var partB = Std.parseInt(partsB[i]);

            if (partA > partB) {
                return 1;
            }
            else if (partA < partB) {
                return -1;
            }

            i++;
        }

        if (partsA.length > partsB.length) {
            return 1;
        }
        else if (partsA.length < partsB.length) {
            return -1;
        }

        return 0;

    }

    public static function getWindowsDrives():Array<String> {

        var result = [];
        var hasC = false;

        if (Sys.systemName() == 'Windows') {

            var out = command('wmic', ['logicaldisk', 'get', 'name'], { mute: true }).stdout;
            for (line in ~/[\r\n]+/g.split(out)) {
                line = line.trim();
                if (line.length >= 2 && line.charAt(1) == ':') {
                    var letter = line.charAt(0).toUpperCase();
                    if (letter == 'C') {
                        hasC = true;
                    }
                    else {
                        result.push(letter);
                    }
                }
            }
        }

        if (hasC) {
            result.unshift('C');
        }

        return result;

    }

    static var RE_NORMALIZED_WINDOWS_PATH_PREFIX = ~/^\/[a-zA-Z]:\//;

    public static function fixWindowsArgsPaths(args:Array<String>):Void {

        // Remove absolute path leading slash on windows, if any
        // This let us accept absolute paths that start with `/c:/` instead of `c:/`
        // which could happen after joining/normalizing paths via node.js or vscode extension
        if (Sys.systemName() == 'Windows') {
            var i = 0;
            while (i + 1 < args.length) {
                if (args[i].startsWith('--')) {
                    var value = args[i + 1];
                    if (value != null && value.startsWith('/') && RE_NORMALIZED_WINDOWS_PATH_PREFIX.match(value)) {
                        args[i + 1] = value.substring(1);
                        i++;
                    }
                }
                i++;
            }
        }

    }
}
