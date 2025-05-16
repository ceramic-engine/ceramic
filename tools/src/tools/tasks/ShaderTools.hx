package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class ShaderTools extends tools.Task {

    static final RE_SHADERTOOLS_ASSET = ~/^shader-tools-(mac|windows|linux|ios|android)-(.*?).(zip|tar\.gz)$/;

    override public function info(cwd:String):String {

        return "Manage shader tools dependency (SPIRV-Cross & shaderc";

    }

    override function run(cwd:String, args:Array<String>):Void {

        final action = if (args.contains('update')) {
            'update';
        }
        else if (args.contains('download')) {
            'download';
        }
        else {
            fail('Unknown action. Use "shader tools update" or "shader tools download"');
            null;
        }

        if (action == 'update' || action == 'download') {

            var release:Dynamic = null;
            if (action == 'update') {
                print('Resolving latest shader tools builds available...');
                release = Github.resolveLatestRelease('jeremyfa', 'shader-tools');
                success('Latest release: ' + release.name + ' / https://github.com/jeremyfa/shader-tools/releases/tag/' + release.tag_name);
            }
            else if (action == 'download') {
                print('Downloading shader tools builds...');
                final glslcCommit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/glslc'])).trim().substr(0,7);
                final spirvCrossCommit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/spirv-cross'])).trim().substr(0,7);
                release = Github.resolveReleaseForTag('jeremyfa', 'shader-tools', 'shader-tools-' + glslcCommit + '-' + spirvCrossCommit);
                success('Matched release: ' + release.name + ' / https://github.com/jeremyfa/shader-tools/releases/tag/' + release.tag_name);
            }

            final assets:Array<Dynamic> = release.assets;
            final glslcShortCommit = Std.string(release.tag_name).split('-')[2];
            final spirvShortCommit = Std.string(release.tag_name).split('-')[3];
            final binaryPath = Path.join([context.ceramicRootPath, 'bin']);
            if (!FileSystem.exists(binaryPath)) {
                FileSystem.createDirectory(binaryPath);
            }

            if (action == 'update') {
                Download.downloadFile(
                    'https://github.com/jeremyfa/shader-tools/releases/download/' + release.tag_name + '/shaderc-commit.txt',
                    Path.join([context.ceramicRootPath, 'bin/.commit/glslc']),
                );
                Download.downloadFile(
                    'https://github.com/jeremyfa/shader-tools/releases/download/' + release.tag_name + '/spirv-cross-commit.txt',
                    Path.join([context.ceramicRootPath, 'bin/.commit/spirv-cross']),
                );
            }
            final glslcLongCommit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/glslc'])).trim();
            final spirvLongCommit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/spirv-cross'])).trim();

            if (action == 'update') {
                File.saveContent(Path.join([context.ceramicRootPath, 'bin/.commit/glslc']), glslcLongCommit);
                File.saveContent(Path.join([context.ceramicRootPath, 'bin/.commit/spirv-cross']), spirvLongCommit);
            }

            for (asset in assets) {
                if (RE_SHADERTOOLS_ASSET.match(asset.name)) {
                    final os = RE_SHADERTOOLS_ASSET.matched(1);
                    final variant = RE_SHADERTOOLS_ASSET.matched(2);
                    final ext = RE_SHADERTOOLS_ASSET.matched(3);
                    var assetLocalName = 'shader-tools.$ext';
                    var assetLocalNameNoExt = 'shader-tools';
                    final assetLocalPath = Path.join([binaryPath, assetLocalName]);
                    final assetLocalPathDir = Path.join([binaryPath, assetLocalNameNoExt]);
                    final assetLocalGlslcCommitFile = Path.join([assetLocalPathDir, 'glslc-commit.txt']);
                    final assetLocalSpirvCommitFile = Path.join([assetLocalPathDir, 'spirv-cross-commit.txt']);

                    #if (windows && !windows_arm64)
                    if (os != 'windows' && variant != 'x64') {
                        continue;
                    }
                    #end
                    #if (windows && windows_arm64)
                    if (os != 'windows' && variant != 'arm64') {
                        continue;
                    }
                    #end
                    #if mac
                    if (os != 'mac') {
                        continue;
                    }
                    #end
                    #if (linux && !linux_arm64)
                    if (os != 'linux' && variant != 'x64') {
                        continue;
                    }
                    #end
                    #if (linux && linux_arm64)
                    if (os != 'linux' && variant != 'arm64') {
                        continue;
                    }
                    #end

                    if (!FileSystem.exists(assetLocalGlslcCommitFile) || !FileSystem.exists(assetLocalSpirvCommitFile) || glslcShortCommit != File.getContent(assetLocalGlslcCommitFile).trim().substring(0,7) || spirvShortCommit != File.getContent(assetLocalSpirvCommitFile).trim().substring(0,7)) {
                        Download.downloadFile(
                            'https://github.com/jeremyfa/shader-tools/releases/download/' + release.tag_name + '/' + asset.name,
                            assetLocalPath,
                        );
                        if (ext == 'zip') {
                            if (FileSystem.exists(assetLocalPathDir)) {
                                Files.deleteRecursive(assetLocalPathDir);
                            }
                            FileSystem.createDirectory(assetLocalPathDir);
                            Zip.unzipFile(assetLocalPath, assetLocalPathDir, binaryPath);
                        }
                        else if (ext == 'tar.gz') {
                            if (FileSystem.exists(assetLocalPathDir)) {
                                Files.deleteRecursive(assetLocalPathDir);
                            }
                            FileSystem.createDirectory(assetLocalPathDir);
                            TarGz.untarGzFile(assetLocalPath, assetLocalPathDir, binaryPath);
                        }
                        FileSystem.deleteFile(assetLocalPath);
                        FileSystem.rename(
                            Path.join([assetLocalPathDir, 'shaderc-commit.txt']),
                            Path.join([assetLocalPathDir, 'glslc-commit.txt'])
                        );
                    }
                    else {
                        print('Already up to date: ' + assetLocalNameNoExt);
                    }
                }
            }
        }

    }

}
