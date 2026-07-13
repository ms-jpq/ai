---
paths:
  - "*.gemspec"
  - "*.rake"
  - "*.rb"
  - "Gemfile"
  - "Rakefile"
---

# Ruby

## Defaults

- Typical script prelude:

  ```ruby
  #!/usr/bin/env -S -- ruby
  # frozen_string_literal: true
  ```

- Import files directly with `require_relative "..."`.

- Use `private`, `protected`, and `private_constant` for non-exported helpers.

---

## Functions

- Prefer keyword arguments.

  ```ruby
  def fetch(source:, timeout: 30, retries: 2) ...
  ```

- Assert method input shape at entry, then write the body against the bound locals.

  ```ruby
  def process(input:, limit:)
    [input, limit] => [String, Integer | nil]
  end
  ```

- Use `Enumerator.new` as Ruby's generator form; keep incremental state inside the enumerator.

  ```ruby
  def product(*iterables, repeat: 1)
    pools = iterables.map(&:to_a) * repeat

    Enumerator.new do |y|
      result = [[]]
      pools.each do |pool|
        result = result.flat_map { |xs| pool.map { xs + [_1] } }
      end
      result.each(&y)
    end
  end
  ```

---

## Control Flow

- Use pattern matching to prove the incoming shape and reject unexpected data.

  ```ruby
  case [mode, value]
  in [:text, String]
    value.strip
  in [:count, Integer]
    value.succ
  end
  ```

- Add `else` only for a better error or cleanup path.

- Use `Kernel.then` for small conversions that need lexical encapsulation and an inline expression result.

  ```ruby
  decoded = Kernel.then do
    JSON.parse(data, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end
  ```

---

## Data Access

- After parsing, reading, decoding, or transforming, use `=>` to bind the expected shape or fail immediately.

  ```ruby
  Integer(raw_count) => Integer => count
  ```

- Read hash records by destructuring them into locals.

  ```ruby
  record => {id: String => id, count: Integer => count}
  ```

- Use `fetch` and `fetch_values` for required hash keys.

- Reserve `[]` for optional or nil-tolerant lookup.

---

## Transforms

- Chain collection transforms instead of mutating an accumulator.

- Use `transform_values`, `filter_map`, `to_h do`, `slice`, and `except`.

---

## Data Modeling

- Use plain `Hash` records with symbol keys as the default data representation.

- Use `Data.define` when a repeated shape needs a named immutable value object.

  ```ruby
  Item = Data.define(:id, :count)

  item = Item.new(id:, count:)
  ```
