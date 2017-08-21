package tools.tasks;

import tools.Tools.*;

class Build extends tools.Task {

/// Properties

    var kind:String;

/// Lifecycle

    override public function new(kind:String) {

        super();

        this.kind = kind;

    } //new

    override public function info(cwd:String):String {

        return kind + " project with " + backend.name + " backend and given target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args);

        var availableTargets = backend.getBuildTargets();
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
        if (!settings.defines.exists(target.name)) {
            settings.defines.set(target.name, '');
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
            backend.runSetup(cwd, [args[0], 'setup', target.name, '--update-project'], target, settings.variant, true);
        }

        // Update assets, if needed
        if (extractArgFlag(args, 'assets', true)) {
            var task = new Assets();
            task.run(cwd, [args[0], 'assets', target.name, '--variant', settings.variant]);
        }

        // Get and run backend's build task
        backend.runBuild(cwd, args, target, settings.variant, configIndex);

        // Generate hxml?
        var hxmlOutput = extractArgValue(args, 'hxml-output', true);
        if (hxmlOutput != null) {
            var task = new Hxml();
            task.run(cwd, [args[0], 'hxml', target.name, '--variant', settings.variant, '--output', hxmlOutput]);
        }

    } //run

} //Buildup
