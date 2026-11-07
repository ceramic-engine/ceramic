// Ported from gpui-kit 0.8.1: crates/story/src/stories/notification_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.Anchor;
import glaze.kit.button.Button;
import glaze.kit.menu.PopupMenu;
import glaze.kit.notification.Notification;
import glaze.kit.text.TextView;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

/** Marker types of the notification ids (Rust local `struct X;`). */
private class TestNotification {}

private class ClickCloseNotification {}

private class SystemNotificationKind {}

private class ManualOpenNotification {}

class NotificationStory extends Model implements Story {

    static final NOTIFICATION_MARKDOWN = '\nThis is a custom notification.\n- List item 1\n- List item 2\n- [Click here](https://github.com/longbridge/gpui-kit)\n';

    static final ANCHORS:Array<Anchor> = [
        Anchor.TopLeft,
        Anchor.TopCenter,
        Anchor.TopRight,
        Anchor.LeftCenter,
        Anchor.RightCenter,
        Anchor.BottomLeft,
        Anchor.BottomCenter,
        Anchor.BottomRight,
    ];

    public static function title():String {
        return 'Notification';
    }

    public static function description():String {
        return 'Show transient feedback without interrupting the current task.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<NotificationStory> {
        return cx.newEntity((c:Context<NotificationStory>) -> new NotificationStory(window, c));
    }

    final focusHandle_:FocusHandle;

    function new(_:Window, cx:Context<NotificationStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .id('notification-story')
            .trackFocus(focusHandle_)
            .sizeFull()
            .gap3()
            .child(storyToolbarGroup()
                .dropdownChild(new Button('placement').label('Placement: ${theme.notification.placement.toString()}'), (menu:PopupMenu, _, cx) -> {
                    for (placement in ANCHORS) {
                        menu = menu.item(PopupMenuItem.create(placement.toString())
                            .checked(Theme.global(cx.app).notification.placement == placement)
                            .onClick((_, _, cx) -> Theme.update(cx, theme -> theme.notification.placement = placement)));
                    }
                    return menu;
                })
                .dropdownChild(new Button('max-items').label('Max items: ${theme.notification.maxItems}'), (menu:PopupMenu, _, cx) -> {
                    for (maxItems in [1, 2, 3, 5, 10]) {
                        menu = menu.item(PopupMenuItem.create('$maxItems')
                            .checked(Theme.global(cx.app).notification.maxItems == maxItems)
                            .onClick((_, _, cx) -> Theme.update(cx, theme -> theme.notification.maxItems = maxItems)));
                    }
                    return menu;
                }))
            .child(section('Default')
                .description('Show a short message.')
                .child(new Button('show-notify-0')
                    .outline()
                    .label('Show Notification')
                    .onClick((_, window, cx) -> window.pushNotification('This is a notification.', cx))))
            .child(section('Types')
                .description('Use semantic treatments for common outcomes.')
                .child(new Button('show-notify-info')
                    .info()
                    .label('Info')
                    .onClick((_, window, cx) -> window.pushNotification({type: Info, message: 'You have been saved file successfully.'}, cx)))
                .child(new Button('show-notify-success')
                    .success()
                    .label('Success')
                    .onClick((_, window, cx) -> window.pushNotification({type: Success, message: 'We have received your payment successfully.'}, cx)))
                .child(new Button('show-notify-warning')
                    .warning()
                    .label('Warning')
                    .onClick((_, window, cx) -> window.pushNotification({type: Warning, message: 'The network is not stable, please check your connection.'}, cx)))
                .child(new Button('show-notify-error')
                    .danger()
                    .label('Error')
                    .onClick((_, window, cx) -> window.pushNotification({type: Error, message: 'There have some error occurred. Please try again later.'}, cx))))
            .child(section('Title and description')
                .description('Pair a concise title with supporting detail.')
                .child(new Button('show-typed-info')
                    .info()
                    .label('Info')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.info('Your changes have been saved to the cloud and will sync across all of your devices.')
                        .title('All changes saved'), cx)))
                .child(new Button('show-typed-success')
                    .success()
                    .label('Success')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.success('Your payment of $$99.00 was processed and a receipt has been emailed to you.')
                        .title('Payment received'), cx)))
                .child(new Button('show-typed-warning')
                    .warning()
                    .label('Warning')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.warning('Your network connection is unstable. Some changes may take longer to save.')
                        .title('Connection unstable'), cx)))
                .child(new Button('show-typed-error')
                    .danger()
                    .label('Error')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.error("We couldn't reach the server. Check your internet connection and try again.")
                        .title('Request failed'), cx))))
            .child(section('Unique')
                .description('Replace duplicate notifications by type.')
                .child(new Button('show-notify-unique')
                    .outline()
                    .label('Unique Notification')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.info('This is a unique notification.')
                        .withId(NotificationStory)
                        .message('This is a unique notification.')
                        .onClose((_, _) -> trace('Notification closed')), cx))))
            .child(section('Keyed')
                .description('Keep separate unique notifications with keys.')
                .child(hFlex()
                    .gap3()
                    .child(new Button('show-notify-unique-key0')
                        .outline()
                        .label('A Notification')
                        .onClick((_, window, cx) -> window.pushNotification(Notification.info('This is A unique notification.').id1(NotificationStory, 1), cx)))
                    .child(new Button('show-notify-unique-key1')
                        .outline()
                        .label('B Notification')
                        .onClick((_, window, cx) -> window.pushNotification(Notification.info('This is B unique notification.').id1(NotificationStory, 2), cx)))))
            .child(section('Action')
                .description('Add an inline action to the notification.')
                .child(new Button('show-notify-with-title')
                    .outline()
                    .label('Notification with Title')
                    .onClick((_, window, cx) -> window.pushNotification(new Notification()
                        .withId(TestNotification)
                        .title('Uh oh! Something went wrong.')
                        .message('There was a problem with your request.')
                        .action((_, _, cx) -> new Button('try-again')
                            .primary()
                            .label('Retry')
                            .onClick(cx.listener((this_:Notification, _, window, cx) -> {
                                trace('You have clicked the try again action.');
                                this_.dismiss(window, cx);
                            })))
                        .onClick((_, _, _) -> trace('Notification clicked')), cx))))
            .child(section('Lifecycle')
                .description('Handle body clicks and close events independently.')
                .child(new Button('show-notify-click-close')
                    .outline()
                    .label('Click vs Close')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.info('Click the body to fire on_click; click the X to close. Watch the console.')
                        .withId(ClickCloseNotification)
                        .title('on_click vs on_close')
                        .autohide(false)
                        .onClick((_, _, _) -> trace('[notification] on_click fired'))
                        .onClose((_, _) -> trace('[notification] on_close fired')), cx))))
            .child(section('Placement per notification')
                .description('Override the global placement for a single notification.')
                .children([for (placement in ANCHORS) (new Button('show-notify-${placement.toString()}')
                    .outline()
                    .label(placement.toString())
                    .onClick((_, window, cx) -> window.pushNotification(Notification.info('This notification is at ${placement.toString()}.')
                        .placement(placement), cx)) : IntoElement)]))
            .child(section('System notification')
                .description('Deliver to the OS notification center; click the system notification to refocus the app. macOS shows them only when running from a bundled .app; Windows requires cx.set_app_identity().')
                .child(new Button('show-notify-system')
                    .outline()
                    .label('System only')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.info('Delivered straight to the notification center.')
                        .withId(SystemNotificationKind)
                        .title('Build finished')
                        .system()
                        .onClick((_, _, _) -> trace('[notification] system notification clicked')), cx)))
                .child(new Button('show-notify-in-app-and-system')
                    .outline()
                    .label('In-app and system')
                    .onClick((_, window, cx) -> window.pushNotification(Notification.info('Shown as a toast and in the notification center.')
                        .withId(SystemNotificationKind)
                        .title('Build finished')
                        .inAppAndSystem()
                        .autohide(false)
                        .onClick((_, _, _) -> trace('[notification] system notification clicked')), cx))))
            .child(section('Custom content')
                .description('Render application-owned notification content.')
                .child(new Button('show-notify-custom')
                    .outline()
                    .label('Show Custom Notification')
                    .onClick((_, window, cx) -> window.pushNotification(new Notification()
                        .content((_, _, _) -> (TextView.markdownAt(NOTIFICATION_MARKDOWN) : IntoElement).intoAnyElement()), cx))))
            .child(section('Manual close')
                .description('Keep a notification visible until it is dismissed.')
                .child(new Button('manual-open-notify')
                    .outline()
                    .label('Show')
                    .onClick((_, window, cx) -> window.pushNotification(new Notification()
                        .withId(ManualOpenNotification)
                        .message('You can close this notification by clicking the Close button.')
                        .autohide(false), cx)))
                .child(new Button('manual-close-notify')
                    .outline()
                    .label('Dismiss All')
                    .onClick((_, window, cx) -> window.removeNotification(ManualOpenNotification, cx))));
    }

}
