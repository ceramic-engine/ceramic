package tools.tasks.android;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class NdkStack extends tools.Task {

    override public function info(cwd:String):String {

        return "Run ndk-stack for the currently running Ceramic app on an android device";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        final sdkPath = AndroidUtils.sdkPath();
        final ndkPath = AndroidUtils.ndkPath();
        final pluginPath = context.plugins.get('android').path;
        final jniLibsPath = Path.join([cwd, 'project', 'android', 'app', 'src', 'main', 'jniLibs']);

        #if windows
        final ndkStack = Path.join([pluginPath, 'resources', 'ndk-stack.bat']);
        #else
        final ndkStack = Path.join([pluginPath, 'resources', 'ndk-stack.sh']);
        #end

        Sys.command(ndkStack, [sdkPath, ndkPath, jniLibsPath]);

    }

}
