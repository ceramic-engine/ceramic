// Ported from vscode src/vs/platform/keybinding/common/keybindingsRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.base.common.Keybindings;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Platform;
import cityscape.platform.commands.common.Commands;
import cityscape.platform.contextkey.common.ContextKey.ContextKeyExpression;

typedef IKeybindingItem = {
    var keybinding:Null<Keybinding>;
    var command:Null<String>;
    @:optional var commandArgs:Any;
    var when:Null<ContextKeyExpression>;
    var weight1:Int;
    var weight2:Int;
    var extensionId:Null<String>;
    var isBuiltinExtension:Bool;
}

typedef IPlatformKeybindings = {
    var primary:Int;
    @:optional var secondary:Array<Int>;
}

typedef IKeybindings = {
    @:optional var primary:Int;
    @:optional var secondary:Array<Int>;
    @:optional var win:IPlatformKeybindings;
    @:optional var linux:IPlatformKeybindings;
    @:optional var mac:IPlatformKeybindings;
}

typedef IKeybindingRule = {
    var id:String;
    var weight:Int;
    @:optional var args:Any;
    /**
     * Keybinding is disabled if expression returns false.
     */
    @:optional var when:Null<ContextKeyExpression>;
    @:optional var primary:Int;
    @:optional var secondary:Array<Int>;
    @:optional var win:IPlatformKeybindings;
    @:optional var linux:IPlatformKeybindings;
    @:optional var mac:IPlatformKeybindings;
}

typedef IExtensionKeybindingRule = {
    var keybinding:Null<Keybinding>;
    var id:String;
    @:optional var args:Any;
    var weight:Int;
    var when:Null<ContextKeyExpression>;
    @:optional var extensionId:String;
    @:optional var isBuiltinExtension:Bool;
}

enum abstract KeybindingWeight(Int) from Int to Int {
    var EditorCore = 0;
    var EditorContrib = 100;
    var WorkbenchContrib = 200;
    var BuiltinExtension = 300;
    var ExternalExtension = 400;
}

typedef ICommandAndKeybindingRule = {
    > IKeybindingRule,
    var handler:ICommandHandler;
    @:optional var metadata:Null<ICommandMetadata>;
}

/**
 * Stores all built-in and extension-provided keybindings (but not ones that
 * user defines themselves), for one `Cityscape` context (Monaco's global
 * `KeybindingsRegistry`). The platform is read when a rule is registered
 * (Monaco's `OS`, here `Platform.OS`).
 */
class KeybindingsRegistry {

    final _coreKeybindings:Array<IKeybindingItem> = [];
    var _extensionKeybindings:Array<IKeybindingItem> = [];
    var _cachedMergedKeybindings:Null<Array<IKeybindingItem>> = null;
    final _commandsRegistry:CommandsRegistry;

    /**
     * Incremented when the keybindings change (the keybinding services
     * rebuild their resolver).
     */
    public var version(default, null):Int = 0;

    public function new(commandsRegistry:CommandsRegistry) {
        this._commandsRegistry = commandsRegistry;
    }

    /**
     * Take current platform into account and reduce to primary & secondary.
     */
    static function bindToCurrentPlatform(kb:IKeybindingRule):{primary:Null<Int>, secondary:Null<Array<Int>>} {
        final OS = Platform.OS;
        if (OS == OperatingSystem.Windows) {
            if (kb != null && kb.win != null) {
                return {primary: kb.win.primary, secondary: kb.win.secondary};
            }
        }
        else if (OS == OperatingSystem.Macintosh) {
            if (kb != null && kb.mac != null) {
                return {primary: kb.mac.primary, secondary: kb.mac.secondary};
            }
        }
        else {
            if (kb != null && kb.linux != null) {
                return {primary: kb.linux.primary, secondary: kb.linux.secondary};
            }
        }

        return {primary: kb.primary, secondary: kb.secondary};
    }

    public function registerKeybindingRule(rule:IKeybindingRule):IDisposable {
        final OS = Platform.OS;
        final actualKb = KeybindingsRegistry.bindToCurrentPlatform(rule);
        final result = new DisposableStore();

        if (actualKb != null && actualKb.primary != null && actualKb.primary != 0) {
            final kk = Keybindings.decodeKeybinding(actualKb.primary, OS);
            if (kk != null) {
                result.add(this._registerDefaultKeybinding(kk, rule.id, rule.args, rule.weight, 0, rule.when));
            }
        }

        if (actualKb != null && actualKb.secondary != null) {
            for (i in 0...actualKb.secondary.length) {
                final k = actualKb.secondary[i];
                final kk = Keybindings.decodeKeybinding(k, OS);
                if (kk != null) {
                    result.add(this._registerDefaultKeybinding(kk, rule.id, rule.args, rule.weight, -i - 1, rule.when));
                }
            }
        }
        return result;
    }

    public function setExtensionKeybindings(rules:Array<IExtensionKeybindingRule>):Void {
        final result:Array<IKeybindingItem> = [];
        for (rule in rules) {
            if (rule.keybinding != null) {
                result.push({
                    keybinding: rule.keybinding,
                    command: rule.id,
                    commandArgs: rule.args,
                    when: rule.when,
                    weight1: rule.weight,
                    weight2: 0,
                    extensionId: rule.extensionId,
                    isBuiltinExtension: rule.isBuiltinExtension == true
                });
            }
        }

        this._extensionKeybindings = result;
        this._cachedMergedKeybindings = null;
        this.version++;
    }

    public function registerCommandAndKeybindingRule(desc:ICommandAndKeybindingRule):IDisposable {
        return Lifecycle.combinedDisposable([
            this.registerKeybindingRule(desc),
            this._commandsRegistry.registerCommand({id: desc.id, handler: desc.handler, metadata: desc.metadata})
        ]);
    }

    function _registerDefaultKeybinding(keybinding:Keybinding, commandId:String, commandArgs:Any, weight1:Int, weight2:Int, when:Null<ContextKeyExpression>):IDisposable {
        final item:IKeybindingItem = {
            keybinding: keybinding,
            command: commandId,
            commandArgs: commandArgs,
            when: when,
            weight1: weight1,
            weight2: weight2,
            extensionId: null,
            isBuiltinExtension: false
        };
        this._coreKeybindings.push(item);
        this._cachedMergedKeybindings = null;
        this.version++;

        return Lifecycle.toDisposable(() -> {
            this._coreKeybindings.remove(item);
            this._cachedMergedKeybindings = null;
            this.version++;
        });
    }

    public function getDefaultKeybindings():Array<IKeybindingItem> {
        if (this._cachedMergedKeybindings == null) {
            final merged = this._coreKeybindings.concat(this._extensionKeybindings);
            haxe.ds.ArraySort.sort(merged, sorter);
            this._cachedMergedKeybindings = merged;
        }
        return this._cachedMergedKeybindings.copy();
    }

    static function sorter(a:IKeybindingItem, b:IKeybindingItem):Int {
        if (a.weight1 != b.weight1) {
            return a.weight1 - b.weight1;
        }
        if (a.command != null && b.command != null) {
            if (a.command < b.command) {
                return -1;
            }
            if (a.command > b.command) {
                return 1;
            }
        }
        return a.weight2 - b.weight2;
    }

}
