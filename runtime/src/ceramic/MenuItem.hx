package ceramic;

/**
 * An item of the application menu bar, given to `screen.setMenuBar`.
 *
 * The menu bar is a list of submenus (`MenuItem.submenu`), whose items are
 * actions, separators, nested submenus or the system's Services menu.
 * Choosing an action item emits `screen.menuAction(item)`.
 *
 * ```haxe
 * screen.setMenuBar([
 *     MenuItem.submenu('My App', [
 *         MenuItem.action('Quit', 'q', META)
 *     ]),
 *     MenuItem.submenu('Edit', [
 *         MenuItem.action('Copy', 'c', META).withRole(COPY)
 *     ])
 * ]);
 * screen.onMenuAction(this, item -> trace('chosen: ' + item.title));
 * ```
 *
 * Shortcuts (`key` and `modifiers`) are shown in the menu, and a keystroke
 * matching one is first delivered to the app as a regular key down: the
 * menu item is only triggered if no key down listener marked it handled
 * (`input.keyDownHandled`).
 */
class MenuItem {

    /** What this item is. */
    public var kind:MenuItemKind = ACTION;

    /** The text of the item (or of the submenu). */
    public var title:String = '';

    /**
     * The key of the shortcut shown next to the item, or `null`: a single
     * character (`"q"`, `","`) or a key name (`space`, `backspace`,
     * `escape`, `up`, `down`, `left`, `right`, `pageup`, `pagedown`,
     * `home`, `end`, `delete`, `insert`, `f1` to `f35`).
     */
    public var key:Null<String> = null;

    /** The modifiers of the shortcut (`META` is the command key on macOS). */
    public var modifiers:KeyModifiers = NONE;

    /** The standard role of this item, if any. */
    public var role:MenuItemRole = NONE;

    /**
     * Whether the item can be chosen, when no `screen.menuItemValidator`
     * is set (the validator decides otherwise).
     */
    public var enabled:Bool = true;

    /** Whether a check mark is shown next to the item. */
    public var checked:Bool = false;

    /** The items of a submenu. */
    public var items:Null<Array<MenuItem>> = null;

    /** Free for the app: anything it needs to recognize the item. */
    public var data:Any = null;

    /**
     * The identifier given to this item by the last `screen.setMenuBar`
     * call that contained it (`-1` before), used by backends.
     */
    public var id(default, null):Int = -1;

    public function new() {}

    /** An item that emits `screen.menuAction` when chosen. */
    public static function action(title:String, ?key:String, modifiers:KeyModifiers = NONE):MenuItem {
        final item = new MenuItem();
        item.title = title;
        item.key = key;
        item.modifiers = modifiers;
        return item;
    }

    /** A separator line. */
    public static function separator():MenuItem {
        final item = new MenuItem();
        item.kind = SEPARATOR;
        return item;
    }

    /** A submenu with the given items. */
    public static function submenu(title:String, items:Array<MenuItem>):MenuItem {
        final item = new MenuItem();
        item.kind = SUBMENU;
        item.title = title;
        item.items = items;
        return item;
    }

    /** The system's Services submenu (macOS). */
    public static function services(title:String):MenuItem {
        final item = new MenuItem();
        item.kind = SERVICES;
        item.title = title;
        return item;
    }

    /** Sets `role` and returns this item. */
    public function withRole(role:MenuItemRole):MenuItem {
        this.role = role;
        return this;
    }

    /** Sets `enabled` and returns this item. */
    public function withEnabled(enabled:Bool):MenuItem {
        this.enabled = enabled;
        return this;
    }

    /** Sets `checked` and returns this item. */
    public function withChecked(checked:Bool):MenuItem {
        this.checked = checked;
        return this;
    }

    /** Sets `data` and returns this item. */
    public function withData(data:Any):MenuItem {
        this.data = data;
        return this;
    }

    @:allow(ceramic.Screen)
    function assignId(id:Int):Void {
        this.id = id;
    }

    function toString():String {
        return 'MenuItem($kind, $title)';
    }

}
