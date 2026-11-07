package;

import ceramic.Scene;
import ceramic.ScrollUnit;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollHandle;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Scroll calibration scene (owner only: it needs real devices and a visible
 * window, see docs/UNITY.md, "Scroll calibration"), and on Unity in batch
 * mode the input self test (`CERAMIC_UNITY_INPUT_SELFTEST=1`, no window).
 *
 * One log line per scroll event: on Unity the raw value of the Input System
 * event, then on every backend Ceramic's `mouseScroll` (deltas and unit),
 * GPUI's `ScrollDelta` and the pixels GPUI scrolls (lines times the line
 * height of the window). A summary line follows each gesture (no event for
 * 0.35 s). The list on screen scrolls with these events, like any GPUI list.
 * Key downs and ups (with their time, for the repeat), committed text and
 * IME composition are logged too.
 */
class MainScene extends Scene {

    public var window(default, null):Window;

    public var view(default, null):CalibrationView;

    var gestureEvents:Int = 0;
    var gestureLines:Int = 0;
    var gesturePixels:Int = 0;
    var gestureCeramicX:Float = 0;
    var gestureCeramicY:Float = 0;
    var gesturePxX:Float = 0;
    var gesturePxY:Float = 0;
    var gestureRawX:Float = 0;
    var gestureRawY:Float = 0;
    var lastEventTime:Float = -1;

    override function create() {

        final cx = App.current;
        window = Window.open(cx, {width: width, height: height}, (window, cx) -> {
            return cx.newEntity((viewCx:Context<CalibrationView>) -> {
                view = new CalibrationView();
                return view;
            });
        });
        add(window.renderable);

        #if unity
        final scrollInput = @:privateAccess app.backend.screen.scrollInput;
        scrollInput.onScrollEvent = (rawX, rawY, time, deltaX, deltaY, unit) -> {
            logEvent('unity raw=(${fmt(rawX)}, ${fmt(rawY)}) t=${fmt(time)}', rawX, rawY, deltaX, deltaY, unit);
        };
        #else
        screen.onMouseScroll(this, (deltaX, deltaY, unit) -> {
            logEvent(#if web 'web' #else 'clay' #end, 0, 0, deltaX, deltaY, unit);
        });
        #end

        app.onUpdate(this, _ -> {
            if (gestureEvents > 0 && ceramic.Timer.now - lastEventTime > 0.35) {
                endGesture();
            }
        });

        #if unity
        if (ceramic.Platform.getEnv('CERAMIC_UNITY_INPUT_SELFTEST') == '1') {
            new UnityInputSelfTest(this);
            return;
        }
        #end

        print('Scroll calibration: scroll over the list. One line per event, a summary per gesture.');
        print('Keys and text are logged too (hold a key for the repeat, type an emoji, use an input method).');
        #if unity
        print('key repeat of the system: delay ${backend.KeyRepeatSettings.delay()} s, interval ${backend.KeyRepeatSettings.interval()} s');
        #end

        // Keys, text and composition, to compare clay and Unity (repeat
        // rate, emoji, IME)
        app.input.startTextEditing(10, 10, 200, 20);
        input.onKeyDown(this, key -> print('key down ${key.scanCodeName} t=${fmt(ceramic.Timer.now)}'));
        input.onKeyUp(this, key -> print('key up ${key.scanCodeName} t=${fmt(ceramic.Timer.now)}'));
        input.onTextCommit(this, text -> print('text ${haxe.Json.stringify(text)}'));
        input.onTextComposition(this, (text, start, length) -> print('composition ${haxe.Json.stringify(text)} start=$start length=$length'));

    }

    function logEvent(prefix:String, rawX:Float, rawY:Float, deltaX:Float, deltaY:Float, unit:ScrollUnit):Void {

        final delta = glaze.GlazeInput.scrollDeltaOf(deltaX, deltaY, unit);
        final lineHeight:Float = window != null ? (window.lineHeight() : Float) : 0;
        final pixels = glaze.ScrollDelta.ScrollDeltaTools.pixelDelta(delta, lineHeight);
        final gpuiText = switch delta {
            case Pixels(d): 'Pixels(${fmt(d.x)}, ${fmt(d.y)})';
            case Lines(d): 'Lines(${fmt(d.x)}, ${fmt(d.y)})';
        }
        print('scroll $prefix ceramic=(${fmt(deltaX)}, ${fmt(deltaY)}) ${unit == ScrollUnit.LINES ? 'LINES' : 'PIXELS'} gpui=$gpuiText px=(${fmt(pixels.x)}, ${fmt(pixels.y)}) lineHeight=${fmt(lineHeight)}');

        gestureEvents++;
        if (unit == ScrollUnit.LINES) gestureLines++; else gesturePixels++;
        gestureCeramicX += deltaX;
        gestureCeramicY += deltaY;
        gesturePxX += pixels.x;
        gesturePxY += pixels.y;
        gestureRawX += rawX;
        gestureRawY += rawY;
        lastEventTime = ceramic.Timer.now;

        if (view != null) {
            view.last = 'ceramic (${fmt(deltaX)}, ${fmt(deltaY)}) ${unit == ScrollUnit.LINES ? 'lines' : 'pixels'}, gpui px (${fmt(pixels.x)}, ${fmt(pixels.y)})';
        }

    }

    function endGesture():Void {

        final offset = view != null ? view.list.offset() : null;
        print('gesture events=$gestureEvents lines=$gestureLines pixels=$gesturePixels'
            #if unity + ' raw sum=(${fmt(gestureRawX)}, ${fmt(gestureRawY)})' #end
            + ' ceramic sum=(${fmt(gestureCeramicX)}, ${fmt(gestureCeramicY)}) gpui px sum=(${fmt(gesturePxX)}, ${fmt(gesturePxY)})'
            + (offset != null ? ' list offset=(${fmt(offset.x)}, ${fmt(offset.y)})' : ''));
        if (view != null) {
            view.gesture = '$gestureEvents events, gpui px (${fmt(gesturePxX)}, ${fmt(gesturePxY)})';
        }
        gestureEvents = 0;
        gestureLines = 0;
        gesturePixels = 0;
        gestureCeramicX = 0;
        gestureCeramicY = 0;
        gesturePxX = 0;
        gesturePxY = 0;
        gestureRawX = 0;
        gestureRawY = 0;

    }

    public static function fmt(value:Float):String {

        final rounded = Math.round(value * 1000) / 1000;
        return '' + rounded;

    }

    public static function print(line:String):Void {

        #if unity
        untyped __cs__('UnityEngine.Debug.Log({0})', line);
        #else
        Sys.println(line);
        #end

    }

    override function resize(width:Float, height:Float) {

        if (window != null) {
            window.resize(width, height);
        }

    }

    override function destroy() {

        if (window != null) {
            window.destroy();
            window = null;
        }

        super.destroy();

    }

}

/**
 * A header with the last event and gesture, and a long list scrolled by the
 * events.
 */
class CalibrationView extends Model implements Render {

    public final list:ScrollHandle = new ScrollHandle();

    @observe public var last:String = 'no scroll event yet';

    @observe public var gesture:String = '';

    public static inline final ROWS = 400;

    public static inline final ROW_HEIGHT = 24;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {

        final offset = list.offset();
        return div()
            .id('root')
            .fontFamily('Inter')
            // The default text size: the list scrolls by window.lineHeight()
            // per line (the line height of the text style where it paints)
            .textColor(hsla(0, 0, 0.92, 1))
            .bg(hsla(0.61, 0.2, 0.13, 1))
            .flex()
            .flexCol()
            .sizeFull()
            .child(
                div().flexNone().p2().flex().flexCol().gap1()
                    .child(div().child('Last event: $last'))
                    .child(div().child('Last gesture: $gesture'))
                    .child(div().child('List offset: (${MainScene.fmt(offset.x)}, ${MainScene.fmt(offset.y)}), line height ${MainScene.fmt((window.lineHeight() : Float))}'))
            )
            .child(
                div().id('list').flex1().overflowYScroll().trackScroll(list).flex().flexCol()
                    .children([for (i in 0...ROWS) {
                        div().flexNone().h(px(ROW_HEIGHT)).px2()
                            .bg(i % 2 == 0 ? hsla(0.61, 0.2, 0.18, 1) : hsla(0.61, 0.2, 0.22, 1))
                            .child('Row $i');
                    }])
            );

    }

}
