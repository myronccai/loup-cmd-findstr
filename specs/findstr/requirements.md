# Requirements: findstr

## Introduction

`findstr` is the Windows command that prints the lines of files that
contain a search string. It takes several search strings at once (separated
by spaces, or one per `/C:` switch or per line of a `/G:` file), reads them
as plain text or as its own small regular-expression dialect, and can
search whole directory trees. This repository recreates it in Loup for
Linux, with findstr's switches, output format, messages and ERRORLEVELs and
its best-known quirks (the way it decides between plain text and regular
expressions, `*` repeating one character, `\\` in literal strings). It uses
the shared Windows code in `source/win/` (switch parser with clustered
switches, wildcards, paths).

## Requirements

### Requirement 1: Search strings

**User Story:** As a cmd user, I want to give findstr one or more search
strings so that a line containing any of them is printed.

#### Acceptance Criteria

1. WHEN neither `/C:` nor `/G:` is given, THE program SHALL take the first
   operand as the search strings, separated by spaces (runs of spaces count
   as one), and every later operand as a file name.
2. WHEN `/C:string` is given (repeatable), THE program SHALL search for the
   whole string, spaces included, and every operand SHALL be a file name.
3. WHEN `/G:file` is given, THE program SHALL read search strings from the
   file, one per line (LF or CR LF; empty lines ignored); `/G:/` SHALL read
   them from standard input.
4. A line SHALL be selected when any search string matches it.
5. WHEN `/L` is given, every search string SHALL be literal; WHEN `/R` is
   given, every search string SHALL be a regular expression; the later of
   the two SHALL win.
6. WHEN neither is given, `/C:` strings SHALL be literal, and the
   space-separated strings (and, separately, the `/G:` strings) SHALL be
   regular expressions if the first of them contains an unescaped `.`,
   `*`, `^`, `$`, `[`, `\<` or `\>` and is a valid expression, and literal
   otherwise.
7. In literal strings `\\` SHALL stand for one backslash and `\"` for a
   quote; any other backslash SHALL be itself.
8. `/I` SHALL make the search ignore the case of ASCII letters.

### Requirement 2: Regular expressions

**User Story:** As a cmd user, I want findstr's regular expressions so that
commands written for Windows find the same lines.

#### Acceptance Criteria

1. `.` SHALL match any character and `*` SHALL repeat the item before it
   (a character, `.` or a class) zero or more times; a `*` with nothing to
   repeat (at the start, after `^`, `$`, `\<` or `\>`) SHALL be a literal
   `*`, and `**` SHALL be the same as `*`.
2. `^` and `$` SHALL match the start and the end of the line (before a
   CR LF or LF), wherever they appear in the expression.
3. `[abc]`, `[a-z]` and `[^abc]` SHALL match one character of (or not of)
   the class; `]` first in the class and `-` first or last SHALL be
   members; `\x` inside a class SHALL be the character x.
4. `\<` and `\>` SHALL match the start and the end of a word (letters,
   digits, `_` and non-ASCII characters).
5. `\x` SHALL match the character x literally; every other character
   (including `+ ? ( ) { } |`) SHALL match itself.
6. WHEN a regular expression has an unclosed `[`, THE program SHALL print
   `FINDSTR: Bad command line` and exit 2.

### Requirement 3: Where the match must be

**User Story:** As a cmd user, I want `/B`, `/E` and `/X` so that I can
anchor a plain search string.

#### Acceptance Criteria

1. `/B` SHALL require the match to start at the beginning of the line.
2. `/E` SHALL require the match to end at the end of the line (a CR before
   the LF is not part of the line).
3. `/X` SHALL require the match to be the whole line (`/B` and `/E`).
4. `/V` SHALL print the lines that no search string matches instead.

### Requirement 4: Output

**User Story:** As a cmd user, I want findstr's output format so that
scripts that parse it keep working.

#### Acceptance Criteria

1. Each printed line SHALL be `[name:][number:][offset:]line`, the line
   exactly as stored (CR and any other bytes included) followed by LF.
2. The file name SHALL be printed (with `\` separators) when there is more
   than one file spec, a spec has a wildcard, or `/S` is given; not for a
   single named file or standard input.
3. `/N` SHALL print the 1-based line number; `/O` SHALL print the byte
   offset of the start of the line in its file.
4. `/M` SHALL print only the name of each file that has a selected line,
   once.
5. A last line without a line end SHALL be searched and printed with LF.

### Requirement 5: Inputs

**User Story:** As a cmd user, I want to search files, wildcards, directory
trees, file lists and standard input.

#### Acceptance Criteria

1. Operands SHALL accept `\` and `/` and the wildcards `*` and `?`
   (Windows rules), matching files in name order.
2. WHEN `/S` is given, THE program SHALL search every file whose name
   matches the spec's last component in the spec's directory and all its
   subdirectories, the directory's own files first, then each
   subdirectory in name order.
3. `/F:file` SHALL add the file names listed in the file, one per line
   (`/F:/`: from standard input).
4. WHEN there is no file at all, THE program SHALL search standard input.
5. `/P` SHALL skip files that contain control characters other than tab,
   LF, form feed and CR.
6. `/OFF` and `/OFFLINE` SHALL be accepted (there is no offline
   attribute); `/A:attr` and `/D:dirs` SHALL be reported as
   `FINDSTR: /A ignored` (as typed) and otherwise ignored.

### Requirement 6: Errors and ERRORLEVELs

**User Story:** As a script author, I want findstr's ERRORLEVELs so that
`if errorlevel` logic ported to this command behaves the same.

#### Acceptance Criteria

1. THE program SHALL exit 0 if it printed (or, with `/M`, selected) a line
   and 1 otherwise.
2. WHEN a file cannot be opened (missing, a directory, or a wildcard
   without match), THE program SHALL print `FINDSTR: Cannot open NAME` on
   standard error and go on.
3. WHEN no search string is given (no operand, only spaces, an empty
   `/C:`), THE program SHALL print `FINDSTR: Bad command line` and exit 2.
4. WHEN a `/G:` or `/F:` file cannot be read, THE program SHALL print
   `FINDSTR: Cannot read strings from NAME` or `FINDSTR: Cannot read file
   list from NAME` and exit 2.
5. WHEN `/?` or `-?` appears among the arguments, THE program SHALL print
   a short help text written for this project and exit 0; `--version`
   alone SHALL print `findstr (loup-cmd-findstr) 0.1.0` and `--help` alone
   the help.
6. Switches SHALL start with `/` or `-`, in any case, may be clustered
   (`/SIN` is `/S /I /N`), and may come anywhere; a `/X` that is not one
   of findstr's switches SHALL be an operand, as SHALL every argument
   after `--`.
