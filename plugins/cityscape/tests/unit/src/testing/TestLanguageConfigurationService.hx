// Ported from vscode src/vs/editor/test/common/modes/testLanguageConfigurationService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.LanguageConfigurationRegistry;

class TestLanguageConfigurationService extends Disposable implements ILanguageConfigurationService {

    final _registry:LanguageConfigurationRegistry;

    final _onDidChange:Emitter<LanguageConfigurationServiceChangeEvent>;
    public var onDidChange(default, null):Event<LanguageConfigurationServiceChangeEvent>;

    public function new() {
        super();
        _registry = _register(new LanguageConfigurationRegistry());
        _onDidChange = _register(new Emitter<LanguageConfigurationServiceChangeEvent>());
        onDidChange = _onDidChange.event;
        _register(_registry.onDidChange((e) -> _onDidChange.fire(new LanguageConfigurationServiceChangeEvent(e.languageId))));
    }

    public function register(languageId:String, configuration:LanguageConfiguration, ?priority:Int):IDisposable {
        return _registry.register(languageId, configuration, priority);
    }

    public function getLanguageConfiguration(languageId:String):ResolvedLanguageConfiguration {
        final config = _registry.getLanguageConfiguration(languageId);
        return config != null ? config : new ResolvedLanguageConfiguration('unknown', {});
    }

}
