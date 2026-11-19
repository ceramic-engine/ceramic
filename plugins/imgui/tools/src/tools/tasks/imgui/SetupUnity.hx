package tools.tasks.imgui;

import haxe.crypto.Md5;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

/**
 * Copies the generated DCImGui C# P/Invoke shim and the prebuilt dcimgui
 * native libraries into the ceramic project's exported Unity project
 * (Assets/Plugins/DCImGui), and the DCImGuiCallbacks companion into
 * Assets/Ceramic (it references the Haxe-generated imgui.ImGuiCallbacks
 * class, so it must live in Assembly-CSharp, NOT in Plugins which compiles
 * first into Assembly-CSharp-firstpass). Runs AUTOMATICALLY at the end of
 * every unity build (hook declared in the plugin's ceramic.yml), so the
 * Unity export always follows the imgui-hx bindings; can also be run
 * manually.
 */
class SetupUnity extends tools.Task {

    override public function info(cwd:String):String {

        return "Copy the DCImGui C# shim + native libs into this project's Unity export.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        ensureCeramicProject(cwd, args, App);

        // With --if-exists (used by the automatic build hook), silently skip
        // when the Unity export doesn't exist yet instead of failing.
        var ifExists = extractArgFlag(args, 'if-exists');

        var project = new tools.Project();
        project.loadAppFile(Path.join([cwd, 'ceramic.yml']));

        // (same resolution as the unity plugin's UnityProject.resolveUnityProjectPath,
        // inlined to avoid a cross-plugin tools dependency)
        var projectName = 'MyApp';
        if (project.app != null && project.app.name != null) {
            projectName = project.app.name;
        }
        var unityProjectPath = Path.join([cwd, 'project', 'unity', projectName]);
        if (project.app != null && project.app.unity != null && project.app.unity.project != null) {
            var customUnityProjectPath:String = project.app.unity.project;
            if (!Path.isAbsolute(customUnityProjectPath)) {
                customUnityProjectPath = Path.join([cwd, customUnityProjectPath]);
            }
            unityProjectPath = customUnityProjectPath;
        }
        if (!FileSystem.exists(unityProjectPath)) {
            if (ifExists) return;
            fail('No Unity project found at $unityProjectPath (run: ceramic unity setup unity)');
        }

        var imguiHxPath = Path.join([context.ceramicGitDepsPath, 'imgui-hx']);
        var pluginsPath = Path.join([unityProjectPath, 'Assets', 'Plugins', 'DCImGui']);
        if (!FileSystem.exists(pluginsPath)) {
            FileSystem.createDirectory(pluginsPath);
        }

        // C# P/Invoke shims (only reference System, safe in Plugins/firstpass)
        copyIfNeeded(Path.join([imguiHxPath, 'src/imguics/DCImGui.cs']), Path.join([pluginsPath, 'DCImGui.cs']));
        copyIfNeeded(Path.join([imguiHxPath, 'src/imguics/DCImGuiExtra.cs']), Path.join([pluginsPath, 'DCImGuiExtra.cs']));

        // Callbacks companion: references the Haxe-generated imgui.ImGuiCallbacks
        // class -> must compile in Assembly-CSharp (Assets/Ceramic), not in
        // Plugins (Assembly-CSharp-firstpass compiles before it).
        // Not in Assets/Ceramic/Scripts either: the unity build sync deletes
        // any .cs there it did not generate itself.
        var ceramicAssetsPath = Path.join([unityProjectPath, 'Assets', 'Ceramic']);
        copyIfNeeded(Path.join([imguiHxPath, 'src/imguics/DCImGuiCallbacks.cs']), Path.join([ceramicAssetsPath, 'DCImGuiCallbacks.cs']));

        // Clean up the copy older versions of this task put in Plugins
        var staleCallbacks = Path.join([pluginsPath, 'DCImGuiCallbacks.cs']);
        if (FileSystem.exists(staleCallbacks)) {
            FileSystem.deleteFile(staleCallbacks);
            if (FileSystem.exists(staleCallbacks + '.meta')) {
                FileSystem.deleteFile(staleCallbacks + '.meta');
            }
        }

        // Native libraries (whichever have been built by build/build-*.sh)
        copyIfNeeded(Path.join([imguiHxPath, 'lib/prebuilt/mac/dcimgui.dylib']), Path.join([pluginsPath, 'dcimgui.dylib']));
        copyIfNeeded(Path.join([imguiHxPath, 'lib/prebuilt/windows/dcimgui.dll']), Path.join([pluginsPath, 'dcimgui.dll']));
        copyIfNeeded(Path.join([imguiHxPath, 'lib/prebuilt/linux/libdcimgui.so']), Path.join([pluginsPath, 'libdcimgui.so']));
        for (abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
            copyIfNeeded(
                Path.join([imguiHxPath, 'lib/prebuilt/android/$abi/libdcimgui.so']),
                Path.join([pluginsPath, 'Android/$abi/libdcimgui.so'])
            );
        }
        // Each library is for its own platform. Without these settings Unity takes
        // every library for every platform, and a player build stops on the four
        // libdcimgui.so that would go to the same place.
        writePluginMeta(Path.join([pluginsPath, 'dcimgui.dylib']), [
            {platform: 'Editor: Editor', settings: ['CPU: AnyCPU', 'DefaultValueInitialized: true', 'OS: OSX']},
            {platform: 'Standalone: OSXUniversal', settings: ['CPU: AnyCPU']}
        ]);
        writePluginMeta(Path.join([pluginsPath, 'dcimgui.dll']), [
            {platform: 'Editor: Editor', settings: ['CPU: x86_64', 'DefaultValueInitialized: true', 'OS: Windows']},
            {platform: 'Standalone: Win64', settings: ['CPU: x86_64']}
        ]);
        writePluginMeta(Path.join([pluginsPath, 'libdcimgui.so']), [
            {platform: 'Editor: Editor', settings: ['CPU: x86_64', 'DefaultValueInitialized: true', 'OS: Linux']},
            {platform: 'Standalone: Linux64', settings: ['CPU: x86_64']}
        ]);
        final androidCpus = ['arm64-v8a' => 'ARM64', 'armeabi-v7a' => 'ARMv7', 'x86_64' => 'X86_64'];
        for (abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
            writePluginMeta(Path.join([pluginsPath, 'Android/$abi/libdcimgui.so']), [
                {platform: 'Android: Android', settings: ['CPU: ' + androidCpus.get(abi)]}
            ]);
        }

        var xcframework = Path.join([imguiHxPath, 'lib/prebuilt/ios/dcimgui.xcframework']);
        if (FileSystem.exists(xcframework)) {
            var dest = Path.join([pluginsPath, 'iOS/dcimgui.xcframework']);
            Files.deleteRecursive(dest);
            Files.copyDirectory(xcframework, dest);
            success('Copy dcimgui.xcframework');
        }

    }

    /**
     * Writes the import settings of a native library: enabled for the given
     * platforms only. The guid of an existing .meta file is kept.
     */
    static function writePluginMeta(file:String, platforms:Array<{platform:String, settings:Array<String>}>):Void {

        if (!FileSystem.exists(file)) return;
        var metaPath = file + '.meta';
        var guid:String = null;
        if (FileSystem.exists(metaPath)) {
            var guidLine = ~/^guid: ([0-9a-f]{32})/m;
            if (guidLine.match(File.getContent(metaPath))) {
                guid = guidLine.matched(1);
            }
        }
        if (guid == null) {
            guid = Md5.encode('ceramic-imgui:' + Path.withoutDirectory(Path.directory(file)) + '/' + Path.withoutDirectory(file));
        }

        var meta = new StringBuf();
        meta.add('fileFormatVersion: 2\n');
        meta.add('guid: ' + guid + '\n');
        meta.add('PluginImporter:\n');
        meta.add('  externalObjects: {}\n');
        meta.add('  serializedVersion: 2\n');
        meta.add('  iconMap: {}\n');
        meta.add('  executionOrder: {}\n');
        meta.add('  defineConstraints: []\n');
        meta.add('  isPreloaded: 0\n');
        meta.add('  isOverridable: 0\n');
        meta.add('  isExplicitlyReferenced: 0\n');
        meta.add('  validateReferences: 1\n');
        meta.add('  platformData:\n');
        meta.add('  - first:\n');
        meta.add('      Any: \n');
        meta.add('    second:\n');
        meta.add('      enabled: 0\n');
        meta.add('      settings: {}\n');
        for (entry in platforms) {
            meta.add('  - first:\n');
            meta.add('      ' + entry.platform + '\n');
            meta.add('    second:\n');
            meta.add('      enabled: 1\n');
            meta.add('      settings:\n');
            for (setting in entry.settings) {
                meta.add('        ' + setting + '\n');
            }
        }
        meta.add('  userData: \n');
        meta.add('  assetBundleName: \n');
        meta.add('  assetBundleVariant: \n');

        var content = meta.toString();
        if (!FileSystem.exists(metaPath) || File.getContent(metaPath) != content) {
            success('Write ' + Path.withoutDirectory(metaPath));
            File.saveContent(metaPath, content);
        }

    }

    static function copyIfNeeded(source:String, dest:String):Void {

        if (!FileSystem.exists(source)) return;
        var destDir = Path.directory(dest);
        if (!FileSystem.exists(destDir)) {
            FileSystem.createDirectory(destDir);
        }
        if (!Files.haveSameLastModified(source, dest)) {
            success('Copy ' + Path.withoutDirectory(dest));
            File.copy(source, dest);
            Files.setToSameLastModified(source, dest);
        }

    }

}
