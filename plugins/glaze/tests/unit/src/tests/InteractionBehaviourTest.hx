package tests;

import glaze.Action;
import glaze.App;
import glaze.Context;
import glaze.Div;
import glaze.DragMoveEvent;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.KeyBinding;
import glaze.MouseButton;
import glaze.Point;
import glaze.ScrollDelta;
import glaze.ScrollHandle;
import glaze.TestDispatcher;
import glaze.Window;
import testing.GlazeTruth;
import testing.InteractionScript;
import testing.TestCase;

import glaze.Prelude.*;
import testing.InteractionScript.*;

@:action(namespace = reference) class ActionA implements Action {}
@:action(namespace = reference) class ActionB implements Action {}
@:action(namespace = reference) class Multi implements Action {}
@:action(namespace = reference) class Escape implements Action {}

class DragValue {
    public final value:Int;
    public function new(value:Int) {
        this.value = value;
    }
}

/**
 * Replays the interaction behaviours of the reference harness
 * (`reference/src/interaction.rs`) on the port and checks that the logs are
 * exactly those produced by the original GPUI (`test/golden/gpui/<id>.json`):
 * capture / bubble order, hover, clicks, drag and drop, scrolling, focus and
 * tab order, key bindings, actions, pending keystrokes and tooltips.
 */
class InteractionBehaviourTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var script:Null<InteractionScript> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = InteractionScript.testApp(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (script != null) {
            script.destroy();
            script = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function compare(id:String, expectedJson:String, actual:Array<String>):Void {
        final expected:Array<String> = haxe.Json.parse(expectedJson).log;
        var firstDifference = -1;
        for (i in 0...Std.int(Math.max(expected.length, actual.length))) {
            if (expected[i] != actual[i]) {
                firstDifference = i;
                break;
            }
        }
        if (firstDifference != -1) {
            final from = Std.int(Math.max(0, firstDifference - 3));
            final context = [for (i in from...firstDifference + 4) '$i: gpui=${expected[i]} | port=${actual[i]}'].join('\n');
            fail('$id: logs differ at line $firstDifference\n$context');
        }
        assertEquals(expected.length, actual.length, '$id log length');
    }

    static inline function bg():Hsla {
        return hsla(0.61, 0.20, 0.13, 1.0);
    }

    static inline function c(h:Float, s:Float, l:Float):Hsla {
        return hsla(h, s, l, 1.0);
    }

    static function boxed(id:String, x:Float, y:Float, w:Float, h:Float, color:Hsla):Div {
        return div().id(id).absolute().left(px(x)).top(px(y)).w(px(w)).h(px(h)).bg(color);
    }

    static function actionLogger<A>(log:Array<String>, line:String):(A, Window, App) -> Void {
        return (_, _, _) -> log.push(line);
    }

/// 1. mouse-dispatch

    function testMouseDispatchMatchesGpui() {
        final log:Array<String> = [];
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx) -> new ScriptView((window, cx) -> {
            div().id('root').sizeFull().relative().bg(bg())
                .captureAnyMouseDown(downLogger(log, 'root capture_any_mouse_down'))
                .onMouseDown(Left, downLogger(log, 'root mouse_down'))
                .captureAnyMouseUp(upLogger(log, 'root capture_any_mouse_up'))
                .onMouseUp(Left, upLogger(log, 'root mouse_up'))
                .child(
                    boxed('outer', 50, 50, 200, 200, c(0.58, 0.4, 0.35))
                        .captureAnyMouseDown(downLogger(log, 'outer capture_any_mouse_down'))
                        .onMouseDown(Left, downLogger(log, 'outer mouse_down'))
                        .onMouseMove(moveLogger(log, 'outer mouse_move'))
                        .onHover(hoverLogger(log, 'outer'))
                        .onClick(clickLogger(log, 'outer'))
                        .child(
                            boxed('inner', 50, 50, 100, 100, c(0.1, 0.6, 0.5))
                                .onMouseDown(Left, downLogger(log, 'inner mouse_down'))
                                .onMouseUp(Left, upLogger(log, 'inner mouse_up'))
                                .onHover(hoverLogger(log, 'inner'))
                                .onClick(clickLogger(log, 'inner'))
                                .onMouseDownOut(downLogger(log, 'inner mouse_down_out'))
                        )
                )
                .child(
                    boxed('stopper', 300, 50, 100, 100, c(0.0, 0.6, 0.5)).onMouseDown(Left, (e, _, cx) -> {
                        log.push('stopper mouse_down ${button(e.button)} ${pt(e.position)} stop_propagation');
                        cx.stopPropagation();
                    })
                )
                .child(
                    boxed('under', 300, 300, 100, 100, c(0.3, 0.6, 0.5))
                        .onMouseDown(Left, downLogger(log, 'under mouse_down'))
                        .onHover(hoverLogger(log, 'under'))
                )
                .child(
                    boxed('cover', 300, 300, 100, 100, c(0.8, 0.6, 0.5))
                        .occlude()
                        .onMouseDown(Left, downLogger(log, 'cover mouse_down'))
                );
        }));
        final s = script = opened.script;
        s.moveTo(60, 60);
        s.moveTo(150, 150);
        s.down(Left, 150, 150, 1);
        s.up(Left, 150, 150, 1);
        s.down(Left, 150, 150, 2);
        s.up(Left, 150, 150, 2);
        s.moveTo(350, 100);
        s.down(Left, 350, 100, 1);
        s.up(Left, 350, 100, 1);
        s.moveTo(350, 350);
        s.down(Left, 350, 350, 1);
        s.up(Left, 350, 350, 1);
        s.moveTo(150, 150);
        s.down(Left, 150, 150, 1);
        s.moveTo(160, 160);
        s.up(Left, 160, 160, 1);
        s.moveTo(150, 150);
        s.down(Left, 150, 150, 1);
        s.moveTo(60, 60);
        s.up(Left, 60, 60, 1);
        s.moveTo(150, 150);
        s.down(Right, 150, 150, 1);
        s.up(Right, 150, 150, 1);
        s.moveTo(10, 10);
        compare('mouse-dispatch', GlazeTruth.load('mouse-dispatch.json'), log);
    }

/// 2. drag-drop

    function testDragDropMatchesGpui() {
        final log:Array<String> = [];
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx) -> new ScriptView((window, cx) -> {
            div().id('root').sizeFull().relative().bg(bg())
                .child(
                    boxed('source', 50, 50, 100, 100, c(0.58, 0.5, 0.5)).onDrag(new DragValue(42), (value:DragValue, offset:Point, _, cx:App) -> {
                        log.push('source on_drag value=${value.value} offset ${pt(offset)}');
                        return cx.newEntity(_ -> new ScriptView((_, _) -> div().size(px(20)).bg(c(0.15, 0.9, 0.6))));
                    })
                )
                .child(
                    boxed('target', 250, 50, 150, 150, c(0.33, 0.4, 0.4))
                        .dragOver(DragValue, (s, _, _, _) -> s.bg(c(0.33, 0.7, 0.6)))
                        .canDrop((value, _, _) -> Std.isOfType(value, DragValue))
                        .onDrop(DragValue, (value, _, _) -> log.push('target on_drop value=${value.value}'))
                        .onDragMove(DragValue, (e:DragMoveEvent<DragValue>, _, _) -> {
                            log.push('target on_drag_move ${pt(e.event.position)} bounds ${pt(e.bounds.origin)} ${f(e.bounds.size.width)} ${f(e.bounds.size.height)}');
                        })
                        .onMouseUp(Left, upLogger(log, 'target mouse_up'))
                );
        }));
        final s = script = opened.script;
        s.setState((_, cx) -> log.push('has_active_drag=${cx.hasActiveDrag()}'));
        s.moveTo(100, 100);
        s.down(Left, 100, 100, 1);
        s.moveTo(101, 100);
        s.moveTo(110, 100);
        s.moveTo(300, 100);
        s.moveTo(310, 110);
        s.up(Left, 310, 110, 1);
        s.moveTo(100, 100);
        s.down(Left, 100, 100, 1);
        s.moveTo(110, 100);
        s.moveTo(200, 300);
        s.up(Left, 200, 300, 1);
        compare('drag-drop', GlazeTruth.load('drag-drop.json'), log);
    }

/// 3. scroll-wheel

    static function scrollLogger(log:Array<String>, name:String):(glaze.ScrollEvent, Window, App) -> Void {
        return (e, window, _) -> {
            final lineHeight = window.lineHeight();
            log.push('$name on_scroll ${pt(e.position)} ${deltaDesc(e.delta)} shift=${e.modifiers.shift} pixel_delta ${pt(e.delta.pixelDelta(lineHeight))} line_height ${f(lineHeight)}');
        };
    }

    function testScrollWheelMatchesGpui() {
        final log:Array<String> = [];
        final list = new ScrollHandle();
        final row = new ScrollHandle();
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx) -> new ScriptView((window, cx) -> {
            div().id('root').sizeFull().relative().bg(bg())
                .child(
                    boxed('list', 20, 20, 200, 200, c(0.6, 0.2, 0.2))
                        .overflowYScroll()
                        .trackScroll(list)
                        .flex()
                        .flexCol()
                        .onScroll(scrollLogger(log, 'list'))
                        .children([for (i in 0...10) div().flexNone().w(px(200)).h(px(50)).bg(c(i / 10, 0.6, 0.5))])
                )
                .child(
                    boxed('row', 260, 20, 200, 60, c(0.6, 0.2, 0.2))
                        .overflowXScroll()
                        .trackScroll(row)
                        .flex()
                        .flexRow()
                        .onScroll(scrollLogger(log, 'row'))
                        .children([for (i in 0...6) div().flexNone().w(px(80)).h(px(60)).bg(c(i / 6, 0.6, 0.5))])
                );
        }));
        final s = script = opened.script;
        s.setState((_, _) -> {
            log.push('list offset ${pt(list.offset())} max ${pt(list.maxOffset())}');
            log.push('row offset ${pt(row.offset())} max ${pt(row.maxOffset())}');
        });
        inline function pixels(x:Float, y:Float):ScrollDelta {
            return ScrollDelta.Pixels(new Point(x, y));
        }
        s.moveTo(100, 100);
        s.scroll(100, 100, pixels(0, -30), false);
        s.scroll(100, 100, ScrollDelta.Lines(new Point(0, -2)), false);
        s.scroll(100, 100, pixels(0, -1000), false);
        s.scroll(100, 100, pixels(0, 50), false);
        s.scroll(400, 400, pixels(0, -30), false);
        s.step('list scroll_to_item 9', (_, _) -> list.scrollToItem(9));
        s.step('list scroll_to_item 0', (_, _) -> list.scrollToItem(0));
        s.step('list set_offset 0.0 -120.0', (_, _) -> list.setOffset(new Point(0, -120)));
        s.moveTo(300, 50);
        s.scroll(300, 50, pixels(0, -40), false);
        s.scroll(300, 50, pixels(0, -40), true);
        s.scroll(300, 50, pixels(-500, 0), false);
        s.step('row scroll_to_item 0', (_, _) -> row.scrollToItem(0));
        compare('scroll-wheel', GlazeTruth.load('scroll-wheel.json'), log);
    }

/// 4. focus-tab

    function testFocusTabMatchesGpui() {
        final log:Array<String> = [];
        final handles:Array<{name:String, handle:FocusHandle}> = [];
        inline function get(name:String):FocusHandle {
            return Lambda.find(handles, h -> h.name == name).handle;
        }
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx:Context<ScriptView>) -> {
            final ws = cx.focusHandle();
            final a = cx.focusHandle().tabStop(true);
            final b = cx.focusHandle().tabIndex(2).tabStop(true);
            final c_ = cx.focusHandle().tabIndex(1).tabStop(true);
            final d = cx.focusHandle();
            final e = cx.focusHandle().tabIndex(1).tabStop(true);
            final f_ = cx.focusHandle().tabIndex(0).tabStop(true);
            for (entry in [{name: 'a', handle: a}, {name: 'b', handle: b}, {name: 'c', handle: c_}, {name: 'd', handle: d}, {name: 'e', handle: e}, {name: 'f', handle: f_}]) {
                final name = entry.name;
                cx.onFocus(entry.handle, window, (_, _, _) -> log.push('$name on_focus'));
                cx.onBlur(entry.handle, window, (_, _, _) -> log.push('$name on_blur'));
            }
            cx.onFocusIn(ws, window, (_, _, _) -> log.push('ws on_focus_in'));
            cx.onFocusOut(ws, window, (_, _, _, _) -> log.push('ws on_focus_out'));
            for (entry in [{name: 'ws', handle: ws}, {name: 'a', handle: a}, {name: 'b', handle: b}, {name: 'c', handle: c_}, {name: 'd', handle: d}, {name: 'e', handle: e}, {name: 'f', handle: f_}]) {
                handles.push(entry);
            }
            return new ScriptView((window, cx) -> {
                inline function item(name:String, x:Float, y:Float, hue:Float):Div {
                    return boxed(name, x, y, 60, 60, c(hue, 0.5, 0.5)).trackFocus(get(name));
                }
                return div().id('ws').trackFocus(get('ws')).sizeFull().relative().bg(bg())
                    .child(item('a', 20, 20, 0.0))
                    .child(item('b', 100, 20, 0.1))
                    .child(item('c', 180, 20, 0.2))
                    .child(item('d', 260, 20, 0.3))
                    .child(
                        boxed('group', 20, 120, 200, 80, c(0.6, 0.2, 0.25))
                            .tabGroup()
                            .child(item('e', 10, 10, 0.4))
                            .child(item('f', 90, 10, 0.5))
                    );
            });
        });
        final s = script = opened.script;
        s.setState((window, cx) -> {
            final focused = window.focused(cx);
            final entry = focused == null ? null : Lambda.find(handles, h -> h.handle == focused);
            log.push('focused=' + (focused == null ? 'none' : (entry != null ? entry.name : 'unknown')));
        });
        s.step('focus a', (window, cx) -> window.focus(get('a'), cx));
        for (_ in 0...5) {
            s.step('focus_next', (window, cx) -> window.focusNext(cx));
        }
        s.step('focus_prev', (window, cx) -> window.focusPrev(cx));
        s.step('focus_prev', (window, cx) -> window.focusPrev(cx));
        s.moveTo(290, 50);
        s.down(Left, 290, 50, 1);
        s.up(Left, 290, 50, 1);
        s.step('focus_next', (window, cx) -> window.focusNext(cx));
        s.moveTo(450, 450);
        s.down(Left, 450, 450, 1);
        s.up(Left, 450, 450, 1);
        s.step('blur', (window, cx) -> window.blur(cx));
        s.step('focus_next', (window, cx) -> window.focusNext(cx));
        s.step('focus e', (window, cx) -> window.focus(get('e'), cx));
        s.step('focus_next', (window, cx) -> window.focusNext(cx));
        compare('focus-tab', GlazeTruth.load('focus-tab.json'), log);
    }

/// 5. key-actions

    function testKeyActionsMatchesGpui() {
        final log:Array<String> = [];
        app.bindKeys([
            new KeyBinding('a', new ActionA(), 'Editor'),
            new KeyBinding('b', new ActionB(), null),
            new KeyBinding('ctrl-k', new ActionB(), 'Pane'),
            new KeyBinding('ctrl-k ctrl-c', new Multi(), 'Editor'),
            new KeyBinding('escape', new Escape(), 'Workspace'),
        ]);
        final ws = app.focusHandle();
        final editor = app.focusHandle();
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx) -> new ScriptView((window, cx) -> {
            div().id('workspace').keyContext('Workspace').trackFocus(ws).sizeFull().relative().bg(bg())
                .captureAction(ActionA, actionLogger(log, 'Workspace capture_action ActionA'))
                .captureAction(ActionB, actionLogger(log, 'Workspace capture_action ActionB'))
                .captureAction(Escape, actionLogger(log, 'Workspace capture_action Escape'))
                .onAction(ActionA, actionLogger(log, 'Workspace on_action ActionA'))
                .onAction(ActionB, actionLogger(log, 'Workspace on_action ActionB'))
                .onAction(Escape, actionLogger(log, 'Workspace on_action Escape'))
                .captureKeyDown(keyDownLogger(log, 'Workspace capture_key_down'))
                .onKeyDown(keyDownLogger(log, 'Workspace on_key_down'))
                .onKeyUp(keyUpLogger(log, 'Workspace on_key_up'))
                .child(
                    boxed('pane', 20, 20, 300, 300, c(0.6, 0.2, 0.25))
                        .keyContext('Pane')
                        .onAction(ActionB, (_, _, cx) -> {
                            log.push('Pane on_action ActionB propagate');
                            cx.propagate();
                        })
                        .captureKeyDown(keyDownLogger(log, 'Pane capture_key_down'))
                        .child(
                            boxed('editor', 20, 20, 200, 200, c(0.55, 0.4, 0.4))
                                .keyContext('Editor')
                                .trackFocus(editor)
                                .onAction(ActionA, actionLogger(log, 'Editor on_action ActionA'))
                                .onAction(Multi, actionLogger(log, 'Editor on_action Multi'))
                                .onKeyDown(keyDownLogger(log, 'Editor on_key_down'))
                                .onKeyUp(keyUpLogger(log, 'Editor on_key_up'))
                        )
                );
        }));
        final s = script = opened.script;
        s.setState((window, cx) -> {
            final keys = window.pendingInputKeystrokes();
            final pending = keys == null ? 'none' : [for (k in keys) keystroke(k)].join(' ');
            final focused = window.focused(cx);
            final name = focused == null ? 'none' : (focused == ws ? 'ws' : (focused == editor ? 'editor' : 'unknown'));
            log.push('focused=$name pending=$pending');
        });
        s.step('focus editor', (window, cx) -> window.focus(editor, cx));
        s.key('a');
        s.keyUp('a');
        s.key('b');
        s.key('x');
        s.keyUp('x');
        s.key('ctrl-k');
        s.key('ctrl-c');
        s.key('ctrl-k');
        s.advance(500);
        s.advance(600);
        s.key('escape');
        s.step('dispatch_action ActionA', (window, cx) -> window.dispatchAction(new ActionA(), cx));
        s.step('focus ws', (window, cx) -> window.focus(ws, cx));
        s.key('a');
        compare('key-actions', GlazeTruth.load('key-actions.json'), log);
    }

/// 6. tooltip

    function testTooltipMatchesGpui() {
        final log:Array<String> = [];
        var frame = 0;
        var tooltipFrame = -1;
        var tooltipDesc:Null<String> = null;
        function tooltipView(name:String, cx:App) {
            return cx.newEntity(_ -> new ScriptView((_, _) -> {
                div().w(px(80)).h(px(24)).bg(c(0.12, 0.8, 0.6)).child(
                    canvas((bounds, _, _) -> {
                        tooltipDesc = '$name ${pt(bounds.origin)} ${f(bounds.size.width)} ${f(bounds.size.height)}';
                        tooltipFrame = frame;
                        return 0;
                    }, (_, _, _, _) -> {}).sizeFull()
                );
            }));
        }
        final opened = InteractionScript.open(app, dispatcher, log, (window, cx) -> new ScriptView((window, cx) -> {
            div().id('root').sizeFull().relative().bg(bg())
                .child(canvas((_, _, _) -> {
                    frame++;
                    return 0;
                }, (_, _, _, _) -> {}).sizeFull())
                .child(
                    boxed('trigger', 100, 100, 100, 40, c(0.58, 0.5, 0.5)).tooltip((_, cx) -> {
                        log.push('trigger tooltip build');
                        return tooltipView('trigger', cx);
                    })
                )
                .child(
                    boxed('hoverable', 100, 300, 100, 40, c(0.33, 0.5, 0.5)).hoverableTooltip((_, cx) -> {
                        log.push('hoverable tooltip build');
                        return tooltipView('hoverable', cx);
                    })
                );
        }));
        final s = script = opened.script;
        s.setState((_, _) -> {
            log.push(tooltipDesc != null && tooltipFrame == frame ? 'tooltip=$tooltipDesc' : 'tooltip=none');
        });
        s.moveTo(150, 120);
        s.advance(300);
        s.advance(300);
        s.moveTo(160, 125);
        s.moveTo(150, 200);
        s.advance(600);
        s.moveTo(150, 320);
        s.advance(600);
        s.moveTo(220, 340);
        s.advance(600);
        s.moveTo(300, 450);
        s.advance(300);
        s.advance(300);
        compare('tooltip', GlazeTruth.load('tooltip.json'), log);
    }

}
