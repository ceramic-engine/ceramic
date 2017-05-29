package tools;

import npm.Colors;
import npm.Fiber;
import sys.FileSystem;
import haxe.io.Path;
import js.node.ChildProcess;

using StringTools;

class Tools {

/// Global

    public static var muted:Bool = false;

    public static var shared(default,null):Tools;

    static function main():Void {

        // Expose new Tools(cwd, args).run()
        var module:Dynamic = js.Node.module;
        module.exports = _tools;

    } //main

    static function _tools(cwd:String, args:Array<String>):Tools {

        return new Tools(cwd, args);

    } //_tools

    public static var settings = {
        colors: true,
        defines: new Map<String,String>(),
        ceramicPath: js.Node.__dirname,
        variant: 'standard'
    };

#if use_backend

    public static var backend:backend.tools.BackendTools = new backend.tools.BackendTools();

#end

/// Properties

    public var cwd:String;

    public var args:Array<String>;

    public var tasks(default,null):Map<String,tools.Task> = new Map<String,tools.Task>();

/// Lifecycle

    function new(cwd:String, args:Array<String>) {

        shared = this;

        this.cwd = cwd;
        this.args = args;

        #if use_backend

        tasks.set('targets', new tools.tasks.Targets());
        tasks.set('setup', new tools.tasks.Setup());
        tasks.set('hxml', new tools.tasks.Hxml());
        tasks.set('build', new tools.tasks.Build('Build'));
        tasks.set('run', new tools.tasks.Build('Run'));
        tasks.set('clean', new tools.tasks.Build('Clean'));
        tasks.set('assets', new tools.tasks.Assets());

        backend.init(this);

        #else

        tasks.set('help', new tools.tasks.Help());
        tasks.set('init', new tools.tasks.Init());
        tasks.set('vscode', new tools.tasks.Vscode());

        #end

        tasks.set('info', new tools.tasks.Info());
        tasks.set('update', new tools.tasks.Update());

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
            fail('You must specify a target to setup.');
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
        settings.defines.set('HXCPP_STACK_LINE', '');
        settings.defines.set('HXCPP_STACK_TRACE', '');

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

        return command(Path.join([js.Node.__dirname, 'ceramic']), args, { cwd: cwd, mute: mute });

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

    public static function command(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {
        
        if (options == null) {
            options = { cwd: null, mute: false };
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

        var fromParts = relativeTo.substr(1).split('/');
        var toParts = absolutePath.substr(1).split('/');

        var length:Int = cast Math.min(fromParts.length, toParts.length);
        var samePartsLength = length;
        for (i in 0...length) {
            if (fromParts[i] != toParts[i]) {
                samePartsLength = i;
                break;
            }
        }

        var outputParts = [];
        for (i in samePartsLength...fromParts.length) {
            outputParts.push('..');
        }

        outputParts = outputParts.concat(toParts.slice(samePartsLength));

        var result = outputParts.join('/');
        if (absolutePath.endsWith('/') && !result.endsWith('/')) {
            result += '/';
        }

        return result;

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

    public static function makeHaxePathAbsoluteInLine(cwd:String, input:String):String {

        var commaIndex = input.indexOf(':');
        if (commaIndex != -1) {
            var before = input.substr(0, commaIndex);
            var after = input.substr(commaIndex + 1);

            if (before.endsWith('.hx')) {
                if (!Path.isAbsolute(before)) {
                    before = Path.normalize(Path.join([cwd, before]));
                    if (FileSystem.exists(before)) {
                        return before + ':' + after;
                    }
                }
            }
        }

        return input;

    } //makeHaxePathAbsoluteInLine

} //Tools
