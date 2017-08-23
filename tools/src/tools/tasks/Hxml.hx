package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Hxml extends tools.Task {

    override public function info(cwd:String):String {

        return "Print hxml data using " + backend.name + " backend and the given target.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args);

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
        if (!context.defines.exists(target.name)) {
            context.defines.set(target.name, '');
        }

        // Get and run backend's setup task
        var rawHxml = backend.getHxml(cwd, args, target, context.variant);
        var hxmlOriginalCwd = backend.getHxmlCwd(cwd, args, target, context.variant);

        // Add completion flag
        rawHxml += "\n" + '-D completion';

        // Add some completion cache optims
        //
        var pathFilters = [];
        var ceramicSrcContentPath = Path.join([context.ceramicPath, 'src/ceramic']);
        for (name in FileSystem.readDirectory(ceramicSrcContentPath)) {
            if (!FileSystem.isDirectory(Path.join([ceramicSrcContentPath, name]))) {
                if (name.endsWith('.hx')) {
                    var className = name.substr(0, name.length - 3);
                    if (className != 'Assets') {
                        pathFilters.push('ceramic.' + className);
                    }
                }
            }
        }
        // We hardcoded nape and spinehaxe/spine classpaths because they are common dependencies that won't change.
        // Might be a better option to compute these from loaded haxe libs directly, but for now it should be fine.
        rawHxml += "\n" + "--macro server.setModuleCheckPolicy(['nape', 'spinehaxe', 'spine', 'ceramic.internal', 'ceramic.macros', 'backend', 'spec'], [NoCheckShadowing, NoCheckDependencies], true)";
        rawHxml += "\n" + "--macro server.setModuleCheckPolicy(" + Json.stringify(pathFilters) + ", [NoCheckShadowing, NoCheckDependencies], false)";

        // Required to ensure assets list gets updated
        var toInvalidate = [
            Path.join([ceramicSrcContentPath, 'Assets.hx'])
        ];
        rawHxml += "\n" + "--macro server.invalidateFiles(" + Json.stringify(toInvalidate) + ")";
        
        // Make every hxml paths absolute (to simplify IDE integration)
        //
        var hxmlData = tools.Hxml.parse(rawHxml);
        var finalHxml = tools.Hxml.formatAndchangeRelativeDir(hxmlData, hxmlOriginalCwd, cwd).join(" ").replace(" \n ", "\n").trim();

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

} //Hxml
