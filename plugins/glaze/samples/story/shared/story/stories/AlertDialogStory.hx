// Ported from gpui-kit 0.8.1: crates/story/src/stories/alert_dialog_story.rs
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
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.dialog.AlertDialog;
import glaze.kit.dialog.DialogDescription;
import glaze.kit.dialog.DialogFooter;
import glaze.kit.dialog.DialogHeader;
import glaze.kit.dialog.DialogTitle;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.ParentElementTools;
using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

class AlertDialogStory extends Model implements Story {

    final focusHandle:FocusHandle;

    public static function title():String {
        return 'AlertDialog';
    }

    public static function description():String {
        return 'Require a response before the user can continue.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<AlertDialogStory> {
        return cx.newEntity((cx:Context<AlertDialogStory>) -> new AlertDialogStory(window, cx));
    }

    function new(_:Window, cx:AppContext) {
        super();
        focusHandle = cx.focusHandle();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<AlertDialogStory> = cast cx;
        final app:App = cx.app;
        return div().id('alert-dialog-story').trackFocus(focusHandle).sizeFull().child(vFlex()
            .gap6()
            .child(section('Default')
                .description('Compose the header, message, and footer actions.')
                .child(new AlertDialog(app)
                    .p0()
                    .trigger(new Button('info-alert').outline().label('Discard Draft'))
                    .onOk((_, window, cx) -> {
                        window.pushNotification('Draft discarded', cx);
                        return true;
                    })
                    .onCancel((_, window, cx) -> {
                        window.pushNotification('Continuing to edit', cx);
                        return true;
                    })
                    .content((content, _, cx) -> content
                        .child(new DialogHeader().p4().child(new DialogTitle().child('Discard unsaved changes?')).child(new DialogDescription()
                            .child('Your edits since the last save will be permanently lost.')))
                        .child(new DialogFooter()
                            .p4()
                            .borderT1()
                            .borderColor(Theme.global(cx).border)
                            .bg(Theme.global(cx).muted)
                            .child(new DialogClose().child(new Button('cancel').outline().label('Cancel')))
                            .child(new DialogAction().child(new Button('ok').label('Discard').danger()))))))
            .child(section('Imperative API').description('Open an alert directly from the window.').child(new Button('confirm-alert')
                .outline()
                .label('Delete File')
                .onClick(self.listener((_, _, window, cx) -> {
                    window.openAlertDialog(cx.app, (alert, _, cx) -> alert
                        .icon(new Icon(IconName.Info).textColor(Theme.global(cx).danger))
                        .title('Delete File')
                        .description('Are you sure you want to delete this file? This action cannot be undone.')
                        .confirm()
                        .okText('Delete')
                        .okVariant(Danger)
                        .onOk((_, window, cx) -> {
                            window.pushNotification('File deleted', cx);
                            return true;
                        }));
                }))))
            .child(section('Icon').description('Add a visual cue above the title.').child(new AlertDialog(app)
                .w(px(320.))
                .trigger(new Button('icon-alert').outline().label('Request Permission'))
                .onOk((_, window, cx) -> {
                    window.pushNotification('Thank you for allowing network access', cx);
                    return true;
                })
                .content((content, _, cx) -> content
                    .child(new DialogHeader()
                        .itemsCenter()
                        .child(new Icon(IconName.TriangleAlert).size10().textColor(Theme.global(cx).warning))
                        .child(new DialogTitle().child('Network Permission Required'))
                        .child(new DialogDescription().child('We need your permission to access the network to provide better services. '
                            + 'Please allow network access in your system settings.')))
                    .child(new DialogFooter()
                        .vFlex()
                        .child(new DialogAction().child(new Button('agree').wFull().primary().label('Allow')))
                        .child(new DialogClose().child(new Button('disagree').wFull().outline().label('Deny')))))))
            .child(section('Destructive')
                .description('Use a destructive action for irreversible choices.')
                .child(new AlertDialog(app)
                    .trigger(new Button('destructive-action').outline().danger().label('Delete Account'))
                    .onOk((_, window, cx) -> {
                        window.pushNotification('Your account has been deleted', cx);
                        return true;
                    })
                    .content((content, _, _) -> content
                        .child(new DialogHeader().child(new DialogTitle().child('Delete Account')).child(new DialogDescription()
                            .child('This will permanently delete your account and all associated data. This action cannot be undone.')))
                        .child(new DialogFooter()
                            .child(new DialogClose().child(new Button('cancel').flex1().outline().label('Cancel')))
                            .child(new DialogAction().child(new Button('delete')
                                .flex1()
                                .outline()
                                .danger()
                                .label('Delete')))))))
            .child(section('Without title').description('Render content without a heading.').child(new Button('without-title')
                .outline()
                .label('Continue without Title')
                .onClick(self.listener((_, _, window, cx) -> {
                    window.openAlertDialog(cx.app, (alert, _, _) -> alert
                        .confirm()
                        .child('Continue with this action?'));
                }))))
            .child(section('Custom footer').description('Replace the default action row.').child(new Button('session-timeout')
                .outline()
                .label('Show Session Expiry')
                .onClick(self.listener((_, _, window, cx) -> {
                    window.openAlertDialog(cx.app, (alert, _, _) -> alert
                        .onOk((_, window, cx) -> {
                            window.pushNotification('Redirecting to login...', cx);
                            return true;
                        })
                        .title('Session Expired')
                        .description('Your session has expired due to inactivity.Please log in again to continue.')
                        .footer(new DialogFooter().child(new Button('sign-in').label('Sign in').primary().flex1().onClick((_, window, cx) -> {
                            window.pushNotification('Redirecting to login...', cx);
                            window.closeDialog(cx);
                        }))));
                }))))
            .child(section('Custom content').description('Style header and footer regions independently.').child(new AlertDialog(app)
                .trigger(new Button('update').outline().label('Install Update'))
                .onCancel((_, window, cx) -> {
                    window.pushNotification('Update postponed', cx);
                    return true;
                })
                .onOk((_, window, cx) -> {
                    window.pushNotification('Starting update...', cx);
                    return true;
                })
                .content((content, _, cx) -> content
                    .child(new DialogHeader().child(new DialogTitle().child('Update Available')).child(new DialogDescription()
                        .child('A new version (v2.0.0) is available.This update includes new features and bug fixes.')))
                    .child(new DialogFooter()
                        .bg(Theme.global(cx).muted)
                        .child(new DialogClose().child(new Button('later').flex1().outline().label('Later')))
                        .child(new DialogAction().child(new Button('update-now').flex1().primary().label('Update')))))))
            .child(section('Keyboard').description('Disable keyboard dismissal when required.').child(new Button('keyboard-disabled')
                .outline()
                .label('Review Notice')
                .onClick(self.listener((_, _, window, cx) -> {
                    window.openAlertDialog(cx.app, (alert, _, _) -> alert
                        .title('Important Notice')
                        .description('Please read this important notice carefully before proceeding.')
                        .okText('Got It')
                        .keyboard(false));
                }))))
            .child(section('Confirm mode').description('Provide standard OK and Cancel actions.').child(new Button('overlay-closable')
                .outline()
                .label('Open Confirmation')
                .onClick(self.listener((_, _, window, cx) -> {
                    window.openAlertDialog(cx.app, (alert, _, _) -> alert
                        .confirm()
                        .title('Are you sure?')
                        .child('Continue with this action?'));
                }))))
            .child(section('Prevent close').description('Callbacks can keep the dialog open.').child(new Button('prevent-close')
                .outline()
                .label('Close During Sync')
                .onClick(self.listener((_, _, window, cx) -> {
                    window.openAlertDialog(cx.app, (alert, _, _) -> alert
                        .title('Sync in progress')
                        .closeButton(true)
                        .description('Your changes are still syncing. The dialog remains open until syncing finishes.')
                        .confirm()
                        .okText('Close')
                        .cancelText('Wait')
                        .onOk((_, window, cx) -> {
                            // Return false to prevent closing
                            window.pushNotification('Cannot close: Process still running', cx);
                            return false;
                        })
                        .onCancel((_, window, cx) -> {
                            window.pushNotification('Waiting...', cx);
                            return false;
                        }));
                })))));
    }

}
