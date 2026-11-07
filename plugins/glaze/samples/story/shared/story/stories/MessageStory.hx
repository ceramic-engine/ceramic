// Ported from gpui-kit 0.8.1: crates/story/src/stories/message_story.rs
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
import gpui.Axis;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.attachment.Attachment;
import gpui.component.avatar.Avatar;
import gpui.component.bubble.Bubble;
import gpui.component.button.Button;
import gpui.component.message.Message;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class MessageStory extends Model implements Story {

    public static function title():String {
        return 'Message';
    }

    public static function description():String {
        return 'Compose sender identity, metadata, rich content, and message actions.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
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
        final b = new Bubble();
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
                .child(new Message()
                    .avatarSlot(new MessageAvatar().child(new Avatar().name('Alice').size8()))
                    .header(new MessageHeader().child('Alice').child('10:24 AM'))
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Secondary, 'Can you review this?')))
                    .footer(new MessageFooter().child('Read')))
                .child(new Message()
                    .alignment(MessageAlignment.End)
                    .avatar(new Avatar().name('You').size8())
                    .header(new MessageHeader().child('You').child('10:25 AM'))
                    .content(new MessageContent().bubble(bubble(null, 'Sure \u2014 I will send notes shortly.')))
                    .footer(new MessageFooter().child('Delivered'))))
            .child(section('Avatar')
                .description('Use sender avatars, initials, or an empty slot to preserve alignment.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(new Message()
                    .avatar(new Avatar()
                        .name('Alice Chen')
                        .src('https://avatars.githubusercontent.com/u/5518?s=64')
                        .size8())
                    .header(new MessageHeader().child('Alice Chen'))
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Secondary, 'The sender image falls back to initials when unavailable.'))))
                .child(new Message()
                    .avatar(new Avatar().name('Jordan Park').size8())
                    .header(new MessageHeader().child('Jordan Park'))
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Muted, 'Initials remain available without an image.'))))
                .child(new Message()
                    .avatarSlot(new MessageAvatar().bg(theme.transparent))
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Secondary, 'An empty avatar slot keeps grouped responses aligned.')))))
            .child(section('Header and footer')
                .description('Compose sender metadata, timestamps, and delivery status explicitly.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(new Message()
                    .avatar(new Avatar().name('Support team').size8())
                    .header(new MessageHeader()
                        .child(div().textColor(theme.foreground).child('Support'))
                        .child('·')
                        .child('10:42 AM'))
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Secondary, 'Your issue has been assigned to the team.')))
                    .footer(new MessageFooter().child('Read by 3 people')))
                .child(new Message()
                    .alignment(MessageAlignment.End)
                    .header(new MessageHeader().contentInset(false).child('You · Just now'))
                    .content(new MessageContent().bubble(bubble(null, 'Thank you for the quick update.')))
                    .footer(new MessageFooter().contentInset(false).child('Delivered'))))
            .child(section('Actions')
                .description('Keep copy, feedback, and retry actions keyboard-accessible.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(new Message()
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Muted, 'The install failure is coming from the workspace package.')))
                    .footer(new MessageFooter()
                        .gap2()
                        .child(new Button('message-copy').ghost().xsmall().icon(IconName.Copy).tooltip('Copy message'))
                        .child(new Button('message-like').ghost().xsmall().icon(IconName.Heart).tooltip('Like message'))
                        .child(new Button('message-save').ghost().xsmall().icon(IconName.Star).tooltip('Save message'))))
                .child(new Message()
                    .alignment(MessageAlignment.End)
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Destructive, 'The response could not be sent.')))
                    .footer(new MessageFooter()
                        .gap2()
                        .child(div().textColor(theme.danger).child('Failed to send'))
                        .child(new Button('message-retry').ghost().xsmall().label('Retry')))))
            .child(section('Attachment')
                .description('Mix image previews, file attachments, and text within one message.')
                .maxW(rems(42.5))
                .vFlex()
                .gap5()
                .child(new Message()
                    .alignment(MessageAlignment.End)
                    .content(new MessageContent()
                        .child(new Attachment()
                            .axis(Axis.Vertical)
                            .media(new AttachmentMedia().src('https://pub.lbkrs.com/files/202503/vEnnmgUM6bo362ya/sdk.svg')))
                        .bubble(bubble(null, 'Can you use this image on the cover?'))))
                .child(new Message()
                    .avatar(new Avatar().name('Alice').size8())
                    .content(new MessageContent()
                        .bubble(bubble(BubbleVariant.Secondary, 'Done. Here is the updated report.'))
                        .child(new Attachment()
                            .media(new AttachmentMedia().child(new Icon(IconName.FileText)))
                            .content(new AttachmentContent()
                                .title(new AttachmentTitle('sales-dashboard.pdf'))
                                .description(new AttachmentDescription('PDF · 2.4 MB')))
                            .actions(new AttachmentActions().child(new Button('message-open-attachment').ghost().small().label('Open')))))))
            .child(section('Multiple bubbles')
                .description('A message can hold multiple surfaces, reactions, and long-form text.')
                .maxW(rems(42.5))
                .child(new Message()
                    .avatar(new Avatar().name('Assistant').size8())
                    .header(new MessageHeader().child('Assistant').child('Just now'))
                    .content(new MessageContent()
                        .gap4()
                        .bubble(bubble(BubbleVariant.Secondary, 'I reviewed the upload and message rendering paths.'))
                        .bubble(bubble(BubbleVariant.Muted, "Keep lifecycle state on the attachment, preserve the sender's alignment, and expose every action as an existing semantic Button.")
                            .reactions(new BubbleReactions().action(new Button('message-bubble-like')
                                .ghost()
                                .xsmall()
                                .label('👍 2')
                                .tooltip('Like this response')))))
                    .footer(new MessageFooter().child('Response complete'))))
            .child(section('Group')
                .description('Group consecutive messages while keeping each row composable.')
                .maxW(rems(42.5))
                .vFlex()
                .child(new MessageGroup()
                    .wFull()
                    .child(new Message()
                        .avatar(new Avatar().name('Alice').size8())
                        .header(new MessageHeader().child('Alice'))
                        .content(new MessageContent().bubble(bubble(BubbleVariant.Secondary, 'I attached the draft.'))))
                    .child(new Message()
                        .avatarSlot(new MessageAvatar().bg(theme.transparent))
                        .content(new MessageContent().bubble(bubble(BubbleVariant.Secondary, 'The second page needs attention.'))))))
            .child(section('Custom style')
                .description('Every structural part accepts GPUI style refinements.')
                .maxW(rems(42.5))
                .child(new Message()
                    .p3()
                    .rounded(theme.radiusLg)
                    .bg(theme.muted.opacity(0.35))
                    .header(new MessageHeader().px0().child('System'))
                    .content(new MessageContent().child('The conversation has been archived.'))
                    .footer(new MessageFooter().px0().child('Just now'))))
            .child(section('Ghost surface')
                .description('Typed ghost bubbles automatically remove metadata insets.')
                .maxW(rems(42.5))
                .child(new Message()
                    .withStackStyle(new StyleBuilder(new StyleRefinement()).gap3().style())
                    .header(new MessageHeader().child('System').child('Just now'))
                    .content(new MessageContent().bubble(bubble(BubbleVariant.Ghost, 'The conversation has been archived.')))
                    .footer(new MessageFooter().child('No further action required'))));
    }

}
