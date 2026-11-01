// Ported from gpui-kit 0.8.1: crates/story/src/stories/icon_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Window;
import gpui.component.Icon;
import gpui.component.Icon.IconView;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.dock.PanelControl;
import gpui.component.menu.PopupMenu;
import gpui.component.theme.Color;
import gpui.component.theme.Theme;
import story.Include;
import story.Story;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.menu.DropdownMenu;

class IconStory extends Model implements Story {

    static final SEARCH_SVG = Include.iconBytes('search.svg');
    static final ARROW_SVG = Include.iconBytes('arrow-up.svg');
    static final LOADER_SVG = Include.iconBytes('loader-circle.svg');

    /** Rust `impl From<Search> for Icon`. */
    static function search():Icon {
        return new Icon().data(SEARCH_SVG);
    }

    final focusHandle:FocusHandle;

    final arrow:Icon;

    final arrowView:Entity<IconView>;

    var message:String;

    function new(_:Window, cx:Context<IconStory>) {
        super();
        final arrow = new Icon()
            .data(ARROW_SVG)
            .rotate(Math.PI / 2)
            .large();
        focusHandle = cx.focusHandle();
        arrowView = arrow.clone().view(cx);
        this.arrow = arrow;
        message = 'Choose a button or menu item to try the icon slots.';
    }

    public static function view(window:Window, cx:App):Entity<IconStory> {
        return cx.newEntity((cx:Context<IconStory>) -> new IconStory(window, cx));
    }

    public static function title():String {
        return 'Icon';
    }

    public static function description():String {
        return 'SVG Icons based on Lucide.dev';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<IconStory> = cast cx;
        final theme = Theme.global(cx);
        final view:Entity<IconStory> = self.entity();
        return vFlex()
            .itemsCenter()
            .gap6()
            .child(section('SVG bytes')
                .description('Embedded icons share the same sizing, colors, and loading behavior.')
                .w(rems(30.))
                .child(vFlex()
                    .gap3()
                    .child(hFlex()
                        .gap4()
                        .child(new Icon().data(SEARCH_SVG).small())
                        .child(new Icon()
                            .data(SEARCH_SVG)
                            .large()
                            .textColor(theme.primary))
                        .child(new Button('embedded-search')
                            .icon(search())
                            .label('Search')
                            .onClick(self.listener((this_:IconStory, _, _, cx) -> {
                                this_.message = 'Search selected from the button.';
                                cx.notify();
                            })))
                        .child(new Button('embedded-loading')
                            .icon(search())
                            .loadingIcon(new Icon().data(LOADER_SVG))
                            .loading(true)
                            .label('Searching'))
                        .child(new Button('embedded-menu')
                            .label('Actions')
                            .dropdownMenu((menu, window, _) -> menu.item(PopupMenuItem.create('Search')
                                .icon(search())
                                // Rust `window.listener_for(&view, ...)`
                                .onClick((_, _, cx) -> view.update(cx, (this_, cx) -> {
                                    this_.message = 'Search selected from the menu.';
                                    cx.notify();
                                }))))))
                    .child(div()
                        .textSm()
                        .textColor(theme.mutedForeground)
                        .child(message))))
            .child(section('Cloning and views')
                .description('Both arrows retain their SVG bytes and 90° rotation.')
                .w(rems(30.))
                .child(hFlex().gap4().child('Clone').child(arrow.clone()))
                .child(hFlex()
                    .gap4()
                    .child('Entity')
                    .child(arrowView)))
            .child(section('Icons')
                .description('Common interface symbols from the bundled icon set.')
                .w(px(480.))
                .textLg()
                .child(new Icon(IconName.Info))
                .child(new Icon(IconName.Map))
                .child(new Icon(IconName.Bot))
                .child(new Icon(IconName.Github))
                .child(new Icon(IconName.Calendar))
                .child(new Icon(IconName.Globe))
                .child(new Icon(IconName.Heart)))
            .child(section('Color')
                .description('Icons inherit semantic foreground colors.')
                .w(px(480.))
                .child(new Icon(IconName.Maximize)
                    .size6()
                    .textColor(theme.green))
                .child(new Icon(IconName.Minimize)
                    .size6()
                    .textColor(theme.red)))
            .child(section('Icon Buttons')
                .description('Icons can be used as compact button content.')
                .w(px(480.))
                .child(hFlex()
                    .gap4()
                    .child(new Button('like1')
                        .icon(new Icon(IconName.Heart)
                            .textColor(Color.neutral500())
                            .size6())
                        .withVariant(Ghost))
                    .child(new Button('like2')
                        .icon(new Icon(IconName.HeartOff)
                            .textColor(theme.red)
                            .size6())
                        .withVariant(Ghost))
                    .child(new Button('like3')
                        .icon(new Icon(IconName.Heart)
                            .textColor(theme.green)
                            .size6())
                        .withVariant(Ghost))))
            .child(section('Custom Size')
                .description('Explicit dimensions support dense controls and counters.')
                .w(px(480.))
                .child(new Button('button-with-size')
                    .outline()
                    .size5()
                    .small()
                    .px0()
                    .label('10')));
    }

}
