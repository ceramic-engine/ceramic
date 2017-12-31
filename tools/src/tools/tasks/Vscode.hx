package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

using StringTools;

class Vscode extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate project files for Visual Studio Code.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var force = extractArgFlag(args, 'force');
        var settingsOnly = extractArgFlag(args, 'settings-only');
        var vscodeDir = Path.join([cwd, '.vscode']);

        if (!force && !settingsOnly) {
            if (FileSystem.exists(Path.join([vscodeDir, 'tasks.json']))
                || FileSystem.exists(Path.join([vscodeDir, 'tasks-chooser.json']))
                || FileSystem.exists(Path.join([vscodeDir, 'settings.json']))) {

                fail('Some Visual Studio Code project files already exist.\nUse --force to generate them again.');
            }
        }

        if (!settingsOnly) {

            var chooser = {
                selectDescription: "Select build config",
                items: [],
                baseItem: {
                    version: "2.0.0"
                }
            };

            // Let plugins extend the list
            for (plugin in context.plugins) {
                if (plugin.extendVscodeTasksChooser != null) {

                    var prevBackend = context.backend;
                    context.backend = plugin.backend;

                    plugin.extendVscodeTasksChooser(chooser.items);

                    context.backend = prevBackend;
                }
            }

            // Save tasks-chooser.json
            //
            if (!FileSystem.exists(vscodeDir)) {
                FileSystem.createDirectory(vscodeDir);
            }
            File.saveContent(Path.join([vscodeDir, 'tasks-chooser.json']), Json.stringify(chooser, null, '    '));

            // Save tasks.json
            //
            var vscodeTasks:Dynamic = {};
            for (key in Reflect.fields(chooser.baseItem)) {
                if (key == 'onSelect') continue;
                Reflect.setField(vscodeTasks, key, Reflect.field(chooser.baseItem, key));
            }
            for (key in Reflect.fields(chooser.items[0])) {
                if (key == 'onSelect') continue;
                Reflect.setField(vscodeTasks, key, Reflect.field(chooser.items[0], key));
            }
            vscodeTasks.chooserIndex = 0;
            File.saveContent(Path.join([vscodeDir, 'tasks.json']), Json.stringify(vscodeTasks, null, '    '));

        }

        // Save settings.json
        //
        var vscodeSettings = {
            "haxe.displayConfigurations": [
                ["completion.hxml", "-D", "seed=" + Math.round(Date.now().getTime())]
            ],
            "search.exclude": {
                "**/.git": true,
                "**/node_modules": true,
                "**/tmp": true,
                "**/out": true
            }
        };

        // If settings already exist, just change haxe.displayConfigurations
        var settingsExist = false;
        if (FileSystem.exists(Path.join([vscodeDir, 'settings.json']))) {
            try {
                var existingVscodeSettings = Json.parse(File.getContent(Path.join([vscodeDir, 'settings.json'])));
                Reflect.setField(existingVscodeSettings, "haxe.displayConfigurations", Reflect.field(vscodeSettings, "haxe.displayConfigurations"));
                vscodeSettings = existingVscodeSettings;
                settingsExist = true;
            }
            catch (e:Dynamic) {}
        }
        
        if (!settingsOnly || settingsExist) {
            File.saveContent(Path.join([vscodeDir, 'settings.json']), Json.stringify(vscodeSettings, null, '    '));
        }

    } //run

} //Vscode
