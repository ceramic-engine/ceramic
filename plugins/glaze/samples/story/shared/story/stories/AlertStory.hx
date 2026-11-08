// Ported from gpui-kit 0.8.1: crates/story/src/stories/alert_story.rs
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
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.alert.Alert;
import glaze.kit.dock.PanelControl;
import glaze.kit.text.TextView;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

class AlertStory extends Model implements Story {

    var size:Size;

    var bannerVisible:Bool;

    final focusHandle:FocusHandle;

    function new(_:Window, cx:AppContext) {
        super();
        size = Medium;
        bannerVisible = true;
        focusHandle = cx.focusHandle();
    }

    public static function view(window:Window, cx:App):Entity<AlertStory> {
        return cx.newEntity((cx:Context<AlertStory>) -> new AlertStory(window, cx));
    }

    public static function title():String {
        return 'Alert';
    }

    public static function description():String {
        return "Communicate important status changes without interrupting the user's workflow.";
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<AlertStory> = cast cx;
        return vFlex()
            .gap4()
            .onAction(ChangeStorySize, self.listener((this_:AlertStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Title, icon, and rich text content.')
                .w2_3()
                .child(Alert.component('alert-default', TextView.markdownAt('Your workspace is ready for the team.\n'
                    + '- **12 members** have access\n'
                    + '- Billing remains with the workspace owner'))
                    .withSize(size)
                    .title('Workspace settings saved')))
            .child(section('Variants')
                .description('Info, success, warning, and error states.')
                .w2_3()
                .child(vFlex()
                    .wFull()
                    .gap3()
                    .child(Alert.info('info1', 'Maintenance starts Friday at 22:00 UTC.')
                        .withSize(size)
                        .title('Scheduled maintenance')
                        .onClose(self.listener((_, _, _, _) -> {
                            trace('Info alert closed');
                        })))
                    .child(Alert.success('success-1', 'The transfer is queued and usually settles within one business day.')
                        .withSize(size)
                        .title('Transfer submitted'))
                    .child(Alert.warning('warning-1', 'Two teammates still use recovery codes generated more than a year ago.\n'
                        + 'Ask them to generate a fresh set in Security settings.')
                        .withSize(size))
                    .child(Alert.error('error-1', TextView.markdownAt('Please verify your billing information and try again.\n'
                        + '- Check your card details\n'
                        + '- Ensure sufficient funds\n'
                        + '- Verify billing address'))
                        .withSize(size)
                        .title('Unable to process your payment.'))))
            .child(section('Banner')
                .description('Full-width and closable alerts.')
                .w2_3()
                .child(vFlex()
                    .wFull()
                    .gap2()
                    .child(Alert.component('banner-1', 'Reporting is read-only while the nightly ledger closes.')
                        .banner()
                        .onClose(self.listener((this_:AlertStory, _, _, cx) -> {
                            this_.bannerVisible = !this_.bannerVisible;
                            cx.notify();
                        }))
                        .visible(bannerVisible)
                        .withSize(size))
                    .child(Alert.info('banner-info', 'A new desktop update will install after you restart.')
                        .banner()
                        .withSize(size))
                    .child(Alert.success('banner-success', 'All 1,284 records finished importing.')
                        .banner()
                        .withSize(size))
                    .child(Alert.warning('banner-warning', 'Your API key expires in 6 days. Rotate it before August 19.')
                        .banner()
                        .withSize(size))
                    .child(Alert.error('banner-error', 'Live updates are disconnected. Changes may be delayed.')
                        .banner()
                        .withSize(size))))
            .child(section('Custom icon')
                .description('Custom icon and long content.')
                .w2_3()
                .child(Alert.component('other-1', 'The quarterly planning review overlaps with the APAC operations call. '
                    + 'Move one event or invite another owner before sending the agenda.')
                    .title('Two events overlap by 30 minutes')
                    .withSize(size)
                    .icon(IconName.Calendar)));
    }

}
