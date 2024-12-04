package ceramic;

import ceramic.Text;
import ceramic.Component;
import ceramic.Entity;

class PasswordText extends Entity implements Component {
	@entity public var visual:Text;

	public var content:String = '';

	var stars:String = '';
	var length:Int = 0;

	function bindAsComponent():Void {
		length = visual.content.length;
		if (length > 0) {
			for (i in 0...length) {
				stars += '*';
			}
			content = visual.content;
			visual.content = stars;
		}
		visual.onGlyphQuadsChange(this, applyChange);
	}

	function applyChange() {
		if (visual.content.length > length) {
			this.content += visual.content.charAt(visual.content.length - 1);
			stars += '*';
		} else if (visual.content.length < length) {
			this.content = content.substr(0, -1);
			this.stars = stars.substr(0, -1);
		}

		visual.content = stars;
		length = visual.content.length;
	}
}
