// Ported from gpui-kit 0.8.1: crates/base/src/tooltip.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AnyElement;
import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Bounds;
import glaze.Context;
import glaze.Div;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Render;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Task;
import glaze.Unit;
import glaze.Window;
import glaze.kit.base.Geometry.Placement;

import glaze.Prelude.*;

/**
 * An unstyled tooltip popup.
 *
 * This corresponds to Base UI's `Tooltip.Popup`: it owns the accessible
 * tooltip role (Rust `Role::Tooltip`, no accesskit in the port) and accepts
 * application-owned content and presentation.
 */
class Tooltip implements RenderOnce implements Styled implements ParentElement {

    /** The stateful element the tooltip renders. */
    public final base:Div;

    public function new(id:ElementIdArg) {
        base = div().id(id);
    }

    public inline function style():StyleRefinement {
        return base.style();
    }

    public function extend(children:Array<AnyElement>):Void {
        base.extend(children);
    }

    public function child(child:IntoElement):Tooltip {
        if (child != null) base.child(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Tooltip {
        base.children(children);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        return base;
    }

}

/**
 * Application-wide timing for tooltips shown through `TooltipOverlay`.
 *
 * Read on every show and hide request, so installing new defaults takes
 * effect in windows that are already open. Durations are in seconds.
 */
class TooltipDefaults {

    var showDelayValue:Float;

    var gracePeriodValue:Float;

    /**
     * Creates the Base defaults: a 500 ms show delay and a 300 ms grace period.
     */
    public function new() {
        showDelayValue = 0.5;
        gracePeriodValue = 0.3;
    }

    /**
     * Sets how long the pointer must rest on a trigger before its tooltip shows.
     */
    public function withShowDelay(delay:Float):TooltipDefaults {
        final result = copy();
        result.showDelayValue = delay;
        return result;
    }

    /**
     * Sets how long a tooltip stays after the pointer leaves its trigger.
     *
     * Entering another trigger within this period switches to its tooltip
     * without waiting for the show delay.
     */
    public function withGracePeriod(period:Float):TooltipDefaults {
        final result = copy();
        result.gracePeriodValue = period;
        return result;
    }

    function copy():TooltipDefaults {
        final result = new TooltipDefaults();
        result.showDelayValue = showDelayValue;
        result.gracePeriodValue = gracePeriodValue;
        return result;
    }

    /** How long the pointer must rest on a trigger before its tooltip shows. */
    public function showDelay():Float {
        return showDelayValue;
    }

    /** How long a tooltip stays after the pointer leaves its trigger. */
    public function gracePeriod():Float {
        return gracePeriodValue;
    }

    /**
     * Installs these defaults for the whole application.
     */
    public function install(cx:AppContext):Void {
        (cx:App).setGlobal(this, TooltipDefaults);
    }

    /**
     * Returns the installed defaults, or the Base ones when none were.
     */
    public static function global(cx:AppContext):TooltipDefaults {
        tracker.Autorun.unobserve();
        final defaults = (cx:App).tryGlobal(TooltipDefaults);
        tracker.Autorun.reobserve();
        return defaults != null ? defaults : new TooltipDefaults();
    }

}

/**
 * Content requested by a tooltip trigger.
 */
class TooltipRequest {

    @:allow(glaze.kit.base)
    final build:(Window, App) -> AnyView;

    @:allow(glaze.kit.base)
    final triggerBounds:Bounds;

    @:allow(glaze.kit.base)
    var preferredPlacement:Null<Placement> = null;

    @:allow(glaze.kit.base)
    var showDelay:Null<Float> = null;

    public function new(triggerBounds:Bounds, build:(Window, App) -> AnyView) {
        this.build = build;
        this.triggerBounds = triggerBounds;
    }

    /**
     * Prefers a side for the tooltip, falling back when it does not fit.
     */
    public function withPlacement(placement:Placement):TooltipRequest {
        preferredPlacement = placement;
        return this;
    }

    /**
     * Overrides `TooltipDefaults.showDelay` for this trigger (seconds).
     */
    public function withShowDelay(delay:Float):TooltipRequest {
        showDelay = delay;
        return this;
    }

}

/**
 * Presentation transition requested by the Base tooltip lifecycle.
 */
enum TooltipTransition {

    Enter(epoch:Int);

    Switch(epoch:Int, previous:Bounds, current:Bounds);

}

/**
 * Per-window tooltip provider and overlay.
 *
 * Show requests are ignored on iOS and Android, where touch input must not
 * open hover tooltips. This does not control GPUI's native `.tooltip()` API.
 *
 * Its state is not observable: it notifies itself (`cx.notify()`) like Rust.
 */
class TooltipOverlay extends Model implements Render {

    static inline final TOOLTIP_PRIORITY:Int = 200;

    @:allow(tests)
    var enabled:Bool;

    @:allow(tests)
    var content:Null<TooltipRequest> = null;

    var previousBounds:Null<Bounds> = null;

    var epoch:Int = 0;

    @:allow(tests)
    var hadRecentTooltip:Bool = false;

    @:allow(tests)
    var animationEpoch:Int = 0;

    var isSwitching:Bool = false;

    @:allow(tests)
    var showTask:Null<Task<Unit>> = null;

    @:allow(tests)
    var hideTask:Null<Task<Unit>> = null;

    var renderer:(AnyView, TooltipTransition, Window, App) -> AnyElement;

    public function new() {
        super();
        enabled = !glaze.kit.base.Prelude.isMobile();
        renderer = (view, _, _, _) -> div().child(view).intoAnyElement();
    }

    /**
     * Sets how the tooltip view is presented (Rust consumes and returns `self`;
     * this mutates and returns the overlay).
     */
    public function renderWith(renderer:(AnyView, TooltipTransition, Window, App) -> AnyElement):TooltipOverlay {
        this.renderer = renderer;
        return this;
    }

    function nextEpoch():Int {
        epoch += 1;
        return epoch;
    }

    // Rust drops a task by replacing it, which cancels it.
    function setShowTask(task:Null<Task<Unit>>):Void {
        if (showTask != null) showTask.cancel();
        showTask = task;
    }

    function setHideTask(task:Null<Task<Unit>>):Void {
        if (hideTask != null) hideTask.cancel();
        hideTask = task;
    }

    public function requestShow(content:TooltipRequest, window:Window, cx:Context<TooltipOverlay>):Void {
        // Gate both delayed display and the immediate grace-period switch.
        // Keep this in Base so every managed component shares the policy.
        if (!enabled) {
            return;
        }
        setHideTask(null);
        final showDelay:Float = content.showDelay != null ? content.showDelay : TooltipDefaults.global(cx.app).showDelay();
        final wasVisible = this.content != null;
        if (wasVisible || hadRecentTooltip || showDelay == 0) {
            previousBounds = this.content != null ? this.content.triggerBounds : null;
            this.content = content;
            setShowTask(null);
            isSwitching = wasVisible;
            animationEpoch += 1;
            cx.notify();
            return;
        }

        final epoch = nextEpoch();
        setShowTask(cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(showDelay).then(_ -> {
            if (window.isDestroyed()) return;
            this_.tryUpdate(acx, (this_, cx) -> {
                if (this_.epoch == epoch) {
                    this_.content = content;
                    this_.previousBounds = null;
                    this_.isSwitching = false;
                    this_.animationEpoch += 1;
                    cx.notify();
                }
            });
        })));
    }

    public function requestHide(window:Window, cx:Context<TooltipOverlay>):Void {
        setShowTask(null);
        if (content == null) {
            return;
        }
        final epoch = nextEpoch();
        final gracePeriod = TooltipDefaults.global(cx.app).gracePeriod();
        hadRecentTooltip = true;
        setHideTask(cx.spawn((this_, acx) -> acx.backgroundExecutor().timer(gracePeriod).then(_ -> {
            if (window.isDestroyed()) return;
            this_.tryUpdate(acx, (this_, cx) -> {
                if (this_.epoch == epoch) {
                    this_.content = null;
                    this_.previousBounds = null;
                    this_.hadRecentTooltip = false;
                    cx.notify();
                }
            });
        })));
    }

    public function hide(cx:Context<TooltipOverlay>):Void {
        final changed = content != null
            || previousBounds != null
            || hadRecentTooltip
            || showTask != null
            || hideTask != null;
        content = null;
        previousBounds = null;
        hadRecentTooltip = false;
        isSwitching = false;
        setShowTask(null);
        setHideTask(null);
        if (changed) {
            cx.notify();
        }
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final content = this.content;
        if (content == null) {
            return div();
        }
        final view = content.build(window, cx.app);
        final transition = isSwitching && previousBounds != null
            ? TooltipTransition.Switch(animationEpoch, previousBounds, content.triggerBounds)
            : TooltipTransition.Enter(animationEpoch);
        final rendered = renderer(view, transition, window, cx.app);
        final positioner = TooltipPositioner.create(content.triggerBounds);
        if (content.preferredPlacement != null) {
            positioner.placement(content.preferredPlacement);
        }
        return deferred(positioner.child(rendered)).withPriority(TOOLTIP_PRIORITY);
    }

    override function destroy() {
        setShowTask(null);
        setHideTask(null);
        super.destroy();
    }

}

/**
 * An unstyled tooltip positioner with viewport-aware flipping and clamping.
 *
 * This is a tooltip-named view of `Positioner`'s side placement. It adds no
 * element of its own; the shared positioner is what gets rendered (Rust
 * `TooltipPositioner(Positioner)`, here a function returning it).
 */
class TooltipPositioner {

    static inline final WINDOW_MARGIN:Float = 4.;

    public static function create(triggerBounds:Bounds):Positioner {
        return Positioner.side(triggerBounds).margin(WINDOW_MARGIN);
    }

}
