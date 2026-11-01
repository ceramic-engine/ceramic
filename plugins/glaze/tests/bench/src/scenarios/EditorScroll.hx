package scenarios;

import gpui.Modifiers;
import gpui.Point;
import gpui.ScrollDelta;
import gpui.ScrollEvent;

/**
 * Scrolling the code editor of `EditorBench`: `step` dispatches a scroll
 * wheel event of 3 lines at the editor center (the path of the golden
 * `scroll` steps, `ScrollDelta.Lines`), down the 5000 lines, then back up
 * once the end is near so long runs never stall at the bottom.
 */
class EditorScroll extends EditorBench {

    static inline final LINES_PER_FRAME:Float = 3;

    /** Frames before the direction flips (about 4600 lines at 3 per frame). */
    static inline final FRAMES_PER_DIRECTION = 1500;

    public function new() {
        super('editor-scroll');
    }

    override function step(frame:Int):Void {
        final down = Std.int(frame / FRAMES_PER_DIRECTION) % 2 == 0;
        final delta = new Point(0, down ? -LINES_PER_FRAME : LINES_PER_FRAME);
        KitBench.dispatch(app, window, new ScrollEvent(center, ScrollDelta.Lines(delta), Modifiers.none()));
    }

}
