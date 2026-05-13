// Purpose: T9 TS001 fixture — circular import partner to a.ts; must fire TS001 once.
import { fromA } from "./a";
export const fromB = (): number => (fromA.length > 0 ? 1 : 0);
