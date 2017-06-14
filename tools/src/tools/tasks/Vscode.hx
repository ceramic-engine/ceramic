package tools.tasks;

import tools.Tools.*;
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

        ensureCeramicProject(cwd, args);

        var force = extractArgFlag(args, 'force');
        var vscodeDir = Path.join([cwd, '.vscode']);

        if (!force) {
            if (FileSystem.exists(Path.join([vscodeDir, 'tasks.json']))
                || FileSystem.exists(Path.join([vscodeDir, 'tasks-chooser.json']))
                || FileSystem.exists(Path.join([vscodeDir, 'settings.json']))) {

                fail('Some Visual Studio Code project files already exist.\nUse --force to generate them again.');
            }
        }

        var chooser:Dynamic = {
            selectDescription: "Select build config",
            items: [],
            baseItem: {
                version: "2.0.0"
            }
        };

        var completionHxmlInfo = null;

        for (backendName in ['luxe']) {

            if (~/^([a-zA-Z0-9_]+)$/.match(backendName) && sys.FileSystem.exists(Path.join([js.Node.__dirname, 'tools-' + backendName + '.js']))) {
                var initTools = js.Node.require('./tools-' + backendName + '.js');
                var tools:tools.Tools = initTools(cwd, ['-D$backendName'].concat(args));

                var backend = tools.getBackend();

                for (target in backend.getBuildTargets()) {

                    for (config in target.configs) {

                        var name:String = null;
                        var kind:String = null;

                        switch (config) {
                            case Build(name_):
                                name = name_;
                                kind = 'build';
                            case Run(name_):
                                name = name_;
                                kind = 'run';
                            case Clean(name_):
                        }

                        if (kind == null) continue;

                        if (completionHxmlInfo == null) {
                            completionHxmlInfo = [backendName, 'hxml', target.name, '--output', 'completion.hxml'];
                        }

                        for (debug in [false, true]) {

                            var tasksContent:Array<Dynamic> = [
                                {
                                    taskName: "build",
                                    command: "ceramic",
                                    args: [backendName, kind, target.name, '--setup', '--assets', '--vscode-editor', '--hxml-output', 'completion.hxml'].concat(debug ? ['--debug'] : []),
                                    problemMatcher: {
                                        owner: "haxe",
                                        pattern: {
                                            "regexp": "^(.+):(\\d+): (?:lines \\d+-(\\d+)|character(?:s (\\d+)-| )(\\d+)) : (?:(Warning) : )?(.*)$",
                                            "file": 1,
                                            "line": 2,
                                            "endLine": 3,
                                            "column": 4,
                                            "endColumn": 5,
                                            "severity": 6,
                                            "message": 7
                                        }
                                    }
                                }
                            ];

                            chooser.items.push({
                                displayName: '▶︎ ' + name + (debug ? ' (debug)' : ''),
                                description: 'ceramic ' + backendName + ' ' + kind + ' ' + target.name + ' --setup --assets' + (debug ? ' --debug' : ''),
                                tasks: tasksContent,
                                onSelect: {
                                    command: "ceramic",
                                    args: [backendName, "hxml", target.name, "--output", "completion.hxml"].concat(debug ? ['--debug'] : [])
                                }
                            });

                        }

                    }

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

        // Save settings.json
        //
        var vscodeSettings = {
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
        File.saveContent(Path.join([vscodeDir, 'settings.json']), Json.stringify(vscodeSettings, null, '    '));

        // Save completion.hxml
        //
        runCeramic(cwd, completionHxmlInfo);

    } //run

} //Vscode
