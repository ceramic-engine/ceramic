package backend.tools.tasks;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.UnityEditor;

using StringTools;

class UnitySetup extends tools.Task {

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
        var targetPath = target.outPath('unity', cwd, context.debug, variant);
        var hxmlPath = Path.join([targetPath, 'build.hxml']);
        var force = args.indexOf('--force') != -1;
        //var updateProject = args.indexOf('--update-project') != -1;

        var sharedHxml = project.sharedHxml();

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
                libs.push('-lib ' + libName);
            }
            else if (libVersion.startsWith('git:')) {
                libs.push('-lib ' + libName + ':git');
            }
            else {
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

            var val:Dynamic = Reflect.field(project.app.defines, key);
            if (val == true) {
                haxeflags.push('-D $key');
            } else {
                haxeflags.push('-D $key=$val');
            }
        }

        // Use universal render pipeline unless unity_birp (built-in render pileline) is defined
        var hasUnityBirp = (project.app.defines.unity_birp != null);
        var hasUnityUrp = (project.app.defines.unity_urp != null);
        if (!hasUnityBirp && !hasUnityUrp) {
            haxeflags.push('-D unity_urp');
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

        if (sharedHxml != null)
            finalHxml = finalHxml.concat(sharedHxml);

        finalHxml = finalHxml.concat(haxeflags);

        if (target.name == 'unity') {
            finalHxml.push('-cs bin');
            finalHxml.push('-D dll');
            finalHxml.push('-D no-root');
            finalHxml.push('-D ceramic_pending_finish_draw');

            var unityVersion:String = null;
            if (project.app.unity != null &&
                project.app.unity.version != null) {
                unityVersion = '' + project.app.unity.version;
            }

            if (context.defines.exists('ceramic_unity_default_net_std')) {
                // No explicit net-std define, stick to defaults
            }
            else if (Sys.systemName() == 'Mac') {
                var unityEditorPath = UnityEditor.resolveUnityEditorPath(cwd, project, true);
                finalHxml.push('-D net-std=$unityEditorPath/Contents/Mono/lib/mono/unity');
            }
            else if (Sys.systemName() == 'Windows') {
                var unityEditorPath = UnityEditor.resolveUnityEditorPath(cwd, project, true);
                finalHxml.push('-D net-std=$unityEditorPath/Data/MonoBleedingEdge/lib/mono/unity');
            }
            else {
                fail('Building for Unity is not yet supported on system: ' + Sys.systemName());
            }

            finalHxml.push('-D net-ver=20');
            if (variant == 'tasks') {
                finalHxml.push('--macro include("tasks", true)');
            }
        } else {
            finalHxml.push('-cs bin');
        }

        // Save hxml file
        File.saveContent(hxmlPath, finalHxml.join("\n"));
        Files.setToSameLastModified(projectPath, hxmlPath);
        print('Updated unity hxml at: $hxmlPath');

    }

}
