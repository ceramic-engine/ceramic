package tools.tasks;

import tools.Tools.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Hxml extends tools.Task {

    override public function info(cwd:String):String {

        return "Print hxml data using " + backend.name + " backend and the given target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        var availableTargets = backend.getBuildTargets();
        var targetName = getTargetName(args, availableTargets);

        if (targetName == null) {
            fail('You must specify a target to get hxml from.');
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

        // Get and run backend's setup task
        var rawHxml = backend.getHxml(cwd, args, target);
        var hxmlOriginalCwd = backend.getHxmlCwd(cwd, args, target);
        
        // Make every hxml paths absolute (to simplify IDE integration)
        //
        var hxmlData = tools.Hxml.parse(rawHxml);
        
        // Add required hxml
        var updatedData = [];

        // Convert relative paths to absolute ones
        var i = 0;
        while (i < hxmlData.length) {

            var item = hxmlData[i];

            if (item.startsWith('-') || item.endsWith('.hxml')) {
                updatedData.push("\n");
            }

            // Update relative path to sub-hxml files
            if (item.endsWith('.hxml')) {
                var path = hxmlData[i];

                if (!Path.isAbsolute(path)) {
                    // Make this path absolute to make it work from project's CWD
                    path = Path.normalize(Path.join([hxmlOriginalCwd, path]));

                    // Remove path prefix
                    path = path.substr(cwd.length + 1);
                }

                updatedData.push(path);
            }
            else {
                updatedData.push(item);
            }

            if (item == '-cp' || item == '-cpp' || item == '-js' || item == '-swf') {
                i++;

                var path = hxmlData[i];
                if (!Path.isAbsolute(path)) {
                    // Make this path absolute to make it work from project's CWD
                    path = Path.normalize(Path.join([hxmlOriginalCwd, path]));

                    // Remove path prefix for -cpp/-js/-swf
                    if (item != '-cp') {
                        path = path.substr(cwd.length + 1);
                    }
                }

                updatedData.push(path);
            }

            i++;
        }

        var finalHxml = updatedData.join(" ").replace(" \n ", "\n").trim() + "\n";

        var output = extractArgValue(args, 'output');
        if (output != null) {
            if (!Path.isAbsolute(output)) {
                output = Path.join([cwd, output]);
            }
            var outputDir = Path.directory(output);
            if (!FileSystem.exists(outputDir)) {
                FileSystem.createDirectory(outputDir);
            }

            // Save result
            File.saveContent(output, finalHxml);
        }
        else {
            // Print result
            print(finalHxml.rtrim());
        }

    } //run

} //Init
