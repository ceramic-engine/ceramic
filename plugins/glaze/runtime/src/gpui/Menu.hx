// Ported from gpui-pre 0.3.10: src/platform/app_menu.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A menu of the application, either a main menu or a submenu.
 *
 * The port has no platform menu bar (`cx.set_menus`, the macOS menu bar
 * and its validation callbacks are not ported): menus are data, drawn in
 * the window by gpui-kit's `AppMenuBar` (`GlobalState.setAppMenus`).
 */
class Menu {

    /** The name of the menu. */
    public var name:String;

    /** The items in the menu. */
    public var items:Array<MenuItem>;

    /** Whether this menu is disabled. */
    public var disabled:Bool;

    public function new(name:String) {
        this.name = name;
        this.items = [];
        this.disabled = false;
    }

    /**
     * Set the items in the menu.
     */
    public function withItems(items:Array<MenuItem>):Menu {
        this.items = items.copy();
        return this;
    }

    /**
     * Set whether the menu is disabled.
     */
    public function withDisabled(disabled:Bool):Menu {
        this.disabled = disabled;
        return this;
    }

    /**
     * Create an `OwnedMenu` from this menu.
     */
    public function owned():OwnedMenu {
        return new OwnedMenu(name, [for (item in items) MenuItemTools.owned(item)], disabled);
    }

}

/**
 * OS menus are menus that are recognized by the operating system. This
 * allows the operating system to provide specialized items for these menus.
 */
class OsMenu {

    /** The name of the menu. */
    public var name:String;

    /** The type of menu. */
    public var menuType:SystemMenuType;

    public function new(name:String, menuType:SystemMenuType) {
        this.name = name;
        this.menuType = menuType;
    }

    /**
     * Create an `OwnedOsMenu` from this menu.
     */
    public function owned():OwnedOsMenu {
        return new OwnedOsMenu(name, menuType);
    }

}

/**
 * The type of system menu.
 */
enum abstract SystemMenuType(Int) {

    /** The 'Services' menu in the Application menu on macOS. */
    var Services;

}

/**
 * The different kinds of items that can be in a menu. Builders and methods
 * are in `MenuItemTools`.
 */
@:using(gpui.Menu.MenuItemTools)
enum MenuItem {

    /** A separator between items. */
    Separator;

    /** A submenu. */
    Submenu(menu:Menu);

    /** A menu, managed by the system (for example, the Services menu on macOS). */
    SystemMenu(menu:OsMenu);

    /** An action that can be performed. */
    Action(name:String, action:gpui.Action, osAction:Null<OsAction>, checked:Bool, disabled:Bool);

}

/**
 * Builders and methods of `MenuItem`.
 */
class MenuItemTools {

    /** Creates a new menu item that is a separator. */
    public static function separator():MenuItem {
        return MenuItem.Separator;
    }

    /** Creates a new menu item that is a submenu. */
    public static function submenu(menu:Menu):MenuItem {
        return MenuItem.Submenu(menu);
    }

    /** Creates a new submenu that is populated by the OS. */
    public static function osSubmenu(name:String, menuType:SystemMenuType):MenuItem {
        return MenuItem.SystemMenu(new OsMenu(name, menuType));
    }

    /** Creates a new menu item that invokes an action. */
    public static function action(name:String, action:gpui.Action):MenuItem {
        return MenuItem.Action(name, action, null, false, false);
    }

    /** Creates a new menu item that invokes an action and has an OS action. */
    public static function osAction(name:String, action:gpui.Action, osAction:OsAction):MenuItem {
        return MenuItem.Action(name, action, osAction, false, false);
    }

    /** Create an `OwnedMenuItem` from this menu item. */
    public static function owned(self:MenuItem):OwnedMenuItem {
        return switch self {
            case Separator: OwnedMenuItem.Separator;
            case Submenu(submenu): OwnedMenuItem.Submenu(submenu.owned());
            case Action(name, action, osAction, checked, disabled): OwnedMenuItem.Action(name, action, osAction, checked, disabled);
            case SystemMenu(osMenu): OwnedMenuItem.SystemMenu(osMenu.owned());
        }
    }

    /** Set whether this menu item is checked. Only for `Action` items. */
    public static function checked(self:MenuItem, checked:Bool):MenuItem {
        return switch self {
            case Action(name, action, osAction, _, disabled): MenuItem.Action(name, action, osAction, checked, disabled);
            case _: self;
        }
    }

    /** Returns whether this menu item is checked. */
    public static function isChecked(self:MenuItem):Bool {
        return switch self {
            case Action(_, _, _, checked, _): checked;
            case _: false;
        }
    }

    /** Set whether this menu item is disabled (`Action` items and submenus). */
    public static function disabled(self:MenuItem, disabled:Bool):MenuItem {
        return switch self {
            case Action(name, action, osAction, checked, _): MenuItem.Action(name, action, osAction, checked, disabled);
            case Submenu(submenu):
                submenu.disabled = disabled;
                self;
            case _: self;
        }
    }

    /** Returns whether this menu item is disabled. */
    public static function isDisabled(self:MenuItem):Bool {
        return switch self {
            case Action(_, _, _, _, disabled): disabled;
            case Submenu(submenu): submenu.disabled;
            case _: false;
        }
    }

}

/**
 * The owned version of `OsMenu`.
 */
class OwnedOsMenu {

    /** The name of the menu. */
    public final name:String;

    /** The type of menu. */
    public final menuType:SystemMenuType;

    public function new(name:String, menuType:SystemMenuType) {
        this.name = name;
        this.menuType = menuType;
    }

    public function clone():OwnedOsMenu {
        return new OwnedOsMenu(name, menuType);
    }

}

/**
 * A menu of the application, either a main menu or a submenu (owned).
 */
class OwnedMenu {

    /** The name of the menu. */
    public final name:String;

    /** The items in the menu. */
    public final items:Array<OwnedMenuItem>;

    /** Whether this menu is disabled. */
    public final disabled:Bool;

    public function new(name:String, items:Array<OwnedMenuItem>, disabled:Bool = false) {
        this.name = name;
        this.items = items;
        this.disabled = disabled;
    }

    public function clone():OwnedMenu {
        return new OwnedMenu(name, [for (item in items) OwnedMenuItemTools.clone(item)], disabled);
    }

}

/**
 * The different kinds of items that can be in a menu (owned).
 */
@:using(gpui.Menu.OwnedMenuItemTools)
enum OwnedMenuItem {

    /** A separator between items. */
    Separator;

    /** A submenu. */
    Submenu(menu:OwnedMenu);

    /** A menu, managed by the system (for example, the Services menu on macOS). */
    SystemMenu(menu:OwnedOsMenu);

    /** An action that can be performed. */
    Action(name:String, action:gpui.Action, osAction:Null<OsAction>, checked:Bool, disabled:Bool);

}

class OwnedMenuItemTools {

    public static function clone(self:OwnedMenuItem):OwnedMenuItem {
        return switch self {
            case Separator: OwnedMenuItem.Separator;
            case Submenu(submenu): OwnedMenuItem.Submenu(submenu.clone());
            case Action(name, action, osAction, checked, disabled): OwnedMenuItem.Action(name, action.boxedClone(), osAction, checked, disabled);
            case SystemMenu(osMenu): OwnedMenuItem.SystemMenu(osMenu.clone());
        }
    }

}

/**
 * OS actions are actions that are recognized by the operating system. This
 * allows the operating system to provide specialized behavior for these
 * actions.
 */
enum abstract OsAction(Int) {

    /** The 'cut' action. */
    var Cut;

    /** The 'copy' action. */
    var Copy;

    /** The 'paste' action. */
    var Paste;

    /** The 'select all' action. */
    var SelectAll;

    /** The 'undo' action. */
    var Undo;

    /** The 'redo' action. */
    var Redo;

}
