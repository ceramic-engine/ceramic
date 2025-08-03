package backend;

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
#if documentation

typedef BlendMode = BlendModeImpl;

enum abstract BlendModeImpl(Int) from Int to Int {

    /** Use zero (black) as the blend factor */
    var ZERO                    = 0;
    /** Use one (white) as the blend factor */
    var ONE                     = 1;
    /** Use source color as the blend factor */
    var SRC_COLOR               = 2;
    /** Use one minus source color as the blend factor */
    var ONE_MINUS_SRC_COLOR     = 3;
    /** Use source alpha as the blend factor */
    var SRC_ALPHA               = 4;
    /** Use one minus source alpha as the blend factor */
    var ONE_MINUS_SRC_ALPHA     = 5;
    /** Use destination alpha as the blend factor */
    var DST_ALPHA               = 6;
    /** Use one minus destination alpha as the blend factor */
    var ONE_MINUS_DST_ALPHA     = 7;
    /** Use destination color as the blend factor */
    var DST_COLOR               = 8;
    /** Use one minus destination color as the blend factor */
    var ONE_MINUS_DST_COLOR     = 9;
    /** Use saturated source alpha as the blend factor */
    var SRC_ALPHA_SATURATE      = 10;

}

#else

enum abstract BlendMode(Int) from Int to Int {

    /** Use zero (black) as the blend factor */
    var ZERO                    = 0;
    /** Use one (white) as the blend factor */
    var ONE                     = 1;
    /** Use source color as the blend factor */
    var SRC_COLOR               = 2;
    /** Use one minus source color as the blend factor */
    var ONE_MINUS_SRC_COLOR     = 3;
    /** Use source alpha as the blend factor */
    var SRC_ALPHA               = 4;
    /** Use one minus source alpha as the blend factor */
    var ONE_MINUS_SRC_ALPHA     = 5;
    /** Use destination alpha as the blend factor */
    var DST_ALPHA               = 6;
    /** Use one minus destination alpha as the blend factor */
    var ONE_MINUS_DST_ALPHA     = 7;
    /** Use destination color as the blend factor */
    var DST_COLOR               = 8;
    /** Use one minus destination color as the blend factor */
    var ONE_MINUS_DST_COLOR     = 9;
    /** Use saturated source alpha as the blend factor */
    var SRC_ALPHA_SATURATE      = 10;

}

#end