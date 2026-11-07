// Ported from gpui-pre 0.3.10: src/platform/app_menu.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import gpui.Menu;
import gpui.NoAction;
import testing.TestCase;

using gpui.Menu.MenuItemTools;

class AppMenuTest extends TestCase {

    function testMenu() {
        final menu = new Menu('App')
            .withItems([
                MenuItemTools.action('Action 1', new NoAction()),
                MenuItemTools.separator(),
            ])
            .withDisabled(true);
        assertEquals('App', menu.name);
        assertEquals(2, menu.items.length);
        assertTrue(menu.disabled);
    }

    function testMenuItemBuilder() {
        final item = MenuItemTools.action('Test Action', new NoAction());
        assertEquals('Test Action', switch item {
            case Action(name, _, _, _, _): name;
            case _: null;
        });
        assertTrue(switch item {
            case Action(_, _, _, false, false): true;
            case _: false;
        });
        assertTrue(MenuItemTools.action('Test Action', new NoAction()).checked(true).isChecked());
        assertTrue(MenuItemTools.action('Test Action', new NoAction()).disabled(true).isDisabled());

        final submenu = MenuItemTools.submenu(new Menu('Submenu').withDisabled(true));
        assertEquals('Submenu', switch submenu {
            case Submenu(menu): menu.name;
            case _: null;
        });
        assertFalse(submenu.isChecked());
        assertTrue(submenu.isDisabled());
    }

}
