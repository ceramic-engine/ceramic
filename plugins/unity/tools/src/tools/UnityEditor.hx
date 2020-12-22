package tools;

import sys.FileSystem;
import haxe.io.Path;
import tools.Helpers.*;

using StringTools;

class UnityEditor {

    public static function resolveUnityEditorPath(cwd:String, project:Project, printVersions:Bool = false):String {

        var unityVersion:String = null;
        var unityEditorPath:String = null;
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

        if (Sys.systemName() == 'Mac' || Sys.systemName() == 'Windows') {
            var unityEditorsPath:String = null;

            if (Sys.systemName() == 'Mac') {
                unityEditorPath = '/Applications/Unity/Hub/Editor/';
            }
            else if (Sys.systemName() == 'Windows') {
                unityEditorPath = 'C:/Program Files/Unity/Hub/Editor/';
            }

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