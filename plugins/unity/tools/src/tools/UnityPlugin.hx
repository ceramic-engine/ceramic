package tools;

import backend.tools.UnityBackendTools;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;
import tools.Ide;
import tools.Vscode;

@:keep
class UnityPlugin {

    public var backend:UnityBackendTools;

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Use same context as parent
        Helpers.context = context;

        // Set backend
        var prevBackend = context.backend;
        backend = new UnityBackendTools();
        context.backend = backend;

        // Add tasks
        context.addTask('unity targets', new tools.tasks.Targets());
        context.addTask('unity setup', new tools.tasks.Setup());
        context.addTask('unity hxml', new tools.tasks.Hxml());
        context.addTask('unity build', new tools.tasks.Build('Build', 'unity'));
        context.addTask('unity run', new tools.tasks.Build('Run', 'unity'));
        context.addTask('unity clean', new tools.tasks.Build('Clean', 'unity'));
        context.addTask('unity assets', new tools.tasks.Assets());
        context.addTask('unity icons', new tools.tasks.Icons());
        context.addTask('unity update', new tools.tasks.Update());
        context.addTask('unity info', new tools.tasks.Info());
        context.addTask('unity libs', new tools.tasks.Libs());

        context.addTask('unity project', new tools.tasks.unity.Project());

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

                    if (context.vscode) {
                        targetArgs.push('--vscode-editor');
                        if (context.vscodeUriScheme != 'vscode') {
                            targetArgs.push('--vscode-uri-scheme');
                            targetArgs.push(context.vscodeUriScheme);
                        }
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
