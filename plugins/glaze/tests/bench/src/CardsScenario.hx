package;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;

import glaze.Prelude.*;

/**
 * The original view caching benchmark (step 13 of the plan): 70 cards with
 * text, icons, borders and shadows (about 2000 elements, one view per card
 * and per badge), where one observable field changes per frame.
 */
class CardsScenario extends BaseScenario {

    public static inline final CARD_COUNT = 70;

    static final ICON = haxe.io.Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="black" stroke-width="2"/><path d="M8 12 L11 15 L16 9" fill="none" stroke="black" stroke-width="2"/></svg>');

    var app:App;

    var cards:Array<glaze.Entity<BenchCard>> = [];

    public function new() {
        super('cards');
    }

    override function setup(app:App, caching:Bool):Window {
        this.app = app;
        if (cards.length == 0) {
            for (i in 0...CARD_COUNT) {
                cards.push(app.newEntity(_ -> new BenchCard('Card $i')));
            }
        }
        return BenchRunner.openWindow(app, caching, buildRoot);
    }

    override function step(frame:Int):Void {
        final card = cards[frame % cards.length].read(app);
        card.value = card.value + 1;
    }

    public function buildRoot():AnyView {
        final cardViews = [for (card in cards) {
            final badge = app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> {
                final value = card.read(cx).value % 10;
                return div().px1().roundedFull().bg(hsla(value / 10, 0.6, 0.5, 1)).textXs().child('$value');
            }));
            app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> renderCard(card, badge, cx.app)));
        }];
        return app.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
            div().id('root').sizeFull().flex().flexWrap().gap2().p2().bg(hsla(0.6, 0.1, 0.96, 1))
                .children([for (view in cardViews) (view : AnyView)])
        ));
    }

    function renderCard(card:glaze.Entity<BenchCard>, badge:glaze.Entity<BenchView>, cx:App):IntoElement {
        final model = card.read(cx);
        final value = model.value;
        return div().id('card').w(px(150)).h(px(118)).flex().flexCol().gap1().p2()
            .bg(white()).border1().borderColor(hsla(0.6, 0.2, 0.8, 1)).roundedMd().shadowSm()
            .hover(s -> s.borderColor(hsla(0.6, 0.6, 0.5, 1)))
            .child(div().flex().gap1().itemsCenter()
                .child(svg().path('bench/icon.svg').data(ICON).size(px(12)).textColor(hsla(0.6, 0.6, 0.4, 1)))
                .child(div().textSm().child(model.title))
                .child((badge : AnyView)))
            .child(div().textXs().textColor(hsla(0, 0, 0.3, 1)).child('Value $value'))
            .child(div().h(px(4)).w(px(130)).bg(hsla(0, 0, 0.9, 1)).roundedFull()
                .child(div().h(px(4)).w(px(10 + (value * 7) % 120)).bg(hsla(0.6, 0.7, 0.5, 1)).roundedFull()))
            .child(div().textXs().textColor(hsla(0, 0, 0.5, 1)).child('Updated every 70 frames'))
            .child(div().flex().gap2().children([for (j in 0...3)
                div().flex().gap1().itemsCenter()
                    .child(svg().path('bench/icon.svg').data(ICON).size(px(10)).textColor(hsla(j / 3, 0.5, 0.5, 1)))
                    .child(div().textXs().child('${j * 10 + 1}'))
            ]));
    }

}

class BenchCard extends Model {

    @observe public var value:Int = 0;

    @observe public var title:String;

    public function new(title:String) {
        super();
        this.title = title;
    }

}
