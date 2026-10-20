# loup-cmd-findstr

The Windows `findstr` command recreated in [Loup](https://code-craft.ai/references/loup):
print the lines of files that contain any of several search strings, read
as plain text or as findstr's own small regular-expression dialect, with
cmd's switches, output format, messages and ERRORLEVELs, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It uses the shared
Windows code in [`source/win/`](source/win/) (switch parser with findstr's
clustered switches, wildcard matcher, path helpers), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type), and is meant to
be read next to [loup-cmd-grep](https://github.com/myronccai/loup-cmd-grep):
grep translates POSIX expressions into `system.regex`, while findstr's
dialect is small enough for a matcher of its own (an automaton over the
pattern's items, run on the file's bytes, in
[`source/commands/pattern.loup`](source/commands/pattern.loup)).

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                            # native binary: build/findstr
make ci                               # check, unit tests, build, end-to-end tests
make run ARGS="/N hello notes.txt"    # run from source with loup run
```

Quote operands that contain `\`, `*`, `?` or spaces so that the Linux shell
passes them through: cmd does not expand wildcards, the command does.

```text
$ build/findstr 'apples euro' 'demo\notes.txt'
price 51.4 euro
200 apples
$ build/findstr /C:'apples euro' 'demo\notes.txt'; echo "ERRORLEVEL $?"
ERRORLEVEL 1
$ build/findstr /N /I '\<the\>' demo/notes.txt
3:The other theme
$ build/findstr /R /X 'h.*e' demo/notes.txt
hello there
$ build/findstr /V /N o demo/notes.txt
6:200 apples
7:end
```

Space-separated search strings are alternatives; `/C:` makes one string of
its whole value. Without `/L` or `/R`, findstr decides from the **first**
search string whether all of them are regular expressions, so the order
matters:

```text
$ build/findstr '51.4 200' demo/notes.txt
price 51.4 euro
code 5174
200 apples
$ build/findstr '200 51.4' demo/notes.txt
price 51.4 euro
200 apples
```

Wildcards, `/S` and several files put the file name before each line;
switches may be clustered:

```text
$ build/findstr /S /N TODO 'demo\*.c'
demo\src\main.c:4:    // TODO: parse the arguments
demo\src\util\str.c:2:    // TODO: handle tabs
$ build/findstr /S /M /I todo 'demo\*.c'
demo\src\main.c
demo\src\util\str.c
$ build/findstr /SIN 'TODO:' 'demo\*.c'
demo\src\main.c:4:    // TODO: parse the arguments
demo\src\util\str.c:2:    // TODO: handle tabs
$ build/findstr /G:demo/words.txt /O demo/notes.txt
40:price 51.4 euro
66:200 apples
$ printf 'x=1\ny=22\nz=x\n' | build/findstr /R /O '=[0-9][0-9]*$'
0:x=1
4:y=22
$ build/findstr hello 'demo\nope.txt' 'demo\notes.txt'; echo "ERRORLEVEL $?"
FINDSTR: Cannot open demo\nope.txt
demo\notes.txt:hello there
ERRORLEVEL 0
$ build/findstr /I; echo "ERRORLEVEL $?"
FINDSTR: Bad command line
ERRORLEVEL 2
$ build/findstr --version
findstr (loup-cmd-findstr) 0.1.0
```

(`demo/notes.txt` holds the seven lines `Hello world`, `hello there`,
`The other theme`, `price 51.4 euro`, `code 5174`, `200 apples`, `end`;
`demo/words.txt` holds `apples` and `euro`.)

## Switches

| Switch | Meaning |
|---|---|
| `strings` | The first operand, without `/C:` or `/G:`: search strings separated by spaces; a line is printed if it contains any of them |
| `/C:string` | One search string, spaces included; repeatable. Every operand is then a file name |
| `/G:file` | Search strings from a file, one per line; `/G:/` reads them from standard input |
| `/F:file` | File names from a file, one per line; `/F:/` reads them from standard input |
| `/L` | Search strings are literal |
| `/R` | Search strings are regular expressions (the later of `/L` and `/R` wins) |
| `/I` | Ignore case (ASCII letters) |
| `/B`, `/E` | The match must start at the beginning / end at the end of the line |
| `/X` | The match must be the whole line |
| `/V` | Print the lines that do not match |
| `/N` | Line number before each line (`3:text`) |
| `/O` | Byte offset of the line in its file before each line (`40:text`) |
| `/M` | Only the name of each file that has a match |
| `/S` | Search matching files in the spec's directory and all subdirectories |
| `/P` | Skip files that contain control characters (other than tab, LF, form feed, CR) |
| `/OFF[LINE]` | Accepted; Linux has no offline attribute |
| `/?` | Help |

Output lines are `[name:][number:][offset:]line`. The name is shown with
`/S`, with a wildcard, or with more than one file; never for standard
input, which is searched when no file is given.

Without `/L` or `/R`: `/C:` strings are literal; the other strings (and,
separately, the strings of a `/G:` file) are regular expressions if the
first of them contains an unescaped `. * ^ $ [ \< \>` and is a valid
expression, and literal otherwise. In literal strings `\\` is one backslash
and `\"` a quote.

Switches start with `/` or `-` and may be in any case (`/n`, `-N`), may be
clustered (`/SIN` is `/S /I /N`) and may come anywhere. A `/X` that is not
one of these is a file name (so `/tmp/a.txt` works), and `--` ends switch
parsing (`findstr -- -n file` searches for `-n`). File operands accept `\`
and `/` and the wildcards `*` and `?` (Windows rules, name order).

### Regular expressions

| Syntax | Matches |
|---|---|
| `.` | any character |
| `x*` | zero or more of the item before (a character, `.` or a class); `*` with nothing before it is a literal `*` |
| `^`, `$` | the start, the end of the line |
| `[abc]`, `[a-z]` | one character of the class |
| `[^abc]` | one character not in the class |
| `\<`, `\>` | the start, the end of a word |
| `\x` | the character `x` itself (`\.`, `\*`, `\\`) |

Everything else matches itself, including `+ ? ( ) { } |`: there is no
alternation inside an expression (give several search strings instead).

Exit status (ERRORLEVEL): `0` a line was found, `1` none was (also when
files could not be opened), `2` a bad command line or an unreadable `/G:`
or `/F:` file.

## Differences from the original

- Bytes and UTF-8 instead of a console code page: like findstr, matching
  works on bytes, but text is taken to be UTF-8. A non-ASCII character in a
  search string matches its UTF-8 bytes; `.` and a class match one byte
  (`caf..` matches `café`, `caf.$` does not); non-ASCII class members match
  any of their bytes; `/I` folds ASCII letters only. UTF-16 files are not
  decoded.
- Lines end at LF and a CR before it is ignored when matching, so `$` and
  `/E` work on Linux (LF) files as well as on CR LF files. Lines are printed
  as stored (CR included) and every printed line ends with LF, also a last
  line that had no line end (Windows adds CR LF).
- Ranges such as `[a-z]` are byte ranges; findstr's ranges follow a
  collation order in which, for example, `[a-z]` also matches most capital
  letters. Word characters for `\<` and `\>` are ASCII letters, digits, `_`
  and every non-ASCII byte.
- findstr's known bugs are not reproduced (for example missed matches with
  several literal strings of different lengths), and there are no line or
  search-string length limits.
- `/A:attr` (colours) and `/D:dirs` are reported as `FINDSTR: /A ignored`
  (as typed) and otherwise ignored; `/OFF[LINE]` has no effect.
- `FINDSTR: Bad command line` (status 2) covers every command-line error
  here: no search string, an empty `/C:`, a switch without its value, and a
  regular expression with an unclosed `[`. `Cannot read strings from` and
  `Cannot read file list from` (status 2) are this implementation's wording
  for missing `/G:` and `/F:` files.
- `/M` on standard input prints nothing (there is no name); the status
  still says whether a line matched.
- Standard input is printed from its decoded bytes, so invalid UTF-8 there
  becomes U+FFFD; files are printed byte for byte.
- `/S` follows symbolic links to directories (Loup 1.26.0 has no `lstat`),
  down to 64 levels, and wildcard names match without regard to case.
- A file that exists but cannot be read (permissions) stops the program
  with the toolchain's `IoError` message: a native `IoError` cannot be
  caught.
- Paths are printed with `\`. Messages go to standard error and end with
  LF.
- `/?` prints a short summary of the syntax, switches and expressions
  written for this project, not Windows' own help text. `--help` and
  `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup                 # entry point
source/appinfo.loup              # name, version, ERRORLEVELs
source/cli/args.loup             # findstr's switches via win.switches (clustered), Options
source/cli/usage.loup            # /? and --version text
source/cli/app.loup              # run(): parse, dispatch, exit status
source/commands/findstr.loup     # search strings, literal or regex, inputs, search_input, run_findstr
source/commands/pattern.loup     # findstr's expressions and literals: compile, match on bytes
source/commands/searcher.loup    # a set of patterns with /B /E /X
source/commands/inputs.loup      # wildcards and /S, /G: and /F: list files, /P
source/win/                      # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup                # unit tests (make test)
tests/e2e.sh                     # end-to-end tests of build/findstr (make e2e)
specs/findstr/                   # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
