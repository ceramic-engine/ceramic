package tools;

import npm.Colors;
import npm.Fiber;
import sys.FileSystem;
import haxe.io.Path;
import js.node.ChildProcess;

using StringTools;
using npm.Colors;

interface ToolsPlugin {

    function init(tools:Tools):Void;

    function extendProject(project:Project):Void;

} //ToolsPlugin

class Tools {

/// Global

    public static var muted:Bool = false;

    public static var shared(default,null):Tools;

    static function main():Void {

        // Expose new Tools(cwd, args).run()
        var module:Dynamic = js.Node.module;
        module.exports = _tools;

    } //main

    static function _tools(cwd:String, args:Array<String>, ceramicPath:String):Tools {

        return new Tools(cwd, args, ceramicPath);

    } //_tools

    public static function addPlugin(plugin:ToolsPlugin):Void {

        if (plugins == null) plugins = [];
        plugins.push(plugin);

    } //addPlugin

    public static var plugins:Array<ToolsPlugin>;

    public static var settings = {
        colors: true,
        defines: new Map<String,String>(),
        ceramicPath: '',
        variant: 'standard',
        vscode: false
    };

#if use_backend

    public static var backend:backend.tools.BackendTools = new backend.tools.BackendTools();

#end

/// Properties

    public var cwd:String;

    public var args:Array<String>;

    public var tasks(default,null):Map<String,tools.Task> = new Map<String,tools.Task>();

/// Lifecycle

    function new(cwd:String, args:Array<String>, ceramicPath:String) {

        shared = this;

        this.cwd = cwd;
        this.args = args;
        settings.ceramicPath = ceramicPath;

        #if use_backend

        tasks.set('targets', new tools.tasks.Targets());
        tasks.set('setup', new tools.tasks.Setup());
        tasks.set('hxml', new tools.tasks.Hxml());
        tasks.set('build', new tools.tasks.Build('Build'));
        tasks.set('run', new tools.tasks.Build('Run'));
        tasks.set('clean', new tools.tasks.Build('Clean'));
        tasks.set('assets', new tools.tasks.Assets());
        tasks.set('icons', new tools.tasks.Icons());
        tasks.set('update', new tools.tasks.Update());

        backend.init(this);

        #else

        tasks.set('help', new tools.tasks.Help());
        tasks.set('init', new tools.tasks.Init());
        tasks.set('vscode', new tools.tasks.Vscode());
        tasks.set('local', new tools.tasks.Local());
        tasks.set('setup', new tools.tasks.Setup());
        tasks.set('link', new tools.tasks.Link());
        tasks.set('unlink', new tools.tasks.Unlink());

        #end

        tasks.set('info', new tools.tasks.Info());
        tasks.set('libs', new tools.tasks.Libs());

        // Init plugins
        //
        if (plugins != null) {
            for (plugin in plugins) {
                plugin.init(this);
            }
        }

    } //new

    function loadRootArgs():Void {

#if use_backend
        settings.defines.set('backend', args[0]);
        settings.defines.set(args[0], '');
#end

        // Colors
        var index:Int = args.indexOf('--no-colors');
        if (index != -1) {
            settings.colors = false;
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
            settings.variant = variant;
            settings.defines.set('variant', variant);
            if (!settings.defines.exists(variant)) {
                settings.defines.set(variant, '');
            }
            args.splice(index, 2);
        }

        // VSCode
        index = args.indexOf('--vscode-editor');
        if (index != -1) {
            settings.vscode = true;
            args.splice(index, 1);
        }

    } //updateSettings

    function run():Void {

        loadRootArgs();

        if (args.length < 2) {
            fail('Invalid arguments.');
        }
        else {
            var taskName = args[1];

            if (tasks.exists(taskName)) {

                // Get task
                var task = tasks.get(taskName);

                // Wrap it inside a fiber to allow calling
                // Async code pseudo-synchronously
                Fiber.fiber(function() {

                    // Extract target defines
#if use_backend
                    extractTargetDefines(cwd, args);
#end

                    // Run task
                    task.run(cwd, args);

                }).run();

            } else {
                fail('Unknown command: $taskName');
            }
        }
        
    } //run

    public function getBackend():tools.spec.BackendTools {
#if use_backend
        return backend;
#else
        return null;
#end
    } //getBackend

/// Utils

#if use_backend

    public static function extractTargetDefines(cwd:String, args:Array<String>):Void {

        var availableTargets = backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            return;
        }

        // Find target from name
        //
        var target = null;
        for (aTarget in availableTargets) {

            if (aTarget.name == targetName) {
                target = aTarget;
                break;
            }

        }

        // Add generic defines
        settings.defines.set('assets_path', Path.join([cwd, 'assets']));
        settings.defines.set('ceramic_assets_path', Path.join([settings.ceramicPath, 'assets']));
        settings.defines.set('HXCPP_STACK_LINE', '');
        settings.defines.set('HXCPP_STACK_TRACE', '');
        settings.defines.set('absolute-path', '');

        // Add target defines
        if (target != null) {
            var extraDefines = backend.getTargetDefines(cwd, args, target, settings.variant);
            for (key in extraDefines.keys()) {
                if (!settings.defines.exists(key)) {
                    settings.defines.set(key, extraDefines.get(key));
                }
            }
        }

    } //extractTargetDefines

#end

    public static function runCeramic(cwd:String, args:Array<String>, mute:Bool = false) {

        return command(Path.join([settings.ceramicPath, 'ceramic']), args, { cwd: cwd, mute: mute });

    } //runCeramic

    public static function print(message:String):Void {

        if (muted) return;

        js.Node.process.stdout.write(''+message+"\n");

    } //log

    public static function success(message:String):Void {

        if (muted) return;

        if (settings.colors) {
            js.Node.process.stdout.write(''+Colors.green(message)+"\n");
        } else {
            js.Node.process.stdout.write(''+message+"\n");
        }

    } //success

    public static function error(message:String):Void {

        if (muted) return;

        if (settings.colors) {
            js.Node.process.stderr.write(''+Colors.red(message)+"\n");
        } else {
            js.Node.process.stderr.write(''+message+"\n");
        }

    } //error

    public static function warning(message:String):Void {

        if (muted) return;

        if (settings.colors) {
            js.Node.process.stderr.write(''+Colors.yellow(message)+"\n");
        } else {
            js.Node.process.stderr.write(''+message+"\n");
        }

    } //warning

    public static function fail(message:String):Void {

        error(message);
        js.Node.process.exit(1);

    } //fail

    public static function haxe(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {

        return command(Path.join([settings.ceramicPath, 'vendor', Sys.systemName().toLowerCase(), 'haxe/haxe']), args, options);

    } //haxe

    public static function haxelib(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {

        return command(Path.join([settings.ceramicPath, 'vendor', Sys.systemName().toLowerCase(), 'haxe/haxelib']), args, options);

    } //haxelib

    public static function node(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {

        return command(Path.join([settings.ceramicPath, 'vendor', Sys.systemName().toLowerCase(), 'node/bin/node']), args, options);

    } //node

    public static function command(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {
        
        if (options == null) {
            options = { cwd: null, mute: false };
        }

        // Handle Windows, again...
        if (Sys.systemName() == 'Windows' && name == 'npm') {
            name = 'npm.cmd';
        }

        if (muted) options.mute = true;

        if (options.cwd == null) options.cwd = shared.cwd;

        if (options.mute) {
            if (args == null) {
                return ChildProcess.spawnSync(name, {cwd: options.cwd});
            }
            return ChildProcess.spawnSync(name, args, {cwd: options.cwd});
        } else {
            if (args == null) {
                return ChildProcess.spawnSync(name, {stdio: "inherit", cwd: options.cwd});
            }
            return ChildProcess.spawnSync(name, args, {stdio: "inherit", cwd: options.cwd});
        }

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
        var targetArg = args[2];
        if (targetArg != null && !targetArg.startsWith('--')) {
            return targetArg;
        }

        // Compute target name from current OS
        //
        var os = Sys.systemName();
        var targetName = null;
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
    static var RE_TRACE_FILE_LINE = ~/(.+?\.hx):([0-9]+):\s+/;
    static var RE_HAXE_ERROR = ~/^(.+):(\d+): (?:lines \d+-(\d+)|character(?:s (\d+)-| )(\d+)) : (?:(Warning) : )?(.*)$/;

    public static function formatLineOutput(cwd:String, input:String):String {

        // We don't want \r char to mess up everything (windows)
        input = input.replace("\r", '');

        if (RE_HAXE_ERROR.match(input)) {
            var relativePath = RE_HAXE_ERROR.matched(1);
            var lineNumber = RE_HAXE_ERROR.matched(2);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            var newPath = Files.getRelativePath(absolutePath, shared.cwd);
            if (settings.vscode) {
                // We need to add 1 to character indexes for vscode to interpret them correctly
                var charsBefore = 'characters ' + RE_HAXE_ERROR.matched(4) + '-' + RE_HAXE_ERROR.matched(5);
                var charsAfter = 'characters ' + (Std.parseInt(RE_HAXE_ERROR.matched(4)) + 1) + '-' + (Std.parseInt(RE_HAXE_ERROR.matched(5)) + 1);
                input = input.replace(charsBefore, charsAfter);
            }
            input = input.replace(relativePath, newPath);
            if (settings.colors) {
                input = '$newPath:$lineNumber: '.gray() + input.substr('$newPath:$lineNumber:'.length + 1).red();
            } else {
                input = '$newPath:$lineNumber: ' + input.substr('$newPath:$lineNumber:'.length + 1);
            }
        }
        else if (RE_STACK_FILE_LINE.match(input)) {
            var symbol = RE_STACK_FILE_LINE.matched(1);
            var relativePath = RE_STACK_FILE_LINE.matched(2);
            var lineNumber = RE_STACK_FILE_LINE.matched(3);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            if (settings.colors) {
                input = input.replace(RE_STACK_FILE_LINE.matched(0), '$symbol '.red() + '$absolutePath:$lineNumber'.gray());
            } else {
                input = input.replace(RE_STACK_FILE_LINE.matched(0), '$symbol $absolutePath:$lineNumber');
            }
        }
        else if (RE_TRACE_FILE_LINE.match(input)) {
            var relativePath = RE_TRACE_FILE_LINE.matched(1);
            var lineNumber = RE_TRACE_FILE_LINE.matched(2);
            var absolutePath = Path.isAbsolute(relativePath) ? relativePath : Path.normalize(Path.join([cwd, relativePath]));
            input = input.replace(RE_TRACE_FILE_LINE.matched(0), '');
            if (settings.colors) {
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
        else if (settings.colors && input.startsWith('Error : ')) {
            input = input.red();
        }
        else if (settings.colors && input.startsWith('Called from hxcpp::')) {
            input = input.red();
        }

        return input;

    } //formatLineOutput

    public static function ensureCeramicProject(cwd:String, args:Array<String>):Void {

        if (!FileSystem.exists(Path.join([cwd, 'ceramic.yml']))) {
            fail("Current working directory must be a valid ceramic project.");
        }

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
                    fail('Error when running hook: ' + hook.command + (hook.args != null ? ' ' + hook.args.join(' ') : ''));
                }

            }
        }

    } //runHooks

} //Tools
