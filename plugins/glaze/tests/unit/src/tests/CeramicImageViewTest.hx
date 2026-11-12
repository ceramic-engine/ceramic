package tests;

import ceramic.ImageView;
import ceramic.RenderTexture;
import ceramic.ViewLayoutMask;
import testing.TestCase;

/**
 * Sizes computed by Ceramic's `ImageView` (plugin `ui`, not Glaze code):
 * the natural size of its texture when nothing gives a size, the ratio of
 * the texture when one axis is given.
 */
class CeramicImageViewTest extends TestCase {

    final created:Array<ceramic.Entity> = [];

    override function teardown() {
        for (entity in created) {
            if (!entity.destroyed) entity.destroy();
        }
        created.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function imageView(width:Float, height:Float, density:Float = 1):ImageView {
        final texture = new RenderTexture(width, height, density);
        created.push(texture);
        final image = new ImageView();
        image.setImageTexture(texture);
        created.push(image);
        return image;
    }

    function assertComputed(image:ImageView, width:Float, height:Float, ?pos:haxe.PosInfos) {
        assertEquals(width, image.computedSize.computedWidth, null, pos);
        assertEquals(height, image.computedSize.computedHeight, null, pos);
    }

    function imageScale(image:ImageView):Float {
        return @:privateAccess image.computedImageScale;
    }

    function testAutoSizeTakesTheTextureSize() {
        final image = imageView(40, 20);
        image.autoComputeSize();
        assertComputed(image, 40, 20);
        assertEquals(1.0, imageScale(image));
    }

    function testAutoSizeAppliedGivesTheTextureSize() {
        final image = imageView(40, 20);
        image.autoComputeSize(true);
        assertEquals(40.0, image.width);
        assertEquals(20.0, image.height);
    }

    function testAutoSizeRespectsTheTextureDensity() {
        final image = imageView(40, 20, 2);
        assertEquals(40.0, @:privateAccess image.imageQuad.texture.width);
        image.autoComputeSize();
        assertComputed(image, 40, 20);
    }

    function testAutoSizeAddsThePadding() {
        final image = imageView(40, 20);
        image.padding(1, 2, 3, 4);
        image.autoComputeSize();
        assertComputed(image, 46, 24);
    }

    function testFixedWidthGivesTheRatioHeight() {
        final image = imageView(40, 20);
        image.viewWidth = 200;
        image.autoComputeSize();
        assertComputed(image, 200, 100);
        assertEquals(5.0, imageScale(image));
    }

    function testFixedHeightGivesTheRatioWidth() {
        final image = imageView(40, 20);
        image.viewHeight = 50;
        image.autoComputeSize();
        assertComputed(image, 100, 50);
    }

    function testBothExplicitAreKept() {
        final image = imageView(40, 20);
        image.viewSize(100, 100);
        image.autoComputeSize();
        assertComputed(image, 100, 100);
        assertEquals(2.5, imageScale(image));
    }

    function testWidthImposedByTheParentGivesTheRatioHeight() {
        final image = imageView(40, 20);
        image.computeSize(100, 0, ViewLayoutMask.FLEXIBLE_HEIGHT, false);
        assertComputed(image, 100, 50);
    }

    function testHeightImposedByTheParentGivesTheRatioWidth() {
        final image = imageView(40, 20);
        image.computeSize(0, 30, ViewLayoutMask.FLEXIBLE_WIDTH, false);
        assertComputed(image, 60, 30);
    }

    function testMaximumWidthReducesTheNaturalSize() {
        final image = imageView(40, 20);
        // The width can shrink but not grow beyond 20
        image.computeSize(20, 0, ViewLayoutMask.FLEXIBLE_HEIGHT | ViewLayoutMask.DECREASE_WIDTH, false);
        assertComputed(image, 20, 10);
    }

    function testMaximumLargerThanTheTextureKeepsTheNaturalSize() {
        final image = imageView(40, 20);
        image.computeSize(300, 200, ViewLayoutMask.DECREASE, false);
        assertComputed(image, 40, 20);
    }

    function testMinimumWidthGivesTheRatioHeight() {
        final image = imageView(40, 20);
        // Existing behaviour: a minimum width from the parent is followed
        image.computeSize(100, 0, ViewLayoutMask.INCREASE | ViewLayoutMask.DECREASE_HEIGHT, false);
        assertComputed(image, 100, 50);
    }

    function testFixedMaskWithAnEmptyParentStaysEmpty() {
        final image = imageView(40, 20);
        image.computeSize(0, 0, ViewLayoutMask.FIXED, false);
        assertComputed(image, 0, 0);
    }

    function testNoTextureHasNoSize() {
        final image = new ImageView();
        created.push(image);
        image.autoComputeSize();
        assertComputed(image, 0, 0);
    }

    function testAutoSizeInALinearLayout() {
        final layout = new ceramic.LinearLayout();
        created.push(layout);
        layout.direction = VERTICAL;
        final image = imageView(40, 20);
        layout.add(image);
        ceramic.App.app.screen.add(layout);
        layout.autoComputeSize(true);
        ceramic.View.requestLayout();
        ceramic.App.app.flushImmediate();
        assertEquals(40.0, image.width);
        assertEquals(20.0, image.height);
        assertEquals(40.0, layout.width);
        assertEquals(20.0, layout.height);
    }

}
