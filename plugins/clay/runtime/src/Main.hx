package;

import clay.Clay;
import ceramic.Path;

class Main {

    public static var project:Project = null;

    public static function main() {
        
        @:privateAccess new Clay();

    }

    // static var _lastUpdateTime:Float = -1;

    // public static function main():Void {

    //     project = @:privateAccess new Project(ceramic.App.init());
        
    //     #if (!ceramic_no_fs && (sys || node || nodejs || hxnodejs))
    //     ceramic.App.app.projectDir = Path.normalize(Path.join([Sys.getCwd(), '../../..']));
    //     #end

    //     #if js
    //     _lastUpdateTime = untyped __js__('new Date().getTime()');
    //     untyped __js__('setInterval({0}, 100)', update);
    //     #end

    //     // Emit ready event
    //     ceramic.App.app.backend.emitReady();

    // }

    // static function update() {

    //     #if js
    //     var time:Float = untyped __js__('new Date().getTime()');
    //     var delta = (time - _lastUpdateTime) * 0.001;
    //     _lastUpdateTime = time;

    //     // Update
    //     ceramic.App.app.backend.emitUpdate(delta);
    //     #end

    // }

}
