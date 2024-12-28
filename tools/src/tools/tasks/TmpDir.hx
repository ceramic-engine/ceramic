package tools.tasks;

import tools.Helpers.*;

class TmpDir extends tools.Task {

    override public function info(cwd:String):String {

        return "Create and return a temporary directory";

    }

    override function run(cwd:String, args:Array<String>):Void {

        print(TempDirectory.tempDir('ceramic'));

    }

}
