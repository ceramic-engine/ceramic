package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Hxml extends tools.Task {

    override public function info(cwd:String):String {

        if (context.backend == null) {
            return "Print hxml data (uses --from-hxml param).";
        }
        else {
            return "Print hxml data using " + context.backend.name + " backend and the given target.";
        }

    }

    override function run(cwd:String, args:Array<String>):Void {

        var rawHxml:String;
        var hxmlOriginalCwd:String;
        var fromHxml = extractArgValue(args, 'from-hxml');

        if (fromHxml != null) {
            // Got a source hxml to use.
            // Simply compare cwd with this source's directory
            // and convert relative paths as needed
            if (!Path.isAbsolute(fromHxml)) {
                fromHxml = Path.join([cwd, fromHxml]);
            }
            rawHxml = File.getContent(fromHxml);
            hxmlOriginalCwd = Path.directory(fromHxml);
        }
        else {

            // Get HXML from ceramic project
            ensureCeramicProject(cwd, args, App);
    
            var availableTargets = context.backend.getBuildTargets();
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
    
            // Update setup, if needed
            if (extractArgFlag(args, 'setup', true)) {
                context.backend.runSetup(cwd, ['setup', target.name, '--update-project'], target, context.variant, true);
            }
    
            // Get and run backend's setup task
            rawHxml = context.backend.getHxml(cwd, args, target, context.variant);
            hxmlOriginalCwd = context.backend.getHxmlCwd(cwd, args, target, context.variant);
    
            // Check hxml validity
            if (rawHxml == null) {
                fail('Failed to get hxml for ${target.name}. Did you run setup on this target?');
            }
    
            // Add completion flags
            rawHxml += "\n" + '-D completion -D display -D no_inline';
    
            // Add some completion cache optims
            //
            var pathFilters = [];
            var ceramicSrcContentPath = Path.join([context.ceramicRuntimePath, 'src/ceramic']);
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
    
            // Let plugins extend completion HXML
            for (plugin in context.plugins) {
                if (plugin.extendCompletionHxml != null) {
    
                    var prevBackend = context.backend;
                    context.backend = plugin.backend;
    
                    plugin.extendCompletionHxml(rawHxml);
    
                    context.backend = prevBackend;
                }
            }
        }
        
        // Make every hxml paths absolute (to simplify IDE integration)
        //
        var hxmlData = tools.Hxml.parse(rawHxml);

        // When getting completion hxml, disable dead code elimitation
        hxmlData = tools.Hxml.disableDeadCodeElimination(hxmlData);

        var hxmlTargetCwd = cwd;
        var output = extractArgValue(args, 'output');

        if (output != null) {
            
            if (!Path.isAbsolute(output)) {
                output = Path.join([cwd, output]);
            }
            var outputDir = Path.directory(output);
            if (!FileSystem.exists(outputDir)) {
                FileSystem.createDirectory(outputDir);
            }

            // Ensure hxml is relative to output (if output dir != cwd dir)
            if (Path.normalize(outputDir) != Path.normalize(hxmlTargetCwd)) {
                hxmlTargetCwd = outputDir;
            }
        }

        //var finalHxml = tools.Hxml.formatAndChangeRelativeDir(hxmlData, hxmlOriginalCwd, hxmlTargetCwd).join(" ").replace(" \n ", "\n").trim();
        
        var finalHxml = tools.Hxml.formatAndChangeRelativeDir(hxmlData, hxmlOriginalCwd, hxmlOriginalCwd).join(" ").replace(" \n ", "\n").trim();
        finalHxml = '--cwd ' + hxmlOriginalCwd + '\n' + finalHxml;

        if (output != null) {

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

    }

}
