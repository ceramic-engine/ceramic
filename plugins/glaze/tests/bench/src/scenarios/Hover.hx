package scenarios;

import Scenario;
import gpui.App;
import gpui.Context;
import gpui.Modifiers;
import gpui.MouseMoveEvent;
import gpui.Point;
import gpui.Window;
import gpui.component.button.Button;

import gpui.Prelude.*;

/**
 * A column of 200 gpui-kit buttons (the variants have hover styles), no gap
 * so the mouse is always over one, in the standard window, overflow hidden. `step` moves the mouse 6 px down per
 * frame (a mouse move event, the path of the golden `move` steps), wrapping
 * at the bottom of the window, and alternates between the button column
 * and the empty area at its right: a move inside the same button changes
 * nothing (no redraw), so every frame enters or leaves a button instead.
 */
class Hover extends BaseScenario {

    public static inline final BUTTON_COUNT = 200;

    static inline final STEP_Y:Float = 6;

    /** The x of the mouse over the buttons (left aligned, 8 px horizontal padding). */
    static inline final MOUSE_X:Float = 60;

    /** The x of the mouse beside the buttons (the widest label ends well before). */
    static inline final OUTSIDE_X:Float = 600;

    /** Elements created by a full draw (needs `gpui_count_allocations`). */
    public var elementCount:Int = 0;

    var app:App;

    var window:Window;

    public function new() {
        super('hover');
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        KitBench.initKit(app);
        window = KitBench.openWindow(app, caching, (window, cx) -> {
            return cx.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
                div().sizeFull().px(px(8)).flex().flexCol().itemsStart().overflowHidden()
                    .children([for (i in 0...BUTTON_COUNT) button(i)])
            ));
        });
        elementCount = KitBench.countElements(window);
        return window;
    }

    static function button(i:Int):Button {
        final button = new Button('button-$i').label('Button $i').withSize(gpui.component.Size.Small);
        return switch (i % 4) {
            case 0: button.primary();
            case 1: button.outline();
            case 2: button.ghost();
            case _: button;
        }
    }

    override function step(frame:Int):Void {
        final y = (frame * STEP_Y) % KitBench.HEIGHT;
        final x = frame % 2 == 0 ? MOUSE_X : OUTSIDE_X;
        KitBench.dispatch(app, window, new MouseMoveEvent(new Point(x, y), null, Modifiers.none()));
    }

}
