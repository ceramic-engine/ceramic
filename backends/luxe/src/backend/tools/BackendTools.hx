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
            name: 'web',
            displayName: 'Web',
            configs: [
                Build('Build Web', 'flow build web'),
                Run('Run Web', 'flow run web'),
                Clean('Clean Web', 'flow clean web')
            ]
        });

        targets.push({
            name: 'mac',
            displayName: 'Mac',
            configs: [
                Build('Build Mac', 'flow build mac'),
                Run('Run Mac', 'flow run mac'),
                Clean('Clean Mac', 'flow clean mac')
            ]
        });

        targets.push({
            name: 'ios',
            displayName: 'iOS',
            configs: [
                Build('Build iOS', 'flow build ios'),
                Run('Run iOS', 'flow run ios'),
                Clean('Clean iOS', 'flow clean ios')
            ]
        });

        targets.push({
            name: 'android',
            displayName: 'Android',
            configs: [
                Build('Build Android', 'flow build android'),
                Run('Run Android', 'flow run android'),
                Clean('Clean Android', 'flow clean android')
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

        return res.stdout != null ? ''+res.stdout : null;

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
