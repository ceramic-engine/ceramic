// Ported from gpui-kit 0.8.1: crates/story/src/stories/breadcrumb_story.rs
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
import glaze.kit.breadcrumb.Breadcrumb;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

class BreadcrumbStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var clickedItem:Null<String>;

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
        clickedItem = null;
    }

    public static function view(window:Window, cx:App):Entity<BreadcrumbStory> {
        return cx.newEntity((cx:Context<BreadcrumbStory>) -> new BreadcrumbStory(window, cx));
    }

    public static function title():String {
        return 'Breadcrumb';
    }

    public static function description():String {
        return 'A breadcrumb navigation element that shows the current location in a hierarchy.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<BreadcrumbStory> = cast cx;
        final interactive = vFlex()
            .gap4()
            .itemsCenter()
            .child(Breadcrumb.component()
                .child('Home')
                .child(BreadcrumbItem.component('Documents').onClick(self.listener((this_:BreadcrumbStory, _, _, cx) -> {
                    this_.clickedItem = 'Documents';
                    cx.notify();
                })))
                .child(BreadcrumbItem.component('Projects').onClick(self.listener((this_:BreadcrumbStory, _, _, cx) -> {
                    this_.clickedItem = 'Projects';
                    cx.notify();
                })))
                .child(BreadcrumbItem.component('Current').onClick(self.listener((this_:BreadcrumbStory, _, _, cx) -> {
                    this_.clickedItem = 'Current';
                    cx.notify();
                }))));
        if (clickedItem != null) interactive.child('Selected: $clickedItem');

        return vFlex()
            .gap6()
            .child(section('Default')
                .description('Shows the current location in a hierarchy.')
                .w(px(480.))
                .child(Breadcrumb.component()
                    .child('Home')
                    .child('Documents')
                    .child('Projects')))
            .child(section('Interactive')
                .description('Earlier levels can respond to navigation clicks.')
                .w(px(480.))
                .child(interactive));
    }

}
