package tools;

import haxe.io.Path;
import sys.FileSystem;
import tools.Helpers.*;

using StringTools;

class UnityEditor {

    public static function resolveUnityEditorPath(cwd:String, project:Project, printVersions:Bool = false):String {

        var unityVersion:String = null;
        if (project.app.unity != null &&
            project.app.unity.version != null) {
            unityVersion = '' + project.app.unity.version;
        }
        if (project.app.unity != null &&
            project.app.unity.path != null) {
            var editorPath = '' + project.app.unity.path;
            if (!Path.isAbsolute(editorPath)) {
                editorPath = Path.join([cwd, editorPath]);
            }
            if (!FileSystem.exists(editorPath)) {
                fail('Unity editor not found at path: $editorPath');
            }
            return editorPath;
        }

        var isMac = (Sys.systemName() == 'Mac');
        var isWindows = (Sys.systemName() == 'Windows');

        if (isMac || isWindows) {
            var unityEditorsPath:String = null;

            if (isMac) {
                unityEditorsPath = '/Applications/Unity/Hub/Editor/';
            }
            else if (isWindows) {
                for (drive in getWindowsDrives()) {
                    var tryPath = '$drive:/Program Files/Unity/Hub/Editor/';
                    if (FileSystem.exists(tryPath)) {
                        unityEditorsPath = tryPath;
                        break;
                    }
                }
            }

            if (unityEditorsPath == null || !FileSystem.exists(unityEditorsPath) || !FileSystem.isDirectory(unityEditorsPath)) {
                fail('Cannot find unity editor path: you need to install Unity first with Unity Hub (https://unity3d.com/get-unity/download)');
            }

            var availableVersions = [];
            for (file in FileSystem.readDirectory(unityEditorsPath)) {
                if (file.startsWith('20')) {
                    var fullPath:String = null;
                    if (isMac) {
                        fullPath = Path.join([unityEditorsPath, file, 'Unity.app']);
                    }
                    else if (isWindows) {
                        fullPath = Path.join([unityEditorsPath, file, 'Editor', 'Unity.exe']);
                    }
                    if (FileSystem.exists(fullPath)) {
                        availableVersions.push(file);
                    }
                }
            }
            availableVersions.sort(compareSemVerAscending);

            if (availableVersions.length == 0) {
                fail('Cannot resolve unity editor path: you need to install Unity first with Unity Hub (https://unity3d.com/get-unity/download)');
            }

            var bestAutomaticVersion = null;
            for (version in availableVersions) {
                if (version.startsWith('2021')) {
                    bestAutomaticVersion = version;
                }
            }
            if (bestAutomaticVersion == null)
                bestAutomaticVersion = availableVersions[availableVersions.length-1];

            if (printVersions) {
                print('Available Unity versions: ' + availableVersions.join(', '));
                if (unityVersion != null) {
                    if (availableVersions.indexOf(unityVersion) == -1) {
                        warning('Requested version $unityVersion not installed. Using ${bestAutomaticVersion} instead!');
                        unityVersion = null;
                    }
                    else {
                        success('Using version ${unityVersion}');
                    }
                }
                else {
                    success('Using version ${bestAutomaticVersion}');
                }
            }

            if (unityVersion == null)
                unityVersion = bestAutomaticVersion;

            if (isMac) {
                return Path.join([unityEditorsPath, unityVersion, 'Unity.app']);
            }
            else if (isWindows) {
                return Path.join([unityEditorsPath, unityVersion, 'Editor']);
            }
        }
        else {
            fail('Cannot resolve unity editor path: not supported on platform ' + Sys.systemName() + ' yet.');
        }

        return null;

    }

}