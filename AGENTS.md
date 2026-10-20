# AGENTS.md

This repository recreates the Windows `findstr` command (search files for
strings and findstr's own regular expressions) in the Loup programming
language, as part of the loup-cmd series of example applications. The
program is `host.dual` Loup built as a native executable for Linux, with
cmd's switch, wildcard, path and message conventions. findstr's expression
dialect is compiled into a list of items and matched by a small automaton
of its own on the input's bytes (no `system.regex`). `source/win/` is a copy
of the shared Windows code (master: loup-cmd-type).

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, ERRORLEVELs (0, 1, 2)
│   ├── cli/
│   │   ├── args.loup            # class Options, findstr_switches(), parse_args() (clustered switches)
│   │   ├── usage.loup           # usage() (the /? summary), version_line()
│   │   └── app.loup             # run(): parse, /? and --version, run_findstr, exit status
│   ├── commands/
│   │   ├── findstr.loup         # collect_strings() (literal or regex), search_input(), run_findstr()
│   │   ├── pattern.loup         # class Pattern: compile_regex(), compile_literal(), search() on bytes
│   │   ├── searcher.loup        # class Searcher: any pattern selects a line; /B /E /X
│   │   └── inputs.loup          # resolve_spec() (wildcards, /S), /G: and /F: list files, /P
│   └── win/                     # shared Windows code (a copy; see below)
│       ├── switches.loup        # cmd switch parser: /S -s /A:H /AH /T 10 /S/Q /SIN /? --
│       ├── wildcard.loup        # Win32 wildcard matcher, expand(), find_recursive()
│       ├── paths.loup           # fs_path(), display_path(), split/join helpers
│       └── messages.loup        # Windows message texts
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void (win_*_test.loup test source/win/)
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/findstr/               # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored); unit tests write fixtures to build/tmp/
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="/N hello notes.txt"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time (`--no-parallel`) |
| Run matching tests | `make test TEST_ARGS="--filter words"` | tests whose name contains `words` |
| Run one test file | `make test TEST_ARGS="--file tests/pattern_test.loup"` | |
| Build | `make build` | native binary at `build/findstr` |
| Run the binary | `build/findstr /S /N TODO '*.c'` | quote `\`, `*`, `?`, spaces and `/?` in the shell |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/findstr`: stdout byte for byte, stderr exactly |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/findstr --version` |
| Clean | `make clean` | removes `build/`, `.temp/` and `.loup-cache/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests. Keep `--no-parallel`: Stage0's
parallel test runner fails these tests at random.

## Making a change

1. Update the spec in `specs/findstr/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in the spec's `tasks.md`.

Keep behaviour in pure functions that return values (`search_input`
returns a `SearchResult` with every output line; `Pattern.describe()` shows
what an expression compiled to) so unit tests can check it; only
`run_findstr` prints.

`source/win/` is a copy of the shared Windows code. Do not change it here
alone: changes go to the master copy in loup-cmd-type and
`ccai-examples/shared/windows/` first.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from win.switches import (parse_switches);`. Tests import them the same
  way. Do not use relative imports (`from .args import ...`): the
  self-hosted `loup run` on Linux x86-64 fails on them.
- Windows conventions: switches via `win.switches` (a `/X` that is not
  declared is a path); operands go through `fs_path()` before file access;
  every printed path goes through `display_path()`; messages use findstr's
  `FINDSTR: ...` wording; a bad command line is ERRORLEVEL 2.
- Match on bytes, not strings: `readBytes` gives the data and a line is a
  `(start, stop)` range of it. Natively every string or list built per line
  stays allocated, so the matcher builds nothing per line (`Pattern`
  reuses its `reached` buffer). The text for output comes from
  `readText(path).split("\n")`, which keeps every byte.
- Records that cross modules are classes (`Options`, `SearchString`,
  `Searcher`, `SearchConfig`, `SearchResult`, `Pattern`): native builds can
  corrupt struct values passed between modules. `Pattern.search` and
  `Searcher.selects` are `modifier` methods: call them inside `safe { }` or
  from a `safe func` that takes the object as `edits`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`; use
  `len() == 0`), `system.text.parseInt` does not link, `IoError` cannot be
  caught (check `isFile`/`isDir` before reading), and a `match` expression
  whose arms build new strings returns freed memory (use the statement form
  or `if` chains).
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
