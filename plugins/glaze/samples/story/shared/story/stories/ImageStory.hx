// Ported from gpui-kit 0.8.1: crates/story/src/stories/image_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.dock.PanelControl;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

class ImageStory extends Model implements Story {

    final focusHandle:FocusHandle;

    public static function title():String {
        return 'Image';
    }

    public static function description():String {
        return 'Image and SVG image supported.';
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
    }

    public static function view(window:Window, cx:App):Entity<ImageStory> {
        return cx.newEntity((cx:Context<ImageStory>) -> new ImageStory(window, cx));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx);
        return vFlex().sizeFull().itemsCenter().gap6().child(section('Remote SVG')
            .description('Loads and renders an SVG from a remote URL.')
            .w(px(480.))
            .child(div()
                .wFull()
                .h(px(180.))
                .flex()
                .itemsCenter()
                .justifyCenter()
                .rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border)
                .child(img('https://pub.lbkrs.com/files/202503/vEnnmgUM6bo362ya/sdk.svg').h24())));
    }

}
