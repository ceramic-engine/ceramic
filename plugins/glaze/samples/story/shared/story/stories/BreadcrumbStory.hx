// Ported from gpui-kit 0.8.1: crates/story/src/stories/breadcrumb_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.AnyView;
import gpui.App;
import gpui.AppContext;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Window;
import gpui.component.breadcrumb.Breadcrumb;
import story.Story;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
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
            .child(new Breadcrumb()
                .child('Home')
                .child(new BreadcrumbItem('Documents').onClick(self.listener((this_:BreadcrumbStory, _, _, cx) -> {
                    this_.clickedItem = 'Documents';
                    cx.notify();
                })))
                .child(new BreadcrumbItem('Projects').onClick(self.listener((this_:BreadcrumbStory, _, _, cx) -> {
                    this_.clickedItem = 'Projects';
                    cx.notify();
                })))
                .child(new BreadcrumbItem('Current').onClick(self.listener((this_:BreadcrumbStory, _, _, cx) -> {
                    this_.clickedItem = 'Current';
                    cx.notify();
                }))));
        if (clickedItem != null) interactive.child('Selected: $clickedItem');

        return vFlex()
            .gap6()
            .child(section('Default')
                .description('Shows the current location in a hierarchy.')
                .w(px(480.))
                .child(new Breadcrumb()
                    .child('Home')
                    .child('Documents')
                    .child('Projects')))
            .child(section('Interactive')
                .description('Earlier levels can respond to navigation clicks.')
                .w(px(480.))
                .child(interactive));
    }

}
