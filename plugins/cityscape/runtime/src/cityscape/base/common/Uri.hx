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
 * A uniform resource identifier, the key of a text model.
 *
 * TODO(step 1): placeholder with the fields only. uri.ts (parsing,
 * `file()`, `with()`, encoding in `toString()`) is ported with the model
 * service.
 */
class Uri {

    public final scheme:String;

    public final authority:String;

    public final path:String;

    public final query:String;

    public final fragment:String;

    public function new(scheme:String, authority:String, path:String, query:String, fragment:String) {
        this.scheme = scheme;
        this.authority = authority;
        this.path = path;
        this.query = query;
        this.fragment = fragment;
    }

}
