/** wg-pause: ceramic.Md5 compiles and agrees with haxe.crypto.Md5 on JS. */
class Md5Js {
    static function main() {
        var failures = 0;
        final samples = ['', 'abc', 'é漢😀 mixed', [for (i in 0...70000) String.fromCharCode(32 + i % 90)].join('')];
        for (s in samples) {
            if (ceramic.Md5.encode(s) != haxe.crypto.Md5.encode(s)) failures++;
            final b = haxe.io.Bytes.ofString(s);
            if (ceramic.Md5.make(b).toHex() != haxe.crypto.Md5.make(b).toHex()) failures++;
        }
        js.Syntax.code('console.log({0})', 'js: ' + samples.length + ' strings, ' + failures + ' failures');
    }
}
