package backend;

import snow.modules.opengl.GL;

@:enum abstract BlendMode(Int) from Int to Int {

    var ZERO                    = GL.ZERO;
    var ONE                     = GL.ONE;
    var SRC_COLOR               = GL.SRC_COLOR;
    var ONE_MINUS_SRC_COLOR     = GL.ONE_MINUS_SRC_COLOR;
    var SRC_ALPHA               = GL.SRC_ALPHA;
    var ONE_MINUS_SRC_ALPHA     = GL.ONE_MINUS_SRC_ALPHA;
    var DST_ALPHA               = GL.DST_ALPHA;
    var ONE_MINUS_DST_ALPHA     = GL.ONE_MINUS_DST_ALPHA;
    var DST_COLOR               = GL.DST_COLOR;
    var ONE_MINUS_DST_COLOR     = GL.ONE_MINUS_DST_COLOR;
    var SRC_ALPHA_SATURATE      = GL.SRC_ALPHA_SATURATE;

} //BlendMode