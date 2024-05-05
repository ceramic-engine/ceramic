package ceramic;

import ceramic.Shortcuts.*;
import haxe.DynamicAccess;
import haxe.Json;

class FragmentsAsset extends Asset {

    @observe public var fragments:DynamicAccess<FragmentData> = null;

    override public function new(name:String, ?variant:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('fragments', name, variant, options #if ceramic_debug_entity_allocs , pos #end);

    }

    override public function load() {

        status = LOADING;

        if (path == null) {
            log.warning('Cannot load fragments asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.texts.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }

        log.info('Load fragments $backendPath');
        app.backend.texts.load(realPath, loadOptions, function(text) {

            if (text != null) {
                try {
                    var rawFragments = Json.parse(text);
                    if (Reflect.hasField(rawFragments, 'version')) {
                        this.fragments = fromRawFragments(rawFragments);
                    }
                    else {
                        this.fragments = rawFragments;
                    }
                } catch (e:Dynamic) {
                    status = BROKEN;
                    log.error('Failed to parse fragments at path: $path');
                    emitComplete(false);
                    return;
                }
                status = READY;
                emitComplete(true);
            }
            else {
                status = BROKEN;
                log.error('Failed to load fragments at path: $path');
                emitComplete(false);
            }

        });

    }

    static function fromRawFragments(rawFragments:Dynamic):DynamicAccess<FragmentData> {

        var fragments:DynamicAccess<FragmentData> = {};

        var version = Std.int(rawFragments.version);
        if (version == 1) {
            // This is a newer fragments file format that needs to be processed
            // in order to be compatible with runtime format.
            var rawFragmentsList:Array<Dynamic> = rawFragments.fragments;
            if (rawFragmentsList != null) {
                for (rawFragment in rawFragmentsList) {

                    var fragmentData:FragmentData = {
                        id: rawFragment.id,
                        data: rawFragment.data ?? {},
                        width: rawFragment.width,
                        height: rawFragment.height,
                        components: rawFragment.components ?? {}
                    };

                    if (Reflect.hasField(rawFragment, 'color')) {
                        fragmentData.color = Color.fromString(rawFragment.color);
                    }

                    if (Reflect.hasField(rawFragment, 'transparent')) {
                        fragmentData.transparent = (rawFragment.transparent == true);
                    }

                    var schema:Dynamic = rawFragments.schema;
                    var items:Array<FragmentItem> = [];

                    if (Reflect.hasField(rawFragment, 'visuals')) {
                        var rawVisuals:Array<Dynamic> = rawFragment.visuals;
                        for (rawVisual in rawVisuals) {

                            var visualData:FragmentItem = {
                                id: rawVisual.id,
                                data: rawVisual.data ?? {},
                                entity: rawVisual.entity,
                                components: rawVisual.components ?? {},
                                props: {}
                            }

                            for (key in Reflect.fields(rawVisual)) {
                                switch key {
                                    case 'entity':
                                        final entity:String = Reflect.field(rawVisual, key);
                                        if (schema != null && entity != null && Reflect.hasField(schema, entity)) {
                                            visualData.schema = Reflect.field(schema, entity);
                                        }
                                    case 'kind' | 'id' | 'locked' | 'components' | 'data':
                                    case _:
                                        Reflect.setField(
                                            visualData.props,
                                            key,
                                            Reflect.field(rawVisual, key)
                                        );
                                }
                            }

                            items.push(visualData);
                        }
                    }

                    if (Reflect.hasField(rawFragment, 'entities')) {
                        var rawEntities:Array<Dynamic> = rawFragment.entities;
                        for (rawEntity in rawEntities) {

                            var entityData:FragmentItem = {
                                id: rawEntity.id,
                                data: rawEntity.data ?? {},
                                entity: rawEntity.entity,
                                components: rawEntity.components ?? {},
                                props: {}
                            }

                            for (key in Reflect.fields(rawEntity)) {
                                switch key {
                                    case 'entity':
                                        final entity:String = Reflect.field(rawEntity, key);
                                        if (schema != null && entity != null && Reflect.hasField(schema, entity)) {
                                            entityData.schema = Reflect.field(schema, entity);
                                        }
                                    case 'kind' | 'id' | 'locked' | 'components' | 'data':
                                    case _:
                                        Reflect.setField(
                                            entityData.props,
                                            key,
                                            Reflect.field(rawEntity, key)
                                        );
                                }
                            }

                            items.push(entityData);
                        }
                    }

                    fragmentData.items = items;
                    fragments.set(fragmentData.id, fragmentData);
                }
            }
        }
        else {
            log.warning('Unsupported fragments file version: $version');
        }

        return fragments;

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.texts.supportsHotReloadPath())
            return;

        var previousTime:Float = -1;
        if (previousFiles.exists(path)) {
            previousTime = previousFiles.get(path);
        }
        var newTime:Float = -1;
        if (newFiles.exists(path)) {
            newTime = newFiles.get(path);
        }

        if (newTime > previousTime) {
            log.info('Reload fragments (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        fragments = null;

    }

}
