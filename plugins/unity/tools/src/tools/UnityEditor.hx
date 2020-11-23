package tools;

import sys.FileSystem;
import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class UnityEditor {

    public static function resolveUnityEditorPath(cwd:String, project:Project, printVersions:Bool = false):String {

        var unityVersion:String = null;
        if (project.app.unity != null &&
            project.app.unity.version != null) {
            unityVersion = '' + project.app.unity.version;
        }

        if (Sys.systemName() == 'Mac') {
            var unityEditorsPath = '/Applications/Unity/Hub/Editor/';

            if (!FileSystem.exists(unityEditorsPath) || !FileSystem.isDirectory(unityEditorsPath)) {
                fail('Cannot unity editor path: you need to install Unity first with Unity Hub (https://unity3d.com/get-unity/download)');
            }

            var availableVersions = [];
            for (file in FileSystem.readDirectory(unityEditorsPath)) {
                if (file.startsWith('20')) {
                    var fullPath = Path.join([unityEditorsPath, file, 'Unity.app']);
                    if (FileSystem.exists(fullPath)) {
                        availableVersions.push(file);
                    }
                }
            }
            availableVersions.sort(compareSemVerAscending);

            if (availableVersions.length == 0) {
                fail('Cannot resolve unity editor path: you need to install Unity first with Unity Hub (https://unity3d.com/get-unity/download)');
            }

            if (printVersions) {
                print('Available Unity versions: ' + availableVersions.join(', '));
                if (unityVersion != null && availableVersions.indexOf(unityVersion) == -1) {
                    warning('Requested version $unityVersion not installed. Using ${availableVersions[availableVersions.length-1]} instead!');
                }
                else {
                    success('Using version ${availableVersions[availableVersions.length-1]}');
                }
            }

            unityVersion = availableVersions[availableVersions.length-1];

            return Path.join([unityEditorsPath, unityVersion, 'Unity.app']);
        }
        else {
            fail('Cannot resolve unity editor path: not supported on platform ' + Sys.systemName() + ' yet.');
        }

        return null;

    }

}