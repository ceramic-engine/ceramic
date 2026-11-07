package;

import ceramic.Scene;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.SystemNotification;
import glaze.SystemNotificationAction;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Click zones of a GPUI window posting and dismissing system notifications
 * from their click handlers (a user gesture), and posts made from a timer
 * (no gesture). Every step is printed on the console as a `WEBNOTIF` line,
 * which `check.js` reads:
 *
 * - top left (0..320, 0..240): posts `a1` then `a2` (two posts in one click);
 * - top right (320..640, 0..240): posts `a1` again ("Replaced", with an
 *   action button);
 * - bottom (0..640, 240..480): dismisses `a2`;
 * - one second after start: posts `timer` outside of any gesture; the page
 *   can post `late` the same way later (`window.__postLate()`).
 *
 * Responses are printed as `response <tag> <action id>`.
 */
class MainScene extends Scene {

    override function create() {
        final cx = App.current;
        cx.setAppIdentity('com.example.webnotifications', 'Web notifications');
        cx.onSystemNotificationResponse((response, _) -> trace('WEBNOTIF response ${response.tag} ${response.actionId}'));

        final window = Window.open(cx, {width: width, height: height}, (window, cx) -> {
            return cx.newEntity((_:Context<ZonesView>) -> new ZonesView());
        });
        add(window.renderable);

        ceramic.Timer.delay(this, 1.0, () -> post(cx, new SystemNotification('timer', 'From a timer', 'No gesture')));
        js.Syntax.code("window.__postLate = {0}", () -> post(cx, new SystemNotification('late', 'Later', 'No gesture')));
        trace('WEBNOTIF ready');
    }

    public static function post(cx:App, notification:SystemNotification):Void {
        cx.showSystemNotification(notification);
        trace('WEBNOTIF posted ${notification.tag}');
    }

}

private class ZonesView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final app = cx.app;
        return div().sizeFull().flex().flexCol()
            .child(div().flex().flexRow().w(px(640)).h(px(240))
                .child(div().id('post').w(px(320)).h(px(240)).bg(rgb(0xddeeff)).onClick((_, _, _) -> {
                    MainScene.post(app, new SystemNotification('a1', 'Build finished', 'All tests passed'));
                    MainScene.post(app, new SystemNotification('a2', 'Second', ''));
                }))
                .child(div().id('replace').w(px(320)).h(px(240)).bg(rgb(0xffeedd)).onClick((_, _, _) -> {
                    MainScene.post(app, new SystemNotification('a1', 'Replaced', 'Same tag', [new SystemNotificationAction('open', 'Open')]));
                })))
            .child(div().id('dismiss').w(px(640)).h(px(240)).bg(rgb(0xeeffdd)).onClick((_, _, _) -> {
                app.dismissSystemNotification('a2');
                trace('WEBNOTIF dismissed a2');
            }));
    }

}
