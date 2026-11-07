// Ported from gpui-kit 0.8.1: crates/story/src/app_menus.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import gpui.App;
import gpui.AppContext;
import gpui.Entity;
import gpui.Menu;
import gpui.base.GlobalState;
import gpui.base.input.InputActions;
import gpui.component.I18n;
import gpui.component.menu.AppMenuBar;
import gpui.component.theme.Theme;
import gpui.component.theme.ThemeMode;
import story.StoryActions;
import story.Themes.SelectTheme;
import story.Themes.SwitchThemeMode;

using gpui.Menu.MenuItemTools;

/**
 * The application menus of the gallery, drawn by the title bar's
 * `AppMenuBar`.
 */
class AppMenus {

    public static function init(title:String, cx:AppContext):Entity<AppMenuBar> {
        final appMenuBar = AppMenuBar.create(cx);
        updateAppMenu(title, appMenuBar, cx);

        cx.onAction(SelectLocale, (s, cx) -> {
            I18n.setLocale(s.value);
            updateAppMenu(title, appMenuBar, cx);
        });

        // Observe theme changes to update the menu to refresh the checked state
        cx.observeGlobal(Theme, cx -> {
            updateAppMenu(title, appMenuBar, cx);
        }).detach();

        return appMenuBar;
    }

    static function updateAppMenu(title:String, appMenuBar:Entity<AppMenuBar>, cx:AppContext):Void {
        // Ceramic has no native menu bar yet: the platform keeps the menus
        // (`cx.getMenus()`), the title bar draws them
        cx.setMenus(buildMenus(title, cx));
        final menus = [for (menu in buildMenus(title, cx)) menu.owned()];
        GlobalState.globalMut(cx).setAppMenus(menus);

        appMenuBar.update(cx, (menuBar, cx) -> {
            menuBar.reload(cx);
        });
    }

    public static function buildMenus(title:String, cx:AppContext):Array<Menu> {
        final isDark = Theme.global(cx).mode.isDark();
        return [
            new Menu(title).withItems([
                MenuItemTools.action('About', new About()),
                MenuItemTools.separator(),
                MenuItemTools.action('Open...', new Open()),
                MenuItemTools.separator(),
                MenuItemTools.submenu(new Menu('Appearance').withItems([
                    MenuItemTools.action('Light', new SwitchThemeMode(ThemeMode.Light)).checked(!isDark),
                    MenuItemTools.action('Dark', new SwitchThemeMode(ThemeMode.Dark)).checked(isDark),
                ])),
                languageMenu(cx),
                MenuItemTools.separator(),
                MenuItemTools.action('Quit', new Quit()),
            ]),
            new Menu('Edit').withItems([
                MenuItemTools.action('Undo', new Undo()),
                MenuItemTools.action('Redo', new Redo()),
                MenuItemTools.separator(),
                MenuItemTools.action('Cut', new Cut()),
                MenuItemTools.action('Copy', new Copy()),
                MenuItemTools.action('Paste', new Paste()),
                MenuItemTools.separator(),
                MenuItemTools.action('Delete', new Delete()),
                MenuItemTools.action('Delete Previous Word', new DeleteToPreviousWordStart()),
                MenuItemTools.action('Delete Next Word', new DeleteToNextWordEnd()),
                MenuItemTools.separator(),
                MenuItemTools.action('Find', new Search()),
                MenuItemTools.separator(),
                MenuItemTools.action('Select All', new SelectAll()),
            ]),
            new Menu('Go').withItems([
                MenuItemTools.action('Go to...', new OpenCommandPalette()),
                MenuItemTools.action('Themes...', new SelectTheme()),
            ]),
            new Menu('Help').withItems([
                MenuItemTools.action('Documentation', new Open()).disabled(true),
                MenuItemTools.separator(),
                MenuItemTools.action('Open Website', new Open()),
            ]),
        ];
    }

    static function languageMenu(_:App):MenuItem {
        final locale = I18n.locale();
        return MenuItemTools.submenu(new Menu('Language').withItems([
            MenuItemTools.action('English', new SelectLocale('en')).checked(locale == 'en'),
            MenuItemTools.action('简体中文', new SelectLocale('zh-CN')).checked(locale == 'zh-CN'),
            MenuItemTools.action('Français', new SelectLocale('fr')).checked(locale == 'fr'),
        ]));
    }

}
