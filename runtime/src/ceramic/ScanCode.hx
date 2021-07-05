package ceramic;

enum abstract ScanCode(Int) from Int to Int {

    /**
     * Convert a scanCode to a readable name
     */
    public static function name(scanCode:ScanCode):String {

        var res = null;

        if ((scanCode:Int) >= 0 && (scanCode:Int) < scanCodeNames.length) {
            res = scanCodeNames[scanCode];
        }

        return res != null ? res : "";

    }

    function toString():String {

        return 'ScanCode(' + this + ' ' + ScanCode.name(this) + ')';

    }

    // special value remains caps
    public static var MASK:Int           = (1<<30);

    var UNKNOWN:ScanCode                 = 0;

    // Usage page 0x07
    // These values are from usage page 0x07 (USB keyboard page).

    var KEY_A:ScanCode                   = 4;
    var KEY_B:ScanCode                   = 5;
    var KEY_C:ScanCode                   = 6;
    var KEY_D:ScanCode                   = 7;
    var KEY_E:ScanCode                   = 8;
    var KEY_F:ScanCode                   = 9;
    var KEY_G:ScanCode                   = 10;
    var KEY_H:ScanCode                   = 11;
    var KEY_I:ScanCode                   = 12;
    var KEY_J:ScanCode                   = 13;
    var KEY_K:ScanCode                   = 14;
    var KEY_L:ScanCode                   = 15;
    var KEY_M:ScanCode                   = 16;
    var KEY_N:ScanCode                   = 17;
    var KEY_O:ScanCode                   = 18;
    var KEY_P:ScanCode                   = 19;
    var KEY_Q:ScanCode                   = 20;
    var KEY_R:ScanCode                   = 21;
    var KEY_S:ScanCode                   = 22;
    var KEY_T:ScanCode                   = 23;
    var KEY_U:ScanCode                   = 24;
    var KEY_V:ScanCode                   = 25;
    var KEY_W:ScanCode                   = 26;
    var KEY_X:ScanCode                   = 27;
    var KEY_Y:ScanCode                   = 28;
    var KEY_Z:ScanCode                   = 29;

    var KEY_1:ScanCode                   = 30;
    var KEY_2:ScanCode                   = 31;
    var KEY_3:ScanCode                   = 32;
    var KEY_4:ScanCode                   = 33;
    var KEY_5:ScanCode                   = 34;
    var KEY_6:ScanCode                   = 35;
    var KEY_7:ScanCode                   = 36;
    var KEY_8:ScanCode                   = 37;
    var KEY_9:ScanCode                   = 38;
    var KEY_0:ScanCode                   = 39;

    var ENTER:ScanCode                   = 40;
    var ESCAPE:ScanCode                  = 41;
    var BACKSPACE:ScanCode               = 42;
    var TAB:ScanCode                     = 43;
    var SPACE:ScanCode                   = 44;

    var MINUS:ScanCode                   = 45;
    var EQUALS:ScanCode                  = 46;
    var LEFTBRACKET:ScanCode             = 47;
    var RIGHTBRACKET:ScanCode            = 48;

    // Located at the lower left of the return
    // key on ISO keyboards and at the right end
    // of the QWERTY row on ANSI keyboards.
    // Produces REVERSE SOLIDUS (backslash) and
    // VERTICAL LINE in a US layout, REVERSE
    // SOLIDUS and VERTICAL LINE in a UK Mac
    // layout, NUMBER SIGN and TILDE in a UK
    // Windows layout, DOLLAR SIGN and POUND SIGN
    // in a Swiss German layout, NUMBER SIGN and
    // APOSTROPHE in a German layout, GRAVE
    // ACCENT and POUND SIGN in a French Mac
    // layout, and ASTERISK and MICRO SIGN in a
    // French Windows layout.

    var BACKSLASH:ScanCode               = 49;

    // ISO USB keyboards actually use this code
    // instead of 49 for the same key, but all
    // OSes I've seen treat the two codes
    // identically. So, as an implementor, unless
    // your keyboard generates both of those
    // codes and your OS treats them differently,
    // you should generate var BACKSLASH
    // instead of this code. As a user, you
    // should not rely on this code because SDL
    // will never generate it with most (all?)
    // keyboards.

    var NONUSHASH:ScanCode          = 50;
    var SEMICOLON:ScanCode          = 51;
    var APOSTROPHE:ScanCode         = 52;

    // Located in the top left corner (on both ANSI
    // and ISO keyboards). Produces GRAVE ACCENT and
    // TILDE in a US Windows layout and in US and UK
    // Mac layouts on ANSI keyboards, GRAVE ACCENT
    // and NOT SIGN in a UK Windows layout, SECTION
    // SIGN and PLUS-MINUS SIGN in US and UK Mac
    // layouts on ISO keyboards, SECTION SIGN and
    // DEGREE SIGN in a Swiss German layout (Mac:
    // only on ISO keyboards); CIRCUMFLEX ACCENT and
    // DEGREE SIGN in a German layout (Mac: only on
    // ISO keyboards), SUPERSCRIPT TWO and TILDE in a
    // French Windows layout, COMMERCIAL AT and
    // NUMBER SIGN in a French Mac layout on ISO
    // keyboards, and LESS-THAN SIGN and GREATER-THAN
    // SIGN in a Swiss German, German, or French Mac
    // layout on ANSI keyboards.

    var GRAVE:ScanCode              = 53;
    var COMMA:ScanCode              = 54;
    var PERIOD:ScanCode             = 55;
    var SLASH:ScanCode              = 56;

    var CAPSLOCK:ScanCode           = 57;

    var F1:ScanCode                 = 58;
    var F2:ScanCode                 = 59;
    var F3:ScanCode                 = 60;
    var F4:ScanCode                 = 61;
    var F5:ScanCode                 = 62;
    var F6:ScanCode                 = 63;
    var F7:ScanCode                 = 64;
    var F8:ScanCode                 = 65;
    var F9:ScanCode                 = 66;
    var F10:ScanCode                = 67;
    var F11:ScanCode                = 68;
    var F12:ScanCode                = 69;

    var PRINTSCREEN:ScanCode        = 70;
    var SCROLLLOCK:ScanCode         = 71;
    var PAUSE:ScanCode              = 72;

    // insert on PC, help on some Mac keyboards (but does send code 73, not 117)
    var INSERT:ScanCode             = 73;
    var HOME:ScanCode               = 74;
    var PAGEUP:ScanCode             = 75;
    var DELETE:ScanCode             = 76;
    var END:ScanCode                = 77;
    var PAGEDOWN:ScanCode           = 78;
    var RIGHT:ScanCode              = 79;
    var LEFT:ScanCode               = 80;
    var DOWN:ScanCode               = 81;
    var UP:ScanCode                 = 82;

    // num lock on PC, clear on Mac keyboards
    var NUMLOCKCLEAR:ScanCode       = 83;
    var KP_DIVIDE:ScanCode          = 84;
    var KP_MULTIPLY:ScanCode        = 85;
    var KP_MINUS:ScanCode           = 86;
    var KP_PLUS:ScanCode            = 87;
    var KP_ENTER:ScanCode           = 88;
    var KP_1:ScanCode               = 89;
    var KP_2:ScanCode               = 90;
    var KP_3:ScanCode               = 91;
    var KP_4:ScanCode               = 92;
    var KP_5:ScanCode               = 93;
    var KP_6:ScanCode               = 94;
    var KP_7:ScanCode               = 95;
    var KP_8:ScanCode               = 96;
    var KP_9:ScanCode               = 97;
    var KP_0:ScanCode               = 98;
    var KP_PERIOD:ScanCode          = 99;


    // This is the additional key that ISO
    // keyboards have over ANSI ones,
    // located between left shift and Y.
    // Produces GRAVE ACCENT and TILDE in a
    // US or UK Mac layout, REVERSE SOLIDUS
    // (backslash) and VERTICAL LINE in a
    // US or UK Windows layout, and
    // LESS-THAN SIGN and GREATER-THAN SIGN
    // in a Swiss German, German, or French
    // layout.
    var NONUSBACKSLASH:ScanCode     = 100;

    // windows contextual menu, compose
    var APPLICATION:ScanCode        = 101;

    // The USB document says this is a status flag,
    // not a physical key - but some Mac keyboards
    // do have a power key.
    var POWER:ScanCode              = 102;
    var KP_EQUALS:ScanCode          = 103;
    var F13:ScanCode                = 104;
    var F14:ScanCode                = 105;
    var F15:ScanCode                = 106;
    var F16:ScanCode                = 107;
    var F17:ScanCode                = 108;
    var F18:ScanCode                = 109;
    var F19:ScanCode                = 110;
    var F20:ScanCode                = 111;
    var F21:ScanCode                = 112;
    var F22:ScanCode                = 113;
    var F23:ScanCode                = 114;
    var F24:ScanCode                = 115;
    var EXECUTE:ScanCode            = 116;
    var HELP:ScanCode               = 117;
    var MENU:ScanCode               = 118;
    var SELECT:ScanCode             = 119;
    var STOP:ScanCode               = 120;

    // redo
    var AGAIN:ScanCode              = 121;
    var UNDO:ScanCode               = 122;
    var CUT:ScanCode                = 123;
    var COPY:ScanCode               = 124;
    var PASTE:ScanCode              = 125;
    var FIND:ScanCode               = 126;
    var MUTE:ScanCode               = 127;
    var VOLUMEUP:ScanCode           = 128;
    var VOLUMEDOWN:ScanCode         = 129;

    // not sure whether there's a reason to enable these
    //  var lockingcapslock = 130,
    //  var lockingnumlock = 131,
    //  var lockingscrolllock = 132,

    var KP_COMMA:ScanCode           = 133;
    var KP_EQUALSAS400:ScanCode     = 134;

    // used on Asian keyboards; see footnotes in USB doc
    var INTERNATIONAL1:ScanCode     = 135;
    var INTERNATIONAL2:ScanCode     = 136;

    // Yen
    var INTERNATIONAL3:ScanCode     = 137;
    var INTERNATIONAL4:ScanCode     = 138;
    var INTERNATIONAL5:ScanCode     = 139;
    var INTERNATIONAL6:ScanCode     = 140;
    var INTERNATIONAL7:ScanCode     = 141;
    var INTERNATIONAL8:ScanCode     = 142;
    var INTERNATIONAL9:ScanCode     = 143;
    // Hangul/English toggle
    var LANG1:ScanCode              = 144;
    // Hanja conversion
    var LANG2:ScanCode              = 145;
    // Katakana
    var LANG3:ScanCode              = 146;
    // Hiragana
    var LANG4:ScanCode              = 147;
    // Zenkaku/Hankaku
    var LANG5:ScanCode              = 148;
    // reserved
    var LANG6:ScanCode              = 149;
    // reserved
    var LANG7:ScanCode              = 150;
    // reserved
    var LANG8:ScanCode              = 151;
    // reserved
    var LANG9:ScanCode              = 152;
    // Erase-Eaze
    var ALTERASE:ScanCode           = 153;
    var SYSREQ:ScanCode             = 154;
    var CANCEL:ScanCode             = 155;
    var CLEAR:ScanCode              = 156;
    var PRIOR:ScanCode              = 157;
    var RETURN2:ScanCode            = 158;
    var SEPARATOR:ScanCode          = 159;
    var OUT:ScanCode                = 160;
    var OPER:ScanCode               = 161;
    var CLEARAGAIN:ScanCode         = 162;
    var CRSEL:ScanCode              = 163;
    var EXSEL:ScanCode              = 164;

    var KP_00:ScanCode              = 176;
    var KP_000:ScanCode             = 177;
    var THOUSANDSSEPARATOR:ScanCode = 178;
    var DECIMALSEPARATOR:ScanCode   = 179;
    var CURRENCYUNIT:ScanCode       = 180;
    var CURRENCYSUBUNIT:ScanCode    = 181;
    var KP_LEFTPAREN:ScanCode       = 182;
    var KP_RIGHTPAREN:ScanCode      = 183;
    var KP_LEFTBRACE:ScanCode       = 184;
    var KP_RIGHTBRACE:ScanCode      = 185;
    var KP_TAB:ScanCode             = 186;
    var KP_BACKSPACE:ScanCode       = 187;
    var KP_A:ScanCode               = 188;
    var KP_B:ScanCode               = 189;
    var KP_C:ScanCode               = 190;
    var KP_D:ScanCode               = 191;
    var KP_E:ScanCode               = 192;
    var KP_F:ScanCode               = 193;
    var KP_XOR:ScanCode             = 194;
    var KP_POWER:ScanCode           = 195;
    var KP_PERCENT:ScanCode         = 196;
    var KP_LESS:ScanCode            = 197;
    var KP_GREATER:ScanCode         = 198;
    var KP_AMPERSAND:ScanCode       = 199;
    var KP_DBLAMPERSAND:ScanCode    = 200;
    var KP_VERTICALBAR:ScanCode     = 201;
    var KP_DBLVERTICALBAR:ScanCode  = 202;
    var KP_COLON:ScanCode           = 203;
    var KP_HASH:ScanCode            = 204;
    var KP_SPACE:ScanCode           = 205;
    var KP_AT:ScanCode              = 206;
    var KP_EXCLAM:ScanCode          = 207;
    var KP_MEMSTORE:ScanCode        = 208;
    var KP_MEMRECALL:ScanCode       = 209;
    var KP_MEMCLEAR:ScanCode        = 210;
    var KP_MEMADD:ScanCode          = 211;
    var KP_MEMSUBTRACT:ScanCode     = 212;
    var KP_MEMMULTIPLY:ScanCode     = 213;
    var KP_MEMDIVIDE:ScanCode       = 214;
    var KP_PLUSMINUS:ScanCode       = 215;
    var KP_CLEAR:ScanCode           = 216;
    var KP_CLEARENTRY:ScanCode      = 217;
    var KP_BINARY:ScanCode          = 218;
    var KP_OCTAL:ScanCode           = 219;
    var KP_DECIMAL:ScanCode         = 220;
    var KP_HEXADECIMAL:ScanCode     = 221;

    var LCTRL:ScanCode              = 224;
    var LSHIFT:ScanCode             = 225;
    // alt, option
    var LALT:ScanCode               = 226;
    // windows, command (apple), meta, super
    var LMETA:ScanCode              = 227;
    var RCTRL:ScanCode              = 228;
    var RSHIFT:ScanCode             = 229;
    // alt gr, option
    var RALT:ScanCode               = 230;
    // windows, command (apple), meta, super
    var RMETA:ScanCode              = 231;

    // Not sure if this is really not covered
    // by any of the above, but since there's a
    // special KMOD_MODE for it I'm adding it here
    var MODE:ScanCode               = 257;

    //
    // Usage page 0x0C
    // These values are mapped from usage page 0x0C (USB consumer page).

    var AUDIONEXT:ScanCode          = 258;
    var AUDIOPREV:ScanCode          = 259;
    var AUDIOSTOP:ScanCode          = 260;
    var AUDIOPLAY:ScanCode          = 261;
    var AUDIOMUTE:ScanCode          = 262;
    var MEDIASELECT:ScanCode        = 263;
    var WWW:ScanCode                = 264;
    var MAIL:ScanCode               = 265;
    var CALCULATOR:ScanCode         = 266;
    var COMPUTER:ScanCode           = 267;
    var AC_SEARCH:ScanCode          = 268;
    var AC_HOME:ScanCode            = 269;
    var AC_BACK:ScanCode            = 270;
    var AC_FORWARD:ScanCode         = 271;
    var AC_STOP:ScanCode            = 272;
    var AC_REFRESH:ScanCode         = 273;
    var AC_BOOKMARKS:ScanCode       = 274;

    // Walther keys
    // These are values that Christian Walther added (for mac keyboard?).

    var BRIGHTNESSDOWN:ScanCode     = 275;
    var BRIGHTNESSUP:ScanCode       = 276;

    // Display mirroring/dual display switch, video mode switch */
    var DISPLAYSWITCH:ScanCode      = 277;

    var KBDILLUMTOGGLE:ScanCode     = 278;
    var KBDILLUMDOWN:ScanCode       = 279;
    var KBDILLUMUP:ScanCode         = 280;
    var EJECT:ScanCode              = 281;
    var SLEEP:ScanCode              = 282;

    var APP1:ScanCode               = 283;
    var APP2:ScanCode               = 284;

    static var scanCodeNames:Array<String> = [
        null, null, null, null,
        "A",
        "B",
        "C",
        "D",
        "E",
        "F",
        "G",
        "H",
        "I",
        "J",
        "K",
        "L",
        "M",
        "N",
        "O",
        "P",
        "Q",
        "R",
        "S",
        "T",
        "U",
        "V",
        "W",
        "X",
        "Y",
        "Z",
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "0",
        "Enter",
        "Escape",
        "Backspace",
        "Tab",
        "Space",
        "-",
        "=",
        "[",
        "]",
        "\\",
        "#",
        ";",
        "'",
        "`",
        ",",
        ".",
        "/",
        "CapsLock",
        "F1",
        "F2",
        "F3",
        "F4",
        "F5",
        "F6",
        "F7",
        "F8",
        "F9",
        "F10",
        "F11",
        "F12",
        "PrintScreen",
        "ScrollLock",
        "Pause",
        "Insert",
        "Home",
        "PageUp",
        "Delete",
        "End",
        "PageDown",
        "Right",
        "Left",
        "Down",
        "Up",
        "Numlock",
        "Keypad /",
        "Keypad *",
        "Keypad -",
        "Keypad +",
        "Keypad Enter",
        "Keypad 1",
        "Keypad 2",
        "Keypad 3",
        "Keypad 4",
        "Keypad 5",
        "Keypad 6",
        "Keypad 7",
        "Keypad 8",
        "Keypad 9",
        "Keypad 0",
        "Keypad .",
        null,
        "Application",
        "Power",
        "Keypad =",
        "F13",
        "F14",
        "F15",
        "F16",
        "F17",
        "F18",
        "F19",
        "F20",
        "F21",
        "F22",
        "F23",
        "F24",
        "Execute",
        "Help",
        "Menu",
        "Select",
        "Stop",
        "Again",
        "Undo",
        "Cut",
        "Copy",
        "Paste",
        "Find",
        "Mute",
        "VolumeUp",
        "VolumeDown",
        null, null, null,
        "Keypad ,",
        "Keypad = (AS400)",
        null, null, null, null, null, null, null, null, null, null, null, null,
        null, null, null, null, null, null,
        "AltErase",
        "SysReq",
        "Cancel",
        "Clear",
        "Prior",
        "Enter",
        "Separator",
        "Out",
        "Oper",
        "Clear / Again",
        "CrSel",
        "ExSel",
        null, null, null, null, null, null, null, null, null, null, null,
        "Keypad 00",
        "Keypad 000",
        "ThousandsSeparator",
        "DecimalSeparator",
        "CurrencyUnit",
        "CurrencySubUnit",
        "Keypad (",
        "Keypad )",
        "Keypad {",
        "Keypad }",
        "Keypad Tab",
        "Keypad Backspace",
        "Keypad A",
        "Keypad B",
        "Keypad C",
        "Keypad D",
        "Keypad E",
        "Keypad F",
        "Keypad XOR",
        "Keypad ^",
        "Keypad %",
        "Keypad <",
        "Keypad >",
        "Keypad &",
        "Keypad &&",
        "Keypad |",
        "Keypad ||",
        "Keypad :",
        "Keypad #",
        "Keypad Space",
        "Keypad @",
        "Keypad !",
        "Keypad MemStore",
        "Keypad MemRecall",
        "Keypad MemClear",
        "Keypad MemAdd",
        "Keypad MemSubtract",
        "Keypad MemMultiply",
        "Keypad MemDivide",
        "Keypad +/-",
        "Keypad Clear",
        "Keypad ClearEntry",
        "Keypad Binary",
        "Keypad Octal",
        "Keypad Decimal",
        "Keypad Hexadecimal",
        null, null,
        "Left Ctrl",
        "Left Shift",
        "Left Alt",
        "Left Meta",
        "Right Ctrl",
        "Right Shift",
        "Right Alt",
        "Right Meta",
        null, null, null, null, null, null, null, null, null, null, null, null,
        null, null, null, null, null, null, null, null, null, null, null, null,
        null,
        "ModeSwitch",
        "AudioNext",
        "AudioPrev",
        "AudioStop",
        "AudioPlay",
        "AudioMute",
        "MediaSelect",
        "WWW",
        "Mail",
        "Calculator",
        "Computer",
        "AC Search",
        "AC Home",
        "AC Back",
        "AC Forward",
        "AC Stop",
        "AC Refresh",
        "AC Bookmarks",
        "BrightnessDown",
        "BrightnessUp",
        "DisplaySwitch",
        "KBDIllumToggle",
        "KBDIllumDown",
        "KBDIllumUp",
        "Eject",
        "Sleep",
    ];

}