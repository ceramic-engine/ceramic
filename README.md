# Ceramic

| ![Ceramic Logo](/tools/resources/AppIcon-128.png) | Cross-platform 2D framework. |
| - | - |

![demo-video](https://user-images.githubusercontent.com/164094/134378094-401c519d-bdd0-4d89-b9a2-c7f9d5893c02.gif)

## ℹ️ More updates about ceramic soon

Ceramic is _almost_ ready to be used by more developers.

At the moment, it lacks a lot of documentation, but you can already read a few articles:
- Start with the introduction: [Discover ceramic, a cross-platform and open-source 2D framework](https://jeremyfa.com/what-is-ceramic-engine/)
- Then, continue with the [Getting Started with ceramic](https://jeremyfa.com/getting-started-with-ceramic/) guide to create your first project.
- Find some more info on the [Wiki Page](https://github.com/ceramic-engine/ceramic/wiki).
- Check the [Ceramic API docs](https://ceramic-engine.com/api/) (still rough, will be improved).
- Take a look at the [Samples repository](https://github.com/ceramic-engine/ceramic-samples/) to see small example projects that demonstrate ceramic features (new samples will be added on a regular basis).
- Join the **#ceramic** channel on the [Haxe Discord](https://discordapp.com/invite/0uEuWH3spjck73Lo) server.

## Why ceramic?

Ceramic is made with a few goals in mind:

* Provide a runtime with high level cross-platform [Haxe](http://haxe.org) API to make apps, 2d games, animations and creative coding projects.
* Bundle a set of command line tools that handle building for different targets. Currently supported: iOS, Android, HTML5 (WebGL), PC (Win/OSX/Linux), Headless (Node.js).
* Make it extensible with a plugin system. A plugin can extend both the runtime and the command line tools.
* Ensure adding new backends is as easy as possible by keeping the API clean and platform independant. New backends/targets can be added via separate plugins without changing the framework itself.
* Provide opinionated features out of the box (event system, observables, physics, data model...), but always try to make these optional.

## How does it work?

Ceramic is built using [Haxe](http://haxe.org), a high level strictly typed programming language that can compile to multiple platforms.

It consists on a high level cross-platform API for Haxe, the **runtime**, and makes it work on different platforms with **backends**.

Ceramic comes with command line tools, also written in Haxe language, then run with Node.js.

## Getting started

**Take a look at the [Wiki](https://github.com/ceramic-engine/ceramic/wiki).**

## Available backends

- Current default backend is `clay`. It allows to natively target Mac, Windows, Linux, iOS, Android and HTML5 (WebGL).

- A `headless` backend allows to run ceramic as a server/cli app (via Node.js for now, even if that could work with other language targets too).

- A `unity` backend allows to run a ceramic app _inside_ Unity Editor and take advantage of all the platforms Unity provides.

## Credits

Ceramic was created by **[Jérémy Faivre](https://github.com/jeremyfa)** but is also possible thanks to the following works:

* **[Luxe Engine (alpha)](https://luxeengine.com/alpha/) by Sven Bergström** which was used as a transitional backend before `clay` backend was ready. `Luxe` is also a great source of inspiration that influenced how ceramic works in various aspects. Some snippets of `ceramic` directly come from `luxe`.

* **[HaxeFlixel's FlxColor class](https://github.com/HaxeFlixel/flixel/blob/a59545015a65a42b8f24b08262ac80de020deb37/flixel/util/FlxColor.hx) by Joe Williamson** which was ported into `ceramic.Color` class.

* **[OpenFL](https://github.com/openfl/openfl/blob/0b84012052fc8f6ab2e211c93769c99ad331beb9/openfl/geom/Matrix.hx) by Joshua Granick** and **[PixiJS](https://github.com/pixijs/pixi.js/blob/85aaea595f77bf0511886c499fc2733d4f5ba524/src/core/math/Matrix.js) by Mathew Groves** to implement `ceramic.Transform` class.

* **[Haxe](https://haxe.org/) by Nicolas Cannasse**, maintained by the **Haxe Foundation**, which is a fantastic cross-platform toolkit and programming language making it much easier to create a portable engine.

* **[Node.js](https://nodejs.org/) and its huge amount of community supported modules**, helping a lot to create feature-complete and cross-platform command line tools.

## License

Ceramic is [MIT licensed](LICENSE).
