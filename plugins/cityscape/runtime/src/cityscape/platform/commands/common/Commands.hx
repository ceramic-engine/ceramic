// Ported from vscode src/vs/platform/commands/common/commands.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.commands.common;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;

/**
 * Metadata of a command (description and arguments).
 *
 * `description` is a plain string here (Monaco also accepts a localized
 * string object); `constraint` and `schema` of the arguments are not kept.
 */
typedef ICommandMetadata = {
    final description:String;
    @:optional final args:Array<ICommandArgument>;
    @:optional final returns:String;
}

typedef ICommandArgument = {
    final name:String;
    @:optional final isOptional:Bool;
    @:optional final description:String;
}

typedef ICommandEvent = {
    var commandId:String;
    var args:Array<Any>;
}

/**
 * A command handler: Monaco's `(accessor, ...args) => void`. The accessor is
 * the `Cityscape` context (no dependency injection), the arguments an array.
 */
typedef ICommandHandler = (accessor:Null<Cityscape>, args:Array<Any>) -> Void;

typedef ICommand = {
    var id:String;
    var handler:ICommandHandler;
    @:optional var metadata:Null<ICommandMetadata>;
}

/**
 * Monaco's `ICommandService`. `executeCommand` runs the command at once
 * (Monaco returns a promise): errors are thrown to the caller.
 */
interface ICommandService {
    var onWillExecuteCommand(get, never):Event<ICommandEvent>;
    var onDidExecuteCommand(get, never):Event<ICommandEvent>;
    function executeCommand(commandId:String, ?args:Array<Any>):Void;
}

/**
 * The commands of a `Cityscape` context (Monaco's global
 * `CommandsRegistry`). A command registered twice shadows the previous
 * registration until it is disposed.
 */
class CommandsRegistry {

    final _commands = new Map<String, Array<ICommand>>();

    final _onDidRegisterCommand = new Emitter<String>();
    public final onDidRegisterCommand:Event<String>;

    public function new() {
        onDidRegisterCommand = _onDidRegisterCommand.event;
        registerCommandHandler('noop', (_, _) -> {});
    }

    /**
     * `registerCommand(id, handler)`.
     */
    public function registerCommandHandler(id:String, handler:ICommandHandler):IDisposable {
        if (id == null || handler == null) {
            throw 'invalid command';
        }
        return this.registerCommand({id: id, handler: handler});
    }

    public function registerCommand(command:ICommand):IDisposable {

        if (command == null) {
            throw 'invalid command';
        }

        // find a place to store the command
        final id = command.id;

        var commands = this._commands.get(id);
        if (commands == null) {
            commands = [];
            this._commands.set(id, commands);
        }

        // LinkedList.unshift: the last registration comes first
        commands.unshift(command);

        final ret = Lifecycle.toDisposable(() -> {
            final list = this._commands.get(id);
            if (list != null) {
                list.remove(command);
                if (list.length == 0) {
                    this._commands.remove(id);
                }
            }
        });

        // tell the world about this command
        this._onDidRegisterCommand.fire(id);

        return ret;
    }

    public function registerCommandAlias(oldId:String, newId:String):IDisposable {
        return this.registerCommandHandler(oldId, (accessor, args) -> {
            if (accessor != null) {
                accessor.commandService.executeCommand(newId, args);
            }
        });
    }

    public function getCommand(id:String):Null<ICommand> {
        final list = this._commands.get(id);
        if (list == null || list.length == 0) {
            return null;
        }
        return list[0];
    }

    public function getCommands():Map<String, ICommand> {
        final result = new Map<String, ICommand>();
        for (key in this._commands.keys()) {
            final command = this.getCommand(key);
            if (command != null) {
                result.set(key, command);
            }
        }
        return result;
    }

}
