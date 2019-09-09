package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
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

    } //new

    override function run(cwd:String, args:Array<String>):Void {

        // TODO tidy! (we'll do that once we removed flow usage completely)

        var updateFramework = args.indexOf('--update-framework') != -1;
        checkFrameworkSetup(updateFramework);

        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var backendName = 'luxe';
        var ceramicPath = context.ceramicToolsPath;

        var outPath = Path.join([cwd, 'out']);
        var targetPath = Path.join([outPath, backendName, target.name + (variant != 'standard' ? '-' + variant : '')]);
        var flowPath = Path.join([targetPath, 'project.flow']);
        var hxmlPath = Path.join([targetPath, 'project.hxml']);
        var force = args.indexOf('--force') != -1;
        //var updateProject = args.indexOf('--update-project') != -1;

        // Compute relative ceramicPath
        var runtimePath = Path.normalize(Path.join([ceramicPath, '../runtime']));
        var runtimePathRelative = getRelativePath(runtimePath, targetPath);
        var backendRuntimePath = Path.normalize(Path.join([context.plugin.path, 'runtime']));
        var backendRuntimePathRelative = getRelativePath(backendRuntimePath, targetPath);

        // If ceramic.yml has changed, force setup update
        //if (!force && updateProject && !Files.haveSameLastModified(projectPath, flowPath)) {

            // For now, always update setup to prevent out of sync files
            // This could be improved later but is not critical
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

        var libsFlow = ['"luxe": "*"'];
        var libsHxml = ['-lib luxe'];

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
            libsFlow.push(Json.stringify(libName) + ': ' + Json.stringify(libVersion));
            if (libVersion == '*') {
                libsHxml.push('-lib $libName');
            }
            else {
                libsHxml.push('-lib $libName:$libVersion');
            }
        }

        var haxeflagsFlow = [];
        var haxeflagsHxml = [];

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
                                haxeflagsFlow.push(Json.stringify(flagParts.join(' ')));
                                haxeflagsHxml.push(flagParts.join(' '));
                            }
                            flagParts = [flag];
                        }
                    }
                }
                if (flagParts.length > 0) {
                    haxeflagsFlow.push(Json.stringify(flagParts.join(' ')));
                    haxeflagsHxml.push(flagParts.join(' '));
                }
            }
        }

        for (key in Reflect.fields(project.app.defines)) {
            var val = Reflect.field(project.app.defines, key);
            if (val == true) {
                haxeflagsFlow.push(Json.stringify('-D $key'));
                haxeflagsHxml.push('-D $key');
            } else {
                haxeflagsFlow.push(Json.stringify('-D $key=$val'));
                haxeflagsHxml.push('-D $key=$val');
            }
        }

        // Disable luxe debug console
        haxeflagsFlow.push(Json.stringify('-D luxe_noprofile'));
        haxeflagsFlow.push(Json.stringify('-D luxe_no_main'));
        haxeflagsFlow.push(Json.stringify('-D no_debug_console'));

        haxeflagsHxml.push('-D luxe_noprofile');
        haxeflagsHxml.push('-D luxe_no_main');
        haxeflagsHxml.push('-D no_debug_console');

        var classPathsFlow = '';
        var classPathsHxml = '';
        for (entry in (project.app.paths:Array<String>)) {
            if (Path.isAbsolute(entry)) {
                var relativePath = getRelativePath(entry, targetPath);
                classPathsFlow += Json.stringify(relativePath) + ',\n        ';
                classPathsHxml += '-cp ' + relativePath + '\n';
            }
            else {
                var relativePath = getRelativePath(Path.join([cwd, entry]), targetPath);
                classPathsFlow += Json.stringify(relativePath) + ',\n        ';
                classPathsHxml += '-cp ' + relativePath + '\n';
            }
        }

        var hooks = '';
        var hookPre = null;

        var targetFlags:String;
        if (target.name == 'web') {
            targetFlags = '-js ${Path.join([cwd, 'project', 'web', project.app.name + '.js'])}';
            targetFlags += '\n' + '-D target-js';
            targetFlags += '\n' + '-D arch-web';
            targetFlags += '\n' + '-D luxe_web';
            targetFlags += '\n' + '-D snow_web';
            targetFlags += '\n' + '--macro snow.Set.assets("snow.core.web.assets.Assets")';
            targetFlags += '\n' + '--macro snow.Set.audio("snow.modules.webaudio.Audio")';
            targetFlags += '\n' + '--macro snow.Set.runtime("snow.core.web.Runtime")';
            targetFlags += '\n' + '--macro snow.Set.io("snow.core.web.io.IO")';
        }
        else {
            targetFlags = '-cpp cpp';
            targetFlags += '\n' + '-lib hxcpp';
            targetFlags += '\n' + '-D target-cpp';
            targetFlags += '\n' + '-D hxcpp_static_std';
            targetFlags += '\n' + '-D luxe_native';
            targetFlags += '\n' + '-D snow_native';
            if (target.name == 'ios' || target.name == 'android') {
                targetFlags += '\n' + '-D linc_opengl_GLES';
            }
            targetFlags += '\n' + '--macro snow.Set.assets("snow.core.native.assets.Assets")';
            targetFlags += '\n' + '--macro snow.Set.runtime("snow.modules.sdl.Runtime")';
            targetFlags += '\n' + '--macro snow.Set.audio("snow.modules.openal.Audio")';
            targetFlags += '\n' + '--macro snow.Set.io("snow.modules.sdl.IO")';
            if (target.name == 'mac' || target.name == 'windows' || target.name == 'linux') {
                targetFlags += '\n' + '-D arch-64';
                targetFlags += '\n' + '-D desktop';
            }
        }

        var hxmlFileContent = ('
-main Main
$targetFlags
-D ${target.name}
-D snow_no_main
-D no_default_font
--macro snow.Set.main("luxe.Engine")
--macro snow.Set.ident(' + Json.stringify(project.app.name) + ')
--macro snow.Set.config("config.json")
' + classPathsHxml + '-cp ' + Path.join([runtimePathRelative, 'src']) + '
-cp ' + Path.join([backendRuntimePathRelative, 'src']) + '
-cp ' + '../../../src' + '
${libsHxml.join('\n')}
-lib linc_opengl
-lib linc_sdl
-lib linc_ogg
-lib linc_stb
-lib linc_timestamp
-lib linc_openal
-lib snow
-lib luxe
${haxeflagsHxml.join('\n')}
').ltrim();
    
        var flowFileContent = ('
{

  project: {
    name: ' + Json.stringify(project.app.name) + ',
    version: ' + Json.stringify(project.app.version) + ',
    author: ' + Json.stringify(project.app.author) + ',

    app: {
      name: ' + Json.stringify(project.app.name) + ',
      package: ' + Json.stringify(Reflect.field(project.app, 'package')) + ',
      codepaths: [
        ' + classPathsFlow + Json.stringify(Path.join([runtimePathRelative, 'src'])) + ',
        ' + Json.stringify(Path.join([backendRuntimePathRelative, 'src'])) + ',
        ' + Json.stringify('../../../src') + '
      ],
      icon: "icons => app"
    },

    build : {
      dependencies : {
        ${libsFlow.join(',\n        ')}
      },
      flags: [
        ${haxeflagsFlow.join(',\n        ')}
      ]$hooks
    },

    files : {
      assets : \'assets/\'
    }

  }

}
').ltrim();

        // Save hxml file
        File.saveContent(hxmlPath, hxmlFileContent); // TODO just testing
        Files.setToSameLastModified(projectPath, hxmlPath);
        print('Updated luxe hxml at: $hxmlPath');

        // Save flow file
        //File.saveContent(flowPath, flowFileContent);
        //Files.setToSameLastModified(projectPath, flowPath);
        //print('Updated luxe project at: $flowPath');

        // Create pre-hook if any
        /*if (hookPre != null) {
            var hookPrePath = Path.join([Path.directory(flowPath), 'hooks/pre.js']);
            if (!FileSystem.exists(Path.directory(hookPrePath))) {
                FileSystem.createDirectory(Path.directory(hookPrePath));
            }
            File.saveContent(hookPrePath, hookPre);
        }*/

        var availableTargets = context.backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);
        if (targetName == 'default') targetName = 'web';

        // Generate files with flow
        //haxelib(['run', 'flow', 'files', targetName], { cwd: targetPath });

        // Run initial project setup if needed
        runInitialProjectSetupIfNeeded(cwd, args);

    } //run

    function runInitialProjectSetupIfNeeded(cwd:String, args:Array<String>):Void {

        if (FileSystem.exists(Path.join([cwd, 'completion.hxml']))) {
            return; // Project seems ready
        }

        // Default to web target
        runCeramic(cwd, ['luxe', 'libs', 'web']);
        runCeramic(cwd, ['luxe', 'build', 'web', '--assets', '--hxml-output', 'completion.hxml']);

    } //runInitialProjectSetupIfNeeded

    function checkFrameworkSetup(forceSetup:Bool = false):Void {
        
        // Almost the same thing as backend.runInstall()

        var output = ''+haxelib(['list'], { mute: true }).stdout;
        var libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        if (libs.exists('luxe') && !forceSetup) {
            // Luxe already available
            return;
        }

        /*// Install luxe (and dependencies)
        //
        print('Install luxe\u2026');

        if (!libs.exists('snowfall')) {
            if (haxelib(['install', 'snowfall']).status != 0) {
                fail('Error when trying to install snowfall.');
            }
        }

        haxelib(['run', 'snowfall', 'update', 'luxe']);*/

        for (lib in ['flow', 'snow', 'luxe', 'linc_ogg', 'linc_openal', 'linc_opengl', 'linc_sdl', 'linc_stb', 'linc_timestamp']) {
            haxelib(['dev', lib, Path.join([context.ceramicGitDepsPath, lib])]);
        }

        // Check that luxe is now available
        //
        output = ''+haxelib(['list'], { mute: true }).stdout;
        libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        if (!libs.exists('luxe')) {
            // Luxe still not available?
            fail('Failed to install luxe or some of its dependency. Check log.');
        }

    } //checkFrameworkSetup

} //Setup
