package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class Angle extends tools.Task {

    static final RE_ANGLE_ASSET = ~/^angle-(mac|windows|linux|ios|android)-(.*?).(zip|tar\.gz)$/;

    override public function info(cwd:String):String {

        return "Manage Angle dependency";

    }

    override function run(cwd:String, args:Array<String>):Void {

        final action = if (args.contains('update')) {
            'update';
        }
        else if (args.contains('download')) {
            'download';
        }
        else {
            fail('Unknown action. Use "angle update" or "angle download"');
            null;
        }

        if (action == 'update' || action == 'download') {

            var release:Dynamic = null;
            if (action == 'update') {
                print('Resolving latest ANGLE builds available...');
                release = Github.resolveLatestRelease('jeremyfa', 'build-angle');
                success('Latest release: ' + release.name + ' / https://github.com/jeremyfa/build-angle/releases/tag/' + release.tag_name);
            }
            else if (action == 'download') {
                print('Downloading ANGLE builds...');
                final commit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/angle'])).trim().substr(0,7);
                release = Github.resolveReleaseForTag('jeremyfa', 'build-angle', 'angle-' + commit);
                success('Matched release: ' + release.name + ' / https://github.com/jeremyfa/build-angle/releases/tag/' + release.tag_name);
            }

            final assets:Array<Dynamic> = release.assets;
            final angleShortCommit = Std.string(release.tag_name).split('-')[1];
            final angleBinaryPath = Path.join([context.ceramicRootPath, 'bin/angle']);
            if (!FileSystem.exists(angleBinaryPath)) {
                FileSystem.createDirectory(angleBinaryPath);
            }

            if (action == 'update') {
                Download.downloadFile(
                    'https://github.com/jeremyfa/build-angle/releases/download/' + release.tag_name + '/commit.txt',
                    Path.join([context.ceramicRootPath, 'bin/.commit/angle']),
                );
            }
            final angleLongCommit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/angle'])).trim();

            if (action == 'update') {
                File.saveContent(Path.join([context.ceramicRootPath, 'bin/.commit/angle']), angleLongCommit);
            }

            for (asset in assets) {
                if (RE_ANGLE_ASSET.match(asset.name)) {
                    final os = RE_ANGLE_ASSET.matched(1);
                    final variant = RE_ANGLE_ASSET.matched(2);
                    final ext = RE_ANGLE_ASSET.matched(3);
                    var assetLocalName = 'angle-$os-$variant.$ext';
                    var assetLocalNameNoExt = 'angle-$os-$variant';
                    final assetLocalPath = Path.join([angleBinaryPath, assetLocalName]);
                    final assetLocalPathDir = Path.join([angleBinaryPath, assetLocalNameNoExt]);
                    final assetLocalCommitFile = Path.join([assetLocalPathDir, 'commit.txt']);

                    #if windows
                    if (os != 'windows' && os != 'android') {
                        continue;
                    }
                    #end
                    #if mac
                    if (os != 'mac' && os != 'ios' && os != 'android' && os != 'windows') {
                        continue;
                    }
                    #end
                    #if linux
                    if (os != 'linux' && os != 'android' && os != 'windows') {
                        continue;
                    }
                    #end

                    if (!FileSystem.exists(assetLocalCommitFile) || angleShortCommit != File.getContent(assetLocalCommitFile).trim().substring(0,7)) {
                        Download.downloadFile(
                            'https://github.com/jeremyfa/build-angle/releases/download/' + release.tag_name + '/' + asset.name,
                            assetLocalPath,
                        );
                        if (ext == 'zip') {
                            if (FileSystem.exists(assetLocalPathDir)) {
                                Files.deleteRecursive(assetLocalPathDir);
                            }
                            FileSystem.createDirectory(assetLocalPathDir);
                            Zip.unzipFile(assetLocalPath, assetLocalPathDir, angleBinaryPath);
                        }
                        else if (ext == 'tar.gz') {
                            if (FileSystem.exists(assetLocalPathDir)) {
                                Files.deleteRecursive(assetLocalPathDir);
                            }
                            FileSystem.createDirectory(assetLocalPathDir);
                            TarGz.untarGzFile(assetLocalPath, assetLocalPathDir, angleBinaryPath);
                        }
                        FileSystem.deleteFile(assetLocalPath);
                    }
                    else {
                        print('Already up to date: ' + assetLocalNameNoExt);
                    }

                    #if mac
                    if (os == 'ios') {
                        fixIosSimulatorInfoPlists(assetLocalPathDir);
                    }
                    #end
                }
            }
        }

    }

    #if mac

    /**
     * The simulator build of ANGLE doesn't emit an Info.plist in its
     * framework bundles (the device build does), and Xcode refuses to
     * embed a framework without one. Synthesize the missing Info.plist
     * from the device slice with the platform fields adjusted.
     */
    static function fixIosSimulatorInfoPlists(iosAnglePath:String):Void {

        for (framework in ['libEGL', 'libGLESv2']) {
            final xcframeworkPath = Path.join([iosAnglePath, framework + '.xcframework']);
            if (!FileSystem.exists(xcframeworkPath))
                continue;

            var devicePlist = null;
            final missingSimulatorPlists = [];
            for (slice in FileSystem.readDirectory(xcframeworkPath)) {
                if (!slice.startsWith('ios-'))
                    continue;
                final plistPath = Path.join([xcframeworkPath, slice, framework + '.framework', 'Info.plist']);
                if (slice.endsWith('-simulator')) {
                    if (!FileSystem.exists(plistPath) && FileSystem.exists(Path.directory(plistPath))) {
                        missingSimulatorPlists.push(plistPath);
                    }
                }
                else if (FileSystem.exists(plistPath)) {
                    devicePlist = plistPath;
                }
            }

            if (devicePlist == null)
                continue;

            for (plistPath in missingSimulatorPlists) {
                print('Add missing Info.plist to $framework simulator slice');
                File.copy(devicePlist, plistPath);
                command('/usr/libexec/PlistBuddy', ['-c', 'Set :CFBundleSupportedPlatforms:0 iPhoneSimulator', plistPath], { mute: true });
                command('/usr/libexec/PlistBuddy', ['-c', 'Set :DTPlatformName iphonesimulator', plistPath], { mute: true });
                final sdkName = command('/usr/libexec/PlistBuddy', ['-c', 'Print :DTSDKName', plistPath], { mute: true }).stdout;
                if (sdkName != null && sdkName.trim().startsWith('iphoneos')) {
                    command('/usr/libexec/PlistBuddy', ['-c', 'Set :DTSDKName ' + sdkName.trim().replace('iphoneos', 'iphonesimulator'), plistPath], { mute: true });
                }
            }
        }

    }

    #end

}
