// Ported from vscode src/vs/base/common/uri.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * The serializable parts of a `Uri`.
 */
typedef UriComponents = {
    var scheme:String;
    @:optional var authority:String;
    @:optional var path:String;
    @:optional var query:String;
    @:optional var fragment:String;
}

/**
 * The changes of `Uri.with`: a field left out (or set to null) keeps the
 * current value... except that Monaco distinguishes `undefined` (keep) from
 * `null` (empty); Haxe has a single null, so use `''` to empty a part.
 */
typedef UriChange = {
    @:optional var scheme:String;
    @:optional var authority:String;
    @:optional var path:String;
    @:optional var query:String;
    @:optional var fragment:String;
}

/**
 * Uniform Resource Identifier (Uri) http://tools.ietf.org/html/rfc3986.
 * This class is a simple parser which creates the basic component parts
 * (http://tools.ietf.org/html/rfc3986#section-3) with minimal validation
 * and encoding.
 *
 * ```txt
 *       foo://example.com:8042/over/there?name=ferret#nose
 *       \_/   \______________/\_________/ \_________/ \__/
 *        |           |            |            |        |
 *     scheme     authority       path        query   fragment
 *        |   _____________________|__
 *       / \ /                        \
 *       urn:example:animal:ferret:nose
 * ```
 *
 * Monaco's `URI` and its internal `Uri` subclass are merged (the cached
 * formatted string of `Uri` is kept). Ported: `parse`, `file`, `from`,
 * `with`, `toString`, `fsPath`, `isUri`. Not ported: `joinPath` and
 * `revive` (not needed yet).
 */
class Uri {

    static inline final _empty = '';

    static inline final _slash = '/';

    /**
     * scheme is the 'http' part of 'http://www.example.com/some/path?query#fragment'.
     * The part before the first colon.
     */
    public final scheme:String;

    /**
     * authority is the 'www.example.com' part of 'http://www.example.com/some/path?query#fragment'.
     * The part between the first double slashes and the next slash.
     */
    public final authority:String;

    /**
     * path is the '/some/path' part of 'http://www.example.com/some/path?query#fragment'.
     */
    public final path:String;

    /**
     * query is the 'query' part of 'http://www.example.com/some/path?query#fragment'.
     */
    public final query:String;

    /**
     * fragment is the 'fragment' part of 'http://www.example.com/some/path?query#fragment'.
     */
    public final fragment:String;

    var _formatted:Null<String> = null;

    var _fsPath:Null<String> = null;

    /**
     * Like Monaco's constructor taking the parts: the scheme defaults to
     * `file` unless `_strict`, the path of `http`, `https` and `file` uris
     * starts with a slash, and the parts are validated (throws).
     */
    public function new(scheme:Null<String>, ?authority:String, ?path:String, ?query:String, ?fragment:String, _strict:Bool = false) {
        this.scheme = _schemeFix(scheme != null ? scheme : _empty, _strict);
        this.authority = (authority != null ? authority : _empty);
        this.path = _referenceResolution(this.scheme, path != null ? path : _empty);
        this.query = (query != null ? query : _empty);
        this.fragment = (fragment != null ? fragment : _empty);

        _validateUri(this, _strict);
    }

    public static function isUri(thing:Any):Bool {
        return Std.isOfType(thing, Uri);
    }

    /**
     * Returns a string representing the corresponding file system path of
     * this Uri (see Monaco's `URI#fsPath`).
     */
    public var fsPath(get, never):String;
    function get_fsPath():String {
        if (_fsPath == null) {
            _fsPath = uriToFsPath(this, false);
        }
        return _fsPath;
    }

    // ---- modify to new -------------------------

    public function with(change:Null<UriChange>):Uri {
        if (change == null) {
            return this;
        }

        final scheme = (change.scheme == null ? this.scheme : change.scheme);
        final authority = (change.authority == null ? this.authority : change.authority);
        final path = (change.path == null ? this.path : change.path);
        final query = (change.query == null ? this.query : change.query);
        final fragment = (change.fragment == null ? this.fragment : change.fragment);

        if (scheme == this.scheme
            && authority == this.authority
            && path == this.path
            && query == this.query
            && fragment == this.fragment) {
            return this;
        }

        return new Uri(scheme, authority, path, query, fragment);
    }

    // ---- parse & validate ------------------------

    /**
     * Creates a new Uri from a string, e.g. `http://www.example.com/some/path`,
     * `file:///usr/home`, or `scheme:with/path`.
     *
     * @param value A string which represents an Uri (see `Uri#toString`).
     */
    public static function parse(value:String, _strict:Bool = false):Uri {
        final match = new RegExp('^(([^:/?#]+?):)?(\\/\\/([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?').exec(value);
        if (match == null) {
            return new Uri(_empty, _empty, _empty, _empty, _empty);
        }
        return new Uri(
            orEmpty(match[2]),
            percentDecode(orEmpty(match[4])),
            percentDecode(orEmpty(match[5])),
            percentDecode(orEmpty(match[7])),
            percentDecode(orEmpty(match[9])),
            _strict
        );
    }

    static inline function orEmpty(s:Null<String>):String {
        return (s == null ? _empty : s);
    }

    /**
     * Creates a new Uri from a file system path, e.g. `c:\my\files`,
     * `/usr/home`, or `\\server\share\some\path`.
     */
    public static function file(path:String):Uri {
        var authority = _empty;

        // normalize to fwd-slashes on windows,
        // on other systems bwd-slashes are valid
        // filename character, eg /f\oo/ba\r.txt
        if (Platform.isWindows) {
            path = StringTools.replace(path, '\\', _slash);
        }

        // check for authority as used in UNC shares
        // or use the path as given
        if (path.charAt(0) == _slash && path.charAt(1) == _slash) {
            final idx = path.indexOf(_slash, 2);
            if (idx == -1) {
                authority = path.substring(2);
                path = _slash;
            }
            else {
                authority = path.substring(2, idx);
                path = path.substring(idx);
                if (path.length == 0) {
                    path = _slash;
                }
            }
        }

        return new Uri('file', authority, path, _empty, _empty);
    }

    /**
     * Creates new Uri from uri components.
     */
    public static function from(components:UriComponents, ?strict:Bool):Uri {
        return new Uri(
            components.scheme,
            components.authority,
            components.path,
            components.query,
            components.fragment,
            strict == true
        );
    }

    // ---- printing/externalize ---------------------------

    /**
     * Creates a string representation for this Uri. It's guaranteed that
     * calling `Uri.parse` with the result of this function creates an Uri
     * which is equal to this Uri.
     *
     * @param skipEncoding Do not encode the result, default is `false`
     */
    public function toString(skipEncoding:Bool = false):String {
        if (!skipEncoding) {
            if (_formatted == null) {
                _formatted = _asFormatted(this, false);
            }
            return _formatted;
        }
        // we don't cache that
        return _asFormatted(this, true);
    }

    public function toJSON():UriComponents {
        return {
            scheme: scheme,
            authority: authority,
            path: path,
            query: query,
            fragment: fragment
        };
    }

    // ---- module functions -----------------------

    static function isSchemeChar(c:Int, first:Bool):Bool {
        // /^\w[\w\d+.-]*$/
        if (RegExp.isAsciiWordChar(c)) {
            return true;
        }
        return !first && (c == '+'.code || c == '.'.code || c == '-'.code);
    }

    static function _validateUri(ret:Uri, _strict:Bool):Void {
        // scheme, must be set
        if (ret.scheme.length == 0 && _strict) {
            throw '[UriError]: Scheme is missing: {scheme: "", authority: "${ret.authority}", path: "${ret.path}", query: "${ret.query}", fragment: "${ret.fragment}"}';
        }

        // scheme, https://tools.ietf.org/html/rfc3986#section-3.1
        // ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
        if (ret.scheme.length > 0) {
            for (i in 0...ret.scheme.length) {
                if (!isSchemeChar(StringTools.fastCodeAt(ret.scheme, i), i == 0)) {
                    throw '[UriError]: Scheme contains illegal characters.';
                }
            }
        }

        // path, http://tools.ietf.org/html/rfc3986#section-3.3
        // If a URI contains an authority component, then the path component
        // must either be empty or begin with a slash ("/") character.  If a URI
        // does not contain an authority component, then the path cannot begin
        // with two slash characters ("//").
        if (ret.path.length > 0) {
            if (ret.authority.length > 0) {
                if (!StringTools.startsWith(ret.path, '/')) {
                    throw '[UriError]: If a URI contains an authority component, then the path component must either be empty or begin with a slash ("/") character';
                }
            }
            else {
                if (StringTools.startsWith(ret.path, '//')) {
                    throw '[UriError]: If a URI does not contain an authority component, then the path cannot begin with two slash characters ("//")';
                }
            }
        }
    }

    // for a while we allowed uris *without* schemes and this is the migration
    // for them, e.g. an uri without scheme and without strict-mode warns and falls
    // back to the file-scheme. that should cause the least carnage and still be a
    // clear warning
    static function _schemeFix(scheme:String, _strict:Bool):String {
        if (scheme.length == 0 && !_strict) {
            return 'file';
        }
        return scheme;
    }

    // implements a bit of https://tools.ietf.org/html/rfc3986#section-5
    static function _referenceResolution(scheme:String, path:String):String {
        // the slash-character is our 'default base' as we don't
        // support constructing URIs relative to other URIs. This
        // also means that we alter and potentially break paths.
        // see https://tools.ietf.org/html/rfc3986#section-5.1.4
        switch scheme {
            case 'https' | 'http' | 'file':
                if (path.length == 0) {
                    path = _slash;
                }
                else if (path.charAt(0) != _slash) {
                    path = _slash + path;
                }
            case _:
        }
        return path;
    }

    // reserved characters: https://tools.ietf.org/html/rfc3986#section-2.2
    static function encodeTable(code:Int):Null<String> {
        return switch code {
            case ':'.code: '%3A'; // gen-delims
            case '/'.code: '%2F';
            case '?'.code: '%3F';
            case '#'.code: '%23';
            case '['.code: '%5B';
            case ']'.code: '%5D';
            case '@'.code: '%40';

            case '!'.code: '%21'; // sub-delims
            case '$'.code: '%24';
            case '&'.code: '%26';
            case '\''.code: '%27';
            case '('.code: '%28';
            case ')'.code: '%29';
            case '*'.code: '%2A';
            case '+'.code: '%2B';
            case ','.code: '%2C';
            case ';'.code: '%3B';
            case '='.code: '%3D';

            case ' '.code: '%20';
            case _: null;
        }
    }

    static function encodeURIComponentFast(uriComponent:String, isPath:Bool, isAuthority:Bool):String {
        var res:Null<String> = null;
        var nativeEncodePos = -1;

        for (pos in 0...uriComponent.length) {
            final code = StringTools.fastCodeAt(uriComponent, pos);

            // unreserved characters: https://tools.ietf.org/html/rfc3986#section-2.3
            if (
                (code >= 'a'.code && code <= 'z'.code)
                || (code >= 'A'.code && code <= 'Z'.code)
                || (code >= '0'.code && code <= '9'.code)
                || code == '-'.code
                || code == '.'.code
                || code == '_'.code
                || code == '~'.code
                || (isPath && code == '/'.code)
                || (isAuthority && code == '['.code)
                || (isAuthority && code == ']'.code)
                || (isAuthority && code == ':'.code)
            ) {
                // check if we are delaying native encode
                if (nativeEncodePos != -1) {
                    res += StringTools.urlEncode(uriComponent.substring(nativeEncodePos, pos));
                    nativeEncodePos = -1;
                }
                // check if we write into a new string (by default we try to return the param)
                if (res != null) {
                    res += uriComponent.charAt(pos);
                }
            }
            else {
                // encoding needed, we need to allocate a new string
                if (res == null) {
                    res = uriComponent.substr(0, pos);
                }

                // check with default table first
                final escaped = encodeTable(code);
                if (escaped != null) {
                    // check if we are delaying native encode
                    if (nativeEncodePos != -1) {
                        res += StringTools.urlEncode(uriComponent.substring(nativeEncodePos, pos));
                        nativeEncodePos = -1;
                    }

                    // append escaped variant to result
                    res += escaped;
                }
                else if (nativeEncodePos == -1) {
                    // use native encode only when needed
                    nativeEncodePos = pos;
                }
            }
        }

        if (nativeEncodePos != -1) {
            res += StringTools.urlEncode(uriComponent.substring(nativeEncodePos));
        }

        return res != null ? res : uriComponent;
    }

    static function encodeURIComponentMinimal(path:String, isPath:Bool, isAuthority:Bool):String {
        var res:Null<String> = null;
        for (pos in 0...path.length) {
            final code = StringTools.fastCodeAt(path, pos);
            if (code == '#'.code || code == '?'.code) {
                if (res == null) {
                    res = path.substr(0, pos);
                }
                res += encodeTable(code);
            }
            else {
                if (res != null) {
                    res += path.charAt(pos);
                }
            }
        }
        return res != null ? res : path;
    }

    /**
     * Compute `fsPath` for the given uri
     */
    public static function uriToFsPath(uri:Uri, keepDriveLetterCasing:Bool):String {
        var value:String;
        final path = uri.path;
        inline function codeAt(i:Int):Int {
            return i < path.length ? StringTools.fastCodeAt(path, i) : -1;
        }
        if (uri.authority.length > 0 && path.length > 1 && uri.scheme == 'file') {
            // unc path: file://shares/c$/far/boo
            value = '//${uri.authority}${path}';
        }
        else if (
            codeAt(0) == '/'.code
            && (codeAt(1) >= 'A'.code && codeAt(1) <= 'Z'.code || codeAt(1) >= 'a'.code && codeAt(1) <= 'z'.code)
            && codeAt(2) == ':'.code
        ) {
            if (!keepDriveLetterCasing) {
                // windows drive letter: file:///c:/far/boo
                value = path.charAt(1).toLowerCase() + path.substr(2);
            }
            else {
                value = path.substr(1);
            }
        }
        else {
            // other path
            value = path;
        }
        if (Platform.isWindows) {
            value = StringTools.replace(value, '/', '\\');
        }
        return value;
    }

    /**
     * Create the external version of a uri
     */
    static function _asFormatted(uri:Uri, skipEncoding:Bool):String {
        final encoder = !skipEncoding ? encodeURIComponentFast : encodeURIComponentMinimal;

        var res = '';
        final scheme = uri.scheme;
        var authority = uri.authority;
        var path = uri.path;
        final query = uri.query;
        final fragment = uri.fragment;
        if (scheme.length > 0) {
            res += scheme;
            res += ':';
        }
        if (authority.length > 0 || scheme == 'file') {
            res += _slash;
            res += _slash;
        }
        if (authority.length > 0) {
            var idx = authority.indexOf('@');
            if (idx != -1) {
                // <user>@<auth>
                final userinfo = authority.substr(0, idx);
                authority = authority.substr(idx + 1);
                idx = userinfo.lastIndexOf(':');
                if (idx == -1) {
                    res += encoder(userinfo, false, false);
                }
                else {
                    // <user>:<pass>@<auth>
                    res += encoder(userinfo.substr(0, idx), false, false);
                    res += ':';
                    res += encoder(userinfo.substr(idx + 1), false, true);
                }
                res += '@';
            }
            authority = authority.toLowerCase();
            idx = authority.lastIndexOf(':');
            if (idx == -1) {
                res += encoder(authority, false, true);
            }
            else {
                // <auth>:<port>
                res += encoder(authority.substr(0, idx), false, true);
                res += authority.substr(idx);
            }
        }
        if (path.length > 0) {
            // lower-case windows drive letters in /C:/fff or C:/fff
            if (path.length >= 3 && StringTools.fastCodeAt(path, 0) == '/'.code && StringTools.fastCodeAt(path, 2) == ':'.code) {
                final code = StringTools.fastCodeAt(path, 1);
                if (code >= 'A'.code && code <= 'Z'.code) {
                    path = '/${String.fromCharCode(code + 32)}:${path.substr(3)}'; // "/c:".length === 3
                }
            }
            else if (path.length >= 2 && StringTools.fastCodeAt(path, 1) == ':'.code) {
                final code = StringTools.fastCodeAt(path, 0);
                if (code >= 'A'.code && code <= 'Z'.code) {
                    path = '${String.fromCharCode(code + 32)}:${path.substr(2)}'; // "/c:".length === 3
                }
            }
            // encode the rest of the path
            res += encoder(path, true, false);
        }
        if (query.length > 0) {
            res += '?';
            res += encoder(query, false, false);
        }
        if (fragment.length > 0) {
            res += '#';
            res += !skipEncoding ? encodeURIComponentFast(fragment, false, false) : fragment;
        }
        return res;
    }

    // --- decode

    static function decodeURIComponentGraceful(str:String):String {
        try {
            final decoded = StringTools.urlDecode(str);
            if (decoded == null) {
                throw 'invalid';
            }
            return decoded;
        }
        catch (e:Dynamic) {
            if (str.length > 3) {
                return str.substr(0, 3) + decodeURIComponentGraceful(str.substr(3));
            }
            else {
                return str;
            }
        }
    }

    static function percentDecode(str:String):String {
        // /(%[0-9A-Za-z][0-9A-Za-z])+/g
        final regex = new RegExp('(%[0-9A-Za-z][0-9A-Za-z])+', 'g');
        var result:Null<StringBuf> = null;
        var last = 0;
        while (true) {
            final m = regex.exec(str);
            if (m == null) {
                break;
            }
            if (result == null) {
                result = new StringBuf();
            }
            result.addSub(str, last, m.index - last);
            result.add(decodeURIComponentGraceful(m[0]));
            last = m.index + m[0].length;
        }
        if (result == null) {
            return str;
        }
        result.addSub(str, last, str.length - last);
        return result.toString();
    }

}
