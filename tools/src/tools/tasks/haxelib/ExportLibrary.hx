package tools.tasks.haxelib;

import tools.Helpers.*;
import haxe.io.Path;
import haxe.Json;
import haxe.DynamicAccess;
import sys.FileSystem;
import sys.io.File;
import tools.Files;

using StringTools;

class ExportLibrary extends tools.Task {

    override public function info(cwd:String):String {

        return "Export haxelib-compatible libraries from ceramic source-code.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var exportRuntime = extractArgFlag(args, 'runtime', true);
        var force = extractArgFlag(args, 'force');

        var outputPath = extractArgValue(args, 'output-path');
        if (outputPath == null) {
            fail('Missing argument: --output-path');
        }
        if (!Path.isAbsolute(outputPath)) outputPath = Path.normalize(Path.join([cwd, outputPath]));

        if (exportRuntime) {
            var libPath = Path.join([outputPath, 'ceramic_runtime']);
            if (!force && FileSystem.exists(libPath)) {
                fail('Output already exists: $libPath. Use --force to overwrite');
            }
            var runtimeSrcPath = Path.join([context.ceramicRuntimePath, 'src']);
            print('Export runtime to $libPath');
            Files.deleteRecursive(libPath);
            Files.copyDirectory(runtimeSrcPath, Path.join([libPath, 'src']), true);

            var haxelibJson = createHaxelibJson(
                'runtime', 'ceramic-engine/ceramic',
                "Runtime for ceramic written in cross-platform Haxe. Needs to be used with a ceramic backend.",
                context.ceramicVersion.split('-')[0],
                "Exported from ceramic v" + context.ceramicVersion
            );

            for (item in tools.Project.runtimeLibraries) {
                if (Std.is(item, String)) {
                    Reflect.setField(haxelibJson.dependencies, item, '');
                }
                else {
                    var libName:String = null;
                    var libVersion:String = null;
                    for (key in Reflect.fields(item)) {
                        libName = key;
                        libVersion = Reflect.field(item, key);
                        break;
                    }
                    if (libVersion != null && libVersion.startsWith('github:')) {
                        Reflect.setField(haxelibJson.dependencies, libName, 'git:https://github.com/' + libVersion.substr('github:'.length) + '.git');
                    }
                    else {
                        Reflect.setField(haxelibJson.dependencies, libName, libVersion);
                    }
                }
            }

            File.saveContent(Path.join([libPath, 'haxelib.json']), Json.stringify(haxelibJson, null, '  '));
        }

    }

    function createHaxelibJson(name:String, github:String, description:String, version:String, releaseNote:String):Dynamic {

        return {
            "name": "ceramic_" + name,
            "url" : "https://github.com/" + github,
            "license": "MIT",
            "tags": ["ceramic", name],
            "description": description,
            "version": version,
            "classPath": "src/",
            "releasenote": releaseNote,
            "contributors": ["jeremyfa"],
            "dependencies": {}
        };

    }

}
