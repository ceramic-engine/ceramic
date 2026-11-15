import sys.thread.Thread;
import sys.thread.Lock;

/**
 * ceramic.Md5 against haxe.crypto.Md5:
 *
 * 1. the same hashes (strings and bytes: empty, every length around the
 *    64 byte blocks, non ASCII text, several megabytes);
 * 2. on hxcpp, how long a collection asked by the main thread waits while
 *    another thread hashes 4 MB: with haxe.crypto.Md5 the wait lasts until
 *    the hash ends (the loop never reaches a GC safe point), with
 *    ceramic.Md5 it stays short.
 *
 * Exits with status 1 on a failure. `Md5Test hashes` runs only part 1.
 */
class Md5Test {

    static var failures = 0;

    static function check(label:String, a:String, b:String):Void {
        if (a != b) {
            failures++;
            Sys.println('FAIL $label: $a != $b');
        }
    }

    static function sample(length:Int, seed:Int):String {
        final chars = ['a', 'Z', '0', ' ', '\n', 'é', '漢', '😀', '~', ';'];
        final buffer = new StringBuf();
        var state = seed;
        var count = 0;
        while (count < length) {
            state = (state * 1103515245 + 12345) & 0x7fffffff;
            buffer.add(chars[state % chars.length]);
            count++;
        }
        return buffer.toString();
    }

    static function hashes():Void {
        final strings = ['', 'a', 'abc', 'message digest', 'The quick brown fox jumps over the lazy dog'];
        for (length in 0...200) strings.push(sample(length, length));
        for (length in [4095, 4096, 4097, 65535, 65536, 65537, 1000000]) strings.push(sample(length, length));
        final big = new StringBuf();
        for (i in 0...60000) big.add('  barista: Welcome back! <b>The usual</b> for you today? $i\n');
        strings.push(big.toString());
        for (s in strings) {
            check('encode length ${s.length}', ceramic.Md5.encode(s), haxe.crypto.Md5.encode(s));
            final bytes = haxe.io.Bytes.ofString(s);
            check('make length ${bytes.length}', ceramic.Md5.make(bytes).toHex(), haxe.crypto.Md5.make(bytes).toHex());
        }
        check('known abc', ceramic.Md5.encode('abc'), '900150983cd24fb0d6963f7d28e17f72');
        Sys.println('hashes: ${strings.length} strings, ${failures} failures');
    }

    #if cpp
    /** The longest wait of a collection asked while another thread hashes. */
    static function waitWhileHashing(useCeramic:Bool, text:String):Float {
        final done = new Lock();
        var running = true;
        Thread.create(() -> {
            for (i in 0...4) {
                if (useCeramic) ceramic.Md5.encode(text) else haxe.crypto.Md5.encode(text);
            }
            running = false;
            done.release();
        });
        Sys.sleep(0.02);
        var longest = 0.0;
        var count = 0;
        while (running) {
            final t0 = haxe.Timer.stamp();
            cpp.vm.Gc.run(false);
            final spent = haxe.Timer.stamp() - t0;
            if (spent > longest) longest = spent;
            count++;
            Sys.sleep(0.002);
        }
        done.wait();
        return longest * 1000;
    }
    #end

    static function main():Void {
        hashes();
        #if cpp
        if (Sys.args()[0] != 'hashes') {
            final text = sample(4 * 1024 * 1024, 7);
            final std = waitWhileHashing(false, text);
            final ours = waitWhileHashing(true, text);
            Sys.println('longest collection while another thread hashes 4M chars: haxe.crypto.Md5 '
                + Math.round(std * 10) / 10 + ' ms, ceramic.Md5 ' + Math.round(ours * 10) / 10 + ' ms');
            // Relative: on a loaded machine the thread may also be
            // descheduled, and the conversion of the string to UTF-8 bytes
            // (one native call) is not cut
            if (ours * 10 > std) {
                failures++;
                Sys.println('FAIL ceramic.Md5 holds the collector (${ours} ms)');
            }
        }
        #end
        Sys.exit(failures > 0 ? 1 : 0);
    }

}
