# Ceramic

<img alt="Ceramic Logo" align="left" src="/tools/tpl/project/empty/assets/ceramic.png" height="130" />

**Ceramic** is a cross-platform 2D framework written in Haxe that can export natively to:

- **Desktop** (windows, mac, linux)
- **Mobile** (ios, android), web (js + webgl)
- **Unity** projects

## Examples and Documentation

https://ceramic-engine.com

## Credits

Ceramic was created by **[Jérémy Faivre](https://github.com/jeremyfa)**, as well as multiple libraries used internally, but is also possible thanks to the following works:

* **[Luxe Engine (alpha)](https://luxeengine.com/alpha/) by ruby0x1** which was used as a transitional backend before `clay` backend was ready. Some snippets of Ceramic still directly come from `luxe`.

* **[HaxeFlixel's FlxColor class](https://github.com/HaxeFlixel/flixel/blob/a59545015a65a42b8f24b08262ac80de020deb37/flixel/util/FlxColor.hx) by Joe Williamson** which was ported into  to `ceramic.Color` and `ceramic.AlphaColor` classes.

* **[OpenFL](https://github.com/openfl/openfl/blob/0b84012052fc8f6ab2e211c93769c99ad331beb9/openfl/geom/Matrix.hx) by Joshua Granick** and **[PixiJS](https://github.com/pixijs/pixi.js/blob/85aaea595f77bf0511886c499fc2733d4f5ba524/src/core/math/Matrix.js) by Mathew Groves** to implement `ceramic.Transform` class.

* **[Haxe](https://haxe.org/) by Nicolas Cannasse**, maintained by the **Haxe Foundation**, which is a fantastic cross-platform toolkit and programming language making it much easier to create a portable engine.

* **[Node.js](https://nodejs.org/) and its huge amount of community supported modules**, helping a lot to create feature-complete and cross-platform command line tools.

* **[Janicek Core Haxe](https://github.com/rjanicek/janicek-core-haxe) by Richard Janicek**, for some borrowed code for `ceramic.Utils.hashCode()`.

* **[Slugify](https://github.com/simov/slugify) by Simov**, and **[Slug haxelib port](https://lib.haxe.org/p/slug)** to provide `ceramic.Slug`.

* **[HaxeFlixel's FlxEmitter class](https://github.com/HaxeFlixel/flixel/blob/02e2d18158761d0d508a06126daef2487aa7373c/flixel/effects/particles/FlxEmitter.hx)** used as a starting point to implement `ceramic.Particles` and `ceramic.ParticleEmitter`.

* **[Optimised HashMaps](https://github.com/mikvor/hashmapTest) by Mikhail Vorontsov** to implement `ceramic.IntIntMap` and related on static targets.

* **[Some crash logging snippets](https://github.com/larsiusprime/crashdumper/blob/24e28e8fd664de922bd480502efe596665d905b8/crashdumper/CrashDumper.hx) by Lars Doucet** to handle errors with `ceramic.Errors`.

* **[Cardinal Spline JS](https://github.com/gdenisov/cardinal-spline-js) by Gleb Denisov**, used to create `ceramic.CardinalSpline`.

* **[Nuclear Blaze's GameBase Camera](https://github.com/deepnight/ld48-NuclearBlaze/blob/master/src/game/gm/Camera.hx) by Sébastien Bénard**, used as a model to create `ceramic.Camera`.

* **[Bezier Easing](https://github.com/gre/bezier-easing) by Gaëtan Renaudeau**, used to create `ceramic.BezierEasing`.

* **[Some GLSL shader code](https://github.com/kiwipxl/GLSL-shaders) by Richman Steward**.

* **[Some browser mess handling](https://github.com/goldfire/howler.js/blob/143ae442386c7b42d91a007d0b1f1695528abe64/src/howler.core.js#L245-L293) from Howler.js** to help implement Ceramic audio backend for web.

* **[Heaps Aseprite](https://github.com/AustinEast/heaps-aseprite) by Austin East**, from which several snippets were ported for make Ceramic `ase` format parsing and rendering.

* **[Aseprite Blend Functions](https://github.com/aseprite/aseprite/blob/23557a190b4f5ab46c9b3ddb19146a7dcfb9dd82/src/doc/blend_funcs.cpp) by Igara Studio S.A. and David Capello**, which were ported to Haxe in order to implement ase frame blending at runtime in Ceramic.

* **[Extrude Polyline](https://github.com/mattdesl/extrude-polyline) by Matt DesLauriers**, via Haxe port used in Ceramic to draw lines.

* **[LibGDX](https://github.com/libgdx/libgdx)**, used as a reference for polygon triangulation.

* **[Haxe Format Tiled](https://github.com/Yanrishatum/haxe-format-tiled) by Pavel Alexandrov** to parse Tiled Map Editor's TMX format.

* **[Akifox Async HTTP](https://github.com/yupswing/akifox-asynchttp) by Simone Cingano**, used to implement HTTP backend on native targets.

* **[Nape Physics](https://joecreates.github.io/napephys) by Luca Deltodesco and contributors**.

* **[HSLuv](https://github.com/hsluv/hsluv)** to provide additional color manipulation helpers to `ceramic.Color` and `ceramic.AlphaColor`.

* **[Dear ImGui](https://github.com/ocornut/imgui) by Omar Cornut**, via **[Haxe bindings](https://github.com/jeremyfa/imgui-hx) initially created by Aidan Lee**.

* **[Gif Capture](https://github.com/snowkit/gif) ported by Tilman Schmidt and Sven Bergström** from [Moments](https://github.com/Chman/Moments).

* **[Linc RTMidi](https://github.com/KeyMaster-/linc_rtmidi) by Tilman Schmidt**.

* **[Rectangle Bin Packing](https://github.com/Tw1ddle/Rectangle-Bin-Packing) by Sam Twidale**, used for `ceramic.TextureAtlasPacker`.

* **[Ase format parser](https://github.com/miriti/ase) by Michael Miriti** to read `.ase`/`.aseprite` files.

* **[Fuzzaldrin](https://github.com/atom/fuzzaldrin) from Atom** to provide some auto-completion features at runtime debug UI.

* **[SoLoud](https://github.com/jarikomppa/soloud) by Jari Komppa** to implement audio on both C++/Native targets and C#/Unity audio mixing (via MiniLoud port)

* **[LDtk](https://github.com/deepnight/ldtk) by Sébastien Bénard**, a modern 2D level editor, compatible with Ceramic

## License

Ceramic is [MIT licensed](LICENSE).
