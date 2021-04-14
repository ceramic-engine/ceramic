package backend.tools;

import tools.Helpers.*;
import tools.Images;
import tools.Files;
import haxe.io.Path;

import sys.FileSystem;
import sys.io.File;

using StringTools;

class BackendTools implements tools.spec.BackendTools {

    public var name(default,null):String = 'clay';

    public var defaultTarget(default,null):String = 'web';

    public function new() {}

    public function init(tools:tools.Tools):Void {

        // Custom setup

    }

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

        // targets.push({
        //     name: 'cppia',
        //     displayName: 'CPPIA',
        //     configs: [
        //         Run('Run CPPIA'),
        //         Build('Build CPPIA'),
        //         Clean('Clean CPPIA')
        //     ]
        // });

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

    }

    public function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var outTargetPath = target.outPath('clay', cwd, context.debug, variant);
        var hxmlPath = Path.join([outTargetPath, 'project.hxml']);

        if (!FileSystem.exists(hxmlPath)) {
            return null;
        }

        return File.getContent(hxmlPath);

    }

    public function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var outTargetPath = target.outPath('clay', cwd, context.debug, variant);

        return outTargetPath;

    }

    public function getTargetDefines(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):Map<String,String> {

        var defines = new Map<String,String>();

        defines.set('target', target.name);
        defines.set(target.name, '');

        switch target.name {
            case 'android' | 'ios':
                defines.set('mobile', '');
            case 'mac' | 'windows' | 'linux':
                defines.set('desktop', '');
            default:
        }

        var outTargetPath = target.outPath('clay', cwd, context.debug, variant);
        defines.set('target_path', outTargetPath);
        defines.set('target_assets_path', Path.join([outTargetPath, 'assets']));

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

        // Update/install clay (and dependencies)

        var output = ''+haxelib(['list'], { mute: true }).stdout;
        var libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        var requiredLibs = backend.tools.tasks.Setup.requiredLibs;

        for (lib in requiredLibs) {
            haxelib(['dev', lib, Path.join([context.ceramicGitDepsPath, lib])]);
        }

        // Check that required libs are available
        //
        output = ''+haxelib(['list'], { mute: true }).stdout;
        libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        for (lib in requiredLibs) {
            if (!libs.exists(lib)) {
                // Lib not available?
                fail('Failed to update or install $lib. Check log.');
            }
        }

    }

    public function transformAssets(cwd:String, assets:Array<tools.Asset>, target:tools.BuildTarget, variant:String, listOnly:Bool, ?dstAssetsPath:String):Array<tools.Asset> {

        var newAssets:Array<tools.Asset> = [];
        var outTargetPath = target.outPath('clay', cwd, context.debug, variant);
        var validDstPaths:Map<String,Bool> = new Map();
        var assetsChanged = false;
        
        var assetsPrefix = '';
        if (context.defines.get('ceramic_assets_prefix') != null) {
            assetsPrefix = context.defines.get('ceramic_assets_prefix');
        }
        var assetsPrefixIsPath = assetsPrefix.indexOf('/') != -1 || assetsPrefix.indexOf('\\') != -1;
        var premultiplyAlpha = (target.name != 'web');

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
                    dstAssetsPath = Path.join([outTargetPath, 'assets']);
            }
        }

        // Add/update missing assets
        //
        for (asset in assets) {

            var srcPath = asset.absolutePath;
            var dstPath = Path.join([dstAssetsPath, assetsPrefix + asset.name]);

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

                if (premultiplyAlpha && srcPath.toLowerCase().endsWith('.png')) {
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
            if (assetsPrefixIsPath) {
                newAssets.push(new tools.Asset(assetsPrefix + asset.name, Path.join([dstAssetsPath, assetsPrefix])));
            }
            else {
                newAssets.push(new tools.Asset(assetsPrefix + asset.name, dstAssetsPath));
            }
        }

        if (!listOnly) {
            // Remove outdated assets
            //
            var assetsJsonName = assetsPrefix + '_assets.json';

            for (name in tools.Files.getFlatDirectory(dstAssetsPath)) {
                if (name != assetsJsonName) {
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

        return newAssets;

    }

    public function transformIcons(cwd:String, appIcon:String, appIconFlat:String, target:tools.BuildTarget, variant:String):Void {

        var toTransform:Array<TargetImage> = [];
        var outTargetPath = target.outPath('clay', cwd, context.debug, variant);
        var outIconsPath = Path.join([outTargetPath, 'icons']);
        var iconsChanged = false;

        switch (target.name) {
            case 'mac':
                // Icon needs to be generated manually for now

            case 'linux':
                // Icon needs to be generated manually for now
            
            case 'windows':
                toTransform.push({
                    path: 'windows/app.ico',
                    width: 256,
                    height: 256
                });
            
            case 'web':
                outIconsPath = Path.join([cwd, 'project/web']);
                toTransform.push({
                    path: 'favicon.png',
                    width: 128,
                    height: 128
                });
                toTransform.push({
                    path: 'touch-icon.png',
                    width: 128,
                    height: 128,
                    flat: true
                });
            
            case 'ios':
                // Might move this to ios plugin later
                outIconsPath = Path.join([cwd, 'project/ios/project/Images.xcassets/AppIcon.appiconset']);
                toTransform.push({
                    path: 'Icon-App-20x20@1x.png',
                    width: 20,
                    height: 20,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-20x20@2x.png',
                    width: 20 * 2,
                    height: 20 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-20x20@3x.png',
                    width: 20 * 3,
                    height: 20 * 3,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-29x29@1x.png',
                    width: 29,
                    height: 29,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-29x29@2x.png',
                    width: 29 * 2,
                    height: 29 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-29x29@3x.png',
                    width: 29 * 3,
                    height: 29 * 3,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-40x40@1x.png',
                    width: 40,
                    height: 40,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-40x40@2x.png',
                    width: 40 * 2,
                    height: 40 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-40x40@3x.png',
                    width: 40 * 3,
                    height: 40 * 3,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-57x57@1x.png',
                    width: 57,
                    height: 57,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-57x57@2x.png',
                    width: 57 * 2,
                    height: 57 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-60x60@2x.png',
                    width: 60 * 2,
                    height: 60 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-60x60@3x.png',
                    width: 60 * 3,
                    height: 60 * 3,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-72x72@1x.png',
                    width: 72,
                    height: 72,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-72x72@2x.png',
                    width: 72 * 2,
                    height: 72 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-76x76@1x.png',
                    width: 76,
                    height: 76,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-76x76@2x.png',
                    width: 76 * 2,
                    height: 76 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-App-83.5x83.5@2x.png',
                    width: 167,
                    height: 167,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-Small-50x50@1x.png',
                    width: 50,
                    height: 50,
                    flat: true
                });
                toTransform.push({
                    path: 'Icon-Small-50x50@2x.png',
                    width: 50 * 2,
                    height: 50 * 2,
                    flat: true
                });
                toTransform.push({
                    path: 'ItunesArtwork@2x.png',
                    width: 1024,
                    height: 1024,
                    flat: true
                });
            
            case 'android':
                // Might move this to android plugin later
                outIconsPath = Path.join([cwd, 'project/android/app/src/main/res']);
                toTransform.push({
                    path: 'mipmap-ldpi/ic_launcher.png',
                    width: 36,
                    height: 36,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-mdpi/ic_launcher.png',
                    width: 48,
                    height: 48,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-mdpi/ic_launcher_foreground.png',
                    width: 72,
                    height: 72,
                    padLeft: 18,
                    padRight: 18,
                    padTop: 18,
                    padBottom: 18,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-hdpi/ic_launcher.png',
                    width: 72,
                    height: 72,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-hdpi/ic_launcher_foreground.png',
                    width: 110,
                    height: 110,
                    padLeft: 26,
                    padRight: 26,
                    padTop: 26,
                    padBottom: 26,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-xhdpi/ic_launcher.png',
                    width: 96,
                    height: 96,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-xhdpi/ic_launcher_foreground.png',
                    width: 146,
                    height: 146,
                    padLeft: 35,
                    padRight: 35,
                    padTop: 35,
                    padBottom: 35,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-xxhdpi/ic_launcher.png',
                    width: 144,
                    height: 144,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-xxhdpi/ic_launcher_foreground.png',
                    width: 220,
                    height: 220,
                    padLeft: 52,
                    padRight: 52,
                    padTop: 52,
                    padBottom: 52,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-xxxhdpi/ic_launcher.png',
                    width: 192,
                    height: 192,
                    flat: true
                });
                toTransform.push({
                    path: 'mipmap-xxxhdpi/ic_launcher_foreground.png',
                    width: 294,
                    height: 294,
                    padLeft: 69,
                    padRight: 69,
                    padTop: 69,
                    padBottom: 69,
                    flat: true
                });

            default:
                // Nothing to do?
        }

        // Create full paths
        for (entry in toTransform) {
            entry.path = Path.join([outIconsPath, entry.path]);

            var usedIcon = entry.flat ? appIconFlat : appIcon;

            // Compare with original
            if (!Files.haveSameLastModified(usedIcon, entry.path)) {

                // Icons did change
                iconsChanged = true;

                if (entry.path.endsWith('.png')) {

                    // Resize
                    if (entry.padTop != null) {
                        Images.resize(usedIcon, entry.path, entry.width, entry.height, entry.padTop, entry.padRight, entry.padBottom, entry.padLeft);
                    }
                    else {
                        Images.resize(usedIcon, entry.path, entry.width, entry.height);
                    }

                } else if (entry.path.endsWith('.ico')) {

                    // Create ico
                    Images.createIco(usedIcon, entry.path, entry.width, entry.height);
                }

                // Set to same last modified
                Files.setToSameLastModified(usedIcon, entry.path);
            }
        }

        if (iconsChanged) {
            context.iconsChanged = true;
        }

    }

}
