// Ported from gpui-kit 0.8.1: crates/component/src/bubble.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.kit.bubble.Bubble;
import glaze.kit.button.Button;
import glaze.kit.message.Message.MessageAlignment;
import testing.TestCase;

/**
 * The `#[cfg(test)]` tests of gpui-component's `bubble` module.
 */
class BubbleTest extends TestCase {

    function testBubbleBuilder() {
        final bubble = new Bubble()
            .alignment(End)
            .withVariant(Outline)
            .content(new BubbleContent().child('Hello'))
            .reactions(new BubbleReactions().child('👍'));

        assertEquals(MessageAlignment.End, bubble.alignmentValue);
        assertEquals(BubbleVariant.Outline, bubble.variant);
        assertEquals(1, bubble.contentValue.childElements.length);
        assertNotNull(bubble.reactionsValue);

        // Direct children survive a later `content(...)` call and stay in
        // front of the new surface's own children.
        final reordered = new Bubble()
            .child('Existing')
            .content(new BubbleContent().child('Configured'));
        assertEquals(2, reordered.contentValue.childElements.length);

        final group = new BubbleGroup().child('First').child('Second');
        assertEquals(2, group.childElements.length);

        final reactions = new BubbleReactions()
            .side(Top)
            .alignment(Start)
            .child('👍 2');

        assertEquals(BubbleReactionSide.Top, reactions.sideValue);
        assertEquals(MessageAlignment.Start, reactions.alignmentValue);
        assertEquals(1, reactions.childElements.length);

        final reactions = new BubbleReactions()
            .action(new Button('reaction-action'))
            .child('👍');
        assertEquals(2, reactions.childElements.length);
        assertTrue(reactions.childElements[0].match(Action(_)));
        assertTrue(reactions.childElements[1].match(Element(_)));
    }

}
