package backend.tools;

import tools.Helpers.*;
import tools.Images;
import tools.Files;
import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

using StringTools;

class BackendTools implements tools.spec.BackendTools {

    public var name(default,null):String = 'unity';

    public var defaultTarget(default,null):String = null;

    public function new() {}

    public function init(tools:tools.Tools):Void {

        // Custom setup

    }

    public function getBuildTargets():Array<tools.BuildTarget> {

        var targets:Array<tools.BuildTarget> = [];
        
        targets.push({
            name: 'unity',
            displayName: 'Unity',
            configs: [
                Run('Run Unity'),
                Build('Build Unity'),
                Clean('Clean Unity')
            ]
        });

        // For now, let's focus on Node.js implementation
        /*

        var os = Sys.systemName();

        if (os == 'Mac') {
            targets.push({
                name: 'mac',
                displayName: 'Mac',
                configs: [
                    Run('Run Mac'),
                    Build('Build Mac'),
                    Clean('Clean Mac')
                ]
            });
        }
        else if (os == 'Windows') {
            targets.push({
                name: 'windows',
                displayName: 'Windows',
                configs: [
                    Run('Run Windows'),
                    Build('Build Windows'),
                    Clean('Clean Windows')
                ]
            });
        }
        else if (os == 'Linux') {
            targets.push({
                name: 'linux',
                displayName: 'Linux',
                configs: [
                    Run('Run Linux'),
                    Build('Build Linux'),
                    Clean('Clean Linux')
                ]
            });
        }
        */

        return targets;

    }

    public function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);
        var hxmlPath = Path.join([hxmlProjectPath, 'build.hxml']);

        if (FileSystem.exists(hxmlPath)) {
            return File.getContent(hxmlPath);
        }

        return null;

    }

    public function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);

        return hxmlProjectPath;

    }

    public function getTargetDefines(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):Map<String,String> {

        var defines = new Map<String,String>();

        defines.set('target', target.name);
        defines.set(target.name, '');

        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);
        defines.set('target_path', hxmlProjectPath);

        if (context.project != null
        && context.project.app != null
        && context.project.app.unity != null
        && context.project.app.unity.project != null) {
            // Allow to point to unity assets directly
            var unityProjectPath:String = context.project.app.unity.project;
            if (!Path.isAbsolute(unityProjectPath)) {
                unityProjectPath = Path.join([cwd, unityProjectPath]);
            }
            defines.set('target_assets_path', Path.join([unityProjectPath, 'Assets/Ceramic/Resources/assets']));
        } else {
            defines.set('target_assets_path', Path.join([hxmlProjectPath, 'assets']));
        }

        return defines;

    }

    public function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, continueOnFail:Bool = false):Void {

        var task = new backend.tools.tasks.Setup(target, variant, continueOnFail);
        task.run(cwd, args);

    }

    public function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, configIndex:Int = 0):Void {

        var task = new backend.tools.tasks.Build(target, variant, configIndex);
        task.run(cwd, args);

    }

    public function runUpdate(cwd:String, args:Array<String>):Void {

        // Update/install dependencies

    }

    public function transformAssets(cwd:String, assets:Array<tools.Asset>, target:tools.BuildTarget, variant:String, listOnly:Bool, ?dstAssetsPath:String):Array<tools.Asset> {

        var txtExtensions = [
            'vert' => true,
            'frag' => true,
            'fnt' => true,
            'json' => true
        ];

        var newAssets:Array<tools.Asset> = [];
        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);
        var validDstPaths:Map<String,Bool> = new Map();
        if (dstAssetsPath == null) {
            dstAssetsPath = Path.join([hxmlProjectPath, 'assets']);
        }
        if (context.project != null
        && context.project.app != null
        && context.project.app.unity != null
        && context.project.app.unity.project != null) {
            // Allow to copy assets right into Unity project
            var unityProjectPath:String = context.project.app.unity.project;
            if (!Path.isAbsolute(unityProjectPath)) {
                unityProjectPath = Path.join([cwd, unityProjectPath]);
            }
            dstAssetsPath = Path.join([unityProjectPath, 'Assets/Ceramic/Resources/assets']);
        } else {
            dstAssetsPath = Path.join([hxmlProjectPath, 'assets']);
        }

        trace('context.project: ' + context.project.app.unity.project);

        // Add/update missing assets
        //
        for (asset in assets) {

            var srcPath = asset.absolutePath;
            var dstPath = Path.join([dstAssetsPath, asset.name]);

            var dotIndex = srcPath.lastIndexOf('.');
            var ext = '';
            if (dotIndex != -1) {
                ext = srcPath.substr(dotIndex + 1).toLowerCase();
            }

            if (txtExtensions.exists(ext)) {
                // Unity needs a .txt extension to treat an asset as text, let's add it
                dstPath += '.txt';
            }

            if (!listOnly && !tools.Files.haveSameLastModified(srcPath, dstPath)) {
                // Copy and set to same date
                if (sys.FileSystem.exists(dstPath)) {
                    sys.FileSystem.deleteFile(dstPath);
                }
                var dir = Path.directory(dstPath);
                if (!sys.FileSystem.exists(dir)) {
                    sys.FileSystem.createDirectory(dir);
                }

                if (ext == 'png') {
                    // If it's a png with alpha channel, premultiply its alpha
                    var raw = Images.getRaw(srcPath);
                    if (raw.channels == 4) {
                        Images.premultiplyAlpha(raw.pixels);
                    }
                    Images.saveRaw(dstPath, raw);
                }
                else {
                    // Otherwise just copy the file
                    sys.io.File.copy(srcPath, dstPath);
                }

                tools.Files.setToSameLastModified(srcPath, dstPath);
            }

            validDstPaths.set(dstPath, true);
            newAssets.push(new tools.Asset(asset.name, dstAssetsPath));
        }

        if (!listOnly) {
            // TODO don't delete meta files
            // Remove outdated assets
            //
            for (name in tools.Files.getFlatDirectory(dstAssetsPath)) {
                var dstPath = Path.join([dstAssetsPath, name]);
                if (!validDstPaths.exists(dstPath)) {
                    tools.Files.deleteRecursive(dstPath);
                }
            }
            tools.Files.removeEmptyDirectories(dstAssetsPath);
        }

        // Copy rtti data (if any)
        /*var rttiPath = Path.join([hxmlProjectPath, '.cache', 'rtti']);
        if (FileSystem.exists(rttiPath)) {
            tools.Files.copyDirectory(rttiPath, Path.join([dstAssetsPath, 'rtti']), true);
        }*/

        return newAssets;

    }

    public function transformIcons(cwd:String, appIcon:String, target:tools.BuildTarget, variant:String):Void {

        // TODO

    }

}
