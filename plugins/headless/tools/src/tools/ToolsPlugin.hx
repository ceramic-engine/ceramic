package tools;

import tools.Context;
import tools.Helpers;
import tools.Vscode;
import tools.Ide;
import tools.Helpers.*;
import backend.tools.BackendTools;

@:keep
class ToolsPlugin {

    public var backend:BackendTools;

    static function main():Void {
        
        var module:Dynamic = js.Node.module;
        module.exports = new ToolsPlugin();

    }

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Set backend
        var prevBackend = context.backend;
        backend = new BackendTools();
        context.backend = backend;

        // Add tasks
        var tasks = context.tasks;
        tasks.set('headless targets', new tools.tasks.Targets());
        tasks.set('headless setup', new tools.tasks.Setup());
        tasks.set('headless hxml', new tools.tasks.Hxml());
        tasks.set('headless build', new tools.tasks.Build('Build', 'headless'));
        tasks.set('headless run', new tools.tasks.Build('Run', 'headless'));
        tasks.set('headless clean', new tools.tasks.Build('Clean', 'headless'));
        tasks.set('headless assets', new tools.tasks.Assets());
        tasks.set('headless icons', new tools.tasks.Icons());
        tasks.set('headless update', new tools.tasks.Update());
        tasks.set('headless info', new tools.tasks.Info());
        tasks.set('headless libs', new tools.tasks.Libs());
        tasks.set('task', new tools.tasks.HeadlessTask());

        // Restore default backend
        context.backend = prevBackend;

    }

    public function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>) {

        var backendName = 'headless';

        if (context.project != null && context.project.app != null) {
            for (buildTarget in backend.getBuildTargets()) {
    
                for (config in buildTarget.configs) {
    
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
    
                    targets.push({
                        name: '$backendName / $name',
                        groups: ['build', backendName],
                        command: 'ceramic',
                        args: [backendName, kind, buildTarget.name, '--setup', '--assets', '--hxml-output', 'completion.hxml'],
                        select: {
                            command: 'ceramic',
                            args: [backendName, "hxml", buildTarget.name, "--setup", "--output", "completion.hxml"]
                        }
                    });
    
                }
            }
        }

    }

    public function extendVscodeTasksChooser(items:Array<VscodeChooserItem>) {

        // Add headless-related tasks
        //
        var backendName = 'headless';

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

                for (editor in [false, true]) {

                    if (editor && (target.name != 'web' || kind != 'build')) continue;

                    for (debug in [false, true]) {

                        if (editor && !debug) continue;

                        var tasksContent:Array<VscodeChooserItemTask> = [
                            {
                                type: "shell",
                                label: "build",
                                command: "ceramic",
                                presentation: {
                                    echo: true,
                                    reveal: "always",
                                    focus: false,
                                    panel: "shared"
                                },
                                args: [backendName, kind, target.name, '--setup', '--assets', '--vscode-editor', '--hxml-output', 'completion.hxml'].concat(debug ? ['--debug'] : []).concat(editor ? ['--variant', 'editor'] : []),
                                group: {
                                    kind: "build",
                                    isDefault: true
                                },
                                problemMatcher: "$haxe",
                                runOptions: {
                                    instanceLimit: 1
                                }
                            }
                        ];

                        items.push({
                            displayName: '▶︎ ' + backendName + ' / ' + name + (debug && !editor ? ' (debug)' : '') + (editor ? ' (editor)' : ''),
                            description: 'ceramic ' + backendName + ' ' + kind + ' ' + target.name + ' --setup --assets' + (debug ? ' --debug' : '') + (editor ? ' --variant editor' : ''),
                            tasks: tasksContent,
                            onSelect: {
                                command: "ceramic",
                                args: [backendName, "hxml", target.name, "--setup", "--output", "completion.hxml"].concat(debug ? ['--debug'] : []).concat(editor ? ['--variant', 'editor'] : [])
                            }
                        });

                    }
                }

            }

        }

    }

}
