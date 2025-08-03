package ceramic;

using ceramic.Extensions;

import ceramic.Shortcuts.*;

#if web
import ceramic.ImGuiImplJS as ImGuiImpl;
#elseif cpp
import ceramic.ImGuiImplCPP as ImGuiImpl;
#end

/**
 * System that manages the Dear ImGui integration in Ceramic.
 * 
 * This system handles:
 * - Platform-specific backend initialization (C++ or JavaScript)
 * - Frame lifecycle management (newFrame/endFrame calls)
 * - Integration with Ceramic's update and render loops
 * 
 * The system automatically selects the appropriate backend based on the target:
 * - C++ targets use SDL2 and OpenGL
 * - Web targets use emscripten-compiled ImGui with WebGL
 * 
 * ImGui rendering happens after all Ceramic visuals are drawn, ensuring
 * the UI appears on top of the game content.
 * 
 * @see ImGuiPlugin
 * @see ImGuiImplCPP
 * @see ImGuiImplJS
 */
class ImGuiSystem extends System {

    /**
     * Shared ImGui system instance.
     * Automatically created when first accessed.
     */
    @lazy public static var shared = new ImGuiSystem();

    /**
     * Whether a frame is currently pending.
     * Not currently used but kept for potential future use.
     */
    var framePending:Bool = false;

    override function new() {

        super();

        // Set high priority to ensure ImGui frame starts before other systems
        earlyUpdateOrder = 1000;

    }

    /**
     * Starts the ImGui system.
     * Called by ImGuiPlugin during initialization.
     * @param done Callback invoked when the system is ready
     */
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

    /**
     * Called at the beginning of each frame.
     * Starts a new ImGui frame, making it ready to receive drawing commands.
     * @param delta Time elapsed since last frame in seconds
     */
    override function earlyUpdate(delta:Float):Void {

        #if (web || cpp)

        ImGuiImpl.newFrame();

        #end

    }

}
