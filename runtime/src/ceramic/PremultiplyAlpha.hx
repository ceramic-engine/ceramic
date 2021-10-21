package ceramic;

class PremultiplyAlpha {

    public static function premultiplyAlpha(pixels:UInt8Array) {

        var count = pixels.length;
        var index = 0;

        while (index < count) {

            var r = pixels[index+0];
            var g = pixels[index+1];
            var b = pixels[index+2];
            var a = pixels[index+3] / 255.0;

            pixels[index+0] = Std.int(r*a);
            pixels[index+1] = Std.int(g*a);
            pixels[index+2] = Std.int(b*a);

            index += 4;

        }

    }

    public static function reversePremultiplyAlpha(pixels:UInt8Array) {

        var count = pixels.length;
        var index = 0;

        while (index < count) {

            var r = pixels[index+0];
            var g = pixels[index+1];
            var b = pixels[index+2];
            var a = pixels[index+3] / 255.0;

            if (a > 0) {
                pixels[index+0] = Std.int(r/a);
                pixels[index+1] = Std.int(g/a);
                pixels[index+2] = Std.int(b/a);
            }

            index += 4;

        }

    }

}