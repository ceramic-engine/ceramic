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
 * popover, and a Ceramic quad receiving clicks. With the plugin `ui` (the
 * story app enables it), Ceramic views measured by the layout: an
 * `ImageView`, a column of Ceramic buttons next to Glaze text, and a
 * `TextView` wrapping in a column, with a button that lengthens its text.
 * Listed by the story app only (`Gallery.portStories`): gpui-kit has no
 * such page.
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

    #if plugin_ui
    static final SHORT_TEXT = 'A Ceramic TextView.';

    static final LONG_TEXT = 'A Ceramic TextView, measured by the Glaze layout: it wraps in the 300 pixels of its column, and the Glaze text below moves down.';

    final imageView:ceramic.ImageView;

    final imageTexture:ceramic.Texture;

    final ceramicButtons:ceramic.LinearLayout;

    final ceramicText:ceramic.TextView;

    /** The Ceramic button pressed last (read by `render`) */
    @observe var pressed:String = 'none';
    #end

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
        #if plugin_ui
        imageTexture = createImageTexture(96, 60);
        imageView = new ceramic.ImageView();
        imageView.setImageTexture(imageTexture);
        ceramicButtons = new ceramic.LinearLayout();
        ceramicButtons.direction = VERTICAL;
        ceramicButtons.itemSpacing = 6;
        for (name in ['Play', 'Options', 'Quit the game']) {
            ceramicButtons.add(createCeramicButton(name));
        }
        ceramicText = new ceramic.TextView();
        ceramicText.pointSize = 16;
        ceramicText.textColor = 0x2563EB;
        ceramicText.content = SHORT_TEXT;
        #end
    }

    #if plugin_ui
    /** A texture of diagonal stripes */
    function createImageTexture(width:Int, height:Int):ceramic.Texture {
        final pixels = new ceramic.UInt8Array(width * height * 4);
        for (y in 0...height) {
            for (x in 0...width) {
                final i = (y * width + x) * 4;
                final stripe = Std.int((x + y) / 12) % 2 == 0;
                pixels[i] = stripe ? 0x3B : 0xF5;
                pixels[i + 1] = stripe ? 0x82 : 0x9E;
                pixels[i + 2] = stripe ? 0xF6 : 0x0B;
                pixels[i + 3] = 0xFF;
            }
        }
        return ceramic.Texture.fromPixels(width, height, pixels);
    }

    /** A Ceramic button: a `TextView` with a background, as wide as its column */
    function createCeramicButton(name:String):ceramic.View {
        final view = new ceramic.TextView();
        view.content = name;
        view.pointSize = 16;
        view.align = CENTER;
        view.padding(8, 14);
        view.transparent = false;
        view.color = 0x2563EB;
        view.textColor = Color.WHITE;
        view.onPointerOver(owner, _ -> view.color = 0x1D4ED8);
        view.onPointerOut(owner, _ -> view.color = 0x2563EB);
        view.onPointerDown(owner, _ -> {
            view.color = 0x16A34A;
            pressed = name;
        });
        view.onPointerUp(owner, _ -> view.color = 0x1D4ED8);
        return view;
    }
    #end

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
        #if plugin_ui
        imageView.destroy();
        imageTexture.destroy();
        ceramicButtons.destroy();
        ceramicText.destroy();
        #end
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
        final page = vFlex().sizeFull().itemsCenter().gap4()
            .child(hFlex().gap4().itemsStart().child(animated).child(scrolling))
            .child(hFlex().gap4().itemsStart().child(popover).child(clickable));
        #if plugin_ui
        final long = ceramicText.content != SHORT_TEXT;
        final views = section('Measured Ceramic views')
            .description('An ImageView following its ratio, a LinearLayout as large as its buttons.')
            .w(px(440.))
            .child(hFlex().gap4().itemsCenter()
                .child(visual(imageView).w(px(120.)).rounded(px(6.)))
                .child(visual(ceramicButtons))
                .child(div().textSm().child('Glaze text. Pressed: $pressed')));
        final wrapping = section('Ceramic text in a column')
            .description('A TextView in a column of 300 pixels: natural width on one line, else wrapped.')
            .w(px(440.))
            .child(vFlex().gap2().itemsStart().w(px(300.))
                .p2()
                .rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border)
                .child(visual(ceramicText).interactive(false))
                .child(div().textSm().child('Glaze text below the Ceramic text.'))
                .child(Button.component('ceramic-visual-text-btn').outline().small()
                    .label(long ? 'Shorten the text' : 'Lengthen the text')
                    .onClick((_, _, cx) -> {
                        // Only the Ceramic view changes: its layout tells Glaze
                        ceramicText.content = long ? SHORT_TEXT : LONG_TEXT;
                    })));
        page.child(hFlex().gap4().itemsStart().child(views).child(wrapping));
        #end
        return page;
    }

}
