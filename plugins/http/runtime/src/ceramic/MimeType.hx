package ceramic;

using StringTools;

/**
 * MIME type utility class for determining content type characteristics.
 * 
 * This class provides helper methods to analyze MIME types and determine whether
 * content should be treated as text or binary data. It's used internally by the
 * HTTP plugin to decide how to process response content.
 * 
 * The classification is based on standard MIME type conventions and includes
 * support for common text-based formats like HTML, CSS, JavaScript, JSON, XML,
 * and various text subtypes.
 * 
 * Example usage:
 * ```haxe
 * var contentType = "application/json; charset=utf-8";
 * 
 * if (MimeType.isText(contentType)) {
 *     // Process as text content
 *     var textData = response.content;
 * } else {
 *     // Process as binary content
 *     var binaryData = response.binaryContent;
 * }
 * ```
 */
class MimeType {

    /**
     * Determines if a MIME type represents binary content.
     * 
     * This method analyzes the given MIME type string and returns true if the content
     * should be treated as binary data. The method handles MIME types with parameters
     * (e.g., "text/html; charset=utf-8") by ignoring everything after the semicolon.
     * 
     * Text-based MIME types include:
     * - All types starting with "text/" (e.g., text/plain, text/html)
     * - JavaScript and JSON (application/javascript, application/json)
     * - XML-based formats (application/xml, image/svg+xml, etc.)
     * - Rich Text Format (application/rtf)
     * - Perl scripts (application/x-perl)
     * - Various specialized text formats
     * 
     * @param type The MIME type string to analyze (may include parameters)
     * @return true if the content is binary, false if it's text-based
     */
    public static function isBinary(type:String):Bool {

        var semicolonIndex = type.indexOf(';');
        if (semicolonIndex != -1) {
            type = type.substring(0, semicolonIndex);
        }

        type = type.trim().toLowerCase();

        if (type.startsWith('text/'))
            return false;

        return switch type {
            case 'text/html': false;
            case 'text/css': false;
            case 'text/xml': false;
            case 'application/javascript': false;
            case 'application/atom+xml': false;
            case 'application/rss+xml': false;
            case 'text/mathml': false;
            case 'text/plain': false;
            case 'text/vnd.sun.j2me.app-descriptor': false;
            case 'text/vnd.wap.wml': false;
            case 'text/x-component': false;
            case 'image/svg+xml': false;
            case 'application/json': false;
            case 'application/rtf': false;
            case 'application/x-perl': false;
            case 'application/xhtml+xml': false;
            case 'application/xspf+xml': false;
            case _: true;
        }

    }

    /**
     * Determines if a MIME type represents text content.
     * 
     * This is a convenience method that returns the inverse of isBinary().
     * Use this when you want to check if content should be processed as text.
     * 
     * @param type The MIME type string to analyze (may include parameters)
     * @return true if the content is text-based, false if it's binary
     */
    public static inline function isText(type:String):Bool {

        return !isBinary(type);

    }

}