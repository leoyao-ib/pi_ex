# Elixir Style Guide

Rules every Elixir source file in this project must follow.

## Naming

- Module names: `PascalCase` (e.g. `MyApp.UserServer`)
- Function and variable names: `snake_case`
- Predicate functions must end with `?` (e.g. `valid?/1`, `empty?/1`)
- Bang functions (raise on failure) must end with `!` (e.g. `fetch!/1`)
- Module attributes used as constants: `@screaming_snake_case` (e.g. `@max_retries`)

## Documentation

- Every public module must have a `@moduledoc` string.
- Every public function must have a `@doc` string.
- Every public function must have a `@spec` type specification.
- Private helper functions do not require docs, but complex ones should have an
  inline comment explaining intent.

## Formatting

- Maximum line length: 98 characters.
- Two-space indentation (no tabs).
- Trailing whitespace is not allowed.
- A single blank line between top-level definitions.
- Two blank lines between unrelated sections inside a module.

## Module structure order

Within a module, items should appear in this order:

1. `@moduledoc`
2. `use`, `import`, `alias`, `require` (in that order, one group per type)
3. Module attributes (`@enforce_keys`, `defstruct`, `@type`, constants)
4. `@doc` / `@spec` / public functions (entry points first)
5. Private helper functions

## Function clauses

- Multiple function clauses for the same function must be defined consecutively
  with no other functions in between.
- Default parameter clauses must come before specific ones.
- Guard clauses (`when`) are preferred over `if` inside function bodies.
