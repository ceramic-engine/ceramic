# Visuals

A `Visual` is an `Entity` used to display elements on screen.

`Visual` objects don't display anything on screen as is. You would use one of its subclasses to display images, texts, polygons...

## Example using a Quad

One of the most simple visuals you can display on screen is a `Quad`, a `Visual` subclass used to display colored rectangles and images.

### Display a colored rectangle

```haxe
// Display a red rectangle at the top-left corner of the screen
// (position defaults to 0,0)
var quad = new Quad();

// Setup color and size
quad.color = Color.RED;
quad.size(200, 80);
```

### Display an image

```haxe
// Display an image
var quad = new Quad();

// We use a previously created asset manager to get our image
// The quad will automatically update its size to match the image size
quad.texture = assets.texture(Images.MY_IMAGE);

// Center the image on screen
quad.pos(screen.width * 0.5, screen.height * 0.5);

// Anchor should be at the center of the quad
// to get it correctly centered on screen
quad.anchor(0.5, 0.5);
```
