package tools.tasks;

import tools.Helpers.*;
import tools.Module as ToolsModule;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Module extends tools.Task {

    override public function info(cwd:String):String {

        return "Target a specific module.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var moduleName = extractArgValue(args, 'name');
        var vscodeDir = Path.join([cwd, '.vscode']);

        // Update .module file
        File.saveContent(Path.join([cwd, '.module']), moduleName != null ? moduleName : '');

        // Patch completion.hxml
        if (FileSystem.exists(Path.join([cwd, 'completion.hxml']))) {
            var hxml = File.getContent(Path.join([cwd, 'completion.hxml']));
            hxml = ToolsModule.patchHxml(cwd, project, hxml, moduleName);
            File.saveContent(Path.join([cwd, 'completion.hxml']), hxml);
        }

        // Update .vscode/settings
        if (FileSystem.exists(Path.join([vscodeDir, 'settings.json']))) {
            try {
                var vscodeSettings = Json.parse(File.getContent(Path.join([vscodeDir, 'settings.json'])));

                if (moduleName != null && moduleName != '') {
                    Reflect.setField(vscodeSettings, "haxe.displayConfigurations", ["completion.hxml", "-D", 'module_$moduleName', "-D", 'ceramic_module=$moduleName']);
                } else {
                    Reflect.setField(vscodeSettings, "haxe.displayConfigurations", ["completion.hxml"]);
                }

                File.saveContent(Path.join([vscodeDir, 'settings.json']), Json.stringify(vscodeSettings, null, '    '));
            }
            catch (e:Dynamic) {
                warning('Error when saving .vscode/settings.json: ' + e);
            }
        }

    } //run

} //Module
