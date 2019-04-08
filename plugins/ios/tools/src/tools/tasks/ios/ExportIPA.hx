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

        return "Export a packaged iOS app (IPA).";

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

        // Get user dir
        var userDir = ('/Users/'+ChildProcess.execSync('whoami')).trim();

        // Create custom keychain?
        var createKeychain = extractArgValue(args, 'create-keychain', true);
        if (createKeychain != null) {
            keychainFile = createKeychain + '.keychain';
            command('security', ['create-keychain', '-p', createKeychain, keychainFile]);
            command('security', ['default-keychain', '-s', keychainFile]);
            command('security', ['unlock-keychain', '-p', createKeychain]);
            command('security', ['set-keychain-settings', '-t', '3600', '-u', keychainFile]);
        }

        // Create ios project if needed
        IosProject.createIosProjectIfNeeded(cwd, project);

        // Update build number
        IosProject.updateBuildNumber(cwd, project);

        // Reset build path
        var buildPath = Path.join([iosProjectPath, 'build']);
        if (FileSystem.exists(buildPath)) {
            Files.deleteRecursive(buildPath);
        }
        FileSystem.createDirectory(buildPath);
        var iosIPAPath = Path.join([buildPath, iosProjectName + '.ipa']);

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
            print('Install signing certificate');
            print('p12: $p12Path');
            print('keychain: $keychainFile');
            print('identity: $signingIdentity');
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

        // Delete previous ipa if any
        if (FileSystem.exists(iosIPAPath)) {
            FileSystem.deleteFile(iosIPAPath);
        }

        // Extract more signing options
        var teamId = extractArgValue(args, 'team-id', true);
        var profileId = extractArgValue(args, 'profile-id', true);
        var profileName = extractArgValue(args, 'profile-name', true);
        
        var pbxPath = Path.join([iosProjectPath, iosProjectName + '.xcodeproj', 'project.pbxproj']);

        var originalPbxContent:String = null;
        var restorePbx:Void->Void = function() {};
        if (teamId != null && profileId != null && profileName != null) {
            var pbxContent = File.getContent(pbxPath);
            originalPbxContent = pbxContent;

            pbxContent = pbxContent.replace('CODE_SIGN_STYLE = Automatic', 'CODE_SIGN_STYLE = Manual');
            pbxContent = pbxContent.replace('ProvisioningStyle = Automatic', 'ProvisioningStyle = Manual');
            pbxContent = pbxContent.replace('DEVELOPMENT_TEAM = ""', 'DEVELOPMENT_TEAM = $teamId');

            // This should be improved as for now it will only work with ceramic-generated Xcode projects. Should be smarter
            pbxContent = replaceWithLimit(pbxContent, 'PROVISIONING_PROFILE = ""', 'PROVISIONING_PROFILE = "$profileId"', 2);
            pbxContent = replaceWithLimit(pbxContent, 'PROVISIONING_PROFILE_SPECIFIER = ""', 'PROVISIONING_PROFILE_SPECIFIER = "$profileName"', 2);

            print('ORIGINAL PBX $originalPbxContent');
            print('--------------------------------');
            print('NEW PBX $pbxContent');

            File.saveContent(pbxPath, pbxContent);

            restorePbx = function() {
                File.saveContent(pbxPath, originalPbxContent);
            };
        }

        // Build
        command('xcodebuild', [
            '-workspace', iosProjectName + '.xcworkspace',
            '-scheme', iosProjectName,
            '-configuration', 'Release',
            '-derivedDataPath', buildPath,
            '-destination', 'generic/platform=iOS',
            'build'
        ], { cwd: Path.join([cwd, 'project/ios']) });

        // Archive
        var result = command('xcodebuild', [
            '-workspace', iosProjectName + '.xcworkspace',
            '-scheme', iosProjectName,
            '-configuration', 'Release',
            '-derivedDataPath', buildPath,
            '-destination', 'generic/platform=iOS',
            'archive',
            '-archivePath', buildPath + '/' + iosProjectName + '.xcarchive'
        ], { cwd: Path.join([cwd, 'project/ios']) });
        if (result.status != 0) {
            restorePbx();
            fail('Xcode build failed with status ' + result.status);
        }

        // Export IPA
        result = command('xcodebuild', [
            '-exportArchive',
            '-archivePath', buildPath + '/' + iosProjectName + '.xcarchive',
            '-exportOptionsPlist', 'exportOptions.plist',
            '-exportPath', buildPath
        ], { cwd: Path.join([cwd, 'project/ios']) });
        if (result.status != 0) {
            restorePbx();
            fail('Xcode archive failed with status ' + result.status);
        }
        restorePbx();

        // Check that IPA has been generated
        if (!FileSystem.exists(iosIPAPath)) {
            fail('Expected IPA file not found: $iosIPAPath');
        }

        success('Generated IPA file at path: $iosIPAPath');

    } //run

    function replaceWithLimit(text:String, sub:String, by:String, limit:Int):String {

        while (limit-- > 0) {
            var index = text.indexOf(sub);
            if (index != -1) {
                text = text.substring(0, index) + by + text.substr(index + sub.length);
            } else {
                break;
            }
        }

        return text;

    } //replaceWithLimit

} //ExportIPA
