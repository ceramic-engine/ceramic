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

    var fromBuild:Bool;

/// Lifecycle

    public function new(target:tools.BuildTarget, fromBuild:Bool) {

        super();

        this.target = target;
        this.fromBuild = fromBuild;

    } //new

    override function run(cwd:String, args:Array<String>):Void {

        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var backendName = 'luxe';
        var ceramicPath = settings.ceramicPath;

        var outPath = Path.join([cwd, 'out']);
        var targetPath = Path.join([outPath, backendName, target.name]);
        var flowPath = Path.join([targetPath, 'project.flow']);
        var overwrite = args.indexOf('--overwrite') != -1;
        var updateSetup = args.indexOf('--update') != -1;

        // Compute relative ceramicPath
        var ceramicPathRelative = getRelativePath(ceramicPath, targetPath);

        // If ceramic.yml has changed, force setup update
        if (!overwrite && updateSetup && !Files.haveSameLastModified(projectPath, flowPath)) {
            overwrite = true;
        }

        if (FileSystem.exists(targetPath)) {
            if (!overwrite) {
                if (fromBuild) {
                    print('No need to update setup.');
                    return;
                } else {
                    fail('Target path already exists: $targetPath\nUse --overwrite to run setup anyway.');
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
        ' + Json.stringify(Path.join([ceramicPathRelative, 'src'])) + ',
        ' + Json.stringify(Path.join([ceramicPathRelative, 'backends/luxe/src'])) + ',
        ' + Json.stringify('../../../src') + '
      ]
    },

    build : {
      dependencies : {
        ${libs.join(',\n        ')}
      }
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

    } //run

} //Setup
