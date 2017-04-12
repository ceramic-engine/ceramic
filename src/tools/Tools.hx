package tools;

import npm.Colors;
import npm.Fiber;
import sys.FileSystem;
import haxe.io.Path;
import js.node.ChildProcess;

using StringTools;

class Tools {

/// Global

    public static var shared(default,null):Tools;

    static function main():Void {

        // Expose new Tools(cwd, args).run()
        var module:Dynamic = js.Node.module;
        module.exports = boot;

    } //main

    static function boot(cwd:String, args:Array<String>):Void {

        shared = new Tools(cwd, args);
        shared.run();

    } //boot

    public static var settings = {
        colors: true,
        defines: new Map<String,String>(),
        ceramicPath: js.Node.__dirname
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

        this.cwd = cwd;
        this.args = args;

        #if use_backend

        tasks.set('targets', new tools.tasks.Targets());
        tasks.set('setup', new tools.tasks.Setup());
        tasks.set('hxml', new tools.tasks.Hxml());
        tasks.set('build', new tools.tasks.Build('Build'));
        tasks.set('run', new tools.tasks.Build('Run'));

        #else

        tasks.set('init', new tools.tasks.Init());
        tasks.set('info', new tools.tasks.Info());

        #end

    } //new

    function loadRootArgs():Void {

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

        // Defines
        var newArgs = [];
        var i = 0;
        while (i < args.length) {
            var arg = args[i];
            if (arg.trim() != '') {
                // Add custom defines?
                if (arg.trim().startsWith('-D')) {
                    var val = null;
                    if (arg.trim() == '-D') {
                        if (i < args.length - 1) {
                            i++;
                            val = args[i].trim();
                        }
                    } else {
                        val = arg.trim().substr(2);
                    }
                    if (val != null && val.length > 0) {
                        var equalIndex = val.indexOf('=');
                        if (equalIndex == -1) {
                            // Simple flag
                            settings.defines.set(val, '');
                        } else {
                            // Flag with custom value
                            settings.defines.set(val.substring(0, equalIndex), val.substring(equalIndex + 1));
                        }
                    }
                }
                else {
                    newArgs.push(arg);
                }
            }
            i++;
        }
        args = newArgs;

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
                    // Run task
                    task.run(cwd, args);

                }).run();

            } else {
                fail('Unknown task: $taskName');
            }
        }
        
    } //run

/// Utils

    public static function print(message:String):Void {

        js.Node.process.stdout.write(''+message+"\n");

    } //log

    public static function success(message:String):Void {

        if (settings.colors) {
            js.Node.process.stdout.write(''+Colors.green(message)+"\n");
        } else {
            js.Node.process.stdout.write(''+message+"\n");
        }

    } //success

    public static function error(message:String):Void {

        if (settings.colors) {
            js.Node.process.stderr.write(''+Colors.red(message)+"\n");
        } else {
            js.Node.process.stderr.write(''+message+"\n");
        }

    } //error

    public static function warning(message:String):Void {

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

} //Tools
