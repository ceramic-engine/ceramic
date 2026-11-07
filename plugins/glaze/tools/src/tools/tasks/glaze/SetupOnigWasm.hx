package tools.tasks.gpui;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

/**
 * Copies vscode-oniguruma's `onig.wasm` and its JavaScript binding
 * (`vscode-oniguruma.js`) from the plugin's `onig-wasm` folder into the
 * ceramic project's web directory, where the code highlighter loads them at
 * startup when the project sets the `gpui_onig_wasm` define. With `--remove`,
 * deletes them from the web directory instead (builds without the define).
 */
class SetupOnigWasm extends tools.Task {

    override public function info(cwd:String):String {

        return "Copy onig.wasm and its JavaScript binding into this ceramic project (web target, gpui_onig_wasm define).";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var doRemove = extractArgFlag(args, 'remove');

        // The files copied into `project/web`, from the plugin's `onig-wasm` folder
        var files = ['onig.wasm', 'vscode-oniguruma.js'];

        var webProjectPath = Path.join([cwd, 'project/web']);

        if (!FileSystem.exists(webProjectPath)) {
            if (doRemove) {
                return;
            }
            FileSystem.createDirectory(webProjectPath);
        }

        if (doRemove) {
            for (name in files) {
                var dest = Path.join([webProjectPath, name]);
                if (FileSystem.exists(dest) && !FileSystem.isDirectory(dest)) {
                    success('Remove $name');
                    FileSystem.deleteFile(dest);
                }
            }
            return;
        }

        var sourcePath = Path.join([pluginPath(), 'onig-wasm']);
        for (name in files) {
            var source = Path.join([sourcePath, name]);
            if (!FileSystem.exists(source)) {
                fail('Missing file: $source');
            }
            var dest = Path.join([webProjectPath, name]);
            if (!Files.haveSameLastModified(source, dest)) {
                success('Copy $name');
                File.copy(source, dest);
                Files.setToSameLastModified(source, dest);
            }
        }

    }

    static function pluginPath():String {

        for (plugin in context.plugins) {
            if (plugin.name == 'Gpui') {
                return plugin.path;
            }
        }
        fail('The gpui plugin is not loaded');
        return null;

    }

}
