package ceramic;

/**
 * File type filter specification for native file dialogs.
 *
 * Used to restrict the types of files shown in open/save dialogs,
 * making it easier for users to find relevant files. Each filter
 * represents a category of files with a human-readable name and
 * a list of associated file extensions.
 *
 * Example usage:
 * ```haxe
 * var imageFilter = {
 *     name: "Image Files",
 *     extensions: ["png", "jpg", "jpeg", "gif"]
 * };
 *
 * Dialogs.openFile("Select Image", [imageFilter], function(path) {
 *     // Handle selected file
 * });
 * ```
 */
typedef DialogsFileFilter = {

    /**
     * Human-readable name for this filter.
     * Displayed in the file type dropdown of the dialog.
     * Examples: "Image Files", "Text Documents", "Ceramic Projects"
     */
    var name:String;

    /**
     * Array of file extensions to include (without dots).
     * Examples: ["png", "jpg"], ["txt", "md"]
     */
    var extensions:Array<String>;

}