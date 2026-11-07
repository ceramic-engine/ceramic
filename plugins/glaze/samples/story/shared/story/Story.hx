// Ported from gpui-kit 0.8.1: crates/story/src/stories/mod.rs (trait Story)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.Render;

/**
 * Rust `trait Story: Render`.
 *
 * Haxe interfaces cannot carry static functions, so the trait is split:
 *
 * - the instance part is this interface. A story view is a
 *   `class XStory extends glaze.Model implements Story` and may define
 *   `public function onActive(active:Bool, window:Window, cx:App):Void`
 *   (the trait's default does nothing);
 * - the static part (`title`, `description`, `closable`, `zoomable`,
 *   `titleBg`, `paddings`, `newView`, `klass`) is declared as static
 *   functions of the story class, read by `StoryMeta.of(XStory)`:
 *
 * ```haxe
 * public static function title():String return 'Button';                  // required
 * public static function description():String return '...';              // default ''
 * public static function closable():Bool return false;                    // default true
 * public static function zoomable():Null<PanelControl> return null;       // default PanelControl.defaultValue()
 * public static function titleBg():Null<Hsla> return ...;                 // default null
 * public static function paddings():Pixels return px(0.);                 // default px(16.)
 * public static function newView(window:Window, cx:App):AnyView return view(window, cx); // required
 * ```
 *
 * `klass()` is the class name (Rust: the last segment of the type name).
 */
interface Story extends Render {}
