// Ported from gpui-kit 0.8.1: crates/story/src/stories/message_scroller_story.rs
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
import gpui.Div;
import gpui.ElementId;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.WeakEntity;
import gpui.base.input.InputState;
import gpui.component.IconName;
import gpui.component.bubble.Bubble;
import gpui.component.bubble.Bubble.BubbleVariant;
import gpui.component.button.Button;
import gpui.component.input.Input;
import gpui.component.marker.Marker;
import gpui.component.marker.Marker.MarkerContent;
import gpui.component.marker.Marker.MarkerVariant;
import gpui.component.message.Message;
import gpui.component.message.Message.MessageAlignment;
import gpui.component.message.Message.MessageContent;
import gpui.component.messagescroller.MessageScroller;
import gpui.component.messagescroller.MessageScroller.MessageScrollerState;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

private class DemoMessage {

    public final id:Int;

    public var body:String;

    public final sent:Bool;

    public function new(id:Int, sent:Bool, body:String) {
        this.id = id;
        this.body = body;
        this.sent = sent;
    }

    public function clone():DemoMessage {
        return new DemoMessage(id, sent, body);
    }

}

class MessageScrollerStory extends Model implements Story {

    static inline final INITIAL_STREAM_MESSAGE_COUNT = 7;

    public static function title():String {
        return 'MessageScroller';
    }

    public static function description():String {
        return 'A virtualized message list with tail following, unread navigation, and anchor preservation.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<MessageScrollerStory> {
        return cx.newEntity((c:Context<MessageScrollerStory>) -> new MessageScrollerStory(window, c));
    }

    final focusHandle_:FocusHandle;

    final scroller:Entity<MessageScrollerState>;

    final streamScroller:Entity<MessageScrollerState>;

    final historyScroller:Entity<MessageScrollerState>;

    final navigationScroller:Entity<MessageScrollerState>;

    final customScroller:Entity<MessageScrollerState>;

    final applicationScroller:Entity<MessageScrollerState>;

    final emptyScroller:Entity<MessageScrollerState>;

    final composer:Entity<InputState>;

    var messages:Array<DemoMessage>;

    var streamMessages:Array<DemoMessage>;

    var historyMessages:Array<DemoMessage>;

    var previewMessages:Array<DemoMessage>;

    var emptyMessages:Array<DemoMessage> = [];

    var unreadIndex:Int = 4;

    var nextId:Int = 10000;

    var streaming:Bool = false;

    /** Rust `stream_task`: dropping it cancels the loop; here a run counter. */
    var streamRun:Int = 0;

    final self:WeakEntity<MessageScrollerStory>;

    static function createScroller(count:Int, cx:Context<MessageScrollerStory>):Entity<MessageScrollerState> {
        final state = cx.newEntity((cx:Context<MessageScrollerState>) -> new MessageScrollerState(count, cx));
        cx.observe(state, (_, _, cx) -> cx.notify()).detach();
        return state;
    }

    static function makePreviewMessages(firstId:Int, count:Int):Array<DemoMessage> {
        return [for (index in 0...count) new DemoMessage(firstId + index, index % 3 == 2, if (index % 4 == 0) {
            'Message ${index + 1} wraps across more than one line to keep virtual-row measurement realistic.';
        } else {
            'Conversation message ${index + 1}';
        })];
    }

    /**
     * The scripted conversation for the main demo, mirroring shadcn's
     * message-scroller demo: an AI chat without avatars or author names.
     */
    static function conversationScript():Array<DemoMessage> {
        final script:Array<{sent:Bool, body:String}> = [
            {sent: true, body: "I'm building a chat for our app and the scroll behavior is driving me nuts. Every time the AI streams a reply, the whole thread jumps around."},
            {sent: false, body: "That's the classic streaming scroll problem. Render the rows with MessageScroller — it follows the tail while the reader sits at the live edge, so streamed tokens land in place instead of shoving the thread around."},
            {sent: true, body: "Okay, but what happens when someone scrolls up to re-read an older answer? I don't want to yank them back down."},
            {sent: false, body: "You won't. Scrolling up releases tail following, so the reading position is preserved while new rows keep arriving below.\n\nA jump-to-latest button appears once the reader leaves the tail; one click returns to the newest row and resumes following."},
            {sent: true, body: "And loading older history when they reach the top?"},
            {sent: false, body: "prepend inserts the earlier rows while the row the reader is on stays anchored in place — no jump to the top, no lost context."},
            {sent: true, body: "Last one — does it handle rows that change height while streaming?"},
            {sent: false, body: "Yes. Remeasure just the growing row and the list keeps its anchor, so streamed markdown, images, and expanding content stay stable."},
        ];
        return [for (index => row in script) new DemoMessage(index, row.sent, row.body)];
    }

    function new(window:Window, cx:Context<MessageScrollerStory>) {
        super();
        self = cx.weakEntity();
        messages = conversationScript();
        streamMessages = makePreviewMessages(1000, INITIAL_STREAM_MESSAGE_COUNT - 1);
        streamMessages.push(new DemoMessage(1000 + INITIAL_STREAM_MESSAGE_COUNT - 1, true, 'How does streaming preserve my position?'));
        historyMessages = makePreviewMessages(2000, 14);
        previewMessages = makePreviewMessages(3000, 18);
        scroller = createScroller(messages.length, cx);
        streamScroller = createScroller(streamMessages.length, cx);
        historyScroller = createScroller(historyMessages.length, cx);
        navigationScroller = createScroller(previewMessages.length, cx);
        customScroller = createScroller(previewMessages.length, cx);
        applicationScroller = createScroller(previewMessages.length, cx);
        emptyScroller = createScroller(0, cx);
        composer = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Write a message…'));
        focusHandle_ = cx.focusHandle();
    }

    function appendMessage(cx:Context<MessageScrollerStory>):Void {
        final id = nextId;
        nextId += 1;
        messages.push(new DemoMessage(id, true, 'New message ${messages.length + 1}'));
        scroller.update(cx, (state, cx) -> state.append(1, cx));
        cx.notify();
    }

    function prependHistory(cx:Context<MessageScrollerStory>):Void {
        final count = 5;
        final firstId = nextId;
        nextId += count;
        final earlier = [for (offset in 0...count) new DemoMessage(firstId + offset, false, 'Earlier history ${offset + 1}')];
        messages = earlier.concat(messages);
        unreadIndex += count;
        scroller.update(cx, (state, cx) -> state.prepend(count, cx));
        cx.notify();
    }

    function sendMessage(window:Window, cx:Context<MessageScrollerStory>):Void {
        final body = composer.read(cx.app).value();
        if (StringTools.trim(body) == '') {
            return;
        }
        final id = nextId;
        nextId += 1;
        messages.push(new DemoMessage(id, true, body));
        composer.update(cx, (input, cx) -> input.setValue('', window, cast cx));
        scroller.update(cx, (state, cx) -> state.append(1, cx));
        cx.notify();
    }

    function resetConversation(cx:Context<MessageScrollerStory>):Void {
        messages = conversationScript();
        unreadIndex = 4;
        final count = messages.length;
        scroller.update(cx, (state, cx) -> state.reset(count, cx));
        cx.notify();
    }

    function scrollToUnread(cx:Context<MessageScrollerStory>):Void {
        final unreadIndex = this.unreadIndex;
        scroller.update(cx, (state, cx) -> state.scrollToItem(unreadIndex, cx));
    }

    function startStream(cx:Context<MessageScrollerStory>):Void {
        if (streaming) {
            return;
        }
        final response = 'The virtual list follows new content while you remain at the live edge. Scroll upward during this response and your reading position stays in place until you choose to return to the latest message.';
        final messageIx = streamMessages.length;
        final id = nextId;
        nextId += 1;
        streaming = true;
        streamMessages.push(new DemoMessage(id, false, 'Preparing response…'));
        streamScroller.update(cx, (state, cx) -> state.append(1, cx));
        cx.notify();
        final tokens = [for (token in ~/\s+/g.split(response)) if (token != '') token];
        final run = ++streamRun;
        final app = cx.app;
        function step(tokenIx:Int):Void {
            if (tokenIx >= tokens.length) {
                self.update(app, (story, cx) -> {
                    if (story.streamRun != run) return;
                    story.streaming = false;
                    story.streamRun++;
                    cx.notify();
                });
                return;
            }
            app.backgroundExecutor().timer(0.11).then(_ -> {
                if (!self.isUpgradable()) return;
                final shouldContinue = self.update(app, (story, cx) -> {
                    if (story.streamRun != run || !story.streaming) {
                        return false;
                    }
                    if (messageIx >= story.streamMessages.length) {
                        return false;
                    }
                    final message = story.streamMessages[messageIx];
                    final token = tokens[tokenIx];
                    message.body = tokenIx == 0 ? token : '${message.body} $token';
                    story.streamScroller.update(cx, (state, cx) -> state.remeasureItems(messageIx, messageIx + 1, cx));
                    cx.notify();
                    return true;
                });
                if (shouldContinue) step(tokenIx + 1);
            });
        }
        step(0);
    }

    function stopStream(cx:Context<MessageScrollerStory>):Void {
        streaming = false;
        streamRun++;
        cx.notify();
    }

    function resetStream(cx:Context<MessageScrollerStory>):Void {
        streaming = false;
        streamRun++;
        if (streamMessages.length > INITIAL_STREAM_MESSAGE_COUNT) streamMessages = streamMessages.slice(0, INITIAL_STREAM_MESSAGE_COUNT);
        streamScroller.update(cx, (state, cx) -> state.reset(INITIAL_STREAM_MESSAGE_COUNT, cx));
        cx.notify();
    }

    function expandStreamResponse(cx:Context<MessageScrollerStory>):Void {
        if (streamMessages.length == 0) {
            return;
        }
        final messageIx = streamMessages.length - 1;
        final message = streamMessages[messageIx];
        message.body = '${message.body}\n\nExpanded details demonstrate how images, Markdown, and progressive content can change an existing row without replacing its identity.';
        streamScroller.update(cx, (state, cx) -> state.remeasureItems(messageIx, messageIx + 1, cx));
        cx.notify();
    }

    function loadEarlierPreview(cx:Context<MessageScrollerStory>):Void {
        final count = 5;
        final firstId = nextId;
        nextId += count;
        final earlier = [for (offset in 0...count) new DemoMessage(firstId + offset, false, 'Earlier saved message ${offset + 1}')];
        historyMessages = earlier.concat(historyMessages);
        historyScroller.update(cx, (state, cx) -> state.prepend(count, cx));
        cx.notify();
    }

    function toggleEmptyConversation(cx:Context<MessageScrollerStory>):Void {
        if (emptyMessages.length == 0) {
            emptyMessages.push(new DemoMessage(20000, true, 'A first message replaces the application-owned empty state.'));
            emptyScroller.update(cx, (state, cx) -> state.append(1, cx));
        } else {
            emptyMessages = [];
            emptyScroller.update(cx, (state, cx) -> state.reset(0, cx));
        }
        cx.notify();
    }

    static function renderMessageRow(message:DemoMessage, unread:Bool):IntoElement {
        // Mirror shadcn's message-scroller demo: no avatars or author names,
        // sent rows on a muted surface, received rows as ghost text.
        final alignment = message.sent ? MessageAlignment.End : MessageAlignment.Start;
        final bubble = new Bubble().withVariant(message.sent ? BubbleVariant.Muted : BubbleVariant.Ghost).child(message.body);
        return vFlex()
            .wFull()
            .minW0()
            .gap3()
            .when(unread, this_ -> this_.child(new Marker()
                .withVariant(MarkerVariant.Separator)
                .content(new MarkerContent().child('Unread'))))
            .child(div()
                .id(ElementId.NamedInteger('message-scroller-row', message.id))
                .wFull()
                .child(new Message().alignment(alignment).content(new MessageContent().bubble(bubble))));
    }

    /** A row renderer over a snapshot of the messages (Rust `Rc<Vec<DemoMessage>>`). */
    static function rows(messages:Array<DemoMessage>, ?unreadIndex:Int = -1):(Int, Window, App) -> IntoElement {
        return (index, _, _) -> index >= 0 && index < messages.length ? renderMessageRow(messages[index], index == unreadIndex) : div();
    }

    static function previewFrame(scroller:MessageScroller, theme:Theme):Div {
        return div()
            .w(rems(26.))
            .maxWFull()
            .h(rems(19.))
            .overflowHidden()
            .rounded(theme.radius2xl())
            .border1()
            .borderColor(theme.border)
            .bg(theme.background)
            .textColor(theme.foreground)
            .child(scroller.withBottomFade(theme.background).sizeFull());
    }

    static function listStyle(f:(StyleBuilder) -> StyleBuilder):StyleRefinement {
        return f(new StyleBuilder(new StyleRefinement())).style();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final app = cx.app;
        final messages = [for (m in this.messages) m.clone()];
        final streamMessages = [for (m in this.streamMessages) m.clone()];
        final historyMessages = [for (m in this.historyMessages) m.clone()];
        final navigationMessages = [for (m in this.previewMessages) m.clone()];
        final customMessages = navigationMessages;
        final applicationMessages = navigationMessages;
        final emptyMessages = [for (m in this.emptyMessages) m.clone()];
        final unreadIndex = this.unreadIndex;
        final streaming = this.streaming;
        final streamHasResponse = this.streamMessages.length > INITIAL_STREAM_MESSAGE_COUNT;
        final customScrolledUp = customScroller.read(app).isScrolledUp();
        final applicationScrolledUp = applicationScroller.read(app).isScrolledUp();
        final empty = this.emptyMessages.length == 0;
        final state = scroller.read(app);
        final status = 'Following tail: ${state.isFollowingTail()} · Scrolled up: ${state.isScrolledUp()}';
        final entity:Entity<MessageScrollerStory> = cast cx.entity();
        // Rust `cx.listener(...)`
        final listener = (f:(MessageScrollerStory, Context<MessageScrollerStory>) -> Void) -> (_:gpui.ClickEvent, _:Window, cx:App) -> entity.update(cx, (this_, cx) -> f(this_, cx));
        return vFlex()
            .gap4()
            .child(section('Conversation')
                .description('Scroll upward, append a row, jump to unread, or prepend history to exercise each behavior.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(hFlex()
                    .gap2()
                    .child(new Button('message-scroller-append').label('Append').onClick(listener((this_, cx) -> this_.appendMessage(cx))))
                    .child(new Button('message-scroller-prepend').label('Prepend history').onClick(listener((this_, cx) -> this_.prependHistory(cx))))
                    .child(new Button('message-scroller-unread').label('Scroll to unread').onClick(listener((this_, cx) -> this_.scrollToUnread(cx)))))
                .child(vFlex()
                    .w96()
                    .maxWFull()
                    .h(rems(35.))
                    .overflowHidden()
                    .rounded(theme.radius4xl())
                    .border1()
                    .borderColor(theme.border)
                    .bg(theme.background)
                    .textColor(theme.foreground)
                    .child(hFlex()
                        .wFull()
                        .itemsStart()
                        .justifyBetween()
                        .gap2()
                        .p5()
                        .borderB1()
                        .borderColor(theme.border)
                        .child(vFlex()
                            .gap1()
                            .child(div().fontSemibold().child('New Chat'))
                            .child(div().textSm().textColor(theme.mutedForeground).child('How can I help you today?')))
                        .child(new Button('message-scroller-reset')
                            .outline()
                            .icon(IconName.RotateCw)
                            .rounded(theme.radiusFull())
                            .tooltip('Reset conversation')
                            .onClick(listener((this_, cx) -> this_.resetConversation(cx)))))
                    .child(div().flex1().minH0().child(new MessageScroller('message-scroller-demo', scroller, rows(messages, unreadIndex))
                        .withListStyle(listStyle(s -> s.p5()))
                        .withBottomFade(theme.background)))
                    .child(div().wFull().px5().pb5().child(vFlex()
                        .wFull()
                        .gap1()
                        .p2()
                        .roundedXl()
                        .bg(theme.muted)
                        .child(new Input(composer).appearance(false))
                        .child(hFlex().wFull().justifyEnd().child(new Button('message-scroller-send')
                            .primary()
                            .icon(IconName.ArrowUp)
                            .rounded(theme.radiusFull())
                            .tooltip('Send')
                            .onClick((_, window, cx) -> entity.update(cx, (this_, cx) -> this_.sendMessage(window, cx))))))))
                .child(div().textXs().textColor(theme.mutedForeground).child(status)))
            .child(section('Streaming responses')
                .description('Append one assistant response, grow its text progressively, and remeasure only that row.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(hFlex()
                    .flexWrap()
                    .gap2()
                    .child(new Button('message-scroller-start-stream')
                        .label('Stream response')
                        .disabled(streaming)
                        .onClick(listener((this_, cx) -> this_.startStream(cx))))
                    .child(new Button('message-scroller-stop-stream')
                        .outline()
                        .label('Stop')
                        .disabled(!streaming)
                        .onClick(listener((this_, cx) -> this_.stopStream(cx))))
                    .child(new Button('message-scroller-expand-response')
                        .label('Expand response')
                        .disabled(streaming || !streamHasResponse)
                        .onClick(listener((this_, cx) -> this_.expandStreamResponse(cx))))
                    .child(new Button('message-scroller-reset-stream')
                        .ghost()
                        .label('Reset')
                        .onClick(listener((this_, cx) -> this_.resetStream(cx)))))
                .child(previewFrame(new MessageScroller('message-scroller-streaming', streamScroller, rows(streamMessages))
                    .withListStyle(listStyle(s -> s.p4())), theme))
                .child(div()
                    .textXs()
                    .textColor(theme.mutedForeground)
                    .child(streaming ? 'Streaming · existing row is remeasured as each token arrives' : 'Idle · scroll upward before streaming to preserve reading position')))
            .child(section('Loading earlier messages')
                .description('Prepend history without disturbing the currently visible message anchor.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(hFlex()
                    .gap2()
                    .child(new Button('message-scroller-load-earlier').label('Load five earlier').onClick(listener((this_, cx) -> this_.loadEarlierPreview(cx))))
                    .child(new Button('message-scroller-history-start')
                        .outline()
                        .label('Scroll to oldest')
                        .onClick(listener((this_, cx) -> this_.historyScroller.update(cx, (state, cx) -> state.scrollToItem(0, cx))))))
                .child(previewFrame(new MessageScroller('message-scroller-history', historyScroller, rows(historyMessages))
                    .withListStyle(listStyle(s -> s.p4())), theme)))
            .child(section('Jumping to messages')
                .description('Applications resolve stable message IDs to their current row indices.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(hFlex()
                    .gap2()
                    .child(new Button('message-scroller-first-message')
                        .label('First message')
                        .onClick(listener((this_, cx) -> this_.navigationScroller.update(cx, (state, cx) -> state.scrollToItem(0, cx)))))
                    .child(new Button('message-scroller-middle-message')
                        .label('Message 9')
                        .onClick(listener((this_, cx) -> this_.navigationScroller.update(cx, (state, cx) -> state.scrollToItem(8, cx)))))
                    .child(new Button('message-scroller-last-message')
                        .outline()
                        .label('Latest')
                        .onClick(listener((this_, cx) -> this_.navigationScroller.update(cx, (state, cx) -> state.scrollToEnd(cx))))))
                .child(previewFrame(new MessageScroller('message-scroller-navigation', navigationScroller, rows(navigationMessages))
                    .withListStyle(listStyle(s -> s.p4())), theme)))
            .child(section('Empty conversation')
                .description('The application owns empty states and switches to a virtual list when data arrives.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(new Button('message-scroller-toggle-empty')
                    .label(empty ? 'Add first message' : 'Clear conversation')
                    .onClick(listener((this_, cx) -> this_.toggleEmptyConversation(cx))))
                .child(div()
                    .w(rems(26.))
                    .maxWFull()
                    .h(rems(14.))
                    .overflowHidden()
                    .rounded(theme.radius2xl())
                    .border1()
                    .borderColor(theme.border)
                    .bg(theme.background)
                    .when(empty, this_ -> this_.child(vFlex()
                        .sizeFull()
                        .itemsCenter()
                        .justifyCenter()
                        .gap1()
                        .child(div().fontSemibold().child('No messages yet'))
                        .child(div().textSm().textColor(theme.mutedForeground).child('Send a message to start the conversation'))))
                    .when(!empty, this_ -> this_.child(new MessageScroller('message-scroller-empty', emptyScroller, rows(emptyMessages))
                        .withListStyle(listStyle(s -> s.p4()))
                        .withBottomFade(theme.background)
                        .sizeFull()))))
            .child(section('Custom jump button')
                .description('Change the built-in button, transition, tooltip, list spacing, and row styles.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(hFlex()
                    .gap2()
                    .child(new Button('message-scroller-show-custom-jump')
                        .label('Reveal jump button')
                        .onClick(listener((this_, cx) -> this_.customScroller.update(cx, (state, cx) -> state.scrollToItem(0, cx)))))
                    .child(div().textSm().textColor(theme.mutedForeground).child(customScrolledUp ? 'Visible' : 'Hidden')))
                .child(previewFrame(new MessageScroller('message-scroller-custom-control', customScroller, rows(customMessages))
                    .withContentStyle(listStyle(s -> s.bg(theme.background)))
                    .withListStyle(listStyle(s -> s.p4()))
                    .withRowStyle(listStyle(s -> s.pb4()))
                    .withJumpButtonLabel('Return to the latest message')
                    .withJumpButtonRenderer(button -> button.outline().small().label('Latest'))
                    .withJumpButtonStyle(listStyle(s -> s.rounded(theme.radiusLg)))
                    .withJumpButtonTransition(0.35), theme)))
            .child(section('Application-owned controls')
                .description('Disable built-in chrome and place the jump action wherever the product needs it.')
                .maxW(rems(45.))
                .vFlex()
                .gap3()
                .child(hFlex()
                    .gap2()
                    .child(new Button('message-scroller-application-scroll-up')
                        .label('Scroll to first')
                        .onClick(listener((this_, cx) -> this_.applicationScroller.update(cx, (state, cx) -> state.scrollToItem(0, cx)))))
                    .child(new Button('message-scroller-application-latest')
                        .outline()
                        .label('Jump to latest')
                        .disabled(!applicationScrolledUp)
                        .onClick(listener((this_, cx) -> this_.applicationScroller.update(cx, (state, cx) -> state.scrollToEnd(cx))))))
                .child(previewFrame(new MessageScroller('message-scroller-application-controls', applicationScroller, rows(applicationMessages))
                    .jumpButton(false)
                    .scrollbar(false)
                    .withListStyle(listStyle(s -> s.p4())), theme)));
    }

}
