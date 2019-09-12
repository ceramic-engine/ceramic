package backend.tools;

import tools.Helpers.*;
import tools.Images;
import tools.Files;
import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

using StringTools;

class BackendTools implements tools.spec.BackendTools {

    public var name(default,null):String = 'luxe';

    public var defaultTarget(default,null):String = 'web';

    public function new() {}

    public function init(tools:tools.Tools):Void {

        // Custom setup

    } //init

    public function getBuildTargets():Array<tools.BuildTarget> {

        var targets:Array<tools.BuildTarget> = [];

        targets.push({
            name: 'web',
            displayName: 'Web',
            configs: [
                Run('Run Web'),
                Build('Build Web'),
                Clean('Clean Web')
            ]
        });

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

        targets.push({
            name: 'ios',
            displayName: 'iOS',
            configs: [
                Run('Run iOS'),
                Build('Build iOS'),
                Clean('Clean iOS')
            ]
        });

        targets.push({
            name: 'android',
            displayName: 'Android',
            configs: [
                Run('Run Android'),
                Build('Build Android'),
                Clean('Clean Android')
            ]
        });

        return targets;

    } //getBuildConfigs

    public function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        var hxmlPath = Path.join([flowProjectPath, 'project.hxml']);
        
        /*
        var cmdArgs = ['run', 'flow', 'info', target.name, '--hxml'];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('--debug');

        var res = haxelib(cmdArgs, { mute: true, cwd: flowProjectPath });
        
        if (res.status != 0) {
            fail('Error when getting project hxml.');
        }

        var output = res.stdout;
        return output;
        */

        if (!FileSystem.exists(hxmlPath)) {
            return null;
        }

        return File.getContent(hxmlPath);
        
        /*if (output == null) return null;

        var mainPart = '-main luxe.Game';
        var mainIndex = output.indexOf(mainPart);
        if (mainIndex != -1) {
            output = output.substring(0, mainIndex) + '-main Main' + output.substr(mainIndex + mainPart.length);
        }

        return output + " -D luxe_no_main --macro server.setModuleCheckPolicy(['luxe','snow','phoenix','glew','sdl','timestamp','opengl','ogg', 'openal','stb'], [NoCheckShadowing, NoCheckDependencies], true)";*/

    } //getHxml

    public function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);

        return flowProjectPath;

    } //getHxmlCwd

    public function getTargetDefines(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):Map<String,String> {

        var defines = new Map<String,String>();

        defines.set('target', target.name);
        defines.set(target.name, '');

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        defines.set('target_path', flowProjectPath);
        defines.set('target_assets_path', Path.join([flowProjectPath, 'assets']));

        return defines;

    } //getTargetDefines

    public function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, continueOnFail:Bool = false):Void {

        var task = new backend.tools.tasks.Setup(target, variant, continueOnFail);
        task.run(cwd, args);

    } //runSetup

    public function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, configIndex:Int = 0):Void {

        var task = new backend.tools.tasks.Build(target, variant, configIndex);
        task.run(cwd, args);

    } //runBuild

    public function runUpdate(cwd:String, args:Array<String>):Void {

        // Update/install luxe (and dependencies)

        var output = ''+haxelib(['list'], { mute: true }).stdout;
        var libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        /*if (!libs.exists('snowfall')) {
            if (haxelib(['install', 'snowfall']).status != 0) {
                fail('Error when trying to install snowfall.');
            }
        }

        haxelib(['run', 'snowfall', 'update', 'luxe']);*/

        for (lib in ['flow', 'snow', 'luxe', 'linc_ogg', 'linc_openal', 'linc_opengl', 'linc_sdl', 'linc_stb', 'linc_timestamp']) {
            haxelib(['dev', lib, Path.join([context.ceramicGitDepsPath, lib])]);
        }

        // Check that luxe is available
        //
        output = ''+haxelib(['list'], { mute: true }).stdout;
        libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        if (!libs.exists('luxe')) {
            // Luxe not available?
            fail('Failed to update or install luxe or some of its dependency. Check log.');
        }

    } //runUpdate

    public function transformAssets(cwd:String, assets:Array<tools.Asset>, target:tools.BuildTarget, variant:String, listOnly:Bool, ?dstAssetsPath:String):Array<tools.Asset> {

        var newAssets:Array<tools.Asset> = [];
        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        var validDstPaths:Map<String,Bool> = new Map();
        var assetsChanged = false;

        if (dstAssetsPath == null) {
            switch (target.name) {
                case 'mac':
                    dstAssetsPath = Path.join([cwd, 'project', 'mac', context.project.app.name + '.app', 'Contents', 'Resources', 'assets']);
                case 'ios':
                    dstAssetsPath = Path.join([cwd, 'project', 'ios', 'project', 'assets', 'assets']);
                case 'android':
                    dstAssetsPath = Path.join([cwd, 'project', 'android', 'app', 'src', 'main', 'assets', 'assets']);
                case 'windows' | 'linux' | 'web':
                    dstAssetsPath = Path.join([cwd, 'project', target.name, 'assets']);
                default:
                    dstAssetsPath = Path.join([flowProjectPath, 'assets']);
            }
        }

        // Add/update missing assets
        //
        for (asset in assets) {

            var srcPath = asset.absolutePath;
            var dstPath = Path.join([dstAssetsPath, asset.name]);

            if (!listOnly && !tools.Files.haveSameLastModified(srcPath, dstPath)) {

                // Assets did change
                assetsChanged = true;

                // Copy and set to same date
                if (sys.FileSystem.exists(dstPath)) {
                    sys.FileSystem.deleteFile(dstPath);
                }
                var dir = Path.directory(dstPath);
                if (!sys.FileSystem.exists(dir)) {
                    sys.FileSystem.createDirectory(dir);
                }

                if (srcPath.toLowerCase().endsWith('.png')) {
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
            // Remove outdated assets
            //
            for (name in tools.Files.getFlatDirectory(dstAssetsPath)) {
                if (name != '_assets.json') {
                    var dstPath = Path.join([dstAssetsPath, name]);
                    if (!validDstPaths.exists(dstPath)) {

                        // Assets did change
                        assetsChanged = true;

                        tools.Files.deleteRecursive(dstPath);
                    }
                }
            }
            tools.Files.removeEmptyDirectories(dstAssetsPath);
        }

        if (assetsChanged) {
            context.assetsChanged = true;
        }

        /*// Copy rtti data (if any)
        var rttiPath = Path.join([flowProjectPath, '.cache', 'rtti']);
        if (FileSystem.exists(rttiPath)) {
            tools.Files.copyDirectory(rttiPath, Path.join([dstAssetsPath, 'rtti']), true);
        }*/

        return newAssets;

    } //transformAssets

    public function transformIcons(cwd:String, appIcon:String, target:tools.BuildTarget, variant:String):Void {

        var toTransform:Array<TargetImage> = [];
        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        var iconsChanged = false;

        switch (target.name) {
            case 'mac':
                toTransform.push({
                    path: 'mac/app.iconset/icon_16x16.png',
                    width: 16,
                    height: 16
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_16x16@2x.png',
                    width: 32,
                    height: 32
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_32x32.png',
                    width: 32,
                    height: 32
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_32x32@2x.png',
                    width: 64,
                    height: 64
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_128x128.png',
                    width: 128,
                    height: 128
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_128x128@2x.png',
                    width: 256,
                    height: 256
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_256x256.png',
                    width: 256,
                    height: 256
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_256x256@2x.png',
                    width: 512,
                    height: 512
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_512x512.png',
                    width: 512,
                    height: 512
                });
                toTransform.push({
                    path: 'mac/app.iconset/icon_512x512@2x.png',
                    width: 1024,
                    height: 1024
                });
            
            case 'windows':
                toTransform.push({
                    path: 'windows/app.ico',
                    width: 256,
                    height: 256
                });
            
            case 'web':
                toTransform.push({
                    path: 'web/app.png',
                    width: 128,
                    height: 128
                });
            
            case 'ios':
                // TODO
            
            case 'android':
                // TODO

            default:
                // Nothing to do?
        }

        // Create full paths
        for (entry in toTransform) {
            entry.path = Path.join([flowProjectPath, 'icons', entry.path]);

            // Compare with original
            if (!Files.haveSameLastModified(appIcon, entry.path)) {

                // Icons did change
                iconsChanged = true;

                if (entry.path.endsWith('.png')) {

                    // Resize
                    Images.resize(appIcon, entry.path, entry.width, entry.height);

                } else if (entry.path.endsWith('.ico')) {

                    // Create ico
                    Images.createIco(appIcon, entry.path, entry.width, entry.height);
                }

                // Set to same last modified
                Files.setToSameLastModified(appIcon, entry.path);
            }
        }

        if (iconsChanged) {
            context.iconsChanged = true;
        }

    } //transformIcons

} //Config
