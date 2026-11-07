// Ported from gpui-kit 0.8.1: crates/story/src/stories/textarea_story.rs
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
import gpui.ClickEvent;
import gpui.ClipboardItem;
import gpui.ElementId;
import gpui.ImageFormat;
import gpui.Subscription;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEvent;
import gpui.base.input.TextareaState;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.attachment.Attachment;
import gpui.component.attachment.Attachment.AttachmentActions;
import gpui.component.attachment.Attachment.AttachmentContent;
import gpui.component.attachment.Attachment.AttachmentDescription;
import gpui.component.attachment.Attachment.AttachmentGroup;
import gpui.component.attachment.Attachment.AttachmentMedia;
import gpui.component.attachment.Attachment.AttachmentTitle;
import gpui.component.button.Button;
import gpui.component.hovercard.HoverCard;
import gpui.component.input.Textarea;
import gpui.component.theme.Theme;
import story.stories.InputTokens.TokenExample;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

private class ComposerAttachment {

    public final id:Int;

    public final title:String;

    public final detail:String;

    public function new(id:Int, title:String, detail:String) {
        this.id = id;
        this.title = title;
        this.detail = detail;
    }

}

class TextareaStory extends Model implements Story {

    public static function title():String {
        return 'Textarea';
    }

    public static function description():String {
        return 'Input with multi-line mode.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function init(_:App):Void {}

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TextareaStory> {
        return cx.newEntity((c:Context<TextareaStory>) -> new TextareaStory(window, c));
    }

    final tokens:Entity<TokenExample>;

    final textarea:Entity<TextareaState>;

    final textareaAutoGrow:Entity<TextareaState>;

    final textareaNoWrap:Entity<TextareaState>;

    final textareaAutoGrowNoWrap:Entity<TextareaState>;

    final chatInput:Entity<TextareaState>;

    @observe var chatMessages:Array<String> = [];

    final composer:Entity<TextareaState>;

    @observe var attachments:Array<ComposerAttachment> = [];

    /**
     * Counter for attachment ids; `Image.id` is a content hash, so pasting
     * the same image twice would collide.
     */
    var nextAttachmentId:Int = 0;

    @observe var size:Size = gpui.component.Size.Medium;

    final subscriptions:Array<Subscription>;

    /** Rust `unindent::unindent` of the raw string literal. */
    static final TEXTAREA_DEFAULT = [
        'Hello 世界，this is GPUI component.',
        'The GPUI Component is a collection of UI components for GPUI framework, including.',
        'Button, Input, Checkbox, Radio, Dropdown, Tab, and more...',
        'Here is an application that is built by using GPUI Component.',
        '> This application is still under development, not published yet.',
        '![image](https://github.com/user-attachments/assets/559a648d-19df-4b5a-b563-b78cc79c8894)',
        '![image](https://github.com/user-attachments/assets/5e06ad5d-7ea0-43db-8d13-86a240da4c8d)',
        '## Demo',
        'If you want to see the demo, here is a some demo applications.',
    ].join('\n\n') + '\n';

    function new(window:Window, cx:Context<TextareaStory>) {
        super();
        textarea = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .rows(10)
            .withPlaceholder('Enter text here...')
            .withSearchable(true)
            .defaultValue(TEXTAREA_DEFAULT));
        textareaNoWrap = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .rows(6)
            .withSoftWrap(false)
            .defaultValue('This is a very long line of text to test if the horizontal scrolling function is working properly, and it should not wrap automatically but display a horizontal scrollbar.\nThe second line is also very long text, used to test the horizontal scrolling effect under multiple lines, and you can input more content to test.\nThe third line: Here you can input other long text content that requires horizontal scrolling.\n'));
        textareaAutoGrow = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .autoGrow(1, 5)
            .withPlaceholder('Enter text here...')
            .defaultValue('Hello 世界 this is a very long line of text to test if the horizontal scrolling function is working properly, and it should not wrap automatically but display a horizontal scrollbar.\nThe second line is also very long text, used to test the horizontal scrolling effect under multiple lines, and you can input more content to test.\nThe third line: Here you can input other long text content that requires horizontal scrolling.\n'));
        textareaAutoGrowNoWrap = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .autoGrow(1, 5)
            .withSoftWrap(false)
            .withPlaceholder('Enter text here...')
            .defaultValue('Hello 世界，this is GPUI component.'));
        chatInput = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .autoGrow(1, 5)
            .withSubmitOnEnter(true)
            .withPlaceholder('Type a message, Enter to send, Shift+Enter for newline'));
        composer = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx)
            .autoGrow(1, 5)
            .withPlaceholder('Paste a screenshot here, it becomes an attachment above'));
        subscriptions = [cx.subscribeIn(chatInput, InputEvent, window, (this_, input, event, window, cx) -> switch event {
            case PressEnter(_, shift) if (!shift):
                final text = StringTools.trim(input.read(cx.app).value());
                if (text != '') {
                    this_.chatMessages = this_.chatMessages.concat([text]);
                    input.update(cx, (state, cx) -> state.setValue('', window, cast cx));
                }
            case _:
        })];
        tokens = TokenExample.create(true, window, cx.app);
    }

    function onInsertTextToTextarea(_:ClickEvent, window:Window, cx:App):Void {
        textarea.update(cx, (input, cx) -> input.insert('Hello 你好', window, cast cx));
    }

    function onReplaceTextToTextarea(_:ClickEvent, window:Window, cx:App):Void {
        textarea.update(cx, (input, cx) -> input.replace('Hello 你好', window, cast cx));
    }

    public function focusHandle(cx:App):FocusHandle {
        return textarea.read(cx).focusHandle;
    }

    /** Rust `{:?}` of an `ImageFormat`. */
    static function formatName(format:ImageFormat):String {
        return switch format {
            case Png: 'Png';
            case Jpeg: 'Jpeg';
            case Webp: 'Webp';
            case Gif: 'Gif';
            case _: Std.string(format);
        }
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final loc = textarea.read(cx.app).cursorPosition();
        final view:gpui.WeakEntity<TextareaStory> = cast cx.weakEntity();
        final attachments = this.attachments;
        final composerColumn = vFlex().gap2().wFull();
        if (attachments.length > 0) {
            composerColumn.child(new AttachmentGroup('composer-attachments').children([for (attachment in attachments) {
                final id = attachment.id;
                (new HoverCard(ElementId.NamedInteger('pasted-preview', id))
                    .trigger(new Attachment()
                        .media(new AttachmentMedia().child(new Icon(IconName.FileText).small()))
                        .content(new AttachmentContent()
                            .title(new AttachmentTitle(attachment.title))
                            .description(new AttachmentDescription(attachment.detail)))
                        .actions(new AttachmentActions().child(new Button(ElementId.NamedInteger('remove-pasted', id))
                            .ghost()
                            .xsmall()
                            .icon(IconName.Close)
                            .onClick((_, _, _) -> this.attachments = this.attachments.filter(item -> item.id != id)))))
                    .child(div().textSm().child(attachment.detail)) : IntoElement);
            }]));
        }
        composerColumn.child(new Textarea(composer)
            .withSize(size)
            .onPaste((item:ClipboardItem, _, cx) -> {
                final images = [for (entry in item.entries) switch entry {
                    case Image(image): image;
                    case _: null;
                }].filter(image -> image != null);
                if (images.length == 0) {
                    return false;
                }
                if (view.isUpgradable()) view.update(cx, (this_:TextareaStory, _) -> {
                    final next = this_.attachments.copy();
                    for (image in images) {
                        final id = this_.nextAttachmentId;
                        this_.nextAttachmentId += 1;
                        next.push(new ComposerAttachment(id, 'pasted-image-$id.png', '${formatName(image.format)} - ${image.bytes.length} bytes'));
                    }
                    this_.attachments = next;
                });
                return true;
            }));

        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Textarea').w(px(560.)).child(vFlex()
                .gap2()
                .wFull()
                .child(new Textarea(textarea).withSize(size).h(px(320.)))
                .child(hFlex()
                    .justifyBetween()
                    .child(hFlex()
                        .gap2()
                        .child(new Button('btn-insert-text').outline().xsmall().label('Insert Text').onClick(onInsertTextToTextarea))
                        .child(new Button('btn-replace-text').outline().xsmall().label('Replace Text').onClick(onReplaceTextToTextarea)))
                    .child('${loc.line}:${loc.character}'))))
            .child(section('No Wrap').w(px(560.)).child(new Textarea(textareaNoWrap).withSize(size).h(px(200.))))
            .child(section('Auto Grow').w(px(560.)).child(new Textarea(textareaAutoGrow).withSize(size)))
            .child(section('Auto Grow with No Wrap').w(px(560.)).child(new Textarea(textareaAutoGrowNoWrap).withSize(size)))
            .child(section('Submit on Enter (Chat)').w(px(560.)).child(vFlex()
                .gap2()
                .wFull()
                .child(vFlex().gap1().children([for (i => msg in chatMessages) (div()
                    .id(ElementId.NamedInteger('chat-msg', i))
                    .px2()
                    .py1()
                    .rounded(theme.radius)
                    .bg(theme.muted)
                    .child(msg) : IntoElement)]))
                .child(new Textarea(chatInput).withSize(size))))
            .child(section('Paste Images (Composer)')
                .description('Paste a screenshot, it lands as an attachment pill above.')
                .w(px(560.))
                .child(composerColumn))
            .child(section('Atomic inline tokens')
                .description('References keep their identity through selection, deletion and undo. Copy returns the underlying text.')
                .wFull()
                .child(tokens));
    }

}
