import { expect, test } from "vitest";
import { APP_VERSION } from "./version";

// Teste de fumaça: estabelece o encanamento do Vitest no CI. Os testes de
// comportamento chegam com o port do RunnerEngine (P1).
test("APP_VERSION segue o formato semver", () => {
  expect(APP_VERSION).toMatch(/^\d+\.\d+\.\d+$/);
});
