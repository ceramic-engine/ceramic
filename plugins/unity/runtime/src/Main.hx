package;

import ceramic.Path;
import unityengine.AudioMixer;
import unityengine.MonoBehaviour;

class Main {

    public static var project:Project = null;

    static var _lastUpdateTime:Float = 0;

    #if unity_urp
    static var _lastRegularUpdateTime:Float = 0;
    #end

    static var _hasCriticalError:Bool = false;

    public static var monoBehaviour:MonoBehaviour = null;

    public static var audioMixer:AudioMixer = null;

    @:keep public static function sync(monoBehaviour:MonoBehaviour, audioMixer:AudioMixer):Void {

        Main.monoBehaviour = monoBehaviour;
        Main.audioMixer = audioMixer;

        if (ceramic.App.app == null || ceramic.App.app.backend == null) {
            main();
        }

    }

    @:keep public static function main():Void {

        // Force to sync app fps with screen fps
        var isEditor:Bool = untyped __cs__('UnityEngine.Application.isEditor');
        untyped __cs__('UnityEngine.QualitySettings.vSyncCount = 1');

        var settings = ceramic.App.init();
        if (isEditor) {
            settings.targetFps = 60;
        }
        project = @:privateAccess new Project(settings);
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..'])); // Fix this TODO

        // Init last update time
        _lastUpdateTime = Sys.cpuTime();

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    }

    #if unity_urp

    @:keep public static function regularUpdate() {

        if (_hasCriticalError)
            return;

        var time:Float = Sys.cpuTime();
        var delta = (time - _lastRegularUpdateTime);
        _lastRegularUpdateTime = time;

        ceramic.App.app.backend.screen.update();
        ceramic.App.app.backend.input.update(delta);

    }

    @:keep public static function renderPassUpdate() {

        if (_hasCriticalError)
            return;

        update();

    }

    #end

    @:keep public static function update() {

        if (_hasCriticalError)
            return;

        #if !ceramic_no_unity_catch_exit
        try {
        #end

            var time:Float = Sys.cpuTime();
            var delta = (time - _lastUpdateTime);
            _lastUpdateTime = time;

            #if !unity_urp
            ceramic.App.app.backend.screen.update();
            ceramic.App.app.backend.input.update(delta);
            #end

            // Update
            ceramic.App.app.backend.emitUpdate(delta);
            ceramic.App.app.backend.emitRender();

        #if !ceramic_no_unity_catch_exit
        }
        catch (e:Dynamic) {

            markCriticalError();
            untyped __cs__('throw');

        }
        #end

    }

    @:noCompletion public static function hasCriticalError():Bool {

        return _hasCriticalError;

    }

    @:noCompletion public static function markCriticalError():Void {

        _hasCriticalError = true;

    }

}
