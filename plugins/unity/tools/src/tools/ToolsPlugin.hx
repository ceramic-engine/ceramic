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
        tasks.set('unity targets', new tools.tasks.Targets());
        tasks.set('unity setup', new tools.tasks.Setup());
        tasks.set('unity hxml', new tools.tasks.Hxml());
        tasks.set('unity build', new tools.tasks.Build('Build', 'unity'));
        tasks.set('unity run', new tools.tasks.Build('Run', 'unity'));
        tasks.set('unity clean', new tools.tasks.Build('Clean', 'unity'));
        tasks.set('unity assets', new tools.tasks.Assets());
        tasks.set('unity icons', new tools.tasks.Icons());
        tasks.set('unity update', new tools.tasks.Update());
        tasks.set('unity info', new tools.tasks.Info());
        tasks.set('unity libs', new tools.tasks.Libs());

        tasks.set('unity project', new tools.tasks.unity.Project());

        // Restore default backend
        context.backend = prevBackend;

    }

    public function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>, hxmlOutput:String) {

        var backendName = 'unity';

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
