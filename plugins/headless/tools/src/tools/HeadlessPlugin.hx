package tools;

import backend.tools.HeadlessBackendTools;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;
import tools.Ide;
import tools.Vscode;

@:keep
class HeadlessPlugin {

    public var backend:HeadlessBackendTools;

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Set backend
        var prevBackend = context.backend;
        backend = new HeadlessBackendTools();
        context.backend = backend;

        // Add tasks
        context.addTask('headless targets', new tools.tasks.Targets());
        context.addTask('headless setup', new tools.tasks.Setup());
        context.addTask('headless hxml', new tools.tasks.Hxml());
        context.addTask('headless build', new tools.tasks.Build('Build', 'headless'));
        context.addTask('headless run', new tools.tasks.Build('Run', 'headless'));
        context.addTask('headless clean', new tools.tasks.Build('Clean', 'headless'));
        context.addTask('headless assets', new tools.tasks.Assets());
        context.addTask('headless icons', new tools.tasks.Icons());
        context.addTask('headless update', new tools.tasks.Update());
        context.addTask('headless info', new tools.tasks.Info());
        context.addTask('headless libs', new tools.tasks.Libs());
        context.addTask('task', new tools.tasks.HeadlessTask());

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
