package tools.tasks;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

class SDL extends tools.Task {

    static final RE_SDL_ASSET = ~/^sdl3-(mac|windows|linux|ios|android)-(.*?).(zip|tar\.gz)$/;

    override public function info(cwd:String):String {

        return "Manage SDL dependency";

    }

    override function run(cwd:String, args:Array<String>):Void {

        final action = if (args.contains('update')) {
            'update';
        }
        else if (args.contains('download')) {
            'download';
        }
        else if (args.contains('build')) {
            'build';
        }
        else {
            fail('Unknown action. Use "sdl update" or "sdl download" or "sdl build"');
            null;
        }

        if (action == 'update' || action == 'download') {

            var release:Dynamic = null;
            if (action == 'update') {
                print('Resolving latest SDL builds available...');
                release = Github.resolveLatestRelease('jeremyfa', 'build-sdl3');
                success('Latest release: ' + release.name + ' / https://github.com/jeremyfa/build-sdl3/releases/tag/' + release.tag_name);
            }
            else if (action == 'download') {
                print('Downloading SDL builds...');
                final commit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/sdl'])).trim().substr(0,7);
                release = Github.resolveReleaseForTag('jeremyfa', 'build-sdl3', 'sdl3-' + commit);
                success('Matched release: ' + release.name + ' / https://github.com/jeremyfa/build-sdl3/releases/tag/' + release.tag_name);
            }

            final assets:Array<Dynamic> = release.assets;
            final sdlShortCommit = Std.string(release.tag_name).split('-')[1];
            final sdlBinaryPath = Path.join([context.ceramicRootPath, 'bin/sdl']);
            if (!FileSystem.exists(sdlBinaryPath)) {
                FileSystem.createDirectory(sdlBinaryPath);
            }

            if (action == 'update') {
                Download.downloadFile(
                    'https://github.com/jeremyfa/build-sdl3/releases/download/' + release.tag_name + '/commit.txt',
                    Path.join([context.ceramicRootPath, 'bin/.commit/sdl']),
                );
            }
            final sdlLongCommit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/sdl'])).trim();

            if (action == 'update') {
                print('Update SDL repository to match release commit: $sdlLongCommit');
                File.saveContent(Path.join([context.ceramicRootPath, 'bin/.commit/sdl']), sdlLongCommit);
                final sdlRepoPath = Path.join([context.ceramicGitDepsPath, 'SDL']);
                command('git', ['fetch'], { cwd: sdlRepoPath });
                command('git', ['checkout', 'main'], { cwd: sdlRepoPath });
                command('git', ['reset', '--hard', sdlLongCommit], { cwd: sdlRepoPath });

                runTask('android update template', []);
            }

            for (asset in assets) {
                if (RE_SDL_ASSET.match(asset.name)) {
                    final os = RE_SDL_ASSET.matched(1);
                    final variant = RE_SDL_ASSET.matched(2);
                    final ext = RE_SDL_ASSET.matched(3);
                    var assetLocalName = 'sdl3-$os-$variant.$ext';
                    var assetLocalNameNoExt = 'sdl3-$os-$variant';
                    final assetLocalPath = Path.join([sdlBinaryPath, assetLocalName]);
                    final assetLocalPathDir = Path.join([sdlBinaryPath, assetLocalNameNoExt]);
                    final assetLocalCommitFile = Path.join([assetLocalPathDir, 'commit.txt']);

                    #if windows
                    if (os != 'windows' && os != 'android') {
                        continue;
                    }
                    #end
                    #if mac
                    if (os != 'mac' && os != 'ios' && os != 'android') {
                        continue;
                    }
                    #end
                    #if linux
                    if (os != 'linux' && os != 'android') {
                        continue;
                    }
                    #end

                    if (!FileSystem.exists(assetLocalCommitFile) || sdlShortCommit != File.getContent(assetLocalCommitFile).trim().substring(0,7)) {
                        Download.downloadFile(
                            'https://github.com/jeremyfa/build-sdl3/releases/download/' + release.tag_name + '/' + asset.name,
                            assetLocalPath,
                        );
                        if (ext == 'zip') {
                            if (FileSystem.exists(assetLocalPathDir)) {
                                Files.deleteRecursive(assetLocalPathDir);
                            }
                            FileSystem.createDirectory(assetLocalPathDir);
                            Zip.unzipFile(assetLocalPath, assetLocalPathDir, sdlBinaryPath);
                        }
                        else if (ext == 'tar.gz') {
                            if (FileSystem.exists(assetLocalPathDir)) {
                                Files.deleteRecursive(assetLocalPathDir);
                            }
                            FileSystem.createDirectory(assetLocalPathDir);
                            TarGz.untarGzFile(assetLocalPath, assetLocalPathDir, sdlBinaryPath);
                        }
                        FileSystem.deleteFile(assetLocalPath);

                        if (os == 'android') {
                            // We don't need the dynamic libs on android
                            Files.deleteRecursive(Path.join([assetLocalPathDir, 'jniLibs']));
                        }
                        else if (os == 'windows') {
                            // We don't need the static libs on windows
                            Files.deleteRecursive(Path.join([assetLocalPathDir, 'lib', 'SDL3-static.lib']));
                        }
                        else if (os == 'linux') {
                            // We don't need the static libs on linux
                            if (FileSystem.exists(Path.join([assetLocalPathDir, 'lib', 'libSDL3.a']))) {
                                FileSystem.deleteFile(Path.join([assetLocalPathDir, 'lib', 'libSDL3.a']));
                            }
                        }
                    }
                    else {
                        print('Already up to date: ' + assetLocalNameNoExt);
                    }
                }
            }
        }
        else if (action == 'build') {
            final commit = File.getContent(Path.join([context.ceramicRootPath, 'bin/.commit/sdl'])).trim();

            if (args.contains('android')) {
                command(
                    './build-sdl3-android.sh',
                    [],
                    {
                        cwd: Path.join([context.ceramicGitDepsPath, 'build-sdl3']),
                        env: {
                            SDL3_COMMIT: commit
                        }
                    }
                );
            }
            else {
                #if mac
                if (args.contains('ios')) {
                    command(
                        './build-sdl3-mac.sh',
                        [],
                        {
                            cwd: Path.join([context.ceramicGitDepsPath, 'build-sdl3']),
                            env: {
                                SDL3_COMMIT: commit
                            }
                        }
                    );
                }
                else {
                    command(
                        './build-sdl3-ios.sh',
                        [],
                        {
                            cwd: Path.join([context.ceramicGitDepsPath, 'build-sdl3']),
                            env: {
                                SDL3_COMMIT: commit
                            }
                        }
                    );
                }
                #elseif windows
                command(
                    './build-sdl3-windows.sh',
                    [],
                    {
                        cwd: Path.join([context.ceramicGitDepsPath, 'build-sdl3']),
                        env: {
                            SDL3_COMMIT: commit
                        }
                    }
                );
                #elseif linux
                command(
                    './build-sdl3-linux.sh',
                    [],
                    {
                        cwd: Path.join([context.ceramicGitDepsPath, 'build-sdl3']),
                        env: {
                            SDL3_COMMIT: commit
                        }
                    }
                );
                #end
            }

        }

    }

}
