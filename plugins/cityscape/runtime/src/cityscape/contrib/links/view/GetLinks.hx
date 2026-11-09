// Ported from vscode src/vs/editor/contrib/links/browser/getLinks.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.links.view;

import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.base.common.Uri;
import cityscape.common.LanguageFeatureRegistry;
import cityscape.common.Languages.ILink;
import cityscape.common.Languages.ILinksList;
import cityscape.common.Languages.LinkProvider;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Range;
import haxe.extern.EitherType;

/**
 * A link of a provider, resolved on demand (`resolve`).
 */
class Link {

    var _link:ILink;
    final _provider:LinkProvider;

    public function new(link:ILink, provider:LinkProvider) {
        this._link = link;
        this._provider = provider;
    }

    public function toJSON():ILink {
        return {
            range: this.range,
            url: this.url,
            tooltip: this.tooltip
        };
    }

    public var range(get, never):IRange;
    function get_range():IRange {
        return this._link.range;
    }

    public var url(get, never):Null<EitherType<Uri, String>>;
    function get_url():Null<EitherType<Uri, String>> {
        return this._link.url;
    }

    public var tooltip(get, never):Null<String>;
    function get_tooltip():Null<String> {
        return this._link.tooltip;
    }

    static function hasUrl(link:ILink):Bool {
        final url = link.url;
        // `if (this._link.url)`: an empty string is falsy
        return url != null && !(Std.isOfType(url, std.String) && (cast url : String).length == 0);
    }

    /**
     * The target of the link (a `Uri` or a string), asking the provider's
     * `resolveLink` when the link has none. Rejects with `'missing'` when
     * the link has no target.
     */
    public function resolve(token:CancellationToken):Promise<EitherType<Uri, String>> {
        if (hasUrl(this._link)) {
            return Promise.resolve(this._link.url);
        }

        final resolveLink = this._provider.resolveLink;
        if (resolveLink != null) {
            return Promise.fromCallback((done:(value:Null<ILink>) -> Void) -> resolveLink(this._link, token, done)).thenPromise(value -> {
                this._link = value != null ? value : this._link;
                if (hasUrl(this._link)) {
                    // recurse
                    return this.resolve(token);
                }

                return Promise.reject('missing');
            });
        }

        return Promise.reject('missing');
    }
}

/**
 * The links of the providers of a model, merged.
 */
class LinksList {

    public final links:Array<Link>;

    final _disposables = new DisposableStore();

    public function new(tuples:Array<{list:ILinksList, provider:LinkProvider}>) {

        var links:Array<Link> = [];
        for (tuple in tuples) {
            final list = tuple.list;
            final provider = tuple.provider;
            // merge all links
            final newLinks = [for (link in list.links) new Link(link, provider)];
            links = LinksList._union(links, newLinks);
            // register disposables
            if (list.dispose != null) {
                this._disposables.add(Lifecycle.toDisposable(list.dispose));
            }
        }
        this.links = links;
    }

    public function dispose():Void {
        this._disposables.dispose();
        this.links.resize(0);
    }

    static function _union(oldLinks:Array<Link>, newLinks:Array<Link>):Array<Link> {
        // reunite oldLinks with newLinks and remove duplicates
        final result:Array<Link> = [];
        var oldIndex = 0;
        var newIndex = 0;
        final oldLen = oldLinks.length;
        final newLen = newLinks.length;

        while (oldIndex < oldLen && newIndex < newLen) {
            final oldLink = oldLinks[oldIndex];
            final newLink = newLinks[newIndex];

            if (Range.areIntersectingOrTouching(oldLink.range, newLink.range)) {
                // Remove the oldLink
                oldIndex++;
                continue;
            }

            final comparisonResult = Range.compareRangesUsingStarts(oldLink.range, newLink.range);

            if (comparisonResult < 0) {
                // oldLink is before
                result.push(oldLink);
                oldIndex++;
            }
            else {
                // newLink is before
                result.push(newLink);
                newIndex++;
            }
        }

        while (oldIndex < oldLen) {
            result.push(oldLinks[oldIndex]);
            oldIndex++;
        }
        while (newIndex < newLen) {
            result.push(newLinks[newIndex]);
            newIndex++;
        }

        return result;
    }

}

/**
 * The module function of getLinks.ts. The `_executeLinkProvider` command
 * is not ported: Cityscape's commands return nothing (call `getLinks`).
 */
class GetLinks {

    /**
     * Asks all the link providers of the model (in parallel, Monaco's
     * `ordered(model).reverse()`), merged in a `LinksList`; an empty list
     * when the token is cancelled.
     */
    public static function getLinks(providers:LanguageFeatureRegistry<LinkProvider>, model:ITextModel, token:CancellationToken):Promise<LinksList> {

        final ordered = providers.ordered(model);
        ordered.reverse();
        final lists:Array<Null<{list:ILinksList, provider:LinkProvider}>> = [for (_ in ordered) null];

        // ask all providers for links in parallel
        final promises:Array<Promise<Bool>> = [];
        for (i in 0...ordered.length) {
            final provider = ordered[i];
            promises.push(Promise.fromCallback((done:(value:Null<ILinksList>) -> Void) -> {
                try {
                    provider.provideLinks(model, token, done);
                }
                catch (err:Dynamic) {
                    Errors.onUnexpectedExternalError(err);
                    done(null);
                }
            }).then(result -> {
                if (result != null) {
                    lists[i] = {list: result, provider: provider};
                }
                return true;
            }, err -> {
                Errors.onUnexpectedExternalError(err);
                return true;
            }));
        }

        return Promise.all(promises).then(_ -> {
            final result = new LinksList([for (l in lists) if (l != null) l]);
            if (!token.isCancellationRequested) {
                return result;
            }
            result.dispose();
            return new LinksList([]);
        });
    }

}
