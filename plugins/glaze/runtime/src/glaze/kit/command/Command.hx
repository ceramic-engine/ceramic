// Ported from gpui-kit 0.8.1: crates/component/src/command/command.rs, crates/component/src/command/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.command;

import glaze.AnyElement;
import glaze.App;
import glaze.DefiniteLength;
import glaze.Entity;
import glaze.IntoDefiniteLength;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.command.CommandItem.CommandEntry;
import glaze.kit.command.CommandItem.CommandGroup;
import glaze.kit.command.CommandState.CommandModel;
import glaze.kit.command.CommandState.OnCancel;
import glaze.kit.command.CommandState.OnIndex;
import glaze.kit.command.CommandState.OnQuery;

import glaze.Prelude.*;

/**
 * A slot of the palette (Rust `CommandSlot`): header, footer or empty content.
 */
typedef CommandSlot = (CommandState, Window, App) -> AnyElement;

/**
 * Presentation of a `Command`, pushed into its state on every render.
 */
@:allow(glaze.kit.command, tests)
class CommandOptions {

    public var style:StyleRefinement = new StyleRefinement();
    public var placeholder:Null<String> = null;
    public var empty:Null<CommandSlot> = null;
    public var maxH:DefiniteLength = DefiniteLength.Absolute(AbsoluteLength.Rems(18.75));
    public var scrollBounce:Null<Bool> = null;
    public var bordered:Bool = true;
    public var header:Null<CommandSlot> = null;
    public var footer:Null<CommandSlot> = null;

    public function new() {}

}

/**
 * A command palette: a search field over a filtered list of commands, with
 * groups, Action keybinding hints and keyboard navigation.
 *
 * Entries and rendering policy are configured on each `Command`; interaction
 * state such as the query and highlighted item lives in `CommandState`.
 *
 * ```haxe
 * final state = cx.newEntity(c -> new CommandState(window, c));
 *
 * new Command(state)
 *     .group(new CommandGroup().label('Suggestions')
 *         .item(new CommandItem().label('Calendar').icon(IconName.Calendar)))
 *     .placeholder('Type a command or search...');
 * ```
 */
class Command implements RenderOnce implements Styled {

    final state:Entity<CommandState>;

    final entries:Array<CommandEntry> = [];

    var searchableValue:Bool = true;

    var filterableValue:Bool = true;

    var onQueryHandler:Null<OnQuery> = null;

    var onSelectHandler:Null<OnIndex> = null;

    var onConfirmHandler:Null<OnIndex> = null;

    var onCancelHandler:Null<OnCancel> = null;

    final options:CommandOptions = new CommandOptions();

    /**
     * Render the palette held by `state`.
     */
    public function new(state:Entity<CommandState>) {
        this.state = state;
    }

    /**
     * Add an ungrouped command item.
     */
    public function item(item:CommandItem):Command {
        entries.push(Item(item));
        return this;
    }

    /**
     * Add multiple ungrouped command items.
     */
    public function items(items:Array<CommandItem>):Command {
        for (item in items) entries.push(Item(item));
        return this;
    }

    /**
     * Add a group of command items.
     */
    public function group(group:CommandGroup):Command {
        entries.push(Group(group));
        return this;
    }

    /**
     * Add a separator between the preceding and following entries.
     */
    public function separator():Command {
        entries.push(Separator);
        return this;
    }

    /**
     * Show or hide the query field and local filtering.
     */
    public function searchable(searchable:Bool):Command {
        searchableValue = searchable;
        return this;
    }

    /**
     * Keep the query field but toggle the local filtering, default: `true`.
     *
     * Turn it off when an external source already answers the query, such as
     * an async search: every supplied item stays visible, the query still
     * reports through `onQuery`, and a query change hands the highlight back
     * to the first item instead of a local textual match.
     */
    public function filterable(filterable:Bool):Command {
        filterableValue = filterable;
        return this;
    }

    /**
     * Run a callback after a searchable query actually changes and the
     * current `CommandState` update releases its lease.
     */
    public function onQuery(callback:(String, Window, App) -> Void):Command {
        onQueryHandler = callback;
        return this;
    }

    /**
     * Run a callback after the highlighted item's original index path changes and the current
     * `CommandState` update releases its lease.
     *
     * For `items`, `section` is 0 and `row` is the item's position in the
     * supplied array. Explicit groups use their group and item positions and
     * follow the implicit ungrouped section when both forms are mixed. Local
     * filtering never changes these coordinates.
     */
    public function onSelect(callback:(IndexPath, Window, App) -> Void):Command {
        onSelectHandler = callback;
        return this;
    }

    /**
     * Run a callback with the confirmed item's original index path after its Action is dispatched,
     * provided the source window remains live. The callback runs after the
     * current `CommandState` update releases its lease.
     * The path follows the same input-model coordinates as `onSelect`.
     */
    public function onConfirm(callback:(IndexPath, Window, App) -> Void):Command {
        onConfirmHandler = callback;
        return this;
    }

    /**
     * Run a callback synchronously before an empty-query Cancel action
     * propagates. A hosting Dialog should perform the dismissal after this
     * callback instead of being closed by the callback itself.
     */
    public function onCancel(callback:(Window, App) -> Void):Command {
        onCancelHandler = callback;
        return this;
    }

    /**
     * Set the placeholder of the search field.
     */
    public function placeholder(placeholder:String):Command {
        options.placeholder = placeholder;
        return this;
    }

    /**
     * Render custom content when no command matches the query.
     */
    public function empty(f:(CommandState, Window, App) -> IntoElement):Command {
        options.empty = (state, window, cx) -> (f(state, window, cx):AnyElement);
        return this;
    }

    /**
     * Set the max height of the list, default: 18.75rem (300px).
     */
    public function maxH(height:IntoDefiniteLength):Command {
        options.maxH = height;
        return this;
    }

    /**
     * Bounce the command list at its vertical boundaries. On by default on iOS,
     * Android and macOS, off elsewhere; reduced motion disables displacement.
     */
    public function scrollBounce(enabled:Bool):Command {
        options.scrollBounce = enabled;
        return this;
    }

    /**
     * Set whether to draw the surrounding border and rounding, default: `true`.
     *
     * Turn it off when the palette already sits inside a frame of its own,
     * such as a `Dialog`.
     */
    public function bordered(bordered:Bool):Command {
        options.bordered = bordered;
        return this;
    }

    /**
     * Render a custom element above the search field and command list.
     */
    public function header(f:(CommandState, Window, App) -> IntoElement):Command {
        options.header = (state, window, cx) -> (f(state, window, cx):AnyElement);
        return this;
    }

    /**
     * Render a custom element below the command list.
     */
    public function footer(f:(CommandState, Window, App) -> IntoElement):Command {
        options.footer = (state, window, cx) -> (f(state, window, cx):AnyElement);
        return this;
    }

    public inline function style():StyleRefinement {
        return options.style;
    }

    public function render(window:Window, cx:App):IntoElement {
        final options = this.options;
        final model = new CommandModel();
        model.entries = entries;
        model.searchable = searchableValue;
        model.filterable = filterableValue;
        model.onQuery = onQueryHandler;
        model.onSelect = onSelectHandler;
        model.onConfirm = onConfirmHandler;
        model.onCancel = onCancelHandler;
        // Installing the model reads and writes the state's observable
        // fields; the view rendering this element must not track them, or
        // every install would schedule it again (the state renders itself).
        tracker.Autorun.unobserve();
        state.update(cx, (state, cx) -> {
            state.setOptions(options);
            state.installModel(model, cx);
        });
        tracker.Autorun.reobserve();

        return state;
    }

}
