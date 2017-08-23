package tools;

import haxe.io.Path;
import js.node.ChildProcess;
import tools.Project;

using StringTools;
using tools.Colors;

class Helpers {

    public static var context:Context;

    public static function extractBackendTargetDefines(cwd:String, args:Array<String>):Void {

        if (context.backend == null) return;

        var availableTargets = context.backend.getBuildTargets();
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
        context.defines.set('assets_path', Path.join([cwd, 'assets']));
        context.defines.set('ceramic_assets_path', Path.join([context.ceramicPath, 'assets']));
        context.defines.set('HXCPP_STACK_LINE', '');
        context.defines.set('HXCPP_STACK_TRACE', '');
        context.defines.set('absolute-path', '');

        // Add target defines
        if (target != null) {
            var extraDefines = context.backend.getTargetDefines(cwd, args, target, context.variant);
            for (key in extraDefines.keys()) {
                if (!context.defines.exists(key)) {
                    context.defines.set(key, extraDefines.get(key));
                }
            }
        }

    } //extractBackendTargetDefines

    public static function runCeramic(cwd:String, args:Array<String>, mute:Bool = false) {

        return command(Path.join([context.ceramicPath, 'ceramic']), args, { cwd: cwd, mute: mute });

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
        
        return command('haxe', args, options);

    } //haxe

    public static function haxelib(args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {

        return command('haxelib', args, options);

    } //haxelib

    public static function command(name:String, ?args:Array<String>, ?options:{ ?cwd:String, ?mute:Bool }) {
        
        if (options == null) {
            options = { cwd: null, mute: false };
        }

        // Handle Windows, again...
        if (Sys.systemName() == 'Windows' && name == 'npm') {
            name = 'npm.cmd';
        }

        if (context.muted) options.mute = true;

        if (options.cwd == null) options.cwd = context.cwd;

        var result = {
            stdout: '',
            stderr: '',
            status: 0
        };

        Sync.run(function(done) {
            var proc = null;
            if (args == null) {
                proc = ChildProcess.spawn(name, {cwd: options.cwd});
            }
            proc = ChildProcess.spawn(name, args, {cwd: options.cwd});

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

            proc.on('close', function(code) {
                result.status = code;
                done();
            });

        });

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
            var newPath = Files.getRelativePath(absolutePath, context.cwd);
            if (context.vscode) {
                // We need to add 1 to character indexes for vscode to interpret them correctly
                var charsBefore = 'characters ' + RE_HAXE_ERROR.matched(4) + '-' + RE_HAXE_ERROR.matched(5);
                var charsAfter = 'characters ' + (Std.parseInt(RE_HAXE_ERROR.matched(4)) + 1) + '-' + (Std.parseInt(RE_HAXE_ERROR.matched(5)) + 1);
                input = input.replace(charsBefore, charsAfter);
            }
            input = input.replace(relativePath, newPath);
            if (context.colors) {
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
            if (context.colors) {
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
        else if (context.colors && input.startsWith('Error : ')) {
            input = input.red();
        }
        else if (context.colors && input.startsWith('Called from hxcpp::')) {
            input = input.red();
        }

        return input;

    } //formatLineOutput

    public static function ensureCeramicProject(cwd:String, args:Array<String>, kind:ProjectKind):Void {

        switch (kind) {
            case App:
                var project = new Project();
                project.loadAppFile(Path.join([cwd, 'ceramic.yml']));

            case Plugin(pluginKinds):
                var project = new Project();
                project.loadPluginFile(Path.join([cwd, 'ceramic.yml']));
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

    public static function isElectron():Bool {

        return js.Node.process.versions['electron'] != null;

    } //isElectron

    public static function isElectronProxy():Bool {

        return js.Node.global.isElectronProxy != null;

    } //isElectronProxy

} //Helpers
