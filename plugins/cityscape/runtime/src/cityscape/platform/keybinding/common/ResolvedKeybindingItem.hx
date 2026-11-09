// Ported from vscode src/vs/platform/keybinding/common/resolvedKeybindingItem.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.keybinding.common;

import cityscape.base.common.CharCode;
import cityscape.base.common.Keybindings.ResolvedKeybinding;
import cityscape.platform.contextkey.common.ContextKey.ContextKeyExpression;

class ResolvedKeybindingItem {

    public final resolvedKeybinding:Null<ResolvedKeybinding>;
    public final chords:Array<String>;
    public final bubble:Bool;
    public final command:Null<String>;
    public final commandArgs:Any;
    public final when:Null<ContextKeyExpression>;
    public final isDefault:Bool;
    public final extensionId:Null<String>;
    public final isBuiltinExtension:Bool;

    public function new(resolvedKeybinding:Null<ResolvedKeybinding>, command:Null<String>, commandArgs:Any, when:Null<ContextKeyExpression>, isDefault:Bool, extensionId:Null<String>, isBuiltinExtension:Bool) {
        this.resolvedKeybinding = resolvedKeybinding;
        var chords:Array<String> = resolvedKeybinding != null ? ResolvedKeybindingItemUtils.toEmptyArrayIfContainsNull(resolvedKeybinding.getDispatchChords()) : [];
        if (resolvedKeybinding != null && chords.length == 0) {
            // handle possible single modifier chord keybindings
            chords = ResolvedKeybindingItemUtils.toEmptyArrayIfContainsNull(resolvedKeybinding.getSingleModifierDispatchChords());
        }
        this.chords = chords;
        this.bubble = (command != null && command.length > 0 ? StringTools.fastCodeAt(command, 0) == CharCode.Caret : false);
        this.command = this.bubble ? command.substr(1) : command;
        this.commandArgs = commandArgs;
        this.when = when;
        this.isDefault = isDefault;
        this.extensionId = extensionId;
        this.isBuiltinExtension = isBuiltinExtension;
    }

}

class ResolvedKeybindingItemUtils {

    public static function toEmptyArrayIfContainsNull<T>(arr:Array<Null<T>>):Array<T> {
        final result:Array<T> = [];
        for (i in 0...arr.length) {
            final element = arr[i];
            if (element == null) {
                return [];
            }
            result.push(element);
        }
        return result;
    }

}
