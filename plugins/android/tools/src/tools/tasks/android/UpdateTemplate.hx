package tools.tasks.android;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class UpdateTemplate extends tools.Task {

    override public function info(cwd:String):String {

        return "Update template (SDL files)";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        // Copy SDL files
        final gitSDLJavaFilesPath = Path.join([context.ceramicGitDepsPath, 'SDL/android-project/app/src/main/java/org/libsdl/app']);
        final tplSDLJavaFilesPath = Path.join([context.plugins.get('android').path, 'tpl/project/android-clay/app/src/main/java/org/libsdl/app']);
        Files.copyDirectory(
            gitSDLJavaFilesPath,
            tplSDLJavaFilesPath,
            true
        );

        // Apply patches
        patch([
            Path.join([tplSDLJavaFilesPath, 'SDLActivity.java']),
            Path.join([context.plugins.get('android').path, 'resources/SDLActivity.patch'])
        ]);

    }

}
