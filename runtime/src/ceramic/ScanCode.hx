package ceramic;

/** The scanCode class. The values below come directly from SDL header include files,
but they aren't specific to SDL so they are used generically */
class ScanCode {

    /** Convert a scanCode to a readable name */
    public static function name( scanCode:Int ) : String {

        var res = null;

        if (scanCode >= 0 && scanCode < scanCodeNames.length) {
            res = scanCodeNames[scanCode];
        }

        return res != null ? res : "";

    }

    // special value remains caps
    public static inline var MASK:Int                      = (1<<30);

    public static inline var UNKNOWN:Int                 = 0;

    // Usage page 0x07
    // These values are from usage page 0x07 (USB keyboard page).

    public static inline var KEY_A:Int                   = 4;
    public static inline var KEY_B:Int                   = 5;
    public static inline var KEY_C:Int                   = 6;
    public static inline var KEY_D:Int                   = 7;
    public static inline var KEY_E:Int                   = 8;
    public static inline var KEY_F:Int                   = 9;
    public static inline var KEY_G:Int                   = 10;
    public static inline var KEY_H:Int                   = 11;
    public static inline var KEY_I:Int                   = 12;
    public static inline var KEY_J:Int                   = 13;
    public static inline var KEY_K:Int                   = 14;
    public static inline var KEY_L:Int                   = 15;
    public static inline var KEY_M:Int                   = 16;
    public static inline var KEY_N:Int                   = 17;
    public static inline var KEY_O:Int                   = 18;
    public static inline var KEY_P:Int                   = 19;
    public static inline var KEY_Q:Int                   = 20;
    public static inline var KEY_R:Int                   = 21;
    public static inline var KEY_S:Int                   = 22;
    public static inline var KEY_T:Int                   = 23;
    public static inline var KEY_U:Int                   = 24;
    public static inline var KEY_V:Int                   = 25;
    public static inline var KEY_W:Int                   = 26;
    public static inline var KEY_X:Int                   = 27;
    public static inline var KEY_Y:Int                   = 28;
    public static inline var KEY_Z:Int                   = 29;

    public static inline var KEY_1:Int                   = 30;
    public static inline var KEY_2:Int                   = 31;
    public static inline var KEY_3:Int                   = 32;
    public static inline var KEY_4:Int                   = 33;
    public static inline var KEY_5:Int                   = 34;
    public static inline var KEY_6:Int                   = 35;
    public static inline var KEY_7:Int                   = 36;
    public static inline var KEY_8:Int                   = 37;
    public static inline var KEY_9:Int                   = 38;
    public static inline var KEY_0:Int                   = 39;

    public static inline var ENTER:Int                   = 40;
    public static inline var ESCAPE:Int                  = 41;
    public static inline var BACKSPACE:Int               = 42;
    public static inline var TAB:Int                     = 43;
    public static inline var SPACE:Int                   = 44;

    public static inline var MINUS:Int                   = 45;
    public static inline var EQUALS:Int                  = 46;
    public static inline var LEFTBRACKET:Int             = 47;
    public static inline var RIGHTBRACKET:Int            = 48;

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

    public static inline var BACKSLASH:Int               = 49;

    // ISO USB keyboards actually use this code
    // instead of 49 for the same key, but all
    // OSes I've seen treat the two codes
    // identically. So, as an implementor, unless
    // your keyboard generates both of those
    // codes and your OS treats them differently,
    // you should generate public static inline var BACKSLASH
    // instead of this code. As a user, you
    // should not rely on this code because SDL
    // will never generate it with most (all?)
    // keyboards.

    public static inline var NONUSHASH:Int          = 50;
    public static inline var SEMICOLON:Int          = 51;
    public static inline var APOSTROPHE:Int         = 52;

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

    public static inline var GRAVE:Int              = 53;
    public static inline var COMMA:Int              = 54;
    public static inline var PERIOD:Int             = 55;
    public static inline var SLASH:Int              = 56;

    public static inline var CAPSLOCK:Int           = 57;

    public static inline var F1:Int                 = 58;
    public static inline var F2:Int                 = 59;
    public static inline var F3:Int                 = 60;
    public static inline var F4:Int                 = 61;
    public static inline var F5:Int                 = 62;
    public static inline var F6:Int                 = 63;
    public static inline var F7:Int                 = 64;
    public static inline var F8:Int                 = 65;
    public static inline var F9:Int                 = 66;
    public static inline var F10:Int                = 67;
    public static inline var F11:Int                = 68;
    public static inline var F12:Int                = 69;

    public static inline var PRINTSCREEN:Int        = 70;
    public static inline var SCROLLLOCK:Int         = 71;
    public static inline var PAUSE:Int              = 72;

    // insert on PC, help on some Mac keyboards (but does send code 73, not 117)
    public static inline var INSERT:Int             = 73;
    public static inline var HOME:Int               = 74;
    public static inline var PAGEUP:Int             = 75;
    public static inline var DELETE:Int             = 76;
    public static inline var END:Int                = 77;
    public static inline var PAGEDOWN:Int           = 78;
    public static inline var RIGHT:Int              = 79;
    public static inline var LEFT:Int               = 80;
    public static inline var DOWN:Int               = 81;
    public static inline var UP:Int                 = 82;

    // num lock on PC, clear on Mac keyboards
    public static inline var NUMLOCKCLEAR:Int       = 83;
    public static inline var KP_DIVIDE:Int          = 84;
    public static inline var KP_MULTIPLY:Int        = 85;
    public static inline var KP_MINUS:Int           = 86;
    public static inline var KP_PLUS:Int            = 87;
    public static inline var KP_ENTER:Int           = 88;
    public static inline var KP_1:Int               = 89;
    public static inline var KP_2:Int               = 90;
    public static inline var KP_3:Int               = 91;
    public static inline var KP_4:Int               = 92;
    public static inline var KP_5:Int               = 93;
    public static inline var KP_6:Int               = 94;
    public static inline var KP_7:Int               = 95;
    public static inline var KP_8:Int               = 96;
    public static inline var KP_9:Int               = 97;
    public static inline var KP_0:Int               = 98;
    public static inline var KP_PERIOD:Int          = 99;


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
    public static inline var NONUSBACKSLASH:Int     = 100;

    // windows contextual menu, compose
    public static inline var APPLICATION:Int        = 101;

    // The USB document says this is a status flag,
    // not a physical key - but some Mac keyboards
    // do have a power key.
    public static inline var POWER:Int              = 102;
    public static inline var KP_EQUALS:Int          = 103;
    public static inline var F13:Int                = 104;
    public static inline var F14:Int                = 105;
    public static inline var F15:Int                = 106;
    public static inline var F16:Int                = 107;
    public static inline var F17:Int                = 108;
    public static inline var F18:Int                = 109;
    public static inline var F19:Int                = 110;
    public static inline var F20:Int                = 111;
    public static inline var F21:Int                = 112;
    public static inline var F22:Int                = 113;
    public static inline var F23:Int                = 114;
    public static inline var F24:Int                = 115;
    public static inline var EXECUTE:Int            = 116;
    public static inline var HELP:Int               = 117;
    public static inline var MENU:Int               = 118;
    public static inline var SELECT:Int             = 119;
    public static inline var STOP:Int               = 120;

    // redo
    public static inline var AGAIN:Int              = 121;
    public static inline var UNDO:Int               = 122;
    public static inline var CUT:Int                = 123;
    public static inline var COPY:Int               = 124;
    public static inline var PASTE:Int              = 125;
    public static inline var FIND:Int               = 126;
    public static inline var MUTE:Int               = 127;
    public static inline var VOLUMEUP:Int           = 128;
    public static inline var VOLUMEDOWN:Int         = 129;

    // not sure whether there's a reason to enable these
    //  public static inline var lockingcapslock = 130,
    //  public static inline var lockingnumlock = 131,
    //  public static inline var lockingscrolllock = 132,

    public static inline var KP_COMMA:Int           = 133;
    public static inline var KP_EQUALSAS400:Int     = 134;

    // used on Asian keyboards; see footnotes in USB doc
    public static inline var INTERNATIONAL1:Int     = 135;
    public static inline var INTERNATIONAL2:Int     = 136;

    // Yen
    public static inline var INTERNATIONAL3:Int     = 137;
    public static inline var INTERNATIONAL4:Int     = 138;
    public static inline var INTERNATIONAL5:Int     = 139;
    public static inline var INTERNATIONAL6:Int     = 140;
    public static inline var INTERNATIONAL7:Int     = 141;
    public static inline var INTERNATIONAL8:Int     = 142;
    public static inline var INTERNATIONAL9:Int     = 143;
    // Hangul/English toggle
    public static inline var LANG1:Int              = 144;
    // Hanja conversion
    public static inline var LANG2:Int              = 145;
    // Katakana
    public static inline var LANG3:Int              = 146;
    // Hiragana
    public static inline var LANG4:Int              = 147;
    // Zenkaku/Hankaku
    public static inline var LANG5:Int              = 148;
    // reserved
    public static inline var LANG6:Int              = 149;
    // reserved
    public static inline var LANG7:Int              = 150;
    // reserved
    public static inline var LANG8:Int              = 151;
    // reserved
    public static inline var LANG9:Int              = 152;
    // Erase-Eaze
    public static inline var ALTERASE:Int           = 153;
    public static inline var SYSREQ:Int             = 154;
    public static inline var CANCEL:Int             = 155;
    public static inline var CLEAR:Int              = 156;
    public static inline var PRIOR:Int              = 157;
    public static inline var RETURN2:Int            = 158;
    public static inline var SEPARATOR:Int          = 159;
    public static inline var OUT:Int                = 160;
    public static inline var OPER:Int               = 161;
    public static inline var CLEARAGAIN:Int         = 162;
    public static inline var CRSEL:Int              = 163;
    public static inline var EXSEL:Int              = 164;

    public static inline var KP_00:Int              = 176;
    public static inline var KP_000:Int             = 177;
    public static inline var THOUSANDSSEPARATOR:Int = 178;
    public static inline var DECIMALSEPARATOR:Int   = 179;
    public static inline var CURRENCYUNIT:Int       = 180;
    public static inline var CURRENCYSUBUNIT:Int    = 181;
    public static inline var KP_LEFTPAREN:Int       = 182;
    public static inline var KP_RIGHTPAREN:Int      = 183;
    public static inline var KP_LEFTBRACE:Int       = 184;
    public static inline var KP_RIGHTBRACE:Int      = 185;
    public static inline var KP_TAB:Int             = 186;
    public static inline var KP_BACKSPACE:Int       = 187;
    public static inline var KP_A:Int               = 188;
    public static inline var KP_B:Int               = 189;
    public static inline var KP_C:Int               = 190;
    public static inline var KP_D:Int               = 191;
    public static inline var KP_E:Int               = 192;
    public static inline var KP_F:Int               = 193;
    public static inline var KP_XOR:Int             = 194;
    public static inline var KP_POWER:Int           = 195;
    public static inline var KP_PERCENT:Int         = 196;
    public static inline var KP_LESS:Int            = 197;
    public static inline var KP_GREATER:Int         = 198;
    public static inline var KP_AMPERSAND:Int       = 199;
    public static inline var KP_DBLAMPERSAND:Int    = 200;
    public static inline var KP_VERTICALBAR:Int     = 201;
    public static inline var KP_DBLVERTICALBAR:Int  = 202;
    public static inline var KP_COLON:Int           = 203;
    public static inline var KP_HASH:Int            = 204;
    public static inline var KP_SPACE:Int           = 205;
    public static inline var KP_AT:Int              = 206;
    public static inline var KP_EXCLAM:Int          = 207;
    public static inline var KP_MEMSTORE:Int        = 208;
    public static inline var KP_MEMRECALL:Int       = 209;
    public static inline var KP_MEMCLEAR:Int        = 210;
    public static inline var KP_MEMADD:Int          = 211;
    public static inline var KP_MEMSUBTRACT:Int     = 212;
    public static inline var KP_MEMMULTIPLY:Int     = 213;
    public static inline var KP_MEMDIVIDE:Int       = 214;
    public static inline var KP_PLUSMINUS:Int       = 215;
    public static inline var KP_CLEAR:Int           = 216;
    public static inline var KP_CLEARENTRY:Int      = 217;
    public static inline var KP_BINARY:Int          = 218;
    public static inline var KP_OCTAL:Int           = 219;
    public static inline var KP_DECIMAL:Int         = 220;
    public static inline var KP_HEXADECIMAL:Int     = 221;

    public static inline var LCTRL:Int              = 224;
    public static inline var LSHIFT:Int             = 225;
    // alt, option
    public static inline var LALT:Int               = 226;
    // windows, command (apple), meta, super
    public static inline var LMETA:Int              = 227;
    public static inline var RCTRL:Int              = 228;
    public static inline var RSHIFT:Int             = 229;
    // alt gr, option
    public static inline var RALT:Int               = 230;
    // windows, command (apple), meta, super
    public static inline var RMETA:Int              = 231;

    // Not sure if this is really not covered
    // by any of the above, but since there's a
    // special KMOD_MODE for it I'm adding it here
    public static inline var MODE:Int               = 257;

    //
    // Usage page 0x0C
    // These values are mapped from usage page 0x0C (USB consumer page).

    public static inline var AUDIONEXT:Int          = 258;
    public static inline var AUDIOPREV:Int          = 259;
    public static inline var AUDIOSTOP:Int          = 260;
    public static inline var AUDIOPLAY:Int          = 261;
    public static inline var AUDIOMUTE:Int          = 262;
    public static inline var MEDIASELECT:Int        = 263;
    public static inline var WWW:Int                = 264;
    public static inline var MAIL:Int               = 265;
    public static inline var CALCULATOR:Int         = 266;
    public static inline var COMPUTER:Int           = 267;
    public static inline var AC_SEARCH:Int          = 268;
    public static inline var AC_HOME:Int            = 269;
    public static inline var AC_BACK:Int            = 270;
    public static inline var AC_FORWARD:Int         = 271;
    public static inline var AC_STOP:Int            = 272;
    public static inline var AC_REFRESH:Int         = 273;
    public static inline var AC_BOOKMARKS:Int       = 274;

    // Walther keys
    // These are values that Christian Walther added (for mac keyboard?).

    public static inline var BRIGHTNESSDOWN:Int     = 275;
    public static inline var BRIGHTNESSUP:Int       = 276;

    // Display mirroring/dual display switch, video mode switch */
    public static inline var DISPLAYSWITCH:Int      = 277;

    public static inline var KBDILLUMTOGGLE:Int     = 278;
    public static inline var KBDILLUMDOWN:Int       = 279;
    public static inline var KBDILLUMUP:Int         = 280;
    public static inline var EJECT:Int              = 281;
    public static inline var SLEEP:Int              = 282;

    public static inline var APP1:Int               = 283;
    public static inline var APP2:Int               = 284;

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
    ]; //scanCode names

}
