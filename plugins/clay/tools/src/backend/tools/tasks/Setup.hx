package backend.tools.tasks;

import haxe.Json;
import haxe.ds.ReadOnlyArray;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;

using StringTools;

class Setup extends tools.Task {

    public static var requiredLibs(get,never):ReadOnlyArray<String>;
    static function get_requiredLibs():ReadOnlyArray<String> {
        var _requiredLibs:Array<String> = ['clay', 'linc_ogg', 'linc_opengl', 'linc_sdl', 'linc_stb', 'linc_timestamp'];
        if (context.defines.exists('ceramic_use_openal')) {
            _requiredLibs.push('linc_openal');
        }
        else {
            _requiredLibs.push('linc_soloud');
        }
        return cast _requiredLibs;
    }

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

        var updateFramework = args.indexOf('--update-framework') != -1;
        checkFrameworkSetup(updateFramework, cwd);

        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var backendName = 'clay';
        var ceramicPath = context.ceramicToolsPath;

        var sharedHxml = project.sharedHxml();

        var outPath = Path.join([cwd, 'out']);
        var targetPath = target.outPath(backendName, cwd, context.debug, variant);
        var hxmlPath = Path.join([targetPath, 'project.hxml']);
        var force = args.indexOf('--force') != -1;

        // Compute relative ceramicPath
        var runtimePath = Path.normalize(Path.join([ceramicPath, '../runtime']));
        var runtimePathRelative = getRelativePath(runtimePath, targetPath);
        var backendRuntimePath = Path.normalize(Path.join([context.plugin.path, 'runtime']));
        var backendRuntimePathRelative = getRelativePath(backendRuntimePath, targetPath);

        // If ceramic.yml has changed, force setup update
        //if (!force && updateProject && !Files.haveSameLastModified(projectPath, hxmlPath)) {

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

        var libsHxml = [];

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
                libsHxml.push('-lib $libName');
            }
            else if (libVersion.startsWith('git:')) {
                libsHxml.push('-lib ' + libName + ':git');
            }
            else {
                libsHxml.push('-lib $libName:$libVersion');
            }
        }

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
                                haxeflagsHxml.push(flagParts.join(' '));
                            }
                            flagParts = [flag];
                        }
                    }
                }
                if (flagParts.length > 0) {
                    haxeflagsHxml.push(flagParts.join(' '));
                }
            }
        }

        if (project.app.defines.ceramic_use_electron) {
            haxeflagsHxml.push('-D clay_web_use_electron_fs');
            haxeflagsHxml.push('-D clay_web_use_electron_pngjs');
        }

        for (key in Reflect.fields(project.app.defines)) {
            var val = Reflect.field(project.app.defines, key);
            if (val == true) {
                haxeflagsHxml.push('-D $key');
            } else {
                haxeflagsHxml.push('-D $key=$val');
            }
        }

        var classPathsHxml = '';
        for (entry in (project.app.paths:Array<String>)) {
            if (Path.isAbsolute(entry)) {
                var relativePath = getRelativePath(entry, targetPath);
                classPathsHxml += '-cp ' + relativePath + '\n';
            }
            else {
                var relativePath = getRelativePath(Path.join([cwd, entry]), targetPath);
                classPathsHxml += '-cp ' + relativePath + '\n';
            }
        }

        var targetFlags:String;
        if (target.name == 'web') {
            targetFlags = '-js ${Path.join([cwd, 'project', 'web', project.app.name + '.js'])}';
            targetFlags += '\n' + '-D clay_web';
            targetFlags += '\n' + '-D ceramic_soft_inline';
            targetFlags += '\n' + '-D ceramic_shader_vert_frag';
            targetFlags += '\n' + '-D ceramic_auto_block_default_scroll';
            targetFlags += '\n' + '-D clay_webgl_unpack_premultiply_alpha';
        }
        else {
            if (target.name == 'cppia') {
                targetFlags = '-cppia app.cppia';
            }
            else {
                targetFlags = '-cpp cpp';
            }
            targetFlags += '\n' + '-lib hxcpp';
            targetFlags += '\n' + '-lib linc_opengl';
            targetFlags += '\n' + '-lib linc_sdl';
            targetFlags += '\n' + '-lib linc_ogg';
            targetFlags += '\n' + '-lib linc_stb';
            targetFlags += '\n' + '-lib linc_timestamp';
            if (context.defines.exists('ceramic_use_openal')) {
                targetFlags += '\n' + '-D clay_openal';
                targetFlags += '\n' + '-lib linc_openal';
            }
            else {
                targetFlags += '\n' + '-D clay_soloud';
                targetFlags += '\n' + '-lib linc_soloud';
            }
            targetFlags += '\n' + '-D hxcpp_static_std';
            targetFlags += '\n' + '-D clay_native';
            targetFlags += '\n' + '-D clay_sdl';
            if (target.name == 'ios') {
                // openal manual init
            }
            if (target.name == 'ios' || target.name == 'android') {
                targetFlags += '\n' + '-D linc_opengl_GLES';
            }
            if (target.name == 'android') {
                // On android, we ran into a shader bug when using "last" texture slot available
                targetFlags += '\n' + '-D ceramic_avoid_last_texture_slot';
            }
            if (target.name == 'mac' || target.name == 'windows' || target.name == 'linux') {
                targetFlags += '\n' + '-D clay_use_glew';
            }
            if (target.name == 'windows' && !context.defines.exists('ceramic_no_clay_gl_finish')) {
                targetFlags += '\n' + '-D clay_gl_finish';
            }
            targetFlags += '\n' + '-D ceramic_shader_vert_frag';
        }

        var hxmlFileContent = ('
-main ${target.name == 'cppia' ? 'CPPIAMain' : 'backend.Main'}
$targetFlags
-D ${target.name}
-D no-console
' + classPathsHxml + '-cp ' + Path.join([runtimePathRelative, 'src']) + '
-cp ' + Path.join([backendRuntimePathRelative, 'src']) + '
-cp ' + '../../../src' + '${sharedHxml != null && sharedHxml.length > 0 ? '\n' + sharedHxml.join('\n') : ''}
${libsHxml.join('\n')}
-lib clay
-D clay_app_id=' + Json.stringify(project.app.name) + '
${haxeflagsHxml.join('\n')}
').ltrim();

        // Save hxml file
        File.saveContent(hxmlPath, hxmlFileContent);
        Files.setToSameLastModified(projectPath, hxmlPath);

        print('Updated clay hxml at: $hxmlPath');

        var availableTargets = context.backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);
        if (targetName == 'default') targetName = 'web';

        // Run initial project setup if needed
        runInitialProjectSetupIfNeeded(cwd, args, targetPath);

    }

    function runInitialProjectSetupIfNeeded(cwd:String, args:Array<String>, targetPath:String):Void {

        var projectHxmlPath = Path.join([targetPath, 'project.hxml']);

        if (FileSystem.exists(projectHxmlPath)) {
            return; // Project seems ready
        }

        var extraArgs = [];
        if (context.debug) {
            extraArgs.push('--debug');
        }
        if (context.variant != null) {
            extraArgs.push('--variant');
            extraArgs.push(context.variant);
        }

        // Default to web target
        runCeramic(cwd, ['clay', 'libs', 'web']);
        runCeramic(cwd, ['clay', 'build', 'web', '--assets'].concat(extraArgs));

    }

    function checkFrameworkSetup(forceSetup:Bool = false, cwd:String):Void {

        // Almost the same thing as backend.runUpdate()

        var output = ''+haxelib(['list'], { mute: true }).stdout;
        var libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        var allLibsInstalled = true;
        if (!forceSetup) {
            for (lib in requiredLibs) {
                if (!libs.exists(lib)) {
                    allLibsInstalled = false;
                    break;
                }
            }
            if (allLibsInstalled) {
                return;
            }
        }

        for (lib in requiredLibs) {
            ensureHaxelibDevToCeramicGit(lib, cwd);
            libs.set(lib, true);
        }

        // Check that libs are available
        //
        for (lib in requiredLibs) {
            if (!libs.exists(lib)) {
                // Lib not available?
                fail('Failed to update or install $lib. Check log.');
            }
        }

    }

}
