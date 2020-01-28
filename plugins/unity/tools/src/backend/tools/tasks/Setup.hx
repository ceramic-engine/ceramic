package backend.tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;
import tools.Files;

using StringTools;

class Setup extends tools.Task {

/// Properties

    var target:tools.BuildTarget;

    var variant:String;

    var continueOnFail:Bool;

/// Lifecycle

    public function new(target:tools.BuildTarget, variant:String, continueOnFail:Bool) {

        super();

        this.target = target;
        this.variant = variant;
        this.continueOnFail = continueOnFail;

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var backendName = 'unity';
        var ceramicPath = context.ceramicToolsPath;

        var outPath = Path.join([cwd, 'out']);
        var targetPath = target.outPath('luxe', cwd, context.debug, variant);
        var hxmlPath = Path.join([targetPath, 'build.hxml']);
        var force = args.indexOf('--force') != -1;
        //var updateProject = args.indexOf('--update-project') != -1;

        // Compute relative ceramicPath
        var runtimePath = Path.normalize(Path.join([ceramicPath, '../runtime']));
        var runtimePathRelative = getRelativePath(runtimePath, targetPath);
        var backendRuntimePath = Path.normalize(Path.join([context.plugin.path, 'runtime']));
        var backendRuntimePathRelative = getRelativePath(backendRuntimePath, targetPath);

        // If ceramic.yml has changed, force setup update
        //if (!force && updateProject && !Files.haveSameLastModified(projectPath, hxmlPath)) {
            force = true;
        //}

        if (FileSystem.exists(targetPath)) {
            if (!force) {
                if (continueOnFail) {
                    print('No need to update setup.');
                    return;
                } else {
                    fail('Target path already exists: $targetPath\nUse --force to run setup anyway.');
                }
            }
        }
        else {
            try {
                FileSystem.createDirectory(targetPath);
            } catch (e:Dynamic) {
                fail('Error when creating directory: ' + e);
            }
        }

        var libs = [];

        if (target.name == 'unity') {
            //libs.push('-lib hxcs');
        }

        var appLibs:Array<Dynamic> = project.app.libs;
        for (lib in appLibs) {
            var libName:String = null;
            var libVersion:String = "*";
            if (Std.is(lib, String)) {
                libName = lib;
            } else {
                for (k in Reflect.fields(lib)) {
                    libName = k;
                    libVersion = Reflect.field(lib, k);
                    break;
                }
            }
            if (libVersion.trim() == '' || libVersion == '*') {
                libs.push('-lib ' + libName);
            } else {
                libs.push('-lib ' + libName + ':' + libVersion);
            }
        }

        var haxeflags = [];

        if (project.app.hxml != null) {
            var parsedHxml = tools.Hxml.parse(project.app.hxml);
            if (parsedHxml != null && parsedHxml.length > 0) {
                parsedHxml = tools.Hxml.formatAndChangeRelativeDir(parsedHxml, cwd, targetPath);
                var flagParts = [];
                for (flag in parsedHxml) {
                    flag = flag.trim();
                    if (flag != '') {
                        if (!flag.startsWith('-')) {
                            flagParts.push(flag);
                        }
                        else {
                            if (flagParts.length > 0) {
                                haxeflags.push(flagParts.join(' '));
                            }
                            flagParts = [flag];
                        }
                    }
                }
                if (flagParts.length > 0) {
                    haxeflags.push(flagParts.join(' '));
                }
            }
        }

        for (key in Reflect.fields(project.app.defines)) {
            var val = Reflect.field(project.app.defines, key);
            if (val == true) {
                haxeflags.push('-D $key');
            } else {
                haxeflags.push('-D $key=$val');
            }
        }

        var classPaths = [];
        for (entry in (project.app.paths:Array<String>)) {
            if (Path.isAbsolute(entry)) {
                var relativePath = getRelativePath(entry, targetPath);
                classPaths.push('-cp ' + relativePath);
            }
            else {
                var relativePath = getRelativePath(Path.join([cwd, entry]), targetPath);
                classPaths.push('-cp ' + relativePath);
            }
        }
    
        var finalHxml = [];

        finalHxml.push('-main Main');
        finalHxml.push('-cp ../../../src');
        finalHxml.push('-cp ' + Path.join([runtimePathRelative, 'src']));
        finalHxml.push('-cp ' + Path.join([backendRuntimePathRelative, 'src']));
        finalHxml = finalHxml.concat(classPaths);
        finalHxml = finalHxml.concat(libs);
        finalHxml = finalHxml.concat(haxeflags);

        if (target.name == 'unity') {
            finalHxml.push('-cs bin');
            finalHxml.push('-D dll');
            finalHxml.push('-D no-root');
            
            if (Sys.systemName() == 'Mac') {
                finalHxml.push('-D csharp-compiler=/Applications/Unity/Unity.app/Contents/Mono/bin/gmcs');
                finalHxml.push('-D net-std=/Applications/Unity/Unity.app/Contents/Mono/lib/mono/unity');
                finalHxml.push('-net-lib=/Applications/Unity/Unity.app/Contents/Managed/UnityEngine.dll');
                //finalHxml.push('-net-lib=/Applications/Unity/Unity.app/Contents/Managed/UnityEditor.dll');
            }
            // TODO windows
            // TODO handle custom Unity path

            finalHxml.push('-D net-ver=20');
            finalHxml.push('-D erase-generics');
            //finalHxml.push('--macro allowPackage("sys")');
            if (variant == 'scripts') {
                finalHxml.push('--macro include("scripts", true)');
            }
        } else {
            finalHxml.push('-cpp bin');
        }

        // Save hxml file
        File.saveContent(hxmlPath, finalHxml.join("\n"));
        Files.setToSameLastModified(projectPath, hxmlPath);
        print('Updated unity project at: $hxmlPath');

    }

}
