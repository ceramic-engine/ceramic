// New code for the Haxe port (no gpui-kit origin): an automated tour of the
// gallery, used to check the story on other backends (Unity in batch mode,
// the web under the Electron runner).
package;

import ceramic.Platform;
import gpui.App;
import gpui.Entity;
import gpui.Modifiers;
import gpui.Point;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.Window;
import gpui.base.IndexPath;
import story.Gallery;

using StringTools;

/**
 * Visits every story page of the gallery, captures each one to a PNG and
 * logs the cost of its frames, then quits. Off unless `GPUI_STORY_TOUR` is
 * set to a folder (absolute path, created if needed).
 *
 * For each page, in the order of the sidebar: the page is selected like a
 * click in the sidebar (`Gallery.selectStoryIndex`), `GPUI_STORY_TOUR_FRAMES`
 * frames run (default 30), the screen is written to
 * `<folder>/<index>-<name>.png`, and a line `story tour: page ...` gives the
 * highest frame cost and the median of the frames after the first one (CPU time from
 * the start of Ceramic's update to the end of its last render of visuals,
 * in ms). With
 * `GPUI_STORY_TOUR_SCROLL_FRAMES` (default 0), the page is then scrolled
 * with the mouse wheel during that many frames (30 pixels per frame at the
 * center of the story area, the direction flips at the ends) and a line
 * `story tour: scroll ...` gives the median, mean, 95th percentile and highest
 * frame cost.
 *
 * `GPUI_STORY_TOUR_ONLY` restricts the tour to a comma separated list of
 * story names. Errors and exceptions are left to the app's log.
 */
class StoryTour {

    static inline final SIDEBAR_WIDTH:Float = 255;

    static inline final SCROLL_STEP:Float = 30;

    final dir:String;

    final waitFrames:Int;

    final scrollFrames:Int;

    final gallery:Entity<Gallery>;

    final window:Window;

    final names:Array<String>;

    final indices:Array<Int>;

    var position:Int = -1;

    var frame:Int = 0;

    var scrolling:Bool = false;

    var scrollDown:Bool = true;

    var scrollInDirection:Int = 0;

    var capturing:Bool = false;

    var frameStart:Float = 0;

    var lastRenderEnd:Float = 0;

    var costs:Array<Float> = [];

    var firstCost:Float = -1;

    public static function startIfRequested(gallery:Entity<Gallery>, window:Window):Void {
        final dir = Platform.getEnv('GPUI_STORY_TOUR');
        if (dir == null || dir == '') return;
        new StoryTour(dir, gallery, window);
    }

    function new(dir:String, gallery:Entity<Gallery>, window:Window) {
        this.dir = dir;
        this.gallery = gallery;
        this.window = window;
        waitFrames = intEnv('GPUI_STORY_TOUR_FRAMES', 30);
        scrollFrames = intEnv('GPUI_STORY_TOUR_SCROLL_FRAMES', 0);

        final cx = App.current;
        final all = @:privateAccess gallery.read(cx).stories;
        names = [for (group in all) for (story in group.stories) story.read(cx).name];
        final only = Platform.getEnv('GPUI_STORY_TOUR_ONLY');
        final wanted = only != null && only != '' ? [for (name in only.split(',')) name.trim().toLowerCase()] : null;
        indices = [for (i in 0...names.length) if (wanted == null || wanted.indexOf(names[i].toLowerCase()) >= 0) i];

        ceramic.Files.createDirectory(dir);
        log.info('story tour: ${indices.length} pages, $waitFrames frames each, $scrollFrames scroll frames, into $dir');

        // A frame costs from the start of Ceramic's update to the end of its
        // last render of visuals, or of its draw where the draw finishes in
        // the same frame (finishDraw is deferred to the next frame on Unity:
        // `ceramic_pending_finish_draw`)
        ceramic.App.app.onEndRenderVisuals(null, () -> lastRenderEnd = now());
        #if !ceramic_pending_finish_draw
        // Backends without a renderer of visuals (headless) only finish their draw
        ceramic.App.app.onFinishDraw(null, () -> lastRenderEnd = now());
        #end
        ceramic.App.app.onPreUpdate(null, _ -> {
            final start = now();
            if (frameStart > 0 && lastRenderEnd > frameStart) {
                onFrameEnd((lastRenderEnd - frameStart) * 1000);
            }
            frameStart = start;
        });
        next();
    }

    function next():Void {
        position++;
        if (position >= indices.length) {
            log.info('story tour: done');
            ceramic.App.app.quit();
            return;
        }
        final index = indices[position];
        App.current.update(cx -> gallery.update(cx, (g, gcx) -> {
            g.selectStoryIndex(new IndexPath(index, 0), window, gcx);
        }));
        frame = 0;
        costs = [];
        firstCost = -1;
        scrolling = false;
    }

    function onFrameEnd(cost:Float):Void {
        if (position >= indices.length || capturing) return;
        frame++;
        if (frame == 1) {
            firstCost = cost;
        }
        else {
            costs.push(cost);
        }

        if (!scrolling && frame >= waitFrames) {
            final index = indices[position];
            final name = names[index];
            log.info('story tour: page $index $name max ${fmt(max(costs, firstCost))} ms, median ${fmt(median(costs))} ms over ${costs.length} frames');
            capturing = true;
            final file = haxe.io.Path.join([dir, '${index < 10 ? '0' : ''}$index-${fileName(name)}.png']);
            screen.toPng(file, () -> {
                capturing = false;
                if (scrollFrames > 0) {
                    scrolling = true;
                    frame = 0;
                    costs = [];
                    scrollDown = true;
                    scrollInDirection = 0;
                    scroll();
                }
                else {
                    next();
                }
            });
            return;
        }

        if (scrolling) {
            if (frame >= scrollFrames) {
                final index = indices[position];
                log.info('story tour: scroll $index ${names[index]} median ${fmt(median(costs))} ms, mean ${fmt(mean(costs))} ms over ${costs.length} frames, p95 ${fmt(percentile(costs, 0.95))} ms, max ${fmt(max(costs, 0))} ms');
                next();
            }
            else {
                scroll();
            }
        }
    }

    /** One wheel step for the next frame; the direction flips when the content stops moving. */
    function scroll():Void {
        final size = window.viewportSize();
        final w:Float = size.width;
        final h:Float = size.height;
        final center = new Point(SIDEBAR_WIDTH + (w - SIDEBAR_WIDTH) / 2, h / 2 + 50);
        if (scrollInDirection >= 40) {
            scrollDown = !scrollDown;
            scrollInDirection = 0;
        }
        if (!dispatchScroll(center) && scrollInDirection > 0) {
            scrollDown = !scrollDown;
            scrollInDirection = 0;
            dispatchScroll(center);
        }
        scrollInDirection++;
    }

    function dispatchScroll(center:Point):Bool {
        final delta = new Point(0, scrollDown ? -SCROLL_STEP : SCROLL_STEP);
        App.current.update(cx -> window.dispatchEvent(new ScrollEvent(center, ScrollDelta.Pixels(delta), Modifiers.none()), cx));
        return window.dirty;
    }

    static function intEnv(name:String, def:Int):Int {
        final value = Platform.getEnv(name);
        final parsed = value != null ? Std.parseInt(value) : null;
        return parsed != null ? parsed : def;
    }

    static function fileName(name:String):String {
        final buf = new StringBuf();
        for (i in 0...name.length) {
            final c = name.charCodeAt(i);
            final ok = (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code);
            buf.add(ok ? String.fromCharCode(c).toLowerCase() : '-');
        }
        return buf.toString();
    }

    static function median(values:Array<Float>):Float {
        if (values.length == 0) return 0;
        final sorted = values.copy();
        sorted.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        return sorted[Std.int(sorted.length / 2)];
    }

    static function percentile(values:Array<Float>, p:Float):Float {
        if (values.length == 0) return 0;
        final sorted = values.copy();
        sorted.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        return sorted[Std.int(Math.min(sorted.length - 1, Math.floor(sorted.length * p)))];
    }

    static function max(values:Array<Float>, first:Float):Float {
        var result = first;
        for (v in values) if (v > result) result = v;
        return result;
    }

    static function mean(values:Array<Float>):Float {
        if (values.length == 0) return 0;
        var sum = 0.0;
        for (v in values) sum += v;
        return sum / values.length;
    }

    static function fmt(ms:Float):String {
        return '${Math.round(ms * 100) / 100}';
    }

    /** Seconds, with a fine resolution on C# (`Sys.time` is coarse there). */
    static inline function now():Float {
        #if cs
        return untyped __cs__('(double)global::System.Diagnostics.Stopwatch.GetTimestamp() / global::System.Diagnostics.Stopwatch.Frequency');
        #else
        return haxe.Timer.stamp();
        #end
    }

}
