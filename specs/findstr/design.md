# Design: findstr

## Overview

```text
argv ─▶ parse_args ─▶ Options ─▶ collect_strings ─▶ SearchString list
                                   │                  (literal or regex per findstr's rule)
                                   ▼
                              build_searcher ─▶ Searcher (one compiled Pattern per string)
                                   │
  file specs (+ /F: list) ─▶ resolve_spec ─▶ files ─▶ readBytes + readText
                                                        │
                                                        ▼
                                  search_input(Searcher, SearchConfig, bytes, lines)
                                                        │
                                                        ▼
                                     SearchResult (output lines, found) ─▶ println
```

Matching is done on the input's **bytes**, as findstr does: each line is a
range of the bytes returned by `readBytes`, so no string is built per line
to search it. The lines are printed from `readText(path).split("\n")`
(native strings keep every byte), so output is byte for byte.

## Modules

| Module | Role |
|---|---|
| `source/cli/args.loup` | class `Options`, `findstr_switches()` (shared parser, clustered), `parse_args()`; first operand vs files; `MSG_BAD_COMMAND_LINE` |
| `source/cli/usage.loup` | `usage()` (the `/?` text, written for this project), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, `/?`, `--version`, `run_findstr`, ERRORLEVEL |
| `source/commands/pattern.loup` | class `Pattern` (compiled search string and its matcher), `compile_regex()`, `compile_literal()`, `looks_like_regex()`, `unescape_literal()`, `split_search_strings()`, UTF-8 helpers |
| `source/commands/searcher.loup` | class `SearchString`, class `Searcher` (any pattern selects a line; `/B` `/E` `/X`), `build_searcher()` |
| `source/commands/inputs.loup` | `resolve_spec()` (wildcards, `/S`), `shows_names()`, `/G:` and `/F:` list files, `has_control_bytes()` (`/P`) |
| `source/commands/findstr.loup` | classes `SearchConfig`, `SearchResult`; `search_input()` (pure), `collect_strings()`, `run_findstr()` |
| `source/win/` | shared Windows code (copy): switches, wildcards, paths, messages |

### Command line

The shared switch parser is called with `clusters = true`, so `/SIN` is
`/S /I /N` when every letter is a findstr flag. Declared: the flags
`B E L R S I X V N M O P OFF OFFLINE`, and `C G F A D` with a required value
(`/C:x`, `/C x`). A missing value is `FINDSTR: Bad command line` (status 2).
Without `/C:` or `/G:`, the first operand is the search strings; an operand
that is empty or only spaces is a bad command line too. `/L` and `/R` set a
mode; the later wins.

### Literal or regular expression

`collect_strings` returns one `SearchString(text, regex)` per string:

- `/C:` strings: literal, unless `/R`.
- The space-separated strings: `/L` or `/R` decide; otherwise all are
  regular expressions if `looks_like_regex(first)`: the first string has an
  unescaped `. * ^ $ [` (or `\<`, `\>`) and compiles. So `"51.4 200"` is two
  regular expressions and `"200 51.4"` two literals.
- `/G:` strings: the same rule, decided by the first non-empty line of the
  files.

Literal strings are unescaped (`\\` → `\`, `\"` → `"`) and compiled to a
pattern of plain bytes.

### Patterns and matching

`compile_regex` walks the pattern's code points and produces items:

| Item | From | Consumes |
|---|---|---|
| `K_CHAR b` | a literal character: one item per UTF-8 byte; `\x` gives x | one byte equal to b |
| `K_ANY` | `.` | any one byte |
| `K_CLASS i` | `[...]`, `[^...]`: lo-hi byte pairs, negation flag | one byte in (not in) the class |
| `K_BOL`, `K_EOL` | `^`, `$` (anywhere) | nothing: start / end of line |
| `K_WORD_START`, `K_WORD_END` | `\<`, `\>` | nothing: word boundary |

A `*` stars the previous consuming item; with nothing to repeat it is a
literal `*`; `**` is `*`. Under `/I`, ASCII capitals in the pattern are
folded to lower case (and classes get the lower-case form of their capital
ranges), and the matcher folds each line byte as it reads it. Non-ASCII
class members add each of their UTF-8 bytes.

`Pattern.search(data, start, stop, from_start, to_end)` tests one line,
`data[start:stop]` without its LF (and without a CR before it):

- A pattern of plain bytes (every literal string) is compared at each
  start position (only one with `/B` or `/E`).
- Any other pattern is simulated as an automaton over the items:
  `reached[k] == at` marks item k as reached after `at` bytes. At each
  position the start item is added (every position, or only the first with
  `/B`), a forward pass follows the zero-width steps (skipping a starred
  item, passing an assertion that holds), the end of the pattern is checked
  (at the end of the line only, with `/E`), and a backward pass reads one
  byte (a starred item stays, another item moves on). The cost is at most
  items × bytes per line, with no backtracking blow-up, and the `reached`
  buffer is reused from line to line.

### Searching an input

`search_input` walks `data` line by line (LF ends a line; a last line
without LF counts), asks the `Searcher`, applies `/V`, and builds
`[name:][number:][offset:]line` from `lines[k]` (or, for standard input,
from the decoded bytes). `/M` stops at the first selected line and yields
the name. It returns a `SearchResult` (output lines and whether a line was
selected); `run_findstr` prints them.

### Inputs

`resolve_spec(spec, subdirs)`:

- `/S`: `find_recursive(parent_dir(spec), base_name(spec), MATCH_FILES)`,
  wildcards or not (a wildcard in a directory part gives nothing);
- a wildcard: `expand(spec, MATCH_FILES)`;
- otherwise the spec itself; `run_findstr` reports a missing file or a
  directory as `FINDSTR: Cannot open NAME`.

File names are printed when `/S` is given, a spec has a wildcard, or there
is more than one spec (command line plus `/F:` list). With no spec at all,
standard input is read with `readBytes("/dev/stdin")`.

### Native-build notes

- The matcher works on `bytes` (`readBytes`) because per-line strings and
  lists are never freed natively: turning each line into a list of code
  points cost about 1.2 KB per line (300 MB for 200,000 lines); the byte
  version stays flat (about 45 MB for a 5 MB, 100,000-line file, 0.2 s).
- Records that cross modules (`Options`, `SearchString`, `Searcher`,
  `SearchConfig`, `SearchResult`, `Pattern`) are classes, not structs.
- `Pattern.search` and `Searcher.selects` are `modifier` methods (they
  reuse the `reached` buffer); callers wrap them in `safe { }` or are
  `safe func`s taking `edits`.
- `match` on strings is avoided (`if` chains), and no `match` expression
  builds a new value in an arm.

## Differences from the original

See the README's "Differences from the original". In short: bytes and
UTF-8 instead of a console code page; `$` and `/E` also work on LF-only
lines; ranges are byte ranges (not findstr's collation order); `/A` and
`/D` are ignored; long-line limits and several Windows messages are not
reproduced; `/?` is this project's own text.

## Error handling

| Situation | Message (stderr) | Status |
|---|---|---|
| no search strings, empty `/C:`, missing switch value | `FINDSTR: Bad command line` | 2 |
| unclosed `[` in a regular expression | `FINDSTR: Bad command line` | 2 |
| `/G:` file missing | `FINDSTR: Cannot read strings from NAME` | 2 |
| `/F:` file missing | `FINDSTR: Cannot read file list from NAME` | 2 |
| file missing, a directory, wildcard without match | `FINDSTR: Cannot open NAME` (and go on) | 0/1 |
| `/A:x`, `/D:x` | `FINDSTR: /A ignored` (and go on) | 0/1 |

A file that exists but cannot be read stops the program with the
toolchain's `IoError` message (a native `IoError` cannot be caught).

## Testing

- `tests/pattern_test.loup`: compiled items (`describe()`), star and class
  quirks, matching, anchors, words, `/B` `/E`, `/I`, bytes, the
  literal-or-regex rule, unescaping, splitting.
- `tests/searcher_test.loup`: several strings, literal plus regex, `/X`
  `/B` `/E` `/I`, bad expressions.
- `tests/args_test.loup`: switches, clusters, `/C:` and `/G:` turning
  operands into files, `--`, ignored switches, bad command lines.
- `tests/inputs_test.loup`: list files, `resolve_spec` on a fixture tree
  (`build/tmp/`), name rule, `/P`.
- `tests/findstr_test.loup`: `search_input` output forms (`/N` `/O` names
  `/V` `/M`, CR kept, last line), `collect_strings` modes and `/G:` files.
- `tests/app_test.loup`: ERRORLEVELs of whole command lines.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: 77 cases against the native binary in a fixture tree:
  every switch, the quirks, `/S`, `/G:` `/F:` (also from standard input),
  byte-exact output (Latin-1 and NUL bytes), messages and statuses.
