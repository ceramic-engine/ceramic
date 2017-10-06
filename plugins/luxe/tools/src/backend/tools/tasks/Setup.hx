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
        var force = args.indexOf('--force') != -1;
        var updateProject = args.indexOf('--update-project') != -1;

        // Compute relative ceramicPath
        var runtimePath = Path.normalize(Path.join([ceramicPath, '../runtime']));
        var runtimePathRelative = getRelativePath(runtimePath, targetPath);
        var backendRuntimePath = Path.normalize(Path.join([context.plugin.path, 'runtime']));
        var backendRuntimePathRelative = getRelativePath(backendRuntimePath, targetPath);

        // If ceramic.yml has changed, force setup update
        if (!force && updateProject && !Files.haveSameLastModified(projectPath, flowPath)) {
            force = true;
        }

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

        var libs = ['"luxe": "*"'];

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
            libs.push(Json.stringify(libName) + ': ' + Json.stringify(libVersion));
        }

        var haxeflags = [];

        if (project.app.hxml != null) {
            var parsedHxml = tools.Hxml.parse(project.app.hxml);
            if (parsedHxml != null && parsedHxml.length > 0) {
                parsedHxml = tools.Hxml.formatAndchangeRelativeDir(parsedHxml, cwd, targetPath);
                for (flag in parsedHxml) {
                    haxeflags.push(Json.stringify(flag));
                }
            }
        }

        for (key in Reflect.fields(project.app.defines)) {
            var val = Reflect.field(project.app.defines, key);
            if (val == true) {
                haxeflags.push(Json.stringify('-D $key'));
            } else {
                haxeflags.push(Json.stringify('-D $key=$val'));
            }
        }

        var classPaths = '';
        for (entry in (project.app.paths:Array<String>)) {
            if (Path.isAbsolute(entry)) {
                var relativePath = getRelativePath(entry, targetPath);
                classPaths += Json.stringify(relativePath) + ',\n        ';
            }
            else {
                var relativePath = getRelativePath(Path.join([cwd, entry]), targetPath);
                classPaths += Json.stringify(relativePath) + ',\n        ';
            }
        }

        var customIndex = '';
        /*if (target.name == 'web') {
            customIndex = ",
      index : { path:'custom_index.html => index.html', template:'project', not_listed:true }";
        }*/

        var hooks = '';
        var hookPre = null;

        if (target.name == 'ios') {
            hookPre = "
exports.hook = function(flow, done) 
{
    // Don't compile Haxe/C++ if no archs are specified explicitly
    if (process.argv.indexOf('--archs') == -1) {
        done(null, true);
    }
    done(null, false);
}
";

        hooks += ",
      pre: {
        priority: 1,
        name: 'ceramic-pre',
        desc: 'run ceramic pre build',
        script: './hooks/pre.js'
      }";
        }
    
        var content = ('
{

  project: {
    name: ' + Json.stringify(project.app.name) + ',
    version: ' + Json.stringify(project.app.version) + ',
    author: ' + Json.stringify(project.app.author) + ',

    app: {
      name: ' + Json.stringify(project.app.name) + ',
      package: ' + Json.stringify(Reflect.field(project.app, 'package')) + ',
      codepaths: [
        ' + classPaths + Json.stringify(Path.join([runtimePathRelative, 'src'])) + ',
        ' + Json.stringify(Path.join([backendRuntimePathRelative, 'src'])) + ',
        ' + Json.stringify('../../../src') + '
      ],
      icon: "icons => app"
    },

    build : {
      dependencies : {
        ${libs.join(',\n        ')}
      },
      flags: [
        ${haxeflags.join(',\n        ')}
      ]$hooks
    },

    files : {
      assets : \'assets/\'$customIndex
    }

  }

}
').ltrim();

        // Save flow file
        File.saveContent(flowPath, content);
        Files.setToSameLastModified(projectPath, flowPath);
        print('Updated luxe project at: $flowPath');

        // Create pre-hook if any
        if (hookPre != null) {
            var hookPrePath = Path.join([Path.directory(flowPath), 'hooks/pre.js']);
            if (!FileSystem.exists(Path.directory(hookPrePath))) {
                FileSystem.createDirectory(Path.directory(hookPrePath));
            }
            File.saveContent(hookPrePath, hookPre);
        }

        // Generate files with flow
        haxelib(['run', 'flow', 'files'], { cwd: targetPath });

    } //run

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

        // Install luxe (and dependencies)
        //
        print('Install luxe\u2026');

        if (!libs.exists('snowfall')) {
            if (haxelib(['install', 'snowfall']).status != 0) {
                fail('Error when trying to install snowfall.');
            }
        }

        haxelib(['run', 'snowfall', 'update', 'luxe']);

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
