// Stand-in for GPUI's `App::open_url` (gpui-pre 0.3.10: src/app.rs, src/platform.rs), used by
// gpui-kit 0.8.1 components (crates/component/src/link.rs)
// Original code Copyright 2022-2025 Zed Industries, Inc. and 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.App;
import gpui.AppContext;

/**
 * Opens URLs with the platform, like GPUI's `App::open_url`, which the
 * port's `App` does not have yet.
 *
 * The last opened URL is recorded (`openedUrl`, like GPUI's test platform)
 * and, when `opener` is set, the URL goes to it instead of the platform
 * (tests set it to a no-op).
 */
class PlatformUrl {

    /** The last URL opened (Rust `TestAppContext::opened_url`). */
    public static var openedUrl:Null<String> = null;

    /** Replaces the platform opener (null: the platform's). */
    public static var opener:Null<String->Void> = null;

    public static function openUrl(cx:AppContext, url:String):Void {
        openedUrl = url;
        if (opener != null) {
            opener(url);
            return;
        }
        (cx:App).openUrl(url);
    }

}
