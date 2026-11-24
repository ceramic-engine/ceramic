// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.AnyView;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.Window;
import glaze.kit.list.ListItem;
import glaze.kit.theme.Theme;
import glaze.kit.tree.Tree;
import glaze.kit.tree.Tree.TreeEvent;
import glaze.kit.tree.Tree.TreeItem;
import glaze.kit.tree.Tree.TreeState;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tree additions without upstream equivalent (KIT-004): explicit
 * folders, the selection kept across `setItems`, no toggle on a single
 * click, the navigation keys, drag and drop of the rows.
 */
class KitTreeAdditionsTest extends KitAdditionsTestCase {

    var tree:Entity<TreeState>;

    function newTree(items:Array<TreeItem>):Entity<TreeState> {
        tree = app.update(cx -> cx.newEntity((tc:Context<TreeState>) -> new TreeState(tc).items(items)));
        return tree;
    }

    function state():TreeState {
        return tree.read(app);
    }

    /** A 300 x 240 tree in a kit root, focused; `configure` sets its options. */
    function show(?configure:(Tree) -> Tree):VisualTestContext {
        final cx = open((_, _) -> {
            final tree = Tree.component(tree, (ix, entry, _, _, _) -> new ListItem(ElementId.NamedInteger('file', ix)).child(probe('row-' + entry.item().id, div().child(entry.item().label))));
            return div().w(px(300.)).h(px(240.)).child(configure != null ? configure(tree) : tree);
        }, 480, 320, true);
        cx.update((window, app) -> tree.update(app, (tree, cx) -> tree.focus(window, cx)));
        frame(cx);
        return cx;
    }

    function frame(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        cx.runUntilParked();
    }

    function click(cx:VisualTestContext, id:String, count:Int = 1):Void {
        final position = boundsOf(cx, 'row-$id').center();
        cx.simulateMouseMove(position);
        for (n in 1...count + 1) {
            cx.simulateEvent(new MouseDownEvent(Left, position, Modifiers.none(), n, false));
            cx.simulateEvent(new MouseUpEvent(Left, position, Modifiers.none(), n));
        }
        frame(cx);
    }

    function project():Array<TreeItem> {
        return [
            new TreeItem('src', 'src').child(new TreeItem('main', 'main.lor')).child(new TreeItem('lib', 'lib.lor')),
            new TreeItem('empty', 'empty').folder(true),
            new TreeItem('readme', 'readme'),
        ];
    }

    /** A click on a row with modifiers held. */
    function clickWith(cx:VisualTestContext, id:String, modifiers:Modifiers):Void {
        final position = boundsOf(cx, 'row-$id').center();
        cx.simulateMouseMove(position);
        cx.simulateEvent(new MouseDownEvent(Left, position, modifiers, 1, false));
        cx.simulateEvent(new MouseUpEvent(Left, position, modifiers, 1));
        frame(cx);
    }

    /// KIT-046: several rows selected

    function flat():Array<TreeItem> {
        return [for (name in ['a', 'b', 'c', 'd', 'e']) new TreeItem(name, name)];
    }

    function testWithoutMultiSelectAModifierClickSelectsOneRow() {
        newTree(flat());
        final cx = show();
        click(cx, 'a');
        clickWith(cx, 'c', Modifiers.of(false, false, false, true));
        assertEquals('[2]', Std.string(state().selectedIndices()));
        clickWith(cx, 'e', Modifiers.of(false, false, true));
        assertEquals('[4]', Std.string(state().selectedIndices()));
    }

    function testMultiSelectAddsRemovesAndExtends() {
        newTree(flat());
        final events:Array<String> = [];
        app.update(cx -> cx.subscribe(tree, TreeEvent, (_, event:TreeEvent, _) -> switch event {
            case SelectionChanged(ids): events.push(ids.join('+'));
            case _:
        }));
        final cx = show(tree -> tree.multiSelect(true));
        click(cx, 'b');
        assertEquals('b', state().selectedIds().join('+'));
        // The platform key adds a row, then takes it out
        clickWith(cx, 'd', Modifiers.of(false, false, false, true));
        assertEquals('b+d', state().selectedIds().join('+'));
        clickWith(cx, 'b', Modifiers.of(false, false, false, true));
        assertEquals('d', state().selectedIds().join('+'));
        // Shift selects from the row the selection is at to the clicked one, in both directions
        clickWith(cx, 'a', Modifiers.of(false, false, true));
        assertEquals('a+b+c+d', state().selectedIds().join('+'));
        clickWith(cx, 'e', Modifiers.of(false, false, true));
        assertEquals('d+e', state().selectedIds().join('+'));
        // A plain click selects that row alone
        click(cx, 'c');
        assertEquals('c', state().selectedIds().join('+'));
        assertEquals('b,b+d,d,a+b+c+d,d+e,c', events.join(','));
    }

    function testTheSelectionCanBeGivenAndFollowsItsItems() {
        newTree(project());
        final events:Array<String> = [];
        app.update(cx -> cx.subscribe(tree, TreeEvent, (_, event:TreeEvent, _) -> switch event {
            case SelectionChanged(ids): events.push(ids.join('+'));
            case _:
        }));
        final cx = show(tree -> tree.multiSelect(true).toggleOnClick(false));
        // Given by the caller: no event, an id that is not a row is left out
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.setSelectedIds(['readme', 'empty', 'nowhere'], cx)));
        frame(cx);
        assertEquals('empty+readme', state().selectedIds().join('+'));
        assertEquals(0, events.length);
        // Expanding a folder above moves the rows: the same items stay selected
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.toggleExpanded(0, cx)));
        frame(cx);
        assertEquals('empty+readme', state().selectedIds().join('+'));
        assertEquals('[3,4]', Std.string(state().selectedIndices()));
        // And across a new list of items, when asked
        final rebuilt = project();
        rebuilt.insert(0, new TreeItem('assets', 'assets').folder(true));
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.setItems(rebuilt, cx, true)));
        frame(cx);
        assertEquals('empty+readme', state().selectedIds().join('+'));
    }

    function testAnItemIsAFolderByItsChildrenUnlessToldOtherwise() {
        assertFalse(new TreeItem('a', 'a').isFolder());
        assertTrue(new TreeItem('a', 'a').child(new TreeItem('b', 'b')).isFolder());
        assertTrue(new TreeItem('a', 'a').folder(true).isFolder());
        assertTrue(new TreeItem('a', 'a').folder(true).clone().isFolder());
        assertFalse(new TreeItem('a', 'a').child(new TreeItem('b', 'b')).folder(false).isFolder());
    }

    function testAnEmptyFolderExpandsAndCollapses() {
        newTree(project());
        final events:Array<String> = [];
        app.update(cx -> cx.subscribe(tree, TreeEvent, (_, event:TreeEvent, _) -> events.push(Std.string(event))));
        final cx = show();
        assertTrue(state().entry(1).isFolder());
        assertFalse(state().entry(2).isFolder());
        click(cx, 'empty');
        assertTrue(state().entry(1).isExpanded());
        assertEquals(3, @:privateAccess state().entries.length);
        click(cx, 'empty');
        assertFalse(state().entry(1).isExpanded());
        // A leaf is selected, nothing more.
        click(cx, 'readme');
        assertEquals(2, state().selectedIndex());
        assertEquals('Expanded(empty),Collapsed(empty)', events.join(','));
    }

    function testSetItemsKeepsTheSelectionByIdWhenAsked() {
        newTree(project());
        final cx = show();
        click(cx, 'readme');
        assertEquals(2, state().selectedIndex());

        // The watcher rebuilt the list: a file appeared before the selection.
        final rebuilt = project();
        rebuilt.insert(0, new TreeItem('assets', 'assets').folder(true));
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.setItems(rebuilt, cx, true)));
        frame(cx);
        assertEquals(3, state().selectedIndex());
        assertEquals('readme', state().selectedItem().id);

        // Its item gone, the selection goes.
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.setItems([new TreeItem('other', 'other')], cx, true)));
        assertEquals(null, state().selectedIndex());

        // gpui-kit's behaviour without the argument: the selection is dropped.
        cx.update((_, app) -> tree.update(app, (tree, cx) -> {
            tree.setItems(project(), cx);
            tree.setSelectedIndex(2, cx);
            tree.setItems(project(), cx);
        }));
        assertEquals(null, state().selectedIndex());
    }

    function testWithoutToggleOnClickAClickOnlySelects() {
        newTree(project());
        final cx = show(tree -> tree.toggleOnClick(false));
        click(cx, 'src');
        assertEquals(0, state().selectedIndex());
        assertFalse(state().entry(0).isExpanded());
        // A double click toggles, and so do the keys and the state.
        click(cx, 'src', 2);
        assertTrue(state().entry(0).isExpanded());
        cx.simulateKeystrokes('left');
        frame(cx);
        assertFalse(state().entry(0).isExpanded());
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.toggleExpanded(0, cx)));
        assertTrue(state().entry(0).isExpanded());
    }

    function testByDefaultAClickTogglesAFolder() {
        newTree(project());
        final cx = show();
        click(cx, 'src');
        assertTrue(state().entry(0).isExpanded());
        click(cx, 'src');
        assertFalse(state().entry(0).isExpanded());
    }

    function many():Array<TreeItem> {
        return [for (i in 0...40) new TreeItem('item-$i', 'Item $i')];
    }

    function testNavigationKeysMoveTheSelection() {
        newTree(many());
        final cx = show(tree -> tree.navigationKeys(true));
        cx.simulateKeystrokes('end');
        frame(cx);
        assertEquals(39, state().selectedIndex());
        cx.simulateKeystrokes('home');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        cx.simulateKeystrokes('pagedown');
        frame(cx);
        final page = state().selectedIndex();
        assertTrue(page > 1 && page < 20, 'a page is $page entries');
        // The page is what fits in the tree, less one entry.
        final rowHeight = boundsOf(cx, 'row-item-${page + 1}').top() - boundsOf(cx, 'row-item-$page').top();
        assertEquals(Math.floor(240. / rowHeight) - 1, page);
        cx.simulateKeystrokes('pagedown');
        frame(cx);
        assertEquals(page * 2, state().selectedIndex());
        cx.simulateKeystrokes('pageup');
        frame(cx);
        assertEquals(page, state().selectedIndex());
        cx.simulateKeystrokes('pageup pageup');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        cx.simulateKeystrokes('end pagedown');
        frame(cx);
        assertEquals(39, state().selectedIndex());
        // The selection is scrolled into view.
        final last = boundsOf(cx, 'row-item-39');
        assertTrue(last.bottom() <= 240.5 && last.top() >= 0., 'last row at ${last.top()}');
    }

    function testLeftGoesToTheParent() {
        newTree([new TreeItem('src', 'src').expanded(true).child(new TreeItem('sub', 'sub').folder(true)).child(new TreeItem('main', 'main.lor'))]);
        final cx = show(tree -> tree.navigationKeys(true));
        click(cx, 'main');
        assertEquals(2, state().selectedIndex());
        cx.simulateKeystrokes('left');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        assertTrue(state().entry(0).isExpanded());
        // On the expanded parent, left collapses as before.
        cx.simulateKeystrokes('left');
        frame(cx);
        assertFalse(state().entry(0).isExpanded());
        // A root has no parent.
        cx.simulateKeystrokes('left');
        frame(cx);
        assertEquals(0, state().selectedIndex());
    }

    function testWithoutNavigationKeysTheKeysDoNothing() {
        newTree([new TreeItem('src', 'src').expanded(true).child(new TreeItem('main', 'main.lor')), new TreeItem('b', 'b'), new TreeItem('c', 'c')]);
        final cx = show();
        click(cx, 'main');
        for (key in ['left', 'end', 'home', 'pagedown', 'pageup']) {
            cx.simulateKeystrokes(key);
            frame(cx);
            assertEquals(1, state().selectedIndex(), key);
        }
    }

    function dragTree(drops:Array<String>):VisualTestContext {
        newTree([
            new TreeItem('main', 'main.lor'),
            new TreeItem('docs', 'docs').folder(true),
            new TreeItem('notes', 'notes.lor'),
        ]);
        return show(tree -> tree
            .dragEntries((ix, entry) -> entry.item().id == 'docs' ? null : new DraggedFile(entry.item().id),
                (_, _, _, cx) -> (cx.newEntity((_:Context<DraggedFilePreview>) -> new DraggedFilePreview()) : AnyView))
            .dropOnEntries(DraggedFile, (file, ix, entry, _, _) -> drops.push('${file.id} on ${entry.item().id} ($ix)'),
                (file, _, entry, _, _) -> entry.isFolder() && entry.item().id != file.id)
            .dropOnRoot(DraggedFile, (file, _, _) -> drops.push('${file.id} on root'), (file, _, _) -> file.id != 'notes'));
    }

    function drag(cx:VisualTestContext, from:String, to:Point):Void {
        final start = boundsOf(cx, 'row-$from').center();
        cx.simulateMouseMove(start);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(start.add(point(px(8.), px(0.))), Left);
        frame(cx);
        cx.simulateMouseMove(to, Left);
        frame(cx);
    }

    function drop(cx:VisualTestContext, at:Point):Void {
        cx.simulateEvent(new MouseUpEvent(Left, at, Modifiers.none(), 1));
        frame(cx);
    }

    function testARowDraggedOnAFolderIsDroppedOnIt() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final theme = cx.update((_, app) -> Theme.global(app));
        final docs = boundsOf(cx, 'row-docs').center();
        assertEquals(0, quadsFilled(cx, theme.dropTarget).length);

        drag(cx, 'main', docs);
        // The folder under the drag is highlighted (the tree too: it takes the drop elsewhere).
        final highlighted = [for (entry in quadsFilled(cx, theme.dropTarget)) if (entry.bounds.size.height < 100. && entry.bounds.contains(docs)) entry];
        assertEquals(1, highlighted.length);
        drop(cx, docs);
        assertEquals('main on docs (1)', drops.join(','));
        assertEquals(0, quadsFilled(cx, theme.dropTarget).length);
        // The press that started the drag selected nothing.
        assertEquals(null, state().selectedIndex());
    }

    // KIT-048: a drop before, inside or after a row

    function aroundTree(drops:Array<String>, ?configure:glaze.kit.tree.Tree->glaze.kit.tree.Tree):VisualTestContext {
        newTree([
            new TreeItem('main', 'main.lor'),
            new TreeItem('docs', 'docs').folder(true),
            new TreeItem('notes', 'notes.lor'),
            new TreeItem('todo', 'todo.lor'),
        ]);
        return show(tree -> {
            tree.dragEntries((ix, entry) -> new DraggedFile(entry.item().id),
                (_, _, _, cx) -> (cx.newEntity((_:Context<DraggedFilePreview>) -> new DraggedFilePreview()) : AnyView))
                // Only a folder takes a row inside, and nothing drops around itself
                .dropAroundEntries(DraggedFile, (file, ix, entry, place, _, _) -> drops.push('${file.id} ${placeName(place)} ${entry.item().id} ($ix)'),
                    (file, _, entry, place, _, _) -> entry.item().id != file.id && (place != glaze.kit.tree.Tree.TreeDropPlace.Inside || entry.isFolder()))
                .dropTargetStyle(s -> s.bg(hsla(0., 0.75, 0.5, 1.)))
                .insertionLineStyle(s -> s.h(px(2.)).bg(hsla(0.6, 0.75, 0.5, 1.)));
            return configure != null ? configure(tree) : tree;
        });
    }

    static function placeName(place:glaze.kit.tree.Tree.TreeDropPlace):String {
        return switch place {
            case Before: 'before';
            case Inside: 'inside';
            case After: 'after';
        }
    }

    /** The padding of a `ListItem` around its content: the rows are that much larger than their probe. */
    static inline final PAD_Y:Float = 4.;

    static inline final PAD_X:Float = 12.;

    /** A point of a row, at a part of the height of its content. */
    function inRow(cx:VisualTestContext, id:String, ratio:Float):Point {
        final bounds = boundsOf(cx, 'row-$id');
        return point(bounds.center().x, px((bounds.origin.y : Float) + (bounds.size.height : Float) * ratio));
    }

    function testDropPlaceAtSplitsARow() {
        final place = glaze.kit.tree.Tree.dropPlaceAt;
        assertEquals('before', placeName(place(1., 0., 20., true, true, true)));
        assertEquals('inside', placeName(place(10., 0., 20., true, true, true)));
        assertEquals('after', placeName(place(19., 0., 20., true, true, true)));
        // Nothing inside: two halves
        assertEquals('before', placeName(place(9., 0., 20., true, false, true)));
        assertEquals('after', placeName(place(11., 0., 20., true, false, true)));
        // Only inside: the whole row
        assertEquals('inside', placeName(place(1., 0., 20., false, true, false)));
        assertEquals('inside', placeName(place(19., 0., 20., false, true, false)));
        assertTrue(place(10., 0., 20., false, false, false) == null);
    }

    function testARowIsDroppedBeforeInsideAndAfterAnother() {
        final blue = hsla(0.6, 0.75, 0.5, 1.);
        final red = hsla(0., 0.75, 0.5, 1.);
        final drops:Array<String> = [];
        final cx = aroundTree(drops);
        assertEquals(0, quadsFilled(cx, blue).length);

        // The top of the folder: a line at the top of its row
        var at = inRow(cx, 'docs', 0.1);
        drag(cx, 'todo', at);
        var lines = quadsFilled(cx, blue);
        assertEquals(1, lines.length);
        final docs = boundsOf(cx, 'row-docs');
        assertEquals(2., (lines[0].bounds.size.height : Float));
        assertEquals((docs.origin.y : Float) - PAD_Y, (lines[0].bounds.origin.y : Float));
        assertEquals(0, quadsFilled(cx, red).length);
        drop(cx, at);
        assertEquals('todo before docs (1)', drops.join(','));
        assertEquals(0, quadsFilled(cx, blue).length);

        // The middle of the folder: the row is highlighted, no line
        at = inRow(cx, 'docs', 0.5);
        drag(cx, 'todo', at);
        assertEquals(0, quadsFilled(cx, blue).length);
        assertEquals(1, [for (entry in quadsFilled(cx, red)) if (entry.bounds.contains(at)) entry].length);
        drop(cx, at);
        assertEquals('todo inside docs (1)', drops[1]);
        assertEquals(0, quadsFilled(cx, red).length);

        // The bottom of the folder: a line at the bottom of its row
        at = inRow(cx, 'docs', 0.9);
        drag(cx, 'todo', at);
        lines = quadsFilled(cx, blue);
        assertEquals(1, lines.length);
        assertEquals((docs.origin.y : Float) + (docs.size.height : Float) + PAD_Y - 2., (lines[0].bounds.origin.y : Float));
        drop(cx, at);
        assertEquals('todo after docs (1)', drops[2]);
    }

    function testARowThatTakesNothingInsideIsSplitInTwo() {
        final blue = hsla(0.6, 0.75, 0.5, 1.);
        final drops:Array<String> = [];
        final cx = aroundTree(drops);
        final notes = boundsOf(cx, 'row-notes');
        var at = inRow(cx, 'notes', 0.4);
        drag(cx, 'main', at);
        var lines = quadsFilled(cx, blue);
        assertEquals(1, lines.length);
        assertEquals((notes.origin.y : Float) - PAD_Y, (lines[0].bounds.origin.y : Float));
        // The line follows the pointer to the other half
        at = inRow(cx, 'notes', 0.6);
        cx.simulateMouseMove(at, Left);
        frame(cx);
        lines = quadsFilled(cx, blue);
        assertEquals(1, lines.length);
        assertEquals((notes.origin.y : Float) + (notes.size.height : Float) + PAD_Y - 2., (lines[0].bounds.origin.y : Float));
        drop(cx, at);
        assertEquals('main after notes (2)', drops.join(','));
    }

    function testARowDoesNotDropAroundItselfAndTheLineLeavesWithThePointer() {
        final blue = hsla(0.6, 0.75, 0.5, 1.);
        final drops:Array<String> = [];
        final cx = aroundTree(drops);
        // Over itself: nothing
        var at = inRow(cx, 'notes', 0.9);
        drag(cx, 'notes', at);
        assertEquals(0, quadsFilled(cx, blue).length);
        // Over another row, then away from every row
        at = inRow(cx, 'todo', 0.9);
        cx.simulateMouseMove(at, Left);
        frame(cx);
        assertEquals(1, quadsFilled(cx, blue).length);
        final away = point(at.x, px((at.y : Float) + 200.));
        cx.simulateMouseMove(away, Left);
        frame(cx);
        assertEquals(0, quadsFilled(cx, blue).length);
        drop(cx, away);
        assertEquals('', drops.join(','));
    }

    function testTheInsertionLineStartsAtItsInset() {
        final blue = hsla(0.6, 0.75, 0.5, 1.);
        final cx = aroundTree([], tree -> tree.insertionInset((ix, entry) -> 30.));
        final at = inRow(cx, 'notes', 0.9);
        drag(cx, 'main', at);
        final lines = quadsFilled(cx, blue);
        assertEquals(1, lines.length);
        final notes = boundsOf(cx, 'row-notes');
        assertEquals((notes.origin.x : Float) - PAD_X + 30., (lines[0].bounds.origin.x : Float));
        drop(cx, at);
    }

    // KIT-015, KIT-016, KIT-017

    /** A folder with two files, a root file: every row takes a drop, the highlight goes to the parent folder. */
    function redirectTree(drops:Array<String>, redirect:Bool, rootStyle:Bool = false):VisualTestContext {
        newTree([
            new TreeItem('src', 'src').expanded(true).child(new TreeItem('main', 'main.lor')).child(new TreeItem('lib', 'lib.lor')),
            new TreeItem('notes', 'notes.lor'),
            new TreeItem('todo', 'todo.lor'),
        ]);
        return show(tree -> {
            tree.dragEntries((ix, entry) -> new DraggedFile(entry.item().id),
                (_, _, _, cx) -> (cx.newEntity((_:Context<DraggedFilePreview>) -> new DraggedFilePreview()) : AnyView))
                .dropOnEntries(DraggedFile, (file, ix, entry, _, _) -> drops.push('${file.id} on ${entry.item().id} ($ix)'),
                    (file, _, entry, _, _) -> entry.item().id != file.id)
                .dropTargetStyle(s -> s.bg(hsla(0., 0.75, 0.5, 1.)));
            if (rootStyle) tree.rootDropTargetStyle(s -> s.bg(hsla(0.3, 0.75, 0.5, 1.)));
            if (redirect) tree.dropTargetFor((ix, entry) -> entry.isFolder() ? ix : state().parentIndex(ix));
            return tree;
        });
    }

    function rowsFilled(cx:VisualTestContext, color:glaze.Hsla):Array<String> {
        final result = [];
        for (id in ['src', 'main', 'lib', 'notes', 'todo']) {
            final center = boundsOf(cx, 'row-$id').center();
            for (entry in quadsFilled(cx, color)) {
                if (entry.bounds.size.height < 100. && entry.bounds.contains(center)) {
                    result.push(id);
                    break;
                }
            }
        }
        return result;
    }

    function testWithoutDropTargetForTheRowUnderThePointerIsHighlighted() {
        final red = hsla(0., 0.75, 0.5, 1.);
        final cx = redirectTree([], false);
        drag(cx, 'notes', boundsOf(cx, 'row-lib').center());
        assertEquals('lib', rowsFilled(cx, red).join(','));
        drop(cx, boundsOf(cx, 'row-lib').center());
    }

    function testDropTargetForMovesTheHighlightToAnotherRow() {
        final red = hsla(0., 0.75, 0.5, 1.);
        final green = hsla(0.3, 0.75, 0.5, 1.);
        final drops:Array<String> = [];
        final cx = redirectTree(drops, true, true);
        assertEquals('', rowsFilled(cx, red).join(','));
        // Over a file of the folder: the folder is highlighted, not the file
        final lib = boundsOf(cx, 'row-lib').center();
        drag(cx, 'notes', lib);
        assertEquals('src', rowsFilled(cx, red).join(','));
        // Over the folder itself
        cx.simulateMouseMove(boundsOf(cx, 'row-src').center(), Left);
        frame(cx);
        assertEquals('src', rowsFilled(cx, red).join(','));
        // Over a root file: no row, the tree takes its root style
        assertEquals(0, quadsFilled(cx, green).length);
        cx.simulateMouseMove(boundsOf(cx, 'row-todo').center(), Left);
        frame(cx);
        assertEquals('', rowsFilled(cx, red).join(','));
        assertEquals(1, quadsFilled(cx, green).length);
        // Over the row being dragged (it refuses itself): nothing
        cx.simulateMouseMove(boundsOf(cx, 'row-notes').center(), Left);
        frame(cx);
        assertEquals('', rowsFilled(cx, red).join(','));
        assertEquals(0, quadsFilled(cx, green).length);
        // Back over a file of the folder, then dropped: the drop goes to the row under the pointer
        cx.simulateMouseMove(lib, Left);
        frame(cx);
        assertEquals('src', rowsFilled(cx, red).join(','));
        drop(cx, lib);
        assertEquals('notes on lib (2)', drops.join(','));
        // Nothing stays highlighted
        frame(cx);
        assertEquals('', rowsFilled(cx, red).join(','));
        assertEquals(0, quadsFilled(cx, green).length);
    }

    function testRowHoverAndRowSelectedReplaceTheThemeColors() {
        final red = hsla(0., 0.75, 0.5, 1.);
        final blue = hsla(0.6, 0.75, 0.5, 1.);
        final build = (styled:Bool) -> {
            newTree(project());
            return show(tree -> styled ? tree.rowHover(s -> s.bg(red)).rowSelected(s -> s.bg(blue)) : tree);
        };
        final plain = build(false);
        final plainTree = tree;
        final styled = build(true);
        // At rest (the pointer outside) the two trees draw the same
        for (cx in [plain, styled]) {
            cx.simulateMouseMove(new Point(400., 300.));
            frame(cx);
        }
        assertEquals(sceneSignature(plain), sceneSignature(styled));
        final theme = styled.update((_, app) -> Theme.global(app));
        final hover = (theme.tokens.listHover.background : glaze.Background).solid;
        final readme = boundsOf(styled, 'row-readme').center();
        // Hover
        plain.simulateMouseMove(readme);
        frame(plain);
        styled.simulateMouseMove(readme);
        frame(styled);
        assertTrue(quadsFilled(plain, hover).length > 0);
        assertEquals(0, quadsFilled(plain, red).length);
        assertEquals(1, quadsFilled(styled, red).length);
        assertTrue(quadsFilled(styled, red)[0].bounds.contains(readme));
        // Selected: the selected style, and no hover style on it
        click(styled, 'readme');
        assertEquals(1, quadsFilled(styled, blue).length);
        assertEquals(0, quadsFilled(styled, red).length);
        assertTrue(quadsFilled(styled, blue)[0].bounds.contains(readme));
        tree = plainTree;
        click(plain, 'readme');
        assertEquals(0, quadsFilled(plain, blue).length);
    }

    function testAListItemsOwnHoverWinsOverTheTrees() {
        final red = hsla(0., 0.75, 0.5, 1.);
        final green = hsla(0.3, 0.75, 0.5, 1.);
        newTree(project());
        final cx = open((_, _) -> {
            final tree = Tree.component(tree, (ix, entry, _, _, _) -> {
                final item = new ListItem(ElementId.NamedInteger('file', ix)).child(probe('row-' + entry.item().id, div().child(entry.item().label)));
                return entry.item().id == 'readme' ? item.hover(s -> s.bg(green)) : item;
            }).rowHover(s -> s.bg(red));
            return div().w(px(300.)).h(px(240.)).child(tree);
        }, 480, 320, true);
        frame(cx);
        cx.simulateMouseMove(boundsOf(cx, 'row-readme').center());
        frame(cx);
        assertEquals(1, quadsFilled(cx, green).length);
        assertEquals(0, quadsFilled(cx, red).length);
        cx.simulateMouseMove(boundsOf(cx, 'row-empty').center());
        frame(cx);
        assertEquals(0, quadsFilled(cx, green).length);
        assertEquals(1, quadsFilled(cx, red).length);
    }

    function rightClick(cx:VisualTestContext, at:Point):Void {
        cx.simulateMouseMove(at);
        cx.simulateMouseDown(at, Right);
        cx.simulateEvent(new MouseUpEvent(Right, at, Modifiers.none(), 1));
        frame(cx);
        frame(cx);
    }

    function testTheRootContextMenuOpensOnTheEmptyArea() {
        newTree(project());
        final built:Array<String> = [];
        final chosen:Array<String> = [];
        final cx = show(tree -> tree
            .contextMenu((ix, entry, menu, _, _) -> {
                built.push(entry.item().id);
                return menu.item(glaze.kit.menu.PopupMenu.PopupMenuItem.create('Rename').onClick((_, _, _) -> chosen.push('rename ' + entry.item().id)));
            })
            .rootContextMenu((menu, _, _) -> {
                built.push('root');
                return menu.item(glaze.kit.menu.PopupMenu.PopupMenuItem.create('New file').onClick((_, _, _) -> chosen.push('new file')));
            }));
        final empty = new Point(150., 200.);
        final readme = boundsOf(cx, 'row-readme').center();
        assertTrue(empty.y > boundsOf(cx, 'row-readme').bottom() + 20.);

        // On a row: the row's menu only
        rightClick(cx, readme);
        assertEquals('readme', built.join(','));
        cx.simulateKeystrokes('down enter');
        frame(cx);
        assertEquals('rename readme', chosen.join(','));

        // On the empty area: the tree's menu
        rightClick(cx, empty);
        assertEquals('readme,root', built.join(','));
        cx.simulateKeystrokes('down enter');
        frame(cx);
        assertEquals('rename readme,new file', chosen.join(','));

        // The tree's menu is open; a right click on a row replaces it with the row's
        rightClick(cx, empty);
        assertEquals('readme,root,root', built.join(','));
        rightClick(cx, boundsOf(cx, 'row-src').center());
        assertEquals('readme,root,root,src', built.join(','));
        cx.simulateKeystrokes('down enter');
        frame(cx);
        assertEquals('rename readme,new file,rename src', chosen.join(','));
        // Nothing is left open: the keys choose nothing more
        cx.simulateKeystrokes('down enter');
        frame(cx);
        assertEquals('rename readme,new file,rename src', chosen.join(','));
    }

    function testWithoutARootContextMenuTheTreeIsDrawnAsBefore() {
        newTree(project());
        final plain = show();
        final plainSignature = sceneSignature(plain);
        newTree(project());
        final withMenu = show(tree -> tree.rootContextMenu((menu, _, _) -> menu));
        assertEquals(plainSignature, sceneSignature(withMenu));
    }

    function testARowThatRefusesTheDropNeitherHighlightsNorTakesIt() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final theme = cx.update((_, app) -> Theme.global(app));
        final notes = boundsOf(cx, 'row-notes').center();
        drag(cx, 'main', notes);
        final rows = [for (entry in quadsFilled(cx, theme.dropTarget)) if (entry.bounds.size.height < 100.) entry];
        assertEquals(0, rows.length);
        drop(cx, notes);
        assertEquals('', drops.join(','));
    }

    function testADropOutsideTheRowsGoesToTheRoot() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final theme = cx.update((_, app) -> Theme.global(app));
        final below = point(px(150.), px(200.));
        drag(cx, 'main', below);
        assertEquals(1, [for (entry in quadsFilled(cx, theme.dropTarget)) if (entry.bounds.size.height > 200.) entry].length);
        drop(cx, below);
        assertEquals('main on root', drops.join(','));

        // The root has its own rule.
        drag(cx, 'notes', below);
        assertEquals(0, quadsFilled(cx, theme.dropTarget).length);
        drop(cx, below);
        assertEquals('main on root', drops.join(','));
    }

    function testARowWithoutAValueDoesNotDrag() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final below = point(px(150.), px(200.));
        drag(cx, 'docs', below);
        drop(cx, below);
        assertEquals('', drops.join(','));
    }


/// KIT-022: rows of different heights

    function tallFolders(tree:Tree):Tree {
        return tree.rowHeight((_, entry) -> entry.isFolder() ? 25. : 23.5);
    }

    function testRowsTakeTheHeightTheHookGives() {
        newTree([
            new TreeItem('src', 'src').child(new TreeItem('main', 'main.lor')).child(new TreeItem('lib', 'lib.lor')).expanded(true),
            new TreeItem('empty', 'empty').folder(true),
            new TreeItem('readme', 'readme'),
        ]);
        final cx = show(tallFolders);
        final tops = [for (id in ['src', 'main', 'lib', 'empty', 'readme']) boundsOf(cx, 'row-$id').origin.y];
        // folder 25, file 23.5, file 23.5, folder 25: each row starts where the one before ends
        assertFloatEquals(25., tops[1] - tops[0], 0.001);
        assertFloatEquals(23.5, tops[2] - tops[1], 0.001);
        assertFloatEquals(23.5, tops[3] - tops[2], 0.001);
        assertFloatEquals(25., tops[4] - tops[3], 0.001);
        // the list in use is the one of `rowScrollHandle`: the uniform list was never laid out
        assertTrue(state().scrollHandle().state.lastItemSize == null);
        assertFloatEquals(240., state().rowScrollHandle().bounds().size.height, 0.001);
        // a click still selects and toggles
        click(cx, 'readme');
        assertEquals(4, state().selectedIndex());
        click(cx, 'src');
        assertFalse(state().entry(0).isExpanded());
        assertFloatEquals(25., boundsOf(cx, 'row-empty').origin.y - boundsOf(cx, 'row-src').origin.y, 0.001);
    }

    function testWithoutTheHookRowsAreUniformAsBefore() {
        newTree(project());
        final plain = show();
        final plainTops = [for (id in ['src', 'empty', 'readme']) boundsOf(plain, 'row-$id').origin.y];
        final plainSignature = sceneSignature(plain);
        newTree(project());
        final unset = show(tree -> tree.rowHeight(null));
        assertEquals(plainSignature, sceneSignature(unset));
        assertFloatEquals(plainTops[1] - plainTops[0], plainTops[2] - plainTops[1], 0.001);
        assertEquals(0., state().rowScrollHandle().contentSize().height);
    }

    function testRowsOfDifferentHeightsStayVirtual() {
        final items = [for (i in 0...1000) i % 10 == 0 ? new TreeItem('n$i', 'folder $i').folder(true) : new TreeItem('n$i', 'file $i')];
        newTree(items);
        var built = 0;
        final cx = open((_, _) -> {
            final tree = Tree.component(tree, (ix, entry, _, _, _) -> {
                built++;
                return new ListItem(ElementId.NamedInteger('file', ix)).child(probe('row-' + entry.item().id, div().child(entry.item().label)));
            }).navigationKeys(true);
            return div().w(px(300.)).h(px(240.)).child(tallFolders(tree));
        }, 480, 320, true);
        cx.update((window, app) -> tree.update(app, (tree, cx) -> tree.focus(window, cx)));
        built = 0;
        frame(cx);
        // 240 px hold about ten rows: the measured row, the rows in view and
        // the overdraw, far from the thousand entries (frame() draws twice)
        assertTrue(built > 0 && built < 60, 'rows built: $built');
        final area = boundsOf(cx, 'row-n0');
        assertTrue(area != null);

        // End selects the last row and brings it into view, at the bottom
        cx.simulateKeystrokes('end');
        frame(cx);
        assertEquals(999, state().selectedIndex());
        final total = 100 * 25. + 900 * 23.5;
        assertFloatEquals(total, state().rowScrollHandle().contentSize().height, 0.01);
        assertFloatEquals(-(total - 240.), state().rowScrollHandle().offset().y, 0.01);
        built = 0;
        frame(cx);
        assertTrue(built > 0 && built < 60, 'rows built after End: $built');

        // scrollToItem and revealItem go to the list in use
        cx.update((_, app) -> tree.update(app, (tree, cx) -> {
            tree.scrollToItem(500, glaze.ScrollStrategy.Top);
            cx.notify();
        }));
        frame(cx);
        // row 500 starts after 50 folders and 450 files
        assertFloatEquals(-(50 * 25. + 450 * 23.5), state().rowScrollHandle().offset().y, 0.01);
        // PageUp moves by the rows that fit, counted with the mean height
        cx.simulateKeystrokes('home');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        assertEquals(0., state().rowScrollHandle().offset().y);
        cx.simulateKeystrokes('pagedown');
        frame(cx);
        assertEquals(Math.floor(240. / (total / 1000.)) - 1, state().selectedIndex());
    }

}

private class DraggedFile {

    public final id:String;

    public function new(id:String) {
        this.id = id;
    }

}

private class DraggedFilePreview extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(10.));
    }

}
