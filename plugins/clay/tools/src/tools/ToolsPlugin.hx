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

    public function extendIdeInfo(targets:Array<IdeInfoTargetItem>, variants:Array<IdeInfoVariantItem>) {

        var backendName = 'clay';

        if (context.project != null && context.project.app != null) {

            for (buildTargets in backend.getBuildTargets()) {

                for (config in buildTargets.configs) {

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
                        args: [backendName, kind, buildTargets.name, '--setup', '--assets', '--hxml-output', 'completion.hxml'],
                        select: {
                            command: 'ceramic',
                            args: [backendName, "hxml", buildTargets.name, "--setup", "--output", "completion.hxml"]
                        }
                    });

                }
            }
        }

    }

}
