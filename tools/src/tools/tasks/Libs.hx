package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;
using tools.Colors;

class Libs extends tools.Task {

    override public function info(cwd:String):String {

        if (context.backend != null) {
            return "Install required haxe libs when using " + context.backend.name + " backend on current project.";
        } else {
            return "Install required haxe libs on current project.";
        }

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        function g(str:String) {
            return context.colors ? str.gray() : str;
        }

        if (context.backend != null) {

            var availableTargets = backend.getBuildTargets();
            var targetName = getTargetName(args, availableTargets);

            if (targetName == null) {
                fail('You must specify a target.');
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

            if (target == null) {
                fail('Unknown target: $targetName');
            }
        }

        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var libs:Map<String,String> = new Map();
        var appLibs:Array<Dynamic> = project.app.libs;
        for (lib in appLibs) {
            var libName:String = null;
            var libVersion:String = null;
            if (Std.is(lib, String)) {
                libName = lib;
            } else {
                for (k in Reflect.fields(lib)) {
                    libName = k;
                    libVersion = Reflect.field(lib, k);
                    break;
                }
            }
            libs.set(libName, libVersion);
        }

        for (libName in libs.keys()) {
            var libVersion = libs.get(libName);
            
            var isGit = false;
            var isPath = false;
            if (libVersion != null) {
                if (libVersion.startsWith('git:')) {
                    isGit = true;
                }
                else if (libVersion.startsWith('path:')) {
                    isPath = true;
                }
            }
            // Check if library is installed
            var query = libName;
            if (libVersion != null && !isPath && !isGit) query += ':' + libVersion;
            var res = haxelib(['path', query], { mute: true, cwd: cwd });
            var path = (''+res.stdout).trim().split("\r").join("").split("\n")[0].trim();

            // Library exists
            if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                if (libVersion != null) {
                    success('Use $libName $libVersion ' + g(path));
                } else {
                    success('Use $libName ' + g(path));
                }
            }
            else {
                // Library doesn't exist, install it
                if (isPath) {
                    var devArg = [libName, libVersion.substring('path:'.length)];
                    res = haxelib(['dev'].concat(devArg), { cwd: cwd });
                }
                else if (isGit) {
                    var gitArgs = [libName, libVersion.substring('git:'.length).replace('#', ' ')];
                    res = haxelib(['git'].concat(gitArgs), { cwd: cwd });
                }
                else {
                    var installArgs = [libName];
                    if (libVersion != null) installArgs.push(libVersion);
                    res = haxelib(['install'].concat(installArgs), { cwd: cwd });
                }
    
                // Check again
                query = libName;
                if (libVersion != null && !isGit && !isPath) query += ':' + libVersion;
                res = haxelib(['path', query], { mute: true, cwd: cwd });
                path = (''+res.stdout).trim().split("\r").join("").split("\n")[0].trim();
                if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
                    // Now installed \o/
                    if (libVersion != null) {
                        success('Installed $libName $libVersion ' + g(path));
                    } else {
                        success('Installed $libName ' + g(path));
                    }
                }
                else {
                    // Still failed
                    if (libVersion != null) {
                        fail('Failed to install $libName $libVersion');
                    } else {
                        fail('Failed to install $libName');
                    }
                }
            }
            
        }

    }

}
