/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

import { DebugFlags } from '../debug';
import { EncodedTokenAttributes, OptionalStandardTokenType, StandardTokenType, toOptionalTokenType } from '../encodedTokenAttributes';
import { IEmbeddedLanguagesMap, IGrammar, IToken, ITokenizeLineResult, ITokenizeLineResult2, ITokenTypeMap, StateStack } from '../main';
import { createMatchers, Matcher } from '../matcher';
import { disposeOnigString, IOnigLib, OnigScanner, OnigString } from '../onigLib';
import { IRawGrammar, IRawRepository, IRawRule } from '../rawGrammar';
import { ruleIdFromNumber, IRuleFactoryHelper, IRuleRegistry, Rule, RuleFactory, RuleId, ruleIdToNumber } from '../rule';
import { FontStyle, ScopeName, ScopePath, ScopeStack, StyleAttributes } from '../theme';
import { clone } from '../utils';
import { BasicScopeAttributes, BasicScopeAttributesProvider } from './basicScopesAttributeProvider';
import { _tokenizeString } from './tokenizeString';

export function createGrammar(
	scopeName: ScopeName,
	grammar: IRawGrammar,
	initialLanguage: number,
	embeddedLanguages: IEmbeddedLanguagesMap | null,
	tokenTypes: ITokenTypeMap | null,
	balancedBracketSelectors: BalancedBracketSelectors | null,
	grammarRepository: IGrammarRepository & IThemeProvider,
	onigLib: IOnigLib
): Grammar {
	return new Grammar(
		scopeName,
		grammar,
		initialLanguage,
		embeddedLanguages,
		tokenTypes,
		balancedBracketSelectors,
		grammarRepository,
		onigLib
	); //TODO
}

export interface IThemeProvider {
	themeMatch(scopePath: ScopeStack): StyleAttributes | null;
	getDefaults(): StyleAttributes;
}

export interface IGrammarRepository {
	lookup(scopeName: ScopeName): IRawGrammar | undefined;
	injections(scopeName: ScopeName): ScopeName[];
}

export interface Injection {
	readonly debugSelector: string;
	readonly matcher: Matcher<string[]>;
	readonly priority: -1 | 0 | 1; // 0 is the default. -1 for 'L' and 1 for 'R'
	readonly ruleId: RuleId;
	readonly grammar: IRawGrammar;
}

function collectInjections(result: Injection[], selector: string, rule: IRawRule, ruleFactoryHelper: IRuleFactoryHelper, grammar: IRawGrammar): void {
	const matchers = createMatchers(selector, nameMatcher);
	const ruleId = RuleFactory.getCompiledRuleId(rule, ruleFactoryHelper, grammar.repository);
	for (const matcher of matchers) {
		result.push({
			debugSelector: selector,
			matcher: matcher.matcher,
			ruleId: ruleId,
			grammar: grammar,
			priority: matcher.priority
		});
	}
}

function nameMatcher(identifers: ScopeName[], scopes: ScopeName[]): boolean {
	if (scopes.length < identifers.length) {
		return false;
	}
	let lastIndex = 0;
	return identifers.every(identifier => {
		for (let i = lastIndex; i < scopes.length; i++) {
			if (scopesAreMatching(scopes[i], identifier)) {
				lastIndex = i + 1;
				return true;
			}
		}
		return false;
	});
}

function scopesAreMatching(thisScopeName: string, scopeName: string): boolean {
	if (!thisScopeName) {
		return false;
	}
	if (thisScopeName === scopeName) {
		return true;
	}
	const len = scopeName.length;
	return thisScopeName.length > len && thisScopeName.substr(0, len) === scopeName && thisScopeName[len] === '.';
}

export class Grammar implements IGrammar, IRuleFactoryHelper, IOnigLib {
	private _rootId: RuleId | -1;
	private _lastRuleId: number;
	private readonly _ruleId2desc: Rule[];
	private readonly _includedGrammars: { [scopeName: string]: IRawGrammar };
	private readonly _grammarRepository: IGrammarRepository & IThemeProvider;
	private readonly _grammar: IRawGrammar;
	private _injections: Injection[] | null;
	private readonly _basicScopeAttributesProvider: BasicScopeAttributesProvider;
	private readonly _tokenTypeMatchers: TokenTypeMatcher[];

	public get themeProvider(): IThemeProvider { return this._grammarRepository; }

	constructor(
		private readonly _rootScopeName: ScopeName,
		grammar: IRawGrammar,
		initialLanguage: number,
		embeddedLanguages: IEmbeddedLanguagesMap | null,
		tokenTypes: ITokenTypeMap | null,
		private readonly balancedBracketSelectors: BalancedBracketSelectors | null,
		grammarRepository: IGrammarRepository & IThemeProvider,
		private readonly _onigLib: IOnigLib
	) {
		this._basicScopeAttributesProvider = new BasicScopeAttributesProvider(
			initialLanguage,
			embeddedLanguages
		);

		this._rootId = -1;
		this._lastRuleId = 0;
		this._ruleId2desc = [null!];
		this._includedGrammars = {};
		this._grammarRepository = grammarRepository;
		this._grammar = initGrammar(grammar, null);
		this._injections = null;

		this._tokenTypeMatchers = [];
		if (tokenTypes) {
			for (const selector of Object.keys(tokenTypes)) {
				const matchers = createMatchers(selector, nameMatcher);
				for (const matcher of matchers) {
					this._tokenTypeMatchers.push({
						matcher: matcher.matcher,
						type: tokenTypes[selector],
					});
				}
			}
		}
	}

	public dispose(): void {
		for (const rule of this._ruleId2desc) {
			if (rule) {
				rule.dispose();
			}
		}
	}

	public createOnigScanner(sources: string[]): OnigScanner {
		return this._onigLib.createOnigScanner(sources);
	}

	public createOnigString(sources: string): OnigString {
		return this._onigLib.createOnigString(sources);
	}

	public getMetadataForScope(scope: string): BasicScopeAttributes {
		return this._basicScopeAttributesProvider.getBasicScopeAttributes(scope);
	}

	private _collectInjections(): Injection[] {
		const grammarRepository: IGrammarRepository = {
			lookup: (scopeName: string): IRawGrammar | undefined => {
				if (scopeName === this._rootScopeName) {
					return this._grammar;
				}
				return this.getExternalGrammar(scopeName);
			},
			injections: (scopeName: string): string[] => {
				return this._grammarRepository.injections(scopeName);
			},
		};

		const result: Injection[] = [];

		const scopeName = this._rootScopeName;

		const grammar = grammarRepository.lookup(scopeName);
		if (grammar) {
			// add injections from the current grammar
			const rawInjections = grammar.injections;
			if (rawInjections) {
				for (let expression in rawInjections) {
					collectInjections(
						result,
						expression,
						rawInjections[expression],
						this,
						grammar
					);
				}
			}

			// add injection grammars contributed for the current scope

			const injectionScopeNames = this._grammarRepository.injections(scopeName);
			if (injectionScopeNames) {
				injectionScopeNames.forEach((injectionScopeName) => {
					const injectionGrammar =
						this.getExternalGrammar(injectionScopeName);
					if (injectionGrammar) {
						const selector = injectionGrammar.injectionSelector;
						if (selector) {
							collectInjections(
								result,
								selector,
								injectionGrammar,
								this,
								injectionGrammar
							);
						}
					}
				});
			}
		}

		result.sort((i1, i2) => i1.priority - i2.priority); // sort by priority

		return result;
	}

	public getInjections(): Injection[] {
		if (this._injections === null) {
			this._injections = this._collectInjections();

			if (DebugFlags.InDebugMode && this._injections.length > 0) {
				console.log(
					`Grammar ${this._rootScopeName} contains the following injections:`
				);
				for (const injection of this._injections) {
					console.log(`  - ${injection.debugSelector}`);
				}
			}
		}
		return this._injections;
	}

	public registerRule<T extends Rule>(factory: (id: RuleId) => T): T {
		const id = ++this._lastRuleId;
		const result = factory(ruleIdFromNumber(id));
		this._ruleId2desc[id] = result;
		return result;
	}

	public getRule(ruleId: RuleId): Rule {
		return this._ruleId2desc[ruleIdToNumber(ruleId)];
	}

	public getExternalGrammar(
		scopeName: string,
		repository?: IRawRepository
	): IRawGrammar | undefined {
		if (this._includedGrammars[scopeName]) {
			return this._includedGrammars[scopeName];
		} else if (this._grammarRepository) {
			const rawIncludedGrammar =
				this._grammarRepository.lookup(scopeName);
			if (rawIncludedGrammar) {
				// console.log('LOADED GRAMMAR ' + pattern.include);
				this._includedGrammars[scopeName] = initGrammar(
					rawIncludedGrammar,
					repository && repository.$base
				);
				return this._includedGrammars[scopeName];
			}
		}
		return undefined;
	}

	public tokenizeLine(
		lineText: string,
		prevState: StateStackImpl | null,
		timeLimit: number = 0
	): ITokenizeLineResult {
		const r = this._tokenize(lineText, prevState, false, timeLimit);
		return {
			tokens: r.lineTokens.getResult(r.ruleStack, r.lineLength),
			ruleStack: r.ruleStack,
			stoppedEarly: r.stoppedEarly,
		};
	}

	public tokenizeLine2(
		lineText: string,
		prevState: StateStackImpl | null,
		timeLimit: number = 0
	): ITokenizeLineResult2 {
		const r = this._tokenize(lineText, prevState, true, timeLimit);
		return {
			tokens: r.lineTokens.getBinaryResult(r.ruleStack, r.lineLength),
			ruleStack: r.ruleStack,
			stoppedEarly: r.stoppedEarly,
		};
	}

	private _tokenize(
		lineText: string,
		prevState: StateStackImpl | null,
		emitBinaryTokens: boolean,
		timeLimit: number
	): {
		lineLength: number;
		lineTokens: LineTokens;
		ruleStack: StateStackImpl;
		stoppedEarly: boolean;
	} {
		if (this._rootId === -1) {
			this._rootId = RuleFactory.getCompiledRuleId(
				this._grammar.repository.$self,
				this,
				this._grammar.repository
			);
			// This ensures ids are deterministic, and thus equal in renderer and webworker.
			this.getInjections();
		}

		let isFirstLine: boolean;
		if (!prevState || prevState === StateStackImpl.NULL) {
			isFirstLine = true;
			const rawDefaultMetadata =
				this._basicScopeAttributesProvider.getDefaultAttributes();
			const defaultStyle = this.themeProvider.getDefaults();
			const defaultMetadata = EncodedTokenAttributes.set(
				0,
				rawDefaultMetadata.languageId,
				rawDefaultMetadata.tokenType,
				null,
				defaultStyle.fontStyle,
				defaultStyle.foregroundId,
				defaultStyle.backgroundId
			);

			const rootScopeName = this.getRule(this._rootId).getName(
				null,
				null
			);

			let scopeList: AttributedScopeStack;
			if (rootScopeName) {
				scopeList = AttributedScopeStack.createRootAndLookUpScopeName(
					rootScopeName,
					defaultMetadata,
					this
				);
			} else {
				scopeList = AttributedScopeStack.createRoot(
					 "unknown",
					 defaultMetadata
				);
			}

			prevState = new StateStackImpl(
				null,
				this._rootId,
				-1,
				-1,
				false,
				null,
				scopeList,
				scopeList
			);
		} else {
			isFirstLine = false;
			prevState.reset();
		}

		lineText = lineText + "\n";
		const onigLineText = this.createOnigString(lineText);
		const lineLength = onigLineText.content.length;
		const lineTokens = new LineTokens(
			emitBinaryTokens,
			lineText,
			this._tokenTypeMatchers,
			this.balancedBracketSelectors
		);
		const r = _tokenizeString(
			this,
			onigLineText,
			isFirstLine,
			0,
			prevState,
			lineTokens,
			true,
			timeLimit
		);

		disposeOnigString(onigLineText);

		return {
			lineLength: lineLength,
			lineTokens: lineTokens,
			ruleStack: r.stack,
			stoppedEarly: r.stoppedEarly,
