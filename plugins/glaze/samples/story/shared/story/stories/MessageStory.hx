// Ported from gpui-kit 0.8.1: crates/story/src/stories/message_story.rs
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
import glaze.Axis;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.attachment.Attachment;
import glaze.kit.avatar.Avatar;
import glaze.kit.bubble.Bubble;
import glaze.kit.button.Button;
import glaze.kit.message.Message;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class MessageStory extends Model implements Story {

    public static function title():String {
        return 'Message';
    }

    public static function description():String {
        return 'Compose sender identity, metadata, rich content, and message actions.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<MessageStory> {
        return cx.newEntity((c:Context<MessageStory>) -> new MessageStory(window, c));
    }

    final focusHandle_:FocusHandle;

    function new(_:Window, cx:Context<MessageStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static function bubble(variant:Null<BubbleVariant>, text:String):Bubble {
        final b = Bubble.component();
        if (variant != null) b.withVariant(variant);
        return b.child(text);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .gap4()
            .child(section('Alignment')
                .description('The message owns alignment for all of its named slots.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(Message.component()
                    .avatarSlot(MessageAvatar.component().child(Avatar.component().name('Alice').size8()))
                    .header(MessageHeader.component().child('Alice').child('10:24 AM'))
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Secondary, 'Can you review this?')))
                    .footer(MessageFooter.component().child('Read')))
                .child(Message.component()
                    .alignment(MessageAlignment.End)
                    .avatar(Avatar.component().name('You').size8())
                    .header(MessageHeader.component().child('You').child('10:25 AM'))
                    .content(MessageContent.component().bubble(bubble(null, 'Sure \u2014 I will send notes shortly.')))
                    .footer(MessageFooter.component().child('Delivered'))))
            .child(section('Avatar')
                .description('Use sender avatars, initials, or an empty slot to preserve alignment.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(Message.component()
                    .avatar(Avatar.component()
                        .name('Alice Chen')
                        .src('https://avatars.githubusercontent.com/u/5518?s=64')
                        .size8())
                    .header(MessageHeader.component().child('Alice Chen'))
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Secondary, 'The sender image falls back to initials when unavailable.'))))
                .child(Message.component()
                    .avatar(Avatar.component().name('Jordan Park').size8())
                    .header(MessageHeader.component().child('Jordan Park'))
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Muted, 'Initials remain available without an image.'))))
                .child(Message.component()
                    .avatarSlot(MessageAvatar.component().bg(theme.transparent))
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Secondary, 'An empty avatar slot keeps grouped responses aligned.')))))
            .child(section('Header and footer')
                .description('Compose sender metadata, timestamps, and delivery status explicitly.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(Message.component()
                    .avatar(Avatar.component().name('Support team').size8())
                    .header(MessageHeader.component()
                        .child(div().textColor(theme.foreground).child('Support'))
                        .child('·')
                        .child('10:42 AM'))
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Secondary, 'Your issue has been assigned to the team.')))
                    .footer(MessageFooter.component().child('Read by 3 people')))
                .child(Message.component()
                    .alignment(MessageAlignment.End)
                    .header(MessageHeader.component().contentInset(false).child('You · Just now'))
                    .content(MessageContent.component().bubble(bubble(null, 'Thank you for the quick update.')))
                    .footer(MessageFooter.component().contentInset(false).child('Delivered'))))
            .child(section('Actions')
                .description('Keep copy, feedback, and retry actions keyboard-accessible.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(Message.component()
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Muted, 'The install failure is coming from the workspace package.')))
                    .footer(MessageFooter.component()
                        .gap2()
                        .child(Button.component('message-copy').ghost().xsmall().icon(IconName.Copy).tooltip('Copy message'))
                        .child(Button.component('message-like').ghost().xsmall().icon(IconName.Heart).tooltip('Like message'))
                        .child(Button.component('message-save').ghost().xsmall().icon(IconName.Star).tooltip('Save message'))))
                .child(Message.component()
                    .alignment(MessageAlignment.End)
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Destructive, 'The response could not be sent.')))
                    .footer(MessageFooter.component()
                        .gap2()
                        .child(div().textColor(theme.danger).child('Failed to send'))
                        .child(Button.component('message-retry').ghost().xsmall().label('Retry')))))
            .child(section('Attachment')
                .description('Mix image previews, file attachments, and text within one message.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(Message.component()
                    .alignment(MessageAlignment.End)
                    .content(MessageContent.component()
                        .child(Attachment.component()
                            .axis(Axis.Vertical)
                            .media(AttachmentMedia.component().src('https://pub.lbkrs.com/files/202503/vEnnmgUM6bo362ya/sdk.svg')))
                        .bubble(bubble(null, 'Can you use this image on the cover?'))))
                .child(Message.component()
                    .avatar(Avatar.component().name('Alice').size8())
                    .content(MessageContent.component()
                        .bubble(bubble(BubbleVariant.Secondary, 'Done. Here is the updated report.'))
                        .child(Attachment.component()
                            .media(AttachmentMedia.component().child(Icon.component(IconName.FileText)))
                            .content(AttachmentContent.component()
                                .title(AttachmentTitle.component('sales-dashboard.pdf'))
                                .description(AttachmentDescription.component('PDF · 2.4 MB')))
                            .actions(AttachmentActions.component().child(Button.component('message-open-attachment').ghost().small().label('Open')))))))
            .child(section('Multiple bubbles')
                .description('A message can hold multiple surfaces, reactions, and long-form text.')
                .maxW(rems(42.5))
                .child(Message.component()
                    .avatar(Avatar.component().name('Assistant').size8())
                    .header(MessageHeader.component().child('Assistant').child('Just now'))
                    .content(MessageContent.component()
                        .gap4()
                        .bubble(bubble(BubbleVariant.Secondary, 'I reviewed the upload and message rendering paths.'))
                        .bubble(bubble(BubbleVariant.Muted, "Keep lifecycle state on the attachment, preserve the sender's alignment, and expose every action as an existing semantic Button.")
                            .reactions(BubbleReactions.component().action(Button.component('message-bubble-like')
                                .ghost()
                                .xsmall()
                                .label('👍 2')
                                .tooltip('Like this response')))))
                    .footer(MessageFooter.component().child('Response complete'))))
            .child(section('Group')
                .description('Group consecutive messages while keeping each row composable.')
                .maxW(rems(42.5))
                .vFlex()
                .child(MessageGroup.component()
                    .wFull()
                    .child(Message.component()
                        .avatar(Avatar.component().name('Alice').size8())
                        .header(MessageHeader.component().child('Alice'))
                        .content(MessageContent.component().bubble(bubble(BubbleVariant.Secondary, 'I attached the draft.'))))
                    .child(Message.component()
                        .avatarSlot(MessageAvatar.component().bg(theme.transparent))
                        .content(MessageContent.component().bubble(bubble(BubbleVariant.Secondary, 'The second page needs attention.'))))))
            .child(section('Custom style')
                .description('Every structural part accepts GPUI style refinements.')
                .maxW(rems(42.5))
                .child(Message.component()
                    .p3()
                    .rounded(theme.radiusLg)
                    .bg(theme.muted.opacity(0.35))
                    .header(MessageHeader.component().px0().child('System'))
                    .content(MessageContent.component().child('The conversation has been archived.'))
                    .footer(MessageFooter.component().px0().child('Just now'))))
            .child(section('Ghost surface')
                .description('Typed ghost bubbles automatically remove metadata insets.')
                .maxW(rems(42.5))
                .child(Message.component()
                    .withStackStyle(new StyleBuilder(new StyleRefinement()).gap3().style())
                    .header(MessageHeader.component().child('System').child('Just now'))
                    .content(MessageContent.component().bubble(bubble(BubbleVariant.Ghost, 'The conversation has been archived.')))
                    .footer(MessageFooter.component().child('No further action required'))));
    }

}
