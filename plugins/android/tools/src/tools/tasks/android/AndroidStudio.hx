package tools.tasks.android;

import tools.Helpers.*;
import tools.Project;
import tools.Colors;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import js.node.Os;
import npm.AppleScript;

using StringTools;

class AndroidStudio extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate or open Android Studio project to build or run it";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var project = ensureCeramicProject(cwd, args, App);

        var androidProjectPath = Path.join([cwd, 'project/android']);
        var androidProjectFile = Path.join([androidProjectPath, 'app/build.gradle']);

        // Create android project if needed
        AndroidProject.createAndroidProjectIfNeeded(cwd, project);

        // Copy OpenAL binaries if needed
        AndroidProject.copyOpenALBinariesIfNeeded(cwd, project);

        var os = Sys.systemName();

        if (os == 'Mac' && FileSystem.exists(androidProjectFile)) {

            // Build or Run?
            var doBuild = extractArgFlag(args, 'build');
            var doRun = extractArgFlag(args, 'run');

            // Open project
            if (doRun) {
                print('Open and run Android Studio project');
            } else {
                print('Open Android Studio project');
            }

            Sync.run(function(done) {

                var script = '
                    activate application "Android Studio"
                    tell application "Android Studio"
                        open "$androidProjectPath"
                    end tell
';

                if (doRun) {
                    script += '
                    tell application "System Events"
                        tell process "Android Studio"
                            keystroke "r" using control down
                        end tell
                    end tell
';
                }

                AppleScript.execString(script, function(err, rtn) {
                    if (err != null) {
                        fail(''+err);
                    }
                    done();
                });
            });

        }

    } //run

} //AndroidStudio
