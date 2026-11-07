// Ported from gpui-kit 0.8.1: crates/story/src/gallery.rs and crates/story/src/lib.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.component.I18n;
import story.Gallery;
import story.Lib;
import testing.TestCase;

/**
 * The `#[cfg(test)]` tests of the story gallery's `gallery.rs` and `lib.rs`
 * (`samples/story`). `app_menus.rs` and `themes.rs` have none. The Linux
 * only `component_story_window_is_opaque` has no equivalent (no window
 * background appearance in the port).
 */
@:access(story.Gallery)
class StoryGalleryTest extends TestCase {

    function testComponentCommandUsesStoryName() {
        final entry = Gallery.componentCommand('Command');

        assertTrue(switch entry {
            case Item(_): true;
            case _: false;
        });
    }

    function testStoryIndexMatchesNamesWithoutFiltering() {
        final groups = [['Welcome', 'Button'], ['Command', 'Dialog']];

        final found = Gallery.findStoryIndex(groups, 'command');
        assertTrue(found != null);
        assertEquals(1, found.group);
        assertEquals(0, found.story);
        assertTrue(Gallery.findStoryIndex(groups, 'missing') == null);
    }

    function testExtendsComponentTranslationsWithStoryLocales() {
        Lib.extendComponentTranslations();

        assertEquals('Janvier', I18n.tryTranslate('fr', 'Calendar.month.January'));
        assertEquals('January', I18n.tryTranslate('en', 'Calendar.month.January'));
    }

}
