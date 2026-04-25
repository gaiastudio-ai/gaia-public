# VCP-FIX-02 — WARNING then clean

> Covers AC1 of E44-S2. LLM-checkable.

## Setup

Artifact with one auto-correctable WARNING finding (e.g., stated component count does not match filesystem enumeration).

## Steps

1. Iteration 1: Val returns one WARNING.
2. Fix applied (update the count). Iteration record appended.
3. Iteration 2: Val returns `findings: []`. Exit loop.

## Assertions

- Exactly 2 Val invocations.
- Both iterations logged to `checkpoint.custom.val_loop_iterations` with severity tagged on iteration 1 finding.
- WARNING is treated as loop-driving (same as CRITICAL).
- Skill proceeds past the loop after iteration 2.
