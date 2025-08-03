package backend;

#if !no_backend_docs
/**
 * Blend mode enumeration for the headless backend.
 * 
 * Defines the blend factors used in alpha blending operations.
 * These correspond to OpenGL blend modes and are used to control
 * how new pixels are combined with existing pixels in the framebuffer.
 * 
 * In headless mode, these values are maintained for API compatibility
 * but don't affect any actual rendering since no visual output occurs.
 */
#end
#if documentation

typedef BlendMode = BlendModeImpl;

enum abstract BlendModeImpl(Int) from Int to Int {

    #if !no_backend_docs
    /** Use zero (black) as the blend factor */
    #end
    var ZERO                    = 0;
    #if !no_backend_docs
    /** Use one (white) as the blend factor */
    #end
    var ONE                     = 1;
    #if !no_backend_docs
    /** Use source color as the blend factor */
    #end
    var SRC_COLOR               = 2;
    #if !no_backend_docs
    /** Use one minus source color as the blend factor */
    #end
    var ONE_MINUS_SRC_COLOR     = 3;
    #if !no_backend_docs
    /** Use source alpha as the blend factor */
    #end
    var SRC_ALPHA               = 4;
    #if !no_backend_docs
    /** Use one minus source alpha as the blend factor */
    #end
    var ONE_MINUS_SRC_ALPHA     = 5;
    #if !no_backend_docs
    /** Use destination alpha as the blend factor */
    #end
    var DST_ALPHA               = 6;
    #if !no_backend_docs
    /** Use one minus destination alpha as the blend factor */
    #end
    var ONE_MINUS_DST_ALPHA     = 7;
    #if !no_backend_docs
    /** Use destination color as the blend factor */
    #end
    var DST_COLOR               = 8;
    #if !no_backend_docs
    /** Use one minus destination color as the blend factor */
    #end
    var ONE_MINUS_DST_COLOR     = 9;
    #if !no_backend_docs
    /** Use saturated source alpha as the blend factor */
    #end
    var SRC_ALPHA_SATURATE      = 10;

}

#else

enum abstract BlendMode(Int) from Int to Int {

    #if !no_backend_docs
    /** Use zero (black) as the blend factor */
    #end
    var ZERO                    = 0;
    #if !no_backend_docs
    /** Use one (white) as the blend factor */
    #end
    var ONE                     = 1;
    #if !no_backend_docs
    /** Use source color as the blend factor */
    #end
    var SRC_COLOR               = 2;
    #if !no_backend_docs
    /** Use one minus source color as the blend factor */
    #end
    var ONE_MINUS_SRC_COLOR     = 3;
    #if !no_backend_docs
    /** Use source alpha as the blend factor */
    #end
    var SRC_ALPHA               = 4;
    #if !no_backend_docs
    /** Use one minus source alpha as the blend factor */
    #end
    var ONE_MINUS_SRC_ALPHA     = 5;
    #if !no_backend_docs
    /** Use destination alpha as the blend factor */
    #end
    var DST_ALPHA               = 6;
    #if !no_backend_docs
    /** Use one minus destination alpha as the blend factor */
    #end
    var ONE_MINUS_DST_ALPHA     = 7;
    #if !no_backend_docs
    /** Use destination color as the blend factor */
    #end
    var DST_COLOR               = 8;
    #if !no_backend_docs
    /** Use one minus destination color as the blend factor */
    #end
    var ONE_MINUS_DST_COLOR     = 9;
    #if !no_backend_docs
    /** Use saturated source alpha as the blend factor */
    #end
    var SRC_ALPHA_SATURATE      = 10;

}

#end