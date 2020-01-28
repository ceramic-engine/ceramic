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
        tasks.set('luxe targets', new tools.tasks.Targets());
        tasks.set('luxe setup', new tools.tasks.Setup());
        tasks.set('luxe hxml', new tools.tasks.Hxml());
        tasks.set('luxe build', new tools.tasks.Build('Build'));
        tasks.set('luxe run', new tools.tasks.Build('Run'));
        tasks.set('luxe clean', new tools.tasks.Build('Clean'));
        tasks.set('luxe assets', new tools.tasks.Assets());
        tasks.set('luxe icons', new tools.tasks.Icons());
        tasks.set('luxe update', new tools.tasks.Update());
        tasks.set('luxe info', new tools.tasks.Info());
        tasks.set('luxe libs', new tools.tasks.Libs());

        // Restore default backend
        context.backend = prevBackend;

    }

    public function extendIdeInfo(tasks:Array<IdeInfoTaskItem>, variants:Array<IdeInfoVariantItem>) {

        var backendName = 'luxe';

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

                tasks.push({
                    name: '$backendName / $name',
                    groups: ['build', backendName],
                    command: 'ceramic',
                    args: [backendName, kind, target.name, '--setup', '--assets', '--hxml-output', 'completion.hxml'],
                    select: {
                        command: 'ceramic',
                        args: [backendName, "hxml", target.name, "--setup", "--output", "completion.hxml"]
                    }
                });

            }
        }

    }

    public function extendVscodeTasksChooser(items:Array<VscodeChooserItem>) {

        // Add luxe-related tasks
        //
        var backendName = 'luxe';

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
                    for (watch in [false, true]) {

                        if (editor && (target.name != 'web' || kind != 'build')) continue;
                        if (watch && (target.name != 'web' || kind != 'run')) continue;

                        for (debug in [false, true]) {

                            if (editor && !debug) continue;
                            if (watch && !debug) continue;

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
                                    args: [backendName, kind, target.name, '--setup', '--assets', '--vscode-editor', '--hxml-output', 'completion.hxml'].concat(debug ? ['--debug'] : []).concat(editor ? ['--variant', 'editor'] : []).concat(watch ? ['--watch'] : []),
                                    group: {
                                        kind: "build",
                                        isDefault: true
                                    },
                                    problemMatcher: "$haxe"
                                }
                            ];

                            items.push({
                                displayName: '▶︎ ' + backendName + ' / ' + name + (debug && !editor && !watch ? ' (debug)' : '') + (editor ? ' (editor)' : '') + (watch ? ' (watch)' : ''),
                                description: 'ceramic ' + backendName + ' ' + kind + ' ' + target.name + ' --setup --assets' + (debug ? ' --debug' : '') + (editor ? ' --variant editor' : '') + (watch ? ' --watch' : ''),
                                tasks: tasksContent,
                                onSelect: {
                                    command: "ceramic",
                                    args: [backendName, "hxml", target.name, "--setup", "--output", "completion.hxml"].concat(debug ? ['--debug'] : []).concat(editor ? ['--variant', 'editor'] : []).concat(watch ? ['--watch'] : [])
                                }
                            });

                        }
                    }
                }

            }

        }

    }

}
