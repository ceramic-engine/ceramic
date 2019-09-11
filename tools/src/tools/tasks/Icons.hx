package tools.tasks;

import tools.Helpers.*;
import sys.FileSystem;
import haxe.io.Path;

class Icons extends tools.Task {

/// Properties

/// Lifecycle

    override public function new() {

        super();

    } //new

    override public function info(cwd:String):String {

        return "Generate app icons using " + context.backend.name + " backend and given target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        var project = new Project();
        var projectPath = Path.join([cwd, 'ceramic.yml']);
        project.loadAppFile(projectPath);

        var availableTargets = context.backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            fail('You must specify a target to generate icons.');
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

        var appIcon = project.app.icon;
        if (!Path.isAbsolute(appIcon)) {
            var projectAppIcon = Path.join([context.cwd, appIcon]);
            var ceramicAppIcon = Path.join([context.ceramicToolsPath, appIcon]);
            if (FileSystem.exists(projectAppIcon)) {
                appIcon = projectAppIcon;
            } else if (FileSystem.exists(ceramicAppIcon)) {
                appIcon = ceramicAppIcon;
            } else {
                fail('Invalid icon: $appIcon');
            }
        } else if (!FileSystem.exists(appIcon)) {
            fail('Invalid icon: $appIcon');
        }

        print('Update project icons');

        context.backend.transformIcons(cwd, appIcon, target, context.variant);

    } //run

}