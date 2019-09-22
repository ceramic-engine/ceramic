# Ceramic

| ![Ceramic Logo](editor/public/icons/128x128.png) | Minimal and portable cross-platform 2D game/multimedia engine. |
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

## Setup / How to use

⚠️ At the moment, **ceramic** tool is only supported on Mac OS X but it is designed from the ground up to be usable on Windows and Linux in the future, thanks to using [Node.js](https://nodejs.org) and [Haxe](http://haxe.org/) which are two fantastic cross platform tools.

### Install ceramic command

Download ceramic

* Mac: http://path.to.ceramic.zip

You can now run **ceramic** globally from terminal:

```
ceramic help
```

Or run it locally:

```
/path/to/ceramic/ceramic help
```

### Install Visual Studio Code

[Visual Studio Code](https://code.visualstudio.com/) is a cross-platform code editor that supports the [Haxe](http://haxe.org) programming language thanks to its [Haxe extension](https://marketplace.visualstudio.com/items?itemName=nadako.vshaxe).

Download and install [Visual Studio Code](https://code.visualstudio.com/) on your computer.

### Install required VS Code extensions

You need to install [Haxe](https://marketplace.visualstudio.com/items?itemName=nadako.vshaxe) and [Tasks chooser](https://marketplace.visualstudio.com/items?itemName=jeremyfa.tasks-chooser) extensions.

To do so, open Visual Studio Code, then launch VS Code Quick Open (CMD+P / CTRL+P) and type:

```
ext install vshaxe
```

Then launch VS Code Quick Open again an type:

```
ext install tasks-chooser
```

You can also install them by browsing the [Extension Marketplace](https://code.visualstudio.com/docs/editor/extension-gallery) within VS Code.

### Create a new project

Create a new project named `MyProject` by running:

```
ceramic init --path MyProject --name MyProject --vscode --backend luxe
```

A new ceramic project is now created inside a `MyProject` directory, using the `luxe` backend and providing Visual Studio Code project files.

Open the `MyProject` directory with Visual Studio Code (you can do so by dragging the folder onto your VS Code icon).

Press (CMD+Shift+B / CTRL+Shift+B) to compile and run the project. **It should work!**

Thanks to the [Tasks chooser](https://marketplace.visualstudio.com/items?itemName=jeremyfa.tasks-chooser) extension, you can choose which target to run by selecting it in the status bar.

## Available backends

At the moment, the only available backend is `luxe` (based on alpha version of [luxe engine](https://luxeengine.com/alpha/) written in `Haxe`).

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
