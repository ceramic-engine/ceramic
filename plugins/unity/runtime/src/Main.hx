package;

import ceramic.Path;

class Main {

    public static var project:Project = null;

    static var _lastUpdateTime:Float = -1;

    public static function main():Void {

        var settings = ceramic.App.init();
        project = @:privateAccess new Project(settings);
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..'])); // Fix this TODO

        // Init last update time
        _lastUpdateTime = Sys.time();

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    }

    public static function update() {

        var time:Float = Sys.time();
        var delta = (time - _lastUpdateTime) * 0.001;
        _lastUpdateTime = time;

        // Update
        ceramic.App.app.backend.emitUpdate(delta);

    }

}
