package ceramic;

/**
 * Central import file that includes all Ceramic API classes.
 * 
 * AllApi serves as a comprehensive import manifest for the Ceramic framework,
 * ensuring all classes are included in the compiled output. This is particularly
 * important for dynamic environments like scripting where classes need to be
 * available at runtime.
 * 
 * Features:
 * - Imports all core Ceramic classes and systems
 * - Imports all plugin classes when plugins are enabled
 * - Provides HScript configuration for scripting environments
 * - Ensures DCE (Dead Code Elimination) doesn't remove needed classes
 * 
 * The file is organized into sections:
 * - Standard Haxe imports
 * - Tracker framework imports
 * - Core Ceramic classes
 * - Plugin-specific imports (conditional compilation)
 * - HScript configuration method
 * 
 * Usage:
 * This file is typically imported by the build system or main application
 * to ensure all necessary classes are available. The @:keep metadata
 * prevents the class from being eliminated during compilation.
 * 
 * @see App
 * @see ceramic.scriptable
 */

import Std;
import StringTools;
import Math;
import Array;
import Type;
import haxe.io.Bytes;
import haxe.ds.StringMap;
#if plugin_script
import ceramic.scriptable.ScriptableMap;
#end

import tracker.Autorun;
import tracker.DynamicEvents;
import tracker.EventDispatcher;
import tracker.Events;
import tracker.History;
import tracker.Observable;
import tracker.Model;
import tracker.SaveModel;
import tracker.Serializable;
import tracker.SerializeChangeset;
import tracker.SerializeModel;
import tracker.Tracker;

/*
import assets.Databases;
import assets.Fonts;
import assets.Images;
import assets.Shaders;
import assets.Sounds;
import assets.Texts;
*/

#if plugin_script
import ceramic.scriptable.ScriptableAlphaColor;
#end
#if (ceramic_cppia_host || documentation) import ceramic.AlphaColor; #end
import ceramic.App;
import ceramic.Arc;
import ceramic.ArrayPool;
import ceramic.Assert;
import ceramic.Asset;
import ceramic.AssetId;
import ceramic.AssetOptions;
import ceramic.AssetPathInfo;
import ceramic.Assets;
import ceramic.AssetsLoadMethod;
import ceramic.AssetsScheduleMethod;
import ceramic.AssetStatus;
import ceramic.Audio;
import ceramic.AudioMixer;
import ceramic.AudioFilters;
import ceramic.AudioFilter;
import ceramic.AudioFilterWorklet;
import ceramic.AudioFilterBuffer;
import ceramic.LowPassFilter;
import ceramic.HighPassFilter;
import ceramic.AutoCollections;
import ceramic.BackgroundQueue;
import ceramic.BezierEasing;
import ceramic.BinaryAsset;
import ceramic.BitmapFont;
import ceramic.BitmapFontCharacter;
import ceramic.BitmapFontData;
import ceramic.BitmapFontDistanceFieldData;
import ceramic.BitmapFontParser;
#if plugin_script
import ceramic.scriptable.ScriptableBlending;
#end
#if (ceramic_cppia_host || documentation) import ceramic.Blending; #end
import ceramic.Border;
import ceramic.BorderPosition;
import ceramic.Camera;
import ceramic.Click;
import ceramic.Closure;
import ceramic.Collection;
import ceramic.CollectionEntry;
import ceramic.CollectionUtils;
import ceramic.scriptable.ScriptableColor;
#if (ceramic_cppia_host || documentation) import ceramic.Color; #end
import ceramic.Component;
import ceramic.ComputeFps;
import ceramic.ConvertArray;
import ceramic.ConvertIntBoolMap;
import ceramic.ConvertComponentMap;
import ceramic.ConvertField;
import ceramic.ConvertFont;
import ceramic.ConvertFragmentData;
import ceramic.ConvertMap;
import ceramic.ConvertTexture;
import ceramic.Csv;
import ceramic.CustomAssetKind;
import ceramic.DatabaseAsset;
import ceramic.DecomposedTransform;
import ceramic.DoubleClick;
import ceramic.Easing;
import ceramic.EasingUtils;
import ceramic.EditText;
import ceramic.Entity;
import ceramic.Enums;
import ceramic.Equal;
import ceramic.Errors;
import ceramic.Extensions;
import ceramic.FieldInfo;
import ceramic.Files;
import ceramic.FileWatcher;
import ceramic.Filter;
import ceramic.scriptable.ScriptableFlags;
#if (ceramic_cppia_host || documentation) import ceramic.Flags; #end
import ceramic.Float32Array;
import ceramic.FontAsset;
import ceramic.Fragment;
import ceramic.FragmentData;
import ceramic.FragmentItem;
import ceramic.Fragments;
import ceramic.FragmentsAsset;
import ceramic.GamepadAxis;
import ceramic.GamepadButton;
import ceramic.GeometryUtils;
import ceramic.GlyphQuad;
import ceramic.Group;
import ceramic.HashedString;
import ceramic.ImageAsset;
import ceramic.InitSettings;
import ceramic.Input;
import ceramic.IntBoolMap;
import ceramic.IntFloatMap;
import ceramic.IntMap;
import ceramic.IntIntMap;
import ceramic.Json;
import ceramic.Key;
import ceramic.KeyAcceleratorItem;
import ceramic.KeyBinding;
import ceramic.KeyBindings;
import ceramic.KeyCode;
import ceramic.Layer;
import ceramic.Lazy;
import ceramic.Line;
import ceramic.LineCap;
import ceramic.LineJoin;
import ceramic.Logger;
import ceramic.LongPress;
import ceramic.LowRes;
import ceramic.Mesh;
import ceramic.scriptable.ScriptableMeshColorMapping;
#if (ceramic_cppia_host || documentation) import ceramic.MeshColorMapping; #end
import ceramic.MeshExtensions;
import ceramic.MeshPool;
import ceramic.MouseButton;
import ceramic.Ngon;
#if plugin_script
import ceramic.scriptable.ScriptableMouseButton;
#end
#if (ceramic_cppia_host || documentation) import ceramic.MouseButton; #end
import ceramic.ParticleItem;
import ceramic.Particles;
import ceramic.ParticlesLaunchMode;
import ceramic.ParticlesStatus;
import ceramic.Path;
import ceramic.PersistentData;
import ceramic.PixelArt;
import ceramic.Pixels;
import ceramic.Platform;
import ceramic.Point;
import ceramic.Pool;
import ceramic.PremultiplyAlpha;
import ceramic.Quad;
import ceramic.ReadOnlyArray;
import ceramic.ReadOnlyMap;
import ceramic.ReadOnlyPoint;
import ceramic.Renderer;
import ceramic.RenderTexture;
import ceramic.ReusableArray;
import ceramic.Runner;
import ceramic.RuntimeAssets;
import ceramic.ScanCode;
import ceramic.Scene;
import ceramic.SceneStatus;
import ceramic.Screen;
import ceramic.ScreenOrientation;
import ceramic.ScreenScaling;
import ceramic.ScrollDirection;
import ceramic.Scroller;
import ceramic.ScrollerStatus;
import ceramic.SeedRandom;
import ceramic.SelectText;
import ceramic.Settings;
import ceramic.Shader;
import ceramic.ShaderAsset;
import ceramic.ShaderAttribute;
import ceramic.Shape;
import ceramic.Shortcuts;
import ceramic.Slug;
import ceramic.SortVisuals;
import ceramic.SortVisualsByDepth;
import ceramic.Sound;
import ceramic.SoundAsset;
import ceramic.SoundPlayer;
#if (sys && ceramic_sqlite) import ceramic.SqliteKeyValue; #end
import ceramic.Scene;
import ceramic.SceneStatus;
import ceramic.SceneSystem;
import ceramic.State;
import ceramic.StateMachine;
import ceramic.StateMachineBase;
import ceramic.StateMachineComponent;
import ceramic.StateMachineSystem;
import ceramic.System;
import ceramic.Systems;
import ceramic.Task;
import ceramic.Tasks;
import ceramic.Text;
import ceramic.TextAlign;
import ceramic.TextAsset;
import ceramic.TextInput;
import ceramic.TextInputDelegate;
import ceramic.TextureAtlas;
import ceramic.TextureAtlasPage;
import ceramic.TextureAtlasParser;
import ceramic.TextureAtlasRegion;
import ceramic.Texture;
import ceramic.TextureFilter;
import ceramic.TextureTile;
import ceramic.TextureTilePacker;
import ceramic.Timeline;
import ceramic.TimelineColorKeyframe;
import ceramic.TimelineColorTrack;
import ceramic.TimelineDegreesTrack;
import ceramic.TimelineFloatKeyframe;
import ceramic.TimelineFloatTrack;
import ceramic.TimelineKeyframe;
import ceramic.TimelineKeyframeData;
import ceramic.TimelineTrack;
import ceramic.TimelineTrackData;
import ceramic.Timelines;
import ceramic.Timer;
import ceramic.Touch;
import ceramic.Touches;
import ceramic.TouchesIterator;
import ceramic.TouchInfo;
import ceramic.TrackerBackend;
import ceramic.Transform;
import ceramic.TransformPool;
import ceramic.Triangle;
import ceramic.Triangulate;
import ceramic.Tween;
import ceramic.UInt8Array;
import ceramic.Utils;
import ceramic.Value;
import ceramic.ValueEntry;
import ceramic.Velocity;
import ceramic.VisibleBounds;
import ceramic.Visual;
import ceramic.VisualTransition;
import ceramic.WatchDirectory;
import ceramic.WaitCallbacks;

#if plugin_script
import ceramic.Script;
import ceramic.ScriptContent;
import ceramic.ScriptModule;
import ceramic.ScriptUtils;
#end

#if plugin_http
import ceramic.Http;
import ceramic.HttpMethod;
import ceramic.HttpRequestOptions;
import ceramic.HttpResponse;
#end

#if plugin_arcade
import ceramic.ArcadeSystem;
import ceramic.ArcadeWorld;
import ceramic.ArcadeSortGroup;
import ceramic.VisualArcadePhysics;
import arcade.Body;
import arcade.World;
import arcade.SortDirection;
import arcade.Collidable;
#end

#if plugin_nape
import ceramic.NapeSystem;
import ceramic.NapePhysicsBodyType;
import ceramic.VisualNapePhysics;
#end

#if plugin_tilemap
import ceramic.AutoTile;
import ceramic.AutoTileKind;
import ceramic.AutoTiler;
import ceramic.ConvertTilemapData;
import ceramic.Tilemap;
import ceramic.TilemapAsset;
import ceramic.TilemapData;
import ceramic.TilemapEditor;
import ceramic.TilemapLayer;
import ceramic.TilemapLayerData;
import ceramic.TilemapOrientation;
import ceramic.TilemapParser;
import ceramic.TilemapPlugin;
import ceramic.TilemapQuad;
import ceramic.TilemapRenderOrder;
import ceramic.TilemapStaggerAxis;
import ceramic.TilemapStaggerIndex;
import ceramic.TilemapTile;
import ceramic.Tileset;
import ceramic.TilesetGridOrientation;
import ceramic.TilesetImage;
#end

#if plugin_sprite
import ceramic.AsepriteJson;
import ceramic.AsepriteJsonParser;
import ceramic.ConvertSpriteSheet;
import ceramic.Sprite;
import ceramic.SpriteAsset;
import ceramic.SpriteSheet;
import ceramic.SpriteSheetAnimation;
import ceramic.SpriteSheetFrame;
import ceramic.SpriteSheetParser;
import ceramic.SpriteSystem;
#end

#if plugin_ase
import ceramic.AsepriteBlendFuncs;
import ceramic.AsepriteData;
import ceramic.AsepriteFrame;
import ceramic.AsepriteFrameLayer;
import ceramic.AsepritePalette;
import ceramic.AsepriteParser;
import ceramic.AsepriteTag;
#end

#if plugin_ldtk
import ceramic.LdtkData;
import ceramic.LdtkVisual;
import ceramic.TilemapLdtkParser;
#end

#if plugin_spine
import ceramic.ConvertSpineData;
import ceramic.Spine;
import ceramic.SpineAsset;
import ceramic.SpineBindVisual;
import ceramic.SpineBindVisualOptions;
import ceramic.SpineBounds;
import ceramic.SpineColors;
import ceramic.SpineData;
import ceramic.SpineFile;
import ceramic.SpineMontage;
import ceramic.SpineMontageAnimation;
import ceramic.SpineMontageDefaults;
import ceramic.SpineMontageSettings;
import ceramic.SpineMontageSpineSettings;
import ceramic.SpinePlugin;
import ceramic.SpineSystem;
import ceramic.SpineTextureLoader;
#end

#if plugin_ui
import ceramic.ChildrenDepth;
import ceramic.CollectionView;
import ceramic.CollectionViewDataSource;
import ceramic.CollectionViewFlowLayout;
import ceramic.CollectionViewItemFrame;
import ceramic.CollectionViewItemPosition;
import ceramic.CollectionViewItemsBehavior;
import ceramic.CollectionViewLayout;
import ceramic.ColumnLayout;
import ceramic.ImageView;
import ceramic.ImageViewScaling;
import ceramic.LayersLayout;
import ceramic.LayoutAlign;
import ceramic.LayoutDirection;
import ceramic.LayoutHorizontalAlign;
import ceramic.LayoutVerticalAlign;
import ceramic.LinearLayout;
import ceramic.RowLayout;
import ceramic.ScrollView;
import ceramic.TextView;
import ceramic.View;
import ceramic.ViewLayoutMask;
import ceramic.ViewSize;
import ceramic.ViewSystem;
#end

#if (plugin_imgui && (web || cpp))
import imgui.ImGui;
import imgui.Helpers;
#end

#if plugin_gif
import ceramic.GifCapture;
#end

#if plugin_elements
import elements.Im;
import elements.Context;
import elements.Theme;
import elements.Window;
#end

/**
 * Utility class to prevent dead code elimination of API classes.
 */
@:keep
class AllApi {

    /**
     * Forces inclusion of commonly used reflection methods.
     * This ensures Type.allEnums and Bytes.ofHex are available at runtime.
     */
    @:keep
    public static function apiCallCache() {

        var allEnums = Type.allEnums(null);
        var ofHex = Bytes.ofHex(null);

    }

    #if plugin_script

    /**
     * Configures an HScript interpreter with Ceramic API bindings.
     * 
     * This method sets up all necessary variable bindings to make Ceramic
     * classes and utilities available within HScript environments. It's used
     * by the scripting plugin to provide full framework access to scripts.
     * 
     * The configuration includes:
     * - Global shortcuts (app, screen, audio, etc.)
     * - Standard Haxe libraries (Std, Math, StringTools)
     * - Tracker framework classes
     * - All Ceramic core classes
     * - Plugin-specific classes when available
     * 
     * @param interp The HScript interpreter to configure
     */
    @:plugin('script')
    public static function configureHscript(interp:hscript.Interp):Void {

        interp.variables.set('app', ceramic.Shortcuts.app);
        interp.variables.set('screen', ceramic.Shortcuts.screen);
        interp.variables.set('audio', ceramic.Shortcuts.audio);
        interp.variables.set('settings', ceramic.Shortcuts.settings);
        //interp.variables.set('collections', ceramic.Shortcuts.collections);
        interp.variables.set('log', ceramic.Shortcuts.log);

        interp.variables.set('Std', ceramic.scriptable.ScriptableStd);
        interp.variables.set('StringTools', StringTools);
        interp.variables.set('Math', Math);
        interp.variables.set('StringMap', haxe.ds.StringMap);

        interp.variables.set('Autorun', tracker.Autorun);
        interp.variables.set('DynamicEvents', tracker.DynamicEvents);
        interp.variables.set('EventDispatcher', tracker.EventDispatcher);
        interp.variables.set('Events', tracker.Events);
        interp.variables.set('History', tracker.History);
        interp.variables.set('Observable', tracker.Observable);
        interp.variables.set('Model', tracker.Model);
        interp.variables.set('SaveModel', tracker.SaveModel);
        interp.variables.set('Serializable', tracker.Serializable);
        interp.variables.set('SerializeChangeset', tracker.SerializeChangeset);
        interp.variables.set('SerializeModel', tracker.SerializeModel);
        interp.variables.set('Tracker', tracker.Tracker);

        interp.variables.set('AlphaColor', ceramic.scriptable.ScriptableAlphaColor);
        interp.variables.set('App', ceramic.App);
        #if plugin_arcade
        interp.variables.set('ArcadeSystem', ceramic.ArcadeSystem);
        #end
        interp.variables.set('Asset', ceramic.Asset);
        interp.variables.set('AssetPathInfo', ceramic.AssetPathInfo);
        interp.variables.set('Assets', ceramic.Assets);
        interp.variables.set('AssetStatus', ceramic.AssetStatus);
        interp.variables.set('AudioMixer', ceramic.AudioMixer);
        interp.variables.set('BackgroundQueue', ceramic.BackgroundQueue);
        interp.variables.set('BezierEasing', ceramic.BezierEasing);
        interp.variables.set('BitmapFont', ceramic.BitmapFont);
        interp.variables.set('BitmapFontCharacter', ceramic.BitmapFontCharacter);
        interp.variables.set('BitmapFontData', ceramic.BitmapFontData);
        interp.variables.set('BitmapFontDistanceFieldData', ceramic.BitmapFontDistanceFieldData);
        interp.variables.set('BitmapFontParser', ceramic.BitmapFontParser);
        interp.variables.set('Blending', ceramic.scriptable.ScriptableBlending);
        interp.variables.set('Border', ceramic.Border);
        interp.variables.set('BorderPosition', ceramic.BorderPosition);
        interp.variables.set('Click', ceramic.Click);
        interp.variables.set('CollectionEntry', ceramic.CollectionEntry);
        interp.variables.set('Color', ceramic.scriptable.ScriptableColor);
        interp.variables.set('Component', ceramic.Component);
        interp.variables.set('ComputeFps', ceramic.ComputeFps);
        interp.variables.set('ConvertComponentMap', ceramic.ConvertComponentMap);
        interp.variables.set('ConvertField', ceramic.ConvertField);
        interp.variables.set('ConvertFont', ceramic.ConvertFont);
        interp.variables.set('ConvertFragmentData', ceramic.ConvertFragmentData);
        interp.variables.set('ConvertMap', ceramic.ConvertMap);
        interp.variables.set('ConvertTexture', ceramic.ConvertTexture);
        interp.variables.set('Csv', ceramic.Csv);
        interp.variables.set('CustomAssetKind', ceramic.CustomAssetKind);
        interp.variables.set('DatabaseAsset', ceramic.DatabaseAsset);
        //interp.variables.set('Databases', assets.Databases);
        interp.variables.set('DecomposedTransform', ceramic.DecomposedTransform);
        interp.variables.set('DoubleClick', ceramic.DoubleClick);
        interp.variables.set('Easing', ceramic.Easing);
        interp.variables.set('EditText', ceramic.EditText);
        interp.variables.set('Entity', ceramic.Entity);
        interp.variables.set('Enums', ceramic.Enums);
        interp.variables.set('Errors', ceramic.Errors);
        interp.variables.set('Extensions', ceramic.Extensions);
        interp.variables.set('FieldInfo', ceramic.FieldInfo);
        interp.variables.set('Files', ceramic.Files);
        interp.variables.set('FileWatcher', ceramic.FileWatcher);
        interp.variables.set('Filter', ceramic.Filter);
        interp.variables.set('Flags', ceramic.scriptable.ScriptableFlags);
        interp.variables.set('FontAsset', ceramic.FontAsset);
        //interp.variables.set('Fonts', assets.Fonts);
        interp.variables.set('Fragment', ceramic.Fragment);
        interp.variables.set('Fragments', ceramic.Fragments);
        interp.variables.set('FragmentsAsset', ceramic.FragmentsAsset);
        interp.variables.set('GeometryUtils', ceramic.GeometryUtils);
        interp.variables.set('GlyphQuad', ceramic.GlyphQuad);
        interp.variables.set('HashedString', ceramic.HashedString);
        interp.variables.set('ImageAsset', ceramic.ImageAsset);
        //interp.variables.set('Images', assets.Images);
        interp.variables.set('InitSettings', ceramic.InitSettings);
        interp.variables.set('Json', ceramic.Json);
        interp.variables.set('Key', ceramic.Key);
        interp.variables.set('KeyAcceleratorItem', ceramic.KeyAcceleratorItem);
        interp.variables.set('KeyBinding', ceramic.KeyBinding);
        interp.variables.set('KeyBindings', ceramic.KeyBindings);
        //interp.variables.set('KeyCode', ceramic.KeyCode);
        interp.variables.set('Layer', ceramic.Layer);
        interp.variables.set('Lazy', ceramic.Lazy);
        interp.variables.set('Line', ceramic.Line);
        interp.variables.set('LineCap', ceramic.LineCap);
        interp.variables.set('LineJoin', ceramic.LineJoin);
        interp.variables.set('Logger', ceramic.Logger);
        interp.variables.set('Mesh', ceramic.Mesh);
        interp.variables.set('MeshColorMapping', ceramic.scriptable.ScriptableMeshColorMapping);
        interp.variables.set('MeshPool', ceramic.MeshPool);
        interp.variables.set('MouseButton', ceramic.scriptable.ScriptableMouseButton);
        #if plugin_nape
        interp.variables.set('NapeSystem', ceramic.NapeSystem);
        #end
        interp.variables.set('ParticleItem', ceramic.ParticleItem);
        interp.variables.set('Particles', ceramic.Particles);
        interp.variables.set('ParticlesLaunchMode', ceramic.ParticlesLaunchMode);
        interp.variables.set('ParticlesStatus', ceramic.ParticlesStatus);
        interp.variables.set('Path', ceramic.Path);
        interp.variables.set('PersistentData', ceramic.PersistentData);
        interp.variables.set('Point', ceramic.Point);
        interp.variables.set('Quad', ceramic.Quad);
        interp.variables.set('Renderer', ceramic.Renderer);
        interp.variables.set('RenderTexture', ceramic.RenderTexture);
        interp.variables.set('ReusableArray', ceramic.ReusableArray);
        interp.variables.set('Runner', ceramic.Runner);
        interp.variables.set('RuntimeAssets', ceramic.RuntimeAssets);
        //interp.variables.set('ScanCode', ceramic.ScanCode);
        interp.variables.set('Screen', ceramic.Screen);
        interp.variables.set('ScreenScaling', ceramic.ScreenScaling);
        //interp.variables.set('Script', ceramic.Script);
        //interp.variables.set('Scripts', ceramic.Scripts);
        interp.variables.set('ScrollDirection', ceramic.ScrollDirection);
        interp.variables.set('Scroller', ceramic.Scroller);
        interp.variables.set('ScrollerStatus', ceramic.ScrollerStatus);
        interp.variables.set('SeedRandom', ceramic.SeedRandom);
        interp.variables.set('SelectText', ceramic.SelectText);
        interp.variables.set('Settings', ceramic.Settings);
        interp.variables.set('Shader', ceramic.Shader);
        interp.variables.set('ShaderAsset', ceramic.ShaderAsset);
        interp.variables.set('ShaderAttribute', ceramic.ShaderAttribute);
        //interp.variables.set('Shaders', assets.Shaders);
        interp.variables.set('Shape', ceramic.Shape);
        interp.variables.set('Shortcuts', ceramic.Shortcuts);
        interp.variables.set('SortVisuals', ceramic.SortVisuals);
        interp.variables.set('Sound', ceramic.Sound);
        interp.variables.set('SoundAsset', ceramic.SoundAsset);
        // TODO interp.variables.set('SoundPlayer', ceramic.SoundPlayer);
        //interp.variables.set('Sounds', assets.Sounds);
        // interp.variables.set('SqliteKeyValue', ceramic.SqliteKeyValue);
        // interp.variables.set('State', ceramic.State);
        // interp.variables.set('StateMachine', ceramic.StateMachine);
        // interp.variables.set('StateMachineImpl', ceramic.StateMachineImpl);
        interp.variables.set('Text', ceramic.Text);
        interp.variables.set('TextAlign', ceramic.TextAlign);
        interp.variables.set('TextAsset', ceramic.TextAsset);
        interp.variables.set('TextInput', ceramic.TextInput);
        interp.variables.set('TextInputDelegate', ceramic.TextInputDelegate);
        //interp.variables.set('Texts', assets.Texts);
        interp.variables.set('Texture', ceramic.Texture);
        interp.variables.set('TextureFilter', ceramic.TextureFilter);
        interp.variables.set('TextureTile', ceramic.TextureTile);
        interp.variables.set('TextureTilePacker', ceramic.TextureTilePacker);
        interp.variables.set('Timeline', ceramic.Timeline);
        interp.variables.set('TimelineColorKeyframe', ceramic.TimelineColorKeyframe);
        interp.variables.set('TimelineColorTrack', ceramic.TimelineColorTrack);
        interp.variables.set('TimelineDegreesTrack', ceramic.TimelineDegreesTrack);
        interp.variables.set('TimelineFloatKeyframe', ceramic.TimelineFloatKeyframe);
        interp.variables.set('TimelineFloatTrack', ceramic.TimelineFloatTrack);
        interp.variables.set('TimelineKeyframe', ceramic.TimelineKeyframe);
        interp.variables.set('TimelineTrack', ceramic.TimelineTrack);
        interp.variables.set('Timer', ceramic.Timer);
        interp.variables.set('Touch', ceramic.Touch);
        interp.variables.set('TouchInfo', ceramic.TouchInfo);
        interp.variables.set('TrackerBackend', ceramic.TrackerBackend);
        interp.variables.set('Transform', ceramic.Transform);
        interp.variables.set('TransformPool', ceramic.TransformPool);
        interp.variables.set('Triangle', ceramic.Triangle);
        interp.variables.set('Triangulate', ceramic.Triangulate);
        interp.variables.set('Tween', ceramic.Tween);
        interp.variables.set('Utils', ceramic.Utils);
        interp.variables.set('ValueEntry', ceramic.ValueEntry);
        interp.variables.set('Velocity', ceramic.Velocity);
        interp.variables.set('Visual', ceramic.Visual);
        #if plugin_arcade
        interp.variables.set('VisualArcadePhysics', ceramic.VisualArcadePhysics);
        #end
        #if plugin_nape
        interp.variables.set('VisualNapePhysics', ceramic.VisualNapePhysics);
        #end
        interp.variables.set('VisualTransition', ceramic.VisualTransition);
        interp.variables.set('WatchDirectory', ceramic.WatchDirectory);

    }

    #end

}