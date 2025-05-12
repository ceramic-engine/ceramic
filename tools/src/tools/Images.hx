package tools;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesData;
import haxe.io.Path;
import haxe.io.UInt8Array;
import stb.Image as StbImage;
import stb.ImageResize as StbImageResize;
import stb.ImageResize.StbImageResizeData;
import stb.ImageResize.StbImageResizePixelLayout;
import stb.ImageWrite as StbImageWrite;
import sys.FileSystem;

typedef RawImageData = {

    var pixels:UInt8Array;

    var width:Int;

    var height:Int;

    var channels:Int;

}

typedef TargetImage = {

    var path:String;

    var width:Int;

    var height:Int;

    @:optional var flat:Bool;

    @:optional var padLeft:Int;

    @:optional var padRight:Int;

    @:optional var padTop:Int;

    @:optional var padBottom:Int;

}

class Images {

    public static function getRaw(srcPath:String):RawImageData {

        var pixels:UInt8Array = null;
        var width:Int;
        var height:Int;
        var channels:Int;

        var info = StbImage.load(srcPath);

        width = info.w;
        height = info.h;
        channels = info.comp;
        pixels = UInt8Array.fromBytes(Bytes.ofData(info.bytes));

        return {
            pixels: pixels,
            width: width,
            height: height,
            channels: channels
        };

    }

    public static function saveRaw(dstPath:String, data:RawImageData):Void {

        var bytes = data.pixels.getData().bytes;

        if (!FileSystem.exists(Path.directory(dstPath))) {
            FileSystem.createDirectory(Path.directory(dstPath));
        }

        StbImageWrite.write_png(
            dstPath, data.width, data.height, data.channels,
            bytes.getData(), 0, bytes.length, data.width * data.channels
        );

    }

    public static function premultiplyAlpha(pixels:UInt8Array):Void {

        var count = pixels.length;
        var index = 0;

        while (index < count) {

            var r = pixels[index+0];
            var g = pixels[index+1];
            var b = pixels[index+2];
            var a = pixels[index+3] / 255.0;

            pixels[index+0] = Std.int(r*a);
            pixels[index+1] = Std.int(g*a);
            pixels[index+2] = Std.int(b*a);

            index += 4;

        }

    }

    public static function blackAndWhiteToWhiteAlpha(data:RawImageData):RawImageData {

        var pixels = data.pixels;
        var channels = data.channels;
        var count = pixels.length;

        var inIndex = 0;
        var outIndex = 0;

        var result = new UInt8Array(data.width * data.height * 4);

        while (inIndex < count) {

            var a = pixels[inIndex+0];

            result[outIndex+0] = 255;
            result[outIndex+1] = 255;
            result[outIndex+2] = 255;
            result[outIndex+3] = a;

            inIndex += channels;
            outIndex += 4;

        }

        return {
            pixels: result,
            channels: 4,
            width: data.width,
            height: data.height
        };

    }

    public static function resizeRaw(data:RawImageData, targetWidth:Float, targetHeight:Float, padTop:Float = 0, padRight:Float = 0, padBottom:Float = 0, padLeft:Float = 0):RawImageData {

        // If downscaling to lower than 50% of original size, do it
        // in multiple passes to prevent aliasing
        while (targetWidth < data.width * 0.5 || targetHeight < data.height * 0.5) {
            data = resizeRaw(data, Math.ceil(data.width * 0.5), Math.ceil(data.height * 0.5));
        }

        var bytes = data.pixels.getData().bytes;
        var outputW = Math.round(targetWidth);
        var outputH = Math.round(targetHeight);

        var dstData:StbImageResizeData = StbImageResize.resize_uint8_linear(
            bytes.getData(), 0, bytes.length,
            data.width, data.height, 0,
            outputW, outputH, 0,
            StbImageResizePixelLayout.STBIR_RGBA, data.channels
        );

        var pixels = UInt8Array.fromBytes(Bytes.ofData(dstData.bytes));

        if (padTop > 0 || padRight > 0 || padBottom > 0 || padLeft > 0) {
            pixels = padPixels(pixels, outputW, outputH, data.channels, padTop, padRight, padBottom, padLeft);
        }

        return {
            pixels: pixels,
            channels: data.channels,
            width: outputW + Math.round(padLeft + padRight),
            height: outputH + Math.round(padTop + padBottom)
        };

    }

    public static function resizeFile(srcPath:String, dstPath:String, targetWidth:Float, targetHeight:Float, padTop:Float = 0, padRight:Float = 0, padBottom:Float = 0, padLeft:Float = 0):Void {

        final origRaw = getRaw(srcPath);

        final resizedRaw = resizeRaw(
            origRaw,
            targetWidth, targetHeight,
            padTop, padRight, padBottom, padLeft
        );

        saveRaw(
            dstPath,
            resizedRaw
        );

    }

    public static function padPixels(pixels:UInt8Array, width:Int, height:Int, channels:Int, padTop:Float, padRight:Float, padBottom:Float, padLeft:Float):UInt8Array {

        // Calculate new dimensions with padding
        var newWidth = Math.round(width + padLeft + padRight);
        var newHeight = Math.round(height + padTop + padBottom);

        // Create new array for padded image
        var paddedPixels = new UInt8Array(newWidth * newHeight * channels);

        // Convert padding to integers
        var topPad = Math.round(padTop);
        var leftPad = Math.round(padLeft);

        // Copy row by row to ensure proper alignment
        for (y in 0...height) {
            // Calculate the starting positions for this row in both arrays
            var srcRowStart = y * width * channels;
            var dstRowStart = ((y + topPad) * newWidth + leftPad) * channels;

            // Copy the entire row at once using a more direct approach
            for (x in 0...width) {
                for (c in 0...channels) {
                    paddedPixels[dstRowStart + (x * channels) + c] = pixels[srcRowStart + (x * channels) + c];
                }
            }
        }

        return paddedPixels;
    }

    public static function createIco(srcPath:String, dstPath:String, targetWidth:Float = 256, targetHeight:Float = 256):Void {

        if (!sys.FileSystem.exists(srcPath)) {
            throw 'Source file not found: $srcPath';
        }

        var output = new haxe.io.BytesOutput();
        output.bigEndian = false;

        var sizes = [16, 24, 32, 48, 64, 128, 256];
        var validSizes = sizes.filter(size -> size <= targetWidth && size <= targetHeight);

        var srcData = getRaw(srcPath);

        // Write ICO header
        output.writeInt16(0);
        output.writeInt16(1);
        output.writeInt16(validSizes.length);

        // Calculate initial directory offset
        var currentOffset = 6 + (validSizes.length * 16);
        var directory = new haxe.io.BytesOutput();
        var imageData = new haxe.io.BytesOutput();

        for (size in validSizes) {

            var resized = resizeRaw(srcData, size, size);

            var resizedBytes = resized.pixels.getData().bytes;

            var pngByteData = StbImageWrite.write_png_to_mem(
                resized.width, resized.height, resized.channels,
                resizedBytes.getData(), 0, resizedBytes.length,
                resized.width * resized.channels
            );

            var pngData = Bytes.ofData(pngByteData);

            // Write directory entry
            directory.writeByte(size >= 256 ? 0 : size);
            directory.writeByte(size >= 256 ? 0 : size);
            directory.writeByte(0);
            directory.writeByte(0);
            directory.writeInt16(1);
            directory.writeInt16(32);
            directory.writeInt32(pngData.length);
            directory.writeInt32(currentOffset);

            // Update offset and write PNG data
            currentOffset += pngData.length;
            imageData.writeBytes(pngData, 0, pngData.length);
        }

        var directoryBytes = directory.getBytes();
        var imageDataBytes = imageData.getBytes();

        // Combine all parts
        output.writeBytes(directoryBytes, 0, directoryBytes.length);
        output.writeBytes(imageDataBytes, 0, imageDataBytes.length);

        var finalBytes = output.getBytes();

        // Save the final ICO file
        sys.io.File.saveBytes(dstPath, finalBytes);

    }

}
