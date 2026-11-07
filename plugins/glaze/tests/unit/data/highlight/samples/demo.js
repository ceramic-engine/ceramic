// JavaScript sample
'use strict';
const re = /^(?:a|b)+\d*$/gi;
/**
 * Adds numbers.
 * @param {number} a
 */
export default async function add(a, b = 2) {
  const s = `sum: ${a + b}`;
  await new Promise((resolve) => setTimeout(resolve, 10));
  return { s, ok: re.test(s), nothing: null, undef: undefined, n: 0x1f };
}
class Thing extends Object { static #priv = 1; get value() { return this.#priv; } }
