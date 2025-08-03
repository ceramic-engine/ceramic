package backend;

/**
 * Clay backend implementation providing platform and asset information.
 * 
 * This class supplies information about:
 * - System capabilities and storage locations
 * - Supported asset file extensions
 * - Platform-specific audio format support
 * 
 * The audio format detection on web platforms dynamically tests browser
 * capabilities to determine which formats can be played, accounting for
 * different browser implementations and versions.
 */
class Info #if !completion implements spec.Info #end {

    public function new() {}

/// System

    /**
     * Gets the platform-specific directory for persistent storage.
     * 
     * On SDL platforms (desktop), returns the user preferences directory
     * where the application can store settings and save data.
     * 
     * @return The storage directory path, or null if not available
     */
    inline public function storageDirectory():String {
        #if (clay_sdl && !macro)
        return clay.Clay.app.io.appPathPrefs();
        #else
        return null;
        #end
    }

/// Assets

    /**
     * Gets the list of supported image file extensions.
     * 
     * @return Array of extensions: ['png', 'jpg', 'jpeg']
     */
    inline public function imageExtensions():Array<String> {
        return ['png', 'jpg', 'jpeg'];
    }

    /**
     * Gets the list of file extensions treated as text assets.
     * 
     * These files are loaded as text rather than binary data.
     * 
     * @return Array of extensions: ['txt', 'json', 'fnt', 'atlas']
     */
    inline public function textExtensions():Array<String> {
        return ['txt', 'json', 'fnt', 'atlas'];
    }

    #if (js && web)
    /** Cached list of supported sound extensions */
    static var _soundExtensions:Array<String> = null;
    /** Regular expression to detect Opera browser version */
    static var RE_OPERA = ~/OPR\/([0-6].)/g;
    /** Regular expression to extract Safari version */
    static var RE_SAFARI_VERSION = ~/Version\/(.*?) /;
    #end

    /**
     * Gets the list of supported audio file extensions.
     * 
     * On web platforms, this dynamically detects browser audio capabilities
     * by testing audio format support. The detection code is ported from
     * howler.js and handles browser-specific quirks:
     * - Old Opera versions that don't support MP3
     * - Safari version compatibility
     * - Format support varies by browser
     * 
     * On native platforms, returns all common formats.
     * 
     * @return Array of supported extensions (e.g., ['ogg', 'mp3', 'wav'])
     */
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

        #else
        return ['ogg', 'mp3', 'flac', 'wav'];
        #end
    }

    /**
     * Gets the list of shader file extensions.
     * 
     * @return Array of extensions: ['frag', 'vert'] for fragment and vertex shaders
     */
    inline public function shaderExtensions():Array<String> {
        return ['frag', 'vert'];
    }

}
