// Ported from vscode src/vs/base/common/charCode.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

// Names from https://blog.codinghorror.com/ascii-pronunciation-rules-for-programmers/

/**
 * Character codes (to be used with `StringTools.fastCodeAt` and
 * `String.charCodeAt`): UTF-16 code units, like JavaScript's `charCodeAt`.
 */
enum abstract CharCode(Int) from Int to Int {
    var Null = 0;
    /**
     * The `\b` character.
     */
    var Backspace = 8;
    /**
     * The `\t` character.
     */
    var Tab = 9;
    /**
     * The `\n` character.
     */
    var LineFeed = 10;
    /**
     * The `\r` character.
     */
    var CarriageReturn = 13;
    var Space = 32;
    /**
     * The `!` character.
     */
    var ExclamationMark = 33;
    /**
     * The `"` character.
     */
    var DoubleQuote = 34;
    /**
     * The `#` character.
     */
    var Hash = 35;
    /**
     * The `$` character.
     */
    var DollarSign = 36;
    /**
     * The `%` character.
     */
    var PercentSign = 37;
    /**
     * The `&` character.
     */
    var Ampersand = 38;
    /**
     * The `'` character.
     */
    var SingleQuote = 39;
    /**
     * The `(` character.
     */
    var OpenParen = 40;
    /**
     * The `)` character.
     */
    var CloseParen = 41;
    /**
     * The `*` character.
     */
    var Asterisk = 42;
    /**
     * The `+` character.
     */
    var Plus = 43;
    /**
     * The `,` character.
     */
    var Comma = 44;
    /**
     * The `-` character.
     */
    var Dash = 45;
    /**
     * The `.` character.
     */
    var Period = 46;
    /**
     * The `/` character.
     */
    var Slash = 47;

    var Digit0 = 48;
    var Digit1 = 49;
    var Digit2 = 50;
    var Digit3 = 51;
    var Digit4 = 52;
    var Digit5 = 53;
    var Digit6 = 54;
    var Digit7 = 55;
    var Digit8 = 56;
    var Digit9 = 57;

    /**
     * The `:` character.
     */
    var Colon = 58;
    /**
     * The `;` character.
     */
    var Semicolon = 59;
    /**
     * The `<` character.
     */
    var LessThan = 60;
    /**
     * The `=` character.
     */
    var Equals = 61;
    /**
     * The `>` character.
     */
    var GreaterThan = 62;
    /**
     * The `?` character.
     */
    var QuestionMark = 63;
    /**
     * The `@` character.
     */
    var AtSign = 64;

    var A = 65;
    var B = 66;
    var C = 67;
    var D = 68;
    var E = 69;
    var F = 70;
    var G = 71;
    var H = 72;
    var I = 73;
    var J = 74;
    var K = 75;
    var L = 76;
    var M = 77;
    var N = 78;
    var O = 79;
    var P = 80;
    var Q = 81;
    var R = 82;
    var S = 83;
    var T = 84;
    var U = 85;
    var V = 86;
    var W = 87;
    var X = 88;
    var Y = 89;
    var Z = 90;

    /**
     * The `[` character.
     */
    var OpenSquareBracket = 91;
    /**
     * The `\` character.
     */
    var Backslash = 92;
    /**
     * The `]` character.
     */
    var CloseSquareBracket = 93;
    /**
     * The `^` character.
     */
    var Caret = 94;
    /**
     * The `_` character.
     */
    var Underline = 95;
    /**
     * The ``(`)`` character.
     */
    var BackTick = 96;

    var a = 97;
    var b = 98;
    var c = 99;
    var d = 100;
    var e = 101;
    var f = 102;
    var g = 103;
    var h = 104;
    var i = 105;
    var j = 106;
    var k = 107;
    var l = 108;
    var m = 109;
    var n = 110;
    var o = 111;
    var p = 112;
    var q = 113;
    var r = 114;
    var s = 115;
    var t = 116;
    var u = 117;
    var v = 118;
    var w = 119;
    var x = 120;
    var y = 121;
    var z = 122;

    /**
     * The `{` character.
     */
    var OpenCurlyBrace = 123;
    /**
     * The `|` character.
     */
    var Pipe = 124;
    /**
     * The `}` character.
     */
    var CloseCurlyBrace = 125;
    /**
     * The `~` character.
     */
    var Tilde = 126;

    /**
     * The &nbsp; (no-break space) character.
     * Unicode Character 'NO-BREAK SPACE' (U+00A0)
     */
    var NoBreakSpace = 160;

    var U_Combining_Grave_Accent = 0x0300;        // U+0300 Combining Grave Accent
    var U_Combining_Acute_Accent = 0x0301;        // U+0301 Combining Acute Accent
    var U_Combining_Circumflex_Accent = 0x0302;       // U+0302 Combining Circumflex Accent
    var U_Combining_Tilde = 0x0303;          // U+0303 Combining Tilde
    var U_Combining_Macron = 0x0304;         // U+0304 Combining Macron
    var U_Combining_Overline = 0x0305;         // U+0305 Combining Overline
    var U_Combining_Breve = 0x0306;          // U+0306 Combining Breve
    var U_Combining_Dot_Above = 0x0307;         // U+0307 Combining Dot Above
    var U_Combining_Diaeresis = 0x0308;         // U+0308 Combining Diaeresis
    var U_Combining_Hook_Above = 0x0309;        // U+0309 Combining Hook Above
    var U_Combining_Ring_Above = 0x030A;        // U+030A Combining Ring Above
    var U_Combining_Double_Acute_Accent = 0x030B;      // U+030B Combining Double Acute Accent
    var U_Combining_Caron = 0x030C;          // U+030C Combining Caron
    var U_Combining_Vertical_Line_Above = 0x030D;      // U+030D Combining Vertical Line Above
    var U_Combining_Double_Vertical_Line_Above = 0x030E;    // U+030E Combining Double Vertical Line Above
    var U_Combining_Double_Grave_Accent = 0x030F;      // U+030F Combining Double Grave Accent
    var U_Combining_Candrabindu = 0x0310;        // U+0310 Combining Candrabindu
    var U_Combining_Inverted_Breve = 0x0311;       // U+0311 Combining Inverted Breve
    var U_Combining_Turned_Comma_Above = 0x0312;      // U+0312 Combining Turned Comma Above
    var U_Combining_Comma_Above = 0x0313;        // U+0313 Combining Comma Above
    var U_Combining_Reversed_Comma_Above = 0x0314;      // U+0314 Combining Reversed Comma Above
    var U_Combining_Comma_Above_Right = 0x0315;       // U+0315 Combining Comma Above Right
    var U_Combining_Grave_Accent_Below = 0x0316;      // U+0316 Combining Grave Accent Below
    var U_Combining_Acute_Accent_Below = 0x0317;      // U+0317 Combining Acute Accent Below
    var U_Combining_Left_Tack_Below = 0x0318;       // U+0318 Combining Left Tack Below
    var U_Combining_Right_Tack_Below = 0x0319;       // U+0319 Combining Right Tack Below
    var U_Combining_Left_Angle_Above = 0x031A;       // U+031A Combining Left Angle Above
    var U_Combining_Horn = 0x031B;          // U+031B Combining Horn
    var U_Combining_Left_Half_Ring_Below = 0x031C;      // U+031C Combining Left Half Ring Below
    var U_Combining_Up_Tack_Below = 0x031D;        // U+031D Combining Up Tack Below
    var U_Combining_Down_Tack_Below = 0x031E;       // U+031E Combining Down Tack Below
    var U_Combining_Plus_Sign_Below = 0x031F;       // U+031F Combining Plus Sign Below
    var U_Combining_Minus_Sign_Below = 0x0320;       // U+0320 Combining Minus Sign Below
    var U_Combining_Palatalized_Hook_Below = 0x0321;     // U+0321 Combining Palatalized Hook Below
    var U_Combining_Retroflex_Hook_Below = 0x0322;      // U+0322 Combining Retroflex Hook Below
    var U_Combining_Dot_Below = 0x0323;         // U+0323 Combining Dot Below
    var U_Combining_Diaeresis_Below = 0x0324;       // U+0324 Combining Diaeresis Below
    var U_Combining_Ring_Below = 0x0325;        // U+0325 Combining Ring Below
    var U_Combining_Comma_Below = 0x0326;        // U+0326 Combining Comma Below
    var U_Combining_Cedilla = 0x0327;         // U+0327 Combining Cedilla
    var U_Combining_Ogonek = 0x0328;         // U+0328 Combining Ogonek
    var U_Combining_Vertical_Line_Below = 0x0329;      // U+0329 Combining Vertical Line Below
    var U_Combining_Bridge_Below = 0x032A;        // U+032A Combining Bridge Below
    var U_Combining_Inverted_Double_Arch_Below = 0x032B;    // U+032B Combining Inverted Double Arch Below
    var U_Combining_Caron_Below = 0x032C;        // U+032C Combining Caron Below
    var U_Combining_Circumflex_Accent_Below = 0x032D;     // U+032D Combining Circumflex Accent Below
    var U_Combining_Breve_Below = 0x032E;        // U+032E Combining Breve Below
    var U_Combining_Inverted_Breve_Below = 0x032F;      // U+032F Combining Inverted Breve Below
    var U_Combining_Tilde_Below = 0x0330;        // U+0330 Combining Tilde Below
    var U_Combining_Macron_Below = 0x0331;        // U+0331 Combining Macron Below
    var U_Combining_Low_Line = 0x0332;         // U+0332 Combining Low Line
    var U_Combining_Double_Low_Line = 0x0333;       // U+0333 Combining Double Low Line
    var U_Combining_Tilde_Overlay = 0x0334;        // U+0334 Combining Tilde Overlay
    var U_Combining_Short_Stroke_Overlay = 0x0335;      // U+0335 Combining Short Stroke Overlay
    var U_Combining_Long_Stroke_Overlay = 0x0336;      // U+0336 Combining Long Stroke Overlay
    var U_Combining_Short_Solidus_Overlay = 0x0337;      // U+0337 Combining Short Solidus Overlay
    var U_Combining_Long_Solidus_Overlay = 0x0338;      // U+0338 Combining Long Solidus Overlay
    var U_Combining_Right_Half_Ring_Below = 0x0339;      // U+0339 Combining Right Half Ring Below
    var U_Combining_Inverted_Bridge_Below = 0x033A;      // U+033A Combining Inverted Bridge Below
    var U_Combining_Square_Below = 0x033B;        // U+033B Combining Square Below
    var U_Combining_Seagull_Below = 0x033C;        // U+033C Combining Seagull Below
    var U_Combining_X_Above = 0x033D;         // U+033D Combining X Above
    var U_Combining_Vertical_Tilde = 0x033E;       // U+033E Combining Vertical Tilde
    var U_Combining_Double_Overline = 0x033F;       // U+033F Combining Double Overline
    var U_Combining_Grave_Tone_Mark = 0x0340;       // U+0340 Combining Grave Tone Mark
    var U_Combining_Acute_Tone_Mark = 0x0341;       // U+0341 Combining Acute Tone Mark
    var U_Combining_Greek_Perispomeni = 0x0342;       // U+0342 Combining Greek Perispomeni
    var U_Combining_Greek_Koronis = 0x0343;        // U+0343 Combining Greek Koronis
    var U_Combining_Greek_Dialytika_Tonos = 0x0344;      // U+0344 Combining Greek Dialytika Tonos
    var U_Combining_Greek_Ypogegrammeni = 0x0345;      // U+0345 Combining Greek Ypogegrammeni
    var U_Combining_Bridge_Above = 0x0346;        // U+0346 Combining Bridge Above
    var U_Combining_Equals_Sign_Below = 0x0347;       // U+0347 Combining Equals Sign Below
    var U_Combining_Double_Vertical_Line_Below = 0x0348;    // U+0348 Combining Double Vertical Line Below
    var U_Combining_Left_Angle_Below = 0x0349;       // U+0349 Combining Left Angle Below
    var U_Combining_Not_Tilde_Above = 0x034A;       // U+034A Combining Not Tilde Above
    var U_Combining_Homothetic_Above = 0x034B;       // U+034B Combining Homothetic Above
    var U_Combining_Almost_Equal_To_Above = 0x034C;      // U+034C Combining Almost Equal To Above
    var U_Combining_Left_Right_Arrow_Below = 0x034D;     // U+034D Combining Left Right Arrow Below
    var U_Combining_Upwards_Arrow_Below = 0x034E;      // U+034E Combining Upwards Arrow Below
    var U_Combining_Grapheme_Joiner = 0x034F;       // U+034F Combining Grapheme Joiner
    var U_Combining_Right_Arrowhead_Above = 0x0350;      // U+0350 Combining Right Arrowhead Above
    var U_Combining_Left_Half_Ring_Above = 0x0351;      // U+0351 Combining Left Half Ring Above
    var U_Combining_Fermata = 0x0352;         // U+0352 Combining Fermata
    var U_Combining_X_Below = 0x0353;         // U+0353 Combining X Below
    var U_Combining_Left_Arrowhead_Below = 0x0354;      // U+0354 Combining Left Arrowhead Below
    var U_Combining_Right_Arrowhead_Below = 0x0355;      // U+0355 Combining Right Arrowhead Below
    var U_Combining_Right_Arrowhead_And_Up_Arrowhead_Below = 0x0356; // U+0356 Combining Right Arrowhead And Up Arrowhead Below
    var U_Combining_Right_Half_Ring_Above = 0x0357;      // U+0357 Combining Right Half Ring Above
    var U_Combining_Dot_Above_Right = 0x0358;       // U+0358 Combining Dot Above Right
    var U_Combining_Asterisk_Below = 0x0359;       // U+0359 Combining Asterisk Below
    var U_Combining_Double_Ring_Below = 0x035A;       // U+035A Combining Double Ring Below
    var U_Combining_Zigzag_Above = 0x035B;        // U+035B Combining Zigzag Above
    var U_Combining_Double_Breve_Below = 0x035C;      // U+035C Combining Double Breve Below
    var U_Combining_Double_Breve = 0x035D;        // U+035D Combining Double Breve
    var U_Combining_Double_Macron = 0x035E;        // U+035E Combining Double Macron
    var U_Combining_Double_Macron_Below = 0x035F;      // U+035F Combining Double Macron Below
    var U_Combining_Double_Tilde = 0x0360;        // U+0360 Combining Double Tilde
    var U_Combining_Double_Inverted_Breve = 0x0361;      // U+0361 Combining Double Inverted Breve
    var U_Combining_Double_Rightwards_Arrow_Below = 0x0362;    // U+0362 Combining Double Rightwards Arrow Below
    var U_Combining_Latin_Small_Letter_A = 0x0363;       // U+0363 Combining Latin Small Letter A
    var U_Combining_Latin_Small_Letter_E = 0x0364;       // U+0364 Combining Latin Small Letter E
    var U_Combining_Latin_Small_Letter_I = 0x0365;       // U+0365 Combining Latin Small Letter I
    var U_Combining_Latin_Small_Letter_O = 0x0366;       // U+0366 Combining Latin Small Letter O
    var U_Combining_Latin_Small_Letter_U = 0x0367;       // U+0367 Combining Latin Small Letter U
    var U_Combining_Latin_Small_Letter_C = 0x0368;       // U+0368 Combining Latin Small Letter C
    var U_Combining_Latin_Small_Letter_D = 0x0369;       // U+0369 Combining Latin Small Letter D
    var U_Combining_Latin_Small_Letter_H = 0x036A;       // U+036A Combining Latin Small Letter H
    var U_Combining_Latin_Small_Letter_M = 0x036B;       // U+036B Combining Latin Small Letter M
    var U_Combining_Latin_Small_Letter_R = 0x036C;       // U+036C Combining Latin Small Letter R
    var U_Combining_Latin_Small_Letter_T = 0x036D;       // U+036D Combining Latin Small Letter T
    var U_Combining_Latin_Small_Letter_V = 0x036E;       // U+036E Combining Latin Small Letter V
    var U_Combining_Latin_Small_Letter_X = 0x036F;       // U+036F Combining Latin Small Letter X

    /**
     * Unicode Character 'LINE SEPARATOR' (U+2028)
     * http://www.fileformat.info/info/unicode/char/2028/index.htm
     */
    var LINE_SEPARATOR = 0x2028;
    /**
     * Unicode Character 'PARAGRAPH SEPARATOR' (U+2029)
     * http://www.fileformat.info/info/unicode/char/2029/index.htm
     */
    var PARAGRAPH_SEPARATOR = 0x2029;
    /**
     * Unicode Character 'NEXT LINE' (U+0085)
     * http://www.fileformat.info/info/unicode/char/0085/index.htm
     */
    var NEXT_LINE = 0x0085;

    // http://www.fileformat.info/info/unicode/category/Sk/list.htm
    var U_CIRCUMFLEX = 0x005E;         // U+005E CIRCUMFLEX
    var U_GRAVE_ACCENT = 0x0060;        // U+0060 GRAVE ACCENT
    var U_DIAERESIS = 0x00A8;         // U+00A8 DIAERESIS
    var U_MACRON = 0x00AF;          // U+00AF MACRON
    var U_ACUTE_ACCENT = 0x00B4;        // U+00B4 ACUTE ACCENT
    var U_CEDILLA = 0x00B8;          // U+00B8 CEDILLA
    var U_MODIFIER_LETTER_LEFT_ARROWHEAD = 0x02C2;    // U+02C2 MODIFIER LETTER LEFT ARROWHEAD
    var U_MODIFIER_LETTER_RIGHT_ARROWHEAD = 0x02C3;    // U+02C3 MODIFIER LETTER RIGHT ARROWHEAD
    var U_MODIFIER_LETTER_UP_ARROWHEAD = 0x02C4;    // U+02C4 MODIFIER LETTER UP ARROWHEAD
    var U_MODIFIER_LETTER_DOWN_ARROWHEAD = 0x02C5;    // U+02C5 MODIFIER LETTER DOWN ARROWHEAD
    var U_MODIFIER_LETTER_CENTRED_RIGHT_HALF_RING = 0x02D2;  // U+02D2 MODIFIER LETTER CENTRED RIGHT HALF RING
    var U_MODIFIER_LETTER_CENTRED_LEFT_HALF_RING = 0x02D3;  // U+02D3 MODIFIER LETTER CENTRED LEFT HALF RING
    var U_MODIFIER_LETTER_UP_TACK = 0x02D4;      // U+02D4 MODIFIER LETTER UP TACK
    var U_MODIFIER_LETTER_DOWN_TACK = 0x02D5;     // U+02D5 MODIFIER LETTER DOWN TACK
    var U_MODIFIER_LETTER_PLUS_SIGN = 0x02D6;     // U+02D6 MODIFIER LETTER PLUS SIGN
    var U_MODIFIER_LETTER_MINUS_SIGN = 0x02D7;     // U+02D7 MODIFIER LETTER MINUS SIGN
    var U_BREVE = 0x02D8;          // U+02D8 BREVE
    var U_DOT_ABOVE = 0x02D9;         // U+02D9 DOT ABOVE
    var U_RING_ABOVE = 0x02DA;         // U+02DA RING ABOVE
    var U_OGONEK = 0x02DB;          // U+02DB OGONEK
    var U_SMALL_TILDE = 0x02DC;         // U+02DC SMALL TILDE
    var U_DOUBLE_ACUTE_ACCENT = 0x02DD;       // U+02DD DOUBLE ACUTE ACCENT
    var U_MODIFIER_LETTER_RHOTIC_HOOK = 0x02DE;     // U+02DE MODIFIER LETTER RHOTIC HOOK
    var U_MODIFIER_LETTER_CROSS_ACCENT = 0x02DF;    // U+02DF MODIFIER LETTER CROSS ACCENT
    var U_MODIFIER_LETTER_EXTRA_HIGH_TONE_BAR = 0x02E5;   // U+02E5 MODIFIER LETTER EXTRA-HIGH TONE BAR
    var U_MODIFIER_LETTER_HIGH_TONE_BAR = 0x02E6;    // U+02E6 MODIFIER LETTER HIGH TONE BAR
    var U_MODIFIER_LETTER_MID_TONE_BAR = 0x02E7;    // U+02E7 MODIFIER LETTER MID TONE BAR
    var U_MODIFIER_LETTER_LOW_TONE_BAR = 0x02E8;    // U+02E8 MODIFIER LETTER LOW TONE BAR
    var U_MODIFIER_LETTER_EXTRA_LOW_TONE_BAR = 0x02E9;   // U+02E9 MODIFIER LETTER EXTRA-LOW TONE BAR
    var U_MODIFIER_LETTER_YIN_DEPARTING_TONE_MARK = 0x02EA;  // U+02EA MODIFIER LETTER YIN DEPARTING TONE MARK
    var U_MODIFIER_LETTER_YANG_DEPARTING_TONE_MARK = 0x02EB; // U+02EB MODIFIER LETTER YANG DEPARTING TONE MARK
    var U_MODIFIER_LETTER_UNASPIRATED = 0x02ED;     // U+02ED MODIFIER LETTER UNASPIRATED
    var U_MODIFIER_LETTER_LOW_DOWN_ARROWHEAD = 0x02EF;   // U+02EF MODIFIER LETTER LOW DOWN ARROWHEAD
    var U_MODIFIER_LETTER_LOW_UP_ARROWHEAD = 0x02F0;   // U+02F0 MODIFIER LETTER LOW UP ARROWHEAD
    var U_MODIFIER_LETTER_LOW_LEFT_ARROWHEAD = 0x02F1;   // U+02F1 MODIFIER LETTER LOW LEFT ARROWHEAD
    var U_MODIFIER_LETTER_LOW_RIGHT_ARROWHEAD = 0x02F2;   // U+02F2 MODIFIER LETTER LOW RIGHT ARROWHEAD
    var U_MODIFIER_LETTER_LOW_RING = 0x02F3;     // U+02F3 MODIFIER LETTER LOW RING
    var U_MODIFIER_LETTER_MIDDLE_GRAVE_ACCENT = 0x02F4;   // U+02F4 MODIFIER LETTER MIDDLE GRAVE ACCENT
    var U_MODIFIER_LETTER_MIDDLE_DOUBLE_GRAVE_ACCENT = 0x02F5; // U+02F5 MODIFIER LETTER MIDDLE DOUBLE GRAVE ACCENT
    var U_MODIFIER_LETTER_MIDDLE_DOUBLE_ACUTE_ACCENT = 0x02F6; // U+02F6 MODIFIER LETTER MIDDLE DOUBLE ACUTE ACCENT
    var U_MODIFIER_LETTER_LOW_TILDE = 0x02F7;     // U+02F7 MODIFIER LETTER LOW TILDE
    var U_MODIFIER_LETTER_RAISED_COLON = 0x02F8;    // U+02F8 MODIFIER LETTER RAISED COLON
    var U_MODIFIER_LETTER_BEGIN_HIGH_TONE = 0x02F9;    // U+02F9 MODIFIER LETTER BEGIN HIGH TONE
    var U_MODIFIER_LETTER_END_HIGH_TONE = 0x02FA;    // U+02FA MODIFIER LETTER END HIGH TONE
    var U_MODIFIER_LETTER_BEGIN_LOW_TONE = 0x02FB;    // U+02FB MODIFIER LETTER BEGIN LOW TONE
    var U_MODIFIER_LETTER_END_LOW_TONE = 0x02FC;    // U+02FC MODIFIER LETTER END LOW TONE
    var U_MODIFIER_LETTER_SHELF = 0x02FD;      // U+02FD MODIFIER LETTER SHELF
    var U_MODIFIER_LETTER_OPEN_SHELF = 0x02FE;     // U+02FE MODIFIER LETTER OPEN SHELF
    var U_MODIFIER_LETTER_LOW_LEFT_ARROW = 0x02FF;    // U+02FF MODIFIER LETTER LOW LEFT ARROW
    var U_GREEK_LOWER_NUMERAL_SIGN = 0x0375;     // U+0375 GREEK LOWER NUMERAL SIGN
    var U_GREEK_TONOS = 0x0384;         // U+0384 GREEK TONOS
    var U_GREEK_DIALYTIKA_TONOS = 0x0385;      // U+0385 GREEK DIALYTIKA TONOS
    var U_GREEK_KORONIS = 0x1FBD;        // U+1FBD GREEK KORONIS
    var U_GREEK_PSILI = 0x1FBF;         // U+1FBF GREEK PSILI
    var U_GREEK_PERISPOMENI = 0x1FC0;       // U+1FC0 GREEK PERISPOMENI
    var U_GREEK_DIALYTIKA_AND_PERISPOMENI = 0x1FC1;    // U+1FC1 GREEK DIALYTIKA AND PERISPOMENI
    var U_GREEK_PSILI_AND_VARIA = 0x1FCD;      // U+1FCD GREEK PSILI AND VARIA
    var U_GREEK_PSILI_AND_OXIA = 0x1FCE;      // U+1FCE GREEK PSILI AND OXIA
    var U_GREEK_PSILI_AND_PERISPOMENI = 0x1FCF;     // U+1FCF GREEK PSILI AND PERISPOMENI
    var U_GREEK_DASIA_AND_VARIA = 0x1FDD;      // U+1FDD GREEK DASIA AND VARIA
    var U_GREEK_DASIA_AND_OXIA = 0x1FDE;      // U+1FDE GREEK DASIA AND OXIA
    var U_GREEK_DASIA_AND_PERISPOMENI = 0x1FDF;     // U+1FDF GREEK DASIA AND PERISPOMENI
    var U_GREEK_DIALYTIKA_AND_VARIA = 0x1FED;     // U+1FED GREEK DIALYTIKA AND VARIA
    var U_GREEK_DIALYTIKA_AND_OXIA = 0x1FEE;     // U+1FEE GREEK DIALYTIKA AND OXIA
    var U_GREEK_VARIA = 0x1FEF;         // U+1FEF GREEK VARIA
    var U_GREEK_OXIA = 0x1FFD;         // U+1FFD GREEK OXIA
    var U_GREEK_DASIA = 0x1FFE;         // U+1FFE GREEK DASIA

    var U_IDEOGRAPHIC_FULL_STOP = 0x3002;      // U+3002 IDEOGRAPHIC FULL STOP
    var U_LEFT_CORNER_BRACKET = 0x300C;       // U+300C LEFT CORNER BRACKET
    var U_RIGHT_CORNER_BRACKET = 0x300D;      // U+300D RIGHT CORNER BRACKET
    var U_LEFT_BLACK_LENTICULAR_BRACKET = 0x3010;    // U+3010 LEFT BLACK LENTICULAR BRACKET
    var U_RIGHT_BLACK_LENTICULAR_BRACKET = 0x3011;    // U+3011 RIGHT BLACK LENTICULAR BRACKET


    var U_OVERLINE = 0x203E; // Unicode Character 'OVERLINE'

    /**
     * UTF-8 BOM
     * Unicode Character 'ZERO WIDTH NO-BREAK SPACE' (U+FEFF)
     * http://www.fileformat.info/info/unicode/char/feff/index.htm
     */
    var UTF8_BOM = 65279;

    var U_FULLWIDTH_SEMICOLON = 0xFF1B;       // U+FF1B FULLWIDTH SEMICOLON
    var U_FULLWIDTH_COMMA = 0xFF0C;        // U+FF0C FULLWIDTH COMMA

}
