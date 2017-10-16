package tools.tasks.spine;

import tools.Helpers.*;

class RunSpine extends tools.Task {

    override public function info(cwd:String):String {

        return "Run Spine application.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var spineAppPath:String = null;
        if (Sys.systemName() == 'Mac') {
            spineAppPath = '/Applications/Spine/Spine.app/Contents/MacOS/Spine';
        } else if (Sys.systemName() == 'Windows') {
            spineAppPath = 'Spine';
        } else {
            fail('Spine export is not yet supported on ' + Sys.systemName() + ' system.');
        }

        // Run
        command(spineAppPath, args.slice(2));

    } //run

} //RunSpine
