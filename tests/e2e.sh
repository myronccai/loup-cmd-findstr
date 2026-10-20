#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree.
W="$TMP/w"
mkdir -p "$W/sub/deep" "$W/lists"
printf 'Hello world\nhello there\nThe other theme\nprice 51.4 euro\ncode 5174\n200 apples\nend\n' > "$W/notes.txt"
printf 'alpha\r\nbeta here\r\nthe end' > "$W/crlf.txt"
printf 'nothing to see\nhello again\n' > "$W/sub/more.txt"
printf 'deep hello\n' > "$W/sub/deep/x.txt"
printf 'int f(void) {\n    return a+b?c:d;\n}\n' > "$W/code.c"
printf 'c:\\dir\\sub\\file\n' > "$W/paths.c"
printf 'use -n here\nplain\n' > "$W/dash.c"
printf 'caf\351 cr\350me\nother\n' > "$W/latin1.c"
printf 'hello\000world\n' > "$W/bin.dat"
printf 'apples\r\nend\n' > "$W/lists/words.lst"
printf '^h\n\n[0-9]$\n' > "$W/lists/regex.lst"
printf 'notes.txt\r\nsub\\more.txt\n' > "$W/lists/files.lst"
cd "$W" || exit 1

# Search strings: space-separated strings, /C:, literal or regex.
check      "one string"              0 $'hello there\n'                       hello notes.txt
check      "strings are alternatives" 0 $'Hello world\n200 apples\n'          'world apples' notes.txt
check      "/C: is one string"       1 ''                                     '/C:world apples' notes.txt
check      "/C: with a space"        0 $'Hello world\n'                       '/c:o w' notes.txt
check      "several /C:"             0 $'Hello world\n200 apples\n'          /C:apples '/C:Hello world' notes.txt
check      "first string is a regex" 0 $'price 51.4 euro\ncode 5174\n200 apples\n' '51.4 200' notes.txt
check      "first string is plain"   0 $'price 51.4 euro\n200 apples\n'      '200 51.4' notes.txt
check      "/L"                      0 $'price 51.4 euro\n'                   /L 51.4 notes.txt
check      "/R escaped dot"          0 $'price 51.4 euro\n'                   /R '51\.4' notes.txt
check      "/C: is literal"          0 $'price 51.4 euro\n'                   /C:51.4 notes.txt
check      "/R /C:"                  0 $'price 51.4 euro\ncode 5174\n'        /R /C:51.4 notes.txt
check      "/I"                      0 $'Hello world\nhello there\n'          /I hello notes.txt
check      "literal backslashes"     0 $'c:\\dir\\sub\\file\n'                '/C:dir\\sub' paths.c
check      "lone backslash"          0 $'c:\\dir\\sub\\file\n'                /L 'dir\sub' paths.c
check      "-- before a dash string" 0 $'use -n here\n'                       -- -n dash.c

# The regular expressions.
check      "star repeats one item"   1 ''                                     /R 'pr*euro' notes.txt
check      "dot star"                0 $'price 51.4 euro\n'                   /R 'pr.*euro' notes.txt
check      "classes"                 0 $'price 51.4 euro\ncode 5174\n200 apples\n' /R '[0-9][0-9]*' notes.txt
check      "negated class"           0 $'Hello world\nThe other theme\n200 apples\n' /R '^[^a-z]' notes.txt
check      "class with /I"           0 $'Hello world\nhello there\ncode 5174\nend\n' /I /R '^[a-h]' notes.txt
check      "word boundaries"         0 $'3:The other theme\n'                 /N /I '\<the\>' notes.txt
check      "end of a word"           0 $'The other theme\n'                   /I /R 'the\>' notes.txt
check      "other punctuation"       0 $'    return a+b?c:d;\n'               /R 'a+b?c' code.c
check      "\$ before CR LF"         0 $'beta here\r\n'                       /R 'here$' crlf.txt
check_both "unclosed class"          2 '' $'FINDSTR: Bad command line\n'      /R '[abc' notes.txt

# Where the match must be: /B, /E, /X.
check      "/B"                      0 $'The other theme\n'                   /B /I the notes.txt
check      "/E"                      0 $'end\n'                               /E end notes.txt
check      "/E before CR LF"         0 $'beta here\r\n'                       /E here crlf.txt
check      "/X"                      0 $'end\n'                               /X end notes.txt
check      "/X /C:"                  0 $'Hello world\n'                       /X /I '/C:hello world' notes.txt
check      "/X regex"                0 $'hello there\n'                       /X /R 'h.*e' notes.txt
check      "/B /E"                   0 $'end\n'                               /B /E end notes.txt

# Output: /V, /N, /O, /M, names, line ends.
check      "/V /N"                   0 $'6:200 apples\n7:end\n'               /V /N o notes.txt
check      "/V nothing left"         1 ''                                     /V e notes.txt
check      "/O /N"                   0 $'7:77:end\n'                          /O /N end notes.txt
check      "/O with CR LF"           0 $'crlf.txt:18:the end\nnotes.txt:77:end\n' /O end crlf.txt notes.txt
check      "CR LF kept"              0 $'1:alpha\r\n'                         /N alpha crlf.txt
check      "last line without LF"    0 $'the end\n'                           the crlf.txt
check      "clustered switches"      0 $'1:Hello world\n2:hello there\n'      /NI hello notes.txt
check      "dash switches"           0 $'1:Hello world\n2:hello there\n'      -n -I hello notes.txt
check      "several files"           0 $'notes.txt:hello there\nsub\\more.txt:hello again\n' hello notes.txt sub/more.txt
check      "wildcard shows names"    0 $'notes.txt:Hello world\n'             world '*.txt'
check      "/M"                      0 $'notes.txt\nsub\\more.txt\n'          /M hello '*.txt' 'sub\more.txt'
check      "/M one file"             0 $'notes.txt\n'                         /M hello notes.txt
printf 'caf\351 cr\350me\n' > "$TMP/latin1.want"
check_file "bytes printed unchanged" 0 "$TMP/latin1.want"                     caf latin1.c
printf 'hello\000world\n' > "$TMP/bin.want"
check_file "NUL bytes"               0 "$TMP/bin.want"                        hello bin.dat
check      "/P skips control bytes"  0 $'notes.txt:hello there\n'             /P hello bin.dat notes.txt

# /S.
check      "/S"                      0 $'notes.txt:Hello world\nnotes.txt:hello there\nsub\\more.txt:hello again\nsub\\deep\\x.txt:deep hello\n' /S /I hello '*.txt'
check      "/S /M"                   0 $'notes.txt\nsub\\more.txt\nsub\\deep\\x.txt\n' /S /M hello '*.txt'
check      "/S plain name"           0 $'sub\\more.txt:hello again\n'         /S hello more.txt
check      "/S below a directory"    0 $'sub\\more.txt:2:hello again\nsub\\deep\\x.txt:1:deep hello\n' /S /N hello 'sub\*.txt'
check      "/SIN"                    0 $'sub\\deep\\x.txt:1:deep hello\n'     /SIN DEEP '*.txt'

# /G: and /F:, standard input.
check      "/G: literal strings"     0 $'200 apples\nend\n'                   '/G:lists\words.lst' notes.txt
check      "/G: regexes"             0 $'hello there\ncode 5174\n'            /G:lists/regex.lst notes.txt
IN=lists/words.lst check "/G:/ from stdin" 0 $'200 apples\nend\n'             /G:/ notes.txt
check      "/F:"                     0 $'notes.txt:hello there\nsub\\more.txt:hello again\n' /F:lists/files.lst hello
IN=lists/files.lst check "/F:/ from stdin" 0 $'notes.txt:hello there\nsub\\more.txt:hello again\n' /F:/ hello
IN=notes.txt check "standard input" 0 $'6:200 apples\n'                       /N apples
IN=crlf.txt check "stdin /O"        0 $'7:beta here\r\n18:the end\n'           /O /R 'e.e'
IN=notes.txt check "stdin /M"       0 ''                                      /M apples
IN=notes.txt check "stdin not found" 1 ''                                     nothing

# Errors and ERRORLEVELs.
check      "not found"               1 ''                                     nope notes.txt
check_both "missing file"            0 $'notes.txt:hello there\n' $'FINDSTR: Cannot open nope.txt\n' hello nope.txt notes.txt
check_both "only a missing file"     1 '' $'FINDSTR: Cannot open nope.txt\n'  hello nope.txt
check_both "wildcard without match"  1 '' $'FINDSTR: Cannot open *.none\n'    hello '*.none'
check_both "a directory"             1 '' $'FINDSTR: Cannot open sub\n'       hello sub
check_both "unknown switch is a file" 1 '' $'FINDSTR: Cannot open \\Q\n'      hello /Q
check_both "no arguments"            2 '' $'FINDSTR: Bad command line\n'
check_both "no search strings"       2 '' $'FINDSTR: Bad command line\n'      /I /N
check_both "only spaces"             2 '' $'FINDSTR: Bad command line\n'      '  ' notes.txt
check_both "empty /C:"               2 '' $'FINDSTR: Bad command line\n'      /C: notes.txt
check_both "missing /G: file"        2 '' $'FINDSTR: Cannot read strings from lists\\nope.lst\n' /G:lists/nope.lst notes.txt
check_both "missing /F: file"        2 '' $'FINDSTR: Cannot read file list from nope.lst\n' /F:nope.lst hello
check_both "/A and /D ignored"       0 $'hello there\n' $'FINDSTR: /A ignored\nFINDSTR: /d ignored\n' /A:1F /d:sub hello notes.txt

# Help and version.
check      "version"                 0 $'findstr (loup-cmd-findstr) 0.1.0\n'  --version
"$BIN" '/?' > "$TMP/help" 2>&1 < /dev/null
status=$?
if [ "$status" -eq 0 ] && head -1 "$TMP/help" | grep -q '^Prints the lines of files' && grep -q '^FINDSTR \[/B\]' "$TMP/help"; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: /? (exit $status)"
fi
"$BIN" hello '-?' notes.txt > "$TMP/help2" 2>&1 < /dev/null
if [ $? -eq 0 ] && cmp -s "$TMP/help" "$TMP/help2"; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: -? anywhere"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
