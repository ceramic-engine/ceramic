// Ported from vscode src/vs/editor/browser/editorExtensions.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view;

import cityscape.Cityscape;
import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.platform.commands.common.Commands;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry;
import cityscape.view.EditorBrowser.ICodeEditor;
import haxe.extern.EitherType;

/*
 * The registration of the editor's commands, actions and contributions.
 *
 * Monaco registers them at module load into global registries. Cityscape
 * has no global registry: `EditorExtensionsRegistry` is a field of a
 * `Cityscape` context (`context.editorExtensions`), filled the first time
 * it is used (the first editor of the context) by `EditorAll.registerAll`,
 * which calls the `register(r)` function of each contribution (the module
 * level code of Monaco's files). A command registers its keybindings in the
 * keybindings registry of the context and its handler in the commands
 * registry of the context.
 *
 * The menus (`MenuRegistry`, `menuOpts`, `contextMenuOpts`) are kept as data
 * in the registry (`getMenuItems`) for the context menu.
 */

enum abstract EditorContributionInstantiation(Int) from Int to Int {
    /**
     * The contribution is created eagerly when the `ICodeEditor` is instantiated.
     * Only Eager contributions can participate in saving or restoring of view state.
     */
    var Eager = 0;

    /**
     * The contribution is created at the latest 50ms after the first render after attaching a text model.
     * If the contribution is explicitly requested via `getContribution`, it will be instantiated sooner.
     * If there is idle time available, it will be instantiated sooner.
     */
    var AfterFirstRender = 1;

    /**
     * The contribution is created before the editor emits events produced by user interaction (mouse events, keyboard events).
     * If the contribution is explicitly requested via `getContribution`, it will be instantiated sooner.
     * If there is idle time available, it will be instantiated sooner.
     */
    var BeforeFirstInteraction = 2;

    /**
     * The contribution is created when there is idle time available, at the latest 5000ms after the editor creation.
     * If the contribution is explicitly requested via `getContribution`, it will be instantiated sooner.
     */
    var Eventually = 3;

    /**
     * The contribution is created only when explicitly requested via `getContribution`.
     */
    var Lazy = 4;
}

typedef EditorContributionCtor = (editor:ICodeEditor) -> IEditorContribution;

typedef IEditorContributionDescription = {
    final id:String;
    final ctor:EditorContributionCtor;
    final instantiation:EditorContributionInstantiation;
}

//#region Command

typedef ICommandKeybindingsOptions = {
    @:optional var kbExpr:Null<ContextKeyExpression>;
    var weight:Int;
    /**
     * the default keybinding arguments
     */
    @:optional var args:Any;
    @:optional var primary:Int;
    @:optional var secondary:Array<Int>;
    @:optional var win:IPlatformKeybindings;
    @:optional var linux:IPlatformKeybindings;
    @:optional var mac:IPlatformKeybindings;
}

/**
 * A menu: Monaco's `MenuId` (its id string: `EditorContext`,
 * `CommandPalette`, `MenubarEditMenu`, `MenubarSelectionMenu`...).
 */
typedef MenuId = String;

typedef ICommandMenuOptions = {
    var menuId:MenuId;
    var group:String;
    var order:Float;
    @:optional var when:Null<ContextKeyExpression>;
    var title:String;
}

typedef ICommandOptions = {
    var id:String;
    var precondition:Null<ContextKeyExpression>;
    /**
     * One `ICommandKeybindingsOptions` or an array.
     */
    @:optional var kbOpts:EitherType<ICommandKeybindingsOptions, Array<ICommandKeybindingsOptions>>;
    @:optional var metadata:Null<ICommandMetadata>;
    /**
     * One `ICommandMenuOptions` or an array.
     */
    @:optional var menuOpts:EitherType<ICommandMenuOptions, Array<ICommandMenuOptions>>;
}

/**
 * A menu item registered by a command (Monaco's `IMenuItem`).
 */
typedef IMenuItem = {
    var command:{id:String, title:String, ?precondition:Null<ContextKeyExpression>};
    @:optional var when:Null<ContextKeyExpression>;
    @:optional var group:String;
    @:optional var order:Float;
}

abstract class Command {

    public final id:String;
    public final precondition:Null<ContextKeyExpression>;
    final _kbOpts:Null<Array<ICommandKeybindingsOptions>>;
    final _menuOpts:Null<Array<ICommandMenuOptions>>;
    public final metadata:Null<ICommandMetadata>;

    public function new(opts:ICommandOptions) {
        this.id = opts.id;
        this.precondition = opts.precondition;
        this._kbOpts = toArray(opts.kbOpts);
        this._menuOpts = toArray(opts.menuOpts);
        this.metadata = opts.metadata;
    }

    @:allow(cityscape.view)
    static function toArray<T>(value:Any):Null<Array<T>> {
        if (value == null) {
            return null;
        }
        if (JsValues.isArray(value)) {
            return value;
        }
        return [value];
    }

    /**
     * Registers the keybindings, the menu items and the handler of the
     * command in the registries of `r`'s context.
     */
    public function register(r:EditorExtensionsRegistry):Void {

        if (this._menuOpts != null) {
            for (item in this._menuOpts) {
                this._registerMenuItem(r, item);
            }
        }

        if (this._kbOpts != null) {
            for (kbOpts in this._kbOpts) {
                var kbWhen = kbOpts.kbExpr;
                if (this.precondition != null) {
                    if (kbWhen != null) {
                        kbWhen = ContextKeyExpr.and(kbWhen, this.precondition);
                    }
                    else {
                        kbWhen = this.precondition;
                    }
                }

                final desc:IKeybindingRule = {
                    id: this.id,
                    weight: kbOpts.weight,
                    args: kbOpts.args,
                    when: kbWhen,
                    primary: kbOpts.primary,
                    secondary: kbOpts.secondary,
                    win: kbOpts.win,
                    linux: kbOpts.linux,
                    mac: kbOpts.mac,
                };

                r.context.keybindingsRegistry.registerKeybindingRule(desc);
            }
        }

        r.context.commandsRegistry.registerCommand({
            id: this.id,
            handler: (accessor, args) -> this.runCommand(accessor, args != null && args.length > 0 ? args[0] : null),
            metadata: this.metadata
        });
    }

    function _registerMenuItem(r:EditorExtensionsRegistry, item:ICommandMenuOptions):Void {
        r.appendMenuItem(item.menuId, {
            group: item.group,
            command: {
                id: this.id,
                title: item.title,
                precondition: this.precondition
            },
            when: item.when,
            order: item.order
        });
    }

    abstract public function runCommand(accessor:Null<Cityscape>, args:Any):Void;

}

//#endregion Command

//#region MultiplexingCommand

/**
 * Potential override for a command.
 *
 * @return `true` if the command was successfully run. This stops other overrides from being executed.
 */
typedef CommandImplementation = (accessor:Null<Cityscape>, args:Any) -> Bool;

private typedef ICommandImplementationRegistration = {
    var priority:Int;
    var name:String;
    var implementation:CommandImplementation;
    @:optional var when:Null<ContextKeyExpression>;
}

class MultiCommand extends Command {

    final _implementations:Array<ICommandImplementationRegistration> = [];

    /**
     * A higher priority gets to be looked at first
     */
    public function addImplementation(priority:Int, name:String, implementation:CommandImplementation, ?when:ContextKeyExpression):IDisposable {
        final registration:ICommandImplementationRegistration = {priority: priority, name: name, implementation: implementation, when: when};
        this._implementations.push(registration);
        haxe.ds.ArraySort.sort(this._implementations, (a, b) -> b.priority - a.priority);
        return Lifecycle.toDisposable(() -> {
            this._implementations.remove(registration);
        });
    }

    public function runCommand(accessor:Null<Cityscape>, args:Any):Void {
        for (impl in this._implementations.copy()) {
            if (impl.when != null) {
                final editor = accessor != null ? accessor.codeEditorService.getFocusedCodeEditor() : null;
                final contextKeyService:Null<IContextKeyService> = editor != null ? editor.contextKeyService : (accessor != null ? accessor.contextKeyService : null);
                if (contextKeyService != null && !contextKeyService.contextMatchesRules(impl.when)) {
                    continue;
                }
            }
            final result = impl.implementation(accessor, args);
            if (result) {
                return;
            }
        }
    }

}

//#endregion

/**
 * A command that delegates to another command's implementation.
 *
 * This lets different commands be registered but share the same implementation
 */
class ProxyCommand extends Command {

    final command:Command;

    public function new(command:Command, opts:ICommandOptions) {
        super(opts);
        this.command = command;
    }

    public function runCommand(accessor:Null<Cityscape>, args:Any):Void {
        this.command.runCommand(accessor, args);
    }

}

//#region EditorCommand

typedef IContributionCommandOptions<T> = {
    > ICommandOptions,
    var handler:(controller:T, args:Any) -> Void;
}

abstract class EditorCommand extends Command {

    /**
     * Monaco's static `EditorCommand.runEditorCommand`: runs `runner` on the
     * focused (or active) editor of the context when `precondition` holds
     * in its context keys.
     */
    public static function runEditorCommandStatic(accessor:Null<Cityscape>, args:Any, precondition:Null<ContextKeyExpression>, runner:(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any) -> Void):Void {
        if (accessor == null) {
            return;
        }
        final codeEditorService = accessor.codeEditorService;

        // Find the editor with text focus or active
        var editor = codeEditorService.getFocusedCodeEditor();
        if (editor == null) {
            editor = codeEditorService.getActiveCodeEditor();
        }
        if (editor == null) {
            // well, at least we tried...
            return;
        }

        editor.invokeWithinContext((editorAccessor) -> {
            final kbService = editor.contextKeyService;
            if (!kbService.contextMatchesRules(precondition)) {
                // precondition does not hold
                return null;
            }

            runner(editorAccessor, editor, args);
            return null;
        });
    }

    public function runCommand(accessor:Null<Cityscape>, args:Any):Void {
        EditorCommand.runEditorCommandStatic(accessor, args, this.precondition, (accessor, editor, args) -> this.runEditorCommand(accessor, editor, args));
    }

    abstract public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void;

}

/**
 * A command bound to an editor contribution (Monaco's
 * `EditorCommand.bindToContribution(getter)` class):
 *
 * ```haxe
 * new ContributionCommand<CommonFindController>(CommonFindController.get, {
 *     id: 'closeFindWidget',
 *     precondition: CONTEXT_FIND_WIDGET_VISIBLE,
 *     handler: (x, args) -> x.closeFindWidget(),
 *     kbOpts: {...}
 * });
 * ```
 */
class ContributionCommand<T:IEditorContribution> extends EditorCommand {

    final _controllerGetter:(editor:ICodeEditor) -> Null<T>;
    final _callback:(controller:T, args:Any) -> Void;

    public function new(controllerGetter:(editor:ICodeEditor) -> Null<T>, opts:IContributionCommandOptions<T>) {
        super(opts);
        this._controllerGetter = controllerGetter;
        this._callback = opts.handler;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = this._controllerGetter(editor);
        if (controller != null) {
            this._callback(controller, args);
        }
    }

}

//#endregion EditorCommand

//#region EditorAction

typedef IEditorActionContextMenuOptions = {
    var group:String;
    var order:Float;
    @:optional var when:Null<ContextKeyExpression>;
    @:optional var menuId:MenuId;
}

typedef IActionOptions = {
    > ICommandOptions,
    var label:String;
    var alias:String;
    /**
     * One `IEditorActionContextMenuOptions` or an array.
     */
    @:optional var contextMenuOpts:EitherType<IEditorActionContextMenuOptions, Array<IEditorActionContextMenuOptions>>;
}

abstract class EditorAction extends EditorCommand {

    static function convertOptions(opts:IActionOptions):ICommandOptions {

        var menuOpts:Array<ICommandMenuOptions> = Command.toArray(opts.menuOpts);
        if (menuOpts == null) {
            menuOpts = [];
        }
        else {
            menuOpts = menuOpts.copy();
        }

        function withDefaults(item:IEditorActionContextMenuOptions):ICommandMenuOptions {
            return {
                menuId: item.menuId != null ? item.menuId : 'EditorContext',
                group: item.group,
                order: item.order,
                title: opts.label,
                when: ContextKeyExpr.and(opts.precondition, item.when)
            };
        }

        final contextMenuOpts:Null<Array<IEditorActionContextMenuOptions>> = Command.toArray(opts.contextMenuOpts);
        if (contextMenuOpts != null) {
            for (item in contextMenuOpts) {
                menuOpts.push(withDefaults(item));
            }
        }

        return {
            id: opts.id,
            precondition: opts.precondition,
            kbOpts: opts.kbOpts,
            metadata: opts.metadata,
            menuOpts: menuOpts
        };
    }

    public final label:String;
    public final alias:String;

    public function new(opts:IActionOptions) {
        super(EditorAction.convertOptions(opts));
        this.label = opts.label;
        this.alias = opts.alias;
    }

    public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        this.run(accessor, editor, args != null ? args : {});
    }

    abstract public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void;

}

typedef EditorActionImplementation = (accessor:Null<Cityscape>, editor:ICodeEditor, args:Any) -> Bool;

class MultiEditorAction extends EditorAction {

    final _implementations:Array<{priority:Int, implementation:EditorActionImplementation}> = [];

    /**
     * A higher priority gets to be looked at first
     */
    public function addImplementation(priority:Int, implementation:EditorActionImplementation):IDisposable {
        final entry = {priority: priority, implementation: implementation};
        this._implementations.push(entry);
        haxe.ds.ArraySort.sort(this._implementations, (a, b) -> b.priority - a.priority);
        return Lifecycle.toDisposable(() -> {
            this._implementations.remove(entry);
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        for (impl in this._implementations.copy()) {
            final result = impl.implementation(accessor, editor, args);
            if (result) {
                return;
            }
        }
    }

}

//#endregion EditorAction

//#region EditorAction2

/**
 * The keybinding of an `Action2` (Monaco's `IAction2Options.keybinding`).
 */
typedef IAction2Keybinding = {
    @:optional var when:Null<ContextKeyExpression>;
    var weight:Int;
    @:optional var args:Any;
    @:optional var primary:Int;
    @:optional var secondary:Array<Int>;
    @:optional var win:IPlatformKeybindings;
    @:optional var linux:IPlatformKeybindings;
    @:optional var mac:IPlatformKeybindings;
}

/**
 * Monaco's `IAction2Options`, the parts Cityscape uses: id, title,
 * precondition, keybindings (one or an array), menus (one or an array).
 */
typedef IAction2Options = {
    var id:String;
    var title:String;
    @:optional var precondition:Null<ContextKeyExpression>;
    @:optional var keybinding:EitherType<IAction2Keybinding, Array<IAction2Keybinding>>;
    @:optional var menu:EitherType<ICommandMenuOptions, Array<ICommandMenuOptions>>;
    @:optional var metadata:Null<ICommandMetadata>;
    @:optional var f1:Bool;
}

/**
 * Monaco's `Action2` (platform/actions/common/actions.ts): a command
 * described by `desc`, registered with `registerAction2`.
 */
abstract class Action2 {

    public final desc:IAction2Options;

    public function new(desc:IAction2Options) {
        this.desc = desc;
    }

    abstract public function run(accessor:Null<Cityscape>, args:Array<Any>):Void;

}

abstract class EditorAction2 extends Action2 {

    public function run(accessor:Null<Cityscape>, args:Array<Any>):Void {
        if (accessor == null) {
            return;
        }
        // Find the editor with text focus or active
        final codeEditorService = accessor.codeEditorService;
        var editor = codeEditorService.getFocusedCodeEditor();
        if (editor == null) {
            editor = codeEditorService.getActiveCodeEditor();
        }
        if (editor == null) {
            // well, at least we tried...
            return;
        }
        // precondition does hold
        editor.invokeWithinContext((editorAccessor) -> {
            final kbService = editor.contextKeyService;
            final enabled = kbService.contextMatchesRules(this.desc.precondition);
            if (!enabled) {
                return null;
            }
            this.runEditorCommand(editorAccessor, editor, args);
            return null;
        });
    }

    abstract public function runEditorCommand(accessor:Null<Cityscape>, editor:ICodeEditor, args:Array<Any>):Void;

}

//#endregion

/**
 * The editor contributions, commands and actions of a `Cityscape` context
 * (Monaco's `EditorExtensionsRegistry` and `EditorContributionRegistry`),
 * with the registration functions of editorExtensions.ts as methods.
 */
class EditorExtensionsRegistry {

    public final context:Cityscape;

    final editorContributions:Array<IEditorContributionDescription> = [];
    final editorActions:Array<EditorAction> = [];
    final editorCommands:Map<String, EditorCommand> = new Map();
    final menuItems:Map<MenuId, Array<IMenuItem>> = new Map();

    /**
     * The `undo` command (Monaco's `UndoCommand`), its implementations added
     * by the core commands.
     */
    public final UndoCommand:MultiCommand;

    /**
     * The `redo` command (Monaco's `RedoCommand`).
     */
    public final RedoCommand:MultiCommand;

    /**
     * The `editor.action.selectAll` command (Monaco's `SelectAllCommand`).
     */
    public final SelectAllCommand:MultiCommand;

    public function new(context:Cityscape) {
        this.context = context;

        UndoCommand = registerCommand(new MultiCommand({
            id: 'undo',
            precondition: null,
            kbOpts: {
                weight: KeybindingWeight.EditorCore,
                primary: KeyMod.CtrlCmd | KeyCode.KeyZ
            },
            menuOpts: [{
                menuId: 'MenubarEditMenu',
                group: '1_do',
                title: localize('miUndo', "&&Undo"),
                order: 1
            }, {
                menuId: 'CommandPalette',
                group: '',
                title: localize('undo', "Undo"),
                order: 1
            }]
        }));

        registerCommand(new ProxyCommand(UndoCommand, {id: 'default:undo', precondition: null}));

        RedoCommand = registerCommand(new MultiCommand({
            id: 'redo',
            precondition: null,
            kbOpts: {
                weight: KeybindingWeight.EditorCore,
                primary: KeyMod.CtrlCmd | KeyCode.KeyY,
                secondary: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyZ],
                mac: {primary: KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyZ}
            },
            menuOpts: [{
                menuId: 'MenubarEditMenu',
                group: '1_do',
                title: localize('miRedo', "&&Redo"),
                order: 2
            }, {
                menuId: 'CommandPalette',
                group: '',
                title: localize('redo', "Redo"),
                order: 1
            }]
        }));

        registerCommand(new ProxyCommand(RedoCommand, {id: 'default:redo', precondition: null}));

        SelectAllCommand = registerCommand(new MultiCommand({
            id: 'editor.action.selectAll',
            precondition: null,
            kbOpts: {
                weight: KeybindingWeight.EditorCore,
                kbExpr: null,
                primary: KeyMod.CtrlCmd | KeyCode.KeyA
            },
            menuOpts: [{
                menuId: 'MenubarSelectionMenu',
                group: '1_basic',
                title: localize('miSelectAll', "&&Select All"),
                order: 1
            }, {
                menuId: 'CommandPalette',
                group: '',
                title: localize('selectAll', "Select All"),
                order: 1
            }]
        }));
    }

    /**
     * Localizes a text with the translation table of the context.
     */
    public inline function localize(key:String, defaultMessage:String, ?args:Array<Any>):String {
        return context.nls.localize(key, defaultMessage, args);
    }

    /**
     * Registers an editor contribution. Editor contributions have a lifecycle which is bound
     * to a specific code editor instance.
     */
    public function registerEditorContribution(id:String, ctor:EditorContributionCtor, instantiation:EditorContributionInstantiation):Void {
        this.editorContributions.push({id: id, ctor: ctor, instantiation: instantiation});
    }

    public function getEditorContributions():Array<IEditorContributionDescription> {
        return this.editorContributions.copy();
    }

    public function getSomeEditorContributions(ids:Array<String>):Array<IEditorContributionDescription> {
        return [for (c in this.editorContributions) if (ids.indexOf(c.id) >= 0) c];
    }

    public function registerEditorAction<T:EditorAction>(action:T):T {
        action.register(this);
        this.editorActions.push(action);
        return action;
    }

    /**
     * Monaco's `registerMultiEditorAction`.
     */
    public function registerMultiEditorAction<T:MultiEditorAction>(action:T):T {
        return registerEditorAction(action);
    }

    public function getEditorActions():Array<EditorAction> {
        return this.editorActions;
    }

    public function registerEditorCommand<T:EditorCommand>(editorCommand:T):T {
        editorCommand.register(this);
        this.editorCommands.set(editorCommand.id, editorCommand);
        return editorCommand;
    }

    public function getEditorCommand(commandId:String):Null<EditorCommand> {
        return this.editorCommands.get(commandId);
    }

    /**
     * Registers a command that is not an editor command (Monaco's module
     * function `registerCommand` of editorExtensions.ts and coreCommands.ts).
     */
    public function registerCommand<T:Command>(command:T):T {
        command.register(this);
        return command;
    }

    /**
     * Registers an `Action2` (Monaco's `registerAction2`): its handler and
     * keybindings.
     */
    public function registerAction2(action:Action2):IDisposable {
        final desc = action.desc;
        final disposables = new DisposableStore();
        disposables.add(context.commandsRegistry.registerCommand({
            id: desc.id,
            handler: (accessor, args) -> action.run(accessor, args != null ? args : []),
            metadata: desc.metadata
        }));
        final keybindings:Null<Array<IAction2Keybinding>> = Command.toArray(desc.keybinding);
        if (keybindings != null) {
            for (item in keybindings) {
                disposables.add(context.keybindingsRegistry.registerKeybindingRule({
                    id: desc.id,
                    weight: item.weight,
                    args: item.args,
                    when: desc.precondition != null ? ContextKeyExpr.and(desc.precondition, item.when) : item.when,
                    primary: item.primary,
                    secondary: item.secondary,
                    win: item.win,
                    linux: item.linux,
                    mac: item.mac
                }));
            }
        }
        final menus:Null<Array<ICommandMenuOptions>> = Command.toArray(desc.menu);
        if (menus != null) {
            for (item in menus) {
                appendMenuItem(item.menuId, {
                    command: {id: desc.id, title: desc.title, precondition: desc.precondition},
                    when: item.when,
                    group: item.group,
                    order: item.order
                });
            }
        }
        return disposables;
    }

    /**
     * Registers a keybinding rule (Monaco's `KeybindingsRegistry.registerKeybindingRule`).
     */
    public function registerKeybindingRule(rule:IKeybindingRule):IDisposable {
        return context.keybindingsRegistry.registerKeybindingRule(rule);
    }

    /**
     * Monaco's `MenuRegistry.appendMenuItem`.
     */
    public function appendMenuItem(menuId:MenuId, item:IMenuItem):IDisposable {
        var items = menuItems.get(menuId);
        if (items == null) {
            items = [];
            menuItems.set(menuId, items);
        }
        items.push(item);
        final list = items;
        return Lifecycle.toDisposable(() -> list.remove(item));
    }

    /**
     * The items of a menu, in registration order.
     */
    public function getMenuItems(menuId:MenuId):Array<IMenuItem> {
        final items = menuItems.get(menuId);
        return items != null ? items.copy() : [];
    }

}
