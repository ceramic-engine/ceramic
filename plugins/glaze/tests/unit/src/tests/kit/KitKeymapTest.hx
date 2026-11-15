package tests.kit;

import glaze.Action;
import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.KeyContext;
import glaze.Keystroke;
import glaze.TestDispatcher;
import glaze.kit.Kit;
import testing.TestCase;

/**
 * The key bindings the kit registers at startup: every binding, in order,
 * identical to the keymap of the kit before the bindings moved to classes of
 * their own (`DataTableKeys`, `SelectKeys`...), and the precedence of an
 * app's own bindings against them unchanged.
 *
 * Set `GLAZE_KEYMAP_DUMP=1` to print the kit's keymap.
 */
class KitKeymapTest extends TestCase {

    var app:App;

    override function setup() {
        app = new App(new TestDispatcher());
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        ceramic.App.app.flushImmediate();
    }

    static function describeAction(action:Action):String {
        final fields = Reflect.fields(action);
        fields.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        final data = [for (field in fields) field + ':' + Std.string(Reflect.field(action, field))];
        return action.name() + (data.length > 0 ? '(' + data.join(', ') + ')' : '');
    }

    static function describe(binding:KeyBinding):String {
        return [for (k in binding.keystrokes) k.unparse(Mac)].join(' ')
            + ' | ' + (binding.contextPredicate != null ? binding.contextPredicate.toString() : '-')
            + ' | ' + describeAction(binding.action);
    }

    static function describeKeymap(app:App):Array<String> {
        return [for (binding in app.keyBindings().bindings()) describe(binding)];
    }

    function dumpIfAsked(list:Array<String>):Void {
        #if js
        final dump:Null<String> = js.Syntax.code('(typeof process !== "undefined" ? process.env.GLAZE_KEYMAP_DUMP : null)');
        #elseif sys
        final dump = Sys.getEnv('GLAZE_KEYMAP_DUMP');
        #else
        final dump:Null<String> = null;
        #end
        if (dump == null || dump.length == 0) return;
        for (line in list) {
            trace('KEYMAP ' + line);
        }
    }

    function assertSameList(expected:Array<String>, actual:Array<String>):Void {
        assertEquals(expected.length, actual.length, 'number of bindings');
        final n = expected.length < actual.length ? expected.length : actual.length;
        for (i in 0...n) {
            assertEquals(expected[i], actual[i], 'binding $i');
        }
    }

    /**
     * The keymap after `Kit.init` is the one the kit registered before the
     * change, binding by binding (recorded from the previous code with
     * `GLAZE_KEYMAP_DUMP=1`, macOS keymap of the tests).
     */
    function testTheKitKeymapIsUnchanged() {
        app.update(cx -> Kit.init(cx));
        final actual = describeKeymap(app);
        dumpIfAsked(actual);
        assertSameList(RECORDED, actual);
    }

    /**
     * `Kit.init` registers the same bindings, in the same order, as the
     * component inits called in the order of the previous `Base.init` and
     * `Kit.initApp` (the Rust order).
     */
    function testTheKitKeymapFollowsTheComponentInitsInOrder() {
        app.update(cx -> Kit.init(cx));
        final other = new App(new TestDispatcher());
        other.update(cx -> {
            final ctx:AppContext = cx;
            // Base.init
            @:privateAccess glaze.kit.base.Dialog.DialogKeys.init(ctx);
            glaze.kit.base.Popover.bindKeys(ctx);
            glaze.kit.base.Sheet.bindKeys(ctx);
            glaze.kit.base.Combobox.bindKeys(ctx);
            glaze.kit.base.ColorPicker.ColorPickerState.init(ctx);
            glaze.kit.base.Select.bindKeys(ctx);
            glaze.kit.base.NumberInput.bindKeys(ctx);
            glaze.kit.base.TimeField.TimeFieldState.init(ctx);
            glaze.kit.base.input.InputKeyBindings.init(ctx);
            glaze.kit.base.Tree.TreeState.init(ctx);
            glaze.kit.base.text.Text.bindKeys(cx);
            glaze.kit.base.Root.bindKeys(ctx);
            // Kit.initApp
            @:privateAccess glaze.kit.diff.DiffActions.init(ctx);
            glaze.kit.time.DatePicker.DatePickerState.init(ctx);
            glaze.kit.sheet.Sheet.bindKeys(ctx);
            glaze.kit.list.ListState.init(ctx);
            glaze.kit.command.CommandState.init(ctx);
            glaze.kit.carousel.Carousel.bindKeys(ctx);
            glaze.kit.menu.Menus.init(ctx);
            glaze.kit.table.DataTable.bindKeys(ctx);
        });
        assertSameList(describeKeymap(other), describeKeymap(app));
    }

    /**
     * An app binding registered after the kit wins over the kit's binding of
     * the same keystroke and context, and one registered before the kit is
     * initialized loses to it, as before.
     */
    function testAnAppBindingKeepsItsPrecedence() {
        final escape = [Keystroke.parse('escape')];
        final dialog = [KeyContext.parse('Dialog')];

        // Registered after the kit: the app's binding comes first
        app.update(cx -> Kit.init(cx));
        app.bindKeys([new KeyBinding('escape', new glaze.kit.base.Actions.SelectFirst(), 'Dialog')]);
        final after = app.keyBindings().bindingsForInput(escape, dialog).bindings;
        assertTrue(after.length >= 2);
        assertEquals('ui::SelectFirst', after[0].action.name());
        assertEquals('ui::Cancel', after[1].action.name());

        // Registered before the kit: the kit's binding comes first
        final early = new App(new TestDispatcher());
        early.bindKeys([new KeyBinding('escape', new glaze.kit.base.Actions.SelectFirst(), 'Dialog')]);
        early.update(cx -> Kit.init(cx));
        final before = early.keyBindings().bindingsForInput(escape, dialog).bindings;
        assertTrue(before.length >= 2);
        assertEquals('ui::Cancel', before[0].action.name());
        assertEquals('ui::SelectFirst', before[1].action.name());
    }

    /** The kit's keymap recorded from the code before the change. */
    static final RECORDED:Array<String> = [
        'escape | Dialog | ui::Cancel',
        'enter | Dialog | ui::Confirm(secondary:false)',
        'escape | Popover | ui::Cancel',
        'enter | Popover | ui::Confirm(secondary:false)',
        'space | Popover | ui::Confirm(secondary:false)',
        'escape | PopoverContent | ui::Cancel',
        'enter | PopoverContent | zed::NoAction',
        'space | PopoverContent | zed::NoAction',
        'escape | Sheet | ui::Cancel',
        'up | Combobox | ui::SelectUp',
        'down | Combobox | ui::SelectDown',
        'enter | Combobox | ui::Confirm(secondary:false)',
        'cmd-enter | Combobox | ui::Confirm(secondary:true)',
        'escape | Combobox | ui::Cancel',
        'enter | ColorPicker | ui::Confirm(secondary:false)',
        'escape | ColorPicker | ui::Cancel',
        'space | Select && !Input | ui::Confirm(secondary:false)',
        'up | Select | ui::SelectUp',
        'down | Select | ui::SelectDown',
        'enter | Select | ui::Confirm(secondary:false)',
        'cmd-enter | Select | ui::Confirm(secondary:true)',
        'escape | Select | ui::Cancel',
        'up | NumberInput | number_input::Increment',
        'down | NumberInput | number_input::Decrement',
        'up | TimeField | number_input::Increment',
        'down | TimeField | number_input::Decrement',
        'left | TimeField | ui::SelectLeft',
        'right | TimeField | ui::SelectRight',
        'tab | TimeField | ui::SelectNextColumn',
        'shift-tab | TimeField | ui::SelectPrevColumn',
        'backspace | TimeField | input::Delete',
        'delete | TimeField | input::Delete',
        'backspace | Input | input::Backspace',
        'shift-backspace | Input | input::Backspace',
        'ctrl-backspace | Input | input::Backspace',
        'delete | Input | input::Delete',
        'shift-delete | Input | input::Delete',
        'cmd-backspace | Input | input::DeleteToBeginningOfLine',
        'cmd-delete | Input | input::DeleteToEndOfLine',
        'alt-backspace | Input | input::DeleteToPreviousWordStart',
        'alt-delete | Input | input::DeleteToNextWordEnd',
        'enter | Input | input::Enter(secondary:false, shift:false)',
        'shift-enter | Input | input::Enter(secondary:false, shift:true)',
        'cmd-enter | Input | input::Enter(secondary:true, shift:false)',
        'escape | Input | input::Escape',
        'up | Input | input::MoveUp',
        'down | Input | input::MoveDown',
        'left | Input | input::MoveLeft',
        'right | Input | input::MoveRight',
        'pageup | Input | input::MovePageUp',
        'pagedown | Input | input::MovePageDown',
        'tab | Input | input::IndentInline',
        'shift-tab | Input | input::OutdentInline',
        'cmd-] | Input | input::Indent',
        'cmd-[ | Input | input::Outdent',
        'shift-left | Input | ui::SelectLeft',
        'shift-right | Input | ui::SelectRight',
        'shift-up | Input | ui::SelectUp',
        'shift-down | Input | ui::SelectDown',
        'alt-cmd-up | Input | input::AddCursorAbove',
        'alt-cmd-down | Input | input::AddCursorBelow',
        'home | Input | input::MoveHome',
        'end | Input | input::MoveEnd',
        'shift-home | Input | input::SelectToStartOfLine',
        'shift-end | Input | input::SelectToEndOfLine',
        'ctrl-shift-a | Input | input::SelectToStartOfLine',
        'ctrl-shift-e | Input | input::SelectToEndOfLine',
        'cmd-shift-left | Input | input::SelectToStartOfLine',
        'cmd-shift-right | Input | input::SelectToEndOfLine',
        'alt-shift-left | Input | input::SelectToPreviousWordStart',
        'alt-shift-right | Input | input::SelectToNextWordEnd',
        'ctrl-cmd-space | Input | input::ShowCharacterPalette',
        'cmd-a | Input | input::SelectAll',
        'cmd-c | Input | input::Copy',
        'cmd-x | Input | input::Cut',
        'cmd-v | Input | input::Paste',
        'ctrl-a | Input | input::MoveHome',
        'cmd-left | Input | input::MoveHome',
        'ctrl-e | Input | input::MoveEnd',
        'cmd-right | Input | input::MoveEnd',
        'cmd-z | Input | input::Undo',
        'cmd-shift-z | Input | input::Redo',
        'cmd-up | Input | input::MoveToStart',
        'cmd-down | Input | input::MoveToEnd',
        'alt-left | Input | input::MoveToPreviousWord',
        'alt-right | Input | input::MoveToNextWord',
        'cmd-shift-up | Input | input::SelectToStart',
        'cmd-shift-down | Input | input::SelectToEnd',
        'cmd-f | Input | input::Search',
        'cmd-shift-f | Input | input::Replace',
        'up | Tree | ui::SelectUp',
        'down | Tree | ui::SelectDown',
        'left | Tree | ui::SelectLeft',
        'right | Tree | ui::SelectRight',
        'cmd-c | TextView | input::Copy',
        'cmd-a | TextView | input::SelectAll',
        'tab | Root | root::Tab',
        'shift-tab | Root | root::TabPrev',
        'cmd-c | Root | input::Copy',
        'up | Diff | diff::ScrollUp',
        'down | Diff | diff::ScrollDown',
        'left | Diff | diff::ScrollLeft',
        'right | Diff | diff::ScrollRight',
        'pageup | Diff | diff::PageUp',
        'pagedown | Diff | diff::PageDown',
        'home | Diff | diff::First',
        'end | Diff | diff::Last',
        'shift-up | Diff | diff::ExtendUp',
        'shift-down | Diff | diff::ExtendDown',
        'cmd-c | Diff | input::Copy',
        'cmd-a | Diff | input::SelectAll',
        'enter | DatePicker | ui::Confirm(secondary:false)',
        'escape | DatePicker | ui::Cancel',
        'delete | DatePicker | input::Delete',
        'backspace | DatePicker | input::Delete',
        'escape | List | ui::Cancel',
        'enter | List | ui::Confirm(secondary:false)',
        'cmd-enter | List | ui::Confirm(secondary:true)',
        'up | List | ui::SelectUp',
        'down | List | ui::SelectDown',
        'escape | Command | ui::Cancel',
        'enter | Command | ui::Confirm(secondary:false)',
        'up | Command | ui::SelectUp',
        'down | Command | ui::SelectDown',
        'left | Carousel | ui::SelectLeft',
        'right | Carousel | ui::SelectRight',
        'up | Carousel | ui::SelectUp',
        'down | Carousel | ui::SelectDown',
        'home | Carousel | ui::SelectFirst',
        'end | Carousel | ui::SelectLast',
        'escape | AppMenuBar | ui::Cancel',
        'left | AppMenuBar | ui::SelectLeft',
        'right | AppMenuBar | ui::SelectRight',
        'enter | PopupMenu | ui::Confirm(secondary:false)',
        'escape | PopupMenu | ui::Cancel',
        'up | PopupMenu | ui::SelectUp',
        'down | PopupMenu | ui::SelectDown',
        'left | PopupMenu | ui::SelectLeft',
        'right | PopupMenu | ui::SelectRight',
        'escape | DataTable | ui::Cancel',
        'up | DataTable | ui::SelectUp',
        'down | DataTable | ui::SelectDown',
        'left | DataTable | ui::SelectPrevColumn',
        'right | DataTable | ui::SelectNextColumn',
        'home | DataTable | ui::SelectFirst',
        'end | DataTable | ui::SelectLast',
        'pageup | DataTable | ui::SelectPageUp',
        'pagedown | DataTable | ui::SelectPageDown',
        'tab | DataTable | ui::SelectNextColumn',
        'shift-tab | DataTable | ui::SelectPrevColumn',
    ];

}
