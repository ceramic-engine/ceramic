package ceramic;

using StringTools;

class MimeType {

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

    public static inline function isText(type:String):Bool {

        return !isBinary(type);

    }

}