package ceramic;

/** RGBA Color stored as integer.
    Can be decomposed to Color/Int (RGB) + Float (A) and
    constructed from Color/Int (RGB) + Float (A). */
abstract AlphaColor(Int) from Int from UInt to Int to UInt {

	public var red(get, set):Int;
	public var blue(get, set):Int;
	public var green(get, set):Int;
	public var alpha(get, set):Int;
	
	public var redFloat(get, set):Float;
	public var blueFloat(get, set):Float;
	public var greenFloat(get, set):Float;
	public var alphaFloat(get, set):Float;

    public var color(get, set):Color;

    public inline function new(color:Color, alpha:Int = 255) {
        var value:AlphaColor = Std.int(color) + 0xFF000000;
        value.alpha = alpha;
        this = value;
    }

    inline function get_color():Color {
        return Color.fromRGB(red, green, blue);
    }
    inline function set_color(color:Color):Color {
        red = color.red;
        green = color.green;
        blue = color.blue;
        return color;
    }
	
	private inline function get_red():Int
	{
		return (this >> 16) & 0xff;
	}
	
	private inline function get_green():Int
	{
		return (this >> 8) & 0xff;
	}
	
	private inline function get_blue():Int
	{
		return this & 0xff;
	}
	
	private inline function get_alpha():Int
	{
		return (this >> 24) & 0xff;
	}
	
	private inline function get_redFloat():Float
	{
		return red / 255;
	}
	
	private inline function get_greenFloat():Float
	{
		return green / 255;
	}
	
	private inline function get_blueFloat():Float
	{
		return blue / 255;
	}
	
	private inline function get_alphaFloat():Float
	{
		return alpha / 255;
	}
	
	private inline function set_red(Value:Int):Int
	{
		this &= 0xff00ffff;
		this |= boundChannel(Value) << 16;
		return Value;
	}
	
	private inline function set_green(Value:Int):Int
	{
		this &= 0xffff00ff;
		this |= boundChannel(Value) << 8;
		return Value;
	}
	
	private inline function set_blue(Value:Int):Int
	{
		this &= 0xffffff00;
		this |= boundChannel(Value);
		return Value;
	}
	
	private inline function set_alpha(Value:Int):Int
	{
		this &= 0x00ffffff;
		this |= boundChannel(Value) << 24;
		return Value;
	}
	
	private inline function set_redFloat(Value:Float):Float
	{
		red = Math.round(Value * 255);
		return Value;
	}
	
	private inline function set_greenFloat(Value:Float):Float
	{
		green = Math.round(Value * 255);
		return Value;
	}
	
	private inline function set_blueFloat(Value:Float):Float
	{
		blue = Math.round(Value * 255);
		return Value;
	}
	
	private inline function set_alphaFloat(Value:Float):Float
	{
		alpha = Math.round(Value * 255);
		return Value;
	}

    private inline function boundChannel(value:Int):Int
    {
        return value > 0xff ? 0xff : value < 0 ? 0 : value;
    }

} //AlphaColor
