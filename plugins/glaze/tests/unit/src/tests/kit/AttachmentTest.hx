// Ported from gpui-kit 0.8.1: crates/component/src/attachment.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.ElementId;
import gpui.IntoElement;
import gpui.KeyDownEvent;
import gpui.KeyUpEvent;
import gpui.Keystroke;
import gpui.ScrollHandle;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.component.Component;
import gpui.component.Size;
import gpui.component.attachment.Attachment;
import gpui.component.button.Button;
import gpui.component.shimmer.ShimmerText.ShimmerStyle;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.component.Size.SizeTools;

/**
 * The `#[cfg(test)]` tests of gpui-component's `attachment` module,
 * including its `click_dispatch` and `retry_dispatch` window tests.
 */
class AttachmentTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function testAttachmentBuilder() {
        final attachment = new Attachment()
            .status(Uploading)
            .axis(Vertical)
            .withSize(gpui.component.Size.Small)
            .media(new AttachmentMedia().src('preview.png'))
            .content(new AttachmentContent()
                .title(new AttachmentTitle('report.pdf'))
                .description(new AttachmentDescription('Uploading')))
            .actions(new AttachmentActions().child('Cancel'));

        assertEquals(AttachmentStatus.Uploading, attachment.statusValue);
        assertEquals(gpui.Axis.Vertical, attachment.axisValue);
        assertTrue(attachment.size.equals(Small));
        assertNotNull(attachment.mediaValue);
        assertNotNull(attachment.contentValue);
        assertNotNull(attachment.actionsValue);

        attachment.layoutSlots();
        assertTrue(attachment.mediaValue.size.equals(Small));
        assertEquals(AttachmentStatus.Uploading, attachment.mediaValue.status);
        assertTrue(attachment.contentValue.verticalLayout);
        assertTrue(attachment.actionsValue.verticalLayout);

        final handle = new ScrollHandle();
        final group = new AttachmentGroup('group')
            .trackScroll(handle)
            .withEdgeFade(black())
            .child('first')
            .child('second');
        assertNotNull(group.scrollHandle);
        assertTrue(group.edgeFade.equals(black()));
        assertEquals(2, group.childElements.length);
        assertNull(new AttachmentGroup('plain').scrollHandle);
        assertNull(new AttachmentGroup('plain').edgeFade);
    }

    function testAttachmentWholeCardClickBuilder() {
        assertNull(new Attachment().idValue);
        assertNull(new Attachment().onClickValue);

        final clickable = new Attachment()
            .id('report-attachment')
            .onClick((_, _, _) -> {});
        assertTrue(Type.enumEq(ElementId.Name('report-attachment'), clickable.idValue));
        assertNotNull(clickable.onClickValue);
    }

    function testAttachmentCornerControlsBuilder() {
        assertNull(new Attachment().onRemoveValue);
        assertNull(new Attachment().onRetryValue);

        final attachment = new Attachment()
            .id('upload')
            .onRemove((_, _, _) -> {})
            .onRetry((_, _, _) -> {});
        assertNotNull(attachment.onRemoveValue);
        assertNotNull(attachment.onRetryValue);
    }

    function testAttachmentRetryControlReachesSlotsOnlyWhileFailed() {
        final failed = new Attachment()
            .id('upload')
            .status(Failed)
            .onRetry((_, _, _) -> {})
            .media(new AttachmentMedia().src('preview.png'))
            .content(new AttachmentContent().description(new AttachmentDescription('Failed')));
        failed.layoutSlots();
        assertNotNull(failed.mediaValue.retry);
        assertNotNull(failed.contentValue.retry);

        // A completed attachment offers no retry, and one without an identity
        // has nothing to key the control on.
        final complete = new Attachment()
            .id('upload')
            .onRetry((_, _, _) -> {})
            .media(new AttachmentMedia().src('preview.png'));
        complete.layoutSlots();
        assertNull(complete.mediaValue.retry);

        final anonymous = new Attachment()
            .status(Failed)
            .onRetry((_, _, _) -> {})
            .media(new AttachmentMedia().src('preview.png'));
        anonymous.layoutSlots();
        assertNull(anonymous.mediaValue.retry);
    }

    function testAttachmentProgressAndTooltipBuilder() {
        assertNull(new Attachment().progressValue);
        assertNull(new Attachment().tooltipValue);
        assertEquals(100., new Attachment().progress(130.).progressValue);
        assertEquals(0., new Attachment().progress(-5.).progressValue);
        assertEquals('Network error', new Attachment().tooltip('Network error').tooltipValue);

        // Progress reaches the slots only while uploading.
        final uploading = new Attachment()
            .id('upload')
            .status(Uploading)
            .progress(62.)
            .media(new AttachmentMedia().src('preview.png'))
            .content(new AttachmentContent().description(new AttachmentDescription('Uploading')));
        uploading.layoutSlots();
        assertEquals(62., uploading.mediaValue.progress);
        assertEquals(62., uploading.contentValue.progress);

        final processing = new Attachment()
            .status(Processing)
            .progress(62.)
            .media(new AttachmentMedia().src('preview.png'));
        processing.layoutSlots();
        assertNull(processing.mediaValue.progress);
    }

    function testAttachmentImageTileMediaIsFlush() {
        final tile = new Attachment()
            .axis(Vertical)
            .media(new AttachmentMedia().src('preview.png'));
        tile.layoutSlots();
        assertTrue(tile.mediaValue.flush);

        final card = new Attachment()
            .axis(Vertical)
            .media(new AttachmentMedia().src('preview.png'))
            .content(new AttachmentContent().title(new AttachmentTitle('preview.png')));
        card.layoutSlots();
        assertFalse(card.mediaValue.flush);
    }

    function testAttachmentDefaultsAndStatusHelpers() {
        assertEquals(AttachmentStatus.Complete, new Attachment().statusValue);
        assertEquals(AttachmentStatus.Complete, AttachmentStatus.defaultValue());
        assertTrue(AttachmentStatus.Pending.isPending());
        assertTrue(AttachmentStatus.Uploading.isInProgress());
        assertTrue(AttachmentStatus.Processing.isProcessing());
        assertTrue(AttachmentStatus.Failed.isFailed());
        assertTrue(AttachmentStatus.Complete.isComplete());
        assertFalse(AttachmentStatus.Complete.isInProgress());
    }

    function testAttachmentSlotsAreComposable() {
        final media = new AttachmentMedia().child('icon');
        assertEquals(1, media.childElements.length);

        final content = new AttachmentContent()
            .title(new AttachmentTitle('name'))
            .description(new AttachmentDescription('Details'))
            .child('Custom progress');
        assertEquals(3, content.childElements.length);
        assertTrue(content.childElements[0].match(Title(_)));
        assertTrue(content.childElements[1].match(Description(_)));
        assertTrue(content.childElements[2].match(Element(_)));

        final legacy = new AttachmentContent().child(new AttachmentTitle('legacy'));
        assertTrue(legacy.childElements[0].match(Element(_)));

        final actions = new AttachmentActions().child('remove');
        assertEquals(1, actions.childElements.length);
    }

    function testAttachmentTypedContentInheritsStatus() {
        final attachment = new Attachment()
            .status(Uploading)
            .content(new AttachmentContent()
                .title(new AttachmentTitle('report.pdf'))
                .description(new AttachmentDescription('Uploading')));

        attachment.layoutSlots();

        final content = attachment.contentValue;
        switch content.childElements[0] {
            case Title(title): assertEquals(AttachmentStatus.Uploading, title.statusValue);
            case _: fail('expected the typed title slot');
        }
        switch content.childElements[1] {
            case Description(description): assertEquals(AttachmentStatus.Uploading, description.statusValue);
            case _: fail('expected the typed description slot');
        }
    }

    function testAttachmentExplicitChildStatusOverridesParent() {
        final attachment = new Attachment().status(Failed).content(new AttachmentContent()
            .title(new AttachmentTitle('report.pdf').status(Processing))
            .description(new AttachmentDescription('Previous upload completed').status(Complete)));

        attachment.layoutSlots();

        final content = attachment.contentValue;
        switch content.childElements[0] {
            case Title(title): assertEquals(AttachmentStatus.Processing, title.statusValue);
            case _: fail('expected the typed title slot');
        }
        switch content.childElements[1] {
            case Description(description): assertEquals(AttachmentStatus.Complete, description.statusValue);
            case _: fail('expected the typed description slot');
        }
    }

    function testAttachmentTitleKeepsCustomShimmerStyle() {
        final attachment = new Attachment()
            .status(Processing)
            .content(new AttachmentContent().title(new AttachmentTitle('report.pdf')
                .withShimmerStyle(new ShimmerStyle().spread(gpui.component.shimmer.ShimmerText.ShimmerSpread.Relative(0.45)).reverse(true))));

        attachment.layoutSlots();

        final content = attachment.contentValue;
        switch content.childElements[0] {
            case Title(title):
                assertEquals(AttachmentStatus.Processing, title.statusValue);
                assertNotNull(title.shimmerStyle);
            case _: fail('expected the typed title slot');
        }
    }

    function testAttachmentMediaPreviewKeepsChildrenAndOverlays() {
        final media = new AttachmentMedia()
            .src('preview.png')
            .child('Existing overlay')
            .overlay('Centered overlay');

        assertNotNull(media.source);
        assertEquals(1, media.childElements.length);
        assertEquals(1, media.overlays.length);
    }

    function testAttachmentMediaSizeInheritsRootUnlessExplicit() {
        function slot(size:Size, status:AttachmentStatus, axis:gpui.Axis, flush:Bool):SlotLayout {
            return new SlotLayout(size, status, axis, flush, null, null, null);
        }
        final inherited = new AttachmentMedia().layout(slot(Small, Complete, Vertical, true));
        assertTrue(inherited.size.equals(Small));
        assertEquals(gpui.Axis.Vertical, inherited.axis);
        assertTrue(inherited.flush);

        final explicit = new AttachmentMedia().withSize(XSmall).layout(slot(Large, Failed, Horizontal, false));
        assertTrue(explicit.size.equals(XSmall));
        assertEquals(AttachmentStatus.Failed, explicit.status);
    }

    function testAttachmentGroupBuilder() {
        final group = new AttachmentGroup('attachments')
            .child('First')
            .child('Second');

        assertEquals(2, group.childElements.length);
    }

/// click_dispatch

    function open(render:(Window, Context<Dynamic>) -> IntoElement):VisualTestContext {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScriptView(render));
        contexts.push(opened.cx);
        return opened.cx;
    }

    function testWholeCardClickStaysBelowTheActions() {
        app.update(cx -> Component.init(cx));
        var cardClicks = 0;
        var actionClicks = 0;
        final cx = open((_, _) -> new Attachment()
            .id('attachment')
            .w(px(200.))
            .h(px(60.))
            .onClick((_, _, _) -> cardClicks++)
            .actions(new AttachmentActions().child(
                new Button('open')
                    .w(px(40.))
                    .h(px(40.))
                    .onClick((_, _, _) -> actionClicks++)
            )));
        cx.update((window, _) -> window.draw());

        // A click on an action must not also fire the whole-card handler.
        cx.simulateClick(point(20., 30.));
        assertEquals(1, actionClicks);
        assertEquals(0, cardClicks);

        // A click elsewhere on the card fires the whole-card handler.
        cx.simulateClick(point(150., 30.));
        assertEquals(1, actionClicks);
        assertEquals(1, cardClicks);
    }

/// retry_dispatch

    function failedMediaHarness(retry:Bool, retries:Array<Int>):VisualTestContext {
        app.update(cx -> Component.init(cx));
        final cx = open((_, _) -> {
            final attachment = new Attachment()
                .id('failed-attachment')
                .status(Failed)
                .media(new AttachmentMedia());
            if (retry) attachment.onRetry((_, _, _) -> retries[0]++);
            return attachment;
        });
        cx.update((window, _) -> window.draw());
        return cx;
    }

    function testFailedMediaWithoutSourceRetriesByPointerAndKeyboard() {
        final retries = [0];
        final cx = failedMediaHarness(true, retries);
        cx.simulateClick(point(20., 20.));
        assertEquals(1, retries[0]);

        cx.update((window, cx) -> window.focusNext(cx));
        cx.update((window, cx) -> assertNotNull(window.focused(cx)));
        final keystroke = Keystroke.parse('enter');
        cx.simulateEvent(new KeyDownEvent(keystroke, false, false));
        cx.simulateEvent(new KeyUpEvent(keystroke));
        assertEquals(2, retries[0]);
    }

    function testFailedMediaWithoutRetryHasNoAction() {
        final retries = [0];
        final cx = failedMediaHarness(false, retries);
        cx.simulateClick(point(20., 20.));
        assertEquals(0, retries[0]);
        cx.update((window, cx) -> window.focusNext(cx));
        cx.update((window, cx) -> assertNull(window.focused(cx)));
    }

}
