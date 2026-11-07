// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (actions)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.Action;
import glaze.kit.base.theme.ScrollbarMode;

/**
 * The actions of the story gallery (namespace `story`). Import this module
 * (`import story.StoryActions;`) to use them. A Rust tuple field `.0` is
 * named `value`.
 */
class StoryActions {}

@:action(namespace = story, noJson)
class SelectScrollbarMode implements Action {
    public final value:ScrollbarMode;
}

@:action(namespace = story, noJson)
class SelectLocale implements Action {
    public final value:String;
}

@:action(namespace = story, noJson)
class SelectFont implements Action {
    public final value:Int;
}

@:action(namespace = story, noJson)
class SelectRadius implements Action {
    public final value:Int;
}

@:action(namespace = story, noJson)
class ChangeStorySize implements Action {
    public final value:glaze.kit.Size;
}

@:action(namespace = story) class About implements Action {}

@:action(namespace = story) class Open implements Action {}

@:action(namespace = story) class OpenCommandPalette implements Action {}

@:action(namespace = story) class Quit implements Action {}

@:action(namespace = story) class ToggleSearch implements Action {}

@:action(namespace = story) class TestAction implements Action {}

@:action(namespace = story) class Tab implements Action {}

@:action(namespace = story) class TabPrev implements Action {}

@:action(namespace = story) class ShowPanelInfo implements Action {}

@:action(namespace = story) class ToggleListActiveHighlight implements Action {}

@:action(namespace = story) class ToggleFpsMonitor implements Action {}

@:action(namespace = story) class ToggleAppMenuBar implements Action {}
