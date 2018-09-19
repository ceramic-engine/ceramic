package tools;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import js.node.ChildProcess;
import tools.Project;
import npm.Yaml;
import npm.StripAnsi;

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
        context.defines.set('assets_path', Path.join([cwd, 'assets']));
        context.defines.set('ceramic_assets_path', Path.join([context.ceramicToolsPath, 'assets']));
        context.defines.set('HXCPP_STACK_LINE', '');
        context.defines.set('HXCPP_STACK_TRACE', '');
        context.defines.set('actuate_manual_update', '');

        if (context.variant != null) {
            context.defines.set('variant', context.variant);
            if (!context.defines.exists(context.variant)) {
                context.defines.set(context.variant, 'variant');
            }
        }

        // Add plugin assets paths
        var pluginsAssetPaths = [];
        for (plugin in context.plugins) {
            var path_ = Path.join([plugin.path, 'assets']);
            if (FileSystem.exists(path_) && FileSystem.isDirectory(path_)) {
                pluginsAssetPaths.push(path_);
            }
        }
        context.defines.set('ceramic_plugins_assets_paths', Json.stringify(Json.stringify(pluginsAssetPaths)));

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

    } //extractDefines

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

    } //setVariant

    public static function computePlugins() {

        context.plugins = new Map();
        context.unbuiltPlugins = new Map();

        var plugins:Map<String,{
            name:String,
            path:String
        }> = new Map();

        // Default plugins
        var files = FileSystem.readDirectory(context.defaultPluginsPath);
        for (file in files) {
            var pluginProjectPath = Path.join([context.defaultPluginsPath, file, 'ceramic.yml']);
            if (FileSystem.exists(pluginProjectPath)) {
                // Extract info
                try {
                    var info = Yaml.parse(File.getContent(pluginProjectPath));
                    if (info != null && info.plugin != null && info.plugin.name != null) {
                        plugins.set((''+info.plugin.name).toLowerCase(), {
                            name: info.plugin.name,
                            path: Path.join([context.defaultPluginsPath, file])
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

        // Plugins as haxe libraries
        // TODO

        for (key in plugins.keys()) {
            var info = plugins.get(key);
            var name:String = info.name;
            var path:String = info.path;
            try {
                if (!Path.isAbsolute(path)) path = Path.normalize(Path.join([context.dotCeramicPath, '..', path]));
                
                var pluginIndexPath = Path.join([path, 'index.js']);
                if (FileSystem.exists(pluginIndexPath)) {
                    var plugin:tools.spec.ToolsPlugin = js.Node.require(pluginIndexPath);
                    plugin.path = Path.directory(js.node.Require.resolve(pluginIndexPath));
                    plugin.name = name;
                    context.plugins.set(name, plugin);
                }
                else {
                    context.unbuiltPlugins.set(name, { path: path });
                }
            }
            catch (e:Dynamic) {
                untyped console.error(e);
                error('Error when loading plugin: ' + path);
            }
        }

    } //computePlugins

    public static function runCeramic(cwd:String, args:Array<String>, mute:Bool = false) {

        return command(Path.join([context.ceramicToolsPath, 'ceramic']), args, { cwd: cwd, mute: mute });

    } //runCeramic

    public static function print(message:String):Void {

        if (context.muted) return;

        stdoutWrite(''+message+"\n");

    } //log

    public static function success(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stdoutWrite(''+Colors.green(message)+"\n");
        } else {
            stdoutWrite(''+message+"\n");
        }

    } //success

    public static function error(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stderrWrite(''+Colors.red(message)+"\n");
        } else {
            stderrWrite(''+message+"\n");
        }

    } //error

    public static function warning(message:String):Void {

        if (context.muted) return;

        if (context.colors) {
            stderrWrite(''+Colors.yellow(message)+"\n");
        } else {
            stderrWrite(''+message+"\n");
        }

    } //warning

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

    } //stdoutWrite

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

    } //stderrWrite

    public static function fail(message:String):Void {

        error(message);
        js.Node.process.exit(1);

    } //fail

    public static function haxe(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {
        
        return command(Path.join([context.ceramicToolsPath, 'haxe']), args, options);

    } //haxe

    public static function haxelib(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {

        return command(Path.join([context.ceramicToolsPath, 'haxelib']), args, options);

    } //haxelib

    public static function command(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {
        
        if (options == null) {
            options = { cwd: null, mute: false };
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
            if (name == 'npm') {
                name = 'npm.cmd';
            }
        }

        // Custom commands
        //
        // Like: rm -rf {path}
        if (name == 'rimraf' && args[0] != null) {
            var rimraf = js.Node.require('rimraf');
            var path = args[0];
            if (!Path.isAbsolute(path)) path = Path.normalize(Path.join([options.cwd, path]));

            rimraf.sync(path);

        }
        // Like: cp -R {source} {dest}
        else if (name == 'ncp' && args[0] != null && args[1] != null) {
            var source = args[0];
            var dest = args[1];
            if (!Path.isAbsolute(source)) source = Path.normalize(Path.join([options.cwd, source]));
            if (!Path.isAbsolute(dest)) dest = Path.normalize(Path.join([options.cwd, dest]));
            
            // We don't use original ncp because it has an outstanding bug unsolved for a year!
            // (see: https://github.com/AvianFlu/ncp/issues/111)
            Files.copyDirectory(source, dest);

        }
        else {

            Sync.run(function(done) {
                var proc = null;
                if (args == null) {
                    proc = ChildProcess.spawn(name, {cwd: options.cwd});
                } else {
                    proc = ChildProcess.spawn(name, args, {cwd: options.cwd});
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

    } //command

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

    } //extractArgValue

    public static function extractArgFlag(args:Array<String>, name:String, remove:Bool = false):Bool {
        
        var index = args.indexOf('--$name');

        if (index == -1) {
            return false;
        }

        if (remove) {
            args.splice(index, 1);
        }

        return true;

    } //extractArgFlag

    public static function getRelativePath(absolutePath:String, relativeTo:String):String {

        return Files.getRelativePath(absolutePath, relativeTo);

    } //getRelativePath

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

    } //getTargetName

    static var RE_STACK_FILE_LINE = ~/Called\s+from\s+([a-zA-Z0-9_:\.]+)\s+(.+?\.hx)\s+line\s+([0-9]+)$/;
    static var RE_STACK_FILE_LINE_BIS = ~/([a-zA-Z0-9_:\.]+)\s+\((.+?\.hx)\s+line\s+([0-9]+)\)$/;
    static var RE_TRACE_FILE_LINE = ~/(.+?\.hx)::?([0-9]+):?\s+/;
    static var RE_HAXE_ERROR = ~/^(.+)::?(\d+):? (?:lines \d+-(\d+)|character(?:s (\d+)-| )(\d+)) : (?:(Warning) : )?(.*)$/;
    static var RE_JS_FILE_LINE = ~/^(?:\[error\] )?at ([a-zA-Z0-9_\.-]+) \((.+)\)$/;

    public static function isErrorOutput(input:String):Bool {

        // We don't want \r char to mess up everything (windows)
        input = input.replace("\r", '');

        var result = RE_HAXE_ERROR.match(input);

        return result;

    } //isErrorOutput

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
                // We need to add 1 to character indexes for vscode to interpret them correctly
                // TODO remove this when using Haxe 4
                var charsBefore = 'characters ' + RE_HAXE_ERROR.matched(4) + '-' + RE_HAXE_ERROR.matched(5);
                var charsAfter = 'characters ' + (Std.parseInt(RE_HAXE_ERROR.matched(4)) + 1) + '-' + (Std.parseInt(RE_HAXE_ERROR.matched(5)) + 1);
                input = input.replace(charsBefore, charsAfter);
            }
            input = input.replace(relativePath, absolutePath);
            if (context.colors) {
                input = '$absolutePath:$lineNumber: '.gray() + input.substr('$absolutePath:$lineNumber:'.length + 1).red();
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
                if (input.startsWith('[log] ')) {
                    input = input.substr(6).cyan();
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
        else if (input.startsWith('[log] ')) {
            if (context.colors) {
                input = input.substring('[log] '.length);
                input = input.cyan();
            }
        }
        else if (input == '[log]' || input == '[success]' || input == '[warning]' || input == '[error]') {
            input = '';
        }
        else if (context.colors && input.startsWith('Called from hxcpp::')) {
            input = input.red();
        }

        return input;

    } //formatLineOutput

    public static function ensureCeramicProject(cwd:String, args:Array<String>, kind:ProjectKind):Project {

        switch (kind) {
            case App:
                var project = new Project();
                project.loadAppFile(Path.join([cwd, 'ceramic.yml']));
                return project;

            case Plugin(pluginKinds):
                var project = new Project();
                project.loadPluginFile(Path.join([cwd, 'ceramic.yml']));
                return project;
        }

        fail('Failed to ensure this is a ceramic project.');
        return null;

    } //ensureCeramicProject

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

                var res = command(hook.command, hook.args != null ? hook.args : [], { cwd: cwd });
                if (res.status != 0) {
                    if (res.stderr.trim().length > 0) {
                        warning(res.stderr);
                    }
                    fail('Error when running hook: ' + hook.command + (hook.args != null ? ' ' + hook.args.join(' ') : ''));
                }

            }
        }

    } //runHooks

    public static function isElectron():Bool {

        return js.Node.process.versions['electron'] != null;

    } //isElectron

    public static function isElectronProxy():Bool {

        return js.Node.global.isElectronProxy != null;

    } //isElectronProxy

} //Helpers
