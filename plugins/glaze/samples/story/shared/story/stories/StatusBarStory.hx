// Ported from gpui-kit 0.8.1: crates/story/src/stories/status_bar_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.dock.PanelControl;
import gpui.component.progress.ProgressCircle;
import gpui.component.separator.Separator;
import gpui.component.statusbar.StatusBar;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

using gpui.component.WindowExt;

class StatusBarStory extends Model implements Story {

    public static function title():String {
        return 'StatusBar';
    }

    public static function description():String {
        return 'A horizontal bar with left/center/right regions, usually placed at the bottom.';
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<StatusBarStory> {
        return cx.newEntity((c:Context<StatusBarStory>) -> new StatusBarStory(window, c));
    }

    final focusHandle_:FocusHandle;

    function new(_:Window, cx:Context<StatusBarStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .child(section('Editor')
                .description('Places repository state on the left and document state on the right.')
                .maxW(px(760.))
                .child(vFlex().wFull().child(new StatusBar()
                    .left(new Button('branch')
                        .ghost()
                        .xsmall()
                        .icon(IconName.Github)
                        .label('main')
                        .tooltip('Git branch')
                        .onClick((_, window, cx) -> window.pushNotification('Switch branch', cx)))
                    .left(Separator.vertical().h3())
                    .left(hFlex()
                        .itemsCenter()
                        .gap2()
                        .child(hFlex()
                            .itemsCenter()
                            .gap1()
                            .child(new Icon(IconName.CircleCheck).xsmall().textColor(theme.green))
                            .child('0'))
                        .child(hFlex()
                            .itemsCenter()
                            .gap1()
                            .child(new Icon(IconName.Info).xsmall().textColor(theme.blue))
                            .child('2')))
                    .right(new Button('position')
                        .ghost()
                        .xsmall()
                        .label('Ln 12, Col 34')
                        .tooltip('Go to Line/Column')
                        .onClick((_, window, cx) -> window.pushNotification('Go to Line/Column', cx)))
                    .right(Separator.vertical().h3())
                    .right(new Button('encoding')
                        .ghost()
                        .xsmall()
                        .label('UTF-8')
                        .onClick((_, window, cx) -> window.pushNotification('Select encoding', cx)))
                    .right(new Button('language')
                        .ghost()
                        .xsmall()
                        .label('Rust')
                        .onClick((_, window, cx) -> window.pushNotification('Select language', cx))))))
            .child(section('Application')
                .description('Combines connectivity, progress, save state, and notifications.')
                .maxW(px(760.))
                .child(vFlex().wFull().child(new StatusBar()
                    .left(hFlex()
                        .itemsCenter()
                        .gap1()
                        .child(new Icon(IconName.Check).xsmall())
                        .child('Connected'))
                    .child(hFlex()
                        .itemsCenter()
                        .gap2()
                        .child(new ProgressCircle('syncing').value(45.))
                        .child('Syncing…'))
                    .right('All changes saved')
                    .right(new Button('notifications')
                        .ghost()
                        .xsmall()
                        .icon(IconName.Bell)
                        .label('3')
                        .tooltip('3 notifications')
                        .onClick((_, window, cx) -> window.pushNotification('3 notifications', cx))))))
            // Layout cases for verifying the dynamic centering behavior.
            .child(section('Alignment')
                .description('Center content adapts when either side is empty or populated.')
                .maxW(px(760.))
                .child(vFlex()
                    .wFull()
                    .gap6()
                    .child(new StatusBar().child('Center only → start-aligned'))
                    .child(new StatusBar().left('Left').child('Center → end (only left)'))
                    .child(new StatusBar().child('Center → start (only right)').right('Right'))
                    .child(new StatusBar().left('Left').child('Center → centered (left + right)').right('Right'))
                    .child(new StatusBar().left('Left').right('Right'))));
    }

}
