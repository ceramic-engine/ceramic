// Ported from vscode src/vs/base/common/event.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

import cityscape.base.common.Lifecycle.IDisposable;

/**
 * An event: a function to which a listener is subscribed. The returned
 * `IDisposable` removes the listener.
 *
 * Monaco's `Event<T>` also takes `thisArgs` and a disposable store; Haxe
 * closures make `thisArgs` unnecessary, and the store is added by the caller.
 * `Event<void>` is `VoidEvent` (a Haxe listener of type `() -> Void`).
 */
typedef Event<T> = (listener:(e:T) -> Void) -> IDisposable;

/**
 * Monaco's `Event<void>`: an event whose listeners take no argument.
 */
typedef VoidEvent = (listener:() -> Void) -> IDisposable;
