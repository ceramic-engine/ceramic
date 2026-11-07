// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (StoryState)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.App;
import glaze.Window;
import glaze.kit.base.dock.JsonValue;

/**
 * The persisted state of a `StoryContainer` panel: its story class.
 */
class StoryState {

    public final storyKlass:String;

    public function new(storyKlass:String) {
        this.storyKlass = storyKlass;
    }

    public function toValue():JsonValue {
        final object = new JsonObject();
        object.set('story_klass', JString(storyKlass));
        return JObject(object);
    }

    public static function fromValue(value:JsonValue):StoryState {
        return switch value {
            case JObject(object):
                switch object.get('story_klass') {
                    case JString(klass): new StoryState(klass);
                    case _: throw 'missing field `story_klass`';
                }
            case _: throw 'invalid type, expected struct StoryState';
        }
    }

    /**
     * The story of `storyKlass` (Rust `to_story`, which returns its title,
     * description, closable, zoomable, view and `on_active_any`).
     */
    public function toStory(window:Window, cx:glaze.AppContext):StoryMeta {
        final meta:Null<StoryMeta> = switch storyKlass {
            case 'AttachmentStory': StoryMeta.optional(story.stories.AttachmentStory);
            case 'BreadcrumbStory': StoryMeta.optional(story.stories.BreadcrumbStory);
            case 'BubbleStory': StoryMeta.optional(story.stories.BubbleStory);
            case 'ButtonStory': StoryMeta.optional(story.stories.ButtonStory);
            case 'CalendarStory': StoryMeta.optional(story.stories.CalendarStory);
            case 'SelectStory': StoryMeta.optional(story.stories.SelectStory);
            case 'IconStory': StoryMeta.optional(story.stories.IconStory);
            case 'ImageStory': StoryMeta.optional(story.stories.ImageStory);
            case 'InputStory': StoryMeta.optional(story.stories.InputStory);
            case 'ListStory': StoryMeta.optional(story.stories.ListStory);
            case 'MarkerStory': StoryMeta.optional(story.stories.MarkerStory);
            case 'MessageStory': StoryMeta.optional(story.stories.MessageStory);
            case 'MessageScrollerStory': StoryMeta.optional(story.stories.MessageScrollerStory);
            case 'DialogStory': StoryMeta.optional(story.stories.DialogStory);
            case 'DiffStory': StoryMeta.optional(story.stories.DiffStory);
            case 'SeparatorStory': StoryMeta.optional(story.stories.SeparatorStory);
            case 'ShimmerStory': StoryMeta.optional(story.stories.ShimmerStory);
            case 'PopoverStory': StoryMeta.optional(story.stories.PopoverStory);
            case 'ProgressStory': StoryMeta.optional(story.stories.ProgressStory);
            case 'ResizableStory': StoryMeta.optional(story.stories.ResizableStory);
            case 'ScrollbarStory': StoryMeta.optional(story.stories.ScrollbarStory);
            case 'SwitchStory': StoryMeta.optional(story.stories.SwitchStory);
            case 'DataTableStory': StoryMeta.optional(story.stories.DataTableStory);
            case 'TableStory': StoryMeta.optional(story.stories.TableStory);
            case 'LabelStory': StoryMeta.optional(story.stories.LabelStory);
            case 'TooltipStory': StoryMeta.optional(story.stories.TooltipStory);
            case 'AccordionStory': StoryMeta.optional(story.stories.AccordionStory);
            case 'SidebarStory': StoryMeta.optional(story.stories.SidebarStory);
            case 'FormStory': StoryMeta.optional(story.stories.FormStory);
            case 'NotificationStory': StoryMeta.optional(story.stories.NotificationStory);
            case 'ThemeColorsStory': StoryMeta.optional(story.stories.ThemeColorsStory);
            case _: null;
        }
        if (meta == null) throw 'Invalid story klass: $storyKlass';
        return meta;
    }

}
