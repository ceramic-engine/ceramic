// Ported from gpui-kit 0.8.1: crates/story/src/stories/mod.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.App;
import story.StoryMeta;

/**
 * Rust `stories::init`: the key bindings of the stories that have some. A
 * story module's `init` is a static `init(cx:App)` of its story class.
 */
class Stories {

    public static function init(cx:App):Void {
        StoryMeta.initOptional(story.stories.InputStory, cx);
        StoryMeta.initOptional(story.stories.ComboboxStory, cx);
        StoryMeta.initOptional(story.stories.RatingStory, cx);
        StoryMeta.initOptional(story.stories.NumberInputStory, cx);
        StoryMeta.initOptional(story.stories.TextareaStory, cx);
        StoryMeta.initOptional(story.stories.SelectStory, cx);
        StoryMeta.initOptional(story.stories.PopoverStory, cx);
        StoryMeta.initOptional(story.stories.MenuStory, cx);
        StoryMeta.initOptional(story.stories.TooltipStory, cx);
        StoryMeta.initOptional(story.stories.OtpInputStory, cx);
        StoryMeta.initOptional(story.stories.TreeStory, cx);
    }

}
