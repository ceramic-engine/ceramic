package unityengine;

import cs.types.UInt8;

/**
 * Represents a text file asset in Unity.
 * Can store any text-based data including JSON, XML, CSV, or plain text.
 * 
 * In Ceramic's Unity backend, TextAssets are used to load:
 * - Configuration files
 * - Shader source code
 * - JSON data files
 * - Any text-based resources
 * 
 * TextAssets are loaded from the Resources folder or AssetBundles
 * and provide both string and binary access to the data.
 * 
 * Supported extensions:
 * - .txt, .json, .xml, .csv
 * - .shader, .cginc (shader files)
 * - .html, .htm
 * - Any file Unity imports as text
 * 
 * @see Resources
 */
@:native('UnityEngine.TextAsset')
extern class TextAsset extends Object {

    /**
     * The text contents of the file as a string.
     * 
     * Automatically handles text encoding (usually UTF-8).
     * Line endings are preserved as in the original file.
     * 
     * Loading JSON data:
     * ```haxe
     * var jsonAsset = Resources.Load<TextAsset>("config/settings");
     * var data = Json.parse(jsonAsset.text);
     * ```
     * 
     * Note: For large files, accessing text may allocate
     * significant memory for the string conversion.
     */
    var text(default, null):String;

    /**
     * Raw bytes of the file content.
     * 
     * Provides direct access to file data without string conversion.
     * Useful for:
     * - Binary data stored as TextAsset
     * - Custom parsing or encoding
     * - Avoiding string allocation for large files
     * 
     * Reading binary data:
     * ```haxe
     * var asset = Resources.Load<TextAsset>("data/binary");
     * var bytes = asset.bytes;
     * // Process bytes directly
     * ```
     * 
     * The byte array is read-only and references Unity's internal data.
     */
    var bytes(default, null):cs.NativeArray<UInt8>;

}
