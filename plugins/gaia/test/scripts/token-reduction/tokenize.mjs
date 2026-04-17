#!/usr/bin/env node
// tokenize.mjs — deterministic surrogate tokenizer for NFR-048 measurements.
//
// token count = ceil(prompt_bytes / 4) — matches the Anthropic rule of thumb
// and _memory/config.yaml archival.token_approximation. Determinism is
// absolute: the same bytes always produce the same token count.
//
// Usage:
//   node tokenize.mjs <prompt_file>  → prints integer token count on stdout

import { readFileSync } from "node:fs";

export function tokenize(bytes) {
  if (!(bytes instanceof Uint8Array) && !Buffer.isBuffer(bytes)) {
    throw new Error("tokenize: input must be a Buffer or Uint8Array");
  }
  return Math.ceil(bytes.length / 4);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const path = process.argv[2];
  if (!path) {
    console.error("usage: node tokenize.mjs <prompt_file>");
    process.exit(2);
  }
  const buf = readFileSync(path);
  process.stdout.write(String(tokenize(buf)));
}
