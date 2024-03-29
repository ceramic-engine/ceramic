package tools.tasks.android;

import haxe.Json;
import haxe.io.Path;
import js.node.ChildProcess;
import npm.StreamSplitter;
import sys.FileSystem;
import sys.io.File;
import tools.AndroidProject;
import tools.Helpers.*;
import tools.Project;

using StringTools;

class NdkStack extends tools.Task {

    override public function info(cwd:String):String {

        return "Filter and reformat android logcat output to print better stack traces.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        var filePath = extractArgValue(args, 'file');

        var os = Sys.systemName();
        if (os == 'Windows') {
            fail('This command is not supported on Windows systems.');
        }

        // Add android flag
        if (!context.defines.exists('android')) {
            context.defines.set('android', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        var androidLocalPropertiesFile = Path.join([cwd, 'project/android/local.properties']);

        if (!FileSystem.exists(androidLocalPropertiesFile)) {
            fail('Missing Android project\'s local.properties file.');
        }

        // Extract ndk directory
        var localProperties = File.getContent(androidLocalPropertiesFile);
        var ndkDir = extractArgValue(args, 'ndk-dir');
        var sdkDir = extractArgValue(args, 'sdk-dir');
        for (line in localProperties.split("\n")) {
            if (ndkDir == null && line.trim().startsWith('ndk.dir=')) {
                ndkDir = line.trim().substring('ndk.dir='.length).trim();
            }
            if (sdkDir == null && line.trim().startsWith('sdk.dir=')) {
                sdkDir = line.trim().substring('sdk.dir='.length).trim();
            }
        }

        if (sdkDir == null) {
            fail('Failed to resolve Android SDK directory.');
        }
        if (ndkDir == null) {
            fail('Failed to resolve Android NDK directory.');
        }

        var adbPath = Path.join([sdkDir, 'platform-tools/adb']);
        var ndkStackPath = Path.join([ndkDir, 'ndk-stack']);

        var abi = 'arm64-v8a'; // Most common ABI
        /*
        var acceptedAbis = [
            'arm64-v8a' => true,
            'armeabi-v7a' => true,
            'x86' => true
        ];

        try {
            var res = command(adbPath, ['shell', 'getprop', 'ro.product.cpu.abilist'], { mute: true });
            var allAbis = res.stdout.trim().split(',');
            for (anAbi in allAbis) {
                if (acceptedAbis.exists(anAbi)) {
                    abi = anAbi;
                    break;
                }
            }
        }
        catch (e:Dynamic) {
            warning('Failed to resolve device ABI: ' + e);
        }
        */

        var status = 0;
        var symbolsPath = Path.join([cwd, 'project/android/app/src/main/jniLibs/$abi']);

        var ndkStackShPath = Path.join([cwd, 'project/android/ndk-stack.sh']);
        var ndkStackSh = '#!/bin/sh
$adbPath logcat | $ndkStackPath -sym $symbolsPath
        ';

        if (filePath != null) {
            if (!Path.isAbsolute(filePath)) {
                filePath = Path.join([cwd, filePath]);
                ndkStackSh = '#!/bin/sh
cat $filePath | $ndkStackPath -sym $symbolsPath';
            }
        }

        File.saveContent(ndkStackShPath, ndkStackSh);

        Sync.run(function(done) {

            var proc = ChildProcess.spawn(
                'sh',
                [ndkStackShPath],
                { cwd: Path.join([cwd, 'project/android']) }
            );

            var out = StreamSplitter.splitter("\n");
            proc.stdout.pipe(untyped out);
            proc.on('close', function(code:Int) {
                status = code;
            });
            out.encoding = 'utf8';
            out.on('token', function(token) {
                stdoutWrite(token + "\n");
            });
            out.on('done', function() {
                done();
            });
            out.on('error', function(err) {
                warning(''+err);
            });

            var err = StreamSplitter.splitter("\n");
            proc.stderr.pipe(untyped err);
            err.encoding = 'utf8';
            err.on('token', function(token) {
                stderrWrite(token + "\n");
            });
            err.on('error', function(err) {
                warning(''+err);
            });

            if (status != 0) {
                fail('Error when running ndk-stack.');
            }

        });

    }

}
