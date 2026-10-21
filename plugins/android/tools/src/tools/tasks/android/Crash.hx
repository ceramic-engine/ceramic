package tools.tasks.android;

import haxe.io.Path;
import haxe.zip.Reader as ZipReader;
import sys.FileSystem;
import sys.io.File;
import tools.AndroidSymbols;
import tools.Helpers.*;

using StringTools;

/**
 * Collects the native crashes of the app from the connected device and symbolicates them
 * with the archived symbols of their build (see `AndroidSymbols`): the crash buffer of
 * logcat, the native crash reports kept by the system (dropbox, which outlive the logcat
 * buffers and reboots), the full crash reports with the stacks of all threads (tombstones,
 * from a bug report of the device, skipped with `--quick`) and the recent logs of the
 * device are saved together, then each
 * crash of the app gets a report with every frame of its library resolved to function,
 * file and line, inlined frames included. The builds of the crashes are marked so that
 * their symbols are kept whole.
 *
 * With `--hang`, the app is expected to be running (stuck): it is aborted first, so that
 * its crash report gives the native stacks of all its threads, symbolicated the same way.
 *
 * Only the crashes not collected before are reported, unless `--all`.
 */
class Crash extends tools.Task {

    override public function info(cwd:String):String {

        return "Collect the native crashes of the app from the android device and symbolicate them (--hang: abort the running app first, to get the stacks of all its threads).";

    }

    override function run(cwd:String, args:Array<String>):Void {

        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        var project = ensureCeramicProject(cwd, args, App);
        var app:Dynamic = project.app;
        var libName = 'lib' + app.name + '.so';
        var packageName:String = Reflect.field(app, 'package');

        var sdkPath = AndroidUtils.sdkPath();
        var adb = Path.join([sdkPath, 'platform-tools', #if windows 'adb.exe' #else 'adb' #end]);
        if (!FileSystem.exists(adb)) adb = 'adb';
        var device = extractArgValue(args, 'device');
        var hang = extractArgFlag(args, 'hang');
        var quick = extractArgFlag(args, 'quick');
        var all = extractArgFlag(args, 'all');
        var adbArgs = device != null ? ['-s', device] : [];

        if (AndroidSymbols.llvmTool('llvm-addr2line') == null) {
            fail('llvm-addr2line not found in the NDK (${AndroidUtils.ndkPath()})');
        }

        // Collect everything first: the logcat buffers are overwritten quickly
        var now = Date.now();
        var stamp = DateTools.format(now, '%Y-%m-%d_%H-%M-%S');
        var collectDir = Path.join([AndroidSymbols.crashesPath(project), stamp]);
        FileSystem.createDirectory(collectDir);

        if (hang) {
            // Without root, the stacks of a live process cannot be dumped from outside:
            // the stuck app is aborted instead (as its own user, it is debuggable), its
            // crash report then has the backtraces of all its threads
            var pid = adbOutput(adb, adbArgs.concat(['shell', 'pidof', packageName]));
            if (pid == null || pid.trim() == '') {
                fail('${app.name} is not running on the device');
            }
            print('Abort ${app.name} (pid ${pid.trim()}) to get the stacks of all its threads');
            if (command(adb, adbArgs.concat(['shell', 'run-as', packageName, 'kill', '-6', pid.trim()]), { mute: true }).status != 0) {
                fail('Could not abort ${app.name} (the app must be debuggable)');
            }
            // The crash report is written by the system after the process dies
            for (i in 0...20) {
                Sys.sleep(0.5);
                var still = adbOutput(adb, adbArgs.concat(['shell', 'pidof', packageName]));
                if (still == null || still.trim() != pid.trim()) break;
            }
            Sys.sleep(2.0);
        }

        var crashBuffer = adbOutput(adb, adbArgs.concat(['logcat', '-d', '-b', 'crash', '-v', 'threadtime']));
        var dropbox = adbOutput(adb, adbArgs.concat(['shell', 'dumpsys', 'dropbox', '--print', 'data_app_native_crash']));
        var mainLog = adbOutput(adb, adbArgs.concat(['logcat', '-d', '-v', 'threadtime']));
        if (crashBuffer == null && dropbox == null && mainLog == null) {
            fail('Could not read anything from the device (is it connected? see `adb devices`)');
        }
        File.saveContent(Path.join([collectDir, 'logcat-crash.txt']), crashBuffer != null ? crashBuffer : '');
        File.saveContent(Path.join([collectDir, 'dropbox-native-crashes.txt']), dropbox != null ? dropbox : '');
        File.saveContent(Path.join([collectDir, 'logcat.txt']), mainLog != null ? mainLog : '');

        // The full crash reports (all threads), only readable from a bug report without root
        var tombstones = new Array<String>();
        if (!quick) {
            print('Get a bug report of the device for the full crash reports (all threads), skip with --quick');
            var bugreport = Path.join([collectDir, 'bugreport.zip']);
            if (command(adb, adbArgs.concat(['bugreport', bugreport]), { mute: true }).status == 0 && FileSystem.exists(bugreport)) {
                tombstones = readTombstones(bugreport, packageName);
                var tombstonesDir = Path.join([collectDir, 'tombstones']);
                if (tombstones.length > 0) FileSystem.createDirectory(tombstonesDir);
                for (i in 0...tombstones.length) {
                    File.saveContent(Path.join([tombstonesDir, 'tombstone-$i.txt']), tombstones[i]);
                }
            }
            else {
                warning('Could not get a bug report: only the crashing thread of each crash is available');
            }
        }

        // The crash reports of the app, each once (the same crash is in several sources):
        // the most complete version of each
        var reports = new Array<CrashReport>();
        var byKey = new Map<String, Int>();
        for (source in [crashBuffer, dropbox].concat(tombstones)) {
            if (source == null) continue;
            for (report in splitReports(source)) {
                if (report.text.indexOf(libName) == -1 && (packageName == null || report.text.indexOf('>>> ' + packageName + ' <<<') == -1)) continue;
                if (byKey.exists(report.key)) {
                    var index = byKey.get(report.key);
                    if (report.text.length > reports[index].text.length) reports[index] = report;
                    continue;
                }
                byKey.set(report.key, reports.length);
                reports.push(report);
            }
        }

        // Only the crashes not collected before, unless --all
        var seenPath = Path.join([AndroidSymbols.crashesPath(project), 'collected.txt']);
        var seen = new Map<String, Bool>();
        if (FileSystem.exists(seenPath)) {
            for (line in File.getContent(seenPath).split('\n')) {
                if (line.trim() != '') seen.set(line.trim(), true);
            }
        }
        var total = reports.length;
        if (!all) {
            reports = reports.filter(r -> !seen.exists(r.key));
        }
        var seenOut = File.append(seenPath, false);
        for (report in reports) {
            if (!seen.exists(report.key)) seenOut.writeString(report.key + '\n');
        }
        seenOut.close();

        if (reports.length == 0) {
            // Nothing new: what was just collected is not kept
            Files.deleteRecursive(collectDir);
            success(total == 0
                ? 'No native crash of ${app.name} on the device'
                : 'No new native crash of ${app.name} on the device ($total collected before, see them again with --all)');
            return;
        }

        var index = 0;
        for (report in reports) {
            index++;
            var reportPath = Path.join([collectDir, 'crash-$index.txt']);
            var symbolicated = symbolicate(project, report, libName, reportPath);
            File.saveContent(reportPath, symbolicated);
            print('');
            print('Crash $index of ${reports.length} (${report.key}):');
            print(symbolicated);
        }

        print('');
        success('${reports.length} crash(es) collected in $collectDir');

    }

    /**
     * The text crash reports (tombstones) of `packageName` in the bug report `path`.
     */
    static function readTombstones(path:String, packageName:String):Array<String> {

        var result = new Array<String>();
        try {
            var input = File.read(path, true);
            var entries = ZipReader.readZip(input);
            input.close();
            for (entry in entries) {
                var name = entry.fileName;
                if (name.indexOf('data/tombstones/tombstone_') == -1 || name.endsWith('.pb')) continue;
                var text = ZipReader.unzip(entry).toString();
                if (packageName == null || text.indexOf('>>> ' + packageName + ' <<<') != -1) {
                    result.push(text);
                }
            }
        }
        catch (e:Dynamic) {
            warning('Could not read the bug report $path: $e');
        }
        return result;

    }

    function adbOutput(adb:String, args:Array<String>):String {

        var res = command(adb, args, { mute: true });
        return res.status == 0 ? res.stdout : null;

    }

    /**
     * The tombstone-like reports of `source` (logcat lines or raw text), without the
     * logcat line prefixes.
     */
    static function splitReports(source:String):Array<CrashReport> {

        var reports = new Array<CrashReport>();
        var prefix = ~/^\S+\s+\S+\s+\d+\s+\d+\s+[A-Z]\s+[^:]*:\s?/;
        var current:StringBuf = null;
        var currentKey:String = null;
        var pid:String = null;
        var timestamp:String = null;

        inline function flush() {
            if (current != null) {
                reports.push({ key: (pid != null ? 'pid $pid' : '?') + (timestamp != null ? ' at $timestamp' : ''), text: current.toString() });
            }
            current = null;
            pid = null;
            timestamp = null;
        }

        for (rawLine in source.replace('\r', '').split('\n')) {
            var line = prefix.match(rawLine) ? prefix.matchedRight() : rawLine;
            if (line.indexOf('*** *** *** *** *** ***') != -1) {
                flush();
                current = new StringBuf();
            }
            if (current == null) continue;
            current.add(line);
            current.add('\n');
            var pidRe = ~/^pid:\s*(\d+)/;
            if (pid == null && pidRe.match(line.trim())) pid = pidRe.matched(1);
            var timeRe = ~/^Timestamp:\s*(.+)$/;
            if (timestamp == null && timeRe.match(line.trim())) timestamp = timeRe.matched(1).trim();
        }
        flush();
        return reports;

    }

    /**
     * `report` with the frames of `libName` resolved with the archived symbols of their
     * build.
     */
    static function symbolicate(project:Project, report:CrashReport, libName:String, reportPath:String):String {

        var addr2line = AndroidSymbols.llvmTool('llvm-addr2line');
        var frameRe = ~/^(\s*#\d+\s+pc\s+)([0-9a-fA-F]+)\s+(\S+)(.*)$/;
        var buildIdRe = ~/BuildId:\s*([0-9a-fA-F]+)/;
        var out = new StringBuf();
        var missing = new Map<String, Bool>();
        var libraries = new Map<String, String>();

        for (line in report.text.split('\n')) {
            out.add(line);
            if (frameRe.match(line) && frameRe.matched(3).endsWith('/' + libName)) {
                var pc = frameRe.matched(2);
                var rest = frameRe.matched(4);
                var buildId = buildIdRe.match(rest) ? buildIdRe.matched(1).toLowerCase() : null;
                if (buildId == null) {
                    out.add('  [no build id in the crash: a build made before symbol archiving]');
                }
                else {
                    if (!libraries.exists(buildId)) {
                        libraries.set(buildId, AndroidSymbols.markCrash(project, buildId, reportPath));
                    }
                    var lib = libraries.get(buildId);
                    if (lib == null) {
                        missing.set(buildId, true);
                    }
                    else {
                        var res = command(addr2line, ['-f', '-C', '-i', '-p', '-e', lib, '0x' + pc], { mute: true });
                        if (res.status == 0 && res.stdout != null) {
                            var resolved = res.stdout.trim().split('\n').map(s -> s.trim()).join('\n        ');
                            out.add('\n        ' + resolved);
                        }
                    }
                }
            }
            out.add('\n');
        }

        for (buildId in missing.keys()) {
            out.add('No archived symbols for build $buildId (in ${AndroidSymbols.storePath(project)})\n');
        }
        return out.toString();

    }

}

typedef CrashReport = {
    key:String,
    text:String
}
