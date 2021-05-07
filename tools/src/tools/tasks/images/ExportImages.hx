package tools.tasks.images;

import tools.Helpers.*;
import tools.Images;
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.DynamicAccess;

import npm.Glob;

using tools.Colors;

typedef ExportImagesInfo = {

    var from:String;

    @:optional var prefix:String;

    @:optional var scale:DynamicAccess<Float>;

}

class ExportImages extends tools.Task {

    override public function info(cwd:String):String {

        return "Export images from a directory to usable assets.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        if (project.app.images == null || !Std.isOfType(project.app.images.export, Array)) {
            fail('Missing images export option in ceramic.yml file like:

    images:
        export:
            - from: path/to/images/dummy/*.png
              prefix: DUMMY_
              scale:
                  1x: 0.2
                  2x: 0.4
');
        }

        var exportList:Array<ExportImagesInfo> = project.app.images.export;
        for (item in exportList) {

            var from = item.from;
            var prefix = '';
            if (item.prefix != null) prefix = item.prefix;

            var scales:DynamicAccess<Float> = {};
            if (item.scale == null) {
                scales.set('1x', 1.0);
            }
            else {
                scales = item.scale;
            }

            for (srcPath in Glob.sync(Path.join([cwd, from]))) {

                var srcName = Path.withoutExtension(Path.withoutDirectory(srcPath));
                var rawData = Images.getRaw(srcPath);

                for (suffix in scales.keys()) {
                    var scale = scales.get(suffix);
                    var targetWidth:Int = Std.int(Math.round(rawData.width * scale));
                    var targetHeight:Int = Std.int(Math.round(rawData.height * scale));

                    var targetName = prefix + srcName + '@' + suffix + '.png';
                    var targetPath = Path.join([cwd, 'assets', targetName]);

                    print('Export $targetName ($targetWidth x $targetHeight)');

                    Images.resize(srcPath, targetPath, targetWidth, targetHeight);
                }

            }

        }
        

    }

}
