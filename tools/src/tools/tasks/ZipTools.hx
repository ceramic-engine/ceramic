package tools.tasks;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class ZipTools extends tools.Task {

    override public function info(cwd:String):String {

        return "Package these ceramic tools as a redistribuable zip file.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        var os = Sys.systemName();
        if (os == 'Mac') {
            var tmpDirContainerPath = Path.join([cwd, 'ceramic.zip.tmp']);
            var tmpDirPath = Path.join([tmpDirContainerPath, 'ceramic']);

            print('Copy ceramic directory to $tmpDirPath');
            if (FileSystem.exists(tmpDirContainerPath)) {
                Files.deleteRecursive(tmpDirContainerPath);
            }
            FileSystem.createDirectory(tmpDirPath);
            command('cp', ['-a', '-f', context.ceramicRootPath + '/.', tmpDirPath + '/']);

            print('Remove files not needed on $os');
            Files.deleteAnyFileNamed('.git', tmpDirPath);
            Files.deleteAnyFileNamed('.DS_Store', tmpDirPath);
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/linc_openal/lib/openal-soft/lib/Windows']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/linc_openal/lib/openal-soft/lib/Windows64']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/linc_openal/lib/openal-soft/lib/Linux']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/linc_openal/lib/openal-soft/lib/Linux64']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/linc_openal/lib/openal-android/lib']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/linc_openal/lib/openal-android/obj']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/spine-hx/spine-runtimes']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/spine-hx/node_modules']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/haxe-binary/linux']));
            Files.deleteRecursive(Path.join([tmpDirPath, 'git/haxe-binary/windows']));

            print('Zip contents');
            var zipPath = Path.join([cwd, 'ceramic.zip']);
            if (FileSystem.exists(zipPath)) {
                FileSystem.deleteFile(zipPath);
            }
            Files.zipDirectory(tmpDirPath, zipPath);

            print('Remove temporary directory');
            Files.deleteRecursive(tmpDirContainerPath);
        }
        else if (os == 'Windows') {
            // TODO
            fail('Not supported on windows yet');
        }
        else if (os == 'Linux') {
            // TODO
            fail('Not supported on linux yet');
        }

    }

}
