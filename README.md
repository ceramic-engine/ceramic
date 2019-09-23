# Ceramic

| ![Ceramic Logo](/tools/resources/AppIcon-128.png) | Minimal and portable cross-platform 2D game/multimedia engine. |
| - | - |

## ⚠️ ACTIVE DEVELOPMENT / DON'T USE IT YET! ⚠️

**You've been warned**, everything in this repository is subject to change and **it is strongly advised not to use `ceramic` yet** on your own projects.

`ceramic` should be considered usable when its [Alpha Milestone](https://github.com/ceramic-engine/ceramic/milestone/1) gets completed. Until then, **no issue will be accepted**, and anyway **you should not use it at all for now** 🙂.

## Why ceramic?

Ceramic is made with very simple goals in mind:

* Provide a high level cross-platform API to make 2D games, animations and creative coding.
* Have a clear separation of ceramic API and its backend API.
* Ensure adding new backends is as easy as possible by keeping the API clean and minimal.
* Leverage as much as possible existing frameworks instead of reinventing the wheel.
* Target iOS, Android, HTML5 (WebGL), PC (Win/OSX/Linux).

## How does it work?

Ceramic is built using [Haxe](http://haxe.org), a high level strictly typed programming language that can compile to multiple platforms.

Depending on the platform, it tries to use the best tools available using multiple backends.

The **ceramic** command line tools are also written in Haxe language but run with Node.js.

## Getting started

**Visit the [Ceramic Wiki](https://github.com/ceramic-engine/ceramic/wiki) to get started.**

## Available backends

At the moment, the only available backend is `luxe` (a stripped-down version of [luxe engine alpha](https://luxeengine.com/alpha/) written in `Haxe`, specifically edited for ceramic).

It allows to target Mac, Windows, Linux, iOS, Android, HTML5 (WebGL).

More backends may be implemented in the future.

## Credits

Ceramic was created by **[Jérémy Faivre](https://github.com/jeremyfa)** but is also possible thanks to the following works:

* **[Luxe Engine (alpha)](https://luxeengine.com/alpha/) by Sven Bergström** which is the low-level-ish tech used by ceramic's default backend to display graphics, play sounds, manage input through [OpenGL](https://www.opengl.org/), [OpenAL](https://www.openal.org/) and [SDL](https://www.libsdl.org/). `Luxe` is also a great source of inspiration that influenced how ceramic works in various aspects. Some snippets of `ceramic` directly come from `luxe`.

* **[HaxeFlixel's FlxColor class](https://github.com/HaxeFlixel/flixel/blob/a59545015a65a42b8f24b08262ac80de020deb37/flixel/util/FlxColor.hx) by Joe Williamson** which was ported into `ceramic.Color` class.

* **[OpenFL](https://github.com/openfl/openfl/blob/0b84012052fc8f6ab2e211c93769c99ad331beb9/openfl/geom/Matrix.hx) by Joshua Granick** and **[PixiJS](https://github.com/pixijs/pixi.js/blob/85aaea595f77bf0511886c499fc2733d4f5ba524/src/core/math/Matrix.js) by Mathew Groves** to implement `ceramic.Transform` class.

* **[Haxe](https://haxe.org/) by Nicolas Cannasse**, maintained by the **Haxe Foundation**, which is a fantastic cross-platform toolkit and programming language making it much easier to create a portable engine.

* **[Node.js](https://nodejs.org/) and its huge amount of community supported modules**, helping a lot to create feature-complete and cross-platform command line tools.

## License

Ceramic is [MIT licensed](LICENSE).
