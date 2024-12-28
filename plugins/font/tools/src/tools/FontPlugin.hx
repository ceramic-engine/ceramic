package tools;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import tools.Context;
import tools.Helpers.*;

using StringTools;

@:keep
class FontPlugin {

/// Tools

    public function new() {}

    public function init(context:Context):Void {

        // Add tasks
        context.addTask('font', new tools.tasks.font.Font());

        // Add assets transformers
        context.assetsTransformers.push({
            transform: transformAssets
        });

    }

    public function transformAssets(assets:Array<tools.Asset>, transformedAssetsPath:String, changedPaths:Array<String>):Array<tools.Asset> {

        var result:Array<tools.Asset> = [];

        for (asset in assets) {
            final lowerCaseName = asset.name.toLowerCase();
            if (lowerCaseName.endsWith('.ttf') || lowerCaseName.endsWith('.otf')) {
                // Transform TTF/OTF to MSDF Bitmap Font

                // Compute destination .fnt path
                var baseName = asset.name.substring(0, asset.name.length - 4);
                var fntName = baseName + '.fnt';
                var pngName = baseName + '.png';
                var dstFntPath = Path.join([transformedAssetsPath, fntName]);
                var dstPngPath = Path.join([transformedAssetsPath, pngName]);

                if (!Files.haveSameLastModified(asset.absolutePath, dstFntPath) || !Files.haveSameLastModified(asset.absolutePath, dstPngPath)) {
                    FontUtils.createBitmapFont({
                        fontPath: asset.absolutePath,
                        outputPath: transformedAssetsPath,
                        msdf: true,
                        quiet: true
                    });
                    Files.setToSameLastModified(asset.absolutePath, dstFntPath);
                    Files.setToSameLastModified(asset.absolutePath, dstPngPath);

                    changedPaths.push(dstFntPath);
                    changedPaths.push(dstPngPath);
                }

                result.push(new tools.Asset(fntName, transformedAssetsPath));
                result.push(new tools.Asset(pngName, transformedAssetsPath));
            }
            else {
                result.push(asset);
            }
        }

        return result;

    }

}
