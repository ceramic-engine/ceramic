// Ported from vscode src/vs/editor/common/tokenizationRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

import cityscape.base.common.Color;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes.ColorId;
import cityscape.common.Languages;

/**
 * The tokenization registry of a `Cityscape` context (Monaco has a global
 * one). Factories are resolved synchronously.
 */
class TokenizationRegistry<TSupport> implements ITokenizationRegistry<TSupport> {

    final _tokenizationSupports = new Map<String, TSupport>();

    final _factories = new Map<String, TokenizationSupportFactoryData<TSupport>>();

    final _onDidChange = new Emitter<ITokenizationSupportChangedEvent>();

    public var onDidChange(default, null):Event<ITokenizationSupportChangedEvent>;

    var _colorMap:Null<Array<Color>>;

    public function new() {
        onDidChange = _onDidChange.event;
        _colorMap = null;
    }

    public function handleChange(languageIds:Array<String>):Void {
        _onDidChange.fire({
            changedLanguages: languageIds,
            changedColorMap: false
        });
    }

    public function register(languageId:String, support:TSupport):IDisposable {
        _tokenizationSupports.set(languageId, support);
        handleChange([languageId]);
        return Lifecycle.toDisposable(() -> {
            if (_tokenizationSupports.get(languageId) != support) {
                return;
            }
            _tokenizationSupports.remove(languageId);
            handleChange([languageId]);
        });
    }

    public function get(languageId:String):Null<TSupport> {
        return _tokenizationSupports.get(languageId);
    }

    public function registerFactory(languageId:String, factory:ILazyTokenizationSupport<TSupport>):IDisposable {
        final existing = _factories.get(languageId);
        if (existing != null) {
            existing.dispose();
        }
        final myData = new TokenizationSupportFactoryData(this, languageId, factory);
        _factories.set(languageId, myData);
        return Lifecycle.toDisposable(() -> {
            final v = _factories.get(languageId);
            if (v == null || v != myData) {
                return;
            }
            _factories.remove(languageId);
            v.dispose();
        });
    }

    public function getOrCreate(languageId:String):Null<TSupport> {
        // check first if the support is already set
        final tokenizationSupport = get(languageId);
        if (tokenizationSupport != null) {
            return tokenizationSupport;
        }

        final factory = _factories.get(languageId);
        if (factory == null || factory.isResolved) {
            // no factory or factory.resolve already finished
            return null;
        }

        factory.resolve();

        return get(languageId);
    }

    public function isResolved(languageId:String):Bool {
        final tokenizationSupport = get(languageId);
        if (tokenizationSupport != null) {
            return true;
        }

        final factory = _factories.get(languageId);
        if (factory == null || factory.isResolved) {
            return true;
        }

        return false;
    }

    public function setColorMap(colorMap:Array<Color>):Void {
        _colorMap = colorMap;
        _onDidChange.fire({
            changedLanguages: [for (k in _tokenizationSupports.keys()) k],
            changedColorMap: true
        });
    }

    public function getColorMap():Null<Array<Color>> {
        return _colorMap;
    }

    public function getDefaultBackground():Null<Color> {
        if (_colorMap != null && _colorMap.length > (ColorId.DefaultBackground : Int)) {
            return _colorMap[ColorId.DefaultBackground];
        }
        return null;
    }

}

private class TokenizationSupportFactoryData<TSupport> extends Disposable {

    var _isDisposed = false;

    var _isResolved = false;

    final _registry:TokenizationRegistry<TSupport>;

    final _languageId:String;

    final _factory:ILazyTokenizationSupport<TSupport>;

    public var isResolved(get, never):Bool;
    inline function get_isResolved():Bool {
        return _isResolved;
    }

    public function new(registry:TokenizationRegistry<TSupport>, languageId:String, factory:ILazyTokenizationSupport<TSupport>) {
        super();
        _registry = registry;
        _languageId = languageId;
        _factory = factory;
    }

    override public function dispose():Void {
        _isDisposed = true;
        super.dispose();
    }

    public function resolve():Void {
        if (_isResolved) {
            return;
        }
        final value = _factory.getTokenizationSupport();
        _isResolved = true;
        if (value != null && !_isDisposed) {
            _register(_registry.register(_languageId, value));
        }
    }

}
