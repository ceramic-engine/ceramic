package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;
using npm.Colors;

class Libs extends tools.Task {

    override public function info(cwd:String):String {

#if use_backend
        return "Install required haxe libs when using " + backend.name + " backend on current project.";
#else
        return "Install required haxe libs on current project.";
#end

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args);

        function g(str:String) {
            return settings.colors ? str.gray() : str;
        }

#if use_backend
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
#end

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
            
            // Check if library is installed
            var query = libName;
            if (libVersion != null) query += ':' + libVersion;
            var res = haxelib(['path', query], { mute: true, cwd: cwd });
            var path = (''+res.stdout).trim().split("\n")[0];

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
                var installArgs = [libName];
                if (libVersion != null) installArgs.push(libVersion);
                res = haxelib(['install'].concat(installArgs), { cwd: cwd });

                // Check again
                query = libName;
                if (libVersion != null) query += ':' + libVersion;
                res = haxelib(['path', query], { mute: true, cwd: cwd });
                path = (''+res.stdout).trim().split("\n")[0];
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

    } //run

} //Libs
