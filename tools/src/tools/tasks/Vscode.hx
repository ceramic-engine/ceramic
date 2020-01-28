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

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var force = extractArgFlag(args, 'force');
        var settingsOnly = extractArgFlag(args, 'settings-only');
        var vscodeDir = Path.join([cwd, '.vscode']);

        var backends = [];
        while (true) {
            var aBackend = extractArgValue(args, 'backend', true);
            if (aBackend == null || aBackend.trim() == '') break;
            backends.push(aBackend);
        }

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

                    if (plugin.backend == null || backends.indexOf(plugin.backend.name) != -1) {

                        // Extend tasks chooser if its an enabled backend
                        // of if its not a backend plugin

                        var prevBackend = context.backend;
                        context.backend = plugin.backend;

                        plugin.extendVscodeTasksChooser(chooser.items);

                        context.backend = prevBackend;

                    }
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
            "window.title": "${activeEditorShort} — " + project.app.name,
            "haxe.displayConfigurations": [
                ["completion.hxml"]
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

        // Save launch.json (for debugging)
        var vscodeLaunch = {
            "version": "0.2.0",
            "configurations": [
                {
                    "name": "Debug Web",
                    "type": "chrome",
                    "request": "attach",
                    "port": 9223,
                    "webRoot": "${workspaceFolder}/project/web",
                    "sourceMaps": true,
                    "disableNetworkCache": true,
                    "smartStep": true
                }
            ]
        };
        
        if (!settingsOnly) {
            File.saveContent(Path.join([vscodeDir, 'launch.json']), Json.stringify(vscodeLaunch, null, '    '));
        }

        /*if (haxeServerSeed) {
            // Just forcing haxe server to restart and clean compile cache.
            Sync.run(function(done) {
                js.Node.setTimeout(function() {
                    Reflect.setField(vscodeSettings, "haxe.displayConfigurations", [["completion.hxml"]]);
                    File.saveContent(Path.join([vscodeDir, 'settings.json']), Json.stringify(vscodeSettings, null, '    '));
                    done();
                }, 250);
            });
        }*/

    }

}
