package;

class Main {

    public static var project:Project = null;

    static var _cwd:String = null;

    static var _lastUpdateTime:Float = -1;

    public static function main():Void {

        _cwd = Sys.getCwd();
        project = @:privateAccess new Project(ceramic.App.init());

        _lastUpdateTime = untyped __js__('new Date().getTime()');
        js.Node.setInterval(update, 100);

        // Emit ready event
        ceramic.App.app.backend.emitReady();

    } //main

    static function update() {

        var time:Float = untyped __js__('new Date().getTime()');
        var delta = time - _lastUpdateTime;
        _lastUpdateTime = time;

        // Update
        ceramic.App.app.backend.emitUpdate(delta);

    } //update

} //Main
