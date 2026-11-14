package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.base.input.BlinkCursor;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * Render on demand (`ceramic.Settings.renderOnDemand`, off by default): with
 * the mode on, Ceramic draws a frame only when something requested it.
 *
 * The asynchronous tests run in the real loop of the app: they count the
 * frames Ceramic draws (its begin draw event) between two steps. Each
 * trigger is tried on an app at rest, and must draw without any warning of
 * the debug check (`ceramic_verify_render_on_demand`, on in this suite), which
 * would otherwise draw the frame itself and hide a missing request.
 *
 * On node (headless backend) nothing is rendered: the test clears the
 * `renderDirty` flag of the render textures after each drawn frame, like the
 * renderer does.
 */
class RenderOnDemandTest extends TestCase {

    var ceramicApp(get, never):ceramic.App;
    inline function get_ceramicApp():ceramic.App return ceramic.App.app;

    var probe:ceramic.Entity = null;

    /** Frames drawn by Ceramic since `setup()` */
    var drawn:Int = 0;

    var drawnMark:Int = 0;

    var warningsMark:Int = 0;

    var steps:Array<RenderOnDemandStep> = [];

    final created:Array<ceramic.Entity> = [];

    var previousSetting:Bool = false;

    var previousBackground:ceramic.Color = ceramic.Color.BLACK;

    // Glaze

    var dispatcher:TestDispatcher;

    var app:App;

    var host:Null<glaze.Glaze> = null;

    var window:Null<Window> = null;

    var view:Null<Entity<RenderOnDemandView>> = null;

    var initialGrace:Int = 120;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.setTextSystem(TextFixtures.textSystem());
        initialGrace = glaze.VisualElement.gracePeriodFrames;
        ceramicApp.flushImmediate();

        previousSetting = ceramicApp.settings.renderOnDemand;
        previousBackground = ceramicApp.settings.background;
        drawn = 0;
        steps = [];
        final probe = new ceramic.Entity();
        this.probe = probe;
        ceramicApp.onBeginDraw(probe, () -> drawn++);
        #if !clay
        ceramicApp.onFinishDraw(probe, () -> {
            for (texture in ceramicApp.renderTextures) {
                texture.renderDirty = false;
            }
        });
        #end
        ceramicApp.onPostUpdate(probe, _ -> runSteps());
    }

    override function teardown() {
        ceramicApp.settings.renderOnDemand = previousSetting;
        ceramicApp.settings.background = previousBackground;
        glaze.VisualElement.gracePeriodFrames = initialGrace;
        if (probe != null) {
            probe.destroy();
            probe = null;
        }
        if (host != null) {
            host.destroy();
            host = null;
        }
        window = null;
        view = null;
        for (entity in created) {
            if (!entity.destroyed) entity.destroy();
        }
        created.resize(0);
        steps = [];
        ceramicApp.requestRender();
        ceramicApp.flushImmediate();
    }

/// Steps

    /** Runs `run` after `frames` updates of the app (in its post update event, before the frame is drawn or skipped) */
    function after(frames:Int, run:() -> Void):Void {
        steps.push(new RenderOnDemandStep(frames, null, run));
    }

    /** Runs `run` at the first update where `until()` is true (10 seconds at most) */
    function when(until:() -> Bool, run:() -> Void):Void {
        steps.push(new RenderOnDemandStep(0, until, run));
    }

    function runSteps():Void {
        if (steps.length == 0) return;
        final step = steps[0];
        step.frames--;
        if (step.until != null) {
            if (step.deadline < 0) step.deadline = haxe.Timer.stamp() + 10;
            if (!step.until()) {
                if (haxe.Timer.stamp() < step.deadline) return;
                fail('a condition was never met');
            }
        }
        else if (step.frames > 0) {
            return;
        }
        steps.shift();
        step.run();
    }

    function mark():Void {
        drawnMark = drawn;
        #if ceramic_verify_render_on_demand
        warningsMark = ceramicApp.renderOnDemandVerifier.warnings;
        #end
    }

    /** Frames drawn since `mark()` */
    function newDraws():Int {
        return drawn - drawnMark;
    }

    /** Warnings of the debug check since `mark()` */
    function newWarnings():Int {
        #if ceramic_verify_render_on_demand
        return ceramicApp.renderOnDemandVerifier.warnings - warningsMark;
        #else
        return 0;
        #end
    }

    function lastWarning():String {
        #if ceramic_verify_render_on_demand
        return ceramicApp.renderOnDemandVerifier.lastWarning;
        #else
        return null;
        #end
    }

    /** The mode on, then the app at rest */
    function onDemand():Void {
        after(1, () -> ceramicApp.settings.renderOnDemand = true);
        rest();
    }

    /** Lets what is pending be drawn */
    function rest():Void {
        after(2, mark);
    }

    /**
     * From an app at rest: no frame is drawn before `trigger`, between `min`
     * and `max` frames are drawn after it, none of them because of the debug
     * check, and the app is at rest again.
     */
    function expectRender(name:String, trigger:() -> Void, min:Int = 1, max:Int = 1, wait:Int = 3):Void {
        rest();
        after(1, () -> {
            assertEquals(0, newDraws(), '$name: frames drawn at rest before');
            assertTrue(ceramicApp.renderSkipped, '$name: last frame skipped before');
            mark();
            trigger();
        });
        after(wait, () -> {
            final draws = newDraws();
            assertTrue(draws >= min && draws <= max, '$name: $draws frames drawn (expected $min to $max)');
            assertEquals(0, newWarnings(), '$name: warning of the debug check: ${lastWarning()}');
            mark();
        });
        after(1, () -> assertEquals(0, newDraws(), '$name: frames drawn at rest after'));
    }

    function quad(width:Float, height:Float):ceramic.Quad {
        final q = new ceramic.Quad();
        q.size(width, height);
        q.color = ceramic.Color.RED;
        created.push(q);
        return q;
    }

/// The setting and the API (synchronous)

    function testOffByDefault() {
        assertFalse(previousSetting);
        assertFalse(@:privateAccess new ceramic.Settings().renderOnDemand);
    }

    function testRequestRenderRaisesTheFlag() {
        ceramicApp.renderRequested = false;
        ceramicApp.requestRender();
        assertTrue(ceramicApp.renderRequested);
    }

    function testContinuousRenderOwners() {
        final a = new ceramic.Entity();
        final b = new ceramic.Entity();
        assertFalse(ceramicApp.hasContinuousRender(a));
        ceramicApp.requestContinuousRender(a);
        ceramicApp.requestContinuousRender(a);
        ceramicApp.requestContinuousRender(b);
        assertTrue(ceramicApp.hasContinuousRender(a));
        assertTrue(ceramicApp.hasContinuousRender(b));
        assertEquals(2, @:privateAccess ceramicApp.continuousRenderOwners.length);
        ceramicApp.releaseContinuousRender(a);
        assertFalse(ceramicApp.hasContinuousRender(a));
        // Released twice, or never requested: nothing
        ceramicApp.releaseContinuousRender(a);
        assertEquals(1, @:privateAccess ceramicApp.continuousRenderOwners.length);
        // Released when the owner is destroyed
        b.destroy();
        assertFalse(ceramicApp.hasContinuousRender(b));
        assertEquals(0, @:privateAccess ceramicApp.continuousRenderOwners.length);
        // A destroyed owner holds nothing
        ceramicApp.requestContinuousRender(b);
        assertEquals(0, @:privateAccess ceramicApp.continuousRenderOwners.length);
        a.destroy();
    }

    function testOnceDrawListenersNeedAFrame() {
        final owner = new ceramic.Entity();
        final rest = ceramicApp.renderRequested;
        ceramicApp.renderRequested = false;
        function needed():Bool {
            return @:privateAccess ceramicApp.shouldRenderOnDemand();
        }
        final before = needed();
        final begin = () -> {};
        ceramicApp.onceBeginDraw(owner, begin);
        assertTrue(needed());
        ceramicApp.offBeginDraw(begin);
        assertEquals(before, needed());
        final finish = () -> {};
        ceramicApp.onceFinishDraw(null, finish);
        assertTrue(needed());
        ceramicApp.offFinishDraw(finish);
        assertEquals(before, needed());
        // A permanent listener is called on drawn frames only: it requests nothing
        ceramicApp.onFinishDraw(owner, finish);
        assertEquals(before, needed());
        owner.destroy();
        ceramicApp.renderRequested = rest;
    }

#if ceramic_verify_render_on_demand
/// The debug check (synchronous)

    function testVerifierSeesWhatHasNoDirtyFlag() {
        final verifier = new ceramic.RenderOnDemandVerifier();
        ceramic.RenderOnDemandVerifier.maxLoggedWarnings = 0;
        final messages:Array<String> = [];
        verifier.onWarning = message -> messages.push(message);
        final q = quad(10, 10);
        q.id = 'checked';
        final other = quad(10, 10);
        final mesh = new ceramic.Mesh();
        created.push(mesh);
        mesh.vertices = [0, 0, 10, 0, 10, 10];
        mesh.indices = [0, 1, 2];
        mesh.colors = [ceramic.AlphaColor.WHITE];
        final visuals:Array<ceramic.Visual> = [q, other, mesh];

        // Nothing kept yet: nothing to compare
        assertFalse(verifier.check(visuals));
        verifier.capture(visuals);
        assertFalse(verifier.check(visuals));
        assertEquals(0, verifier.warnings);

        function changed(kind:String, ?pos:haxe.PosInfos):Void {
            final count = verifier.warnings;
            assertTrue(verifier.check(visuals), kind, pos);
            assertEquals(count + 1, verifier.warnings, kind, pos);
            assertTrue(verifier.lastWarning.indexOf(kind) != -1, verifier.lastWarning, pos);
            assertEquals(verifier.lastWarning, messages[messages.length - 1], null, pos);
            // The frame is then drawn
            verifier.capture(visuals);
            assertFalse(verifier.check(visuals), kind, pos);
        }

        q.color = ceramic.Color.BLUE;
        changed('color');
        assertTrue(verifier.lastWarning.indexOf('Quad(checked)') != -1, verifier.lastWarning);
        q.frameX = 2;
        changed('transform');
        @:privateAccess q.matTX = 4;
        changed('transform');
        @:privateAccess q.computedAlpha = 0.5;
        changed('alpha');
        @:bypassAccessor q.blending = ceramic.Blending.ADD;
        changed('blending');
        @:privateAccess q._texture = new ceramic.RenderTexture(4, 4);
        created.push(q.texture);
        changed('texture');
        @:bypassAccessor q.shader = ceramicApp.defaultTexturedShader;
        changed('shader');
        @:bypassAccessor q.shader = null;
        changed('shader');
        mesh.vertices[2] = 12;
        changed('mesh');
        mesh.indices.push(0);
        changed('mesh');
        mesh.uvs.push(0.5);
        changed('mesh');
        mesh.colors[0] = ceramic.AlphaColor.BLACK;
        changed('color');

        // A visual that is not shown is not compared, wherever it is in the list
        // (the sort of the visuals does not keep the order of the ones not shown)
        @:privateAccess other.computedVisible = false;
        changed('visible visuals');
        other.color = ceramic.Color.GREEN;
        assertFalse(verifier.check(visuals));
        visuals[0] = other;
        visuals[1] = q;
        assertFalse(verifier.check(visuals));
        @:privateAccess other.computedVisible = true;
        changed('visible visuals');

        // Another list of visuals
        visuals.pop();
        changed('visible visuals');
        visuals[0] = q;
        visuals[1] = other;
        changed('visible visuals');
        ceramic.RenderOnDemandVerifier.maxLoggedWarnings = 50;
    }
#end

/// The decision

    function asyncTestOffEveryFrameIsDrawn(done:() -> Void) {
        assertFalse(ceramicApp.settings.renderOnDemand);
        after(2, mark);
        after(6, () -> {
            assertEquals(6, newDraws());
            assertFalse(ceramicApp.renderSkipped);
            done();
        });
    }

    function asyncTestFramesAtRestAreSkipped(done:() -> Void) {
        var updates = 0;
        ceramicApp.onUpdate(probe, _ -> updates++);
        onDemand();
        after(1, () -> updates = 0);
        after(10, () -> {
            assertEquals(0, newDraws());
            assertTrue(ceramicApp.renderSkipped);
            assertFalse(ceramicApp.renderRequested);
            // The app still updates
            assertEquals(10, updates);
            mark();
            ceramicApp.requestRender();
            // Twice is still one frame
            ceramicApp.requestRender();
        });
        after(1, () -> {
            assertEquals(1, newDraws());
            assertFalse(ceramicApp.renderSkipped);
        });
        after(4, () -> {
            assertEquals(1, newDraws());
            assertTrue(ceramicApp.renderSkipped);
            // Back to off: every frame again
            ceramicApp.settings.renderOnDemand = false;
            mark();
        });
        after(4, () -> {
            assertEquals(4, newDraws());
            assertFalse(ceramicApp.renderSkipped);
            done();
        });
    }

    function asyncTestTweensKeepTheirPaceOnSkippedFrames(done:() -> Void) {
        // `Tween.endFrame()` runs on skipped frames too: a tween started at rest
        // ticks at every frame, from its first one
        onDemand();
        var values = 0;
        var complete = false;
        after(1, () -> {
            final tween = ceramic.Tween.start(probe, LINEAR, 0.45, 0, 1, (_, _) -> values++);
            tween.onceComplete(probe, () -> complete = true);
            mark();
        });
        after(3, () -> {
            // Every frame is drawn while it runs
            assertEquals(3, newDraws());
            assertTrue(values >= 3, '$values values');
        });
        when(() -> complete, () -> {});
        rest();
        after(3, () -> {
            assertEquals(0, newDraws());
            assertEquals(0, newWarnings(), lastWarning());
            done();
        });
    }

/// Automatic requests

    function asyncTestVisualChangesRequestARender(done:() -> Void) {
        onDemand();
        var q:ceramic.Quad = null;
        var other:ceramic.Quad = null;
        var texture:ceramic.RenderTexture = null;
        expectRender('visual added', () -> {
            q = quad(10, 10);
            ceramicApp.screen.add(q);
            other = quad(10, 10);
            ceramicApp.screen.add(other);
            texture = new ceramic.RenderTexture(8, 8);
            texture.autoRender = false;
            created.push(texture);
        }, 1, 3);
        expectRender('x', () -> q.x = 20);
        expectRender('y', () -> q.y = 20);
        expectRender('scale', () -> q.scaleX = 2);
        expectRender('rotation', () -> q.rotation = 30);
        expectRender('anchor', () -> q.anchor(0.5, 0.5));
        expectRender('alpha', () -> q.alpha = 0.5);
        expectRender('depth', () -> q.depth = 3);
        expectRender('width', () -> other.width = 30);
        expectRender('height', () -> other.height = 30);
        expectRender('hidden', () -> q.visible = false);
        expectRender('shown', () -> q.visible = true);
        expectRender('inactive', () -> q.active = false);
        expectRender('active', () -> q.active = true);
        after(1, done);
    }

    function asyncTestVisualContentChangesRequestARender(done:() -> Void) {
        onDemand();
        var q:ceramic.Quad = null;
        var other:ceramic.Quad = null;
        var texture:ceramic.RenderTexture = null;
        expectRender('visual added', () -> {
            q = quad(10, 10);
            ceramicApp.screen.add(q);
            other = quad(10, 10);
            ceramicApp.screen.add(other);
            texture = new ceramic.RenderTexture(8, 8);
            texture.autoRender = false;
            created.push(texture);
        }, 1, 3);
        expectRender('content', () -> q.contentDirty = true);
        expectRender('transform set', () -> q.transform = new ceramic.Transform());
        expectRender('transform changed', () -> {
            q.transform.tx = 5;
            q.transform.changedDirty = true;
        });
        expectRender('texture', () -> q.texture = texture);
        expectRender('no texture', () -> q.texture = null);
        expectRender('blending', () -> q.blending = ceramic.Blending.ADD);
        expectRender('shader', () -> q.shader = ceramicApp.defaultTexturedShader);
        expectRender('no shader', () -> q.shader = null);
        expectRender('clip', () -> q.clip = other);
        expectRender('no clip', () -> q.clip = null);
        expectRender('render target', () -> other.renderTarget = texture, 1, 2);
        expectRender('no render target', () -> other.renderTarget = null, 1, 2);
        expectRender('child added', () -> q.add(other));
        expectRender('child removed', () -> q.remove(other), 1, 2);
        expectRender('destroyed', () -> q.destroy(), 1, 2);
        after(1, done);
    }

    function asyncTestTimeAndCallbacksRequestARender(done:() -> Void) {
        onDemand();

        var fired = false;
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            ceramic.Timer.delay(probe, 0.12, () -> fired = true);
        });
        when(() -> fired, mark);
        after(1, () -> assertEquals(1, newDraws(), 'timer'));
        after(3, () -> assertEquals(1, newDraws(), 'timer, at rest after'));

        var updatesFired = false;
        rest();
        after(1, () -> ceramicApp.onceXUpdates(probe, 2, () -> updatesFired = true));
        when(() -> updatesFired, mark);
        after(1, () -> assertEquals(1, newDraws(), 'onceXUpdates'));
        after(3, () -> assertEquals(1, newDraws(), 'onceXUpdates, at rest after'));

        var mainFired = false;
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            mark();
            ceramic.Runner.runInMain(() -> mainFired = true);
        });
        after(4, () -> {
            assertTrue(mainFired);
            final draws = newDraws();
            assertTrue(draws >= 1 && draws <= 2, 'runInMain: $draws frames drawn');
        });

        var backgroundFired = false;
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            mark();
            ceramic.Runner.runInBackground(() -> ceramic.Runner.runInMain(() -> backgroundFired = true));
        });
        when(() -> backgroundFired, () -> {});
        after(2, () -> {
            final draws = newDraws();
            assertTrue(draws >= 1 && draws <= 3, 'runInBackground: $draws frames drawn');
        });

        expectRender('tween without duration', () -> ceramic.Tween.start(probe, LINEAR, 0, 0, 1, (_, _) -> {}), 1, 2);
        expectRender('begin update callback', () -> @:privateAccess ceramicApp.beginUpdateCallbacks.push(() -> {}));
        expectRender('asset load', () -> {
            final asset = new ceramic.TextAsset('render-on-demand');
            created.push(asset);
            @:privateAccess asset.emitComplete(true);
        });
        expectRender('render texture marked dirty', () -> {
            final texture = new ceramic.RenderTexture(8, 8);
            texture.autoRender = false;
            created.push(texture);
            texture.renderDirty = true;
        }, 1, 3);
        after(1, done);
    }

    function asyncTestInputAndScreenEventsRequestARender(done:() -> Void) {
        onDemand();
        final input = ceramicApp.input;
        final screen = ceramicApp.screen;
        final key = new ceramic.Key(ceramic.KeyCode.KEY_A, ceramic.ScanCode.KEY_A);
        expectRender('key down', () -> @:privateAccess input.emitKeyDown(key), 1, 3);
        expectRender('key up', () -> @:privateAccess input.emitKeyUp(key), 1, 3);
        expectRender('text commit', () -> @:privateAccess input.emitTextCommit('a'), 1, 3);
        expectRender('text composition', () -> @:privateAccess input.emitTextComposition('', 0, 0), 1, 3);
        expectRender('mouse move', () -> @:privateAccess screen.emitMouseMove(600, 400), 1, 3);
        expectRender('mouse down', () -> @:privateAccess screen.emitMouseDown(0, 600, 400), 1, 3);
        expectRender('mouse up', () -> @:privateAccess screen.emitMouseUp(0, 600, 400), 1, 3);
        expectRender('mouse wheel', () -> @:privateAccess screen.emitMouseWheel(0, 1), 1, 3);
        expectRender('mouse scroll', () -> @:privateAccess screen.emitMouseScroll(0, 10, ceramic.ScrollUnit.PIXELS), 1, 3);
        expectRender('touch down', () -> @:privateAccess screen.emitTouchDown(0, 600, 400), 1, 3);
        expectRender('touch move', () -> @:privateAccess screen.emitTouchMove(0, 601, 400), 1, 3);
        expectRender('touch up', () -> @:privateAccess screen.emitTouchUp(0, 601, 400), 1, 3);
        expectRender('touch cancel', () -> @:privateAccess screen.emitTouchCancel(0, 601, 400), 1, 3);
        expectRender('gamepad down', () -> @:privateAccess input.emitGamepadDown(0, ceramic.GamepadButton.A), 1, 3);
        expectRender('gamepad up', () -> @:privateAccess input.emitGamepadUp(0, ceramic.GamepadButton.A), 1, 3);
        expectRender('gamepad axis', () -> @:privateAccess input.emitGamepadAxis(0, ceramic.GamepadAxis.LEFT_X, 0.5), 1, 3);
        expectRender('gamepad axis back', () -> @:privateAccess input.emitGamepadAxis(0, ceramic.GamepadAxis.LEFT_X, 0), 1, 3);
        // Queued by the backend, like every real input and window event
        expectRender('backend key down', () -> @:privateAccess ceramicApp.backend.input.emitKeyDown(key), 1, 3);
        expectRender('backend key up', () -> @:privateAccess ceramicApp.backend.input.emitKeyUp(key), 1, 3);
        expectRender('backend resize', () -> @:privateAccess ceramicApp.backend.screen.emitResize(), 1, 3);
        expectRender('screen resize', () -> @:privateAccess screen.resize(), 1, 3);
        expectRender('background', () -> ceramicApp.settings.background = 0x123456, 1, 3);
        after(1, done);
    }

    /**
     * From an app at rest: `trigger` runs app code (a timer, an event) and no frame
     * is drawn for it.
     */
    function expectNoRender(name:String, trigger:() -> Void, wait:Int = 4):Void {
        rest();
        after(1, () -> {
            assertEquals(0, newDraws(), '$name: frames drawn at rest before');
            mark();
            trigger();
        });
        after(wait, () -> assertEquals(0, newDraws(), '$name: frames drawn'));
    }

    function asyncTestCallbackRequestsCanBeTurnedOff(done:() -> Void) {
        onDemand();
        final input = ceramicApp.input;
        final screen = ceramicApp.screen;
        final key = new ceramic.Key(ceramic.KeyCode.KEY_A, ceramic.ScanCode.KEY_A);
        after(1, () -> {
            assertTrue(ceramicApp.settings.renderOnDemandCallbacks, 'on by default');
            ceramicApp.settings.renderOnDemandCallbacks = false;
        });

        // App code runs, nothing asks for a render: no frame
        var fired = 0;
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            mark();
            ceramic.Timer.delay(probe, 0.01, () -> fired++);
        });
        when(() -> fired == 1, () -> {});
        after(3, () -> assertEquals(0, newDraws(), 'timer: frames drawn'));
        expectNoRender('onceXUpdates', () -> ceramicApp.onceXUpdates(probe, 1, () -> fired++));
        expectNoRender('runInMain', () -> ceramic.Runner.runInMain(() -> fired++));
        after(1, () -> assertEquals(3, fired, 'the callbacks ran'));
        expectNoRender('key down', () -> @:privateAccess input.emitKeyDown(key));
        expectNoRender('key up', () -> @:privateAccess input.emitKeyUp(key));
        expectNoRender('mouse move', () -> @:privateAccess screen.emitMouseMove(610, 410));
        expectNoRender('mouse down', () -> @:privateAccess screen.emitMouseDown(0, 610, 410));
        expectNoRender('mouse up', () -> @:privateAccess screen.emitMouseUp(0, 610, 410));
        expectNoRender('backend key down', () -> @:privateAccess ceramicApp.backend.input.emitKeyDown(key));
        expectNoRender('backend key up', () -> @:privateAccess ceramicApp.backend.input.emitKeyUp(key));

        // What Ceramic tracks, window events and explicit requests still draw
        var q:ceramic.Quad = null;
        expectRender('visual added', () -> {
            q = quad(10, 10);
            ceramicApp.screen.add(q);
        }, 1, 3);
        expectRender('requestRender', () -> ceramicApp.requestRender());

        // A timer moves a visual: tracked by its dirty flag, drawn without any request
        var moved = false;
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            ceramic.Timer.delay(probe, 0.01, () -> { q.x = 20; moved = true; });
        });
        when(() -> moved, mark);
        after(1, () -> assertEquals(1, newDraws(), 'visual moved from a timer'));
        after(3, () -> assertEquals(1, newDraws(), 'visual moved from a timer, at rest after'));

        // A timer changes a plain field: the app asks for the render itself
        var colored = false;
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            ceramic.Timer.delay(probe, 0.01, () -> {
                q.color = ceramic.Color.BLUE;
                ceramicApp.requestRender();
                colored = true;
            });
        });
        when(() -> colored, mark);
        after(1, () -> assertEquals(1, newDraws(), 'plain field from a timer, with a request'));
        after(3, () -> assertEquals(1, newDraws(), 'plain field from a timer, at rest after'));

        expectRender('screen resize', () -> @:privateAccess screen.resize(), 1, 3);
        expectRender('backend resize', () -> @:privateAccess ceramicApp.backend.screen.emitResize(), 1, 3);

        after(1, () -> ceramicApp.settings.renderOnDemandCallbacks = true);
        expectRender('on again: key down', () -> @:privateAccess input.emitKeyDown(key), 1, 3);
        expectRender('on again: key up', () -> @:privateAccess input.emitKeyUp(key), 1, 3);
        after(1, done);
    }

/// Listeners of the draw events, continuous requests

    function asyncTestOnceDrawListenersGetTheirFrame(done:() -> Void) {
        onDemand();
        var begun = 0;
        var finished = 0;
        expectRender('onceBeginDraw', () -> ceramicApp.onceBeginDraw(probe, () -> begun++));
        after(1, () -> assertEquals(1, begun));
        expectRender('onceFinishDraw', () -> ceramicApp.onceFinishDraw(probe, () -> finished++));
        after(1, () -> assertEquals(1, finished));
        // A listener registered while drawing waits for one more frame
        expectRender('chained', () -> ceramicApp.onceFinishDraw(probe, () -> ceramicApp.onceFinishDraw(probe, () -> finished++)), 2, 2);
        after(1, () -> {
            assertEquals(2, finished);
            done();
        });
    }

    function asyncTestContinuousRender(done:() -> Void) {
        onDemand();
        final owner = new ceramic.Entity();
        created.push(owner);
        final second = new ceramic.Entity();
        created.push(second);
        after(1, () -> {
            assertEquals(0, newDraws());
            mark();
            ceramicApp.requestContinuousRender(owner);
        });
        after(6, () -> {
            assertEquals(6, newDraws());
            assertEquals(0, newWarnings(), lastWarning());
            // Two owners: every frame until both released
            ceramicApp.requestContinuousRender(second);
            ceramicApp.releaseContinuousRender(owner);
            mark();
        });
        after(4, () -> {
            assertEquals(4, newDraws());
            // Released by the destruction of its owner
            second.destroy();
        });
        rest();
        after(4, () -> {
            assertEquals(0, newDraws());
            assertTrue(ceramicApp.renderSkipped);
            done();
        });
    }

#if ceramic_verify_render_on_demand
/// The debug check, in the loop

    function asyncTestVerifierDrawsAChangeWithoutRequest(done:() -> Void) {
        ceramic.RenderOnDemandVerifier.maxLoggedWarnings = 0;
        onDemand();
        var q:ceramic.Quad = null;
        expectRender('visual added', () -> {
            q = quad(10, 10);
            q.id = 'forgotten';
            ceramicApp.screen.add(q);
        }, 1, 2);
        rest();
        after(1, () -> {
            assertEquals(0, newDraws());
            mark();
            // A plain field: no dirty flag, no request
            q.color = ceramic.Color.BLUE;
            assertFalse(ceramicApp.renderRequested);
        });
        after(3, () -> {
            // Reported once, and drawn
            assertEquals(1, newWarnings());
            assertEquals(1, newDraws());
            final message = lastWarning();
            assertTrue(message.indexOf('Quad(forgotten)') != -1 && message.indexOf('color') != -1, message);
            mark();
            // With a request: drawn without a warning
            q.color = ceramic.Color.GREEN;
            ceramicApp.requestRender();
        });
        after(3, () -> {
            assertEquals(0, newWarnings(), lastWarning());
            assertEquals(1, newDraws());
            ceramic.RenderOnDemandVerifier.maxLoggedWarnings = 50;
            done();
        });
    }
#end

/// Glaze

    /** A Glaze visual on screen, drawn by the `GlazeSystem` like in an app */
    function open(width:Float, height:Float, render:(Window, Context<Dynamic>) -> IntoElement):Window {
        final host = new glaze.Glaze((window, cx) -> {
            final entity = cx.newEntity((_:Context<RenderOnDemandView>) -> new RenderOnDemandView(render));
            view = entity;
            return entity;
        }, {width: width, height: height, scaleFactor: 1, renderToTexture: true}, app);
        this.host = host;
        host.pos(0, 0);
        ceramicApp.screen.add(host);
        window = host.window;
        return window;
    }

    function asyncTestGlazeWindowAtRestRequestsNoRender(done:() -> Void) {
        ceramicApp.settings.renderOnDemand = true;
        open(200, 120, (_, _) -> div().sizeFull().flex().flexCol().p2().gap1().bg(white())
            .child(div().id('hover').hover(s -> s.bg(red())).child('Render on demand'))
            .child(div().h(px(20)).w(px(60)).bg(blue())));
        var requests = 0;
        var draws = 0;
        var updates = 0;
        after(8, () -> {
            assertTrue(window.drawCount > 0);
            draws = window.drawCount;
            mark();
            // Read after the Glaze system ran, before Ceramic looks at its visuals
            ceramicApp.onPostUpdate(probe, _ -> {
                updates++;
                if (ceramicApp.renderRequested) requests++;
            });
        });
        after(121, () -> {
            assertTrue(updates >= 120, '$updates updates');
            // Nothing raised a flag, in any of the frames
            assertEquals(0, requests);
            assertEquals(0, newDraws());
            assertEquals(0, newWarnings(), lastWarning());
            assertEquals(draws, window.drawCount);
            assertTrue(ceramicApp.renderSkipped);
            done();
        });
    }

    function asyncTestGlazeChangesRequestARender(done:() -> Void) {
        countsRenders();
        ceramicApp.settings.renderOnDemand = true;
        var animate = 0;
        var label = 'child';
        var child:Entity<RenderOnDemandView> = null;
        var cursor:Entity<BlinkCursor> = null;
        final texture = new ceramic.RenderTexture(20, 20);
        texture.autoRender = false;
        created.push(texture);
        open(240, 160, (window, cx) -> {
            if (animate > 0) {
                animate--;
                window.requestAnimationFrame();
            }
            if (child == null) {
                child = cx.app.newEntity((_:Context<RenderOnDemandView>) -> new RenderOnDemandView((_, _) -> div().h(px(20)).w(px(120)).child(label)));
            }
            return div().sizeFull().flex().flexCol().p2().gap1().bg(white())
                .child(div().id('hover').h(px(20)).w(px(120)).hover(s -> s.bg(red())).child('Hover'))
                .child((child : AnyView))
                .child(div().h(px(20)).child(cursor != null && cursor.read(cx).visible() ? 'caret' : 'no caret'))
                .child(img(texture).size(px(20.)));
        });
        var draws = 0;
        rest();
        after(4, () -> draws = window.drawCount);

        // notify
        expectRender('notify', () -> view.update(app, (_, cx) -> cx.notify()));
        after(1, () -> {
            assertEquals(draws + 1, window.drawCount, 'notify');
            draws = window.drawCount;
        });

        // Input: the pointer over an element with a hover style
        expectRender('hover', () -> @:privateAccess ceramicApp.screen.emitMouseMove(30, 18), 1, 2);
        after(1, () -> {
            assertTrue(window.drawCount > draws, 'hover');
            draws = window.drawCount;
        });
        expectRender('hover out', () -> @:privateAccess ceramicApp.screen.emitMouseMove(230, 150), 1, 2);
        after(1, () -> draws = window.drawCount);

        // requestAnimationFrame: one frame after the other, then at rest
        expectRender('requestAnimationFrame', () -> {
            animate = 3;
            view.update(app, (_, cx) -> cx.notify());
        }, 4, 4, 7);
        after(1, () -> {
            assertEquals(draws + 4, window.drawCount, 'requestAnimationFrame');
            draws = window.drawCount;
        });

        // A timer of the app (the caret blink of the kit, on the test clock)
        expectRender('caret shown', () -> {
            cursor = app.update(cx -> cx.newEntity(cx -> new BlinkCursor(cx)));
            app.update(cx -> cx.observe(cursor, (_, cx) -> view.update(cx, (_, viewCx) -> viewCx.notify())));
            cursor.update(app, (cursor, cx) -> cursor.start(cx));
        });
        after(1, () -> {
            assertTrue(cursor.readWith(app, (cursor, _) -> cursor.visible()));
            draws = window.drawCount;
        });
        expectRender('caret blink', () -> {
            dispatcher.advanceClock(BlinkCursor.INTERVAL + 1e-9);
            dispatcher.runUntilParked();
        });
        after(1, () -> {
            assertFalse(cursor.readWith(app, (cursor, _) -> cursor.visible()));
            assertEquals(draws + 1, window.drawCount, 'caret blink');
            cursor.update(app, (cursor, cx) -> cursor.stop(cx));
        });
        rest();
        after(1, () -> draws = window.drawCount);

        // A frame drawn in place: the child view alone
        var inPlace = 0;
        expectRender('in place frame', () -> {
            inPlace = Window.inPlaceFramesDrawn;
            label = 'child changed';
            child.update(app, (_, cx) -> cx.notify());
        });
        after(1, () -> {
            assertEquals(inPlace + 1, Window.inPlaceFramesDrawn, 'in place frame');
            assertEquals(draws + 1, window.drawCount, 'in place frame');
            draws = window.drawCount;
        });

        // An external texture drawn again: its version changes, no view renders
        rest();
        after(1, () -> {
            assertEquals(0, newDraws(), 'external texture: at rest before');
            draws = window.drawCount;
            mark();
            #if clay
            texture.renderDirty = true;
            #else
            // Like the renderer does when it draws into it (nothing is drawn on
            // node, so the window texture never catches up with this version)
            @:privateAccess texture.renderVersion++;
            #end
        });
        after(4, () -> {
            assertTrue(newDraws() >= 1, 'external texture');
            assertEquals(0, newWarnings(), lastWarning());
            assertEquals(draws, window.drawCount, 'external texture');
            done();
        });
    }

    function asyncTestVisualAlwaysModeRendersEveryFrame(done:() -> Void) {
        ceramicApp.settings.renderOnDemand = true;
        glaze.VisualElement.gracePeriodFrames = 2;
        final content = quad(40, 40);
        var explicit = false;
        var show = true;
        open(100, 100, (_, _) -> {
            final root = div().sizeFull();
            if (show) {
                final element = visual(content).size(px(40.));
                if (explicit) element.renderMode(Explicit);
                root.child(element);
            }
            return root;
        });
        var draws = 0;
        after(6, () -> {
            draws = window.drawCount;
            mark();
        });
        after(10, () -> {
            // `Always`: every Ceramic frame is drawn, no view renders
            assertEquals(10, newDraws());
            assertEquals(0, newWarnings(), lastWarning());
            assertEquals(draws, window.drawCount);
            // `Explicit`: at rest
            explicit = true;
            view.update(app, (_, cx) -> cx.notify());
        });
        after(6, mark);
        after(6, () -> {
            assertEquals(0, newDraws(), 'explicit');
            assertEquals(0, newWarnings(), lastWarning());
            assertTrue(ceramicApp.renderSkipped);
            // `Always` again (the window draws at the next frame)
            explicit = false;
            view.update(app, (_, cx) -> cx.notify());
        });
        after(3, mark);
        after(6, () -> {
            assertEquals(6, newDraws(), 'always again');
            // Not shown anymore: at rest, once its grace period is over
            show = false;
            view.update(app, (_, cx) -> cx.notify());
        });
        after(8, mark);
        after(6, () -> {
            assertEquals(0, newDraws(), 'not shown');
            assertEquals(0, newWarnings(), lastWarning());
            done();
        });
    }

}

private class RenderOnDemandStep {

    public var frames:Int;

    public var deadline:Float = -1;

    public final until:Null<() -> Bool>;

    public final run:() -> Void;

    public function new(frames:Int, until:Null<() -> Bool>, run:() -> Void) {
        this.frames = frames;
        this.until = until;
        this.run = run;
    }

}

class RenderOnDemandView extends Model implements Render {

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}
