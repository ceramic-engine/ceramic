package;

import haxe.io.Path;

import unityengine.Time;

class Main {

    public static var project:Project = null;

    static var _lastUpdateTime:Float = -1;

    public static function main():Void {

        project = @:privateAccess new Project(ceramic.App.init());
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..'])); // Fix this TODO

        // Init last update time
        _lastUpdateTime = Sys.time();

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    } //main

    public static function update() {

        var time:Float = Sys.time();
        var delta = (time - _lastUpdateTime) * 0.001;
        _lastUpdateTime = time;

        // Update
        ceramic.App.app.backend.emitUpdate(delta);

    } //update

} //Main
