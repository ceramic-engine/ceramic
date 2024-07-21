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
        tasks.set('clay targets', new tools.tasks.Targets());
        tasks.set('clay setup', new tools.tasks.Setup());
        tasks.set('clay hxml', new tools.tasks.Hxml());
        tasks.set('clay build', new tools.tasks.Build('Build', 'clay'));
        tasks.set('clay run', new tools.tasks.Build('Run', 'clay'));
        tasks.set('clay clean', new tools.tasks.Build('Clean', 'clay'));
        tasks.set('clay assets', new tools.tasks.Assets());
        tasks.set('clay icons', new tools.tasks.Icons());
        tasks.set('clay update', new tools.tasks.Update());
        tasks.set('clay info', new tools.tasks.Info());
        tasks.set('clay libs', new tools.tasks.Libs());

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
