package tools.tasks.ios;

import tools.Helpers.*;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.IosProject;

import js.node.ChildProcess;

using StringTools;

class ExportIPA extends tools.Task {

    override public function info(cwd:String):String {

        return "Install Xcode project pod dependencies.";

    } //info

    override function run(cwd:String, args:Array<String>):Void {

        // Add ios flag
        if (!context.defines.exists('ios')) {
            context.defines.set('ios', '');
        }

        var project = ensureCeramicProject(cwd, args, App);

        var keychainFile = 'login.keychain';

        var iosProjectName = project.app.name;
        var iosProjectPath = Path.join([cwd, 'project/ios']);
        var iosProjectFile = Path.join([iosProjectPath, iosProjectName + '.xcodeproj']);
        var iosWorkspaceFile = Path.join([iosProjectPath, iosProjectName + '.xcworkspace']);

        // Get user dir
        var userDir = ('/Users/'+ChildProcess.execSync('whoami')).trim();

        // Create custom keychain?
        var createKeychain = extractArgValue(args, 'create-keychain', true);
        if (createKeychain != null) {
            keychainFile = createKeychain + '.keychain';
            command('security', ['create-keychain', '-p', createKeychain, keychainFile]);
            command('security', ['default-keychain', '-s', keychainFile]);
            command('security', ['unlock-keychain', '-p', createKeychain]);
            command('security', ['set-keychain-settings', '-t', '3600', '-u', createKeychain]);
        }

        // Create ios project if needed
        IosProject.createIosProjectIfNeeded(cwd, project);

        var derivedDataPath = Path.join([iosProjectPath, 'build']);
        if (!FileSystem.exists(derivedDataPath)) {
            FileSystem.createDirectory(derivedDataPath);
        }

        // Get signing identities
        //
        while (true) {
            var p12Path = extractArgValue(args, 'p12-path', true);
            if (p12Path == null) {
                break;
            }
            var p12Password = extractArgValue(args, 'p12-password', true);
            if (p12Password == null) {
                fail('--p12-password argument specifying a valid .p12 password is required');
            }
            
            if (!Path.isAbsolute(p12Path)) p12Path = Path.join([cwd, p12Path]);

            if (!FileSystem.exists(p12Path)) {
                fail('P12 file not found at path: $p12Path');
            }

            // Retrieve signing identity
            var signingIdentity:String = null;
            var tmpPemPath = Path.join([context.cwd, 'tmp/xcodebuild/keystore.pem']);
            command('rm', ['-rf', Path.join([context.cwd, 'tmp/xcodebuild'])]);
            command('mkdir', ['-p', Path.join([context.cwd, 'tmp/xcodebuild'])]);
            command('openssl', ['pkcs12', '-passin', 'pass:'+p12Password, '-in', p12Path, '-out', tmpPemPath, '-nodes']);
            var pemData = File.getContent(tmpPemPath);
            if (pemData == null || pemData.trim() == '') {
                fail('Error when extracting signing identity from $p12Path');
            }
            for (line in pemData.split("\n")) {
                line = line.trim();
                if (line.indexOf('friendlyName') == 0) {
                    signingIdentity = line.substring(line.indexOf(': ')+1).trim();
                    signingIdentity = signingIdentity.substr(0, signingIdentity.lastIndexOf('(')).trim();
                    break;
                }
            }
            if (signingIdentity == null || signingIdentity.trim() == '') {
                fail('Error when extracting signing identity from $p12Path pem');
            }
            command('rm', ['-rf', Path.join([context.cwd, 'tmp/xcodebuild'])]);

            // Install signing certificate
            command('security', ['import', p12Path, '-t', 'agg', '-k', keychainFile, '-P', p12Password, '-A']);
        }

        if (createKeychain != null) {
            // Unlock keychain to prevent signing issues (https://docs.travis-ci.com/user/common-build-problems/#mac-macos-sierra-1012-code-signing-errors)
            command('security', ['set-key-partition-list', '-S', 'apple-tool:,apple:', '-s', '-k', createKeychain, keychainFile]);
        }

        // Get provisioning profiles
        //
        while (true) {
            var provisioningProfilePath = extractArgValue(args, 'provisioning-profile', true);
            if (provisioningProfilePath == null) {
                break;
            }
            if (!Path.isAbsolute(provisioningProfilePath)) provisioningProfilePath = Path.join([cwd, provisioningProfilePath]);

            // Extract provisioning profile UUID
            var provisioningUUID = ('' + ChildProcess.execSync("/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< $(security cms -D -i " + provisioningProfilePath.quoteUnixArg() + ")")).trim();

            // Create ~/Library/MobileDevice/Provisioning Profiles/ folders if it doesn't exist
            var profilesPath = '$userDir/Library/MobileDevice/Provisioning Profiles';
            if (!FileSystem.exists(profilesPath)) {
                FileSystem.createDirectory(profilesPath);
            }
            // Add our provisioning profile if needed
            if (!FileSystem.exists(Path.join([profilesPath, provisioningUUID+'.mobileprovision']))) {
                command('cp', ['-f', provisioningProfilePath, Path.join([profilesPath, provisioningUUID+'.mobileprovision'])]);
            }
        }

        // TODO

        // Run xcodebuild
        command('xcodebuild', [
            '-workspace', iosProjectName + '.xcworkspace',
            '-scheme', iosProjectName,
            '-configuration', 'Release',
            '-derivedDataPath', derivedDataPath,
            //'-sdk', 'iphoneos',
            '-destination', 'generic/platform=iOS',
            //'CODE_SIGN_STYLE="Manual"',
            //'CODE_SIGN_IDENTITY=' + signingIdentity,
            //'PROVISIONING_PROFILE=' + provisioningUUID,
            //'DEPLOYMENT_POSTPROCESSING=YES',
            'build'
        ], { cwd: Path.join([cwd, 'project/ios']) });


    } //run

} //ExportIPA
