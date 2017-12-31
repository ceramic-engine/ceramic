package ceramic;

// Substantial portion of the following code taken from snow/luxe (https://luxeengine.com)

/** The keyCode class, with conversion helpers for scanCodes. The values below come directly from SDL header include files,
but they aren't specific to SDL so they are used generically */
class KeyCode {

    /** Convert a scanCode to a keyCode for comparison */
    public static inline function fromScanCode( scanCode:Int ):Int {

        return (scanCode | ScanCode.MASK);

    } //fromScanCode

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
            case KeyCode.ENTER:         return ScanCode.ENTER;
            case KeyCode.ESCAPE:        return ScanCode.ESCAPE;
            case KeyCode.BACKSPACE:     return ScanCode.BACKSPACE;
            case KeyCode.TAB:           return ScanCode.TAB;
            case KeyCode.SPACE:         return ScanCode.SPACE;
            case KeyCode.SLASH:         return ScanCode.SLASH;
            case KeyCode.KEY_0:         return ScanCode.KEY_0;
            case KeyCode.KEY_1:         return ScanCode.KEY_1;
            case KeyCode.KEY_2:         return ScanCode.KEY_2;
            case KeyCode.KEY_3:         return ScanCode.KEY_3;
            case KeyCode.KEY_4:         return ScanCode.KEY_4;
            case KeyCode.KEY_5:         return ScanCode.KEY_5;
            case KeyCode.KEY_6:         return ScanCode.KEY_6;
            case KeyCode.KEY_7:         return ScanCode.KEY_7;
            case KeyCode.KEY_8:         return ScanCode.KEY_8;
            case KeyCode.KEY_9:         return ScanCode.KEY_9;
            case KeyCode.SEMICOLON:     return ScanCode.SEMICOLON;
            case KeyCode.EQUALS:        return ScanCode.EQUALS;
            case KeyCode.LEFTBRACKET:   return ScanCode.LEFTBRACKET;
            case KeyCode.BACKSLASH:     return ScanCode.BACKSLASH;
            case KeyCode.RIGHTBRACKET:  return ScanCode.RIGHTBRACKET;
            case KeyCode.BACKQUOTE:     return ScanCode.GRAVE;
            case KeyCode.KEY_A:         return ScanCode.KEY_A;
            case KeyCode.KEY_B:         return ScanCode.KEY_B;
            case KeyCode.KEY_C:         return ScanCode.KEY_C;
            case KeyCode.KEY_D:         return ScanCode.KEY_D;
            case KeyCode.KEY_E:         return ScanCode.KEY_E;
            case KeyCode.KEY_F:         return ScanCode.KEY_F;
            case KeyCode.KEY_G:         return ScanCode.KEY_G;
            case KeyCode.KEY_H:         return ScanCode.KEY_H;
            case KeyCode.KEY_I:         return ScanCode.KEY_I;
            case KeyCode.KEY_J:         return ScanCode.KEY_J;
            case KeyCode.KEY_K:         return ScanCode.KEY_K;
            case KeyCode.KEY_L:         return ScanCode.KEY_L;
            case KeyCode.KEY_M:         return ScanCode.KEY_M;
            case KeyCode.KEY_N:         return ScanCode.KEY_N;
            case KeyCode.KEY_O:         return ScanCode.KEY_O;
            case KeyCode.KEY_P:         return ScanCode.KEY_P;
            case KeyCode.KEY_Q:         return ScanCode.KEY_Q;
            case KeyCode.KEY_R:         return ScanCode.KEY_R;
            case KeyCode.KEY_S:         return ScanCode.KEY_S;
            case KeyCode.KEY_T:         return ScanCode.KEY_T;
            case KeyCode.KEY_U:         return ScanCode.KEY_U;
            case KeyCode.KEY_V:         return ScanCode.KEY_V;
            case KeyCode.KEY_W:         return ScanCode.KEY_W;
            case KeyCode.KEY_X:         return ScanCode.KEY_X;
            case KeyCode.KEY_Y:         return ScanCode.KEY_Y;
            case KeyCode.KEY_Z:         return ScanCode.KEY_Z;


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

    } //toScanCode

    /** Convert a keyCode to string */
    public static function name( keyCode:Int ) : String {

        //we don't use toScanCode because it would consume
        //the typeable characters and we want those as unicode etc.

        if ((keyCode & ScanCode.MASK) != 0) {
            return ScanCode.name(keyCode &~ ScanCode.MASK);
        }

        switch(keyCode) {

            case KeyCode.ENTER:     return ScanCode.name(ScanCode.ENTER);
            case KeyCode.ESCAPE:    return ScanCode.name(ScanCode.ESCAPE);
            case KeyCode.BACKSPACE: return ScanCode.name(ScanCode.BACKSPACE);
            case KeyCode.TAB:       return ScanCode.name(ScanCode.TAB);
            case KeyCode.SPACE:     return ScanCode.name(ScanCode.SPACE);
            case KeyCode.DELETE:    return ScanCode.name(ScanCode.DELETE);
            
            case KeyCode.KEY_A:     return ScanCode.name(ScanCode.KEY_A);
            case KeyCode.KEY_B:     return ScanCode.name(ScanCode.KEY_B);
            case KeyCode.KEY_C:     return ScanCode.name(ScanCode.KEY_C);
            case KeyCode.KEY_D:     return ScanCode.name(ScanCode.KEY_D);
            case KeyCode.KEY_E:     return ScanCode.name(ScanCode.KEY_E);
            case KeyCode.KEY_F:     return ScanCode.name(ScanCode.KEY_F);
            case KeyCode.KEY_G:     return ScanCode.name(ScanCode.KEY_G);
            case KeyCode.KEY_H:     return ScanCode.name(ScanCode.KEY_H);
            case KeyCode.KEY_I:     return ScanCode.name(ScanCode.KEY_I);
            case KeyCode.KEY_J:     return ScanCode.name(ScanCode.KEY_J);
            case KeyCode.KEY_K:     return ScanCode.name(ScanCode.KEY_K);
            case KeyCode.KEY_L:     return ScanCode.name(ScanCode.KEY_L);
            case KeyCode.KEY_M:     return ScanCode.name(ScanCode.KEY_M);
            case KeyCode.KEY_N:     return ScanCode.name(ScanCode.KEY_N);
            case KeyCode.KEY_O:     return ScanCode.name(ScanCode.KEY_O);
            case KeyCode.KEY_P:     return ScanCode.name(ScanCode.KEY_P);
            case KeyCode.KEY_Q:     return ScanCode.name(ScanCode.KEY_Q);
            case KeyCode.KEY_R:     return ScanCode.name(ScanCode.KEY_R);
            case KeyCode.KEY_S:     return ScanCode.name(ScanCode.KEY_S);
            case KeyCode.KEY_T:     return ScanCode.name(ScanCode.KEY_T);
            case KeyCode.KEY_U:     return ScanCode.name(ScanCode.KEY_U);
            case KeyCode.KEY_V:     return ScanCode.name(ScanCode.KEY_V);
            case KeyCode.KEY_W:     return ScanCode.name(ScanCode.KEY_W);
            case KeyCode.KEY_X:     return ScanCode.name(ScanCode.KEY_X);
            case KeyCode.KEY_Y:     return ScanCode.name(ScanCode.KEY_Y);
            case KeyCode.KEY_Z:     return ScanCode.name(ScanCode.KEY_Z);

            default: {

                var decoder = new haxe.Utf8();
                    decoder.addChar(keyCode);

                return decoder.toString();

            } //default

        } //switch(keyCode)

    } //name

    public static inline var UNKNOWN:Int              = 0;

    public static inline var ENTER:Int                = 13;
    public static inline var ESCAPE:Int               = 27;
    public static inline var BACKSPACE:Int            = 8;
    public static inline var TAB:Int                  = 9;
    public static inline var SPACE:Int                = 32;
    public static inline var EXCLAIM:Int              = 33;
    public static inline var QUOTEDBL:Int             = 34;
    public static inline var HASH:Int                 = 35;
    public static inline var PERCENT:Int              = 37;
    public static inline var DOLLAR:Int               = 36;
    public static inline var AMPERSAND:Int            = 38;
    public static inline var QUOTE:Int                = 39;
    public static inline var LEFTPAREN:Int            = 40;
    public static inline var RIGHTPAREN:Int           = 41;
    public static inline var ASTERISK:Int             = 42;
    public static inline var PLUS:Int                 = 43;
    public static inline var COMMA:Int                = 44;
    public static inline var MINUS:Int                = 45;
    public static inline var PERIOD:Int               = 46;
    public static inline var SLASH:Int                = 47;
    public static inline var KEY_0:Int                = 48;
    public static inline var KEY_1:Int                = 49;
    public static inline var KEY_2:Int                = 50;
    public static inline var KEY_3:Int                = 51;
    public static inline var KEY_4:Int                = 52;
    public static inline var KEY_5:Int                = 53;
    public static inline var KEY_6:Int                = 54;
    public static inline var KEY_7:Int                = 55;
    public static inline var KEY_8:Int                = 56;
    public static inline var KEY_9:Int                = 57;
    public static inline var COLON:Int                = 58;
    public static inline var SEMICOLON:Int            = 59;
    public static inline var LESS:Int                 = 60;
    public static inline var EQUALS:Int               = 61;
    public static inline var GREATER:Int              = 62;
    public static inline var QUESTION:Int             = 63;
    public static inline var AT:Int                   = 64;

       // Skip uppercase letters

    public static inline var LEFTBRACKET:Int          = 91;
    public static inline var BACKSLASH:Int            = 92;
    public static inline var RIGHTBRACKET:Int         = 93;
    public static inline var CARET:Int                = 94;
    public static inline var UNDERSCORE:Int           = 95;
    public static inline var BACKQUOTE:Int            = 96;
    public static inline var KEY_A:Int                = 97;
    public static inline var KEY_B:Int                = 98;
    public static inline var KEY_C:Int                = 99;
    public static inline var KEY_D:Int                = 100;
    public static inline var KEY_E:Int                = 101;
    public static inline var KEY_F:Int                = 102;
    public static inline var KEY_G:Int                = 103;
    public static inline var KEY_H:Int                = 104;
    public static inline var KEY_I:Int                = 105;
    public static inline var KEY_J:Int                = 106;
    public static inline var KEY_K:Int                = 107;
    public static inline var KEY_L:Int                = 108;
    public static inline var KEY_M:Int                = 109;
    public static inline var KEY_N:Int                = 110;
    public static inline var KEY_O:Int                = 111;
    public static inline var KEY_P:Int                = 112;
    public static inline var KEY_Q:Int                = 113;
    public static inline var KEY_R:Int                = 114;
    public static inline var KEY_S:Int                = 115;
    public static inline var KEY_T:Int                = 116;
    public static inline var KEY_U:Int                = 117;
    public static inline var KEY_V:Int                = 118;
    public static inline var KEY_W:Int                = 119;
    public static inline var KEY_X:Int                = 120;
    public static inline var KEY_Y:Int                = 121;
    public static inline var KEY_Z:Int                = 122;

    public static inline var CAPSLOCK:Int             = fromScanCode(ScanCode.CAPSLOCK);

    public static inline var F1:Int                   = fromScanCode(ScanCode.F1);
    public static inline var F2:Int                   = fromScanCode(ScanCode.F2);
    public static inline var F3:Int                   = fromScanCode(ScanCode.F3);
    public static inline var F4:Int                   = fromScanCode(ScanCode.F4);
    public static inline var F5:Int                   = fromScanCode(ScanCode.F5);
    public static inline var F6:Int                   = fromScanCode(ScanCode.F6);
    public static inline var F7:Int                   = fromScanCode(ScanCode.F7);
    public static inline var F8:Int                   = fromScanCode(ScanCode.F8);
    public static inline var F9:Int                   = fromScanCode(ScanCode.F9);
    public static inline var F10:Int                  = fromScanCode(ScanCode.F10);
    public static inline var F11:Int                  = fromScanCode(ScanCode.F11);
    public static inline var F12:Int                  = fromScanCode(ScanCode.F12);

    public static inline var PRINTSCREEN:Int          = fromScanCode(ScanCode.PRINTSCREEN);
    public static inline var SCROLLLOCK:Int           = fromScanCode(ScanCode.SCROLLLOCK);
    public static inline var PAUSE:Int                = fromScanCode(ScanCode.PAUSE);
    public static inline var INSERT:Int               = fromScanCode(ScanCode.INSERT);
    public static inline var HOME:Int                 = fromScanCode(ScanCode.HOME);
    public static inline var PAGEUP:Int               = fromScanCode(ScanCode.PAGEUP);
    public static inline var DELETE:Int               = 127;
    public static inline var END:Int                  = fromScanCode(ScanCode.END);
    public static inline var PAGEDOWN:Int             = fromScanCode(ScanCode.PAGEDOWN);
    public static inline var RIGHT:Int                = fromScanCode(ScanCode.RIGHT);
    public static inline var LEFT:Int                 = fromScanCode(ScanCode.LEFT);
    public static inline var DOWN:Int                 = fromScanCode(ScanCode.DOWN);
    public static inline var UP:Int                   = fromScanCode(ScanCode.UP);

    public static inline var NUMLOCKCLEAR:Int         = fromScanCode(ScanCode.NUMLOCKCLEAR);
    public static inline var KP_DIVIDE:Int            = fromScanCode(ScanCode.KP_DIVIDE);
    public static inline var KP_MULTIPLY:Int          = fromScanCode(ScanCode.KP_MULTIPLY);
    public static inline var KP_MINUS:Int             = fromScanCode(ScanCode.KP_MINUS);
    public static inline var KP_PLUS:Int              = fromScanCode(ScanCode.KP_PLUS);
    public static inline var KP_ENTER:Int             = fromScanCode(ScanCode.KP_ENTER);
    public static inline var KP_1:Int                 = fromScanCode(ScanCode.KP_1);
    public static inline var KP_2:Int                 = fromScanCode(ScanCode.KP_2);
    public static inline var KP_3:Int                 = fromScanCode(ScanCode.KP_3);
    public static inline var KP_4:Int                 = fromScanCode(ScanCode.KP_4);
    public static inline var KP_5:Int                 = fromScanCode(ScanCode.KP_5);
    public static inline var KP_6:Int                 = fromScanCode(ScanCode.KP_6);
    public static inline var KP_7:Int                 = fromScanCode(ScanCode.KP_7);
    public static inline var KP_8:Int                 = fromScanCode(ScanCode.KP_8);
    public static inline var KP_9:Int                 = fromScanCode(ScanCode.KP_9);
    public static inline var KP_0:Int                 = fromScanCode(ScanCode.KP_0);
    public static inline var KP_PERIOD:Int            = fromScanCode(ScanCode.KP_PERIOD);

    public static inline var APPLICATION:Int          = fromScanCode(ScanCode.APPLICATION);
    public static inline var POWER:Int                = fromScanCode(ScanCode.POWER);
    public static inline var KP_EQUALS:Int            = fromScanCode(ScanCode.KP_EQUALS);
    public static inline var F13:Int                  = fromScanCode(ScanCode.F13);
    public static inline var F14:Int                  = fromScanCode(ScanCode.F14);
    public static inline var F15:Int                  = fromScanCode(ScanCode.F15);
    public static inline var F16:Int                  = fromScanCode(ScanCode.F16);
    public static inline var F17:Int                  = fromScanCode(ScanCode.F17);
    public static inline var F18:Int                  = fromScanCode(ScanCode.F18);
    public static inline var F19:Int                  = fromScanCode(ScanCode.F19);
    public static inline var F20:Int                  = fromScanCode(ScanCode.F20);
    public static inline var F21:Int                  = fromScanCode(ScanCode.F21);
    public static inline var F22:Int                  = fromScanCode(ScanCode.F22);
    public static inline var F23:Int                  = fromScanCode(ScanCode.F23);
    public static inline var F24:Int                  = fromScanCode(ScanCode.F24);
    public static inline var EXECUTE:Int              = fromScanCode(ScanCode.EXECUTE);
    public static inline var HELP:Int                 = fromScanCode(ScanCode.HELP);
    public static inline var MENU:Int                 = fromScanCode(ScanCode.MENU);
    public static inline var SELECT:Int               = fromScanCode(ScanCode.SELECT);
    public static inline var STOP:Int                 = fromScanCode(ScanCode.STOP);
    public static inline var AGAIN:Int                = fromScanCode(ScanCode.AGAIN);
    public static inline var UNDO:Int                 = fromScanCode(ScanCode.UNDO);
    public static inline var CUT:Int                  = fromScanCode(ScanCode.CUT);
    public static inline var COPY:Int                 = fromScanCode(ScanCode.COPY);
    public static inline var PASTE:Int                = fromScanCode(ScanCode.PASTE);
    public static inline var FIND:Int                 = fromScanCode(ScanCode.FIND);
    public static inline var MUTE:Int                 = fromScanCode(ScanCode.MUTE);
    public static inline var VOLUMEUP:Int             = fromScanCode(ScanCode.VOLUMEUP);
    public static inline var VOLUMEDOWN:Int           = fromScanCode(ScanCode.VOLUMEDOWN);
    public static inline var KP_COMMA:Int             = fromScanCode(ScanCode.KP_COMMA);
    public static inline var KP_EQUALSAS400:Int       = fromScanCode(ScanCode.KP_EQUALSAS400);

    public static inline var ALTERASE:Int             = fromScanCode(ScanCode.ALTERASE);
    public static inline var SYSREQ:Int               = fromScanCode(ScanCode.SYSREQ);
    public static inline var CANCEL:Int               = fromScanCode(ScanCode.CANCEL);
    public static inline var CLEAR:Int                = fromScanCode(ScanCode.CLEAR);
    public static inline var PRIOR:Int                = fromScanCode(ScanCode.PRIOR);
    public static inline var RETURN2:Int              = fromScanCode(ScanCode.RETURN2);
    public static inline var SEPARATOR:Int            = fromScanCode(ScanCode.SEPARATOR);
    public static inline var OUT:Int                  = fromScanCode(ScanCode.OUT);
    public static inline var OPER:Int                 = fromScanCode(ScanCode.OPER);
    public static inline var CLEARAGAIN:Int           = fromScanCode(ScanCode.CLEARAGAIN);
    public static inline var CRSEL:Int                = fromScanCode(ScanCode.CRSEL);
    public static inline var EXSEL:Int                = fromScanCode(ScanCode.EXSEL);

    public static inline var KP_00:Int                = fromScanCode(ScanCode.KP_00);
    public static inline var KP_000:Int               = fromScanCode(ScanCode.KP_000);
    public static inline var THOUSANDSSEPARATOR:Int   = fromScanCode(ScanCode.THOUSANDSSEPARATOR);
    public static inline var DECIMALSEPARATOR:Int     = fromScanCode(ScanCode.DECIMALSEPARATOR);
    public static inline var CURRENCYUNIT:Int         = fromScanCode(ScanCode.CURRENCYUNIT);
    public static inline var CURRENCYSUBUNIT:Int      = fromScanCode(ScanCode.CURRENCYSUBUNIT);
    public static inline var KP_LEFTPAREN:Int         = fromScanCode(ScanCode.KP_LEFTPAREN);
    public static inline var KP_RIGHTPAREN:Int        = fromScanCode(ScanCode.KP_RIGHTPAREN);
    public static inline var KP_LEFTBRACE:Int         = fromScanCode(ScanCode.KP_LEFTBRACE);
    public static inline var KP_RIGHTBRACE:Int        = fromScanCode(ScanCode.KP_RIGHTBRACE);
    public static inline var KP_TAB:Int               = fromScanCode(ScanCode.KP_TAB);
    public static inline var KP_BACKSPACE:Int         = fromScanCode(ScanCode.KP_BACKSPACE);
    public static inline var KP_A:Int                 = fromScanCode(ScanCode.KP_A);
    public static inline var KP_B:Int                 = fromScanCode(ScanCode.KP_B);
    public static inline var KP_C:Int                 = fromScanCode(ScanCode.KP_C);
    public static inline var KP_D:Int                 = fromScanCode(ScanCode.KP_D);
    public static inline var KP_E:Int                 = fromScanCode(ScanCode.KP_E);
    public static inline var KP_F:Int                 = fromScanCode(ScanCode.KP_F);
    public static inline var KP_XOR:Int               = fromScanCode(ScanCode.KP_XOR);
    public static inline var KP_POWER:Int             = fromScanCode(ScanCode.KP_POWER);
    public static inline var KP_PERCENT:Int           = fromScanCode(ScanCode.KP_PERCENT);
    public static inline var KP_LESS:Int              = fromScanCode(ScanCode.KP_LESS);
    public static inline var KP_GREATER:Int           = fromScanCode(ScanCode.KP_GREATER);
    public static inline var KP_AMPERSAND:Int         = fromScanCode(ScanCode.KP_AMPERSAND);
    public static inline var KP_DBLAMPERSAND:Int      = fromScanCode(ScanCode.KP_DBLAMPERSAND);
    public static inline var KP_VERTICALBAR:Int       = fromScanCode(ScanCode.KP_VERTICALBAR);
    public static inline var KP_DBLVERTICALBAR:Int    = fromScanCode(ScanCode.KP_DBLVERTICALBAR);
    public static inline var KP_COLON:Int             = fromScanCode(ScanCode.KP_COLON);
    public static inline var KP_HASH:Int              = fromScanCode(ScanCode.KP_HASH);
    public static inline var KP_SPACE:Int             = fromScanCode(ScanCode.KP_SPACE);
    public static inline var KP_AT:Int                = fromScanCode(ScanCode.KP_AT);
    public static inline var KP_EXCLAM:Int            = fromScanCode(ScanCode.KP_EXCLAM);
    public static inline var KP_MEMSTORE:Int          = fromScanCode(ScanCode.KP_MEMSTORE);
    public static inline var KP_MEMRECALL:Int         = fromScanCode(ScanCode.KP_MEMRECALL);
    public static inline var KP_MEMCLEAR:Int          = fromScanCode(ScanCode.KP_MEMCLEAR);
    public static inline var KP_MEMADD:Int            = fromScanCode(ScanCode.KP_MEMADD);
    public static inline var KP_MEMSUBTRACT:Int       = fromScanCode(ScanCode.KP_MEMSUBTRACT);
    public static inline var KP_MEMMULTIPLY:Int       = fromScanCode(ScanCode.KP_MEMMULTIPLY);
    public static inline var KP_MEMDIVIDE:Int         = fromScanCode(ScanCode.KP_MEMDIVIDE);
    public static inline var KP_PLUSMINUS:Int         = fromScanCode(ScanCode.KP_PLUSMINUS);
    public static inline var KP_CLEAR:Int             = fromScanCode(ScanCode.KP_CLEAR);
    public static inline var KP_CLEARENTRY:Int        = fromScanCode(ScanCode.KP_CLEARENTRY);
    public static inline var KP_BINARY:Int            = fromScanCode(ScanCode.KP_BINARY);
    public static inline var KP_OCTAL:Int             = fromScanCode(ScanCode.KP_OCTAL);
    public static inline var KP_DECIMAL:Int           = fromScanCode(ScanCode.KP_DECIMAL);
    public static inline var KP_HEXADECIMAL:Int       = fromScanCode(ScanCode.KP_HEXADECIMAL);

    public static inline var LCTRL:Int                = fromScanCode(ScanCode.LCTRL);
    public static inline var LSHIFT:Int               = fromScanCode(ScanCode.LSHIFT);
    public static inline var LALT:Int                 = fromScanCode(ScanCode.LALT);
    public static inline var LMETA:Int                = fromScanCode(ScanCode.LMETA);
    public static inline var RCTRL:Int                = fromScanCode(ScanCode.RCTRL);
    public static inline var RSHIFT:Int               = fromScanCode(ScanCode.RSHIFT);
    public static inline var RALT:Int                 = fromScanCode(ScanCode.RALT);
    public static inline var RMETA:Int                = fromScanCode(ScanCode.RMETA);

    public static inline var MODE:Int                 = fromScanCode(ScanCode.MODE);

    public static inline var AUDIONEXT:Int            = fromScanCode(ScanCode.AUDIONEXT);
    public static inline var AUDIOPREV:Int            = fromScanCode(ScanCode.AUDIOPREV);
    public static inline var AUDIOSTOP:Int            = fromScanCode(ScanCode.AUDIOSTOP);
    public static inline var AUDIOPLAY:Int            = fromScanCode(ScanCode.AUDIOPLAY);
    public static inline var AUDIOMUTE:Int            = fromScanCode(ScanCode.AUDIOMUTE);
    public static inline var MEDIASELECT:Int          = fromScanCode(ScanCode.MEDIASELECT);
    public static inline var WWW:Int                  = fromScanCode(ScanCode.WWW);
    public static inline var MAIL:Int                 = fromScanCode(ScanCode.MAIL);
    public static inline var CALCULATOR:Int           = fromScanCode(ScanCode.CALCULATOR);
    public static inline var COMPUTER:Int             = fromScanCode(ScanCode.COMPUTER);
    public static inline var AC_SEARCH:Int            = fromScanCode(ScanCode.AC_SEARCH);
    public static inline var AC_HOME:Int              = fromScanCode(ScanCode.AC_HOME);
    public static inline var AC_BACK:Int              = fromScanCode(ScanCode.AC_BACK);
    public static inline var AC_FORWARD:Int           = fromScanCode(ScanCode.AC_FORWARD);
    public static inline var AC_STOP:Int              = fromScanCode(ScanCode.AC_STOP);
    public static inline var AC_REFRESH:Int           = fromScanCode(ScanCode.AC_REFRESH);
    public static inline var AC_BOOKMARKS:Int         = fromScanCode(ScanCode.AC_BOOKMARKS);

    public static inline var BRIGHTNESSDOWN:Int       = fromScanCode(ScanCode.BRIGHTNESSDOWN);
    public static inline var BRIGHTNESSUP:Int         = fromScanCode(ScanCode.BRIGHTNESSUP);
    public static inline var DISPLAYSWITCH:Int        = fromScanCode(ScanCode.DISPLAYSWITCH);
    public static inline var KBDILLUMTOGGLE:Int       = fromScanCode(ScanCode.KBDILLUMTOGGLE);
    public static inline var KBDILLUMDOWN:Int         = fromScanCode(ScanCode.KBDILLUMDOWN);
    public static inline var KBDILLUMUP:Int           = fromScanCode(ScanCode.KBDILLUMUP);
    public static inline var EJECT:Int                = fromScanCode(ScanCode.EJECT);
    public static inline var SLEEP:Int                = fromScanCode(ScanCode.SLEEP);

} //KeyCode
