package;

import haxe.io.Path;

class Main {

    public static var project:Project = null;

    static var _lastUpdateTime:Float = -1;

    public static function main():Void {

        project = @:privateAccess new Project(ceramic.App.init());
        ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..']));

        #if js
        _lastUpdateTime = untyped __js__('new Date().getTime()');
        untyped __js__('setInterval({0}, 100)', update);
        #end

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    } //main

    static function update() {

        #if js
        var time:Float = untyped __js__('new Date().getTime()');
        var delta = (time - _lastUpdateTime) * 0.001;
        _lastUpdateTime = time;

        // Update
        ceramic.App.app.backend.emitUpdate(delta);
        #end

    } //update

} //Main
