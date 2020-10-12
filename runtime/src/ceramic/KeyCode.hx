package ceramic;

// Substantial portion of the following code taken from snow/luxe (https://luxeengine.com)

/** The keyCode class, with conversion helpers for scanCodes. The values below come directly from SDL header include files,
but they aren't specific to SDL so they are used generically */
class KeyCode {

    /** Convert a scanCode to a keyCode for comparison */
    public static inline function fromScanCode( scanCode:Int ):Int {

        return (scanCode | ScanCode.MASK);

    }

    /** Convert a keyCode to a scanCode if possible.
        NOTE - this will only map a large % but not all keys,
        there is a list of unmapped keys commented in the code. */
    public static function toScanCode( keyCode:Int ):Int {

        // Quite a lot map directly to a masked scanCode
        // Ff that's the case, return it directly
        if ((keyCode & ScanCode.MASK) != 0) {
            return keyCode &~ ScanCode.MASK;
        }

        // Now we translate them to the scan where unmapped

        switch(keyCode) {
            case 13  /*KeyCode.ENTER*/:         return ScanCode.ENTER;
            case 27  /*KeyCode.ESCAPE*/:        return ScanCode.ESCAPE;
            case 8   /*KeyCode.BACKSPACE*/:     return ScanCode.BACKSPACE;
            case 9   /*KeyCode.TAB*/:           return ScanCode.TAB;
            case 32  /*KeyCode.SPACE*/:         return ScanCode.SPACE;
            case 47  /*KeyCode.SLASH*/:         return ScanCode.SLASH;
            case 48  /*KeyCode.KEY_0*/:         return ScanCode.KEY_0;
            case 49  /*KeyCode.KEY_1*/:         return ScanCode.KEY_1;
            case 50  /*KeyCode.KEY_2*/:         return ScanCode.KEY_2;
            case 51  /*KeyCode.KEY_3*/:         return ScanCode.KEY_3;
            case 52  /*KeyCode.KEY_4*/:         return ScanCode.KEY_4;
            case 53  /*KeyCode.KEY_5*/:         return ScanCode.KEY_5;
            case 54  /*KeyCode.KEY_6*/:         return ScanCode.KEY_6;
            case 55  /*KeyCode.KEY_7*/:         return ScanCode.KEY_7;
            case 56  /*KeyCode.KEY_8*/:         return ScanCode.KEY_8;
            case 57  /*KeyCode.KEY_9*/:         return ScanCode.KEY_9;
            case 59  /*KeyCode.SEMICOLON*/:     return ScanCode.SEMICOLON;
            case 61  /*KeyCode.EQUALS*/:        return ScanCode.EQUALS;
            case 91  /*KeyCode.LEFTBRACKET*/:   return ScanCode.LEFTBRACKET;
            case 92  /*KeyCode.BACKSLASH*/:     return ScanCode.BACKSLASH;
            case 93  /*KeyCode.RIGHTBRACKET*/:  return ScanCode.RIGHTBRACKET;
            case 96  /*KeyCode.BACKQUOTE*/:     return ScanCode.GRAVE;
            case 97  /*KeyCode.KEY_A*/:         return ScanCode.KEY_A;
            case 98  /*KeyCode.KEY_B*/:         return ScanCode.KEY_B;
            case 99  /*KeyCode.KEY_C*/:         return ScanCode.KEY_C;
            case 100 /*KeyCode.KEY_D*/:         return ScanCode.KEY_D;
            case 101 /*KeyCode.KEY_E*/:         return ScanCode.KEY_E;
            case 102 /*KeyCode.KEY_F*/:         return ScanCode.KEY_F;
            case 103 /*KeyCode.KEY_G*/:         return ScanCode.KEY_G;
            case 104 /*KeyCode.KEY_H*/:         return ScanCode.KEY_H;
            case 105 /*KeyCode.KEY_I*/:         return ScanCode.KEY_I;
            case 106 /*KeyCode.KEY_J*/:         return ScanCode.KEY_J;
            case 107 /*KeyCode.KEY_K*/:         return ScanCode.KEY_K;
            case 108 /*KeyCode.KEY_L*/:         return ScanCode.KEY_L;
            case 109 /*KeyCode.KEY_M*/:         return ScanCode.KEY_M;
            case 110 /*KeyCode.KEY_N*/:         return ScanCode.KEY_N;
            case 111 /*KeyCode.KEY_O*/:         return ScanCode.KEY_O;
            case 112 /*KeyCode.KEY_P*/:         return ScanCode.KEY_P;
            case 113 /*KeyCode.KEY_Q*/:         return ScanCode.KEY_Q;
            case 114 /*KeyCode.KEY_R*/:         return ScanCode.KEY_R;
            case 115 /*KeyCode.KEY_S*/:         return ScanCode.KEY_S;
            case 116 /*KeyCode.KEY_T*/:         return ScanCode.KEY_T;
            case 117 /*KeyCode.KEY_U*/:         return ScanCode.KEY_U;
            case 118 /*KeyCode.KEY_V*/:         return ScanCode.KEY_V;
            case 119 /*KeyCode.KEY_W*/:         return ScanCode.KEY_W;
            case 120 /*KeyCode.KEY_X*/:         return ScanCode.KEY_X;
            case 121 /*KeyCode.KEY_Y*/:         return ScanCode.KEY_Y;
            case 122 /*KeyCode.KEY_Z*/:         return ScanCode.KEY_Z;


            // These are unmappable because they are not keys
            // but values on the key (like a shift key combo)
            // and to hardcode them to the key you think it is,
            // would be to map it to a fixed locale probably.
            // They don't have scanCodes, so we don't return one

            // case exclaim:      ;
            // case quotedbl:     ;
            // case hash:         ;
            // case percent:      ;
            // case dollar:       ;
            // case ampersand:    ;
            // case quote:        ;
            // case leftparen:    ;
            // case rightparen:   ;
            // case asterisk:     ;
            // case plus:         ;
            // case comma:        ;
            // case minus:        ;
            // case period:       ;
            // case less:         ;
            // case colon:        ;
            // case greater:      ;
            // case question:     ;
            // case at:           ;
            // case caret:        ;
            // case underscore:   ;

        } //switch(keyCode)

        return ScanCode.UNKNOWN;

    }

    /** Convert a keyCode to string */
    public static function name( keyCode:Int ) : String {

        //we don't use toScanCode because it would consume
        //the typeable characters and we want those as unicode etc.

        if ((keyCode & ScanCode.MASK) != 0) {
            return ScanCode.name(keyCode &~ ScanCode.MASK);
        }

        switch(keyCode) {

            case 13  /*KeyCode.ENTER*/:     return ScanCode.name(ScanCode.ENTER);
            case 27  /*KeyCode.ESCAPE*/:    return ScanCode.name(ScanCode.ESCAPE);
            case 8   /*KeyCode.BACKSPACE*/: return ScanCode.name(ScanCode.BACKSPACE);
            case 9   /*KeyCode.TAB*/:       return ScanCode.name(ScanCode.TAB);
            case 32  /*KeyCode.SPACE*/:     return ScanCode.name(ScanCode.SPACE);
            case 127 /*KeyCode.DELETE*/:    return ScanCode.name(ScanCode.DELETE);
            
            case 97  /*KeyCode.KEY_A*/:     return ScanCode.name(ScanCode.KEY_A);
            case 98  /*KeyCode.KEY_B*/:     return ScanCode.name(ScanCode.KEY_B);
            case 99  /*KeyCode.KEY_C*/:     return ScanCode.name(ScanCode.KEY_C);
            case 100 /*KeyCode.KEY_D*/:     return ScanCode.name(ScanCode.KEY_D);
            case 101 /*KeyCode.KEY_E*/:     return ScanCode.name(ScanCode.KEY_E);
            case 102 /*KeyCode.KEY_F*/:     return ScanCode.name(ScanCode.KEY_F);
            case 103 /*KeyCode.KEY_G*/:     return ScanCode.name(ScanCode.KEY_G);
            case 104 /*KeyCode.KEY_H*/:     return ScanCode.name(ScanCode.KEY_H);
            case 105 /*KeyCode.KEY_I*/:     return ScanCode.name(ScanCode.KEY_I);
            case 106 /*KeyCode.KEY_J*/:     return ScanCode.name(ScanCode.KEY_J);
            case 107 /*KeyCode.KEY_K*/:     return ScanCode.name(ScanCode.KEY_K);
            case 108 /*KeyCode.KEY_L*/:     return ScanCode.name(ScanCode.KEY_L);
            case 109 /*KeyCode.KEY_M*/:     return ScanCode.name(ScanCode.KEY_M);
            case 110 /*KeyCode.KEY_N*/:     return ScanCode.name(ScanCode.KEY_N);
            case 111 /*KeyCode.KEY_O*/:     return ScanCode.name(ScanCode.KEY_O);
            case 112 /*KeyCode.KEY_P*/:     return ScanCode.name(ScanCode.KEY_P);
            case 113 /*KeyCode.KEY_Q*/:     return ScanCode.name(ScanCode.KEY_Q);
            case 114 /*KeyCode.KEY_R*/:     return ScanCode.name(ScanCode.KEY_R);
            case 115 /*KeyCode.KEY_S*/:     return ScanCode.name(ScanCode.KEY_S);
            case 116 /*KeyCode.KEY_T*/:     return ScanCode.name(ScanCode.KEY_T);
            case 117 /*KeyCode.KEY_U*/:     return ScanCode.name(ScanCode.KEY_U);
            case 118 /*KeyCode.KEY_V*/:     return ScanCode.name(ScanCode.KEY_V);
            case 119 /*KeyCode.KEY_W*/:     return ScanCode.name(ScanCode.KEY_W);
            case 120 /*KeyCode.KEY_X*/:     return ScanCode.name(ScanCode.KEY_X);
            case 121 /*KeyCode.KEY_Y*/:     return ScanCode.name(ScanCode.KEY_Y);
            case 122 /*KeyCode.KEY_Z*/:     return ScanCode.name(ScanCode.KEY_Z);

            default: {

                return String.fromCharCode(keyCode);

            }

        } //switch(keyCode)

    }

    public static #if (!no_inline && !haxe_server) inline #end var UNKNOWN:Int              = 0;

    public static #if (!no_inline && !haxe_server) inline #end var ENTER:Int                = 13;
    public static #if (!no_inline && !haxe_server) inline #end var ESCAPE:Int               = 27;
    public static #if (!no_inline && !haxe_server) inline #end var BACKSPACE:Int            = 8;
    public static #if (!no_inline && !haxe_server) inline #end var TAB:Int                  = 9;
    public static #if (!no_inline && !haxe_server) inline #end var SPACE:Int                = 32;
    public static #if (!no_inline && !haxe_server) inline #end var EXCLAIM:Int              = 33;
    public static #if (!no_inline && !haxe_server) inline #end var QUOTEDBL:Int             = 34;
    public static #if (!no_inline && !haxe_server) inline #end var HASH:Int                 = 35;
    public static #if (!no_inline && !haxe_server) inline #end var PERCENT:Int              = 37;
    public static #if (!no_inline && !haxe_server) inline #end var DOLLAR:Int               = 36;
    public static #if (!no_inline && !haxe_server) inline #end var AMPERSAND:Int            = 38;
    public static #if (!no_inline && !haxe_server) inline #end var QUOTE:Int                = 39;
    public static #if (!no_inline && !haxe_server) inline #end var LEFTPAREN:Int            = 40;
    public static #if (!no_inline && !haxe_server) inline #end var RIGHTPAREN:Int           = 41;
    public static #if (!no_inline && !haxe_server) inline #end var ASTERISK:Int             = 42;
    public static #if (!no_inline && !haxe_server) inline #end var PLUS:Int                 = 43;
    public static #if (!no_inline && !haxe_server) inline #end var COMMA:Int                = 44;
    public static #if (!no_inline && !haxe_server) inline #end var MINUS:Int                = 45;
    public static #if (!no_inline && !haxe_server) inline #end var PERIOD:Int               = 46;
    public static #if (!no_inline && !haxe_server) inline #end var SLASH:Int                = 47;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_0:Int                = 48;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_1:Int                = 49;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_2:Int                = 50;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_3:Int                = 51;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_4:Int                = 52;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_5:Int                = 53;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_6:Int                = 54;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_7:Int                = 55;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_8:Int                = 56;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_9:Int                = 57;
    public static #if (!no_inline && !haxe_server) inline #end var COLON:Int                = 58;
    public static #if (!no_inline && !haxe_server) inline #end var SEMICOLON:Int            = 59;
    public static #if (!no_inline && !haxe_server) inline #end var LESS:Int                 = 60;
    public static #if (!no_inline && !haxe_server) inline #end var EQUALS:Int               = 61;
    public static #if (!no_inline && !haxe_server) inline #end var GREATER:Int              = 62;
    public static #if (!no_inline && !haxe_server) inline #end var QUESTION:Int             = 63;
    public static #if (!no_inline && !haxe_server) inline #end var AT:Int                   = 64;

       // Skip uppercase letters

    public static #if (!no_inline && !haxe_server) inline #end var LEFTBRACKET:Int          = 91;
    public static #if (!no_inline && !haxe_server) inline #end var BACKSLASH:Int            = 92;
    public static #if (!no_inline && !haxe_server) inline #end var RIGHTBRACKET:Int         = 93;
    public static #if (!no_inline && !haxe_server) inline #end var CARET:Int                = 94;
    public static #if (!no_inline && !haxe_server) inline #end var UNDERSCORE:Int           = 95;
    public static #if (!no_inline && !haxe_server) inline #end var BACKQUOTE:Int            = 96;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_A:Int                = 97;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_B:Int                = 98;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_C:Int                = 99;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_D:Int                = 100;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_E:Int                = 101;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_F:Int                = 102;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_G:Int                = 103;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_H:Int                = 104;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_I:Int                = 105;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_J:Int                = 106;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_K:Int                = 107;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_L:Int                = 108;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_M:Int                = 109;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_N:Int                = 110;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_O:Int                = 111;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_P:Int                = 112;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_Q:Int                = 113;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_R:Int                = 114;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_S:Int                = 115;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_T:Int                = 116;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_U:Int                = 117;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_V:Int                = 118;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_W:Int                = 119;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_X:Int                = 120;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_Y:Int                = 121;
    public static #if (!no_inline && !haxe_server) inline #end var KEY_Z:Int                = 122;

    public static #if (!no_inline && !haxe_server) inline #end var CAPSLOCK:Int             = fromScanCode(ScanCode.CAPSLOCK);

    public static #if (!no_inline && !haxe_server) inline #end var F1:Int                   = fromScanCode(ScanCode.F1);
    public static #if (!no_inline && !haxe_server) inline #end var F2:Int                   = fromScanCode(ScanCode.F2);
    public static #if (!no_inline && !haxe_server) inline #end var F3:Int                   = fromScanCode(ScanCode.F3);
    public static #if (!no_inline && !haxe_server) inline #end var F4:Int                   = fromScanCode(ScanCode.F4);
    public static #if (!no_inline && !haxe_server) inline #end var F5:Int                   = fromScanCode(ScanCode.F5);
    public static #if (!no_inline && !haxe_server) inline #end var F6:Int                   = fromScanCode(ScanCode.F6);
    public static #if (!no_inline && !haxe_server) inline #end var F7:Int                   = fromScanCode(ScanCode.F7);
    public static #if (!no_inline && !haxe_server) inline #end var F8:Int                   = fromScanCode(ScanCode.F8);
    public static #if (!no_inline && !haxe_server) inline #end var F9:Int                   = fromScanCode(ScanCode.F9);
    public static #if (!no_inline && !haxe_server) inline #end var F10:Int                  = fromScanCode(ScanCode.F10);
    public static #if (!no_inline && !haxe_server) inline #end var F11:Int                  = fromScanCode(ScanCode.F11);
    public static #if (!no_inline && !haxe_server) inline #end var F12:Int                  = fromScanCode(ScanCode.F12);

    public static #if (!no_inline && !haxe_server) inline #end var PRINTSCREEN:Int          = fromScanCode(ScanCode.PRINTSCREEN);
    public static #if (!no_inline && !haxe_server) inline #end var SCROLLLOCK:Int           = fromScanCode(ScanCode.SCROLLLOCK);
    public static #if (!no_inline && !haxe_server) inline #end var PAUSE:Int                = fromScanCode(ScanCode.PAUSE);
    public static #if (!no_inline && !haxe_server) inline #end var INSERT:Int               = fromScanCode(ScanCode.INSERT);
    public static #if (!no_inline && !haxe_server) inline #end var HOME:Int                 = fromScanCode(ScanCode.HOME);
    public static #if (!no_inline && !haxe_server) inline #end var PAGEUP:Int               = fromScanCode(ScanCode.PAGEUP);
    public static #if (!no_inline && !haxe_server) inline #end var DELETE:Int               = 127;
    public static #if (!no_inline && !haxe_server) inline #end var END:Int                  = fromScanCode(ScanCode.END);
    public static #if (!no_inline && !haxe_server) inline #end var PAGEDOWN:Int             = fromScanCode(ScanCode.PAGEDOWN);
    public static #if (!no_inline && !haxe_server) inline #end var RIGHT:Int                = fromScanCode(ScanCode.RIGHT);
    public static #if (!no_inline && !haxe_server) inline #end var LEFT:Int                 = fromScanCode(ScanCode.LEFT);
    public static #if (!no_inline && !haxe_server) inline #end var DOWN:Int                 = fromScanCode(ScanCode.DOWN);
    public static #if (!no_inline && !haxe_server) inline #end var UP:Int                   = fromScanCode(ScanCode.UP);

    public static #if (!no_inline && !haxe_server) inline #end var NUMLOCKCLEAR:Int         = fromScanCode(ScanCode.NUMLOCKCLEAR);
    public static #if (!no_inline && !haxe_server) inline #end var KP_DIVIDE:Int            = fromScanCode(ScanCode.KP_DIVIDE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MULTIPLY:Int          = fromScanCode(ScanCode.KP_MULTIPLY);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MINUS:Int             = fromScanCode(ScanCode.KP_MINUS);
    public static #if (!no_inline && !haxe_server) inline #end var KP_PLUS:Int              = fromScanCode(ScanCode.KP_PLUS);
    public static #if (!no_inline && !haxe_server) inline #end var KP_ENTER:Int             = fromScanCode(ScanCode.KP_ENTER);
    public static #if (!no_inline && !haxe_server) inline #end var KP_1:Int                 = fromScanCode(ScanCode.KP_1);
    public static #if (!no_inline && !haxe_server) inline #end var KP_2:Int                 = fromScanCode(ScanCode.KP_2);
    public static #if (!no_inline && !haxe_server) inline #end var KP_3:Int                 = fromScanCode(ScanCode.KP_3);
    public static #if (!no_inline && !haxe_server) inline #end var KP_4:Int                 = fromScanCode(ScanCode.KP_4);
    public static #if (!no_inline && !haxe_server) inline #end var KP_5:Int                 = fromScanCode(ScanCode.KP_5);
    public static #if (!no_inline && !haxe_server) inline #end var KP_6:Int                 = fromScanCode(ScanCode.KP_6);
    public static #if (!no_inline && !haxe_server) inline #end var KP_7:Int                 = fromScanCode(ScanCode.KP_7);
    public static #if (!no_inline && !haxe_server) inline #end var KP_8:Int                 = fromScanCode(ScanCode.KP_8);
    public static #if (!no_inline && !haxe_server) inline #end var KP_9:Int                 = fromScanCode(ScanCode.KP_9);
    public static #if (!no_inline && !haxe_server) inline #end var KP_0:Int                 = fromScanCode(ScanCode.KP_0);
    public static #if (!no_inline && !haxe_server) inline #end var KP_PERIOD:Int            = fromScanCode(ScanCode.KP_PERIOD);

    public static #if (!no_inline && !haxe_server) inline #end var APPLICATION:Int          = fromScanCode(ScanCode.APPLICATION);
    public static #if (!no_inline && !haxe_server) inline #end var POWER:Int                = fromScanCode(ScanCode.POWER);
    public static #if (!no_inline && !haxe_server) inline #end var KP_EQUALS:Int            = fromScanCode(ScanCode.KP_EQUALS);
    public static #if (!no_inline && !haxe_server) inline #end var F13:Int                  = fromScanCode(ScanCode.F13);
    public static #if (!no_inline && !haxe_server) inline #end var F14:Int                  = fromScanCode(ScanCode.F14);
    public static #if (!no_inline && !haxe_server) inline #end var F15:Int                  = fromScanCode(ScanCode.F15);
    public static #if (!no_inline && !haxe_server) inline #end var F16:Int                  = fromScanCode(ScanCode.F16);
    public static #if (!no_inline && !haxe_server) inline #end var F17:Int                  = fromScanCode(ScanCode.F17);
    public static #if (!no_inline && !haxe_server) inline #end var F18:Int                  = fromScanCode(ScanCode.F18);
    public static #if (!no_inline && !haxe_server) inline #end var F19:Int                  = fromScanCode(ScanCode.F19);
    public static #if (!no_inline && !haxe_server) inline #end var F20:Int                  = fromScanCode(ScanCode.F20);
    public static #if (!no_inline && !haxe_server) inline #end var F21:Int                  = fromScanCode(ScanCode.F21);
    public static #if (!no_inline && !haxe_server) inline #end var F22:Int                  = fromScanCode(ScanCode.F22);
    public static #if (!no_inline && !haxe_server) inline #end var F23:Int                  = fromScanCode(ScanCode.F23);
    public static #if (!no_inline && !haxe_server) inline #end var F24:Int                  = fromScanCode(ScanCode.F24);
    public static #if (!no_inline && !haxe_server) inline #end var EXECUTE:Int              = fromScanCode(ScanCode.EXECUTE);
    public static #if (!no_inline && !haxe_server) inline #end var HELP:Int                 = fromScanCode(ScanCode.HELP);
    public static #if (!no_inline && !haxe_server) inline #end var MENU:Int                 = fromScanCode(ScanCode.MENU);
    public static #if (!no_inline && !haxe_server) inline #end var SELECT:Int               = fromScanCode(ScanCode.SELECT);
    public static #if (!no_inline && !haxe_server) inline #end var STOP:Int                 = fromScanCode(ScanCode.STOP);
    public static #if (!no_inline && !haxe_server) inline #end var AGAIN:Int                = fromScanCode(ScanCode.AGAIN);
    public static #if (!no_inline && !haxe_server) inline #end var UNDO:Int                 = fromScanCode(ScanCode.UNDO);
    public static #if (!no_inline && !haxe_server) inline #end var CUT:Int                  = fromScanCode(ScanCode.CUT);
    public static #if (!no_inline && !haxe_server) inline #end var COPY:Int                 = fromScanCode(ScanCode.COPY);
    public static #if (!no_inline && !haxe_server) inline #end var PASTE:Int                = fromScanCode(ScanCode.PASTE);
    public static #if (!no_inline && !haxe_server) inline #end var FIND:Int                 = fromScanCode(ScanCode.FIND);
    public static #if (!no_inline && !haxe_server) inline #end var MUTE:Int                 = fromScanCode(ScanCode.MUTE);
    public static #if (!no_inline && !haxe_server) inline #end var VOLUMEUP:Int             = fromScanCode(ScanCode.VOLUMEUP);
    public static #if (!no_inline && !haxe_server) inline #end var VOLUMEDOWN:Int           = fromScanCode(ScanCode.VOLUMEDOWN);
    public static #if (!no_inline && !haxe_server) inline #end var KP_COMMA:Int             = fromScanCode(ScanCode.KP_COMMA);
    public static #if (!no_inline && !haxe_server) inline #end var KP_EQUALSAS400:Int       = fromScanCode(ScanCode.KP_EQUALSAS400);

    public static #if (!no_inline && !haxe_server) inline #end var ALTERASE:Int             = fromScanCode(ScanCode.ALTERASE);
    public static #if (!no_inline && !haxe_server) inline #end var SYSREQ:Int               = fromScanCode(ScanCode.SYSREQ);
    public static #if (!no_inline && !haxe_server) inline #end var CANCEL:Int               = fromScanCode(ScanCode.CANCEL);
    public static #if (!no_inline && !haxe_server) inline #end var CLEAR:Int                = fromScanCode(ScanCode.CLEAR);
    public static #if (!no_inline && !haxe_server) inline #end var PRIOR:Int                = fromScanCode(ScanCode.PRIOR);
    public static #if (!no_inline && !haxe_server) inline #end var RETURN2:Int              = fromScanCode(ScanCode.RETURN2);
    public static #if (!no_inline && !haxe_server) inline #end var SEPARATOR:Int            = fromScanCode(ScanCode.SEPARATOR);
    public static #if (!no_inline && !haxe_server) inline #end var OUT:Int                  = fromScanCode(ScanCode.OUT);
    public static #if (!no_inline && !haxe_server) inline #end var OPER:Int                 = fromScanCode(ScanCode.OPER);
    public static #if (!no_inline && !haxe_server) inline #end var CLEARAGAIN:Int           = fromScanCode(ScanCode.CLEARAGAIN);
    public static #if (!no_inline && !haxe_server) inline #end var CRSEL:Int                = fromScanCode(ScanCode.CRSEL);
    public static #if (!no_inline && !haxe_server) inline #end var EXSEL:Int                = fromScanCode(ScanCode.EXSEL);

    public static #if (!no_inline && !haxe_server) inline #end var KP_00:Int                = fromScanCode(ScanCode.KP_00);
    public static #if (!no_inline && !haxe_server) inline #end var KP_000:Int               = fromScanCode(ScanCode.KP_000);
    public static #if (!no_inline && !haxe_server) inline #end var THOUSANDSSEPARATOR:Int   = fromScanCode(ScanCode.THOUSANDSSEPARATOR);
    public static #if (!no_inline && !haxe_server) inline #end var DECIMALSEPARATOR:Int     = fromScanCode(ScanCode.DECIMALSEPARATOR);
    public static #if (!no_inline && !haxe_server) inline #end var CURRENCYUNIT:Int         = fromScanCode(ScanCode.CURRENCYUNIT);
    public static #if (!no_inline && !haxe_server) inline #end var CURRENCYSUBUNIT:Int      = fromScanCode(ScanCode.CURRENCYSUBUNIT);
    public static #if (!no_inline && !haxe_server) inline #end var KP_LEFTPAREN:Int         = fromScanCode(ScanCode.KP_LEFTPAREN);
    public static #if (!no_inline && !haxe_server) inline #end var KP_RIGHTPAREN:Int        = fromScanCode(ScanCode.KP_RIGHTPAREN);
    public static #if (!no_inline && !haxe_server) inline #end var KP_LEFTBRACE:Int         = fromScanCode(ScanCode.KP_LEFTBRACE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_RIGHTBRACE:Int        = fromScanCode(ScanCode.KP_RIGHTBRACE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_TAB:Int               = fromScanCode(ScanCode.KP_TAB);
    public static #if (!no_inline && !haxe_server) inline #end var KP_BACKSPACE:Int         = fromScanCode(ScanCode.KP_BACKSPACE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_A:Int                 = fromScanCode(ScanCode.KP_A);
    public static #if (!no_inline && !haxe_server) inline #end var KP_B:Int                 = fromScanCode(ScanCode.KP_B);
    public static #if (!no_inline && !haxe_server) inline #end var KP_C:Int                 = fromScanCode(ScanCode.KP_C);
    public static #if (!no_inline && !haxe_server) inline #end var KP_D:Int                 = fromScanCode(ScanCode.KP_D);
    public static #if (!no_inline && !haxe_server) inline #end var KP_E:Int                 = fromScanCode(ScanCode.KP_E);
    public static #if (!no_inline && !haxe_server) inline #end var KP_F:Int                 = fromScanCode(ScanCode.KP_F);
    public static #if (!no_inline && !haxe_server) inline #end var KP_XOR:Int               = fromScanCode(ScanCode.KP_XOR);
    public static #if (!no_inline && !haxe_server) inline #end var KP_POWER:Int             = fromScanCode(ScanCode.KP_POWER);
    public static #if (!no_inline && !haxe_server) inline #end var KP_PERCENT:Int           = fromScanCode(ScanCode.KP_PERCENT);
    public static #if (!no_inline && !haxe_server) inline #end var KP_LESS:Int              = fromScanCode(ScanCode.KP_LESS);
    public static #if (!no_inline && !haxe_server) inline #end var KP_GREATER:Int           = fromScanCode(ScanCode.KP_GREATER);
    public static #if (!no_inline && !haxe_server) inline #end var KP_AMPERSAND:Int         = fromScanCode(ScanCode.KP_AMPERSAND);
    public static #if (!no_inline && !haxe_server) inline #end var KP_DBLAMPERSAND:Int      = fromScanCode(ScanCode.KP_DBLAMPERSAND);
    public static #if (!no_inline && !haxe_server) inline #end var KP_VERTICALBAR:Int       = fromScanCode(ScanCode.KP_VERTICALBAR);
    public static #if (!no_inline && !haxe_server) inline #end var KP_DBLVERTICALBAR:Int    = fromScanCode(ScanCode.KP_DBLVERTICALBAR);
    public static #if (!no_inline && !haxe_server) inline #end var KP_COLON:Int             = fromScanCode(ScanCode.KP_COLON);
    public static #if (!no_inline && !haxe_server) inline #end var KP_HASH:Int              = fromScanCode(ScanCode.KP_HASH);
    public static #if (!no_inline && !haxe_server) inline #end var KP_SPACE:Int             = fromScanCode(ScanCode.KP_SPACE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_AT:Int                = fromScanCode(ScanCode.KP_AT);
    public static #if (!no_inline && !haxe_server) inline #end var KP_EXCLAM:Int            = fromScanCode(ScanCode.KP_EXCLAM);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMSTORE:Int          = fromScanCode(ScanCode.KP_MEMSTORE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMRECALL:Int         = fromScanCode(ScanCode.KP_MEMRECALL);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMCLEAR:Int          = fromScanCode(ScanCode.KP_MEMCLEAR);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMADD:Int            = fromScanCode(ScanCode.KP_MEMADD);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMSUBTRACT:Int       = fromScanCode(ScanCode.KP_MEMSUBTRACT);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMMULTIPLY:Int       = fromScanCode(ScanCode.KP_MEMMULTIPLY);
    public static #if (!no_inline && !haxe_server) inline #end var KP_MEMDIVIDE:Int         = fromScanCode(ScanCode.KP_MEMDIVIDE);
    public static #if (!no_inline && !haxe_server) inline #end var KP_PLUSMINUS:Int         = fromScanCode(ScanCode.KP_PLUSMINUS);
    public static #if (!no_inline && !haxe_server) inline #end var KP_CLEAR:Int             = fromScanCode(ScanCode.KP_CLEAR);
    public static #if (!no_inline && !haxe_server) inline #end var KP_CLEARENTRY:Int        = fromScanCode(ScanCode.KP_CLEARENTRY);
    public static #if (!no_inline && !haxe_server) inline #end var KP_BINARY:Int            = fromScanCode(ScanCode.KP_BINARY);
    public static #if (!no_inline && !haxe_server) inline #end var KP_OCTAL:Int             = fromScanCode(ScanCode.KP_OCTAL);
    public static #if (!no_inline && !haxe_server) inline #end var KP_DECIMAL:Int           = fromScanCode(ScanCode.KP_DECIMAL);
    public static #if (!no_inline && !haxe_server) inline #end var KP_HEXADECIMAL:Int       = fromScanCode(ScanCode.KP_HEXADECIMAL);

    public static #if (!no_inline && !haxe_server) inline #end var LCTRL:Int                = fromScanCode(ScanCode.LCTRL);
    public static #if (!no_inline && !haxe_server) inline #end var LSHIFT:Int               = fromScanCode(ScanCode.LSHIFT);
    public static #if (!no_inline && !haxe_server) inline #end var LALT:Int                 = fromScanCode(ScanCode.LALT);
    public static #if (!no_inline && !haxe_server) inline #end var LMETA:Int                = fromScanCode(ScanCode.LMETA);
    public static #if (!no_inline && !haxe_server) inline #end var RCTRL:Int                = fromScanCode(ScanCode.RCTRL);
    public static #if (!no_inline && !haxe_server) inline #end var RSHIFT:Int               = fromScanCode(ScanCode.RSHIFT);
    public static #if (!no_inline && !haxe_server) inline #end var RALT:Int                 = fromScanCode(ScanCode.RALT);
    public static #if (!no_inline && !haxe_server) inline #end var RMETA:Int                = fromScanCode(ScanCode.RMETA);

    public static #if (!no_inline && !haxe_server) inline #end var MODE:Int                 = fromScanCode(ScanCode.MODE);

    public static #if (!no_inline && !haxe_server) inline #end var AUDIONEXT:Int            = fromScanCode(ScanCode.AUDIONEXT);
    public static #if (!no_inline && !haxe_server) inline #end var AUDIOPREV:Int            = fromScanCode(ScanCode.AUDIOPREV);
    public static #if (!no_inline && !haxe_server) inline #end var AUDIOSTOP:Int            = fromScanCode(ScanCode.AUDIOSTOP);
    public static #if (!no_inline && !haxe_server) inline #end var AUDIOPLAY:Int            = fromScanCode(ScanCode.AUDIOPLAY);
    public static #if (!no_inline && !haxe_server) inline #end var AUDIOMUTE:Int            = fromScanCode(ScanCode.AUDIOMUTE);
    public static #if (!no_inline && !haxe_server) inline #end var MEDIASELECT:Int          = fromScanCode(ScanCode.MEDIASELECT);
    public static #if (!no_inline && !haxe_server) inline #end var WWW:Int                  = fromScanCode(ScanCode.WWW);
    public static #if (!no_inline && !haxe_server) inline #end var MAIL:Int                 = fromScanCode(ScanCode.MAIL);
    public static #if (!no_inline && !haxe_server) inline #end var CALCULATOR:Int           = fromScanCode(ScanCode.CALCULATOR);
    public static #if (!no_inline && !haxe_server) inline #end var COMPUTER:Int             = fromScanCode(ScanCode.COMPUTER);
    public static #if (!no_inline && !haxe_server) inline #end var AC_SEARCH:Int            = fromScanCode(ScanCode.AC_SEARCH);
    public static #if (!no_inline && !haxe_server) inline #end var AC_HOME:Int              = fromScanCode(ScanCode.AC_HOME);
    public static #if (!no_inline && !haxe_server) inline #end var AC_BACK:Int              = fromScanCode(ScanCode.AC_BACK);
    public static #if (!no_inline && !haxe_server) inline #end var AC_FORWARD:Int           = fromScanCode(ScanCode.AC_FORWARD);
    public static #if (!no_inline && !haxe_server) inline #end var AC_STOP:Int              = fromScanCode(ScanCode.AC_STOP);
    public static #if (!no_inline && !haxe_server) inline #end var AC_REFRESH:Int           = fromScanCode(ScanCode.AC_REFRESH);
    public static #if (!no_inline && !haxe_server) inline #end var AC_BOOKMARKS:Int         = fromScanCode(ScanCode.AC_BOOKMARKS);

    public static #if (!no_inline && !haxe_server) inline #end var BRIGHTNESSDOWN:Int       = fromScanCode(ScanCode.BRIGHTNESSDOWN);
    public static #if (!no_inline && !haxe_server) inline #end var BRIGHTNESSUP:Int         = fromScanCode(ScanCode.BRIGHTNESSUP);
    public static #if (!no_inline && !haxe_server) inline #end var DISPLAYSWITCH:Int        = fromScanCode(ScanCode.DISPLAYSWITCH);
    public static #if (!no_inline && !haxe_server) inline #end var KBDILLUMTOGGLE:Int       = fromScanCode(ScanCode.KBDILLUMTOGGLE);
    public static #if (!no_inline && !haxe_server) inline #end var KBDILLUMDOWN:Int         = fromScanCode(ScanCode.KBDILLUMDOWN);
    public static #if (!no_inline && !haxe_server) inline #end var KBDILLUMUP:Int           = fromScanCode(ScanCode.KBDILLUMUP);
    public static #if (!no_inline && !haxe_server) inline #end var EJECT:Int                = fromScanCode(ScanCode.EJECT);
    public static #if (!no_inline && !haxe_server) inline #end var SLEEP:Int                = fromScanCode(ScanCode.SLEEP);

}
