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

        extractTargetDefines(cwd, args);

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
        var rawHxml = backend.getHxml(cwd, args, target, settings.variant);
        var hxmlOriginalCwd = backend.getHxmlCwd(cwd, args, target, settings.variant);

        // Add completion flag
        rawHxml += "\n" + '-D completion';
        
        // Make every hxml paths absolute (to simplify IDE integration)
        //
        var hxmlData = tools.Hxml.parse(rawHxml);
        var finalHxml = tools.Hxml.changeRelativeDir(hxmlData, hxmlOriginalCwd, cwd).join("\n");

        var output = extractArgValue(args, 'output');
        if (output != null) {
            if (!Path.isAbsolute(output)) {
                output = Path.join([cwd, output]);
            }
            var outputDir = Path.directory(output);
            if (!FileSystem.exists(outputDir)) {
                FileSystem.createDirectory(outputDir);
            }

            // Compare with existing
            var prevHxml = null;
            if (FileSystem.exists(output)) {
                prevHxml = File.getContent(output);
            }

            // Save result if changed
            if (finalHxml != prevHxml) {
                File.saveContent(output, finalHxml.rtrim() + "\n");
            }
        }
        else {
            // Print result
            print(finalHxml.rtrim());
        }

    } //run

} //Init
