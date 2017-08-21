package npm;

import js.html.CanvasElement;

/**
	The `Canvas` interface provides properties and methods for manipulating the layout and presentation of canvas elements. The `Canvas` interface also inherits the properties and methods of the `HTMLElement` interface.

	Documentation [Canvas](https://developer.mozilla.org/en-US/docs/Web/API/Canvas) by [Mozilla Contributors](https://developer.mozilla.org/en-US/docs/Web/API/Canvas$history), licensed under [CC-BY-SA 2.5](https://creativecommons.org/licenses/by-sa/2.5/).

	@see <https://developer.mozilla.org/en-US/docs/Web/API/Canvas>
**/
@:jsRequire("canvas-prebuilt")
extern class Canvas
{
	var width : Int;
	
	var height : Int;

    function new(width:Int, height:Int, ?setting:String);
	
	/**
		Returns a drawing context on the canvas, or null if the context ID is not supported. A drawing context lets you draw on the canvas. Calling getContext with `"2d"` returns a `CanvasRenderingContext2D` object.
	**/
	function getContext( contextId : String, ?contextOptions : Dynamic ) : Dynamic;
	
	/**
		Returns a data-URL containing a representation of the image in the format specified by the `type` parameter (defaults to `png`). The returned image is in a resolution of 96dpi.
	**/
	function toDataURL( ?type : String = "", ?encoderOptions : Dynamic ) : String;
	
	/**
		Creates a `Buffer` object representing the image contained in the canvas; this file may be cached on the disk or stored in memory at the discretion of the user agent.
	**/
	function toBuffer( ?callback : js.node.Buffer -> Void, ?type : String = "", ?encoderOptions : Dynamic ) : js.node.Buffer;
    
	/** Shorthand for getting a CanvasRenderingContext2D. */
	inline function getContext2d( ?attribs : {} ) : CanvasRenderingContext2D {
		return cast getContext("2d", attribs);
	}

} //Canvas

@:jsRequire("canvas-prebuilt", "Image")
extern class Image {
	
	var src : js.node.Buffer;

    var dataMode : Dynamic;

    ///

	/**
		Is a `DOMString` that reflects the `alt` HTML attribute,  thus indicating fallback context for the image.
	**/
	var alt : String;
	
	/**
		Is a `DOMString` reflecting the `srcset` HTML attribute, containing a list of candidate images, separated by a comma (`',', U+002C COMMA`). A candidate image is a URL followed by a `'w'` with the width of the images, or an `'x'` followed by the pixel density.
	**/
	var srcset : String;
	
	/**
		Is a `DOMString` representing the CORS setting for this image element. See CORS settings attributes for further details.
	**/
	var crossOrigin : String;
	
	/**
		Is a `DOMString` that reflects the `usemap` HTML attribute, containing a partial URL of a map element.
	**/
	var useMap : String;
	
	/**
		Is a `Boolean` that reflects the `ismap` HTML attribute, indicating that the image is part of a server-side image map.
	**/
	var isMap : Bool;
	
	/**
		Is a `unsigned long` that reflects the `width` HTML attribute, indicating the rendered width of the image in CSS pixels.
	**/
	var width : Int;
	
	/**
		Is a `unsigned long` that reflects the `height` HTML attribute, indicating the rendered height of the image in CSS pixels.
	**/
	var height : Int;
	
	/**
		Returns a `unsigned long` representing the intrinsic width of the image in CSS pixels, if it is available; otherwise, it will show `0`.
	**/
	var naturalWidth(default,null) : Int;
	
	/**
		Returns a `unsigned long` representing the intrinsic height of the image in CSS pixels, if it is available; else, it shows `0`.
	**/
	var naturalHeight(default,null) : Int;
	
	/**
		Returns a `Boolean` that is `true` if the browser has finished fetching the image, whether successful or not. It also shows true, if the image has no `HTMLImageElement.src` value.
	**/
	var complete(default,null) : Bool;
	
	/**
		Is a `DOMString` representing the name of the element.
	**/
	var name : String;
	
	/**
		Is a `DOMString` indicating the alignment of the image with respect to the surrounding context.
	**/
	var align : String;
	
	/**
		Is a `long` representing the space on either side of the image.
	**/
	var hspace : Int;
	
	/**
		Is a `long` representing the space above and below the image.
	**/
	var vspace : Int;
	
	/**
		Is a `DOMString` representing the URI of a long description of the image.
	**/
	var longDesc : String;
	
	/**
		Is a `DOMString` that is responsible for the width of the border surrounding the image. This is now deprecated and the CSS `border` property should be used instead.
	**/
	var border : String;
	
	/**
		Is a `DOMString` reflecting the `sizes` HTML attribute.
	**/
	var sizes : String;
	
	/**
		Returns a `DOMString` representing the URL to the currently displayed image (which may change, for example in response to media queries).
	**/
	var currentSrc(default,null) : String;
	var lowsrc : String;
	
	/**
		Returns a `long` representing the horizontal offset from the nearest layer. This property mimics an old Netscape 4 behavior.
	**/
	var x(default,null) : Int;
	
	/**
		Returns a `long` representing the vertical offset from the nearest layer. This property is also similar to behavior of an old Netscape 4.
	**/
	var y(default,null) : Int;

} //Image

extern class CanvasRenderingContext2D {

    var patternQuality:String;

    var textDrawingMode:String;

    var filter:String;

    var antialias:String;

    ///

	var canvas(default,null) : Canvas;
	var globalAlpha : Float;
	var globalCompositeOperation : String;
	var strokeStyle : haxe.extern.EitherType<String,haxe.extern.EitherType<js.html.CanvasGradient,js.html.CanvasPattern>>;
	var fillStyle : haxe.extern.EitherType<String,haxe.extern.EitherType<js.html.CanvasGradient,js.html.CanvasPattern>>;
	var shadowOffsetX : Float;
	var shadowOffsetY : Float;
	var shadowBlur : Float;
	var shadowColor : String;
	var imageSmoothingEnabled : Bool;
	var lineWidth : Float;
	var lineCap : String;
	var lineJoin : String;
	var miterLimit : Float;
	var lineDashOffset : Float;
	var font : String;
	var textAlign : String;
	var textBaseline : String;
	
	function save() : Void;
	function restore() : Void;
	/** @throws DOMError */
	function scale( x : Float, y : Float ) : Void;
	/** @throws DOMError */
	function rotate( angle : Float ) : Void;
	/** @throws DOMError */
	function translate( x : Float, y : Float ) : Void;
	/** @throws DOMError */
	function transform( a : Float, b : Float, c : Float, d : Float, e : Float, f : Float ) : Void;
	/** @throws DOMError */
	function setTransform( a : Float, b : Float, c : Float, d : Float, e : Float, f : Float ) : Void;
	/** @throws DOMError */
	function resetTransform() : Void;
	function createLinearGradient( x0 : Float, y0 : Float, x1 : Float, y1 : Float ) : js.html.CanvasGradient;
	/** @throws DOMError */
	function createRadialGradient( x0 : Float, y0 : Float, r0 : Float, x1 : Float, y1 : Float, r1 : Float ) : js.html.CanvasGradient;
	/** @throws DOMError */
	function createPattern( image : haxe.extern.EitherType<Image,haxe.extern.EitherType<Canvas,haxe.extern.EitherType<js.html.VideoElement,js.html.ImageBitmap>>>, repetition : String ) : js.html.CanvasPattern;
	function clearRect( x : Float, y : Float, w : Float, h : Float ) : Void;
	function fillRect( x : Float, y : Float, w : Float, h : Float ) : Void;
	function strokeRect( x : Float, y : Float, w : Float, h : Float ) : Void;
	function beginPath() : Void;
	@:overload( function( ?winding : js.html.CanvasWindingRule = "nonzero" ) : Void {} )
	function fill( path : js.html.Path2D, ?winding : js.html.CanvasWindingRule = "nonzero" ) : Void;
	@:overload( function() : Void {} )
	function stroke( path : js.html.Path2D ) : Void;
	/** @throws DOMError */
	function drawFocusIfNeeded( element : js.html.Element ) : Void;
	function drawCustomFocusRing( element : js.html.Element ) : Bool;
	@:overload( function( ?winding : js.html.CanvasWindingRule = "nonzero" ) : Void {} )
	function clip( path : js.html.Path2D, ?winding : js.html.CanvasWindingRule = "nonzero" ) : Void;
	@:overload( function( x : Float, y : Float, ?winding : js.html.CanvasWindingRule = "nonzero" ) : Bool {} )
	function isPointInPath( path : js.html.Path2D, x : Float, y : Float, ?winding : js.html.CanvasWindingRule = "nonzero" ) : Bool;
	@:overload( function( x : Float, y : Float ) : Bool {} )
	function isPointInStroke( path : js.html.Path2D, x : Float, y : Float ) : Bool;
	/** @throws DOMError */
	function fillText( text : String, x : Float, y : Float, ?maxWidth : Float ) : Void;
	/** @throws DOMError */
	function strokeText( text : String, x : Float, y : Float, ?maxWidth : Float ) : Void;
	/** @throws DOMError */
	function measureText( text : String ) : js.html.TextMetrics;
	/** @throws DOMError */
	@:overload( function( image : haxe.extern.EitherType<Image,haxe.extern.EitherType<Canvas,haxe.extern.EitherType<js.html.VideoElement,js.html.ImageBitmap>>>, dx : Float, dy : Float ) : Void {} )
	@:overload( function( image : haxe.extern.EitherType<Image,haxe.extern.EitherType<Canvas,haxe.extern.EitherType<js.html.VideoElement,js.html.ImageBitmap>>>, dx : Float, dy : Float, dw : Float, dh : Float ) : Void {} )
	function drawImage( image : haxe.extern.EitherType<Image,haxe.extern.EitherType<Canvas,haxe.extern.EitherType<js.html.VideoElement,js.html.ImageBitmap>>>, sx : Float, sy : Float, sw : Float, sh : Float, dx : Float, dy : Float, dw : Float, dh : Float ) : Void;
	/** @throws DOMError */
	function addHitRegion( ?options : js.html.HitRegionOptions ) : Void;
	function removeHitRegion( id : String ) : Void;
	function clearHitRegions() : Void;
	/** @throws DOMError */
	@:overload( function( sw : Float, sh : Float ) : ImageData {} )
	function createImageData( imagedata : ImageData ) : ImageData;
	/** @throws DOMError */
	function getImageData( sx : Float, sy : Float, sw : Float, sh : Float ) : ImageData;
	/** @throws DOMError */
	@:overload( function( imagedata : ImageData, dx : Float, dy : Float ) : Void {} )
	function putImageData( imagedata : ImageData, dx : Float, dy : Float, dirtyX : Float, dirtyY : Float, dirtyWidth : Float, dirtyHeight : Float ) : Void;
	/** @throws DOMError */
	function setLineDash( segments : Array<Float> ) : Void;
	function getLineDash() : Array<Float>;
	function closePath() : Void;
	function moveTo( x : Float, y : Float ) : Void;
	function lineTo( x : Float, y : Float ) : Void;
	function quadraticCurveTo( cpx : Float, cpy : Float, x : Float, y : Float ) : Void;
	function bezierCurveTo( cp1x : Float, cp1y : Float, cp2x : Float, cp2y : Float, x : Float, y : Float ) : Void;
	/** @throws DOMError */
	function arcTo( x1 : Float, y1 : Float, x2 : Float, y2 : Float, radius : Float ) : Void;
	function rect( x : Float, y : Float, w : Float, h : Float ) : Void;
	/** @throws DOMError */
	function arc( x : Float, y : Float, radius : Float, startAngle : Float, endAngle : Float, ?anticlockwise : Bool = false ) : Void;
	/** @throws DOMError */
	function ellipse( x : Float, y : Float, radiusX : Float, radiusY : Float, rotation : Float, startAngle : Float, endAngle : Float, ?anticlockwise : Bool = false ) : Void;

} //CanvasRenderingContext2D

@:jsRequire("canvas-prebuilt", "ImageData")
extern class ImageData
{
	/**
		Is an `unsigned` `long` representing the actual width, in pixels, of the `ImageData`.
	**/
	var width(default,null) : Int;
	
	/**
		Is an `unsigned` `long` representing the actual height, in pixels, of the `ImageData`.
	**/
	var height(default,null) : Int;
	
	/**
		Is a `Uint8ClampedArray` representing a one-dimensional array containing the data in the RGBA order, with integer values between `0` and `255` (included).
	**/
	var data(default,null) : js.html.Uint8ClampedArray;
	
	/** @throws DOMError */
	@:overload( function( sw : Int, sh : Int ) : Void {} )
	function new( data : js.html.Uint8ClampedArray, sw : Int, ?sh : Int ) : Void;
}
