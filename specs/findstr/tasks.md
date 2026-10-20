# Tasks: findstr

- [x] 1. Copy the shared Windows code into `source/win/` with its tests
  - _Requirements: 5.1, 6.6_
- [x] 2. Parse findstr's command line: flags, clusters, `/C:` `/G:` `/F:`, `/L` vs `/R`, `/?`, `--`
  - _Requirements: 1.1, 1.2, 1.5, 6.3, 6.5, 6.6_
- [x] 3. Compile findstr's regular expressions and literal strings to byte patterns
  - _Requirements: 1.7, 1.8, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
- [x] 4. Match with an automaton over the items, plus the plain-bytes fast path; `/B` `/E` `/X`
  - _Requirements: 1.4, 3.1, 3.2, 3.3_
- [x] 5. Decide literal or regular expression from the first string; read `/G:` files
  - _Requirements: 1.3, 1.5, 1.6_
- [x] 6. Search one input: lines, CR, `/V`, `/N`, `/O`, `/M`, names
  - _Requirements: 3.4, 4.1, 4.2, 4.3, 4.4, 4.5_
- [x] 7. Inputs: wildcards, `/S`, `/F:` lists, standard input, `/P`, `/OFF`, ignored `/A` `/D`
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_
- [x] 8. Messages and ERRORLEVELs
  - _Requirements: 6.1, 6.2, 6.3, 6.4_
- [x] 9. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
