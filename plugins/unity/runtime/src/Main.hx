package;

import unityengine.MonoBehaviour;
import ceramic.Path;

class Main {

    public static var project:Project = null;

    static var _lastUpdateTime:Float = -1;

    static var _hasCriticalError:Bool = false;

    public static var monoBehaviour:MonoBehaviour = null;

    @:keep public static function sync(monoBehaviour:MonoBehaviour):Void {

        Main.monoBehaviour = monoBehaviour;

        if (ceramic.App.app == null || ceramic.App.app.backend == null) {
            main();
        }

    }

    @:keep public static function main():Void {

        // Force to sync app fps with screen fps
        untyped __cs__('UnityEngine.QualitySettings.vSyncCount = 1');

        var settings = ceramic.App.init();
        project = @:privateAccess new Project(settings);
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..'])); // Fix this TODO

        // Init last update time
        _lastUpdateTime = Sys.cpuTime();

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    }

    @:keep public static function update() {

        if (_hasCriticalError)
            return;

        #if !ceramic_no_unity_catch_exit
        try {
        #end

            var time:Float = Sys.cpuTime();
            var delta = (time - _lastUpdateTime);
            _lastUpdateTime = time;
    
            // Update
            ceramic.App.app.backend.emitUpdate(delta);

        #if !ceramic_no_unity_catch_exit
        }
        catch (e:Dynamic) {

            _hasCriticalError = true;
            untyped __cs__('throw');

        }
        #end

    }

}
