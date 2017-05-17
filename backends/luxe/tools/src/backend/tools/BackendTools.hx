package backend.tools;

import tools.Tools.*;
import haxe.io.Path;

class BackendTools implements tools.spec.BackendTools {

    public var name(default,null):String = 'luxe';

    public function new() {}

    public function init(tools:tools.Tools):Void {

        // Custom setup

    } //init

    public function getBuildTargets():Array<tools.BuildTarget> {

        var targets:Array<tools.BuildTarget> = [];

        targets.push({
            name: 'mac',
            displayName: 'Mac',
            configs: [
                Run('Run Mac'),
                Build('Build Mac'),
                Clean('Clean Mac')
            ]
        });

        targets.push({
            name: 'web',
            displayName: 'Web',
            configs: [
                Run('Run Web'),
                Build('Build Web'),
                Clean('Clean Web')
            ]
        });

        targets.push({
            name: 'ios',
            displayName: 'iOS',
            configs: [
                Run('Run iOS'),
                Build('Build iOS'),
                Clean('Clean iOS')
            ]
        });

        targets.push({
            name: 'android',
            displayName: 'Android',
            configs: [
                Run('Run Android'),
                Build('Build Android'),
                Clean('Clean Android')
            ]
        });

        return targets;

    } //getBuildConfigs

    public function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        
        var cmdArgs = ['run', 'flow', 'info', target.name, '--hxml'];
        var debug = extractArgFlag(args, 'debug');
        if (debug) cmdArgs.push('--debug');

        var res = command('haxelib', cmdArgs, { mute: true, cwd: flowProjectPath });
        
        if (res.status != 0) {
            fail('Error when getting project hxml.');
        }

        var output = res.stdout;
        if (output == null) return null;

        return output + " --macro server.setModuleCheckPolicy(['luxe','snow','phoenix'], [NoCheckShadowing, NoCheckDependencies], true)";

    } //getHxml

    public function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):String {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);

        return flowProjectPath;

    } //getHxmlCwd

    public function getTargetDefines(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String):Map<String,String> {

        var defines = new Map<String,String>();

        defines.set('target', target.name);
        defines.set(target.name, '');

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        defines.set('target_path', flowProjectPath);
        defines.set('assets_path', Path.join([flowProjectPath, 'assets']));

        return defines;

    } //getTargetDefines

    public function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, continueOnFail:Bool = false):Void {

        var task = new backend.tools.tasks.Setup(target, variant, continueOnFail);
        task.run(cwd, args);

    } //runSetup

    public function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, variant:String, configIndex:Int = 0):Void {

        var task = new backend.tools.tasks.Build(target, variant, configIndex);
        task.run(cwd, args);

    } //runBuild

    public function runUpdate(cwd:String, args:Array<String>):Void {

        // Update/install luxe (and dependencies)

        var output = ''+command('haxelib', ['list'], { mute: true }).stdout;
        var libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        if (!libs.exists('snowfall')) {
            if (command('haxelib', ['install', 'snowfall']).status != 0) {
                fail('Error when trying to install snowfall.');
            }
        }

        command('haxelib', ['run', 'snowfall', 'update', 'luxe']);

        // Check that luxe is available
        //
        output = ''+command('haxelib', ['list'], { mute: true }).stdout;
        libs = new Map<String,Bool>();
        for (line in output.split("\n")) {
            var libName = line.split(':')[0];
            libs.set(libName, true);
        }

        if (!libs.exists('luxe')) {
            // Luxe not available?
            fail('Failed to update or install luxe or some of its dependency. Check log.');
        }

    } //runUpdate

    public function transformAssets(cwd:String, assets:Array<tools.Asset>, target:tools.BuildTarget, variant:String):Array<tools.Asset> {

        var newAssets:Array<tools.Asset> = [];
        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name + (variant != 'standard' ? '-' + variant : '')]);
        var validDstPaths:Map<String,Bool> = new Map();
        var dstAssetsPath = Path.join([flowProjectPath, 'assets']);

        // Add/update missing assets
        //
        for (asset in assets) {

            var srcPath = asset.absolutePath;
            var dstPath = Path.join([dstAssetsPath, asset.name]);

            if (!tools.Files.haveSameLastModified(srcPath, dstPath)) {
                // Copy and set to same date
                if (sys.FileSystem.exists(dstPath)) {
                    sys.FileSystem.deleteFile(dstPath);
                }
                var dir = Path.directory(dstPath);
                if (!sys.FileSystem.exists(dir)) {
                    sys.FileSystem.createDirectory(dir);
                }
                sys.io.File.copy(srcPath, dstPath);
                tools.Files.setToSameLastModified(srcPath, dstPath);
            }

            validDstPaths.set(dstPath, true);
            newAssets.push(new tools.Asset(asset.name, dstAssetsPath));
        }

        // Remove outdated assets
        //
        for (name in tools.Files.getFlatDirectory(dstAssetsPath)) {
            var dstPath = Path.join([dstAssetsPath, name]);
            if (!validDstPaths.exists(dstPath)) {
                tools.Files.deleteRecursive(dstPath);
            }
        }
        tools.Files.removeEmptyDirectories(dstAssetsPath);

        return newAssets;

    } //transformAssets

} //Config
