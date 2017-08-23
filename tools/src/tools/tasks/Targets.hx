package tools.tasks;

import tools.Helpers.*;

class Targets extends tools.Task {

    override public function info(cwd:String):String {

        return "List targets available with " + backend.name + " backend.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args);

        for (target in backend.getBuildTargets()) {

            var configs = [];
            for (config in target.configs) {
                configs.push(config.getName().toLowerCase());
            }

            print(target.name + ' (' + configs.join(', ') + ')');

        }

    } //run

} //Targets
