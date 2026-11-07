// Ported from gpui-pre 0.3.10: examples/animation.rs (AnimationExample, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import glaze.Animation;
import glaze.AnimationPhase;
import glaze.App;
import glaze.Context;
import glaze.Easing.*;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.Pixels;
import glaze.Render;
import glaze.SpringAnimation;
import glaze.SpringConfig;
import glaze.Svg;
import glaze.Svg.Transformation;
import glaze.Window;

import glaze.Prelude.*;

using glaze.AnimationExt;

class AnimationExample extends Model implements Render {

    public static inline var WIDTH:Float = 300.0;

    public static inline var HEIGHT:Float = 300.0;

    /**
     * `concat!(env!("CARGO_MANIFEST_DIR"), "/examples/image/arrow_circle.svg")`:
     * the file is in the assets of the project.
     */
    static inline var ARROW_CIRCLE_SVG:String = 'image/arrow_circle.svg';

    static inline var MINIMUM_DAMPING:Float = 2.0;

    static inline var MAXIMUM_DAMPING:Float = 32.0;

    static inline var DAMPING_SLIDER_WIDTH:Float = 224.0;

    @observe public var springPhase:Int;

    @observe public var springDamping:Float;

    /**
     * `Option<(Pixels, f32)>`: start position and start damping of a drag.
     */
    @observe public var springDampingDrag:Null<Array<Float>>;

    public function new(springPhase:Int, springDamping:Float, springDampingDrag:Null<Array<Float>>) {
        super();
        this.springPhase = springPhase;
        this.springDamping = springDamping;
        this.springDampingDrag = springDampingDrag;
    }

    public function render(_window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<AnimationExample> = cast cx;

        final springPhase = this.springPhase;
        final springPosition = px(98.0 * springPhase);
        final springDamping = this.springDamping;
        final spring = new SpringConfig(170.0, springDamping, 1.0);
        final dampingRatio = spring.canonical()[1];
        final dampingFraction =
            (springDamping - MINIMUM_DAMPING) / (MAXIMUM_DAMPING - MINIMUM_DAMPING);

        return div()
            .flex()
            .flexCol()
            .sizeFull()
            .bg(white())
            .textColor(black())
            .justifyAround()
            .child(
                div()
                    .flex()
                    .flexCol()
                    .sizeFull()
                    .justifyAround()
                    .child(
                        div()
                            .id('content')
                            .flex()
                            .flexCol()
                            .h(px(150.))
                            .overflowYScroll()
                            .wFull()
                            .flex1()
                            .justifyCenter()
                            .itemsCenter()
                            .textXl()
                            .gap4()
                            .child('Hello Animation')
                            .child(
                                div()
                                    .id('spring-demo')
                                    .flex()
                                    .flexCol()
                                    .gap2()
                                    .p2()
                                    .w(px(240.0))
                                    .roundedMd()
                                    .bg(rgba(0x00000010))
                                    .cursorPointer()
                                    .onMouseDown(
                                        MouseButton.Left,
                                        cx.listener((this_:AnimationExample, _, _, cx) -> {
                                            this_.springPhase = (this_.springPhase + 1) % 3;
                                            cx.notify();
                                        })
                                    )
                                    .child(
                                        'Target phase $springPhase: click rapidly to redirect momentum'
                                    )
                                    .child(
                                        div()
                                            .id('spring-damping-controls')
                                            .flex()
                                            .flexCol()
                                            .gap1()
                                            .textSm()
                                            .onClick((_, _, cx) -> cx.stopPropagation())
                                            .child(
                                                'Drag damping: ${fixed(springDamping, 1)} (ζ ${fixed(dampingRatio, 2)})'
                                            )
                                            .child(
                                                div()
                                                    .id('spring-damping')
                                                    .relative()
                                                    .h(px(20.0))
                                                    .w(px(DAMPING_SLIDER_WIDTH))
                                                    .cursorPointer()
                                                    .onMouseDown(
                                                        MouseButton.Left,
                                                        cx.listener(
                                                            (this_:AnimationExample,
                                                             event:MouseDownEvent,
                                                             _,
                                                             cx) -> {
                                                                this_.springDampingDrag = [
                                                                    event.position.x,
                                                                    this_.springDamping,
                                                                ];
                                                                cx.stopPropagation();
                                                            }
                                                        )
                                                    )
                                                    .onMouseMove(cx.listener(
                                                        (this_:AnimationExample,
                                                         event:MouseMoveEvent,
                                                         _,
                                                         cx) -> {
                                                            final drag = this_.springDampingDrag;
                                                            if (drag == null) {
                                                                return;
                                                            }
                                                            final startPosition = drag[0];
                                                            final startDamping = drag[1];
                                                            final delta = (event.position.x
                                                                - startPosition)
                                                                / DAMPING_SLIDER_WIDTH;
                                                            this_.springDamping = clamp(
                                                                startDamping
                                                                    + delta
                                                                        * (MAXIMUM_DAMPING
                                                                            - MINIMUM_DAMPING),
                                                                MINIMUM_DAMPING,
                                                                MAXIMUM_DAMPING
                                                            );
                                                            cx.stopPropagation();
                                                            cx.notify();
                                                        }
                                                    ))
                                                    .onMouseUp(
                                                        MouseButton.Left,
                                                        cx.listener((this_:AnimationExample, _, _, cx) -> {
                                                            this_.springDampingDrag = null;
                                                            cx.stopPropagation();
                                                        })
                                                    )
                                                    .onMouseUpOut(
                                                        MouseButton.Left,
                                                        cx.listener((this_:AnimationExample, _, _, cx) -> {
                                                            this_.springDampingDrag = null;
                                                            cx.stopPropagation();
                                                        })
                                                    )
                                                    .child(
                                                        div()
                                                            .absolute()
                                                            .top(px(8.0))
                                                            .h(px(4.0))
                                                            .wFull()
                                                            .roundedFull()
                                                            .bg(rgba(0x00000030))
                                                    )
                                                    .child(
                                                        div()
                                                            .absolute()
                                                            .top(px(8.0))
                                                            .h(px(4.0))
                                                            .w(relative(dampingFraction))
                                                            .roundedFull()
                                                            .bg(rgba(0x3b82f6ff))
                                                    )
                                                    .child(
                                                        div()
                                                            .absolute()
                                                            .top(px(3.0))
                                                            .left(relative(dampingFraction))
                                                            .ml(px(-7.0))
                                                            .size(px(14.0))
                                                            .roundedFull()
                                                            .bg(rgba(0x2563ebff))
                                                    )
                                            )
                                    )
                                    .child(
                                        div().relative().h(px(32.0)).wFull().child(
                                            div()
                                                .absolute()
                                                .top1()
                                                .size(px(24.0))
                                                .roundedFull()
                                                .bg(rgba(0x3b82f6ff))
                                                .cursorPointer()
                                                .debugSelector(() -> 'spring-position')
                                                .withSpring(
                                                    'spring-position',
                                                    new SpringAnimation<Float>(spring)
                                                        .toValue(springPosition)
                                                        .withEpsilon(0.25),
                                                    (this_, left) -> this_.left(px(left))
                                                )
                                        )
                                    )
                                    .child(
                                        div().h(px(24.0)).roundedSm().withSpring(
                                            'spring-phase',
                                            new SpringAnimation<Float>(spring)
                                                .toPhase(new AnimationPhase(springPhase))
                                                .withEpsilon(0.001),
                                            (this_, phase:AnimationPhase) -> {
                                                var width:Float;
                                                var color:glaze.Rgba;
                                                if ((phase:Float) <= 1.0) {
                                                    width = phase.interpolateBetween(
                                                        0.0, 1.0,
                                                        px(48.0),
                                                        px(224.0)
                                                    );
                                                    color = phase.interpolateBetweenClamped(
                                                        0.0, 1.0,
                                                        rgba(0xf97316ff),
                                                        rgba(0x22c55eff)
                                                    );
                                                } else {
                                                    width = phase.interpolateBetween(
                                                        1.0, 2.0,
                                                        px(224.0),
                                                        px(96.0)
                                                    );
                                                    color = phase.interpolateBetweenClamped(
                                                        1.0, 2.0,
                                                        rgba(0x22c55eff),
                                                        rgba(0xa855f7ff)
                                                    );
                                                }
                                                return this_.w(px(width)).bg(color);
                                            }
                                        )
                                    )
                            )
                            .child(
                                svg()
                                    .size20()
                                    .overflowHidden()
                                    .path(ARROW_CIRCLE_SVG)
                                    .textColor(black())
                                    .withAnimation(
                                        'image_circle',
                                        new Animation(2.0)
                                            .repeat()
                                            .withEasing(bounce(easeInOut)),
                                        (svg:Svg, delta:Float) -> {
                                            return svg.withTransformation(Transformation.rotated(
                                                percentage(delta)
                                            ));
                                        }
                                    )
                            )
                    )
                    .child(
                        div()
                            .flex()
                            .h(px(64.))
                            .wFull()
                            .p2()
                            .justifyCenter()
                            .itemsCenter()
                            .borderT1()
                            .borderColor(black().opacity(0.1))
                            .bg(black().opacity(0.05))
                            .child('Other Panel')
                    )
            );
    }

    static function clamp(value:Float, min:Float, max:Float):Float {
        return value < min ? min : value > max ? max : value;
    }

    /**
     * Rust `{:.N}` of a float (round half to even on exact ties).
     */
    static function fixed(value:Float, digits:Int):String {
        final factor = Math.pow(10, digits);
        final scaled = Math.abs(value) * factor;
        var n = Math.floor(scaled);
        final frac = scaled - n;
        if (frac > 0.5 || (frac == 0.5 && n % 2 != 0)) n++;
        final negative = value < 0 && n != 0;
        final intPart = Std.string(Std.int(n / factor));
        var decimals = Std.string(Std.int(n % factor));
        while (decimals.length < digits) decimals = '0' + decimals;
        return (negative ? '-' : '') + intPart + (digits > 0 ? '.' + decimals : '');
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(_window:Window, cx:App):Entity<AnimationExample> {
        return cx.newEntity(_ -> new AnimationExample(0, 14.0, null));
    }

}
