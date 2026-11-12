import type en from './en.js';

export type PluralForms = { zero?: string; one?: string; two?: string; few?: string; many?: string; other: string };
export type MessageKey = keyof typeof en;
/** A language's texts: every key English has, as a plain text or, where English has plural forms, as plural forms. */
export type Catalog = { readonly [K in MessageKey]: (typeof en)[K] extends string ? string : PluralForms };
