// Ported from gpui-pre 0.3.10: src/style.rs (ObjectFit)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import plutovg.Utils.f32;

/**
 * How to fit the image into the bounds of the element.
 */
enum abstract ObjectFit(Int) {

    /** The image will be stretched to fill the bounds of the element. */
    var Fill = 0;

    /** The image will be scaled to fit within the bounds of the element. */
    var Contain = 1;

    /** The image will be scaled to cover the bounds of the element. */
    var Cover = 2;

    /** The image will be scaled down to fit within the bounds of the element. */
    var ScaleDown = 3;

    /** The image will maintain its original size. */
    var None = 4;

    /**
     * Get the bounds of the image within the given bounds. `imageSize` is in
     * device pixels and used as is (like GPUI, it is not divided by the scale
     * factor). Computed in f32 like the Rust code.
     */
    public function getBounds(bounds:Bounds, imageSize:Size):Bounds {
        final imageWidth = f32(imageSize.width);
        final imageHeight = f32(imageSize.height);
        final boundsWidth = f32(bounds.size.width);
        final boundsHeight = f32(bounds.size.height);
        final imageRatio = f32(imageWidth / imageHeight);
        final boundsRatio = f32(boundsWidth / boundsHeight);

        inline function centered(width:Float, height:Float):Bounds {
            return new Bounds(
                new Point(
                    f32(bounds.origin.x + f32(f32(boundsWidth - width) / 2.0)),
                    f32(bounds.origin.y + f32(f32(boundsHeight - height) / 2.0))
                ),
                new Size(width, height)
            );
        }

        inline function containSize():Bounds {
            return if (boundsRatio > imageRatio) {
                centered(f32(imageWidth * f32(boundsHeight / imageHeight)), boundsHeight);
            }
            else {
                centered(boundsWidth, f32(imageHeight * f32(boundsWidth / imageWidth)));
            }
        }

        return switch (cast this : ObjectFit) {
            case Fill:
                bounds;
            case Contain:
                containSize();
            case ScaleDown:
                // Check if the image is larger than the bounds in either dimension.
                if (imageWidth > boundsWidth || imageHeight > boundsHeight) {
                    // If the image is larger, use the same logic as Contain to scale it down.
                    containSize();
                }
                else {
                    // If the image is smaller than or equal to the container, display it at its
                    // original size, centered within the container.
                    centered(imageWidth, imageHeight);
                }
            case Cover:
                if (boundsRatio > imageRatio) {
                    centered(boundsWidth, f32(imageHeight * f32(boundsWidth / imageWidth)));
                }
                else {
                    centered(f32(imageWidth * f32(boundsHeight / imageHeight)), boundsHeight);
                }
            case None:
                new Bounds(bounds.origin, new Size(imageWidth, imageHeight));
        }
    }

    public function toString():String {
        return switch (cast this : ObjectFit) {
            case Fill: 'Fill';
            case Contain: 'Contain';
            case Cover: 'Cover';
            case ScaleDown: 'ScaleDown';
            case None: 'None';
        }
    }

}
