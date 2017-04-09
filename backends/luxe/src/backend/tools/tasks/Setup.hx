package backend.tools.tasks;

import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import tools.Tools.*;

using StringTools;

class Setup extends tools.Task {

/// Properties

    var target:tools.BuildTarget;

/// Lifecycle

    public function new(target:tools.BuildTarget) {

        super();

        this.target = target;

    } //new

    override function run(cwd:String, args:Array<String>):Void {

        var project = new tools.Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var backendName = 'luxe';
        var ceramicPath = settings.ceramicPath;

        var outPath = Path.join([cwd, 'out']);
        var targetPath = Path.join([outPath, backendName, target.name]);
        var overwrite = args.indexOf('--overwrite') != -1;

        if (FileSystem.exists(targetPath)) {
            if (!overwrite) {
                fail('Target path already exists: $targetPath\nUse --overwrite to run setup anyway.');
            }
        }
        else {
            try {
                FileSystem.createDirectory(targetPath);
            } catch (e:Dynamic) {
                fail('Error when creating directory: ' + e);
            }
        }
    
        var content = '
{

  project: {
    name: ' + Json.stringify(project.app.name) + ',
    version: ' + Json.stringify(project.app.version) + ',
    author: ' + Json.stringify(project.app.author) + ',

    app: {
      name: ' + Json.stringify(project.app.name) + ',
      package: ' + Json.stringify(Reflect.field(project.app, 'package')) + ',
      codepaths: [
        ' + Json.stringify(Path.join([ceramicPath, 'src'])) + ',
        ' + Json.stringify(Path.join([ceramicPath, 'backends/luxe/src'])) + ',
        ' + Json.stringify('../../../src') + '
      ]
    },

    build : {
      dependencies : {
        luxe : \'*\'
      }
    },

    files : {
      assets : \'assets/\'
    }

  }

}
'.ltrim();

        // Save flow file
        var flowPath = Path.join([targetPath, 'project.flow']);
        File.saveContent(flowPath, content);
        print('Updated luxe project at: $flowPath');

    } //run

} //Setup
