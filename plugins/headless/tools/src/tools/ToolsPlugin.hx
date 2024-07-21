package tools;

import backend.tools.BackendTools;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;
import tools.Ide;
import tools.Vscode;

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

    public function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>, hxmlOutput:String) {

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

                    var targetArgs = [backendName, kind, buildTarget.name, '--setup', '--assets'];
                    var selectArgs = [backendName, "hxml", buildTarget.name, "--setup"];

                    if (context.vscode) {
                        targetArgs.push('--vscode-editor');
                    }

                    if (hxmlOutput != null) {

                        targetArgs.push('--hxml-output');
                        targetArgs.push(hxmlOutput);

                        selectArgs.push('--output');
                        selectArgs.push(hxmlOutput);
                    }

                    targets.push({
                        name: '$backendName / $name',
                        groups: ['build', backendName],
                        command: 'ceramic',
                        args: targetArgs,
                        select: {
                            command: 'ceramic',
                            args: selectArgs
                        }
                    });

                }
            }
        }

    }

}
