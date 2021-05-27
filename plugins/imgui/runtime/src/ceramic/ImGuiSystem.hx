package ceramic;

using ceramic.Extensions;

import ceramic.Shortcuts.*;

#if web
import ceramic.ImGuiImplJS as ImGuiImpl;
#elseif cpp
import ceramic.ImGuiImplCPP as ImGuiImpl;
#end

class ImGuiSystem extends System {

    /**
     * Shared imgui system
     */
    @lazy public static var shared = new ImGuiSystem();

    var framePending:Bool = false;

    override function new() {

        super();

        earlyUpdateOrder = 1000;

    }

    @:allow(ceramic.ImGuiPlugin)
    function start(done:()->Void):Void {

        #if (web || cpp)

        ImGuiImpl.init(function() {
            app.onFinishDraw(this, ImGuiImpl.endFrame);
            done();
        });

        #else

        done();

        #end

    }

    override function earlyUpdate(delta:Float):Void {

        #if (web || cpp)

        ImGuiImpl.newFrame();

        #end

    }

}
