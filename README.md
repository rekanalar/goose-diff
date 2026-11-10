# goose-diff

[![ci](https://github.com/rekanalar/goose-diff/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-diff/actions/workflows/ci.yml)

Text differences for Goose. The package computes a diff of two texts. It writes the diff in the unified format. It reads a unified patch. It applies a patch to a text.

It finds the blocks of equal lines and the words that match a word best. It compares the characters, the words, the lines and the sentences of two texts.

## Install

```goose
import diff from "rekanalar/goose-diff@v1.1.0";
```

The package depends on `goose-unicode`. A program declares the dependency in its root file too, because Goose reads the packages from the root file only:

```goose
import unicode from "rekanalar/goose-unicode@v0.3.0";
```

The word bounds, the cluster bounds and the case fold of Unicode come from that package.

## Reference libraries

| Library | What the package matches |
|---|---|
| Python `difflib` | `SequenceMatcher` with `find_longest_match`, `get_matching_blocks`, `get_opcodes`, `get_grouped_opcodes`, `ratio`, `quick_ratio`, `real_quick_ratio`, junk and `autojunk`. Also `get_close_matches` |
| Python `difflib` | The opcodes of the change, the grouping of hunks, the format of a range, the format of a unified diff |
| Python `difflib` | `context_diff` |
| Python `difflib` | `ndiff` with the lines of hints, and `restore` |
| Python `difflib` | `HtmlDiff` with `make_table` and `make_file` |
| Node `diff` (jsdiff) | `createPatch`, `applyPatch`, the reading of a patch, the reverse apply |
| Node `diff` (jsdiff) | `diffChars`, `diffTrimmedLines`, `diffSentences`, `diffArrays`, the switches of the options |
| Node `diff` (jsdiff) | `diffCss`, `diffJson`, and the canonical form of a JSON value |
| Node `diff` (jsdiff) | `diffWords`, `diffWordsWithSpace`, the table of the word characters |
| Rust `similar` | The Myers, Patience and LCS searches (`Algorithm::Myers`, `Algorithm::Patience`, `Algorithm::Lcs`) |
| Rust `similar` | The unified output, the reading of a patch, the apply of a patch |
| Go `go-difflib` | `GetUnifiedDiffString`, the writing of a unified diff |

## Features

- **A minimal diff of two texts.** The search is the Myers diff. The result holds the opcodes of the change, as `difflib` gives them.
- **A diff that reads well.** The package holds the search of `difflib`. It finds the longest block of equal lines that holds no junk. The blocks read well to a person.
- **The unified format.** The output follows GNU `diff -u`. It holds the file names, the hunk headers and the lines of the change.
- **The patch of several files.** One patch holds many files, each with many hunks. The reader skips the lines before a file header, such as `Index:` and `diff --git`.
- **The structured patch.** `structured_patch` builds the hunk structure of jsdiff from two texts. `patch_text` and `format_patch` write it as text, `create_patch` in the form with the line of `Index:`. `patch_parse_structured` reads one file of a patch into it. `patch_reverse` flips it. `patch_apply_fuzz` applies it, with a rule for context lines that may mismatch.
- **The XML and DMP forms.** `changes_xml` and `changes_dmp` give a change list in the XML and the `diff-match-patch` forms. The XML form escapes `&`, `<`, `>` and the quote, as jsdiff does.
- **The apply of a patch.** The apply checks every context line and every removed line. It finds a hunk that sits at another line than its header says.
- **The reverse apply.** The patch takes the text back to the form before the change.
- **Five searches.** The rule `algorithm` takes five values. `ALG_MYERS` is the classic search and `ALG_RO` is the matcher of `difflib`. `ALG_PATIENCE`, `ALG_LCS` and `ALG_MYERS_SPLIT` follow `similar`. The Patience search and `ALG_MYERS_SPLIT` match the Rust crate `similar` step by step.
- **The CSS and JSON searches.** `diff_css` compares the tokens of a style sheet. `diff_json` writes both JSON texts in one canonical form with sorted keys, then compares the lines. A comma at the end of a line does not count.
- **The context format.** `context_diff` writes the context diff of `difflib`. The hunks follow the rule `context`.
- **The dates and the line terminator.** `unified_diff_dated` and `context_diff_dated` take a date for each file. They take the line terminator of the header lines. Python names these `fromfiledate`, `tofiledate` and `lineterm`.
- **The delta with hints.** `ndiff` writes the delta of `difflib`. A pair of close lines gets a line of hints that marks the changed characters. `ndiff_restore` takes one of the two texts back out of a delta.
- **The side by side HTML diff.** `html_table` and `html_file` write the table and the page of `HtmlDiff`. The table holds the line numbers and the links to the changes. It marks the changes inside a line. It has a context form and wraps long lines. The bytes follow Python 3.14.
- **The close words.** The package finds the words that match a word best. It compares the words by their characters.
- **The token searches.** The package compares the characters, the sentences and the tokens that the caller gives. It also compares the lines without the white space at their ends.
- **The Unicode word, cluster and case rules.** `diff_unicode_words`, `diff_graphemes`, `unicode_words` and `unicode_case` follow `similar` and the Node library.
- **The word searches.** The package compares the words of two texts. One search ignores the white space between the words. The other keeps it.
- **The switches of a token search.** Four switches change the search. They cover the case, the white space, the carriage return and the line end.
- **A bounded search.** The search for a hunk and the search of the matcher spend from a budget. A patch that needs too much work is a fault, not a hang.
- **The minimality flag.** Every diff call gives a flag. The flag is true when the diff holds the most equal lines that any diff can hold.

## API

| Call | What it does |
|---|---|
| `diff_lines(a, b, o, ops)` | Adds the opcodes of `a` against `b` to `ops`. Gives a code and the minimality flag |
| `unified_diff(out, a, b, a_name, b_name, o)` | Adds the unified diff of `a` against `b` to `out`. Gives a code and the minimality flag |
| `matcher_blocks(a, b, o, blocks)` | Adds the blocks of equal lines of `a` against `b` to `blocks`. Gives a code |
| `matcher_opcodes(a, b, o, ops)` | Adds the opcodes of the matcher of `a` against `b` to `ops`. Gives a code and the minimality flag |
| `matcher_longest(a, b, o, alo, ahi, blo, bhi)` | Gives the longest block of equal lines in a range of the two texts. Gives a code and the block |
| `matcher_grouped(a, b, o, n, ops, ends)` | Adds the opcodes of the matcher to `ops` and the ends of the hunks to `ends`. Gives a code |
| `matcher_ratio(a, b, o)` | Gives the ratio of the two texts. Gives a code and the ratio |
| `diff_ratio(a, b, o)` | Gives the ratio over the lines of the diff, as `TextDiff::ratio` of `similar`. Gives a code and the ratio |
| `matcher_quick_ratio(a, b, o)` | Gives the quick ratio of the two texts. Gives a code and the ratio |
| `matcher_real_quick_ratio(a, b, o)` | Gives the real quick ratio of the two texts. Gives a code and the ratio |
| `unified_diff_dated(out, a, b, a_name, b_name, a_date, b_date, lineterm, o)` | The unified diff with a date after each name and the line terminator of the header lines. Gives a code and the minimality flag |
| `context_diff_dated(out, a, b, a_name, b_name, a_date, b_date, lineterm, o)` | The context diff with the same dates and terminator. Gives a code and the minimality flag |
| `context_diff(out, a, b, a_name, b_name, o)` | Adds the context diff of `a` against `b` to `out`. Gives a code and the minimality flag |
| `diff_css(a, b, o, changes)` | Adds the changes of the CSS tokens of `a` against `b` to `changes`. Gives a code and the minimality flag |
| `json_canonical(text, o, out)` | Adds the canonical form of a JSON text to `out`. Sorted keys, two blanks of indent, the numbers of JavaScript. Gives a code |
| `diff_json(a, b, o, ca, cb, changes)` | Writes the canonical forms of `a` and `b` to `ca` and `cb`. Adds the changes of their lines to `changes`. Gives a code and the minimality flag |
| `diff_json_text(a, b, o, changes)` | Compares two texts line by line. A comma at the end of a line does not count. Gives a code and the minimality flag |
| `ndiff(a, b, o, out)` | Adds the delta of `a` against `b` to `out`. Lines of the first text begin with `- `, lines of the second with `+ `, shared lines with two blanks, hints with `? `. Gives a code |
| `ndiff_restore(delta, which, out)` | Adds the lines of the text `which` (1 or 2) of a delta to `out`, without the codes. Gives a code |
| `close_matches(word, cands, n, cutoff, out)` | Adds the places of the words that match the word best to `out`. Gives a code |
| `diff_chars(a, b, o, changes)` | Adds the changes of the characters of `a` against `b` to `changes`. Gives a code and the minimality flag |
| `inline_changes(a, b, o, changes, segs)` | Adds every line of the diff of `a` against `b` to `changes`, with its segments in `segs`. A block of changed lines that share enough words gets its changed words marked. It follows `iter_inline_changes` of `similar` |
| `inline_missing_newline(a, b, c, segs)` | Tells whether the last segment of an inline change has no line end |
| `diff_lines_text(a, b, o, changes)` | Adds the changes of the lines of `a` against `b`, as `diffLines` of jsdiff does. The rules `ignore_whitespace`, `ignore_newline_at_eof` and `one_change_per_token` apply |
| `diff_lines_trimmed(a, b, o, changes)` | Adds the changes of the lines of `a` against `b` to `changes`. It cuts the white space at the ends of the lines |
| `diff_sentences(a, b, o, changes)` | Adds the changes of the sentences of `a` against `b` to `changes`. Gives a code and the minimality flag |
| `diff_arrays(a, b, ta, tb, o, changes)` | Adds the changes of the two lists of tokens to `changes`. The tokens stand in the two texts |
| `diff_words(a, b, o, changes)` | Adds the changes of the words of `a` against `b` to `changes`. The white space between the words does not matter |
| `diff_unicode_words(a, b, o, changes)` | Adds the changes of the Unicode words of `a` against `b`. Every word and every run of white space is a token, as `from_unicode_words` of `similar` gives them |
| `diff_graphemes(a, b, o, changes)` | Adds the changes of the grapheme clusters of `a` against `b`, as `from_graphemes` of `similar` gives them |
| `diff_words_with_space(a, b, o, changes)` | Adds the changes of the words of `a` against `b` to `changes`. The white space between the words matters |
| `patch_parse(text, files, hunks, body)` | Reads a unified patch. Gives a code |
| `patch_apply(src, text, files, hunks, body, file, o, out)` | Adds the text of `src` after one file of a patch is applied. Gives a code |
| `structured_patch(a_name, b_name, a, b, a_header, b_header, o, sp, hunks, names, marks, body, lspans)` | Builds the structured patch of `a` against `b` into the flat buffers. Gives a code |
| `patch_text(sp, hunks, names, marks, body, lspans, out)` | Writes the structured patch as patch text. The line of `Index:` appears when the two names are equal. Gives a code |
| `format_patch(sp, hunks, names, marks, body, lspans, out)` | Writes a structured patch as patch text, as `patch_text` does. Gives a code |
| `format_patch_opts(sp, hunks, names, marks, body, lspans, hopt, out)` | Writes a structured patch with the headers that `hopt` names. Gives a code |
| `patch_text_opts(sp, hunks, names, marks, body, lspans, hopt, out)` | Does the same as `format_patch_opts` |
| `default_header_options()`, `file_headers_only_options()`, `omit_headers_options()` | Give the `HeaderOptions` of `INCLUDE_HEADERS`, `FILE_HEADERS_ONLY` and `OMIT_HEADERS` in jsdiff. The fields are `include_index`, `include_underline`, `include_file_headers` and `skip_empty_header` |
| `create_patch(name, a, b, a_header, b_header, o, sp, hunks, names, marks, body, lspans, out)` | Builds the patch of one file and writes it. Gives a code |
| `patch_parse_structured(text, file, sp, hunks, names, marks, body, lspans)` | Reads one file of a patch into the structured model. Gives a code |
| `patch_reverse(sp, hunks, names, marks, fsp, fhunks, fnames, fmarks)` | Fills the flipped patch. The flipped patch shares the body lines with the patch. Gives a code |
| `patch_apply_all(srcs, spans, text, files, hunks, body, o, out, outs)` | Applies every file of a patch to its own source, as `applyPatches` of jsdiff does. The caller loads the sources. It stops at the first fault and gives the code and the index of the file |
| `patch_apply_fuzz(src, sp, hunks, marks, body, lspans, o, out)` | Applies a structured patch. The rule `fuzz` gives the most context lines that may mismatch. Gives a code |
| `changes_xml(changes, a, b, out)` | Writes the change list in the XML form. Removed text goes into `<del>`, added text into `<ins>`. The text is escaped. Gives a code |
| `changes_dmp(changes, a, b, out)` | Writes the change list as the `diff-match-patch` array of pairs of a tag and a text. Gives a code |
| `default_options()` | The rules of most calls: 3 lines of context, 2000 edits, 16 MiB of input |
| `default_token_options()` | The rules of most token searches: 2000 edits, 16 MiB of input, no switch |
| `html_table(a, b, from_desc, to_desc, o, h, out)` | Adds the side by side HTML table of `a` against `b`. Gives a code |
| `html_file(a, b, from_desc, to_desc, charset, o, h, out)` | Adds a full HTML page with the table, the style and the legend. Gives a code |
| `default_html_options()` | The rules of Python: a tab stop of 8, no break, all lines, 5 lines, prefix 0, 64 MiB of output |
| `default_apply_options()` | The rules of most applies: a forward apply, 50 million compares, no fuzz, a shift of 1 million lines, 16 MiB of input |
| `error_text(code)` | Names a code |

### The opcodes

| Field | Meaning |
|---|---|
| `tag` | `OP_EQUAL`, `OP_DELETE`, `OP_INSERT` or `OP_REPLACE` |
| `a_lo`, `a_hi` | The range of the lines of the first text. The end is the first line outside the range |
| `b_lo`, `b_hi` | The range of the lines of the second text |

### The blocks of equal lines

| Field | Meaning |
|---|---|
| `a`, `b` | The place of the first line of the block in each text |
| `size` | The count of the equal lines of the block |

The last block is the empty block at the end of the texts. Its place is the count of the lines of each text.

### The changes of a token search

| Field | Meaning |
|---|---|
| `at` | The place of the first byte of the change in the text it comes from |
| `len` | The count of the bytes of the change |
| `count` | The count of the tokens of the change |
| `text` | The text of the change: 0 for the first text, 1 for the second text |
| `added` | The change stands in the second text only |
| `removed` | The change stands in the first text only |

A part that stays comes from the second text, as the Node library gives it.

### The rules of a diff

| Field | Meaning | Default |
|---|---|---|
| `context` | The lines of context around a change in the unified output | 3 |
| `max_edits` | The most edits that the Myers search takes. It goes from 1 to 3000 | 2000 |
| `max_input` | The most bytes of one input | 16777216 |
| `algorithm` | The search of the diff, from `ALG_MYERS` to `ALG_MYERS_SPLIT` | `ALG_MYERS` |
| `junk` | The junk rule of the matcher: `JUNK_NONE`, `JUNK_BLANK` or `JUNK_COMMENT` | `JUNK_NONE` |
| `char_junk` | The junk characters of `ndiff` and of the HTML table: `CHARJUNK_BLANK` (the blank and the tab) or `CHARJUNK_NONE` | `CHARJUNK_BLANK` |
| `autojunk` | The popular rule of the matcher. It drops a line that appears often in the second text | true |
| `max_work` | The most compares that the matcher spends. It goes from 0 to 500000000 | 50000000 |
| `strip_trailing_cr` | The carriage return that stands before a line feed does not matter | false |
| `max_tokens` | The most lines of the two texts. It goes from 1 to 8000000 | 2000000 |
| `unicode_words` | `inline_changes` splits the words at the word bounds of Unicode, as `similar` does with its `unicode` feature | false |

A program that builds the rules with a literal must name every field. A program that takes the rules from `default_options()` needs no change.

### The words

| Field | Meaning |
|---|---|
| `at` | The place of the first byte of the change in the text it comes from |
| `len` | The count of the bytes of the change |
| `count` | The count of the words of the change |

The white space between the words stands in two words of the Node
library. The package moves it to the part that stays, as the Node
library does.

### The rules of a token search

| Field | Meaning | Default |
|---|---|---|
| `max_edits` | The most edits that the Myers search takes. It goes from 1 to 3000 | 2000 |
| `max_input` | The most bytes of one input | 16777216 |
| `algorithm` | The search of the diff, from `ALG_MYERS` to `ALG_MYERS_SPLIT` | `ALG_MYERS` |
| `max_work` | The most compares that the search spends. It goes from 0 to 500000000 | 50000000 |
| `ignore_case` | The case of the tokens does not matter | false |
| `ignore_whitespace` | The white space at the ends of a token does not matter | false |
| `strip_trailing_cr` | The carriage return that stands before a line feed does not matter | false |
| `newline_is_token` | The line end is a token of its own | false |
| `ignore_newline_at_eof` | A line end at the end of a line does not matter. Acts in `diff_lines_text` when `ignore_whitespace` and `newline_is_token` are off | false |
| `one_change_per_token` | Every token is a change of its own. The word search does not move white space | false |
| `max_tokens` | The most tokens of the two texts. It goes from 1 to 8000000 | 2000000 |
| `unicode_words` | `diff_words` splits the words at the word bounds of Unicode, as the `intlSegmenter` option of the Node library does | false |
| `unicode_case` | The tokens compare with the full lower case form of Unicode, as `ignoreCase` of the Node library does | false |

The rule `newline_is_token` changes the line searches only. The rule `ignore_whitespace` has no effect on the trimmed line search, which always cuts the white space.

### The rules of an apply

| Field | Meaning | Default |
|---|---|---|
| `reverse` | Apply the patch the other way | false |
| `max_work` | The most line compares that the search spends | 50000000 |
| `max_shift` | The most lines that a hunk may move from the place of its header | 1000000 |
| `max_input` | The most bytes of the text | 16777216 |
| `fuzz` | The most context lines of a hunk that may mismatch | 0 |
| `auto_line_ends` | Convert the line ends of the patch when the text uses only CRLF and the patch only LF, or the reverse. Acts in `patch_apply_fuzz` | true |

### The codes

| Code | The fault |
|---|---|
| `ERR_OK` | No fault |
| `ERR_TOO_LARGE` | An input, a file count or a hunk count is over the limit |
| `ERR_BAD_OPTION` | A rule is out of range |
| `ERR_BAD_NAME` | A file name holds a line end |
| `ERR_BAD_PATCH` | The patch is not a valid unified patch |
| `ERR_NO_MATCH` | A hunk matches no place in the text |
| `ERR_TOO_MUCH_WORK` | The search for a hunk took too much work |
| `ERR_NO_FILE` | The patch holds no such file |
| `ERR_BAD_JSON` | The text is not JSON |

A call that fails leaves the buffer of the caller as it was.

## Example

```goose
import std;
import diff from "rekanalar/goose-diff@v1.1.0";

fn main() {
    var out: u8[>..] = [];
    let code, exact = diff::unified_diff(out, "one\ntwo\n", "one\nthree\n", "a.txt", "b.txt",
                                         diff::default_options());
    assert(code == diff::ERR_OK && exact);
    print(out[..]);
}
```

## Security

- **The Patience search spends from a budget.** It counts the rounds and the compares of its Myers searches. At `max_work` the range that is left becomes one replace. The diff stays valid, but not minimal. The call says so with its flag.
- **The LCS table has a cap.** The table holds at most 16777216 cells, which is 64 MB. A pair of texts that needs more gives `ERR_TOO_MUCH_WORK`. So does a table past `max_work`. The Rust crate holds the table in a map with no cap. Memory grows with the product of the two lengths.
- **The Patience search maps the ids onto a dense range.** It gives every distinct id a place in a map. The map holds one slot per distinct id. A caller may pass ids of any value, even a negative one. No id can reach past the arrays of the counts.
- **The dates and the terminator are checked.** A date with a line end gives `ERR_BAD_NAME`. The line terminator may hold the bytes 10 and 13 only, two at most. Python takes any text, so a terminator could forge a line of a diff.
- **The HTML text is escaped.** The table escapes `&`, `<` and `>` in every line. It escapes the two descriptions too, and the quote as well. Python writes the two descriptions as they are, so a name with markup injects HTML.
- **The marks of the table stay out of the text.** Python uses the bytes 0 and 1 as inner marks. A text with such a byte breaks its markup. The package gives `ERR_BAD_TEXT` for a text or a description with one.
- **The page charset is checked.** It may hold letters, digits and `-_.:` only. Python writes the charset into the page as it is.
- **The HTML output has a cap.** The rule `max_output` bounds the bytes of the table and of the tab expand. A break at column 1 or a tab stop of a million cannot fill memory.
- **The fuzz apply spends from a budget.** Every try of a hunk place counts one compare. A patch against a large text with a small budget gives `ERR_TOO_MUCH_WORK`, not a hang. The cap of the rule `fuzz` is 100.
- **A structured fault changes nothing.** `structured_patch`, `patch_reverse` and `patch_apply_fuzz` build their output apart. They copy it after every check passes.
- **The model ranges are checked.** Every place and every count of the model must lie inside its buffer. A model that a caller builds with a range past its buffer gives `ERR_BAD_PATCH`. So a bad range cannot read past the buffer.
- **The apply stays inside the source.** A hunk that asks for more lines than the text holds gives `ERR_NO_MATCH`. The Node library reads past the end and stops the process.
- **The change list is checked against its texts.** Every change must lie inside the text that it names. A change with a place past its text gives `ERR_BAD_OPTION`.
- **The JSON writer holds no recursion.** It walks the tree with a stack in a buffer. A text of `[` repeated one million times cannot overflow the call stack. The Node library recurses and fails on deep input.
- **The canonical text has a size cap.** It may not pass eight times the rule `max_input`. A deep text has an output of the order of its depth squared, because every level adds an indent. The cap gives `ERR_TOO_LARGE` instead.
- **The call `diff_json` caps each canonical text at `max_input`.** It stops at the cap before it compares. A deep pair cannot cost memory for a result that the call then refuses.
- **The keys sort once per object.** The sort costs the order of n log n. An object of many equal keys keeps one key.
- **The JSON parser is the parser of the standard library.** It reads RFC 8259 text only. A text with a comment, a trailing comma or a bare word gives `ERR_BAD_JSON`.
- **A failed JSON call changes nothing.** `json_canonical` and `diff_json` build their output apart. They copy it after every check passes.
- **The delta spends from a budget.** The search counts the length of every pair of lines and every compare. It stops at `max_work` and gives `ERR_TOO_MUCH_WORK`. A block of near lines cannot make it run forever. The Python library `difflib` has no such bound.
- **The delta looks ten lines to each side.** The close pair search stays inside a window of ten lines. So the work grows with the count of lines, not with its square.
- **A delta line always ends in a line end.** Python joins an unended last line to the next code. The package adds one.
- **A fault leaves the buffer of the caller as it was.** The call `ndiff` builds the delta apart. It copies the delta after the search ends.

- **The search for a hunk spends from a budget.** The apply counts the line compares. It stops at `max_work` and gives `ERR_TOO_MUCH_WORK`. A patch that moves a hunk far gives `ERR_NO_MATCH`. A hostile patch cannot make the search run forever.
- **The search of the matcher spends from a budget.** The matcher counts its compares and its walk over the lines. It stops at `max_work` and gives `ERR_TOO_MUCH_WORK`. A text that repeats the same line many times cannot make the search run forever.
- **The close words spend from a budget.** The search stops at 50 million compares and gives `ERR_TOO_MUCH_WORK`. A long list of words cannot make the search run forever.
- **The counts of a patch are checked against its body**. A hunk header may not count more lines than the body holds. A patch may not ask for a big count and give few lines.
- **A line that the counts do not ask for is a fault**. It comes after the last line of a hunk. GNU `patch` refuses it too. The package refuses it, so a patch cannot carry a change that the apply drops without a fault.
- **The numbers of a header are bounded.** A number of more than 15 digits is a fault. A header cannot ask for a line number beyond the range of the machine.
- **The file count and the hunk count are bounded.** A patch holds at most 10000 files and 100000 hunks.
- **The size of an input is bounded.** A text of more than 16 MiB is a fault.
- **The diff of two texts is minimal.** The search keeps a trace of the order of its square. The rule `max_edits` bounds that trace. The cap of 3000 keeps the trace of one call at about 36 MB. The rule `max_work` bounds the compares of the search. Past a bound, the diff stays valid, but it is not minimal. The call says so with its flag.
- **The word searches spend from a budget.** The word search counts its compares. The Myers search stops at `max_work`. Its diff then stays valid, but it is not minimal.
- **The places of the words stay inside the text.** Every change holds a place and a count of bytes. The count never goes below zero. A move of the white space that does not fit a change is left out.
- **The token searches spend from a budget.** The search counts its compares. The search of `difflib` stops at `max_work` and gives `ERR_TOO_MUCH_WORK`. The Myers search stops at `max_work` too. Its diff then stays valid, but it is not minimal. A text of many distinct characters cannot make the search run forever.
- **The places of the tokens are checked.** The array search takes the places of the tokens from the caller. A place outside its text is a fault. So a bad place cannot read past the text.
- **The size of a token search is bounded.** A text of more than 16 MiB is a fault. The count of the tokens of a text stays within the text.
- **The count of the lines and the tokens is bounded.** Every line and every token holds memory of its own. The rule `max_tokens` caps the count. The search stops at the cap, so it never holds the whole list. A text of too many lines gives `ERR_TOO_LARGE`. So a hostile text cannot make the package hold a long list.
- **The rules of a diff stay in range**. The rule `context` goes to 1073741824. The rule `max_edits` goes to 3000. The rule `max_work` goes to 500000000. A rule beyond its cap is a fault. So no rule can wrap the arithmetic of the output or of the search.
- **The lines of a text never join into one byte.** Every line keeps its line end. A line of the text can hold any byte, so a diff never splits a line of a text.
- **A failed call changes nothing**. A fault in the read of a patch rolls back the file list, the hunk list and the body list. A fault in an apply rolls back the output buffer. A fault in the matcher rolls back the list of the blocks and the list of the opcodes.
- **The Unicode splits bound their input.** The package `goose-unicode` takes at most 1 MiB per call. The package cuts a longer text where the rules give a break, so the cap does not limit the input. The token count stays under `max_tokens`. The token count stays under `max_tokens`. A hostile text cannot grow the work past the budget.

Risks that stay: the package reads a patch and a text from the caller. It does not read a file and it does not run a command. Your program bounds the size of a patch from a network. The caller chooses the size of the buffer that holds the patch.

## Limits

- **Two ratios exist, and the references disagree.** `matcher_ratio` counts the blocks of the `difflib` matcher. `diff_ratio` counts the equal lines of the diff, as `similar` does. The two values can differ for the same texts. No standard fixes the choice, so the package offers both.
- **Python `difflib` ends a last line in another way.** It writes no marker for a last line with no end. The package writes `\ No newline at end of file`, as GNU `diff`, jsdiff and `similar` do.
- **An absent header needs a switch.** jsdiff writes no tab for an undefined header. It writes a tab for an empty one. The writers write the tab for both, unless `skip_empty_header` is true.
- **The Unicode splits use the default rules.** They follow UAX 29 with no dictionary and no locale. A text in Chinese, Japanese, Thai, Lao, Khmer or Burmese splits where the default rules split it. The Node `Intl.Segmenter` may split these texts at the word of a dictionary. The Rust crate `unicode-segmentation` splits as the package does. The package has no list of abbreviations.
- **`unicode_case` lowers each token alone.** A one-letter capital sigma stays `σ`, as in the Node library.
- **The inline search uses the Patience search for the words.** The rule `algorithm` names the search of the lines. The words always use `ALG_PATIENCE`, as `similar` does.
- **`ALG_MYERS` is the classic search.** It may pick another shortest script than `similar`. Use `ALG_MYERS_SPLIT` for the script of `similar`, with its compaction pass.
- **The LCS search differs from `similar` on a shared prefix.** The table of `similar` reads the wrong elements then. Its script holds fewer equal lines than the longest common subsequence. The package builds the table after the prefix, so it keeps the longest one.
- **The Myers search of the package differs from `similar`.** Both give a minimal diff. They pick other anchors when more than one diff is minimal. The Patience search runs the Myers search of `similar` over its gaps, so it matches the crate on every case.
- **The LCS search fixes a fault of the crate.** `similar` starts the table at the first line. It should start after the common start. The diff may then miss the longest subsequence. The package builds the table after the common start. It always gives the longest. The outputs differ on about one random case in six.
- **The flag of the Patience search is strict.** Patience does not promise the smallest diff. The flag is true only when the check of the minimality finds that it is the smallest. The check runs on small texts only.
- **The Patience search needs memory for its Myers search.** Two arrays hold the furthest points. They cost about 16 bytes per line.
- **The deadline of `similar` is the budget here.** The crate stops by the clock. The package stops by the count of steps, so a result does not depend on the speed of the machine.
- **The JSON search takes text.** The Node library takes a value. The package takes a JSON text. Build the text with the standard library. A JSON string at the top is a string in the output. The Node library takes a string as a text that is already written.
- **The numbers follow JavaScript.** A number reads as a double. An integer above 2^53 loses its low digits, as in JavaScript. A number that is not finite gives `null`. The text of the number comes from the shortest form of the standard library.
- **The keys sort as in JavaScript.** The keys that are array indexes come first, in the order of their values. The other keys follow in the order of the UTF-16 code units. A key with a half of a surrogate pair can sort in another place. Keys with the same code points but other broken bytes sort by their bytes.
- **Equal lines may come as several changes.** The Node library joins the longer lines into one change. The package gives one change for each part from one text.
- **The JSON search needs memory for every value.** A value costs about 80 bytes. A 16 MiB document of small values may take over a gigabyte. Lower `max_input` to bound it.
- **The replacer of the Node library is out.** The options `stringifyReplacer` and `undefinedReplacement` have no meaning for a JSON text.
- **Bytes that are no UTF-8 pass through.** The Node library works on UTF-16 strings and cannot hold such bytes.
- **The context diff marks a line without a line end.** `difflib` writes the line as it is. The package adds a line end and the marker line of GNU `diff`.
- **The hints count code points.** A mark stands under one code point, as in Python. A broken byte counts as one code point. A terminal may show a wide character in two columns, so the marks may not line up.
- **A last line without a line end gets one.** The delta holds that line with a line end. `ndiff_restore` gives it back with a line end. The Python library keeps the line as it is.
- **The delta takes junk rules, not junk functions.** The line search follows the rule `junk`. The mode `JUNK_COMMENT` is `IS_LINE_JUNK` of Python. The character search follows `char_junk`, and `CHARJUNK_BLANK` is `IS_CHARACTER_JUNK`. Python also takes any function, as `linejunk` and `charjunk`. Goose holds no function value.
- **The diff works on lines.** The call `diff_lines` compares whole lines. A change inside a line shows the whole line on each side. The token searches show the change inside the line.
- **The HTML page is UTF-8.** Python encodes the page into the charset. The package names the charset and writes UTF-8.
- **The anchor prefix is a rule.** Python counts the tables of a page with a global counter. The package takes the number in the rule `prefix`. Give each table of a page its own number.
- **The table follows the junk rules of `ndiff`.** It takes no junk function, for the reason that `ndiff` takes none.
- **A line end ends a line.** The table splits a text at the line feed. A carriage return stays in the line and resets the column of the tab stops.
- **A large fuzz apply takes time.** The budget is 50 million compares. A hunk that matches nowhere searches every place of a large text. Lower `max_work` and `max_shift` for a patch from a network.
- **The word searches hold the white space twice.** The Node library gives the white space between two words to both. A change there holds it twice.

The package gives the white space to one word and then moves it. The changes hold the same bytes as the changes of the Node library.
- **The word search cuts the white space at the ends.** The Node library compares the words without that white space. The package does the same.
- **The changes hold bytes.** The Node library holds the text of a change. The package holds the place of the text and the count of its bytes. A code point outside the Basic Multilingual Plane holds more bytes than characters.
- **The array search takes the places of the tokens.** The Node library takes the tokens themselves. The package takes the place of every token in its text.
- **`ignore_case` folds ASCII letters only.** It folds A to Z. A letter outside ASCII keeps its case. Set `unicode_case` for the full lower case form of Unicode, as `ignoreCase` of the Node library gives it.
- **The carriage return stays in the text.** The Node library removes the carriage return from the text before the search. The package keeps it in the text of a change and ignores it in the comparison. The unified output keeps it too. GNU `diff --strip-trailing-cr` removes it from the output.
- **The switches reach further than in the Node library.** The switch `ignore_whitespace` and the switch `strip_trailing_cr` change every token search. The Node library applies them to the line searches only.
- **The token searches pick another anchor than the Node library.** Both diffs hold the same count of changes. The anchor decides which part stays. The reference libraries disagree on the anchor. The word searches differ from the Node library on four of every hundred cases. The search of the package matches the Python library `difflib` on every case.
- **The close words compare characters.** The package compares the words by their characters, as `difflib` does. The words stand in one text, one per line. A word with a line end cannot stand in the list of the words.
- **The matcher holds no state.** The Python library keeps the two texts in the matcher and changes them. The package takes the two texts in every call. The results are the same.
- **The junk rule is a mode.** The Python library takes a function that tells junk. Goose holds no function value. The package takes a mode. The mode names no junk, a blank line, or a blank line and a hash sign. The last mode matches Python 3.14. The blank line alone matches Python 3.13 and older.
- **The memory of the matcher grows with the lines.** The matcher holds an array for every distinct line. A text of many short lines costs more memory than a text of few long lines.
- **The memory of a token search grows with the tokens.** The package holds a span for every token. A text of many characters costs more memory than a text of few long lines. The rule `max_tokens` keeps the memory of one call at about 160 MB. Its cap of eight million tokens gives about 600 MB.
- **The move of the white space holds a table.** The word search walks the runs of white space. The table holds one place per part of a run. One long run costs the order of its length.
- **The matcher is not minimal.** The search of `difflib` gives blocks that read well to a person. It does not give the smallest diff. The call gives the flag of the minimality, and the flag is false in most cases.
- **The flag of the minimality runs on small texts.** The check counts the longest common subsequence of the two texts. It runs only for small texts: a million lines each, and a million pairs. Past that, the flag is false.
- **The unified output holds no time stamp.** GNU `diff -u` writes the time of each file into the two header lines. The package writes only the names that the caller gives.
- **The diff of two texts may differ from the diff of GNU**. The reference libraries pick different anchors when more than one diff is minimal. GNU `diff` skips the search when it thinks the cost is too high. So its diff is not always minimal. The package always gives a minimal diff, unless the rule `max_edits` stops the search first. The rule `algorithm` gives the search of `difflib`, which picks other anchors.
- **The hunks of `structured_patch` may sit elsewhere than those of jsdiff.** The two libraries pick other anchors. The counts of changes stay the same. Of 200 random cases, 191 hold the byte-for-byte hunks of jsdiff.
- **The structured patch holds one file.** The caller loops over the files of a patch with several files. jsdiff walks them through callbacks. The reader `patch_parse_structured` takes one file by index.
- **A header holds one line.** jsdiff lets a header hold line ends. The builder refuses a name or a header with a line end, as the patch reader of the package does.
- **The writer always takes the tab of a header.** jsdiff leaves the tab out when the caller passes no header. The package writes one tab for every header, even an empty one.
- **The apply of a patch reads no file**. `patch_apply_all` takes the sources from the caller, one per file. `patch_apply` takes the index of one file.
- **The read of a patch takes no limit of bytes**. The count of files and the count of hunks are bounded. The size of the patch is not. Your program bounds the size of a patch from a network.
- **The apply takes the same text that the read took**. The call holds the patch bytes apart from the parsed places. Give it the text that `patch_parse` read. Another text holds places that do not fit.
- **The apply does not create or remove a file.** A patch that adds or removes a file gives `ERR_NO_MATCH`. The package does not touch a file of the file system.
- **The patch reads no binary diff.** The package reads the unified format only. The Git binary format, and the format of `diff -u` with the `--binary` rule, stay out.
- **The patch holds no other text.** A line before the first file header is skipped. A patch with a text of its own is not read.
- **A hunk finds its place by its content.** The apply searches outward from the place of the header. A hunk that matches at many places takes the first one that fits.
