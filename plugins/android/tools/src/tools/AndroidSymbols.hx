package tools;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Helpers.*;

using StringTools;

/**
 * The native symbols of the Android builds, kept aside so that a crash on a device can be
 * symbolicated (see `ceramic android crash`). The library shipped in the app is stripped;
 * hxcpp keeps an unstripped copy next to the objects (`HXCPP_DEBUG_LINK_AND_STRIP`, set
 * by the clay plugin), which is archived here under its build id, debug sections
 * compressed, in `~/.ceramic/symbols/<app package>/android/<build id>/`.
 *
 * The archive does not grow indefinitely: the builds a crash was collected for are kept
 * whole, the `android_symbols_keep_recent` most recent ones too (5 by default), and the
 * debug sections of the others are removed (their symbol table stays: function names,
 * without files and lines).
 */
class AndroidSymbols {

    static final DEFAULT_KEEP_RECENT = 5;

    /**
     * The directory of the archive, for `project`.
     */
    public static function storePath(project:Project):String {

        var app:Dynamic = project.app;
        var appPackage:String = Reflect.field(app, 'package');
        var key:String = appPackage != null ? appPackage : app.name;
        return Path.join([homedir(), '.ceramic', 'symbols', key, 'android']);

    }

    /**
     * The directory of the crashes collected for `project` (see `ceramic android crash`).
     */
    public static function crashesPath(project:Project):String {

        var app:Dynamic = project.app;
        var appPackage:String = Reflect.field(app, 'package');
        var key:String = appPackage != null ? appPackage : app.name;
        return Path.join([homedir(), '.ceramic', 'crashes', key, 'android']);

    }

    /**
     * The directory of the LLVM tools of the NDK (`llvm-readelf`, `llvm-objcopy`,
     * `llvm-addr2line`).
     */
    public static function llvmBinPath():String {

        var ndkPath = AndroidUtils.ndkPath();
        if (ndkPath == null) return null;
        var prebuilt = Path.join([ndkPath, 'toolchains', 'llvm', 'prebuilt']);
        if (!FileSystem.exists(prebuilt)) return null;
        #if windows
        var preferred = 'windows-x86_64';
        #elseif mac
        var preferred = 'darwin-x86_64';
        #else
        var preferred = 'linux-x86_64';
        #end
        if (FileSystem.exists(Path.join([prebuilt, preferred, 'bin']))) {
            return Path.join([prebuilt, preferred, 'bin']);
        }
        for (name in FileSystem.readDirectory(prebuilt)) {
            if (FileSystem.exists(Path.join([prebuilt, name, 'bin']))) {
                return Path.join([prebuilt, name, 'bin']);
            }
        }
        return null;

    }

    public static function llvmTool(name:String):String {

        var bin = llvmBinPath();
        if (bin == null) return null;
        #if windows
        var path = Path.join([bin, name + '.exe']);
        #else
        var path = Path.join([bin, name]);
        #end
        return FileSystem.exists(path) ? path : null;

    }

    /**
     * The build id of the ELF file `path` (hexadecimal), or null.
     */
    public static function readBuildId(path:String):String {

        var readelf = llvmTool('llvm-readelf');
        if (readelf == null || !FileSystem.exists(path)) return null;
        var res = command(readelf, ['-n', path], { mute: true });
        if (res.status != 0 || res.stdout == null) return null;
        var re = ~/Build ID:\s*([0-9a-fA-F]+)/;
        if (re.match(res.stdout)) return re.matched(1).toLowerCase();
        return null;

    }

    /**
     * The Android ABI directory name of `arch` (as given to `android compile --archs`).
     */
    public static function abiOfArch(arch:String):String {

        return switch arch {
            case 'armv7': 'armeabi-v7a';
            case 'arm64': 'arm64-v8a';
            case 'x86' | 'i386': 'x86';
            case 'x86_64': 'x86_64';
            default: arch;
        }

    }

    /**
     * The unstripped library hxcpp kept for `arch` in `objPath` (`out/.../cpp/obj`), or null.
     */
    static function unstrippedLibrary(objPath:String, arch:String):String {

        if (!FileSystem.exists(objPath)) return null;
        var best:String = null;
        var bestTime = -1.0;
        for (dir in FileSystem.readDirectory(objPath)) {
            var matches = switch arch {
                case 'arm64': dir.indexOf('arm64') != -1;
                case 'armv7': dir.indexOf('v7') != -1;
                case 'x86_64': dir.indexOf('x86_64') != -1;
                case 'x86' | 'i386': dir.indexOf('x86') != -1 && dir.indexOf('x86_64') == -1;
                default: false;
            }
            if (!matches) continue;
            var dirPath = Path.join([objPath, dir]);
            if (!FileSystem.isDirectory(dirPath)) continue;
            for (name in FileSystem.readDirectory(dirPath)) {
                if (!name.startsWith('lib') || !name.endsWith('.so')) continue;
                var path = Path.join([dirPath, name]);
                var time = FileSystem.stat(path).mtime.getTime();
                if (time > bestTime) {
                    bestTime = time;
                    best = path;
                }
            }
        }
        return best;

    }

    /**
     * Archives the symbols of the library just built for `arch`: `builtLibrary` is the
     * stripped library that goes in the app, `cppPath` the hxcpp output directory.
     */
    public static function archive(cwd:String, project:Project, arch:String, builtLibrary:String, cppPath:String):Void {

        var buildId = readBuildId(builtLibrary);
        if (buildId == null) {
            warning('No build id in $builtLibrary: its symbols are not archived (crashes of this build cannot be symbolicated)');
            return;
        }

        var unstripped = unstrippedLibrary(Path.join([cppPath, 'obj']), arch);
        if (unstripped == null || readBuildId(unstripped) != buildId) {
            warning('No unstripped library matching $builtLibrary (build id $buildId): its symbols are not archived');
            return;
        }

        var app:Dynamic = project.app;
        var libName = 'lib' + app.name + '.so';
        var dir = Path.join([storePath(project), buildId]);
        var target = Path.join([dir, libName]);
        if (!FileSystem.exists(target)) {
            if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
            var objcopy = llvmTool('llvm-objcopy');
            var res = objcopy != null ? command(objcopy, ['--compress-debug-sections=zlib', unstripped, target], { mute: true }) : null;
            if (res == null || res.status != 0) {
                // Uncompressed rather than nothing
                File.copy(unstripped, target);
            }
            var info:Dynamic = {
                buildId: buildId,
                arch: arch,
                abi: abiOfArch(arch),
                app: app.name,
                date: Date.now().toString(),
                time: Date.now().getTime(),
                project: gitState(cwd),
                ceramic: gitState(context.ceramicRootPath),
                stripped: false,
                crashes: []
            };
            writeInfo(dir, info);
            print('Archived the symbols of build $buildId ($arch) in $dir');
        }

        prune(project);

    }

    /**
     * Removes the debug sections of the archived builds that are neither among the most
     * recent ones nor involved in a collected crash.
     */
    public static function prune(project:Project):Void {

        var store = storePath(project);
        if (!FileSystem.exists(store)) return;

        var keepRecent = DEFAULT_KEEP_RECENT;
        var keepDefine = context.defines.get('android_symbols_keep_recent');
        if (keepDefine != null && Std.parseInt(keepDefine) != null) {
            keepRecent = Std.parseInt(keepDefine);
        }

        var builds:Array<{dir:String, info:Dynamic}> = [];
        for (name in FileSystem.readDirectory(store)) {
            var dir = Path.join([store, name]);
            var info = readInfo(dir);
            if (info != null) builds.push({ dir: dir, info: info });
        }
        builds.sort((a, b) -> a.info.time > b.info.time ? -1 : (a.info.time < b.info.time ? 1 : 0));

        var objcopy = llvmTool('llvm-objcopy');
        if (objcopy == null) return;
        var app:Dynamic = project.app;
        var libName = 'lib' + app.name + '.so';
        for (i in keepRecent...builds.length) {
            var build = builds[i];
            var crashes:Array<Dynamic> = build.info.crashes;
            if (build.info.stripped == true || (crashes != null && crashes.length > 0)) continue;
            var lib = Path.join([build.dir, libName]);
            var tmp = lib + '.tmp';
            var res = command(objcopy, ['--strip-debug', lib, tmp], { mute: true });
            if (res.status == 0 && FileSystem.exists(tmp)) {
                FileSystem.deleteFile(lib);
                FileSystem.rename(tmp, lib);
                build.info.stripped = true;
                writeInfo(build.dir, build.info);
            }
        }

    }

    /**
     * Records that `crashReport` was collected for build `buildId`: its symbols are then
     * kept whole. Returns the archived library, or null when the build is not archived.
     */
    public static function markCrash(project:Project, buildId:String, crashReport:String):String {

        var dir = Path.join([storePath(project), buildId]);
        var info = readInfo(dir);
        if (info == null) return null;
        var crashes:Array<Dynamic> = info.crashes != null ? info.crashes : [];
        if (crashes.indexOf(crashReport) == -1) crashes.push(crashReport);
        info.crashes = crashes;
        writeInfo(dir, info);
        var app:Dynamic = project.app;
        return Path.join([dir, 'lib' + app.name + '.so']);

    }

    public static function readInfo(dir:String):Dynamic {

        var path = Path.join([dir, 'info.json']);
        if (!FileSystem.exists(path)) return null;
        try {
            return Json.parse(File.getContent(path));
        }
        catch (e:Dynamic) {
            return null;
        }

    }

    static function writeInfo(dir:String, info:Dynamic):Void {

        File.saveContent(Path.join([dir, 'info.json']), Json.stringify(info, null, '  '));

    }

    /**
     * The commit of the git repository at `path`, with `+changes` when the working tree
     * differs from it, or null.
     */
    static function gitState(path:String):String {

        if (path == null || !FileSystem.exists(path)) return null;
        var head = command('git', ['-C', path, 'rev-parse', '--short', 'HEAD'], { mute: true });
        if (head.status != 0 || head.stdout == null) return null;
        var state = head.stdout.trim();
        var status = command('git', ['-C', path, 'status', '--porcelain', '--untracked-files=no'], { mute: true });
        if (status.status == 0 && status.stdout != null && status.stdout.trim() != '') state += '+changes';
        return state;

    }

}
