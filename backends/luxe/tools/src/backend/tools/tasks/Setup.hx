package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import tools.Tools.*;
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
        var ceramicPath = settings.ceramicPath;

        var outPath = Path.join([cwd, 'out']);
        var targetPath = Path.join([outPath, backendName, target.name + (variant != 'standard' ? '-' + variant : '')]);
        var flowPath = Path.join([targetPath, 'project.flow']);
        var force = args.indexOf('--force') != -1;
        var updateProject = args.indexOf('--update-project') != -1;

        // Compute relative ceramicPath
        var ceramicPathRelative = getRelativePath(ceramicPath, targetPath);

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
                classPaths += Json.stringify(entry) + ',\n        ';
            }
            else {
                var relativePath = getRelativePath(Path.join([cwd, entry]), targetPath);
                classPaths += Json.stringify(relativePath) + ',\n        ';
            }
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
        ' + classPaths + Json.stringify(Path.join([ceramicPathRelative, 'src'])) + ',
        ' + Json.stringify(Path.join([ceramicPathRelative, 'backends/luxe/src'])) + ',
        ' + Json.stringify('../../../src') + '
      ]
    },

    build : {
      dependencies : {
        ${libs.join(',\n        ')}
      },
      flags: [
        ${haxeflags.join(',\n        ')}
      ]
    },

    files : {
      assets : \'assets/\'
    }

  }

}
').ltrim();

        // Save flow file
        File.saveContent(flowPath, content);
        Files.setToSameLastModified(projectPath, flowPath);
        print('Updated luxe project at: $flowPath');

        // Generate files with flow
        command('haxelib', ['run', 'flow', 'files'], { cwd: flowPath });

    } //run

    function checkFrameworkSetup(forceSetup:Bool = false):Void {
        
        // Almost the same thing as backend.runInstall()

        var output = ''+command('haxelib', ['list'], { mute: true }).stdout;
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
            if (command('haxelib', ['install', 'snowfall']).status != 0) {
                fail('Error when trying to install snowfall.');
            }
        }

        command('haxelib', ['run', 'snowfall', 'update', 'luxe']);

        // Check that luxe is now available
        //
        output = ''+command('haxelib', ['list'], { mute: true }).stdout;
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
