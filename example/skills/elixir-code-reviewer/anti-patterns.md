# Elixir Anti-Patterns

Common patterns to flag during code review.

## AP-01: Nested `if`/`else` instead of `case` or pattern matching

**Bad:**
```elixir
def process(x) do
  if is_integer(x) do
    if x > 0 do
      {:ok, x * 2}
    else
      {:error, :negative}
    end
  else
    {:error, :not_integer}
  end
end
```
**Good:** use `case`, `cond`, or multi-clause functions.

---

## AP-02: Catching all errors with `rescue`

Rescuing `_` or `Exception` hides bugs and violates "let it crash".

**Bad:**
```elixir
try do
  risky_call()
rescue
  _ -> :error
end
```
**Good:** only rescue specific, expected exception types.

---

## AP-03: Using `Enum.map` + `Enum.filter` as separate passes

Two passes over the same collection is wasteful; use a comprehension or
`Enum.flat_map` with `nil` filtering.

**Bad:**
```elixir
list |> Enum.map(&transform/1) |> Enum.filter(&valid?/1)
```
**Good:**
```elixir
for item <- list, valid?(transform(item)), do: transform(item)
# or use Enum.flat_map/2 to avoid double-transform
```

---

## AP-04: String interpolation of inspected terms in log messages

`Logger` macros are lazy — building the string unconditionally wastes CPU
when the log level is disabled.

**Bad:**
```elixir
Logger.debug("State is: #{inspect(state)}")
```
**Good:**
```elixir
Logger.debug(fn -> "State is: #{inspect(state)}" end)
```

---

## AP-05: Using `length/1` to check if a list is non-empty

`length/1` is O(n); use pattern matching instead.

**Bad:**
```elixir
if length(list) > 0, do: ...
```
**Good:**
```elixir
case list do
  [] -> ...
  [_ | _] -> ...
end
```

---

## AP-06: Missing `with` for chained fallible operations

Nested `case` blocks for sequential fallible calls are hard to read and
error-prone.

**Bad:**
```elixir
case step_one() do
  {:ok, a} ->
    case step_two(a) do
      {:ok, b} -> {:ok, b}
      err -> err
    end
  err -> err
end
```
**Good:**
```elixir
with {:ok, a} <- step_one(),
     {:ok, b} <- step_two(a) do
  {:ok, b}
end
```

---

## AP-07: Atoms created dynamically from untrusted input

The atom table is not garbage-collected; converting arbitrary strings to atoms
can crash the VM.

**Bad:**
```elixir
String.to_atom(user_input)
```
**Good:**
```elixir
String.to_existing_atom(user_input)
# or keep the value as a string
```
