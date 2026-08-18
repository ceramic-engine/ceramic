package tools.tasks.imgui;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

/**
 * Copies the prebuilt dcimgui wasm module (emscripten single-file js) into
 * the ceramic project's web directory, where the imgui plugin loads it at
 * startup on the web target.
 */
class SetupJS extends tools.Task {

    override public function info(cwd:String):String {

        return "Copy the dcimgui wasm module into this ceramic project (web target).";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var doRemove = extractArgFlag(args, 'remove');

        // With --if-exists (used by the automatic build hook), silently skip
        // when there is no web export (e.g. a clay mac/ios build).
        var ifExists = extractArgFlag(args, 'if-exists');

        var webProjectPath = Path.join([cwd, 'project/web']);
        var moduleSource = Path.join([context.ceramicGitDepsPath, 'imgui-hx/lib/prebuilt/web/dcimgui.js']);

        if (!FileSystem.exists(webProjectPath)) {
            if (doRemove || ifExists) {
                return;
            }
            FileSystem.createDirectory(webProjectPath);
        }

        var dest = Path.join([webProjectPath, 'dcimgui.js']);
        if (doRemove) {
            if (FileSystem.exists(dest)) {
                FileSystem.deleteFile(dest);
            }
        }
        else {
            if (!Files.haveSameLastModified(moduleSource, dest)) {
                success('Copy dcimgui.js');
                File.copy(moduleSource, dest);
                Files.setToSameLastModified(moduleSource, dest);
            }
        }

    }

}
