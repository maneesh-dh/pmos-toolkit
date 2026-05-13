// Purpose: T9 TS001 fixture — circular import partner to b.ts; must fire TS001 once.
import { fromB } from "./b";
export const fromA = (): number => fromB() + 1;
