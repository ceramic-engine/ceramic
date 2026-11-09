// Ported from gpui-kit 0.8.1: crates/component/src/attachment.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.ScrollHandle;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.Size;
import glaze.kit.attachment.Attachment;
import glaze.kit.button.Button;
import glaze.kit.shimmer.ShimmerText.ShimmerStyle;
import testing.InteractionScript.ScriptView;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.Size.SizeTools;

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
        final attachment = Attachment.component()
            .status(Uploading)
            .axis(Vertical)
            .withSize(glaze.kit.Size.Small)
            .media(AttachmentMedia.component().src('preview.png'))
            .content(AttachmentContent.component()
                .title(AttachmentTitle.component('report.pdf'))
                .description(AttachmentDescription.component('Uploading')))
            .actions(AttachmentActions.component().child('Cancel'));

        assertEquals(AttachmentStatus.Uploading, attachment.statusProp);
        assertEquals(glaze.Axis.Vertical, attachment.axisProp);
        assertTrue(attachment.size.equals(Small));
        assertNotNull(attachment.mediaProp);
        assertNotNull(attachment.contentProp);
        assertNotNull(attachment.actionsProp);

        attachment.layoutSlots();
        assertTrue(attachment.mediaProp.size.equals(Small));
        assertEquals(AttachmentStatus.Uploading, attachment.mediaProp.status);
        assertTrue(attachment.contentProp.verticalLayout);
        assertTrue(attachment.actionsProp.verticalLayout);

        final handle = new ScrollHandle();
        final group = AttachmentGroup.component('group')
            .trackScroll(handle)
            .withEdgeFade(black())
            .child('first')
            .child('second');
        assertNotNull(group.trackScrollProp);
        assertTrue(group.edgeFade.equals(black()));
        assertEquals(2, group.childElements.length);
        assertNull(AttachmentGroup.component('plain').trackScrollProp);
        assertNull(AttachmentGroup.component('plain').edgeFade);
    }

    function testAttachmentWholeCardClickBuilder() {
        assertNull(Attachment.component().idProp);
        assertNull(Attachment.component().onClickValue);

        final clickable = Attachment.component()
            .id('report-attachment')
            .onClick((_, _, _) -> {});
        assertTrue(Type.enumEq(ElementId.Name('report-attachment'), clickable.idProp));
        assertNotNull(clickable.onClickValue);
    }

    function testAttachmentCornerControlsBuilder() {
        assertNull(Attachment.component().onRemoveValue);
        assertNull(Attachment.component().onRetryValue);

        final attachment = Attachment.component()
            .id('upload')
            .onRemove((_, _, _) -> {})
            .onRetry((_, _, _) -> {});
        assertNotNull(attachment.onRemoveValue);
        assertNotNull(attachment.onRetryValue);
    }

    function testAttachmentRetryControlReachesSlotsOnlyWhileFailed() {
        final failed = Attachment.component()
            .id('upload')
            .status(Failed)
            .onRetry((_, _, _) -> {})
            .media(AttachmentMedia.component().src('preview.png'))
            .content(AttachmentContent.component().description(AttachmentDescription.component('Failed')));
        failed.layoutSlots();
        assertNotNull(failed.mediaProp.retry);
        assertNotNull(failed.contentProp.retry);

        // A completed attachment offers no retry, and one without an identity
        // has nothing to key the control on.
        final complete = Attachment.component()
            .id('upload')
            .onRetry((_, _, _) -> {})
            .media(AttachmentMedia.component().src('preview.png'));
        complete.layoutSlots();
        assertNull(complete.mediaProp.retry);

        final anonymous = Attachment.component()
            .status(Failed)
            .onRetry((_, _, _) -> {})
            .media(AttachmentMedia.component().src('preview.png'));
        anonymous.layoutSlots();
        assertNull(anonymous.mediaProp.retry);
    }

    function testAttachmentProgressAndTooltipBuilder() {
        assertNull(Attachment.component().progressValue);
        assertNull(Attachment.component().tooltipProp);
        assertEquals(100., Attachment.component().progress(130.).progressValue);
        assertEquals(0., Attachment.component().progress(-5.).progressValue);
        assertEquals('Network error', Attachment.component().tooltip('Network error').tooltipProp);

        // Progress reaches the slots only while uploading.
        final uploading = Attachment.component()
            .id('upload')
            .status(Uploading)
            .progress(62.)
            .media(AttachmentMedia.component().src('preview.png'))
            .content(AttachmentContent.component().description(AttachmentDescription.component('Uploading')));
        uploading.layoutSlots();
        assertEquals(62., uploading.mediaProp.progress);
        assertEquals(62., uploading.contentProp.progress);

        final processing = Attachment.component()
            .status(Processing)
            .progress(62.)
            .media(AttachmentMedia.component().src('preview.png'));
        processing.layoutSlots();
        assertNull(processing.mediaProp.progress);
    }

    function testAttachmentImageTileMediaIsFlush() {
        final tile = Attachment.component()
            .axis(Vertical)
            .media(AttachmentMedia.component().src('preview.png'));
        tile.layoutSlots();
        assertTrue(tile.mediaProp.flush);

        final card = Attachment.component()
            .axis(Vertical)
            .media(AttachmentMedia.component().src('preview.png'))
            .content(AttachmentContent.component().title(AttachmentTitle.component('preview.png')));
        card.layoutSlots();
        assertFalse(card.mediaProp.flush);
    }

    function testAttachmentDefaultsAndStatusHelpers() {
        assertEquals(AttachmentStatus.Complete, Attachment.component().statusProp);
        assertEquals(AttachmentStatus.Complete, AttachmentStatus.defaultValue());
        assertTrue(AttachmentStatus.Pending.isPending());
        assertTrue(AttachmentStatus.Uploading.isInProgress());
        assertTrue(AttachmentStatus.Processing.isProcessing());
        assertTrue(AttachmentStatus.Failed.isFailed());
        assertTrue(AttachmentStatus.Complete.isComplete());
        assertFalse(AttachmentStatus.Complete.isInProgress());
    }

    function testAttachmentSlotsAreComposable() {
        final media = AttachmentMedia.component().child('icon');
        assertEquals(1, media.childElements.length);

        final content = AttachmentContent.component()
            .title(AttachmentTitle.component('name'))
            .description(AttachmentDescription.component('Details'))
            .child('Custom progress');
        assertEquals(3, content.childElements.length);
        assertTrue(content.childElements[0].match(Title(_)));
        assertTrue(content.childElements[1].match(Description(_)));
        assertTrue(content.childElements[2].match(Element(_)));

        final legacy = AttachmentContent.component().child(AttachmentTitle.component('legacy'));
        assertTrue(legacy.childElements[0].match(Element(_)));

        final actions = AttachmentActions.component().child('remove');
        assertEquals(1, actions.childElements.length);
    }

    function testAttachmentTypedContentInheritsStatus() {
        final attachment = Attachment.component()
            .status(Uploading)
            .content(AttachmentContent.component()
                .title(AttachmentTitle.component('report.pdf'))
                .description(AttachmentDescription.component('Uploading')));

        attachment.layoutSlots();

        final content = attachment.contentProp;
        switch content.childElements[0] {
            case Title(title): assertEquals(AttachmentStatus.Uploading, title.statusProp);
            case _: fail('expected the typed title slot');
        }
        switch content.childElements[1] {
            case Description(description): assertEquals(AttachmentStatus.Uploading, description.statusProp);
            case _: fail('expected the typed description slot');
        }
    }

    function testAttachmentExplicitChildStatusOverridesParent() {
        final attachment = Attachment.component().status(Failed).content(AttachmentContent.component()
            .title(AttachmentTitle.component('report.pdf').status(Processing))
            .description(AttachmentDescription.component('Previous upload completed').status(Complete)));

        attachment.layoutSlots();

        final content = attachment.contentProp;
        switch content.childElements[0] {
            case Title(title): assertEquals(AttachmentStatus.Processing, title.statusProp);
            case _: fail('expected the typed title slot');
        }
        switch content.childElements[1] {
            case Description(description): assertEquals(AttachmentStatus.Complete, description.statusProp);
            case _: fail('expected the typed description slot');
        }
    }

    function testAttachmentTitleKeepsCustomShimmerStyle() {
        final attachment = Attachment.component()
            .status(Processing)
            .content(AttachmentContent.component().title(AttachmentTitle.component('report.pdf')
                .withShimmerStyle(new ShimmerStyle().spread(glaze.kit.shimmer.ShimmerText.ShimmerSpread.Relative(0.45)).reverse(true))));

        attachment.layoutSlots();

        final content = attachment.contentProp;
        switch content.childElements[0] {
            case Title(title):
                assertEquals(AttachmentStatus.Processing, title.statusProp);
                assertNotNull(title.shimmerStyle);
            case _: fail('expected the typed title slot');
        }
    }

    function testAttachmentMediaPreviewKeepsChildrenAndOverlays() {
        final media = AttachmentMedia.component()
            .src('preview.png')
            .child('Existing overlay')
            .overlay('Centered overlay');

        assertNotNull(media.source);
        assertEquals(1, media.childElements.length);
        assertEquals(1, media.overlays.length);
    }

    function testAttachmentMediaSizeInheritsRootUnlessExplicit() {
        function slot(size:Size, status:AttachmentStatus, axis:glaze.Axis, flush:Bool):SlotLayout {
            return new SlotLayout(size, status, axis, flush, null, null, null);
        }
        final inherited = AttachmentMedia.component().layout(slot(Small, Complete, Vertical, true));
        assertTrue(inherited.size.equals(Small));
        assertEquals(glaze.Axis.Vertical, inherited.axis);
        assertTrue(inherited.flush);

        final explicit = AttachmentMedia.component().withSize(XSmall).layout(slot(Large, Failed, Horizontal, false));
        assertTrue(explicit.size.equals(XSmall));
        assertEquals(AttachmentStatus.Failed, explicit.status);
    }

    function testAttachmentGroupBuilder() {
        final group = AttachmentGroup.component('attachments')
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
        var cardClicks = 0;
        var actionClicks = 0;
        final cx = open((_, _) -> Attachment.component()
            .id('attachment')
            .w(px(200.))
            .h(px(60.))
            .onClick((_, _, _) -> cardClicks++)
            .actions(AttachmentActions.component().child(
                Button.component('open')
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
        final cx = open((_, _) -> {
            final attachment = Attachment.component()
                .id('failed-attachment')
                .status(Failed)
                .media(AttachmentMedia.component());
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
