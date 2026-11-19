// New code for the Haxe port of gpui-kit (no gpui-kit origin): the transformed and animated fragments of an
// `InlineFlow`, the animation descriptor and the text case transforms of the rich text (G12). The glyph walk
// follows `ShimmerText.paintHighlight`. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.Bounds;
import glaze.GlobalElementId;
import glaze.Hsla;
import glaze.LayoutId;
import glaze.Pixels;
import glaze.Point;
import glaze.ShapedLine;
import glaze.Size;
import glaze.Style;
import glaze.TextRun;
import glaze.Transformation;
import glaze.TransformationMatrix;
import glaze.Window;
import glaze.kit.base.motion.Keyframes;
import glaze.kit.base.motion.MotionTransform;
import glaze.kit.base.motion.Stagger;
import glaze.kit.base.motion.Timing;
import glaze.kit.base.text.InlineFlow.CodeBox;
import glaze.util.Utf8;

/** The case a span of text is shown in. */
enum abstract InlineTextTransform(Int) {

    var None = 0;

    var Uppercase;

    var Lowercase;

    /** The first letter of each word in upper case. */
    var Capitalize;

}

/**
 * The animation of a span of an `InlineFlow`: keyframes of
 * `MotionTransform` (translation, scale, rotation, opacity) played with a
 * `Timing`, sampled each time the span is painted. The layout of the flow
 * never depends on it.
 *
 * By default the span moves in one piece, its box with it (`perRun`); the
 * rotation is then left out (an element cannot be rotated). With
 * `perCharacter`, each character is animated on its own, later by the
 * stagger's delay, rotation included, and the box stays still; the words of
 * such a span are never broken across lines.
 */
class InlineAnimation {

    public final keyframes:Keyframes<MotionTransform>;

    public final timing:Timing;

    var stagger:Null<Stagger> = null;

    var ahead:Bool = false;

    var em:Bool = false;

    public function new(keyframes:Keyframes<MotionTransform>, timing:Timing) {
        this.keyframes = keyframes;
        this.timing = timing;
    }

    /** An animation from keyframes given as a list (offsets from 0 to 1, in order). */
    public static function of(frames:Array<glaze.kit.base.motion.Keyframes.Keyframe<MotionTransform>>, timing:Timing):InlineAnimation {
        return new InlineAnimation(Keyframes.tryNew(frames, glaze.kit.base.motion.Interpolators.MOTION_TRANSFORM), timing);
    }

    /**
     * Animates each character on its own, character `i` starting later by
     * the delay `stagger` gives it. With `ahead`, the delay is taken as an
     * advance instead (a negative delay in CSS): every character is already
     * running on the first frame, out of phase with its neighbours.
     */
    public function perCharacter(stagger:Stagger, ahead:Bool = false):InlineAnimation {
        this.stagger = stagger;
        this.ahead = ahead;
        return this;
    }

    /** Animates the span in one piece, its box with it (the default). */
    public function perRun():InlineAnimation {
        stagger = null;
        ahead = false;
        return this;
    }

    /**
     * Reads the translations of the keyframes in em of the span's font size
     * instead of pixels, so that the animation follows the size of the text.
     */
    public function translationInEm(em:Bool = true):InlineAnimation {
        this.em = em;
        return this;
    }

    public inline function isPerCharacter():Bool {
        return stagger != null;
    }

    /**
     * The transform of character `index` among `count` (or of the whole run,
     * `index` 0 of 1) after `elapsed` seconds, for a font size of `fontSize`.
     */
    public function sample(elapsed:Float, index:Int, count:Int, fontSize:Float):MotionTransform {
        var at = elapsed;
        if (stagger != null) {
            final delay = stagger.delay(index, count);
            at = ahead ? elapsed + delay : elapsed - delay;
        }
        final value = keyframes.sample(timing.sample(at).directedProgress);
        if (!em) {
            return value;
        }
        return new MotionTransform(new Point(value.translation.x * fontSize, value.translation.y * fontSize), value.scale, value.rotationRadians, value.opacity);
    }

    /** Whether the animation still moves after `elapsed` seconds. */
    public function isRunning(elapsed:Float, count:Int):Bool {
        var last = elapsed;
        if (stagger != null && !ahead && count > 0) {
            var longest = 0.;
            for (index in 0...count) {
                final delay = stagger.delay(index, count);
                if (delay > longest) longest = delay;
            }
            last = elapsed - longest;
        }
        return !timing.sample(last).finished;
    }

}

/**
 * The helpers of the rich text additions that are not tied to one flow.
 */
class InlineMotion {

    /**
     * `text` in the case of `transform`. The mapping is the same on every
     * target: ASCII, Latin-1, Latin Extended-A, basic Greek and Cyrillic,
     * with the German sharp s becoming `SS` in upper case (so the length can
     * change); other characters are left as they are.
     */
    public static function transformText(text:String, transform:Null<InlineTextTransform>):String {
        if (transform == null || transform == None) {
            return text;
        }
        final out = new StringBuf();
        var wordStart = true;
        for (c in new haxe.iterators.StringIteratorUnicode(text)) {
            final space = c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code || c == 0xA0;
            final upper = transform == Uppercase || (transform == Capitalize && wordStart);
            if (upper) {
                if (c == 0xDF) {
                    out.add(transform == Capitalize ? 'Ss' : 'SS');
                } else {
                    addCodePoint(out, upperOf(c));
                }
            } else if (transform == Lowercase) {
                addCodePoint(out, lowerOf(c));
            } else {
                addCodePoint(out, c);
            }
            wordStart = space;
        }
        return out.toString();
    }

    static inline function addCodePoint(out:StringBuf, c:Int):Void {
        out.add(unicodeString(c));
    }

    static function unicodeString(c:Int):String {
        #if (js || java)
        if (c >= 0x10000) {
            final v = c - 0x10000;
            return String.fromCharCode(0xD800 + (v >> 10)) + String.fromCharCode(0xDC00 + (v & 0x3FF));
        }
        #end
        return String.fromCharCode(c);
    }

    static function upperOf(c:Int):Int {
        if (c >= 'a'.code && c <= 'z'.code) return c - 32;
        if (c < 0x80) return c;
        if (c >= 0xE0 && c <= 0xFE && c != 0xF7) return c - 32;
        if (c == 0xFF) return 0x178;
        if (c >= 0x100 && c <= 0x17F) {
            if (c == 0x131) return 'I'.code;
            if (c == 0x17F) return 'S'.code;
            if (c == 0x138 || c == 0x149) return c;
            final lowerIsOdd = (c <= 0x137) || (c >= 0x14A && c <= 0x177);
            return (lowerIsOdd ? (c & 1) == 1 : (c & 1) == 0) ? c - 1 : c;
        }
        if (c >= 0x3B1 && c <= 0x3C9) return c == 0x3C2 ? 0x3A3 : c - 32;
        if (c == 0x3AC) return 0x386;
        if (c >= 0x3AD && c <= 0x3AF) return c - 37;
        if (c == 0x3CC) return 0x38C;
        if (c == 0x3CD || c == 0x3CE) return c - 63;
        if (c >= 0x430 && c <= 0x44F) return c - 32;
        if (c >= 0x450 && c <= 0x45F) return c - 80;
        return c;
    }

    static function lowerOf(c:Int):Int {
        if (c >= 'A'.code && c <= 'Z'.code) return c + 32;
        if (c < 0x80) return c;
        if (c >= 0xC0 && c <= 0xDE && c != 0xD7) return c + 32;
        if (c == 0x178) return 0xFF;
        if (c >= 0x100 && c <= 0x17F) {
            if (c == 0x130 || c == 0x138 || c == 0x149 || c == 0x17F) return c;
            final upperIsEven = (c <= 0x137) || (c >= 0x14A && c <= 0x177);
            return (upperIsEven ? (c & 1) == 0 : (c & 1) == 1) ? c + 1 : c;
        }
        if (c >= 0x391 && c <= 0x3A9 && c != 0x3A2) return c + 32;
        if (c == 0x386) return 0x3AC;
        if (c >= 0x388 && c <= 0x38A) return c + 37;
        if (c == 0x38C) return 0x3CC;
        if (c == 0x38E || c == 0x38F) return c + 63;
        if (c >= 0x410 && c <= 0x42F) return c + 32;
        if (c >= 0x400 && c <= 0x40F) return c + 80;
        return c;
    }

}

/** The first time an animated fragment of a flow was painted (kept in the flow's frame state). */
class InlineMotionClock {

    public var startedAt:Null<Float> = null;

    public function new() {}

}

/**
 * Paints one fragment of an `InlineFlow` whose span has a transformation
 * or an animation: the glyphs one by one, each with its matrix, instead of
 * the `Inline` text leaf. Such a fragment takes no part in selection and
 * its links are not clickable.
 *
 * Underlines and strikethroughs follow a run animated in one piece and
 * stay still under characters animated one by one.
 */
@:allow(glaze.kit.base.text)
@:allow(tests)
class InlineMotionFragment extends glaze.Element {

    /** How many glyphs the fragments painted with a matrix other than the unit one (for the tests). */
    static var TRANSFORMED_GLYPHS:Int = 0;

    /** The transforms of the fragment painted last (for the tests): one per character, or one for a run. */
    static var LAST_SAMPLES:Array<MotionTransform> = [];

    final text:String;

    final fontSize:Pixels;

    final runs:Array<TextRun>;

    /** The top left corner of the glyph box, and its size. */
    final origin:Point;

    final size:Size;

    /** The box of the span, in window coordinates. */
    final box:Null<CodeBox>;

    final genericBox:Bool;

    final boxRadius:Float;

    final transformation:Null<Transformation>;

    final animation:Null<InlineAnimation>;

    final clock:InlineMotionClock;

    final opacity:Float;

    function new(text:String, fontSize:Pixels, runs:Array<TextRun>, origin:Point, size:Size, box:Null<CodeBox>, genericBox:Bool, boxRadius:Float,
            transformation:Null<Transformation>, animation:Null<InlineAnimation>, clock:InlineMotionClock, opacity:Float) {
        this.text = text;
        this.fontSize = fontSize;
        this.runs = runs;
        this.origin = origin;
        this.size = size;
        this.box = box;
        this.genericBox = genericBox;
        this.boxRadius = boxRadius;
        this.transformation = transformation;
        this.animation = animation;
        this.clock = clock;
        this.opacity = opacity;
    }

    public function requestLayout(globalId:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return window.requestLayout(@:privateAccess glaze.Style.sharedDefaultStyle(), null, cx);
    }

    public function prepaint(globalId:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {}

    public function paint(globalId:Null<GlobalElementId>, _:Bounds, window:Window, cx:App):Void {
        final bounds = new Bounds(origin, size);
        final area = box != null ? box.bounds.union(bounds) : bounds;
        // Nothing to draw, and no frame to ask for, while the span is out of sight.
        if (!window.contentMask().bounds.intersects(area)) {
            return;
        }

        final line = window.textSystem().shapeLine(text, fontSize, [for (run in runs) run.clone()]);
        final count = characterCount(line);
        var elapsed = 0.;
        final animation = cx.reduceMotion() ? null : this.animation;
        if (animation != null) {
            final now = cx.backgroundExecutor().now();
            if (clock.startedAt == null) clock.startedAt = now;
            elapsed = now - clock.startedAt;
            if (animation.isRunning(elapsed, count)) {
                // Paint only: the frame changes no layout and nothing the
                // ancestors of the view render, so the view renders alone
                window.requestAnimationFrameInPlace();
            }
        }

        final fixed = transformation != null && !transformation.isIdentity() ? transformation : null;
        LAST_SAMPLES = [];
        if (animation != null && animation.isPerCharacter()) {
            // The box and the decorations stay still, each glyph moves.
            final still = fixed != null ? fixed.intoElementMatrix(area) : null;
            window.withElementTransform(still, window -> {
                paintBox(window, cx, 1.);
                paintDecorations(line, bounds, window, 1.);
                paintGlyphs(line, bounds, window, (index, glyphCenter) -> {
                    final sample = animation.sample(elapsed, index, count, fontSize);
                    LAST_SAMPLES.push(sample);
                    return {matrix: glyphMatrix(sample, glyphCenter), opacity: sample.opacity};
                });
                return null;
            });
        } else {
            // One transform for the whole fragment: the fixed one, then the animated one.
            var motion:Null<MotionTransform> = null;
            if (animation != null) {
                motion = animation.sample(elapsed, 0, 1, fontSize);
                LAST_SAMPLES.push(motion);
            }
            var matrix:Null<TransformationMatrix> = fixed != null ? fixed.intoElementMatrix(area) : null;
            if (motion != null) {
                final moved = Transformation.fromMotion(motion).intoElementMatrix(area);
                matrix = matrix != null ? moved.compose(matrix) : moved;
            }
            final alpha = motion != null ? motion.opacity : 1.;
            // A fixed rotation cannot turn an element: it turns each glyph around the center of the span.
            final rotation:Float = fixed != null ? (fixed.rotate : Float) : 0.;
            window.withElementTransform(matrix, window -> {
                paintBox(window, cx, alpha);
                paintDecorations(line, bounds, window, alpha);
                paintGlyphs(line, bounds, window, (_, glyphCenter) -> {
                    if (rotation == 0.) return {matrix: null, opacity: alpha};
                    final center = area.center();
                    // Around the center of the span, in coordinates relative to the glyph origin.
                    final pivot = new Point(center.x - glyphCenter.origin.x, center.y - glyphCenter.origin.y);
                    return {
                        matrix: TransformationMatrix.unit().translate(pivot.x, pivot.y).rotate(rotation).translate(-pivot.x, -pivot.y),
                        opacity: alpha
                    };
                });
                return null;
            });
        }
    }

    /** The characters a per character animation staggers: every glyph of the line. */
    static function characterCount(line:ShapedLine):Int {
        var count = 0;
        for (run in line.runs()) count += run.glyphs.length;
        return count;
    }

    /** The matrix of one glyph, around the glyph origin: `sample` applied around the center of the glyph. */
    static function glyphMatrix(sample:MotionTransform, glyph:GlyphPlace):Null<TransformationMatrix> {
        final identity = sample.translation.x == 0. && sample.translation.y == 0. && sample.scale.x == 1. && sample.scale.y == 1.
            && sample.rotationRadians == 0.;
        if (identity) {
            return null;
        }
        final cx = glyph.center.x - glyph.origin.x;
        final cy = glyph.center.y - glyph.origin.y;
        return TransformationMatrix.unit()
            .translate(cx + sample.translation.x, cy + sample.translation.y)
            .rotate(sample.rotationRadians)
            .scale(sample.scale.x, sample.scale.y)
            .translate(-cx, -cy);
    }

    function paintBox(window:Window, cx:App, alpha:Float):Void {
        final box = this.box;
        if (box == null) {
            return;
        }
        final style = new Style();
        if (!genericBox) {
            final radius = glaze.AbsoluteLength.Pixels(boxRadius);
            style.cornerRadiusTopLeft = radius;
            style.cornerRadiusTopRight = radius;
            style.cornerRadiusBottomLeft = radius;
            style.cornerRadiusBottomRight = radius;
        }
        final refinement = alpha < 1. ? box.style.clone() : box.style;
        if (alpha < 1.) {
            if (refinement.background != null) refinement.background = refinement.background.opacity(alpha);
            if (refinement.borderColor != null) refinement.borderColor = refinement.borderColor.opacity(alpha);
        }
        style.refine(refinement);
        style.paint(box.bounds, window, cx, (_, _) -> {});
    }

    /** The color of the text run holding byte `index`. */
    function runAt(index:Int):TextRun {
        var end = 0;
        for (run in runs) {
            end += run.len;
            if (index < end) return run;
        }
        return runs[runs.length - 1];
    }

    function paintGlyphs(line:ShapedLine, bounds:Bounds, window:Window, place:(Int, GlyphPlace) -> {matrix:Null<TransformationMatrix>, opacity:Float}):Void {
        if (glaze.TextPainter.lineObserver != null) glaze.TextPainter.lineObserver(line.text, bounds.origin, line.layout, bounds.size.height, line.decorationRuns, 0, null);
        final ascent:Float = line.ascent();
        final descent:Float = line.descent();
        // The glyphs are centered in the fragment's box, like a text line in its line height.
        final baselineY = bounds.origin.y + (bounds.size.height - ascent - descent) / 2. + ascent;
        final width:Float = line.width();
        var index = 0;
        final shapedRuns = line.runs();
        for (runIx in 0...shapedRuns.length) {
            final run = shapedRuns[runIx];
            for (glyphIx in 0...run.glyphs.length) {
                final glyph = run.glyphs[glyphIx];
                // The advance: up to the next glyph, or to the end of the line.
                var next:Float = width;
                if (glyphIx + 1 < run.glyphs.length) {
                    next = run.glyphs[glyphIx + 1].position.x;
                } else if (runIx + 1 < shapedRuns.length && shapedRuns[runIx + 1].glyphs.length > 0) {
                    next = shapedRuns[runIx + 1].glyphs[0].position.x;
                }
                final glyphOrigin = new Point(bounds.origin.x + glyph.position.x, baselineY + glyph.position.y);
                final center = new Point(glyphOrigin.x + (next - glyph.position.x) / 2., baselineY - (ascent - descent) / 2.);
                final placed = place(index, new GlyphPlace(glyphOrigin, center));
                index++;
                if (placed.matrix != null) TRANSFORMED_GLYPHS++;
                if (glyph.isEmoji) {
                    window.paintEmoji(glyphOrigin, run.fontId, glyph.id, fontSize, placed.matrix);
                } else {
                    var color:Hsla = runAt(glyph.index).color;
                    final alpha = placed.opacity * opacity;
                    if (alpha < 1.) color = color.opacity(alpha);
                    window.paintGlyph(glyphOrigin, run.fontId, glyph.id, fontSize, color, placed.matrix);
                }
            }
        }
    }

    function paintDecorations(line:ShapedLine, bounds:Bounds, window:Window, alpha:Float):Void {
        final ascent:Float = line.ascent();
        final descent:Float = line.descent();
        final top = bounds.origin.y + (bounds.size.height - ascent - descent) / 2.;
        final baselineY = top + ascent;
        var start = 0;
        for (run in runs) {
            final end = start + run.len;
            if (run.underline != null || run.strikethrough != null || run.backgroundColor != null) {
                final x0:Float = line.xForIndex(start);
                final x1:Float = line.xForIndex(end);
                final x = bounds.origin.x + x0;
                if (run.backgroundColor != null) {
                    window.paintQuad(glaze.Prelude.fill(new Bounds(new Point(x, bounds.origin.y), new Size(x1 - x0, bounds.size.height)),
                        run.backgroundColor.opacity(alpha * opacity)));
                }
                if (run.underline != null) {
                    final underline = run.underline.clone();
                    underline.color = (underline.color != null ? underline.color : run.color).opacity(alpha * opacity);
                    window.paintUnderline(new Point(x, baselineY + descent * 0.618), x1 - x0, underline);
                }
                if (run.strikethrough != null) {
                    final strikethrough = run.strikethrough.clone();
                    strikethrough.color = (strikethrough.color != null ? strikethrough.color : run.color).opacity(alpha * opacity);
                    window.paintStrikethrough(new Point(x, bounds.origin.y + (ascent * 0.5 + (top - bounds.origin.y) + ascent) * 0.5), x1 - x0, strikethrough);
                }
            }
            start = end;
        }
    }

}

/** Where a glyph is painted: its origin on the baseline and the center of its cell. */
private class GlyphPlace {

    public final origin:Point;

    public final center:Point;

    public inline function new(origin:Point, center:Point) {
        this.origin = origin;
        this.center = center;
    }

}
