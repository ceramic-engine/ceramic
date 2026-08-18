package tools.tasks.ios;

import haxe.Json;
import haxe.io.Path;
import process.Process;
import sys.FileSystem;
import tools.Helpers.*;
import tools.InstanceManager;

using StringTools;

class RunDevice extends tools.Task {

    override public function info(cwd:String):String {

        return "Build, deploy and run the app on an iOS device, streaming its logs.";

    }

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        // Check devicectl availability (ships with Xcode 15+)
        //
        if (command('xcrun', ['devicectl', '--version'], { mute: true }).status != 0) {
            fail('devicectl is not available. It ships with Xcode 15 and later.
Install or update Xcode, then make sure it is the selected developer directory:

    sudo xcode-select -s /Applications/Xcode.app');
        }

        // Resolve signing configuration from environment
        //
        var developmentTeam = Sys.getEnv('CERAMIC_IOS_DEVELOPMENT_TEAM');
        var codesignIdentity = Sys.getEnv('CERAMIC_IOS_CODESIGN_IDENTITY');
        var provisioningProfile = Sys.getEnv('CERAMIC_IOS_PROVISIONING_PROFILE');

        if (developmentTeam == null || developmentTeam.trim() == '') {
            fail('Missing CERAMIC_IOS_DEVELOPMENT_TEAM environment variable.
Set it to your Apple Development Team ID to let Xcode sign the app automatically:

    export CERAMIC_IOS_DEVELOPMENT_TEAM=ABCDE12345

You can find your Team ID at https://developer.apple.com/account (Membership details),
or in Xcode > Settings > Accounts (select your team, the ID is displayed next to its name).

Optional, to use manual signing instead of automatic:

    export CERAMIC_IOS_CODESIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)"
    export CERAMIC_IOS_PROVISIONING_PROFILE="Your Provisioning Profile Name"');
        }

        // Resolve the target device
        //
        var backendName = context.backend != null ? context.backend.name : 'clay';
        var outTargetPath = BuildTargetExtensions.outPathWithName(backendName, 'ios', cwd, context.debug, context.variant);
        if (!FileSystem.exists(outTargetPath)) {
            FileSystem.createDirectory(outTargetPath);
        }

        var requestedDevice = extractArgValue(args, 'device');
        if (requestedDevice == null || requestedDevice.trim() == '') {
            requestedDevice = Sys.getEnv('CERAMIC_IOS_DEVICE');
        }

        var device = resolveDevice(outTargetPath, requestedDevice);

        print('Using device: ' + device.name + ' (' + device.udid + ')');

        // Make sure the Xcode project exists and is fully provisioned
        // (frameworks copied, app xcframework with both platform slices)
        //
        runTask('ios xcode', []);

        // Build the signed app. The native code is compiled by the project's
        // own "Ceramic / Haxe" build phase, with the archs Xcode requests —
        // same path as when building from the Xcode UI.
        //
        var iosProjectPath = Path.join([cwd, 'project/ios']);
        var configuration = context.debug ? 'Debug' : 'Release';

        var xcodebuildArgs = [
            '-project', project.app.name + '.xcodeproj',
            '-scheme', project.app.name,
            '-configuration', configuration,
            '-destination', 'generic/platform=iOS',
            '-derivedDataPath', 'build',
            '-allowProvisioningUpdates',
            'DEVELOPMENT_TEAM=' + developmentTeam
        ];
        if (codesignIdentity != null && codesignIdentity.trim() != ''
            && provisioningProfile != null && provisioningProfile.trim() != '') {
            xcodebuildArgs.push('CODE_SIGN_STYLE=Manual');
            xcodebuildArgs.push('CODE_SIGN_IDENTITY=' + codesignIdentity);
            xcodebuildArgs.push('PROVISIONING_PROFILE_SPECIFIER=' + provisioningProfile);
        }
        else {
            xcodebuildArgs.push('CODE_SIGN_STYLE=Automatic');
        }
        xcodebuildArgs.push('build');

        print('Build signed app ($configuration)');
        var buildStatus = commandWithChecksAndLogs('xcodebuild', xcodebuildArgs, { cwd: iosProjectPath, logCwd: outTargetPath });
        if (buildStatus != 0) {
            fail('Failed to build the app with xcodebuild (status ' + buildStatus + ')');
        }

        var appPath = Path.join([iosProjectPath, 'build/Build/Products', configuration + '-iphoneos', project.app.name + '.app']);
        if (!FileSystem.exists(appPath)) {
            fail('Expected app bundle not found at path: $appPath');
        }

        // The built Info.plist is the source of truth for the bundle identifier
        //
        var plistResult = command('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleIdentifier', Path.join([appPath, 'Info.plist'])], { mute: true });
        if (plistResult.status != 0) {
            fail('Failed to read bundle identifier from built app');
        }
        var bundleIdentifier = plistResult.stdout.trim();

        // Install on device
        //
        print('Install ' + project.app.name + '.app on ' + device.name);
        if (command('xcrun', ['devicectl', 'device', 'install', 'app', '--device', device.identifier, appPath]).status != 0) {
            fail('Failed to install the app on the device.
Make sure the device is unlocked, paired with this Mac, and that
Developer Mode is enabled (Settings > Privacy & Security > Developer Mode).');
        }

        // Launch with the app streams attached to this console.
        // devicectl blocks until the app exits and forwards signals,
        // so Ctrl+C stops the app.
        //
        InstanceManager.makeUnique('run ~ ' + context.cwd);

        print('Launch $bundleIdentifier');
        launchWithConsole(device.identifier, bundleIdentifier, outTargetPath);

    }

    function resolveDevice(outTargetPath:String, requestedDevice:String):{ identifier:String, udid:String, name:String } {

        var devicesJsonPath = Path.join([outTargetPath, 'devicectl-devices.json']);
        if (command('xcrun', ['devicectl', 'list', 'devices', '--json-output', devicesJsonPath, '--quiet'], { mute: true }).status != 0) {
            fail('Failed to list devices with devicectl');
        }

        var devices:Array<{ identifier:String, udid:String, name:String }> = [];
        var json:Dynamic = Json.parse(sys.io.File.getContent(devicesJsonPath));
        var jsonDevices:Array<Dynamic> = json.result.devices;
        for (jsonDevice in jsonDevices) {
            var platform:String = jsonDevice.hardwareProperties != null ? jsonDevice.hardwareProperties.platform : null;
            var tunnelState:String = jsonDevice.connectionProperties != null ? jsonDevice.connectionProperties.tunnelState : null;
            if (platform == 'iOS' && tunnelState == 'connected') {
                devices.push({
                    identifier: jsonDevice.identifier,
                    udid: jsonDevice.hardwareProperties.udid,
                    name: jsonDevice.deviceProperties != null ? jsonDevice.deviceProperties.name : jsonDevice.identifier
                });
            }
        }

        if (devices.length == 0) {
            fail('No iOS device connected.
Plug in an iPhone or iPad with USB and unlock it. The device must be paired
with this Mac and have Developer Mode enabled
(Settings > Privacy & Security > Developer Mode).');
        }

        if (requestedDevice != null && requestedDevice.trim() != '') {
            var requested = requestedDevice.trim();
            for (device in devices) {
                if (device.name == requested || device.udid == requested || device.identifier == requested) {
                    return device;
                }
            }
            fail('No connected iOS device matching "$requested".
Connected devices: ' + devices.map(device -> device.name + ' (' + device.udid + ')').join(', '));
        }

        if (devices.length > 1) {
            print('Multiple devices connected, using the first one. Use --device <name|udid> or CERAMIC_IOS_DEVICE to pick another.');
        }

        return devices[0];

    }

    /**
     * Runs `devicectl device process launch --console` streaming the app
     * output line by line, with the same haxe trace formatting as when
     * running a desktop build.
     */
    function launchWithConsole(deviceIdentifier:String, bundleIdentifier:String, logCwd:String):Void {

        final proc = new Process('xcrun', [
            'devicectl', 'device', 'process', 'launch',
            '--console', '--terminate-existing',
            '--device', deviceIdentifier,
            bundleIdentifier
        ], context.cwd);

        proc.inherit_file_descriptors = false;

        var stdout = new SplitStream('\n'.code, line -> {
            line = formatLineOutput(logCwd, line);
            stdoutWrite(line + "\n");
        });

        var stderr = new SplitStream('\n'.code, line -> {
            line = formatLineOutput(logCwd, line);
            stderrWrite(line + "\n");
        });

        proc.read_stdout = data -> {
            stdout.add(data);
        };

        proc.read_stderr = data -> {
            stderr.add(data);
        };

        proc.create();

        var status = proc.tick_until_exit_status(() -> {
            Runner.tick();
            timer.update();
            if (context.shouldExit) {
                proc.kill(false);
                Sys.exit(0);
            }
        });

        if (status != 0) {
            fail('Failed to launch the app (status $status).
Make sure the device is still connected and unlocked, then try again.');
        }

    }

}
