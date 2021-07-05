package backend;

#if documentation

typedef BlendMode = BlendModeImpl;

@:enum abstract BlendModeImpl(Int) from Int to Int {

    var ZERO                    = 0;
    var ONE                     = 1;
    var SRC_COLOR               = 2;
    var ONE_MINUS_SRC_COLOR     = 3;
    var SRC_ALPHA               = 4;
    var ONE_MINUS_SRC_ALPHA     = 5;
    var DST_ALPHA               = 6;
    var ONE_MINUS_DST_ALPHA     = 7;
    var DST_COLOR               = 8;
    var ONE_MINUS_DST_COLOR     = 9;
    var SRC_ALPHA_SATURATE      = 10;

}

#else

@:enum abstract BlendMode(Int) from Int to Int {

    var ZERO                    = 0;
    var ONE                     = 1;
    var SRC_COLOR               = 2;
    var ONE_MINUS_SRC_COLOR     = 3;
    var SRC_ALPHA               = 4;
    var ONE_MINUS_SRC_ALPHA     = 5;
    var DST_ALPHA               = 6;
    var ONE_MINUS_DST_ALPHA     = 7;
    var DST_COLOR               = 8;
    var ONE_MINUS_DST_COLOR     = 9;
    var SRC_ALPHA_SATURATE      = 10;

}

#end
