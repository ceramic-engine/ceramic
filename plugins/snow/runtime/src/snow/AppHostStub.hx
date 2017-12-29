package snow;

import snow.types.Types;
import snow.modules.opengl.GL;

typedef UserConfig = {}

class AppHostStub extends snow.App {

    function new() {}

    override function config(config:AppConfig):AppConfig {

        return config;

    } //config

    override function ready() {}

    override function onkeyup(keycode:Int, _,_, mod:ModState, _,_) {}

    override function tick(delta:Float) {}

} //Main
