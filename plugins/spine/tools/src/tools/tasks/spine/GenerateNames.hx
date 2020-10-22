package tools.tasks.spine;

import tools.Helpers.*;
import tools.Project;
import haxe.io.Path;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import generate.Generate;

using StringTools;

class GenerateNames extends tools.Task {

    override public function info(cwd:String):String {

        return "Generate spine names";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);
        
        var assetsPath = Path.join([context.cwd, 'assets']);
        var spineDirs = computeSpineDirs(assetsPath);

        var entries:Dynamic = {};

        for (spineDir in spineDirs) {
            var baseName = Path.withoutExtension(spineDir);
            var spineConstName = toAssetConstName(baseName);
            var absSpineDir = Path.join([assetsPath, spineDir]);

            var animations:Dynamic = {};
            animations._id = 'spine:' + baseName;

            // Find json with animations
            var jsonPath = null;
            for (file in FileSystem.readDirectory(absSpineDir)) {
                if (file.toLowerCase().endsWith('.json')) {
                    jsonPath = Path.join([absSpineDir, file]);
                    break;
                }
            }

            if (jsonPath != null) {
                var jsonData = Json.parse(File.getContent(jsonPath));
                var animationNames = Reflect.fields(jsonData.animations);
                for (animName in animationNames) {
                    var constName = toAssetConstName(animName);
                    if (!constName.startsWith('_')) {
                        Reflect.setField(
                            animations,
                            constName,
                            animName
                        );
                    }
                }
            }

            Reflect.setField(entries, spineConstName, animations);
        }

        var gen = new Generate();
        gen.generateDataHaxeFiles('Spines', entries, ['assets']);

        // Write data
        var projectGenPath = Path.join([context.cwd, 'gen']);

        for (key in gen.files.keys()) {
            var haxePath = key.replace('.', '/') + '.hx';
            var absHaxePath = Path.join([projectGenPath, haxePath]);
            var existing:String = null;
            if (FileSystem.exists(absHaxePath) && !FileSystem.isDirectory(absHaxePath)) {
                existing = File.getContent(absHaxePath);
            }
            var content = gen.files.get(key);
            if (content != existing) {
                success('Save $haxePath');
                File.saveContent(absHaxePath, content);
            }
        }

    }

    static public function computeSpineDirs(assetsPath:String):Array<String> {

        var result = [];
        var used = new Map<String,Bool>();

        var allPaths = Files.getFlatDirectory(assetsPath);

        for (path in allPaths) {
            var cleanedPath = Path.normalize(path);
            if (cleanedPath.toLowerCase().indexOf('.spine/') != -1) {
                var spineDir = cleanedPath.substring(0, cleanedPath.toLowerCase().indexOf('.spine/') + '.spine'.length);
                var absSpineDir = Path.join([assetsPath, spineDir]);
                if (!used.exists(spineDir) && FileSystem.exists(absSpineDir) && FileSystem.isDirectory(absSpineDir)) {
                    used.set(spineDir, true);
                    result.push(spineDir.substring(0, spineDir.length));
                }
            }
        }

        return result;

    }

}
