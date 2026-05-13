// Fixture: triggers a stable, mixed-severity finding set for T16 determinism.
// Includes one warn (U004 console.log) and one info (U007 will fire on b.ts);
// no block findings so no ADR write side effects perturb determinism.
export function greet(name: string) {
  console.log("hello", name);
}
