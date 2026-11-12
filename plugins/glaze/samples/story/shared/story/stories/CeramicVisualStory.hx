// New code for the Haxe port (no gpui-kit origin): Ceramic visuals shown as
// Glaze elements (`visual()`). See NOTICE.md.
package story.stories;

import ceramic.Color;
import ceramic.Quad;
import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.ObjectFit;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.dock.PanelControl;
import glaze.kit.popover.Popover;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

/**
 * Ceramic visuals in a Glaze hierarchy (`visual()`, specific to the Haxe
 * port): an animated visual in a panel, inside a scroll area, under a
 * popover, and a Ceramic quad receiving clicks. Listed by the story app
 * only (`Gallery.portStories`): gpui-kit has no such page.
 */
class CeramicVisualStory extends Model implements Story {

    final focusHandle:FocusHandle;

    /** Owns the animation callbacks */
    final owner:ceramic.Entity = new ceramic.Entity();

    final spinner:ceramic.Visual;

    final scrolled:ceramic.Visual;

    final covered:ceramic.Visual;

    final button:Quad;

    /** Clicks received by the Ceramic quad (read by `render`) */
    @observe var clicks:Int = 0;

    public static function title():String {
        return 'Ceramic Visual';
    }

    public static function description():String {
        return 'Ceramic visuals shown as Glaze elements, rendered into a texture and drawn in order.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function zoomable():Null<PanelControl> {
        return Toolbar;
    }

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
        spinner = createSpinner(0x3B82F6, 0xF59E0B);
        scrolled = createSpinner(0x10B981, 0xEF4444);
        covered = createSpinner(0x8B5CF6, 0x06B6D4);
        button = new Quad();
        button.size(160, 48);
        button.color = 0x2563EB;
        button.onPointerOver(owner, _ -> button.color = 0x1D4ED8);
        button.onPointerOut(owner, _ -> button.color = 0x2563EB);
        button.onPointerDown(owner, _ -> {
            button.color = 0x16A34A;
            clicks++;
        });
        button.onPointerUp(owner, _ -> button.color = 0x1D4ED8);
    }

    /** A square of rotating bars, animated at every frame */
    function createSpinner(first:Color, second:Color):ceramic.Visual {
        final root = new ceramic.Visual();
        root.size(160, 160);
        final wheel = new ceramic.Visual();
        wheel.size(160, 160);
        wheel.anchor(0.5, 0.5);
        wheel.pos(80, 80);
        root.add(wheel);
        final count = 12;
        for (i in 0...count) {
            final bar = new Quad();
            bar.size(10, 44);
            bar.anchor(0.5, 1.4);
            bar.pos(80, 80);
            bar.rotation = i * 360 / count;
            bar.color = Color.interpolate(first, second, i / (count - 1));
            bar.alpha = 0.35 + 0.65 * i / (count - 1);
            wheel.add(bar);
        }
        final dot = new Quad();
        dot.size(28, 28);
        dot.anchor(0.5, 0.5);
        dot.pos(80, 80);
        dot.color = second;
        root.add(dot);
        var time = 0.0;
        ceramic.App.app.onUpdate(owner, delta -> {
            time += delta;
            wheel.rotation = (time * 120) % 360;
            final pulse = 1 + 0.25 * Math.sin(time * 4);
            dot.scale(pulse, pulse);
        });
        return root;
    }

    public static function view(window:Window, cx:App):Entity<CeramicVisualStory> {
        return cx.newEntity((cx:Context<CeramicVisualStory>) -> new CeramicVisualStory(window, cx));
    }

    override function destroy() {
        owner.destroy();
        spinner.destroy();
        scrolled.destroy();
        covered.destroy();
        button.destroy();
        super.destroy();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx);
        final panel = () -> div()
            .flex()
            .itemsCenter()
            .justifyCenter()
            .rounded(theme.radiusLg)
            .border1()
            .borderColor(theme.border)
            .bg(theme.secondary);
        final animated = section('Animated visual')
            .description('Animated at every frame, sized by the layout: only its rectangle is drawn again.')
            .w(px(440.))
            .child(panel().w(px(240.)).h(px(170.)).child(
                visual(spinner).sizeFull().fit(ObjectFit.Contain).rounded(theme.radiusLg)
            ));
        final scrolling = section('Inside a scroll area')
            .description('Clipped by the scrolling container, moved with its content.')
            .w(px(440.))
            .child(div()
                .id('ceramic-visual-scroll')
                .w(px(300.))
                .h(px(170.))
                .overflowYScroll()
                .rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border)
                .child(vFlex().p3().gap1()
                    .children([for (i in 0...3) div().textSm().child('Row ${i + 1} above the visual')])
                    .child(panel().h(px(130.)).child(visual(scrolled).w(px(110.)).h(px(110.)).fit(ObjectFit.Contain)))
                    .children([for (i in 0...6) div().textSm().child('Row ${i + 1} below the visual')])));
        final popover = section('Under a popover')
            .description('Glaze popovers, menus and dialogs are drawn over it, and get the mouse.')
            .w(px(440.))
            .child(vFlex().gap2().itemsStart()
                .child(Popover.component('ceramic-visual-popover')
                    .defaultOpen(true)
                    .trigger(Button.component('ceramic-visual-popover-btn').outline().label('Popover'))
                    .w(px(220.))
                    .textSm()
                    .child('This popover is drawn over the Ceramic visual.'))
                .child(panel().w(px(240.)).h(px(130.)).child(visual(covered).sizeFull().fit(ObjectFit.Contain))));
        final clickable = section('Clickable Ceramic quad')
            .description('Ceramic pointer events reach it where it is the topmost element.')
            .w(px(440.))
            .child(hFlex().gap4().itemsCenter()
                .child(visual(button).trackFocus(focusHandle).rounded(px(8.)))
                .child(div().textSm().child('Clicks: $clicks')));
        return vFlex().sizeFull().itemsCenter().gap4()
            .child(hFlex().gap4().itemsStart().child(animated).child(scrolling))
            .child(hFlex().gap4().itemsStart().child(popover).child(clickable));
    }

}
