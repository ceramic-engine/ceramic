package tools.tasks.plugin;

import tools.Helpers.*;
import tools.Project;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class PluginHxml extends tools.Task {

    override public function info(cwd:String):String {

        return "Print hxml data for the current plugin.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var isToolsKind = extractArgFlag(args, 'tools', true);
        var isRuntimeKind = extractArgFlag(args, 'runtime', true);
        var isEditorKind = extractArgFlag(args, 'editor', true);

        var completionFlag = extractArgFlag(args, 'completion', true);

        if ((isToolsKind && isRuntimeKind) || (isToolsKind && isEditorKind) || (isRuntimeKind && isEditorKind)) {
            fail('Ambiguous plugin kind.');
        }

        var kinds:Array<PluginKind> = [];
        if (isToolsKind) {
            kinds.push(Tools);
            if (!context.defines.exists('tools')) {
                context.defines.set('tools', '');
            }
        }
        if (isRuntimeKind) {
            kinds.push(Runtime);
            if (!context.defines.exists('runtime')) {
                context.defines.set('runtime', '');
            }
        }
        if (isEditorKind) {
            kinds.push(Editor);
            if (!context.defines.exists('editor')) {
                context.defines.set('editor', '');
            }
        }

        ensureCeramicProject(cwd, args, Plugin(kinds));

        if (!isToolsKind) {
            fail('HXML output is not supported for this kind of plugin.');
        }

        // Load project
        var project = new Project();
        project.loadPluginFile(Path.join([cwd, 'ceramic.yml']));

        // Add path
        project.plugin.paths.push(Path.join([context.ceramicToolsPath, 'src']));

        // Compute extra HXML
        //
        var extraHxml = [];

        var pluginLibs:Array<Dynamic> = project.plugin.libs;
        for (lib in pluginLibs) {
            var libName:String = null;
            var libVersion:String = "*";
            if (Std.isOfType(lib, String)) {
                libName = lib;
            } else {
                for (k in Reflect.fields(lib)) {
                    libName = k;
                    libVersion = Reflect.field(lib, k);
                    break;
                }
            }
            if (libVersion != "*") {
                extraHxml.push('-lib ' + libName + ':' + libVersion);
            } else {
                extraHxml.push('-lib ' + libName);
            }
        }

        if (project.plugin.hxml != null) {
            var parsedHxml = tools.Hxml.parse(project.plugin.hxml);
            if (parsedHxml != null && parsedHxml.length > 0) {
                parsedHxml = tools.Hxml.formatAndChangeRelativeDir(parsedHxml, cwd, cwd);
                for (flag in parsedHxml) {
                    extraHxml.push(flag);
                }
            }
        }

        for (key in Reflect.fields(project.plugin.defines)) {
            var val = Reflect.field(project.plugin.defines, key);
            if (val == true) {
                extraHxml.push('-D $key');
            } else {
                extraHxml.push('-D $key=$val');
            }
        }

        for (entry in (project.plugin.paths:Array<String>)) {
            extraHxml.push('-cp ' + entry);
        }

        if (completionFlag) {
            extraHxml.push('-D completion');
        }

        // Main entry point
        extraHxml.push('-main tools.ToolsPlugin');

        // Compute hxml (raw)
        var hxmlOriginalCwd = cwd;
        var rawHxml = '
        -cp tools/src
        -lib hxnodejs
        -lib hxnodejs-ws
        -lib hscript
        -js index.js
        -debug
        ' + extraHxml.join("\n");
        
        // Make every hxml paths absolute (to simplify IDE integration)
        //
        var hxmlData = tools.Hxml.parse(rawHxml);

        var finalHxml = tools.Hxml.formatAndChangeRelativeDir(hxmlData, hxmlOriginalCwd, cwd).join(" ").replace(" \n ", "\n").trim();

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

    }

}
