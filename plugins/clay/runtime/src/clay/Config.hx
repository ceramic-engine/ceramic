package clay;

#if clay_web
typedef RuntimeConfig = clay.web.WebConfig;
#elseif clay_sdl
typedef RuntimeConfig = clay.sdl.SDLConfig;
#end

/** Config specific to the rendering context that would be used when creating windows */
typedef RenderConfig = {

    /** Request the number of depth bits for the rendering context.
        A value of 0 will not request a depth buffer. default: 0 */
    @:optional var depth:Int;

    /** Request the number of stencil bits for the rendering context.
        A value of 0 will not request a stencil buffer. default: 0 */
    @:optional var stencil:Int;

    /** A value of `0`, `2`, `4`, `8` or other valid system value.
        On WebGL contexts this value is true or false, bigger than 0 being true.
        On native contexts this value sets the MSAA typically.
        default webgl: 1 (enabled)
        default: 0 */
    @:optional var antialiasing:Int;

    /** Request a specific number of red bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    @:optional var redBits:Int;
    /** Request a specific number of green bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    @:optional var greenBits:Int;
    /** Request a specific number of blue bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    @:optional var blueBits:Int;
    /** Request a specific number of alpha bits for the rendering context.
        Unless you need to change this, don't. default: 8 */
    @:optional var alphaBits:Int;

    /** A color value that when creating the window, the window backbuffer will be cleared to.
        A framework above clay can also use this for default clear color if desired.
        The values are specified as 0..1. default: black, 0,0,0,1  */
    @:optional var defaultClear:{ r:Float, g:Float, b:Float, a:Float };

    #if clay_web

    /** WebGL render context specific settings */
    @:optional var webgl:RenderConfigWebGL;

    #elseif clay_sdl

    /** OpenGL render context specific settings */
    @:optional var opengl:RenderConfigOpenGL;

    #end

}

#if clay_web

/** Config specific to a WebGL rendering context.
    See: https://www.khronos.org/registry/webgl/specs/latest/1.0/#WEBGLCONTEXTATTRIBUTES */
typedef RenderConfigWebGL = {

    /** The WebGL version to request. default: 1 */
    @:optional var version:Int;

    /** If the value is true, the drawing buffer has an alpha channel for the
        purposes of performing OpenGL destination alpha operations and
        compositing with the page. If the value is false, no alpha buffer is available.
        clay default: false
        webgl default: true */
    @:optional var alpha:Bool;

    /** If the value is true, the drawing buffer has a depth buffer of at least 16 bits.
        If the value is false, no depth buffer is available.
        clay default: uses render config depth flag
        webgl default: true */
    @:optional var depth:Bool;

    /** If the value is true, the drawing buffer has a stencil buffer of at least 8 bits.
        If the value is false, no stencil buffer is available.
        clay default: uses render config stencil flag
        webgl default: false */
    @:optional var stencil:Bool;

    /** If the value is true and the implementation supports antialiasing the drawing buffer
        will perform antialiasing using its choice of technique (multisample/supersample) and quality.
        If the value is false or the implementation does not support
        antialiasing, no antialiasing is performed
        clay default: uses render config antialias flag
        webgl default: true */
    @:optional var antialias:Bool;
    
    /** If the value is true the page compositor will assume the drawing buffer contains colors with premultiplied alpha.
        If the value is false the page compositor will assume that colors in the drawing buffer are not premultiplied.
        This flag is ignored if the alpha flag is false.
        clay default: false
        webgl default: true */
    @:optional var premultipliedAlpha:Bool;

    /** If false, once the drawing buffer is presented as described in theDrawing Buffer section,
        the contents of the drawing buffer are cleared to their default values. All elements of the
        drawing buffer (color, depth and stencil) are cleared. If the value is true the buffers will
        not be cleared and will preserve their values until cleared or overwritten by the author.
        On some hardware setting the preserveDrawingBuffer flag to true can have significant performance implications.
        clay default: uses webgl default
        webgl default: false */
    @:optional var preserveDrawingBuffer:Bool;

    /** Provides a hint to the implementation suggesting that, if possible, it creates a context
        that optimizes for power consumption over performance. For example, on hardware that has more
        than one GPU, it may be the case that one of them is less powerful but also uses less power.
        An implementation may choose to, and may have to, ignore this hint.
        clay default: uses webgl default
        webgl default: false */
    @:optional var preferLowPowerToHighPerformance:Bool;

    /** If the value is true, context creation will fail if the implementation determines that the
        performance of the created WebGL context would be dramatically lower than that of a native
        application making equivalent OpenGL calls.
        clay default: uses webgl default
        webgl default: false */
    @:optional var failIfMajorPerformanceCaveat:Bool;

}

#elseif clay_sdl

/** A type of OpenGL context profile to request. see RenderConfigOpenGL for info */
enum abstract OpenGLProfile(Int)
    from Int to Int {

    var COMPATIBILITY = 0;

    var CORE = 1;

    var GLES = 2;

    inline function toString() {
        return switch(this) {
            case COMPATIBILITY: 'COMPATIBILITY';
            case CORE:          'CORE';
            case GLES:          'GLES';
            case _:             '$this';
        }
    }

}

/** Config specific to an OpenGL rendering context.
    Note that these are hints to the system,
    you must always check the values after initializing
    for what you actually received. The OS/driver decides. */
typedef RenderConfigOpenGL = {

    /** The major OpenGL version to request */
    @:optional var major:Int;

    /** The minor OpenGL version to request */
    @:optional var minor:Int;

    /** The OpenGL context profile to request */
    @:optional var profile:OpenGLProfile;

}

#end

/** Window configuration information for creating windows */
typedef WindowConfig = {

    /** create in fullscreen, default: false, `mobile` true */
    @:optional var fullscreen:Bool;
    
    /** If false, the users native window/desktop resolution will be used instead of the specified window size. default: false
        On native, changing the users video mode is less than ideal, so trueFullscreen is commonly discouraged. */
    @:optional var trueFullscreen:Bool;

    /** allow the window to be resized, default: true */
    @:optional var resizable:Bool;

    /** create as a borderless window, default: false */
    @:optional var borderless:Bool;

    /** window x at creation. Leave this alone to use the OS default. */
    @:optional var x:Int;

    /** window y at creation. Leave this alone to use the OS default. */
    @:optional var y:Int;

    /** window width at creation, default: 960 */
    @:optional var width:Int;

    /** window height at creation, default: 640 */
    @:optional var height:Int;

    /** window title, default: 'clay app' */
    @:optional var title:String;
    
    /** disables input arriving at/from this window. default: false */
    @:optional var noInput:Bool;

    /** Time in seconds to sleep when in the background. 
        Setting this to zero disables the behavior. 
        This has no effect on the web target, 
        as there is no concept of sleep there (and browsers usually throttle background tabs).
        Higher sleep times (i.e 1/10 or 1/30) use less cpu. default: 1/15 */
    @:optional var backgroundSleep:Float;

}

typedef Config = {

    /**
     * The window config for the default window. default: see `WindowConfig` docs
     */
    @:optional var window:WindowConfig;

    /**
     * The render config that specifies rendering and context backend specifics.
     */
    @:optional var render:RenderConfig;

    /**
     * The runtime specific config
     */
    @:optional var runtime:RuntimeConfig;

}
