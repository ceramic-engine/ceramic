// Ported from gpui-kit 0.8.1: crates/base/examples/showcase (the avatar, link
// and progress pages: components/avatar.rs, components/link.rs,
// components/progress.rs, the page wrapper of `render_page` and the root
// container of `BaseShowcase::render` in mod.rs) and
// crates/base/examples/shared/palette.rs (`ExamplePalette`, `example_rgb`,
// `canvas`).
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic; only the pages whose
// components are ported, without the showcase shell (NavStack, navigation
// bar, TextSelectionLayer, theme activation), light palette. See NOTICE.md.
package examples.showcase;

import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Rgba;
import gpui.ScrollHandle;
import gpui.Window;
import gpui.base.Avatar;
import gpui.base.Avatar.AvatarFallback;
import gpui.base.Link;
import gpui.base.Progress;
import gpui.base.Progress.ProgressIndicator;
import gpui.base.Progress.ProgressTrack;

import gpui.Prelude.*;

/**
 * `palette.rs`: the colors of the examples, light or dark.
 */
@:structInit
class ExamplePalette {

    public final canvas:Int;
    public final surface:Int;
    public final elevated:Int;
    public final foreground:Int;
    public final mutedForeground:Int;
    public final subtleForeground:Int;
    public final border:Int;
    public final strongBorder:Int;
    public final hover:Int;
    public final selected:Int;
    public final accent:Int;
    public final accentForeground:Int;

    public static function forDark(dark:Bool):ExamplePalette {
        if (dark) {
            return {
                canvas: 0x0e0e0e,
                surface: 0x171717,
                elevated: 0x262626,
                foreground: 0xffffff,
                mutedForeground: 0xa3a3a3,
                subtleForeground: 0x737373,
                border: 0x404040,
                strongBorder: 0xd4d4d4,
                hover: 0x262626,
                selected: 0x303030,
                accent: 0xffffff,
                accentForeground: 0x171717,
            };
        } else {
            return {
                canvas: 0xffffff,
                surface: 0xffffff,
                elevated: 0xf5f5f5,
                foreground: 0x171717,
                mutedForeground: 0x525252,
                subtleForeground: 0x737373,
                border: 0xd4d4d4,
                strongBorder: 0x171717,
                hover: 0xf5f5f5,
                selected: 0xf0f0f0,
                accent: 0x171717,
                accentForeground: 0xffffff,
            };
        }
    }

    public function resolve(lightColor:Int):Int {
        return switch lightColor {
            case 0xffffff: surface;
            case 0x171717: foreground;
            case 0x262626: foreground;
            case 0x404040: strongBorder;
            case 0x525252: mutedForeground;
            case 0x737373: subtleForeground;
            case 0xa3a3a3: subtleForeground;
            case 0x71717a: mutedForeground;
            case 0xd4d4d4 | 0xd4d4d8 | 0xe5e5e5 | 0xe5e7eb: border;
            case 0xf0f0f0: selected;
            case 0xf4f4f5 | 0xf5f5f5: hover;
            case 0x007fff if (canvas == 0x0e0e0e): 0x79c0ff;
            case 0x036a07 if (canvas == 0x0e0e0e): 0x7ee787;
            case 0x0433ff if (canvas == 0x0e0e0e): 0x79c0ff;
            case 0xc5060b if (canvas == 0x0e0e0e): 0xff7b72;
            case 0x0000a2 | 0x6f42c1 if (canvas == 0x0e0e0e): 0xd2a8ff;
            case 0x333333 if (canvas == 0x0e0e0e): 0xc9d1d9;
            case color: color;
        }
    }

}

class BaseShowcase extends Model implements Render {

    public static inline var WIDTH:Float = 840.0;

    public static inline var HEIGHT:Float = 640.0;

    /**
     * The active palette (`ACTIVE`): light until a dark window activates it.
     */
    static final ACTIVE:ExamplePalette = ExamplePalette.forDark(false);

    public static function exampleRgb(color:Int):Rgba {
        return rgb(ACTIVE.resolve(color));
    }

    public static function exampleCanvas():Rgba {
        return rgb(ACTIVE.canvas);
    }

    // `component` is a member of ceramic.Entity
    final pageComponent:String;

    final scroll:ScrollHandle = new ScrollHandle();

    public function new(component:String) {
        super();
        this.pageComponent = component;
    }

/// components/avatar.rs

    public function avatar():IntoElement {
        return div().flex().itemsStart().gap2().children(
            [for (entry in [
                {initials: 'AM', background: 0xf5f5f5},
                {initials: 'JL', background: 0xe5e5e5},
                {initials: 'SK', background: 0xd4d4d4},
                {initials: '+3', background: 0xffffff},
            ]) {
                final initials = entry.initials;
                final background = entry.background;
                new Avatar()
                    .size(px(34.))
                    .overflowHidden()
                    .border1()
                    .borderColor(exampleRgb(0xa3a3a3))
                    .fallback(
                        new AvatarFallback()
                            .flex()
                            .size8()
                            .itemsCenter()
                            .justifyCenter()
                            .bg(exampleRgb(background))
                            .textXs()
                            .textColor(exampleRgb(0x262626))
                            .child(initials)
                    );
            }]
        );
    }

/// components/link.rs

    public function link():IntoElement {
        return div()
            .w56()
            .flex()
            .flexCol()
            .gap2()
            .textXs()
            .child('Navigation is application-owned')
            .child(
                new Link('example-link')
                    .href('/base/primitives/link')
                    .openWith((href, _, _, cx) -> cx.openUrl(href))
                    .h7()
                    .px3()
                    .py0()
                    .flex()
                    .itemsCenter()
                    .border1()
                    .borderColor(exampleRgb(0x171717))
                    .child('Open Link documentation  →')
            )
            .child(
                new Link('disabled-link')
                    .href('/disabled')
                    .disabled(true)
                    .h7()
                    .px3()
                    .py0()
                    .flex()
                    .itemsCenter()
                    .border1()
                    .borderColor(exampleRgb(0xd4d4d4))
                    .textColor(exampleRgb(0x737373))
                    .child('Disabled destination')
            );
    }

/// components/progress.rs

    public function progress():IntoElement {
        return div()
            .w64()
            .flex()
            .flexCol()
            .gap2()
            .textXs()
            .child(
                div()
                    .flex()
                    .justifyBetween()
                    .child('Uploading assets')
                    .child('68%')
            )
            .child(
                new Progress('example-progress').value(68.).child(
                    new ProgressTrack()
                        .wFull()
                        .h(px(7.))
                        .border1()
                        .borderColor(exampleRgb(0x171717))
                        .child(
                            new ProgressIndicator()
                                .w(px(177.))
                                .hFull()
                                .bg(exampleRgb(0x171717))
                        )
                )
            )
            .child(
                div()
                    .flex()
                    .justifyBetween()
                    .textSm()
                    .textColor(exampleRgb(0x737373))
                    .child('Optimizing bundle')
                    .child('32%')
            )
            .child(
                new Progress('example-progress-secondary')
                    .value(32.)
                    .child(
                        new ProgressTrack()
                            .wFull()
                            .h(px(6.))
                            .border1()
                            .borderColor(exampleRgb(0xa3a3a3))
                            .child(
                                new ProgressIndicator()
                                    .w(px(83.))
                                    .hFull()
                                    .bg(exampleRgb(0x737373))
                            )
                    )
            );
    }

/// mod.rs

    /**
     * `render_page`, for these three pages.
     */
    function renderPage(component:String, window:Window, cx:Context<BaseShowcase>):AnyElement {
        final content:IntoElement = switch component {
            case 'avatar': avatar();
            case 'link': link();
            case 'progress': progress();
            case _: div();
        };
        // Surfaces rather than parts: these take the whole viewport.
        final fillsViewport = component == 'dock';
        final isTextView = component == 'text-view';
        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .child(
                div()
                    .id('showcase-scroll')
                    .flex1()
                    .minH0()
                    .overflowYScroll()
                    .trackScroll(scroll)
                    .child(
                        div()
                            .minHFull()
                            .wFull()
                            .flex()
                            .when(!fillsViewport, this_ -> this_.itemsCenter().justifyCenter())
                            .p4()
                            .child(
                                div()
                                    .map(this_ -> switch [fillsViewport, isTextView] {
                                        case [true, _]: this_.flex1().sizeFull().minH(px(420.));
                                        case [false, true]: this_.flex1().wFull().maxW(px(720.));
                                        case [false, false]: this_.flexNone();
                                    })
                                    .child(content)
                            )
                    )
            )
            .intoAnyElement();
    }

    /**
     * `BaseShowcase::render`: the root container, with the page in place of
     * the NavStack.
     */
    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<BaseShowcase> = cast cx;
        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .bg(exampleCanvas())
            .textColor(exampleRgb(0x171717))
            .textXs()
            .fontFamily('.SystemUIFont')
            .child(
                div()
                    .flex1()
                    .minH0()
                    .overflowHidden()
                    .child(renderPage(pageComponent, window, cx))
            );
    }

    /**
     * `run`: `gpui_base::init`, then the window.
     */
    public static function setup(cx:App):Void {
        gpui.base.Base.init(cx);
    }

    public static function open(component:String):(Window, App) -> Entity<BaseShowcase> {
        return (_, cx) -> cx.newEntity(_ -> new BaseShowcase(component));
    }

}
