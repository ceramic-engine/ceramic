package ceramic;

enum abstract KeyCode(Int) from Int to Int {

    var UNKNOWN:KeyCode             = 0;

    var ENTER:KeyCode               = 13;
    var ESCAPE:KeyCode              = 27;
    var BACKSPACE:KeyCode           = 8;
    var TAB:KeyCode                 = 9;
    var SPACE:KeyCode               = 32;
    var EXCLAIM:KeyCode             = 33;
    var QUOTEDBL:KeyCode            = 34;
    var HASH:KeyCode                = 35;
    var PERCENT:KeyCode             = 37;
    var DOLLAR:KeyCode              = 36;
    var AMPERSAND:KeyCode           = 38;
    var QUOTE:KeyCode               = 39;
    var LEFTPAREN:KeyCode           = 40;
    var RIGHTPAREN:KeyCode          = 41;
    var ASTERISK:KeyCode            = 42;
    var PLUS:KeyCode                = 43;
    var COMMA:KeyCode               = 44;
    var MINUS:KeyCode               = 45;
    var PERIOD:KeyCode              = 46;
    var SLASH:KeyCode               = 47;
    var KEY_0:KeyCode               = 48;
    var KEY_1:KeyCode               = 49;
    var KEY_2:KeyCode               = 50;
    var KEY_3:KeyCode               = 51;
    var KEY_4:KeyCode               = 52;
    var KEY_5:KeyCode               = 53;
    var KEY_6:KeyCode               = 54;
    var KEY_7:KeyCode               = 55;
    var KEY_8:KeyCode               = 56;
    var KEY_9:KeyCode               = 57;
    var COLON:KeyCode               = 58;
    var SEMICOLON:KeyCode           = 59;
    var LESS:KeyCode                = 60;
    var EQUALS:KeyCode              = 61;
    var GREATER:KeyCode             = 62;
    var QUESTION:KeyCode            = 63;
    var AT:KeyCode                  = 64;

    // Skip uppercase letters

    var LEFTBRACKET:KeyCode         = 91;
    var BACKSLASH:KeyCode           = 92;
    var RIGHTBRACKET:KeyCode        = 93;
    var CARET:KeyCode               = 94;
    var UNDERSCORE:KeyCode          = 95;
    var BACKQUOTE:KeyCode           = 96;
    var KEY_A:KeyCode               = 97;
    var KEY_B:KeyCode               = 98;
    var KEY_C:KeyCode               = 99;
    var KEY_D:KeyCode               = 100;
    var KEY_E:KeyCode               = 101;
    var KEY_F:KeyCode               = 102;
    var KEY_G:KeyCode               = 103;
    var KEY_H:KeyCode               = 104;
    var KEY_I:KeyCode               = 105;
    var KEY_J:KeyCode               = 106;
    var KEY_K:KeyCode               = 107;
    var KEY_L:KeyCode               = 108;
    var KEY_M:KeyCode               = 109;
    var KEY_N:KeyCode               = 110;
    var KEY_O:KeyCode               = 111;
    var KEY_P:KeyCode               = 112;
    var KEY_Q:KeyCode               = 113;
    var KEY_R:KeyCode               = 114;
    var KEY_S:KeyCode               = 115;
    var KEY_T:KeyCode               = 116;
    var KEY_U:KeyCode               = 117;
    var KEY_V:KeyCode               = 118;
    var KEY_W:KeyCode               = 119;
    var KEY_X:KeyCode               = 120;
    var KEY_Y:KeyCode               = 121;
    var KEY_Z:KeyCode               = 122;

    var CAPSLOCK:KeyCode            = 57 | (1<<30);

    var F1:KeyCode                  = 58 | (1<<30);
    var F2:KeyCode                  = 59 | (1<<30);
    var F3:KeyCode                  = 60 | (1<<30);
    var F4:KeyCode                  = 61 | (1<<30);
    var F5:KeyCode                  = 62 | (1<<30);
    var F6:KeyCode                  = 63 | (1<<30);
    var F7:KeyCode                  = 64 | (1<<30);
    var F8:KeyCode                  = 65 | (1<<30);
    var F9:KeyCode                  = 66 | (1<<30);
    var F10:KeyCode                 = 67 | (1<<30);
    var F11:KeyCode                 = 68 | (1<<30);
    var F12:KeyCode                 = 69 | (1<<30);

    var PRINTSCREEN:KeyCode         = 70 | (1<<30);
    var SCROLLLOCK:KeyCode          = 71 | (1<<30);
    var PAUSE:KeyCode               = 72 | (1<<30);

    var INSERT:KeyCode              = 73 | (1<<30);
    var HOME:KeyCode                = 74 | (1<<30);
    var PAGEUP:KeyCode              = 75 | (1<<30);
    var DELETE:KeyCode              = 127;
    var END:KeyCode                 = 77 | (1<<30);
    var PAGEDOWN:KeyCode            = 78 | (1<<30);
    var RIGHT:KeyCode               = 79 | (1<<30);
    var LEFT:KeyCode                = 80 | (1<<30);
    var DOWN:KeyCode                = 81 | (1<<30);
    var UP:KeyCode                  = 82 | (1<<30);

    var NUMLOCKCLEAR:KeyCode        = 83 | (1<<30);
    var KP_DIVIDE:KeyCode           = 84 | (1<<30);
    var KP_MULTIPLY:KeyCode         = 85 | (1<<30);
    var KP_MINUS:KeyCode            = 86 | (1<<30);
    var KP_PLUS:KeyCode             = 87 | (1<<30);
    var KP_ENTER:KeyCode            = 88 | (1<<30);
    var KP_1:KeyCode                = 89 | (1<<30);
    var KP_2:KeyCode                = 90 | (1<<30);
    var KP_3:KeyCode                = 91 | (1<<30);
    var KP_4:KeyCode                = 92 | (1<<30);
    var KP_5:KeyCode                = 93 | (1<<30);
    var KP_6:KeyCode                = 94 | (1<<30);
    var KP_7:KeyCode                = 95 | (1<<30);
    var KP_8:KeyCode                = 96 | (1<<30);
    var KP_9:KeyCode                = 97 | (1<<30);
    var KP_0:KeyCode                = 98 | (1<<30);
    var KP_PERIOD:KeyCode           = 99 | (1<<30);

    var APPLICATION:KeyCode         = 101 | (1<<30);

    var POWER:KeyCode               = 102 | (1<<30);
    var KP_EQUALS:KeyCode           = 103 | (1<<30);
    var F13:KeyCode                 = 104 | (1<<30);
    var F14:KeyCode                 = 105 | (1<<30);
    var F15:KeyCode                 = 106 | (1<<30);
    var F16:KeyCode                 = 107 | (1<<30);
    var F17:KeyCode                 = 108 | (1<<30);
    var F18:KeyCode                 = 109 | (1<<30);
    var F19:KeyCode                 = 110 | (1<<30);
    var F20:KeyCode                 = 111 | (1<<30);
    var F21:KeyCode                 = 112 | (1<<30);
    var F22:KeyCode                 = 113 | (1<<30);
    var F23:KeyCode                 = 114 | (1<<30);
    var F24:KeyCode                 = 115 | (1<<30);
    var EXECUTE:KeyCode             = 116 | (1<<30);
    var HELP:KeyCode                = 117 | (1<<30);
    var MENU:KeyCode                = 118 | (1<<30);
    var SELECT:KeyCode              = 119 | (1<<30);
    var STOP:KeyCode                = 120 | (1<<30);

    var AGAIN:KeyCode               = 121 | (1<<30);
    var UNDO:KeyCode                = 122 | (1<<30);
    var CUT:KeyCode                 = 123 | (1<<30);
    var COPY:KeyCode                = 124 | (1<<30);
    var PASTE:KeyCode               = 125 | (1<<30);
    var FIND:KeyCode                = 126 | (1<<30);
    var MUTE:KeyCode                = 127 | (1<<30);
    var VOLUMEUP:KeyCode            = 128 | (1<<30);
    var VOLUMEDOWN:KeyCode          = 129 | (1<<30);

    var KP_COMMA:KeyCode            = 133 | (1<<30);
    var KP_EQUALSAS400:KeyCode      = 134 | (1<<30);

    var ALTERASE:KeyCode            = 153 | (1<<30);
    var SYSREQ:KeyCode              = 154 | (1<<30);
    var CANCEL:KeyCode              = 155 | (1<<30);
    var CLEAR:KeyCode               = 156 | (1<<30);
    var PRIOR:KeyCode               = 157 | (1<<30);
    var RETURN2:KeyCode             = 158 | (1<<30);
    var SEPARATOR:KeyCode           = 159 | (1<<30);
    var OUT:KeyCode                 = 160 | (1<<30);
    var OPER:KeyCode                = 161 | (1<<30);
    var CLEARAGAIN:KeyCode          = 162 | (1<<30);
    var CRSEL:KeyCode               = 163 | (1<<30);
    var EXSEL:KeyCode               = 164 | (1<<30);

    var KP_00:KeyCode               = 176 | (1<<30);
    var KP_000:KeyCode              = 177 | (1<<30);
    var THOUSANDSSEPARATOR:Int      = 178 | (1<<30);
    var DECIMALSEPARATOR:Int        = 179 | (1<<30);
    var CURRENCYUNIT:KeyCode        = 180 | (1<<30);
    var CURRENCYSUBUNIT:KeyCode     = 181 | (1<<30);
    var KP_LEFTPAREN:KeyCode        = 182 | (1<<30);
    var KP_RIGHTPAREN:KeyCode       = 183 | (1<<30);
    var KP_LEFTBRACE:KeyCode        = 184 | (1<<30);
    var KP_RIGHTBRACE:KeyCode       = 185 | (1<<30);
    var KP_TAB:KeyCode              = 186 | (1<<30);
    var KP_BACKSPACE:KeyCode        = 187 | (1<<30);
    var KP_A:KeyCode                = 188 | (1<<30);
    var KP_B:KeyCode                = 189 | (1<<30);
    var KP_C:KeyCode                = 190 | (1<<30);
    var KP_D:KeyCode                = 191 | (1<<30);
    var KP_E:KeyCode                = 192 | (1<<30);
    var KP_F:KeyCode                = 193 | (1<<30);
    var KP_XOR:KeyCode              = 194 | (1<<30);
    var KP_POWER:KeyCode            = 195 | (1<<30);
    var KP_PERCENT:KeyCode          = 196 | (1<<30);
    var KP_LESS:KeyCode             = 197 | (1<<30);
    var KP_GREATER:KeyCode          = 198 | (1<<30);
    var KP_AMPERSAND:KeyCode        = 199 | (1<<30);
    var KP_DBLAMPERSAND:KeyCode     = 200 | (1<<30);
    var KP_VERTICALBAR:KeyCode      = 201 | (1<<30);
    var KP_DBLVERTICALBAR:Int       = 202 | (1<<30);
    var KP_COLON:KeyCode            = 203 | (1<<30);
    var KP_HASH:KeyCode             = 204 | (1<<30);
    var KP_SPACE:KeyCode            = 205 | (1<<30);
    var KP_AT:KeyCode               = 206 | (1<<30);
    var KP_EXCLAM:KeyCode           = 207 | (1<<30);
    var KP_MEMSTORE:KeyCode         = 208 | (1<<30);
    var KP_MEMRECALL:KeyCode        = 209 | (1<<30);
    var KP_MEMCLEAR:KeyCode         = 210 | (1<<30);
    var KP_MEMADD:KeyCode           = 211 | (1<<30);
    var KP_MEMSUBTRACT:KeyCode      = 212 | (1<<30);
    var KP_MEMMULTIPLY:KeyCode      = 213 | (1<<30);
    var KP_MEMDIVIDE:KeyCode        = 214 | (1<<30);
    var KP_PLUSMINUS:KeyCode        = 215 | (1<<30);
    var KP_CLEAR:KeyCode            = 216 | (1<<30);
    var KP_CLEARENTRY:KeyCode       = 217 | (1<<30);
    var KP_BINARY:KeyCode           = 218 | (1<<30);
    var KP_OCTAL:KeyCode            = 219 | (1<<30);
    var KP_DECIMAL:KeyCode          = 220 | (1<<30);
    var KP_HEXADECIMAL:KeyCode      = 221 | (1<<30);

    var LCTRL:KeyCode               = 224 | (1<<30);
    var LSHIFT:KeyCode              = 225 | (1<<30);
    var LALT:KeyCode                = 226 | (1<<30);
    var LMETA:KeyCode               = 227 | (1<<30);
    var RCTRL:KeyCode               = 228 | (1<<30);
    var RSHIFT:KeyCode              = 229 | (1<<30);
    var RALT:KeyCode                = 230 | (1<<30);
    var RMETA:KeyCode               = 231 | (1<<30);

    var MODE:KeyCode                = 257 | (1<<30);

    var AUDIONEXT:KeyCode           = 258 | (1<<30);
    var AUDIOPREV:KeyCode           = 259 | (1<<30);
    var AUDIOSTOP:KeyCode           = 260 | (1<<30);
    var AUDIOPLAY:KeyCode           = 261 | (1<<30);
    var AUDIOMUTE:KeyCode           = 262 | (1<<30);
    var MEDIASELECT:KeyCode         = 263 | (1<<30);
    var WWW:KeyCode                 = 264 | (1<<30);
    var MAIL:KeyCode                = 265 | (1<<30);
    var CALCULATOR:KeyCode          = 266 | (1<<30);
    var COMPUTER:KeyCode            = 267 | (1<<30);
    var AC_SEARCH:KeyCode           = 268 | (1<<30);
    var AC_HOME:KeyCode             = 269 | (1<<30);
    var AC_BACK:KeyCode             = 270 | (1<<30);
    var AC_FORWARD:KeyCode          = 271 | (1<<30);
    var AC_STOP:KeyCode             = 272 | (1<<30);
    var AC_REFRESH:KeyCode          = 273 | (1<<30);
    var AC_BOOKMARKS:KeyCode        = 274 | (1<<30);

    var BRIGHTNESSDOWN:KeyCode      = 275 | (1<<30);
    var BRIGHTNESSUP:KeyCode        = 276 | (1<<30);
    var DISPLAYSWITCH:KeyCode       = 277 | (1<<30);
    var KBDILLUMTOGGLE:KeyCode      = 278 | (1<<30);
    var KBDILLUMDOWN:KeyCode        = 279 | (1<<30);
    var KBDILLUMUP:KeyCode          = 280 | (1<<30);
    var EJECT:KeyCode               = 281 | (1<<30);
    var SLEEP:KeyCode               = 282 | (1<<30);

    /** Convert a keyCode to string */
    public static function name(keyCode:KeyCode):String {

        //we don't use toScanCode because it would consume
        //the typeable characters and we want those as unicode etc.

        if ((keyCode & ScanCode.MASK) != 0) {
            return ScanCode.name(keyCode &~ ScanCode.MASK);
        }

        switch (keyCode) {

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

        }

    }

    function toString():String {

        return 'KeyCode(' + this + ' ' + KeyCode.name(this) + ')';

    }

}