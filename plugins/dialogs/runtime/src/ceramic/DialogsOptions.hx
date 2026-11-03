package ceramic;

/**
 * Options of `Dialogs.choosePaths` and `Dialogs.chooseNewPath`.
 *
 * Every field is optional. Example:
 * ```haxe
 * Dialogs.chooseNewPath({
 *     directory: '/Users/me/Downloads',
 *     defaultName: 'export.csv',
 *     filters: [{name: 'CSV', extensions: ['csv']}]
 * }, (path, error) -> {
 *     if (path != null) Files.saveContent(path, csv);
 * });
 * ```
 */
typedef DialogsOptions = {

    /**
     * Title of the dialog window (not shown by every platform).
     */
    @:optional var title:String;

    /**
     * Label of the accept button (macOS and Windows), for example "Open" or "Export".
     */
    @:optional var prompt:String;

    /**
     * Folder the dialog starts in.
     */
    @:optional var directory:String;

    /**
     * File name proposed by a save dialog (`chooseNewPath`).
     */
    @:optional var defaultName:String;

    /**
     * File type filters. The user may still be allowed to pick other files.
     */
    @:optional var filters:Array<DialogsFileFilter>;

    /**
     * `choosePaths`: whether files can be chosen (default true unless
     * `directories` is true).
     */
    @:optional var files:Bool;

    /**
     * `choosePaths`: whether folders can be chosen (default false). Native
     * dialogs pick either files or folders: when both are requested, folders
     * are picked (see `Dialogs.canSelectMixedFilesAndDirectories`).
     */
    @:optional var directories:Bool;

    /**
     * `choosePaths`: whether several entries can be chosen (default false).
     */
    @:optional var multiple:Bool;

}
