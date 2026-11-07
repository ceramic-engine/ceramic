// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.base.motion.Easing;
import gpui.base.motion.MotionTime;

/**
 * Motion policy of a text view. Base plays it; every duration defaults to
 * zero, so an unstyled view adopts new content at once.
 *
 * Durations are in seconds. The builders return a new value.
 */
class TextViewMotion {

    @:allow(gpui.base.text)
    var _streamFade:Float = 0;

    @:allow(gpui.base.text)
    var _streamFadeStagger:Float = 0;

    @:allow(gpui.base.text)
    var _streamFadeEasing:Easing;

    public function new() {
        _streamFadeEasing = Easing.defaultValue();
    }

    function copy():TextViewMotion {
        final motion = new TextViewMotion();
        motion._streamFade = _streamFade;
        motion._streamFadeStagger = _streamFadeStagger;
        motion._streamFadeEasing = _streamFadeEasing;
        return motion;
    }

    /** How long the text an update appends takes to reach full color. */
    public function withStreamFade(duration:Float):TextViewMotion {
        final motion = copy();
        motion._streamFade = duration;
        return motion;
    }

    /**
     * How much later each further word of one update starts fading than the
     * word before it; zero fades the update as one chunk. A long update is
     * compressed so its last word starts within one `streamFade`.
     */
    public function withStreamFadeStagger(stagger:Float):TextViewMotion {
        final motion = copy();
        motion._streamFadeStagger = stagger;
        return motion;
    }

    /** The curve the appended text fades in along. */
    public function withStreamFadeEasing(easing:Easing):TextViewMotion {
        final motion = copy();
        motion._streamFadeEasing = easing;
        return motion;
    }

    public inline function streamFade():Float {
        return _streamFade;
    }

    public inline function streamFadeStagger():Float {
        return _streamFadeStagger;
    }

    public inline function streamFadeEasing():Easing {
        return _streamFadeEasing;
    }

    /**
     * The start offset between consecutive words of an update `words` long:
     * the stagger as asked, or nothing.
     *
     * Staggering only reads as words arriving one after another while the
     * whole update lights up well within one `streamFade`. Once the last word
     * would start later than that, what is left is a sweep drawn across text
     * that appeared at once, so drop it instead and let the update fade as one
     * chunk.
     */
    @:allow(gpui.base.text)
    function staggerStep(words:Int):Float {
        if (words < 2) {
            return 0;
        }
        final span = MotionTime.nanos(_streamFadeStagger) * (words - 1);
        if (span > MotionTime.nanos(_streamFade)) {
            return 0;
        }
        return _streamFadeStagger;
    }

}
