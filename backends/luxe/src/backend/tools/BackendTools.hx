package backend.tools;

class BackendTools implements tools.spec.BackendTools {

    public function new() {

    } //new

    public function getBuildTargets():Array<tools.BuildTarget> {

        var targets:Array<tools.BuildTarget> = [];

        targets.push({
            name: 'web',
            displayName: 'Web',
            configs: [
                Build('Build Web', 'flow build web'),
                Run('Run Web', 'flow run web')
            ]
        });

        targets.push({
            name: 'mac',
            displayName: 'Mac',
            configs: [
                Build('Build Mac', 'flow build mac'),
                Run('Run Mac', 'flow run mac')
            ]
        });

        targets.push({
            name: 'ios',
            displayName: 'iOS',
            configs: [
                Build('Build iOS', 'flow build ios'),
                Run('Run iOS', 'flow run ios')
            ]
        });

        targets.push({
            name: 'android',
            displayName: 'Android',
            configs: [
                Build('Build Android', 'flow build android'),
                Run('Run Android', 'flow run android')
            ]
        });

        return targets;

    } //getBuildConfigs

    public function getSetupTask(target:tools.BuildTarget):tools.Task {

        return new backend.tools.tasks.Setup(target);

    } //getSetupTask

    public function getBuildTask(target:tools.BuildTarget, configIndex:Int = 0):tools.Task {

        return null;

    } //getBuildTask

    public function getAssets(assets:Array<tools.Asset>, target:tools.BuildTarget):Array<tools.Asset> {

        return assets;

    } //getAssets

} //Config
