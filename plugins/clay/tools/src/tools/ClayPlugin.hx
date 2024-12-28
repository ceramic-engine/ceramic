package tools;

import backend.tools.ClayBackendTools;
import tools.Context;
import tools.Helpers.*;
import tools.Helpers;
import tools.Ide;
import tools.Vscode;

@:keep
class ClayPlugin {

    public var backend:ClayBackendTools;

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Set backend
        var prevBackend = context.backend;
        backend = new ClayBackendTools();
        context.backend = backend;

        // Add tasks
        context.addTask('clay targets', new tools.tasks.Targets());
        context.addTask('clay setup', new tools.tasks.Setup());
        context.addTask('clay hxml', new tools.tasks.Hxml());
        context.addTask('clay build', new tools.tasks.Build('Build', 'clay'));
        context.addTask('clay run', new tools.tasks.Build('Run', 'clay'));
        context.addTask('clay clean', new tools.tasks.Build('Clean', 'clay'));
        context.addTask('clay assets', new tools.tasks.Assets());
        context.addTask('clay icons', new tools.tasks.Icons());
        context.addTask('clay update', new tools.tasks.Update());
        context.addTask('clay info', new tools.tasks.Info());
        context.addTask('clay libs', new tools.tasks.Libs());

        // Restore default backend
        context.backend = prevBackend;

    }

    public function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>, hxmlOutput:String) {

        var backendName = 'clay';

        if (context.project != null && context.project.app != null) {

            for (buildTarget in backend.getBuildTargets()) {

                for (config in buildTarget.configs) {

                    var name:String = null;
                    var kind:String = null;
                    var extraArgs:Array<String> = [];

                    switch (config) {
                        case Build(name_, extraArgs_):
                            name = name_;
                            kind = 'build';
                            if (extraArgs_ != null) {
                                extraArgs = extraArgs_;
                            }
                        case Run(name_, extraArgs_):
                            name = name_;
                            kind = 'run';
                            if (extraArgs_ != null) {
                                extraArgs = extraArgs_;
                            }
                        case Clean(name_, extraArgs_):
                            if (extraArgs_ != null) {
                                extraArgs = extraArgs_;
                            }
                    }

                    if (kind == null) continue;

                    var targetArgs = [backendName, kind, buildTarget.name, '--setup', '--assets'].concat(extraArgs);
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
