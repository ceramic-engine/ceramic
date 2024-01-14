package ceramic;

import ceramic.Shape;

/**
 * An extension of Shape that creates a nicely rounded rectangle
 */
class RoundedQuad extends Shape {
	/**
	 * Amount of corner segments
	 * One to ten is going to be the sanest quantity
	 */
	public var segments:Int = 10;
	/**
	 * Defines the radius of each corner
	 */
	public var radius:CornerRadius = {tl: 0, tr: 0, br: 0, bl: 0};

	override public function new() {
		super();
		autoComputeSize = false;
	}

	override function computeContent() {
		points = [];

		// Define the relative coordinates for the radius
		var sine = [for (angle in 0...segments + 1) Math.sin(Math.PI / 2 * angle / segments)];
		var cosine = [for (angle in 0...segments + 1) Math.cos(Math.PI / 2 * angle / segments)];

		// TOP LEFT
		for (pointPairIndex in 0...segments) {
			points.push(radius.tl * (1 - cosine[pointPairIndex]));
			points.push(radius.tl * (1 - sine[pointPairIndex]));
		}

		// TOP RIGHT
		for (pointPairIndex in 0...segments) {
			points.push(width + radius.tr * (cosine[segments - pointPairIndex] - 1));
			points.push(radius.tr * (1 - sine[segments - pointPairIndex]));
		}

		// BOTTOM RIGHT
		for (pointPairIndex in 0...segments) {
			points.push(width + radius.br * (cosine[pointPairIndex] - 1));
			points.push(height + radius.br * (sine[pointPairIndex] - 1));
		}

		// BOTTOM LEFT
		for (pointPairIndex in 0...segments) {
			points.push(radius.bl * (1 - cosine[segments - pointPairIndex]));
			points.push(height + radius.bl * (sine[segments - pointPairIndex] - 1));
		}
		
		super.computeContent();

	}
}

typedef CornerRadius = {
	tl: Int,
	tr: Int,
	br: Int,
	bl: Int,
};
