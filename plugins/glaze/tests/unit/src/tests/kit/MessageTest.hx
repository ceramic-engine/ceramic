// Ported from gpui-kit 0.8.1: crates/component/src/message.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.ElementId;
import gpui.StyleBuilder;
import gpui.base.A11y.Role;
import gpui.base.A11y.RoleOverride;
import gpui.component.bubble.Bubble;
import gpui.component.message.Message;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-component's `message` module.
 */
class MessageTest extends TestCase {

    function testMessageBuilder() {
        final stackStyle = StyleBuilder.build(s -> s.gap1());
        final message = new Message()
            .alignment(End)
            .withStackStyle(stackStyle.clone())
            .avatarSlot(new MessageAvatar().child(div()))
            .header(new MessageHeader().contentInset(false).child('Alice'))
            .content(new MessageContent().child('Hello'))
            .footer(new MessageFooter().contentInset(false).child('Delivered'));

        assertEquals(End, message.alignmentValue);
        assertTrue(message.stackStyle.equals(stackStyle));
        assertNotNull(message.avatarValue);
        assertNotNull(message.headerValue);
        assertNotNull(message.contentValue);
        assertNotNull(message.footerValue);
        assertEquals(false, message.headerValue.contentInsetValue);
        assertEquals(false, message.footerValue.contentInsetValue);
        assertNull(message.idValue);
        assertTrue(Type.enumEq(RoleOverride.Implicit, message.roleValue));

        final row = new Message().id('message-1').role(Explicit(Role.ListItem));
        assertTrue(Type.enumEq(ElementId.Name('message-1'), row.idValue));
        assertTrue(Type.enumEq(RoleOverride.Explicit(Role.ListItem), row.roleValue));

        final group = new MessageGroup().child('First').child('Second');
        assertEquals(2, group.childElements.length);

        final content = new MessageContent().aligned(End);
        assertEquals(End, content.alignment);

        final avatar = new MessageAvatar().child('ME');
        assertEquals(1, avatar.childElements.length);
    }

    function testGhostBubbleInheritsMessageSlotInsets() {
        final content = new MessageContent()
            .bubble(new Bubble())
            .bubble(new Bubble().withVariant(Ghost));

        assertTrue(content.hasGhostBubble);
        assertEquals(2, content.childElements.length);
        assertEquals(false, new MessageHeader().withInheritedContentInset(false).contentInsetValue);
        assertEquals(false, new MessageFooter().withInheritedContentInset(false).contentInsetValue);
        assertEquals(true, new MessageHeader().contentInset(true).withInheritedContentInset(false).contentInsetValue);
        assertEquals(true, new MessageFooter().contentInset(true).withInheritedContentInset(false).contentInsetValue);
    }

}
