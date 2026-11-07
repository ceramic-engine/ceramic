// Ported from gpui-kit 0.8.1: crates/component/src/command/item.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.command;

import gpui.Action;
import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.Window;
import gpui.base.ComponentTraits.Disableable;
import gpui.component.Icon;
import gpui.component.Icon.IntoIcon;

/**
 * The lazily built content of a command item (Rust `CommandItemContent`).
 */
typedef CommandItemContent = (Window, App) -> AnyElement;

/**
 * A single command in a `Command` palette.
 */
class CommandItem implements Disableable {

    var labelValue:Null<String> = null;

    var keywordsValue:Array<String> = [];

    @:allow(gpui.component.command, tests)
    var iconValue:Null<Icon> = null;

    @:allow(gpui.component.command, tests)
    var actionValue:Null<Action> = null;

    @:allow(gpui.component.command, tests)
    var checkedValue:Bool = false;

    var disabledValue:Bool = false;

    @:allow(gpui.component.command, tests)
    var content:Null<CommandItemContent> = null;

    /**
     * Create an empty command item.
     */
    public function new() {}

    /**
     * Rust `Clone`: the Action is cloned with `boxedClone`, the lazy child
     * is shared.
     */
    public function clone():CommandItem {
        final item = new CommandItem();
        item.labelValue = labelValue;
        item.keywordsValue = keywordsValue.copy();
        item.iconValue = iconValue != null ? iconValue.clone() : null;
        item.actionValue = actionValue != null ? actionValue.boxedClone() : null;
        item.checkedValue = checkedValue;
        item.disabledValue = disabledValue;
        item.content = content;
        return item;
    }

    /**
     * Set the label to display and search.
     */
    public function label(label:String):CommandItem {
        labelValue = label;
        return this;
    }

    /**
     * Set the leading icon.
     */
    public function icon(icon:IntoIcon):CommandItem {
        iconValue = (icon:Icon);
        return this;
    }

    /**
     * Set the Action dispatched when this item is clicked or confirmed.
     *
     * The Action's active keybinding is also shown by the default row.
     */
    public function action(action:Action):CommandItem {
        actionValue = action;
        return this;
    }

    /**
     * Mark this item as the chosen one, drawing a check at the right end of
     * the row.
     *
     * A resolved Action binding takes that slot, so an item with one shows no
     * check.
     */
    public function checked(checked:Bool):CommandItem {
        checkedValue = checked;
        return this;
    }

    /**
     * Add extra terms the search matches against, besides the label.
     */
    public function keywords(keywords:Array<String>):CommandItem {
        for (keyword in keywords) keywordsValue.push(keyword);
        return this;
    }

    /**
     * Replace the row content (icon and label) with a lazily built child.
     *
     * The builder may run more than once for measurement and rendering, so it
     * must be side-effect-free. Custom children own their complete visual
     * presentation, including any keybinding hint.
     */
    public function child(builder:(Window, App) -> IntoElement):CommandItem {
        if (builder != null) content = (window, cx) -> (builder(window, cx):AnyElement);
        return this;
    }

    public function disabled(disabled:Bool):CommandItem {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    /** Whether this item is non-interactive. */
    @:allow(gpui.component.command, tests)
    function isDisabled():Bool {
        return disabledValue;
    }

    /**
     * Whether this item matches the search query, ignoring case.
     *
     * An empty query matches everything.
     */
    @:allow(gpui.component.command, tests)
    function matches(query:String):Bool {
        if (query.length == 0) return true;

        final query = query.toLowerCase();

        if (labelValue != null && labelValue.toLowerCase().indexOf(query) != -1) return true;
        for (keyword in keywordsValue) {
            if (keyword.toLowerCase().indexOf(query) != -1) return true;
        }
        return false;
    }

    @:allow(gpui.component.command, tests)
    function labelText():Null<String> {
        return labelValue;
    }

    /**
     * Whether `other` filters and measures exactly like this item, so a
     * palette can keep its rows and row sizes when a host re-render rebuilds
     * an unchanged model.
     *
     * An item with a custom child never counts as unchanged, even when it is
     * a clone sharing the same closure: the child can read state outside the
     * item, so only laying it out again tells whether its height changed.
     */
    @:allow(gpui.component.command, tests)
    function sameLayout(other:CommandItem):Bool {
        if (content != null || other.content != null) return false;
        if (labelValue != other.labelValue) return false;
        if (keywordsValue.length != other.keywordsValue.length) return false;
        for (i in 0...keywordsValue.length) {
            if (keywordsValue[i] != other.keywordsValue[i]) return false;
        }
        if (iconValue != null && other.iconValue != null) {
            if (!StyleRefinementEq.iconSameLayout(iconValue, other.iconValue)) return false;
        } else if (iconValue != null || other.iconValue != null) {
            return false;
        }
        if (checkedValue != other.checkedValue) return false;
        if (disabledValue != other.disabledValue) return false;
        if (actionValue != null && other.actionValue != null) {
            return actionValue.partialEq(other.actionValue);
        }
        return actionValue == null && other.actionValue == null;
    }

}

/**
 * A titled section of `CommandItem`s.
 *
 * The heading is hidden while every item in the group is filtered out.
 */
class CommandGroup {

    var headingValue:Null<String> = null;

    @:allow(gpui.component.command, tests)
    var items:Array<CommandItem> = [];

    /**
     * Create a new group without a label.
     */
    public function new() {}

    public function clone():CommandGroup {
        final group = new CommandGroup();
        group.headingValue = headingValue;
        group.items = [for (item in items) item.clone()];
        return group;
    }

    /**
     * Set the label displayed above the group's items.
     */
    public function label(label:String):CommandGroup {
        headingValue = label;
        return this;
    }

    /**
     * Add an item to the group.
     */
    public function item(item:CommandItem):CommandGroup {
        items.push(item);
        return this;
    }

    /**
     * Add multiple items to the group (Rust `items`, renamed: `items` is a field).
     */
    public function withItems(items:Array<CommandItem>):CommandGroup {
        for (item in items) this.items.push(item);
        return this;
    }

    /**
     * The heading of the group, when it has one.
     */
    public function heading():Null<String> {
        return headingValue;
    }

    @:allow(gpui.component.command, tests)
    function sameLayout(other:CommandGroup):Bool {
        if (headingValue != other.headingValue || items.length != other.items.length) return false;
        for (i in 0...items.length) {
            if (!items[i].sameLayout(other.items[i])) return false;
        }
        return true;
    }

}

/**
 * A top-level entry in a `Command`.
 */
@:using(gpui.component.command.CommandItem.CommandEntryTools)
enum CommandEntry {
    /** A single ungrouped item. */
    Item(item:CommandItem);
    /** A titled group of items. */
    Group(group:CommandGroup);
    /**
     * A divider between groups.
     *
     * A separator that ends up leading, trailing, or next to another
     * separator once the query has filtered the list is not rendered.
     */
    Separator;
}

class CommandEntryTools {

    /**
     * Whether `other` produces the same rows and row sizes as this entry for
     * any query. See `CommandItem.sameLayout`.
     */
    @:allow(gpui.component.command, tests)
    static function sameLayout(self:CommandEntry, other:CommandEntry):Bool {
        return switch [self, other] {
            case [Item(item), Item(other)]: item.sameLayout(other);
            case [Group(group), Group(other)]: group.sameLayout(other);
            case [Separator, Separator]: true;
            case _: false;
        }
    }

    public static function clone(self:CommandEntry):CommandEntry {
        return switch self {
            case Item(item): Item(item.clone());
            case Group(group): Group(group.clone());
            case Separator: Separator;
        }
    }

}
