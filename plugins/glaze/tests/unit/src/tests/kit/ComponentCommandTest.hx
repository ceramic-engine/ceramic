// Ported from gpui-kit 0.8.1: crates/component/src/command/item.rs (tests),
// crates/component/src/command/state.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.Action;
import gpui.AnyElement;
import gpui.App;
import gpui.AvailableSpace;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Model;
import gpui.Point;
import gpui.Render;
import gpui.SizeOf;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Actions.Cancel;
import gpui.base.Actions.Confirm;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectUp;
import gpui.base.IndexPath;
import gpui.component.Component;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.command.Command;
import gpui.component.command.CommandItem;
import gpui.component.command.CommandItem.CommandEntry;
import gpui.component.command.CommandItem.CommandGroup;
import gpui.component.command.CommandState;
import gpui.component.command.CommandState.CommandModel;
import gpui.component.command.CommandState.CommandRow;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

using gpui.component.command.CommandItem.CommandEntryTools;

@:action(namespace = command_item_test) class CloneAction implements Action {}

@:action(namespace = command_test) class GlobalTestItem implements Action {}

@:action(namespace = command_test) class OpenTestItem implements Action {}

@:action(namespace = command_test) class RemovePaletteTestItem implements Action {}

/**
 * The tests of gpui-component's command palette (`command/item.rs`,
 * `command/state.rs`).
 *
 * Rust's `cx.draw(origin, AvailableSpace::min_size(), ...)` probes, which lay
 * an element out as a root at its min-content size, lay the element out with
 * `AnyElement.layoutAsRoot` here. GPUI's `TestAppContext` window is 1920x1080
 * at scale factor 2, like `VisualTestContext.addWindowView`.
 */
class ComponentCommandTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    var visual:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.onEffectsFlushed = app -> {
            if (window != null && window.dirty && !window.isDestroyed()) window.draw();
        };
        app.update(cx -> Component.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (visual != null) visual.destroy();
        visual = null;
        if (window != null) window.destroy();
        window = null;
        ceramic.App.app.flushImmediate();
    }

    /** `cx.add_empty_window()`. */
    function emptyWindow():Void {
        app.update(cx -> {
            window = Window.open(cx, {width: 1920, height: 1080, scaleFactor: 2, autoDraw: false, bindInput: false}, (window, cx) -> {
                return cx.newEntity((c:Context<CommandBlank>) -> new CommandBlank());
            });
        });
        dispatcher.runUntilParked();
    }

    function addWindowView<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final result = VisualTestContext.addWindowView(app, dispatcher, build);
        visual = result.cx;
        return result;
    }

    static function draw(cx:VisualTestContext):Void {
        cx.update((window, _) -> window.draw());
    }

    static inline function ip(row:Int, section:Int = 0):IndexPath {
        return new IndexPath(row).withSection(section);
    }

    static function samePath(a:Null<IndexPath>, b:Null<IndexPath>):Bool {
        if (a == null || b == null) return a == b;
        return a.equals(b);
    }

    static function model(entries:Array<CommandEntry>, searchable:Bool = true, filterable:Bool = true):CommandModel {
        final model = new CommandModel();
        model.entries = entries;
        model.searchable = searchable;
        model.filterable = filterable;
        return model;
    }

    static function commandState(window:Window, cx:Context<CommandState>, entries:Array<CommandEntry>, searchable:Bool = true):CommandState {
        final state = new CommandState(window, cx);
        state.installModel(model(entries, searchable), cx);
        return state;
    }

    static function newCommandState(cx:App, window:Window, entries:Array<CommandEntry>, searchable:Bool = true):Entity<CommandState> {
        return cx.newEntity((c:Context<CommandState>) -> commandState(window, c, entries, searchable));
    }

    static function suggestionEntries():Array<CommandEntry> {
        return [
            CommandEntry.Group(new CommandGroup()
                .label("Suggestions")
                .item(new CommandItem().label("Calendar"))
                .item(new CommandItem().label("Search Emoji"))
                .item(new CommandItem().label("Calculator").disabled(true))),
            CommandEntry.Separator,
            CommandEntry.Group(new CommandGroup()
                .label("Settings")
                .item(new CommandItem().label("Profile"))
                .item(new CommandItem().label("Billing"))),
        ];
    }

    static function countRows(state:CommandState, heading:Bool):Int {
        var count = 0;
        for (row in state.rows) {
            switch row {
                case CommandRow.Heading(_) if (heading): count++;
                case CommandRow.Separator if (!heading): count++;
                case _:
            }
        }
        return count;
    }

    /** The min-content width of a rendered item (Rust `cx.draw` probe). */
    static function itemWidth(state:Entity<CommandState>, matchedIx:Int, window:Window, cx:App, update:Bool = false):Float {
        final item = state.update(cx, (state, cx) -> {
            if (update) state.updateMatches(cx.app);
            return state.renderItem(matchedIx, window, cx);
        });
        final size = div().child(item).intoAnyElement().layoutAsRoot(new SizeOf<AvailableSpace>(MinContent, MinContent), window, cx);
        return size.width;
    }

    // MARK: item.rs

    function testClonedEntriesKeepActionsAndLazyChildrenUsable() {
        var actionCount = 0;
        var childCount = 0;
        app.update(cx -> cx.onAction(CloneAction, (_, _) -> actionCount++));

        final entry = CommandEntry.Group(new CommandGroup().label("Group").item(
            new CommandItem()
                .label("cloneable")
                .action(new CloneAction())
                .child((_, _) -> {
                    childCount++;
                    return div();
                })
        ));
        final cloned = entry.clone();
        final group = switch cloned {
            case CommandEntry.Group(group): group;
            case _: null;
        };
        // the cloned entry should remain a group
        assertTrue(group != null);
        final clonedItem = group.items[0];

        emptyWindow();
        app.update(cx -> {
            final child = clonedItem.content;
            child(window, cx);
            window.dispatchAction(clonedItem.actionValue.boxedClone(), cx);
        });
        dispatcher.runUntilParked();

        assertEquals(1, childCount);
        assertEquals(1, actionCount);
    }

    function testLabelIsOptionalForCustomContent() {
        assertEquals(null, new CommandItem().labelText());
        assertEquals("Calendar", new CommandItem().label("Calendar").labelText());
    }

    function testMatchesLabelAndKeywords() {
        final item = new CommandItem()
            .label("Profile")
            .keywords(["account", "user"]);

        assertTrue(item.matches(""));
        assertTrue(item.matches("PRO"));
        assertTrue(item.matches("Account"));
        assertFalse(item.matches("billing"));
    }

    // MARK: state.rs

    function testQueryAndSelectionCallbacksRunAfterTheStateLeaseInDefinedOrder() {
        final h = addWindowView((window, cx:Context<ReentrantCallbackHarness>) -> new ReentrantCallbackHarness(cx.newEntity(c -> new CommandState(window, c))));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        cx.update((window, cx) -> {
            window.draw();
            state.update(cx, (state, cx) -> {
                state.selectedIndexValue = 1;
                state.setQuery("alpha", window, cx);
            });
        });

        assertEquals("select:0:0,query:alpha", h.view.read(app).events.join(','));
        assertEquals(0, h.view.read(app).failures);
    }

    function testActionlessConfirmCallbackRunsAfterTheStateLease() {
        final h = addWindowView((window, cx:Context<ReentrantCallbackHarness>) -> new ReentrantCallbackHarness(cx.newEntity(c -> new CommandState(window, c))));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        cx.update((window, cx) -> {
            window.draw();
            state.update(cx, (state, cx) -> state.confirm(0, window, cx));
        });

        assertEquals("confirm:0:0", h.view.read(app).events.join(','));
        assertEquals(0, h.view.read(app).failures);
    }

    function testActionThatRemovesCommandStateStillConfirmsAfterDispatch() {
        final events:Array<String> = [];
        var stateOwner:Null<Entity<CommandState>> = null;
        app.update(cx -> cx.onAction(RemovePaletteTestItem, (_, _) -> {
            events.push("action");
            stateOwner = null;
        }));
        emptyWindow();
        app.update(cx -> {
            final state = cx.newEntity((c:Context<CommandState>) -> {
                final state = new CommandState(window, c);
                final m = model([CommandEntry.Item(new CommandItem().label("removed").action(new RemovePaletteTestItem()))], false);
                m.onConfirm = (index, _, _) -> events.push('confirm:${index.section}:${index.row}');
                state.installModel(m, c);
                return state;
            });
            stateOwner = state;
            state.update(cx, (state, cx) -> state.confirm(0, window, cx));
        });
        dispatcher.runUntilParked();

        assertEquals(null, stateOwner);
        assertEquals("action,confirm:0:0", events.join(','));
    }

    function testCommandActionsAndCallbacksFollowDefinedOrder() {
        app.update(cx -> cx.bindKeys([
            new KeyBinding("ctrl-o", new OpenTestItem(), CommandState.CONTEXT),
            new KeyBinding("ctrl-g", new GlobalTestItem(), null),
        ]));
        final events:Array<String> = [];
        final h = addWindowView((window, cx:Context<CommandActionsHarness>) -> new CommandActionsHarness(cx.newEntity(c -> new CommandState(window, c)), events));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        cx.update((window, cx) -> {
            window.draw();
            state.update(cx, (state, cx) -> state.focus(window, cx.app));
            window.draw();
        });

        final widths = cx.update((window, cx) -> [for (ix in 0...3) itemWidth(state, ix, window, cx)]);
        final actionWidth = widths[0];
        final plainWidth = widths[1];
        final globalWidth = widths[2];
        // the scoped Action binding should add a visible Kbd
        assertTrue(actionWidth > plainWidth);
        // the app-level fallback binding should add a visible Kbd
        assertTrue(globalWidth > plainWidth);

        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> {
                state.setQuery("needle", window, cx);
                state.setQuery("needle", window, cx);
                state.setQuery("", window, cx);
            });
            window.dispatchAction(new SelectDown(), cx);
            window.dispatchAction(new SelectUp(), cx);
            window.dispatchAction(new Confirm(false), cx);
        });
        cx.runUntilParked();

        assertEquals("query:needle,query:,select:0:1,select:0:0,action,confirm:0:0", events.join(','));

        cx.simulateClick(new Point(20., 52.));
        cx.runUntilParked();
        cx.update((window, cx) -> window.dispatchAction(new Cancel(), cx));
        cx.runUntilParked();

        assertEquals("query:needle,query:,select:0:1,select:0:0,action,confirm:0:0,action,confirm:0:0,cancel,propagated_cancel", events.join(','));
    }

    function testCommandOwnsEntriesAndLazyItemContent() {
        final h = addWindowView((window, cx:Context<CommandOwnedEntriesHarness>) -> new CommandOwnedEntriesHarness(cx.newEntity(c -> new CommandState(window, c))));
        final cx = h.cx;

        cx.runUntilParked();
        draw(cx);

        final state = h.view.read(app).state.read(app);
        final labels = [for (matchedIx in 0...state.matchedCount()) state.itemAt(matchedIx).labelText()];

        assertEquals("alpha,beta,custom", labels.join(','));
        final rows = state.rows;
        assertEquals(5, rows.length);
        assertTrue(rows[0].match(CommandRow.Item(_)));
        assertTrue(rows[1].match(CommandRow.Heading("Settings")));
        assertTrue(rows[2].match(CommandRow.Item(_)));
        assertTrue(rows[3].match(CommandRow.Separator));
        assertTrue(rows[4].match(CommandRow.Item(_)));
        assertEquals(84., state.rowSizes[4].height);
    }

    function testQueryHidesTheGroupsThatHaveNoMatch() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, suggestionEntries());

            state.update(cx, (state, cx) -> {
                state.updateMatches(cx.app);
                assertEquals(5, state.matchedCount());
                assertEquals(2, countRows(state, true));
                assertEquals(1, countRows(state, false));

                // "Bil" only matches an item of the second group, so the first
                // group's heading and the separator between them both go.
                state.setQuery("Bil", window, cx);
                state.updateMatches(cx.app);

                assertEquals(1, state.matchedCount());
                assertTrue(samePath(ip(1, 1), state.selectedIndex()));
                assertEquals(0, countRows(state, false));
                assertTrue(state.rows[0].match(CommandRow.Heading(_)));
            });
        });
    }

    static function customEntries():Array<CommandEntry> {
        return [CommandEntry.Item(new CommandItem().label("Custom").child((_, _) -> div()))];
    }

    function testReinstallingAnUnchangedModelKeepsTheMeasuredRows() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, suggestionEntries());

            state.update(cx, (state, cx) -> {
                // A host re-render rebuilds an equal model: nothing to lay out again.
                state.needsMeasure = false;
                state.installModel(model(suggestionEntries()), cx);
                assertFalse(state.needsMeasure);
                assertEquals(5, state.matchedCount());

                // A custom child can read state outside the item, so it is
                // always measured again.
                state.installModel(model(customEntries()), cx);
                assertTrue(state.needsMeasure);
                assertEquals(1, state.matchedCount());

                // Even when the host clones entries it built once, which
                // keeps the same closure.
                state.needsMeasure = false;
                final entries = [for (entry in state.model.entries) entry.clone()];
                state.installModel(model(entries), cx);
                assertTrue(state.needsMeasure);

                // A changed label or icon style changes how the label wraps,
                // and a changed disabled flag changes what can be highlighted.
                final item = () -> new CommandItem().label("Renamed");
                final icon = () -> new Icon(IconName.Check);
                for (entries in [
                    [CommandEntry.Item(item())],
                    [CommandEntry.Item(item().icon(icon()))],
                    [CommandEntry.Item(item().icon(icon().ml2()))],
                    [CommandEntry.Item(item().icon(icon().ml2()).disabled(true))],
                ]) {
                    state.needsMeasure = false;
                    state.installModel(model(entries), cx);
                    assertTrue(state.needsMeasure);
                }
                assertEquals(null, state.selectedIndex());
            });
        });
    }

    function testAQueryThatMatchesNothingLeavesNoRows() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, suggestionEntries());

            state.update(cx, (state, cx) -> {
                state.setQuery("zzz", window, cx);
                state.updateMatches(cx.app);

                assertEquals(0, state.matchedCount());
                assertEquals(0, state.rows.length);
                assertEquals(null, state.selectedIndex());
            });
        });
    }

    function testFilterableOffKeepsEveryItemAndResetsTheHighlight() {
        emptyWindow();
        app.update(cx -> {
            final state = cx.newEntity((c:Context<CommandState>) -> {
                final state = new CommandState(window, c);
                state.installModel(model(suggestionEntries(), true, false), c);
                return state;
            });

            state.update(cx, (state, cx) -> {
                state.setSelectedIndex(ip(1, 1), window, cx);

                // "Bil" would locally match only "Billing"; an unfiltered
                // palette keeps every row and hands the highlight back to the
                // first item instead of the textual match.
                state.setQuery("Bil", window, cx);

                assertEquals(5, state.matchedCount());
                assertTrue(samePath(ip(0, 0), state.selectedIndex()));
            });
        });
    }

    function testKeywordsMatchWhenTheLabelDoesNot() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, [CommandEntry.Item(new CommandItem().label("Profile").keywords(["account"]))]);

            state.update(cx, (state, cx) -> {
                state.setQuery("account", window, cx);
                state.updateMatches(cx.app);

                assertEquals(1, state.matchedCount());
            });
        });
    }

    function testNonSearchableCommandKeepsEveryItem() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, [
                CommandEntry.Item(new CommandItem().label("alpha")),
                CommandEntry.Item(new CommandItem().label("beta")),
            ], false);
            state.update(cx, (state, cx) -> {
                state.setQuery("missing", window, cx);
                assertEquals(2, state.matchedCount());
            });
        });
    }

    function harness(command:(Entity<CommandState>) -> Command):{view:Entity<CommandHarness>, cx:VisualTestContext} {
        return addWindowView((window, cx:Context<CommandHarness>) -> new CommandHarness(cx.newEntity(c -> new CommandState(window, c)), command));
    }

    function testNonSearchableCommandUsesFrameFocus() {
        var confirmed:Null<IndexPath> = null;
        final h = harness(state -> new Command(state)
            .searchable(false)
            .item(new CommandItem().label("alpha"))
            .item(new CommandItem().label("beta"))
            .onConfirm((indexPath, _, _) -> confirmed = indexPath));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.focus(window, cx.app));
            assertTrue(state.read(cx).focusHandleValue.isFocused(window));
            window.dispatchAction(new SelectDown(), cx);
            window.dispatchAction(new Confirm(false), cx);
        });

        assertTrue(samePath(ip(1, 0), confirmed));
    }

    function testFilteredUngroupedItemKeepsItsInputRow() {
        var confirmed:Null<IndexPath> = null;
        final h = harness(state -> new Command(state)
            .items([
                new CommandItem().label("alpha"),
                new CommandItem().label("beta"),
                new CommandItem().label("gamma"),
            ])
            .onConfirm((indexPath, _, _) -> confirmed = indexPath));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> {
                state.setQuery("gamma", window, cx);
                state.focus(window, cx.app);
            });
            window.dispatchAction(new Confirm(false), cx);
        });

        assertTrue(samePath(ip(2, 0), confirmed));
    }

    function testInitiallyRenderedDisabledFirstItemSelectsAndConfirmsTheFirstEnabledItem() {
        var confirmed:Null<IndexPath> = null;
        final h = harness(state -> new Command(state)
            .item(new CommandItem().label("disabled").disabled(true))
            .item(new CommandItem().label("enabled"))
            .onConfirm((indexPath, _, _) -> confirmed = indexPath));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.focus(window, cx.app));
            window.dispatchAction(new Confirm(false), cx);
        });

        assertTrue(samePath(ip(1, 0), state.read(app).selectedIndex()));
        assertTrue(samePath(ip(1, 0), confirmed));
    }

    function testInitiallyRenderedAllDisabledItemsHaveNoSelectedIndexAndIgnoreEnter() {
        var confirmed:Null<IndexPath> = null;
        final h = harness(state -> new Command(state)
            .item(new CommandItem().label("one").disabled(true))
            .item(new CommandItem().label("two").disabled(true))
            .onConfirm((indexPath, _, _) -> confirmed = indexPath));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.focus(window, cx.app));
            window.dispatchAction(new Confirm(false), cx);
        });

        assertEquals(null, state.read(app).selectedIndex());
        assertEquals(null, confirmed);
    }

    function testNonSearchableCommandCancelsWithoutClearingAHiddenQuery() {
        var cancelled = false;
        var queryCalls = 0;
        final h = harness(state -> new Command(state)
            .searchable(false)
            .item(new CommandItem().label("alpha"))
            .onQuery((_, _, _) -> queryCalls++)
            .onCancel((_, _) -> cancelled = true));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> {
                state.setQuery("hidden query", window, cx);
                state.focus(window, cx.app);
            });
            window.dispatchAction(new Cancel(), cx);
        });

        assertTrue(cancelled);
        assertEquals(0, queryCalls);
        assertEquals("hidden query", state.read(app).query(app));
    }

    function testMovingTheHighlightSkipsDisabledItemsAndWraps() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, suggestionEntries());

            state.update(cx, (state, cx) -> {
                state.updateMatches(cx.app);
                state.resetSelection();
                assertTrue(samePath(ip(0, 0), state.selectedIndex()));

                state.selectBy(1, window, cx);
                assertTrue(samePath(ip(1, 0), state.selectedIndex()));

                // "Calculator" is disabled, so it is stepped over.
                state.selectBy(1, window, cx);
                assertTrue(samePath(ip(0, 1), state.selectedIndex()));

                state.selectBy(-1, window, cx);
                assertTrue(samePath(ip(1, 0), state.selectedIndex()));

                // Wraps around the end, skipping the disabled item again.
                state.selectBy(-1, window, cx);
                assertTrue(samePath(ip(0, 0), state.selectedIndex()));
                state.selectBy(-1, window, cx);
                assertTrue(samePath(ip(1, 1), state.selectedIndex()));
            });
        });
    }

    function testOwnerCanSetAndClearSelectionByOriginalIndexPath() {
        emptyWindow();
        app.update(cx -> {
            final initiallyEmpty = cx.newEntity((c:Context<CommandState>) -> new CommandState(window, c));
            initiallyEmpty.update(cx, (state, cx) -> {
                state.setSelectedIndex(null, window, cx);
                state.installModel(model(suggestionEntries()), cx);
                assertEquals(null, state.selectedIndex());
            });

            final state = newCommandState(cx, window, suggestionEntries());

            state.update(cx, (state, cx) -> {
                final target = ip(1, 1);
                state.setSelectedIndex(target, window, cx);
                assertTrue(samePath(target, state.selectedIndex()));

                state.setSelectedIndex(null, window, cx);
                assertEquals(null, state.selectedIndex());

                state.installModel(model(suggestionEntries()), cx);
                assertEquals(null, state.selectedIndex());

                state.setQuery("calendar", window, cx);
                state.setSelectedIndex(target, window, cx);
                assertEquals(null, state.selectedIndex());
            });
        });
    }

    function testConfirmingADisabledItemDoesNothing() {
        emptyWindow();
        app.update(cx -> {
            final state = newCommandState(cx, window, [
                CommandEntry.Item(new CommandItem().label("enabled")),
                CommandEntry.Item(new CommandItem().label("disabled").disabled(true)),
            ]);

            state.update(cx, (state, cx) -> {
                state.updateMatches(cx.app);

                assertEquals(2, state.matchedCount());
                // Reaching the disabled row is only possible with the mouse or
                // an explicit index; confirming it must be a no-op.
                state.confirm(1, window, cx);
                assertEquals(0, state.selectedIndexValue);
            });
        });
    }

    function testACheckedItemUsesAnXsmallTrailingCheckIcon() {
        emptyWindow();
        final widths = app.update(cx -> {
            final unchecked = newCommandState(cx, window, [CommandEntry.Item(new CommandItem().label("theme"))]);
            final checked = newCommandState(cx, window, [CommandEntry.Item(new CommandItem().label("theme").checked(true))]);
            return [itemWidth(unchecked, 0, window, cx, true), itemWidth(checked, 0, window, cx, true)];
        });

        assertEquals(20., widths[1] - widths[0]);
    }

    function testHeaderAndFooterRenderWithCurrentState() {
        final h = addWindowView((window, cx:Context<HeaderFooterHarness>) -> new HeaderFooterHarness(cx.newEntity(c -> new CommandState(window, c))));
        final cx = h.cx;

        cx.runUntilParked();
        draw(cx);

        final harness = h.view.read(app);
        assertTrue(harness.headerCalls > 0);
        assertTrue(harness.footerCalls > 0);
        assertEquals(2, harness.headerMatchedCount);
        assertEquals(2, harness.footerMatchedCount);
    }

    function testCustomEmptySlotRendersWithCurrentState() {
        var emptyCalls = 0;
        var emptyMatchedCount:Null<Int> = null;
        final h = harness(state -> new Command(state).empty((state, _, _) -> {
            emptyCalls++;
            emptyMatchedCount = state.matchedCount();
            return div().child("Custom empty");
        }));
        final cx = h.cx;

        cx.runUntilParked();
        draw(cx);

        assertTrue(emptyCalls > 0);
        assertEquals(0, emptyMatchedCount);
    }

    static function entriesWithLateFirstEnabledItem():Array<CommandEntry> {
        return [
            CommandEntry.Group(new CommandGroup()
                .label("Disabled")
                .withItems([for (ix in 0...30) new CommandItem().label('disabled-$ix').keywords(["match"]).disabled(true)])),
            CommandEntry.Separator,
            CommandEntry.Group(new CommandGroup()
                .label("Enabled")
                .item(new CommandItem().label("enabled").keywords(["match"]))),
        ];
    }

    static function commandWithEntries(state:Entity<CommandState>, entries:Array<CommandEntry>):Command {
        var command = new Command(state);
        for (entry in entries) {
            command = switch entry {
                case CommandEntry.Item(item): command.item(item);
                case CommandEntry.Group(group): command.group(group);
                case CommandEntry.Separator: command.separator();
            }
        }
        return command;
    }

    function assertFirstEnabledRowIsScrolledIntoView(state:Entity<CommandState>):Void {
        final s = state.read(app);
        final selectedRow = s.matched[s.selectedIndexValue].rowIx;
        final offset = s.scrollHandle.baseHandle().offset().y;

        assertTrue(selectedRow > 30);
        // the list should scroll to the selected row, not row zero
        assertTrue(offset < -900.);
    }

    function testFirstEnabledSelectionResetsScrollToItsLateRow() {
        final h = harness(state -> commandWithEntries(state, entriesWithLateFirstEnabledItem()));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        assertFirstEnabledRowIsScrolledIntoView(state);

        cx.update((window, cx) -> {
            state.update(cx, (state, cx) -> state.setQuery("match", window, cx));
            window.draw();
        });
        assertFirstEnabledRowIsScrolledIntoView(state);

        cx.update((window, cx) -> {
            h.view.update(cx, (_, cx) -> cx.notify());
            window.draw();
        });
        assertFirstEnabledRowIsScrolledIntoView(state);
    }

    function rowHeight(view:Entity<Dynamic>, state:Entity<CommandState>, row:Int):Float {
        return state.read(app).rowSizes[row].height;
    }

    function testWrappingRowsRemeasureForTheListContentWidth() {
        final h = addWindowView((window, cx:Context<WrappingHarness>) -> new WrappingHarness(cx.newEntity(c -> new CommandState(window, c)), 360.));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.runUntilParked();
        draw(cx);

        final wide = state.read(app).rowSizes[0].height;

        cx.update((_, cx) -> h.view.update(cx, (harness, cx) -> {
            harness.width = 120.;
            cx.notify();
        }));
        cx.runUntilParked();
        draw(cx);
        cx.runUntilParked();
        draw(cx);
        final narrow = state.read(app).rowSizes[0].height;

        // the narrow list should cache a taller wrapped row
        assertTrue(narrow > wide);
    }

    function testWrappingRowsRemeasureWhenRemSizeChanges() {
        final h = addWindowView((window, cx:Context<WrappingHarness>) -> {
            window.setRemSize(20.);
            return new WrappingHarness(cx.newEntity(c -> new CommandState(window, c)), 160.);
        });
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.runUntilParked();
        draw(cx);
        final smallerRem = state.read(app).rowSizes[0].height;

        cx.update((window, cx) -> {
            window.setRemSize(28.);
            window.draw();
        });
        cx.runUntilParked();
        draw(cx);
        final largerRem = state.read(app).rowSizes[0].height;

        // a larger rem should remeasure the fixed-width wrapped row
        assertTrue(largerRem > smallerRem);
    }

    function testWrappingRowsRemeasureWhenInheritedTypographyChanges() {
        final h = addWindowView((window, cx:Context<WrappingHarness>) -> new WrappingHarness(cx.newEntity(c -> new CommandState(window, c)), 160.));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.runUntilParked();
        draw(cx);
        final wrappedHeight = state.read(app).rowSizes[0].height;

        cx.update((window, cx) -> {
            h.view.update(cx, (harness, cx) -> {
                harness.noWrap = true;
                cx.notify();
            });
            window.draw();
        });
        cx.runUntilParked();
        draw(cx);
        final noWrapHeight = state.read(app).rowSizes[0].height;
        // a changed inherited typography should remeasure the fixed-width row
        assertTrue(noWrapHeight < wrappedHeight);
    }

    function testOuterCommandPaddingDoesNotInflateMeasuredRowHeights() {
        final h = harness(state -> new Command(state)
            .item(new CommandItem().label("fixed").child((_, _) -> div().h(px(32.))))
            .p4());
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.runUntilParked();
        draw(cx);

        assertEquals(44., state.read(app).rowSizes[0].height);
    }

    function testCustomRowsKeepIndependentHeights() {
        final h = harness(state -> new Command(state)
            .group(new CommandGroup().label("Short").item(new CommandItem().label("short").child((_, _) -> div().h(px(32.)))))
            .separator()
            .group(new CommandGroup().label("Tall").item(new CommandItem().label("tall").child((_, _) -> div().h(px(72.))))));
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        final rowSizes = state.read(app).rowSizes;

        assertEquals(5, rowSizes.length);
        assertTrue(rowSizes[0].height > 0.);
        assertEquals(44., rowSizes[1].height);
        assertEquals(CommandState.SEPARATOR_ROW_HEIGHT, rowSizes[2].height);
        assertTrue(rowSizes[3].height > 0.);
        assertEquals(84., rowSizes[4].height);
    }

    function testReinstallingAModelPreservesSelectionByIndexPathAndRemeasuresRows() {
        var reversed = false;
        final h = harness(state -> {
            final alpha = new CommandItem().label("alpha").child((_, _) -> div().h(px(32.)));
            final beta = new CommandItem().label("beta").child((_, _) -> div().h(px(72.)));
            return reversed ? new Command(state).item(beta).item(alpha) : new Command(state).item(alpha).item(beta);
        });
        final cx = h.cx;
        final state = h.view.read(app).state;

        cx.runUntilParked();
        draw(cx);
        cx.update((window, cx) -> state.update(cx, (state, cx) -> state.selectBy(1, window, cx)));
        assertTrue(samePath(ip(1, 0), state.read(app).selectedIndex()));

        reversed = true;
        cx.update((window, cx) -> {
            h.view.update(cx, (_, cx) -> cx.notify());
            window.draw();
        });

        final s = state.read(app);
        assertEquals(1, s.selectedIndexValue);
        assertTrue(samePath(ip(1, 0), s.selectedIndex()));
        assertEquals(84., s.rowSizes[0].height);
        assertEquals(44., s.rowSizes[1].height);
    }

    function testAStateRedrawReusesTheInstalledCustomRowMeasurement() {
        var renders = 0;
        final h = addWindowView((window, cx:Context<RootHarness>) -> new RootHarness());
        final cx = h.cx;
        final state = cx.update((window, cx) -> newCommandState(cx, window, [
            CommandEntry.Item(new CommandItem().label("custom").child((_, _) -> {
                renders++;
                return div().child("Custom");
            })),
        ]));

        final layout = () -> cx.update((window, cx) -> {
            // `cx.draw(origin, min_size, || state)`: the state is the root view of the frame
            h.view.update(cx, (root, cx) -> {
                root.child = state;
                cx.notify();
            });
            window.draw();
        });
        layout();
        layout();
        final afterFirstDraw = renders;
        layout();

        assertEquals(2, renders - afterFirstDraw);
    }

    function testMovingPastTheVisibleRowsScrollsTheList() {
        final h = harness(state -> new Command(state).items([for (ix in 0...50) new CommandItem().label('Item $ix')]));
        final cx = h.cx;

        cx.runUntilParked();
        draw(cx);

        final state = h.view.read(app).state;
        assertEquals(0., state.read(app).scrollHandle.baseHandle().offset().y);

        // The list is capped well below 50 rows, so walking to the last one has
        // to bring the viewport with it.
        cx.update((window, cx) -> state.update(cx, (state, cx) -> {
            for (_ in 0...49) state.selectBy(1, window, cx);
        }));
        draw(cx);

        assertTrue(samePath(ip(49, 0), state.read(app).selectedIndex()));
        // selecting the last row should have scrolled the list
        assertTrue(state.read(app).scrollHandle.baseHandle().offset().y < 0.);
    }

    function testAReinstalledModelDoesNotScrollAPreservedSelection() {
        final h = harness(state -> new Command(state).items([for (ix in 0...50) new CommandItem().label('Item $ix')]));
        final cx = h.cx;

        cx.runUntilParked();
        draw(cx);

        final state = h.view.read(app).state;

        // Hover selection does not scroll, and the host re-render it notifies
        // reinstalls the model with the selection preserved. That reinstall
        // must not scroll either, or the hover still moves the list one frame
        // later.
        cx.update((window, cx) -> state.update(cx, (state, cx) -> state.select(10, window, cx)));
        draw(cx);

        // reinstalling the model must keep the scroll position
        assertEquals(0., state.read(app).scrollHandle.baseHandle().offset().y);
    }

}

private class CommandBlank extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

/** Hosts an arbitrary view as the root of the frame (Rust `cx.draw(..., || view)`). */
private class RootHarness extends Model implements Render {

    public var child:Null<Entity<CommandState>> = null;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final element = div();
        if (child != null) element.child(child.uncached());
        return element;
    }

}

private class CommandActionsHarness extends Model implements Render {

    public final state:Entity<CommandState>;

    public final events:Array<String>;

    public function new(state:Entity<CommandState>, events:Array<String>) {
        super();
        this.state = state;
        this.events = events;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final events = this.events;
        return div()
            .sizeFull()
            .onAction(OpenTestItem, (_, _, _) -> events.push("action"))
            .onAction(Cancel, (_, _, _) -> events.push("propagated_cancel"))
            .child(new Command(state)
                .item(new CommandItem().label("Item").keywords(["needle"]).action(new OpenTestItem()))
                .item(new CommandItem().label("Item"))
                .item(new CommandItem().label("Item").action(new GlobalTestItem()))
                .onQuery((query, _, _) -> events.push('query:$query'))
                .onSelect((index, _, _) -> events.push('select:${index.section}:${index.row}'))
                .onConfirm((index, _, _) -> events.push('confirm:${index.section}:${index.row}'))
                .onCancel((_, _) -> events.push("cancel")));
    }

}

private class ReentrantCallbackHarness extends Model implements Render {

    public final state:Entity<CommandState>;

    public final events:Array<String> = [];

    /** Failed `assert_eq!` inside the callbacks (checked by the test). */
    public var failures:Int = 0;

    public function new(state:Entity<CommandState>) {
        super();
        this.state = state;
    }

    static function same(a:Null<IndexPath>, b:IndexPath):Bool {
        return a != null && a.equals(b);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final owner:gpui.WeakEntity<ReentrantCallbackHarness> = cast cx.weakEntity();

        return new Command(state)
            .item(new CommandItem().label("alpha"))
            .item(new CommandItem().label("beta"))
            .onSelect((index, _, cx) -> {
                owner.tryUpdate(cx, (harness, cx) -> {
                    if (!same(harness.state.read(cx).selectedIndex(), index)) harness.failures++;
                    harness.events.push('select:${index.section}:${index.row}');
                });
            })
            .onQuery((query, _, cx) -> {
                owner.tryUpdate(cx, (harness, cx) -> {
                    if (harness.state.read(cx).query(cx.app) != query) harness.failures++;
                    harness.events.push('query:$query');
                });
            })
            .onConfirm((index, _, cx) -> {
                owner.tryUpdate(cx, (harness, cx) -> {
                    if (!same(harness.state.read(cx).selectedIndex(), index)) harness.failures++;
                    harness.events.push('confirm:${index.section}:${index.row}');
                });
            });
    }

}

private class CommandOwnedEntriesHarness extends Model implements Render {

    public final state:Entity<CommandState>;

    public function new(state:Entity<CommandState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new Command(state)
            .searchable(false)
            .item(new CommandItem().label("alpha"))
            .group(new CommandGroup().label("Settings").item(new CommandItem().label("beta")))
            .separator()
            .item(new CommandItem().label("custom").child((_, _) -> div().h(px(72.)).child("Custom")));
    }

}

private class CommandHarness extends Model implements Render {

    public final state:Entity<CommandState>;

    final command:(Entity<CommandState>) -> Command;

    public function new(state:Entity<CommandState>, command:(Entity<CommandState>) -> Command) {
        super();
        this.state = state;
        this.command = command;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .child(command(state).maxH(px(200.)));
    }

}

private class HeaderFooterHarness extends Model implements Render {

    public final state:Entity<CommandState>;

    public var headerCalls:Int = 0;

    public var footerCalls:Int = 0;

    public var headerMatchedCount:Null<Int> = null;

    public var footerMatchedCount:Null<Int> = null;

    public function new(state:Entity<CommandState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final harness = this;
        return div().sizeFull().child(
            new Command(state)
                .items([
                    new CommandItem().label("Calendar"),
                    new CommandItem().label("Calculator"),
                ])
                .maxH(px(200.))
                .header((state, _, _) -> {
                    harness.headerCalls++;
                    harness.headerMatchedCount = state.matchedCount();
                    return div();
                })
                .footer((state, _, _) -> {
                    harness.footerCalls++;
                    harness.footerMatchedCount = state.matchedCount();
                    return div();
                })
        );
    }

}

private class WrappingHarness extends Model implements Render {

    public final state:Entity<CommandState>;

    public var width:Float;

    public var noWrap:Bool = false;

    public function new(state:Entity<CommandState>, width:Float) {
        super();
        this.state = state;
        this.width = width;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final command = new Command(state)
            .item(new CommandItem().label("wrapped").child((_, _) -> div()
                .wFull()
                .child("A command row whose content wraps at narrow list widths")))
            .maxH(px(200.));
        if (noWrap) command.whitespaceNowrap();
        return div().sizeFull().child(div().w(px(width)).child(command));
    }

}
