// Ported from chrono 0.4.45: src/format/strftime.rs, src/format/formatting.rs, src/format/parse.rs
// (the specifiers gpui-kit 0.8.1 and its tests use, plus the common date and time ones)
// Original code Copyright (c) 2014--2026, Kang Seonghoon and contributors, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.chrono;

/**
 * chrono's strftime-like formatting and parsing, for the specifiers the
 * port needs:
 *
 * - dates: `%Y %C %y %m %b %h %B %d %e %a %A %w %u %j %F %D`;
 * - times: `%H %k %I %l %M %S %p %P %T %R`;
 * - `%%`, `%n`, `%t`, and the padding modifiers `%-x` (none), `%_x`
 *   (spaces), `%0x` (zeros).
 *
 * Other specifiers are written as is. Parsing knows `%Y %m %d %H %M %S` and
 * literal characters.
 */
class ChronoFormat {

    static final MONTH_SHORT:Array<String> = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    static final MONTH_LONG:Array<String> = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    /**
     * Formats `date` and `time` (either may be null when the format does not
     * use it) with `format`.
     */
    public static function format(format:String, date:Null<NaiveDate>, time:Null<NaiveTime>):String {
        final out = new StringBuf();
        final n = format.length;
        var i = 0;
        while (i < n) {
            final c = format.charCodeAt(i);
            if (c != '%'.code || i + 1 >= n) {
                out.addChar(c);
                i++;
                continue;
            }
            i++;
            var pad:Null<Int> = null; // null: the specifier's default
            var spec = format.charCodeAt(i);
            if (spec == '-'.code || spec == '_'.code || spec == '0'.code) {
                pad = spec == '-'.code ? -1 : (spec == '_'.code ? ' '.code : '0'.code);
                i++;
                if (i >= n) break;
                spec = format.charCodeAt(i);
            }
            i++;
            write(out, spec, pad, date, time);
        }
        return out.toString();
    }

    static function num(out:StringBuf, value:Int, width:Int, defaultPad:Int, pad:Null<Int>):Void {
        final p = pad != null ? pad : defaultPad;
        final negative = value < 0;
        var digits = Std.string(negative ? -value : value);
        if (p != -1) {
            var w = width - (negative ? 1 : 0);
            while (digits.length < w) {
                digits = String.fromCharCode(p) + digits;
            }
        }
        if (negative) out.add('-');
        out.add(digits);
    }

    static function write(out:StringBuf, spec:Int, pad:Null<Int>, date:Null<NaiveDate>, time:Null<NaiveTime>):Void {
        switch spec {
            case 'Y'.code:
                final y = date.year();
                if (y >= 0 && y <= 9999) {
                    num(out, y, 4, '0'.code, pad);
                } else {
                    // chrono writes years outside 0..=9999 with an explicit sign
                    if (y > 0) out.add('+');
                    num(out, y, 4, '0'.code, pad);
                }
            case 'C'.code:
                num(out, Math.floor(date.year() / 100), 2, '0'.code, pad);
            case 'y'.code:
                final y = date.year();
                num(out, y - Math.floor(y / 100) * 100, 2, '0'.code, pad);
            case 'm'.code:
                num(out, date.month(), 2, '0'.code, pad);
            case 'b'.code | 'h'.code:
                out.add(MONTH_SHORT[date.month() - 1]);
            case 'B'.code:
                out.add(MONTH_LONG[date.month() - 1]);
            case 'd'.code:
                num(out, date.day(), 2, '0'.code, pad);
            case 'e'.code:
                num(out, date.day(), 2, ' '.code, pad);
            case 'a'.code:
                out.add(Weekday.SHORT_NAMES[date.weekday().numDaysFromMonday()]);
            case 'A'.code:
                out.add(Weekday.LONG_NAMES[date.weekday().numDaysFromMonday()]);
            case 'w'.code:
                num(out, date.weekday().numDaysFromSunday(), 1, '0'.code, pad);
            case 'u'.code:
                num(out, date.weekday().numberFromMonday(), 1, '0'.code, pad);
            case 'j'.code:
                num(out, date.ordinal(), 3, '0'.code, pad);
            case 'F'.code:
                write(out, 'Y'.code, pad, date, time);
                out.add('-');
                write(out, 'm'.code, null, date, time);
                out.add('-');
                write(out, 'd'.code, null, date, time);
            case 'D'.code:
                write(out, 'm'.code, null, date, time);
                out.add('/');
                write(out, 'd'.code, null, date, time);
                out.add('/');
                write(out, 'y'.code, null, date, time);
            case 'H'.code:
                num(out, time.hour(), 2, '0'.code, pad);
            case 'k'.code:
                num(out, time.hour(), 2, ' '.code, pad);
            case 'I'.code:
                num(out, hour12(time), 2, '0'.code, pad);
            case 'l'.code:
                num(out, hour12(time), 2, ' '.code, pad);
            case 'M'.code:
                num(out, time.minute(), 2, '0'.code, pad);
            case 'S'.code:
                num(out, time.second(), 2, '0'.code, pad);
            case 'p'.code:
                out.add(time.hour() < 12 ? 'AM' : 'PM');
            case 'P'.code:
                out.add(time.hour() < 12 ? 'am' : 'pm');
            case 'T'.code:
                write(out, 'H'.code, null, date, time);
                out.add(':');
                write(out, 'M'.code, null, date, time);
                out.add(':');
                write(out, 'S'.code, null, date, time);
            case 'R'.code:
                write(out, 'H'.code, null, date, time);
                out.add(':');
                write(out, 'M'.code, null, date, time);
            case '%'.code:
                out.add('%');
            case 'n'.code:
                out.add('\n');
            case 't'.code:
                out.add('\t');
            case _:
                out.add('%');
                out.addChar(spec);
        }
    }

    static function hour12(time:NaiveTime):Int {
        final h = time.hour() % 12;
        return h == 0 ? 12 : h;
    }

    /**
     * Parses `value` against `format` (`%Y %m %d %H %M %S`, literals), or
     * returns null. Fields absent from the format are 0 (date fields 1).
     */
    public static function parse(value:String, format:String):Null<{year:Int, month:Int, day:Int, hour:Int, minute:Int, second:Int}> {
        final result = {year: 0, month: 1, day: 1, hour: 0, minute: 0, second: 0};
        var vi = 0;
        var fi = 0;
        final vn = value.length;
        final fn = format.length;

        function digits(min:Int, max:Int, signed:Bool):Null<Int> {
            var negative = false;
            if (signed && vi < vn && (value.charCodeAt(vi) == '-'.code || value.charCodeAt(vi) == '+'.code)) {
                negative = value.charCodeAt(vi) == '-'.code;
                vi++;
            }
            var count = 0;
            var n = 0;
            while (vi < vn && count < max) {
                final c = value.charCodeAt(vi);
                if (c < '0'.code || c > '9'.code) break;
                n = n * 10 + (c - '0'.code);
                vi++;
                count++;
            }
            if (count < min) return null;
            return negative ? -n : n;
        }

        while (fi < fn) {
            final c = format.charCodeAt(fi);
            if (c == '%'.code && fi + 1 < fn) {
                final spec = format.charCodeAt(fi + 1);
                fi += 2;
                final v:Null<Int> = switch spec {
                    case 'Y'.code: digits(1, 9, true);
                    case 'm'.code | 'd'.code | 'H'.code | 'M'.code | 'S'.code: digits(1, 2, false);
                    case '%'.code:
                        if (vi < vn && value.charCodeAt(vi) == '%'.code) {
                            vi++;
                            0;
                        } else null;
                    case _: null;
                }
                if (v == null) return null;
                switch spec {
                    case 'Y'.code: result.year = v;
                    case 'm'.code: result.month = v;
                    case 'd'.code: result.day = v;
                    case 'H'.code: result.hour = v;
                    case 'M'.code: result.minute = v;
                    case 'S'.code: result.second = v;
                    case _:
                }
            } else {
                if (vi >= vn || value.charCodeAt(vi) != c) return null;
                vi++;
                fi++;
            }
        }
        if (vi != vn) return null;
        return result;
    }

}
