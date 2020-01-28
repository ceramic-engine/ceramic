package tools.tasks.ios;

import tools.Helpers.*;
import haxe.io.Path;

class InstallPods extends tools.Task {

    override public function info(cwd:String):String {

        return "Install Xcode project pod dependencies.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        // Create ios project if needed
        IosProject.createIosProjectIfNeeded(cwd, project);

        // Args
        var cmdArgs = ['install'];

        // Repo update?
        if (extractArgFlag(args, 'repo-update')) {
            cmdArgs.push('--repo-update');
        }

        // Run command
        command('pod', cmdArgs, { cwd: Path.join([cwd, 'project/ios/project']) });

    }

}
