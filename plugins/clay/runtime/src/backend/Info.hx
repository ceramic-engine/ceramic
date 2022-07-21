package backend;

class Info #if !completion implements spec.Info #end {

    public function new() {}

/// System

    inline public function storageDirectory():String {
        #if (cpp && linc_sdl && !macro)
        return clay.Clay.app.io.appPathPrefs();
        #else
        return null;
        #end
    }

/// Assets

    inline public function imageExtensions():Array<String> {
        return ['png', 'jpg', 'jpeg'];
    }

    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt', 'atlas'];
    }

    #if (js && web)
    static var _soundExtensions:Array<String> = null;
    static var RE_OPERA = ~/OPR\/([0-6].)/g;
    static var RE_SAFARI_VERSION = ~/Version\/(.*?) /;
    #end

    inline public function soundExtensions():Array<String> {
        #if (js && web)
        if (_soundExtensions != null)
            return [].concat(_soundExtensions);

        // Snippet ported from howler.js
        // https://github.com/goldfire/howler.js/blob/143ae442386c7b42d91a007d0b1f1695528abe64/src/howler.core.js#L245-L293

        _soundExtensions = [];
        var audioTest = new js.html.Audio();

        var ua = js.Browser.navigator != null ? js.Browser.navigator.userAgent : '';
        var checkOpera = RE_OPERA.match(ua);
        var isOldOpera = (checkOpera && js.Lib.parseInt(RE_OPERA.matched(0).split('/')[1], 10) < 33);
        var checkSafari = ua.indexOf('Safari') != -1 && ua.indexOf('Chrome') == -1;
        var safariVersion = RE_SAFARI_VERSION.match(ua);
        var isOldSafari = (checkSafari && safariVersion && js.Lib.parseInt(RE_SAFARI_VERSION.matched(1), 10) < 15);

        // OGG support
        var oggTest = audioTest.canPlayType('audio/ogg; codecs="vorbis"');
        var canPlayOgg = (oggTest != null && oggTest != 'no' && oggTest != '');
        if (canPlayOgg) {
            _soundExtensions.push('ogg');
        }

        // MP3 support
        var mpegTest = audioTest.canPlayType('audio/mpeg;');
        var mp3Test = audioTest.canPlayType('audio/mp3;');
        var canPlayMp3 = (mpegTest != null && mpegTest != 'no' && mpegTest != '') || (mp3Test != null && mp3Test != 'no' && mp3Test != '');
        if (!isOldOpera && canPlayMp3) {
            _soundExtensions.push('mp3');
        }

        // FLAC support
        var xFlacTest = audioTest.canPlayType('audio/x-flac;');
        var flacTest = audioTest.canPlayType('audio/flac;');
        var canPlayFlac = (xFlacTest != null && xFlacTest != 'no' && xFlacTest != '') || (flacTest != null && flacTest != 'no' && flacTest != '');
        if (canPlayFlac) {
            _soundExtensions.push('flac');
        }

        // WAV support
        var wavCodecTest = audioTest.canPlayType('audio/wav; codecs="1"');
        var wavTest = audioTest.canPlayType('audio/wav;');
        var canPlayWav = (wavCodecTest != null && wavCodecTest != 'no' && wavCodecTest != '') || (wavTest != null && wavTest != 'no' && wavTest != '');
        if (canPlayWav) {
            _soundExtensions.push('wav');
        }

        return [].concat(_soundExtensions);

        #elseif clay_use_openal
        return ['ogg', 'wav'];
        #else
        return ['ogg', 'mp3', 'flac', 'wav'];
        #end
    }

    inline public function shaderExtensions():Array<String> {
        return ['frag', 'vert'];
    }

}
