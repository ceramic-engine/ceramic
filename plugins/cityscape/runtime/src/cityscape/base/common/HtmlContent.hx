// Ported from vscode src/vs/base/common/htmlContent.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Uri.UriComponents;
import haxe.extern.EitherType;

/**
 * Markdown text with its rendering options (hover messages, decorations).
 */
typedef IMarkdownString = {
    final value:String;
    @:optional final isTrusted:EitherType<Bool, MarkdownStringTrustedOptions>;
    @:optional final supportThemeIcons:Bool;
    @:optional final supportHtml:Bool;
    @:optional final baseUri:UriComponents;
    @:optional var uris:Map<String, UriComponents>;
}

typedef MarkdownStringTrustedOptions = {
    final enabledCommands:Array<String>;
}
