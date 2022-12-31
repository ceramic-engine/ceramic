package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class Vscode extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate project files for Visual Studio Code.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var force = extractArgFlag(args, 'force');
        var updateTasks = extractArgFlag(args, 'update-tasks');
        var settingsOnly = extractArgFlag(args, 'settings-only');
        var vscodeProjectRoot = extractArgValue(args, 'vscode-project-root');
        var vscodeDir = vscodeProjectRoot != null ? vscodeProjectRoot : Path.join([cwd, '.vscode']);
        if (!Path.isAbsolute(vscodeDir)) {
            vscodeDir = Path.join([cwd, vscodeDir]);
        }

        var backends = [];
        while (true) {
            var aBackend = extractArgValue(args, 'backend', true);
            if (aBackend == null || aBackend.trim() == '') break;
            backends.push(aBackend);
        }

        if (!force && !settingsOnly && !updateTasks) {
            if (FileSystem.exists(Path.join([vscodeDir, 'tasks.json']))
                || FileSystem.exists(Path.join([vscodeDir, 'settings.json']))) {

                fail('Some Visual Studio Code project files already exist.\nUse --force to generate them again.');
            }
        }

        // Ensure vscode directory exists
        if (!FileSystem.exists(vscodeDir)) {
            FileSystem.createDirectory(vscodeDir);
        }

        if (!settingsOnly) {

            // Save tasks.json
            var vscodeTasks = {
                "version": "2.0.0",
                "tasks": [
                    {
                        "type": "ceramic",
                        "args": "active configuration",
                        "problemMatcher": [
                            "$haxe-absolute",
                            "$haxe",
                            "$haxe-error",
                            "$haxe-trace"
                        ],
                        "group": {
                            "kind": "build",
                            "isDefault": true
                        },
                        "label": "ceramic: active configuration"
                    }
                ]
            };
            File.saveContent(Path.join([vscodeDir, 'tasks.json']), Json.stringify(vscodeTasks, null, '    '));

        }

        var haxePath = Path.normalize(Path.join([context.ceramicToolsPath, 'haxe']));
        var haxelibPath = Path.normalize(Path.join([context.ceramicToolsPath, 'haxelib']));

        // Required on windows
        if (Sys.systemName() == 'Windows') {
            haxePath += '.cmd';
            haxelibPath += '.cmd';
        }

        // Save settings.json
        //
        var vscodeSettings = {
            "window.title": "${activeEditorShort} — " + project.app.name,
            "search.exclude": {
                "**/.git": true,
                "**/node_modules": true,
                "**/tmp": true,
                "**/out": true
            },
            "haxe.executable": Files.getRelativePath(haxePath, cwd),
            "haxelib.executable": Files.getRelativePath(haxelibPath, cwd)
        };

        // If settings already exist, just change haxe.configurations
        var settingsModified = false;
        if (FileSystem.exists(Path.join([vscodeDir, 'settings.json']))) {
            try {
                var existingVscodeSettings = Json.parse(File.getContent(Path.join([vscodeDir, 'settings.json'])));
                if (Reflect.hasField(existingVscodeSettings, "haxe.configurations")) {
                    Reflect.deleteField(existingVscodeSettings, "haxe.configurations");
                    settingsModified = true;
                    vscodeSettings = existingVscodeSettings;
                }
                if (Reflect.hasField(existingVscodeSettings, "haxe.displayConfigurations")) {
                    Reflect.deleteField(existingVscodeSettings, "haxe.displayConfigurations");
                    settingsModified = true;
                    vscodeSettings = existingVscodeSettings;
                }
            }
            catch (e:Dynamic) {}
        }

        if (!settingsOnly || settingsModified) {
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
                    Reflect.setField(vscodeSettings, "haxe.configurations", [["completion.hxml"]]);
                    File.saveContent(Path.join([vscodeDir, 'settings.json']), Json.stringify(vscodeSettings, null, '    '));
                    done();
                }, 250);
            });
        }*/

    }

}
