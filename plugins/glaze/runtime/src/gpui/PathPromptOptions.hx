// Ported from gpui-pre 0.3.10: src/platform.rs (PathPromptOptions)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The options of `App.promptForPaths`.
 */
class PathPromptOptions {

    /** Should the prompt allow files to be selected? */
    public var files:Bool;

    /** Should the prompt allow directories to be selected? */
    public var directories:Bool;

    /** Should the prompt allow multiple files to be selected? */
    public var multiple:Bool;

    /** The prompt to show to a user when selecting a path. */
    public var prompt:Null<String> = null;

    public function new(files:Bool, directories:Bool, multiple:Bool, ?prompt:String) {
        this.files = files;
        this.directories = directories;
        this.multiple = multiple;
        this.prompt = prompt;
    }

}
