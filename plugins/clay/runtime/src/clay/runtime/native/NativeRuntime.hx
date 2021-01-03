package clay.runtime.native;

import sdl.SDL;
import timestamp.Timestamp;

#if clay_use_glew
import glew.GLEW;
#end

/**
 * Native runtime, using SDL to operate
 */
class NativeRuntime implements clay.runtime.spec.Runtime implements tracker.Events {

/// Events

    /**
     * When an SDL event is fired
     * @param event 
     */
    @event function sdlEvent(event:sdl.Event);

/// Properties

    /**
     * The SDL GL context
     */
    public var gl:sdl.GLContext;

    /**
     * The SDL window handle
     */
    public var window:sdl.Window;

    /**
     * Toggle auto window swap
     */
    public var autoSwap:Bool = true;

    /**
     * Current SDL event being handled, if any
     */
    public var currentSdlEvent:sdl.Event = null;

    /**
     * Whether the window was hidden at startup
     */
    public var windowHiddenAtStartup:Bool = false;

/// Lifecycle

    function new() {

    }

}
