package tools.tasks;

import tools.Helpers.*;

class Build extends tools.Task {

/// Properties

    var kind:String;

/// Lifecycle

    override public function new(kind:String) {

        super();

        this.kind = kind;

    } //new

    override public function info(cwd:String):String {

        return kind + " project with " + context.backend.name + " backend and given target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var availableTargets = context.backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            fail('You must specify a target to build.');
        }

        // Find target from name
        //
        var target = null;
        for (aTarget in availableTargets) {

            if (aTarget.name == targetName) {
                target = aTarget;
                break;
            }

        }

        if (target == null) {
            fail('Unknown target: $targetName');
        }

        // Add target define
        if (!context.defines.exists(target.name)) {
            context.defines.set(target.name, '');
        }

        // Get build config
        //
        var buildConfig = null;
        var configIndex = 0;
        for (conf in target.configs) {
            if (conf.getName() == kind) {
                buildConfig = conf;
                break;
            }
            configIndex++;
        }

        if (buildConfig == null) {
            fail('Invalid configuration ' + kind + ' for target ' + target.name + ' (' + target.displayName + ').');
        }

        // Update setup, if needed
        if (extractArgFlag(args, 'setup', true)) {
            context.backend.runSetup(cwd, ['setup', target.name, '--update-project'], target, context.variant, true);
        }

        // Update assets, if needed
        if (extractArgFlag(args, 'assets', true)) {
            var task = new Assets();
            task.run(cwd, ['assets', target.name, '--variant', context.variant]);
        }

        // Get and run backend's build task
        context.backend.runBuild(cwd, args, target, context.variant, configIndex);

        // Generate hxml?
        var hxmlOutput = extractArgValue(args, 'hxml-output', true);
        if (hxmlOutput != null) {
            var task = new Hxml();
            task.run(cwd, ['hxml', target.name, '--variant', context.variant, '--output', hxmlOutput]);
        }

        // Update vscode settings?
        if (context.vscode) {
            // This will ensure haxe completion server is restarted after a build.
            var task = new Vscode();
            task.run(cwd, ['vscode', target.name, '--variant', context.variant, '--settings-only']);
        }

    } //run

} //Buildup
