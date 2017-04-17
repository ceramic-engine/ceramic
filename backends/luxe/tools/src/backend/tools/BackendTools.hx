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

    public function getHxml(cwd:String, args:Array<String>, target:tools.BuildTarget):String {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name]);
        
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

    public function getHxmlCwd(cwd:String, args:Array<String>, target:tools.BuildTarget):String {

        var flowProjectPath = Path.join([cwd, 'out', 'luxe', target.name]);

        return flowProjectPath;

    } //getHxmlCwd

    public function runSetup(cwd:String, args:Array<String>, target:tools.BuildTarget, fromBuild:Bool = false):Void {

        var task = new backend.tools.tasks.Setup(target, fromBuild);
        task.run(cwd, args);

    } //runSetup

    public function runBuild(cwd:String, args:Array<String>, target:tools.BuildTarget, configIndex:Int = 0):Void {

        var task = new backend.tools.tasks.Build(target, configIndex);
        task.run(cwd, args);

    } //runBuild

    public function getAssets(assets:Array<tools.Asset>, target:tools.BuildTarget):Array<tools.Asset> {

        return assets;

    } //getAssets

} //Config
