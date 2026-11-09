// Ported from vscode src/vs/platform/commands/common/commands.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.commands.common;

/**
 * Metadata of a command (description and arguments).
 *
 * TODO(step 3): only the metadata type so far; the command registry comes
 * with the commands and keybindings, as a field of the `Cityscape` context.
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
