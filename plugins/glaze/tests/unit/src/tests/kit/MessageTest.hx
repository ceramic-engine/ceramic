// Ported from gpui-kit 0.8.1: crates/component/src/message.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.ElementId;
import glaze.StyleBuilder;
import glaze.kit.base.A11y.Role;
import glaze.kit.base.A11y.RoleOverride;
import glaze.kit.bubble.Bubble;
import glaze.kit.message.Message;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `message` module.
 */
class MessageTest extends TestCase {

    function testMessageBuilder() {
        final stackStyle = StyleBuilder.build(s -> s.gap1());
        final message = Message.component()
            .alignment(End)
            .withStackStyle(stackStyle.clone())
            .avatarSlot(MessageAvatar.component().child(div()))
            .header(MessageHeader.component().contentInset(false).child('Alice'))
            .content(MessageContent.component().child('Hello'))
            .footer(MessageFooter.component().contentInset(false).child('Delivered'));

        assertEquals(End, message.alignmentProp);
        assertTrue(message.stackStyle.equals(stackStyle));
        assertNotNull(message.avatarSlotProp);
        assertNotNull(message.headerProp);
        assertNotNull(message.contentProp);
        assertNotNull(message.footerProp);
        assertEquals(false, message.headerProp.contentInsetProp);
        assertEquals(false, message.footerProp.contentInsetProp);
        assertNull(message.idProp);
        assertTrue(Type.enumEq(RoleOverride.Implicit, message.roleProp));

        final row = Message.component().id('message-1').role(Explicit(Role.ListItem));
        assertTrue(Type.enumEq(ElementId.Name('message-1'), row.idProp));
        assertTrue(Type.enumEq(RoleOverride.Explicit(Role.ListItem), row.roleProp));

        final group = MessageGroup.component().child('First').child('Second');
        assertEquals(2, group.childElements.length);

        final content = MessageContent.component().aligned(End);
        assertEquals(End, content.alignment);

        final avatar = MessageAvatar.component().child('ME');
        assertEquals(1, avatar.childElements.length);
    }

    function testGhostBubbleInheritsMessageSlotInsets() {
        final content = MessageContent.component()
            .bubble(Bubble.component())
            .bubble(Bubble.component().withVariant(Ghost));

        assertTrue(content.hasGhostBubble);
        assertEquals(2, content.childElements.length);
        assertEquals(false, MessageHeader.component().withInheritedContentInset(false).contentInsetProp);
        assertEquals(false, MessageFooter.component().withInheritedContentInset(false).contentInsetProp);
        assertEquals(true, MessageHeader.component().contentInset(true).withInheritedContentInset(false).contentInsetProp);
        assertEquals(true, MessageFooter.component().contentInset(true).withInheritedContentInset(false).contentInsetProp);
    }

}
