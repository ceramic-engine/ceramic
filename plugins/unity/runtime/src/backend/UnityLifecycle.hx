package backend;

/**
 * Component added by `Main` to the game object running Ceramic: receives
 * Unity's application messages (`OnApplicationFocus`, `OnApplicationPause`)
 * and gives them to the screen (window focus, background and foreground).
 * Added at run time, so that existing Unity projects get it without a
 * change to their `RunCeramic` script.
 */
@:keep
@:nativeGen
class UnityLifecycle extends unityengine.MonoBehaviour {

    function OnApplicationFocus(focused:Bool):Void {

        final app = ceramic.App.app;
        if (app != null && app.backend != null) {
            app.backend.screen.handleApplicationFocus(focused);
        }

    }

    function OnApplicationPause(paused:Bool):Void {

        final app = ceramic.App.app;
        if (app != null && app.backend != null) {
            app.backend.screen.handleApplicationPause(paused);
        }

    }

}
