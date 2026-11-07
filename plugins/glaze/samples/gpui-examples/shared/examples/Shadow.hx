// Ported from gpui-pre 0.3.10: examples/shadow.rs (Shadow, example, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import glaze.App;
import glaze.BoxShadow;
import glaze.Context;
import glaze.Div;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

class Shadow extends Model implements Render {

    public static inline var WIDTH:Float = 1000.0;

    public static inline var HEIGHT:Float = 800.0;

    public function new() {
        super();
    }

    static function base():Div {
        return div()
            .size16()
            .bg(rgb(0xffffff))
            .roundedFull()
            .border1()
            .borderColor(hsla(0.0, 0.0, 0.0, 0.1));
    }

    static function square():Div {
        return div()
            .size16()
            .bg(rgb(0xffffff))
            .border1()
            .borderColor(hsla(0.0, 0.0, 0.0, 0.1));
    }

    static function roundedSmall():Div {
        return div()
            .size16()
            .bg(rgb(0xffffff))
            .rounded(px(4.))
            .border1()
            .borderColor(hsla(0.0, 0.0, 0.0, 0.1));
    }

    static function roundedMedium():Div {
        return div()
            .size16()
            .bg(rgb(0xffffff))
            .rounded(px(8.))
            .border1()
            .borderColor(hsla(0.0, 0.0, 0.0, 0.1));
    }

    static function roundedLarge():Div {
        return div()
            .size16()
            .bg(rgb(0xffffff))
            .rounded(px(12.))
            .border1()
            .borderColor(hsla(0.0, 0.0, 0.0, 0.1));
    }

    static function example(label:String, example:IntoElement):Div {
        return div()
            .flex()
            .flexCol()
            .justifyCenter()
            .itemsCenter()
            .w(relative(1. / 6.))
            .borderR1()
            .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
            .child(
                div()
                    .flex()
                    .itemsCenter()
                    .justifyCenter()
                    .flex1()
                    .py12()
                    .child(example)
            )
            .child(
                div()
                    .wFull()
                    .borderT1()
                    .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                    .p1()
                    .flex()
                    .itemsCenter()
                    .child(label)
            );
    }

    public function render(_window:Window, _cx:Context<Dynamic>):IntoElement {
        return div()
            .id('shadow-example')
            .overflowYScroll()
            .bg(rgb(0xffffff))
            .sizeFull()
            .textXs()
            .child(div().flex().flexCol().wFull().children([
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .flexRow()
                        .children([
                            example(
                                'Square',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded 4',
                                roundedSmall().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded 8',
                                roundedMedium().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded 16',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Circle',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                        ]),
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .wFull()
                        .children([
                            example('None', base()),
                            // 2Xsmall shadow
                            example('2X Small', base().shadow2xs()),
                            // Xsmall shadow
                            example('Extra Small', base().shadowXs()),
                            // Small shadow
                            example('Small', base().shadowSm()),
                            // Medium shadow
                            example('Medium', base().shadowMd()),
                            // Large shadow
                            example('Large', base().shadowLg()),
                            example('Extra Large', base().shadowXl()),
                            example('2X Large', base().shadow2xl()),
                        ]),
                    // Horizontal list of increasing blur radii
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Blur 0',
                                base().shadow([new BoxShadow(
                                    px(0.0),
                                    px(8.0),
                                    hsla(0.0, 0.0, 0.0, 0.3)
                                )])
                            ),
                            example(
                                'Blur 2',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(2.0)),
                                ])
                            ),
                            example(
                                'Blur 4',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(4.0)),
                                ])
                            ),
                            example(
                                'Blur 8',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Blur 16',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(16.0)),
                                ])
                            ),
                        ]),
                    // Horizontal list of increasing spread radii
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Spread 0',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Spread 2',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(2.0)),
                                ])
                            ),
                            example(
                                'Spread 4',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(4.0)),
                                ])
                            ),
                            example(
                                'Spread 8',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Spread 16',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(16.0)),
                                ])
                            ),
                        ]),
                    // Square spread examples
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Square Spread 0',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Square Spread 8',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Square Spread 16',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(16.0)),
                                ])
                            ),
                        ]),
                    // Rounded large spread examples
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Rounded Large Spread 0',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded Large Spread 8',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded Large Spread 16',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.3))
                                        .withBlurRadius(px(8.0))
                                        .withSpreadRadius(px(16.0)),
                                ])
                            ),
                        ]),
                    // Directional shadows
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Left',
                                base().shadow([
                                    new BoxShadow(px(-8.0), px(0.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Right',
                                base().shadow([
                                    new BoxShadow(px(8.0), px(0.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Top',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(-8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Bottom',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                        ]),
                    // Square directional shadows
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Square Left',
                                square().shadow([
                                    new BoxShadow(px(-8.0), px(0.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Square Right',
                                square().shadow([
                                    new BoxShadow(px(8.0), px(0.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Square Top',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(-8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Square Bottom',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                        ]),
                    // Rounded large directional shadows
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Rounded Large Left',
                                roundedLarge().shadow([
                                    new BoxShadow(px(-8.0), px(0.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded Large Right',
                                roundedLarge().shadow([
                                    new BoxShadow(px(8.0), px(0.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded Large Top',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(-8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                            example(
                                'Rounded Large Bottom',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.5, 0.5, 0.3))
                                        .withBlurRadius(px(8.0)),
                                ])
                            ),
                        ]),
                    // Multiple shadows for different shapes
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .children([
                            example(
                                'Circle Multiple',
                                base().shadow([
                                    new BoxShadow(
                                        px(0.0),
                                        px(-12.0),
                                        hsla(0.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(12.0),
                                        px(0.0),
                                        hsla(60.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(0.0),
                                        px(12.0),
                                        hsla(120.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(-12.0),
                                        px(0.0),
                                        hsla(240.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                ])
                            ),
                            example(
                                'Square Multiple',
                                square().shadow([
                                    new BoxShadow(
                                        px(0.0),
                                        px(-12.0),
                                        hsla(0.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(12.0),
                                        px(0.0),
                                        hsla(60.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(0.0),
                                        px(12.0),
                                        hsla(120.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(-12.0),
                                        px(0.0),
                                        hsla(240.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                ])
                            ),
                            example(
                                'Rounded Large Multiple',
                                roundedLarge().shadow([
                                    new BoxShadow(
                                        px(0.0),
                                        px(-12.0),
                                        hsla(0.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(12.0),
                                        px(0.0),
                                        hsla(60.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(0.0),
                                        px(12.0),
                                        hsla(120.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                    new BoxShadow(
                                        px(-12.0),
                                        px(0.0),
                                        hsla(240.0 / 360.0, 1.0, 0.5, 0.3)
                                    )
                                    .withBlurRadius(px(8.0))
                                    .withSpreadRadius(px(2.0)),
                                ])
                            ),
                        ]),
                    // Inset shadows (CSS `box-shadow: inset ...`).
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .wFull()
                        .children([
                            example(
                                'Inset basic',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(0.0), hsla(0.0, 0.0, 0.0, 0.5))
                                        .withBlurRadius(px(12.0))
                                        .withInset(),
                                ])
                            ),
                            example(
                                'Inset offset',
                                base().shadow([
                                    new BoxShadow(px(6.0), px(6.0), hsla(0.0, 0.0, 0.0, 0.5))
                                        .withBlurRadius(px(8.0))
                                        .withInset(),
                                ])
                            ),
                            example(
                                'Inset spread',
                                base().shadow([
                                    new BoxShadow(px(0.0), px(0.0), hsla(0.0, 0.0, 0.0, 0.5))
                                        .withBlurRadius(px(4.0))
                                        .withSpreadRadius(px(8.0))
                                        .withInset(),
                                ])
                            ),
                            example(
                                'Inset rounded',
                                roundedLarge().shadow([
                                    new BoxShadow(px(0.0), px(4.0), hsla(0.0, 0.0, 0.0, 0.5))
                                        .withBlurRadius(px(10.0))
                                        .withSpreadRadius(px(2.0))
                                        .withInset(),
                                ])
                            ),
                            example(
                                'Inset sharp',
                                square().shadow([
                                    new BoxShadow(px(0.0), px(0.0), hsla(0.0, 0.0, 0.0, 0.6))
                                        .withSpreadRadius(px(6.0))
                                        .withInset(),
                                ])
                            ),
                        ]),
                    // Combined: drop + inset shadows on the same element.
                    div()
                        .borderB1()
                        .borderColor(hsla(0.0, 0.0, 0.0, 1.0))
                        .flex()
                        .wFull()
                        .children([example(
                            'Drop + Inset',
                            roundedMedium().shadow([
                                new BoxShadow(px(0.0), px(8.0), hsla(0.0, 0.0, 0.0, 0.25))
                                    .withBlurRadius(px(12.0)),
                                new BoxShadow(px(0.0), px(2.0), hsla(0.0, 0.0, 0.0, 0.4))
                                    .withBlurRadius(px(4.0))
                                    .withInset(),
                            ])
                        )]),
                ]));
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(_window:Window, cx:App):Entity<Shadow> {
        return cx.newEntity(_ -> new Shadow());
    }

}
