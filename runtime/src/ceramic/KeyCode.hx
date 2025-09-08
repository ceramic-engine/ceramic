package ceramic;

#if (cpp && windows)
@:headerCode('
// Needed otherwise windows build fails :(
// But why?
#undef DELETE
#undef OUT
')
#end
/**
 * Keyboard key codes representing the character/symbol associated with a key.
 * 
 * KeyCode values represent the actual character or symbol that would be generated
 * by pressing a key, taking into account the current keyboard layout and modifiers.
 * This is different from ScanCode which represents the physical key position.
 * 
 * For example, pressing the 'A' key will always generate KeyCode.KEY_A (97),
 * but the physical scan code may vary based on keyboard layout.
 * 
 * Key codes are layout-dependent and represent the "virtual" key value.
 * For physical key positions, use ScanCode instead.
 * 
 * @see ScanCode
 * @see Key
 * @see Input
 */
enum abstract KeyCode(Int) from Int to Int {

    /** Unknown key code */
    var UNKNOWN:KeyCode             = 0;

    /** Enter/Return key */
    var ENTER:KeyCode               = 13;
    /** Escape key */
    var ESCAPE:KeyCode              = 27;
    /** Backspace key */
    var BACKSPACE:KeyCode           = 8;
    /** Tab key */
    var TAB:KeyCode                 = 9;
    /** Space bar */
    var SPACE:KeyCode               = 32;
    /** Exclamation mark (!) */
    var EXCLAIM:KeyCode             = 33;
    /** Double quote (") */
    var QUOTEDBL:KeyCode            = 34;
    /** Hash/Pound sign (#) */
    var HASH:KeyCode                = 35;
    /** Percent sign (%) */
    var PERCENT:KeyCode             = 37;
    /** Dollar sign ($) */
    var DOLLAR:KeyCode              = 36;
    /** Ampersand (&) */
    var AMPERSAND:KeyCode           = 38;
    /** Single quote/Apostrophe (') */
    var QUOTE:KeyCode               = 39;
    /** Left parenthesis (() */
    var LEFTPAREN:KeyCode           = 40;
    /** Right parenthesis ()) */
    var RIGHTPAREN:KeyCode          = 41;
    /** Asterisk (*) */
    var ASTERISK:KeyCode            = 42;
    /** Plus sign (+) */
    var PLUS:KeyCode                = 43;
    /** Comma (,) */
    var COMMA:KeyCode               = 44;
    /** Minus/Hyphen (-) */
    var MINUS:KeyCode               = 45;
    /** Period/Full stop (.) */
    var PERIOD:KeyCode              = 46;
    /** Forward slash (/) */
    var SLASH:KeyCode               = 47;
    /** Number 0 key */
    var KEY_0:KeyCode               = 48;
    /** Number 1 key */
    var KEY_1:KeyCode               = 49;
    /** Number 2 key */
    var KEY_2:KeyCode               = 50;
    /** Number 3 key */
    var KEY_3:KeyCode               = 51;
    /** Number 4 key */
    var KEY_4:KeyCode               = 52;
    /** Number 5 key */
    var KEY_5:KeyCode               = 53;
    /** Number 6 key */
    var KEY_6:KeyCode               = 54;
    /** Number 7 key */
    var KEY_7:KeyCode               = 55;
    /** Number 8 key */
    var KEY_8:KeyCode               = 56;
    /** Number 9 key */
    var KEY_9:KeyCode               = 57;
    /** Colon (:) */
    var COLON:KeyCode               = 58;
    /** Semicolon (;) */
    var SEMICOLON:KeyCode           = 59;
    /** Less than sign (<) */
    var LESS:KeyCode                = 60;
    /** Equals sign (=) */
    var EQUALS:KeyCode              = 61;
    /** Greater than sign (>) */
    var GREATER:KeyCode             = 62;
    /** Question mark (?) */
    var QUESTION:KeyCode            = 63;
    /** At sign (@) */
    var AT:KeyCode                  = 64;

    // Skip uppercase letters

    /** Left square bracket ([) */
    var LEFTBRACKET:KeyCode         = 91;
    /** Backslash (\) */
    var BACKSLASH:KeyCode           = 92;
    /** Right square bracket (]) */
    var RIGHTBRACKET:KeyCode        = 93;
    /** Caret (^) */
    var CARET:KeyCode               = 94;
    /** Underscore (_) */
    var UNDERSCORE:KeyCode          = 95;
    /** Backtick/Grave accent (`) */
    var BACKQUOTE:KeyCode           = 96;
    /** Letter A key (lowercase) */
    var KEY_A:KeyCode               = 97;
    /** Letter B key (lowercase) */
    var KEY_B:KeyCode               = 98;
    /** Letter C key (lowercase) */
    var KEY_C:KeyCode               = 99;
    /** Letter D key (lowercase) */
    var KEY_D:KeyCode               = 100;
    /** Letter E key (lowercase) */
    var KEY_E:KeyCode               = 101;
    /** Letter F key (lowercase) */
    var KEY_F:KeyCode               = 102;
    /** Letter G key (lowercase) */
    var KEY_G:KeyCode               = 103;
    /** Letter H key (lowercase) */
    var KEY_H:KeyCode               = 104;
    /** Letter I key (lowercase) */
    var KEY_I:KeyCode               = 105;
    /** Letter J key (lowercase) */
    var KEY_J:KeyCode               = 106;
    /** Letter K key (lowercase) */
    var KEY_K:KeyCode               = 107;
    /** Letter L key (lowercase) */
    var KEY_L:KeyCode               = 108;
    /** Letter M key (lowercase) */
    var KEY_M:KeyCode               = 109;
    /** Letter N key (lowercase) */
    var KEY_N:KeyCode               = 110;
    /** Letter O key (lowercase) */
    var KEY_O:KeyCode               = 111;
    /** Letter P key (lowercase) */
    var KEY_P:KeyCode               = 112;
    /** Letter Q key (lowercase) */
    var KEY_Q:KeyCode               = 113;
    /** Letter R key (lowercase) */
    var KEY_R:KeyCode               = 114;
    /** Letter S key (lowercase) */
    var KEY_S:KeyCode               = 115;
    /** Letter T key (lowercase) */
    var KEY_T:KeyCode               = 116;
    /** Letter U key (lowercase) */
    var KEY_U:KeyCode               = 117;
    /** Letter V key (lowercase) */
    var KEY_V:KeyCode               = 118;
    /** Letter W key (lowercase) */
    var KEY_W:KeyCode               = 119;
    /** Letter X key (lowercase) */
    var KEY_X:KeyCode               = 120;
    /** Letter Y key (lowercase) */
    var KEY_Y:KeyCode               = 121;
    /** Letter Z key (lowercase) */
    var KEY_Z:KeyCode               = 122;

    /** Caps Lock key */
    var CAPSLOCK:KeyCode            = 57 | (1<<30);

    /** F1 function key */
    var F1:KeyCode                  = 58 | (1<<30);
    /** F2 function key */
    var F2:KeyCode                  = 59 | (1<<30);
    /** F3 function key */
    var F3:KeyCode                  = 60 | (1<<30);
    /** F4 function key */
    var F4:KeyCode                  = 61 | (1<<30);
    /** F5 function key */
    var F5:KeyCode                  = 62 | (1<<30);
    /** F6 function key */
    var F6:KeyCode                  = 63 | (1<<30);
    /** F7 function key */
    var F7:KeyCode                  = 64 | (1<<30);
    /** F8 function key */
    var F8:KeyCode                  = 65 | (1<<30);
    /** F9 function key */
    var F9:KeyCode                  = 66 | (1<<30);
    /** F10 function key */
    var F10:KeyCode                 = 67 | (1<<30);
    /** F11 function key */
    var F11:KeyCode                 = 68 | (1<<30);
    /** F12 function key */
    var F12:KeyCode                 = 69 | (1<<30);

    /** Print Screen key */
    var PRINTSCREEN:KeyCode         = 70 | (1<<30);
    /** Scroll Lock key */
    var SCROLLLOCK:KeyCode          = 71 | (1<<30);
    /** Pause/Break key */
    var PAUSE:KeyCode               = 72 | (1<<30);

    /** Insert key */
    var INSERT:KeyCode              = 73 | (1<<30);
    /** Home key */
    var HOME:KeyCode                = 74 | (1<<30);
    /** Page Up key */
    var PAGEUP:KeyCode              = 75 | (1<<30);
    /** Delete key */
    var DELETE:KeyCode              = 127;
    /** End key */
    var END:KeyCode                 = 77 | (1<<30);
    /** Page Down key */
    var PAGEDOWN:KeyCode            = 78 | (1<<30);
    /** Right arrow key */
    var RIGHT:KeyCode               = 79 | (1<<30);
    /** Left arrow key */
    var LEFT:KeyCode                = 80 | (1<<30);
    /** Down arrow key */
    var DOWN:KeyCode                = 81 | (1<<30);
    /** Up arrow key */
    var UP:KeyCode                  = 82 | (1<<30);

    /** Num Lock key */
    var NUMLOCKCLEAR:KeyCode        = 83 | (1<<30);
    /** Keypad divide (/) */
    var KP_DIVIDE:KeyCode           = 84 | (1<<30);
    /** Keypad multiply (*) */
    var KP_MULTIPLY:KeyCode         = 85 | (1<<30);
    /** Keypad minus (-) */
    var KP_MINUS:KeyCode            = 86 | (1<<30);
    /** Keypad plus (+) */
    var KP_PLUS:KeyCode             = 87 | (1<<30);
    /** Keypad enter */
    var KP_ENTER:KeyCode            = 88 | (1<<30);
    /** Keypad 1 */
    var KP_1:KeyCode                = 89 | (1<<30);
    /** Keypad 2 */
    var KP_2:KeyCode                = 90 | (1<<30);
    /** Keypad 3 */
    var KP_3:KeyCode                = 91 | (1<<30);
    /** Keypad 4 */
    var KP_4:KeyCode                = 92 | (1<<30);
    /** Keypad 5 */
    var KP_5:KeyCode                = 93 | (1<<30);
    /** Keypad 6 */
    var KP_6:KeyCode                = 94 | (1<<30);
    /** Keypad 7 */
    var KP_7:KeyCode                = 95 | (1<<30);
    /** Keypad 8 */
    var KP_8:KeyCode                = 96 | (1<<30);
    /** Keypad 9 */
    var KP_9:KeyCode                = 97 | (1<<30);
    /** Keypad 0 */
    var KP_0:KeyCode                = 98 | (1<<30);
    /** Keypad period (.) */
    var KP_PERIOD:KeyCode           = 99 | (1<<30);

    /** Application/Menu key */
    var APPLICATION:KeyCode         = 101 | (1<<30);

    /** Power key */
    var POWER:KeyCode               = 102 | (1<<30);
    /** Keypad equals (=) */
    var KP_EQUALS:KeyCode           = 103 | (1<<30);
    /** F13 function key */
    var F13:KeyCode                 = 104 | (1<<30);
    /** F14 function key */
    var F14:KeyCode                 = 105 | (1<<30);
    /** F15 function key */
    var F15:KeyCode                 = 106 | (1<<30);
    /** F16 function key */
    var F16:KeyCode                 = 107 | (1<<30);
    /** F17 function key */
    var F17:KeyCode                 = 108 | (1<<30);
    /** F18 function key */
    var F18:KeyCode                 = 109 | (1<<30);
    /** F19 function key */
    var F19:KeyCode                 = 110 | (1<<30);
    /** F20 function key */
    var F20:KeyCode                 = 111 | (1<<30);
    /** F21 function key */
    var F21:KeyCode                 = 112 | (1<<30);
    /** F22 function key */
    var F22:KeyCode                 = 113 | (1<<30);
    /** F23 function key */
    var F23:KeyCode                 = 114 | (1<<30);
    /** F24 function key */
    var F24:KeyCode                 = 115 | (1<<30);
    /** Execute key */
    var EXECUTE:KeyCode             = 116 | (1<<30);
    /** Help key */
    var HELP:KeyCode                = 117 | (1<<30);
    /** Menu key */
    var MENU:KeyCode                = 118 | (1<<30);
    /** Select key */
    var SELECT:KeyCode              = 119 | (1<<30);
    /** Stop key */
    var STOP:KeyCode                = 120 | (1<<30);

    /** Again/Redo key */
    var AGAIN:KeyCode               = 121 | (1<<30);
    /** Undo key */
    var UNDO:KeyCode                = 122 | (1<<30);
    /** Cut key */
    var CUT:KeyCode                 = 123 | (1<<30);
    /** Copy key */
    var COPY:KeyCode                = 124 | (1<<30);
    /** Paste key */
    var PASTE:KeyCode               = 125 | (1<<30);
    /** Find key */
    var FIND:KeyCode                = 126 | (1<<30);
    /** Mute key */
    var MUTE:KeyCode                = 127 | (1<<30);
    /** Volume Up key */
    var VOLUMEUP:KeyCode            = 128 | (1<<30);
    /** Volume Down key */
    var VOLUMEDOWN:KeyCode          = 129 | (1<<30);

    /** Keypad comma (,) */
    var KP_COMMA:KeyCode            = 133 | (1<<30);
    /** Keypad equals on AS/400 keyboards */
    var KP_EQUALSAS400:KeyCode      = 134 | (1<<30);

    /** Alt Erase key */
    var ALTERASE:KeyCode            = 153 | (1<<30);
    /** SysReq/Attention key */
    var SYSREQ:KeyCode              = 154 | (1<<30);
    /** Cancel key */
    var CANCEL:KeyCode              = 155 | (1<<30);
    /** Clear key */
    var CLEAR:KeyCode               = 156 | (1<<30);
    /** Prior key */
    var PRIOR:KeyCode               = 157 | (1<<30);
    /** Secondary Return/Enter key */
    var RETURN2:KeyCode             = 158 | (1<<30);
    /** Separator key */
    var SEPARATOR:KeyCode           = 159 | (1<<30);
    /** Out key */
    var OUT:KeyCode                 = 160 | (1<<30);
    /** Oper key */
    var OPER:KeyCode                = 161 | (1<<30);
    /** Clear/Again key */
    var CLEARAGAIN:KeyCode          = 162 | (1<<30);
    /** CrSel/Props key */
    var CRSEL:KeyCode               = 163 | (1<<30);
    /** ExSel key */
    var EXSEL:KeyCode               = 164 | (1<<30);

    /** Keypad 00 */
    var KP_00:KeyCode               = 176 | (1<<30);
    /** Keypad 000 */
    var KP_000:KeyCode              = 177 | (1<<30);
    /** Thousands separator */
    var THOUSANDSSEPARATOR:Int      = 178 | (1<<30);
    /** Decimal separator */
    var DECIMALSEPARATOR:Int        = 179 | (1<<30);
    /** Currency unit */
    var CURRENCYUNIT:KeyCode        = 180 | (1<<30);
    /** Currency sub-unit */
    var CURRENCYSUBUNIT:KeyCode     = 181 | (1<<30);
    /** Keypad left parenthesis (() */
    var KP_LEFTPAREN:KeyCode        = 182 | (1<<30);
    /** Keypad right parenthesis ()) */
    var KP_RIGHTPAREN:KeyCode       = 183 | (1<<30);
    /** Keypad left brace ({) */
    var KP_LEFTBRACE:KeyCode        = 184 | (1<<30);
    /** Keypad right brace (}) */
    var KP_RIGHTBRACE:KeyCode       = 185 | (1<<30);
    /** Keypad tab */
    var KP_TAB:KeyCode              = 186 | (1<<30);
    /** Keypad backspace */
    var KP_BACKSPACE:KeyCode        = 187 | (1<<30);
    /** Keypad A */
    var KP_A:KeyCode                = 188 | (1<<30);
    /** Keypad B */
    var KP_B:KeyCode                = 189 | (1<<30);
    /** Keypad C */
    var KP_C:KeyCode                = 190 | (1<<30);
    /** Keypad D */
    var KP_D:KeyCode                = 191 | (1<<30);
    /** Keypad E */
    var KP_E:KeyCode                = 192 | (1<<30);
    /** Keypad F */
    var KP_F:KeyCode                = 193 | (1<<30);
    /** Keypad XOR (^) */
    var KP_XOR:KeyCode              = 194 | (1<<30);
    /** Keypad power (^) */
    var KP_POWER:KeyCode            = 195 | (1<<30);
    /** Keypad percent (%) */
    var KP_PERCENT:KeyCode          = 196 | (1<<30);
    /** Keypad less than (<) */
    var KP_LESS:KeyCode             = 197 | (1<<30);
    /** Keypad greater than (>) */
    var KP_GREATER:KeyCode          = 198 | (1<<30);
    /** Keypad ampersand (&) */
    var KP_AMPERSAND:KeyCode        = 199 | (1<<30);
    /** Keypad double ampersand (&&) */
    var KP_DBLAMPERSAND:KeyCode     = 200 | (1<<30);
    /** Keypad vertical bar (|) */
    var KP_VERTICALBAR:KeyCode      = 201 | (1<<30);
    /** Keypad double vertical bar (||) */
    var KP_DBLVERTICALBAR:Int       = 202 | (1<<30);
    /** Keypad colon (:) */
    var KP_COLON:KeyCode            = 203 | (1<<30);
    /** Keypad hash (#) */
    var KP_HASH:KeyCode             = 204 | (1<<30);
    /** Keypad space */
    var KP_SPACE:KeyCode            = 205 | (1<<30);
    /** Keypad at (@) */
    var KP_AT:KeyCode               = 206 | (1<<30);
    /** Keypad exclamation (!) */
    var KP_EXCLAM:KeyCode           = 207 | (1<<30);
    /** Keypad memory store */
    var KP_MEMSTORE:KeyCode         = 208 | (1<<30);
    /** Keypad memory recall */
    var KP_MEMRECALL:KeyCode        = 209 | (1<<30);
    /** Keypad memory clear */
    var KP_MEMCLEAR:KeyCode         = 210 | (1<<30);
    /** Keypad memory add */
    var KP_MEMADD:KeyCode           = 211 | (1<<30);
    /** Keypad memory subtract */
    var KP_MEMSUBTRACT:KeyCode      = 212 | (1<<30);
    /** Keypad memory multiply */
    var KP_MEMMULTIPLY:KeyCode      = 213 | (1<<30);
    /** Keypad memory divide */
    var KP_MEMDIVIDE:KeyCode        = 214 | (1<<30);
    /** Keypad plus/minus (+/-) */
    var KP_PLUSMINUS:KeyCode        = 215 | (1<<30);
    /** Keypad clear */
    var KP_CLEAR:KeyCode            = 216 | (1<<30);
    /** Keypad clear entry */
    var KP_CLEARENTRY:KeyCode       = 217 | (1<<30);
    /** Keypad binary */
    var KP_BINARY:KeyCode           = 218 | (1<<30);
    /** Keypad octal */
    var KP_OCTAL:KeyCode            = 219 | (1<<30);
    /** Keypad decimal */
    var KP_DECIMAL:KeyCode          = 220 | (1<<30);
    /** Keypad hexadecimal */
    var KP_HEXADECIMAL:KeyCode      = 221 | (1<<30);

    /** Left Control key */
    var LCTRL:KeyCode               = 224 | (1<<30);
    /** Left Shift key */
    var LSHIFT:KeyCode              = 225 | (1<<30);
    /** Left Alt key */
    var LALT:KeyCode                = 226 | (1<<30);
    /** Left Meta/Windows/Command key */
    var LMETA:KeyCode               = 227 | (1<<30);
    /** Right Control key */
    var RCTRL:KeyCode               = 228 | (1<<30);
    /** Right Shift key */
    var RSHIFT:KeyCode              = 229 | (1<<30);
    /** Right Alt key */
    var RALT:KeyCode                = 230 | (1<<30);
    /** Right Meta/Windows/Command key */
    var RMETA:KeyCode               = 231 | (1<<30);

    /** Mode key */
    var MODE:KeyCode                = 257 | (1<<30);

    /** Audio Next Track key */
    var AUDIONEXT:KeyCode           = 258 | (1<<30);
    /** Audio Previous Track key */
    var AUDIOPREV:KeyCode           = 259 | (1<<30);
    /** Audio Stop key */
    var AUDIOSTOP:KeyCode           = 260 | (1<<30);
    /** Audio Play key */
    var AUDIOPLAY:KeyCode           = 261 | (1<<30);
    /** Audio Mute key */
    var AUDIOMUTE:KeyCode           = 262 | (1<<30);
    /** Media Select key */
    var MEDIASELECT:KeyCode         = 263 | (1<<30);
    /** WWW/Internet key */
    var WWW:KeyCode                 = 264 | (1<<30);
    /** Mail key */
    var MAIL:KeyCode                = 265 | (1<<30);
    /** Calculator key */
    var CALCULATOR:KeyCode          = 266 | (1<<30);
    /** Computer/My Computer key */
    var COMPUTER:KeyCode            = 267 | (1<<30);
    /** AC Search key */
    var AC_SEARCH:KeyCode           = 268 | (1<<30);
    /** AC Home key */
    var AC_HOME:KeyCode             = 269 | (1<<30);
    /** AC Back key */
    var AC_BACK:KeyCode             = 270 | (1<<30);
    /** AC Forward key */
    var AC_FORWARD:KeyCode          = 271 | (1<<30);
    /** AC Stop key */
    var AC_STOP:KeyCode             = 272 | (1<<30);
    /** AC Refresh key */
    var AC_REFRESH:KeyCode          = 273 | (1<<30);
    /** AC Bookmarks key */
    var AC_BOOKMARKS:KeyCode        = 274 | (1<<30);

    /** Brightness Down key */
    var BRIGHTNESSDOWN:KeyCode      = 275 | (1<<30);
    /** Brightness Up key */
    var BRIGHTNESSUP:KeyCode        = 276 | (1<<30);
    /** Display Switch key */
    var DISPLAYSWITCH:KeyCode       = 277 | (1<<30);
    /** Keyboard Illumination Toggle key */
    var KBDILLUMTOGGLE:KeyCode      = 278 | (1<<30);
    /** Keyboard Illumination Down key */
    var KBDILLUMDOWN:KeyCode        = 279 | (1<<30);
    /** Keyboard Illumination Up key */
    var KBDILLUMUP:KeyCode          = 280 | (1<<30);
    /** Eject key */
    var EJECT:KeyCode               = 281 | (1<<30);
    /** Sleep key */
    var SLEEP:KeyCode               = 282 | (1<<30);

    /**
     * Convert a key code to its string representation.
     * 
     * For printable characters, returns the character itself.
     * For special keys, returns the key name from ScanCode.
     * 
     * @param keyCode The key code to convert
     * @return A string representation of the key
     */
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

    /**
     * Convert this key code to a string representation.
     * @return A string in the format "KeyCode(value name)"
     */
    function toString():String {

        return 'KeyCode(' + this + ' ' + KeyCode.name(this) + ')';

    }

}