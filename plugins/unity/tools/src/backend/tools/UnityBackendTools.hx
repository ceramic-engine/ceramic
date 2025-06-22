package backend.tools;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Files;
import tools.Helpers.*;
import tools.Images;
import tools.UnityMeta;
import tools.UnityProject;
import tools.UnityShader;

using StringTools;

class UnityBackendTools implements tools.spec.BackendTools {

    public var name(default,null):String = 'unity';

    public var defaultTarget(default,null):String = 'unity';

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
        defines.set('target_path', Json.stringify(hxmlProjectPath));

        var unityProjectPath = UnityProject.resolveUnityProjectPath(cwd, context.project);

        return defines;

    }

    public function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, continueOnFail:Bool = false):Void {

        var task = new backend.tools.tasks.UnitySetup(target, variant, continueOnFail);
        task.run(cwd, args);

    }

    public function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, configIndex:Int = 0):Void {

        var task = new backend.tools.tasks.UnityBuild(target, variant, configIndex);
        task.run(cwd, args);

    }

    public function runUpdate(cwd:String, args:Array<String>):Void {

        // Update/install dependencies

    }

    public function getDstAssetsPath(cwd:String, target:tools.BuildTarget, variant:String):String {

        var outTargetPath = target.outPath('unity', cwd, context.debug, variant);

        return Path.join([cwd, 'project', 'unity', context.project.app.name, 'Assets', 'Ceramic', 'Resources', 'assets']);

    }

    public function getTransformedAssetsPath(cwd:String, target:tools.BuildTarget, variant:String):String {

        var hxmlProjectPath = target.outPath('unity', cwd, context.debug, variant);
        return Path.join([hxmlProjectPath, 'transformedAssets']);

    }

    public function transformAssets(cwd:String, assets:Array<tools.Asset>, target:tools.BuildTarget, variant:String, listOnly:Bool, ?dstAssetsPath:String):Array<tools.Asset> {

        var nonTxtExtensions = [
            'shader' => true,
            'png' => true,
            'jpg' => true,
            'jpeg' => true,
            'gif' => true,
            'm4a' => true,
            'wav' => true,
            'aiff' => true,
            'flac' => true,
            'mp3' => true,
            'mp4' => true,
            'mov' => true,
            'zip' => true,
            'ogg' => true,
            'bin' => true
        ];

        var newAssets:Array<tools.Asset> = [];
        var validDstPaths:Map<String,Bool> = new Map();
        if (dstAssetsPath == null) {
            dstAssetsPath = getDstAssetsPath(cwd, target, variant);
        }

        var unityProjectPath = UnityProject.resolveUnityProjectPath(cwd, context.project);
        print('Unity Editor project path: ' + unityProjectPath);
        dstAssetsPath = Path.join([unityProjectPath, 'Assets', 'Ceramic', 'Resources', 'assets']);

        var sounds:Map<String,tools.Asset> = new Map();
        for (asset in assets) {
            var srcPath = asset.absolutePath;
            var dotIndex = srcPath.lastIndexOf('.');
            var ext = '';
            if (dotIndex != -1) {
                ext = srcPath.substr(dotIndex + 1).toLowerCase();
            }
            if (ext == 'mp3' || ext == 'wav' || ext == 'ogg') {
                sounds.set(srcPath, asset);
            }
        }

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

            // Avoid copying MP3 if we have wav or ogg because MP3
            // is not allowing clean loops in unity
            if (ext == 'mp3') {
                var asOgg = srcPath.substr(0, dotIndex) + '.ogg';
                if (sounds.exists(asOgg)) continue;
                var asWav = srcPath.substr(0, dotIndex) + '.wav';
                if (sounds.exists(asWav)) continue;
            }

            if (!nonTxtExtensions.exists(ext)) {
                // Unity needs a .txt extension to treat an asset as text, let's add it
                dstPath += '.txt';
            }

            if (!listOnly && ext == 'shader') {
                // If it's a shader, check if it's a multi-texture template
                // and process it if needed
                var shaderContent = sys.io.File.getContent(srcPath);
                if (UnityShader.isMultiTextureTemplate(shaderContent)) {
                    for (n in [8]) {
                        var processedPath = dstPath.substring(0, dstPath.length - ext.length - 1) + '_mt' + n + '.shader';
                        validDstPaths.set(processedPath, true);
                        if (!tools.Files.haveSameLastModified(srcPath, processedPath)) {
                            var processed = UnityShader.processMultiTextureTemplate(shaderContent, n);
                            File.saveContent(processedPath, processed);
                            tools.Files.setToSameLastModified(srcPath, processedPath);
                        }
                    }
                }
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

                if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
                    // Generate texture meta if none exists already
                    // (needed to ensure we have correct texture settings on unity side)
                    var dstMetaPath = dstPath + '.meta';
                    if (!sys.FileSystem.exists(dstMetaPath)) {
                        var metaContent = UnityMeta.generateTextureMeta();
                        File.saveContent(dstMetaPath, metaContent);
                    }
                }

                tools.Files.setToSameLastModified(srcPath, dstPath);
            }

            validDstPaths.set(dstPath, true);
            newAssets.push(new tools.Asset(asset.name, dstAssetsPath));
        }

        if (!listOnly) {
            // Remove outdated assets (keep meta files of remaining assets)
            //
            for (name in tools.Files.getFlatDirectory(dstAssetsPath)) {
                var dstPath = Path.join([dstAssetsPath, name]);
                var isMeta = name.endsWith('.meta');
                if (!isMeta && !validDstPaths.exists(dstPath)) {
                    tools.Files.deleteRecursive(dstPath);
                }
                else if (isMeta && !validDstPaths.exists(dstPath.substring(0, dstPath.length - '.meta'.length))) {
                    tools.Files.deleteRecursive(dstPath);
                }
            }
            tools.Files.removeEmptyDirectories(dstAssetsPath);
        }

        return newAssets;

    }

    public function transformIcons(cwd:String, appIcon:String, appIconFlat:String, target:tools.BuildTarget, variant:String):Void {

        // TODO

    }

}
