// The tests of the group unicode.
namespace unicode_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import diff_checks;

// The expected lines come from the Rust crate similar (from_unicode_words
// and from_graphemes) and from jsdiff (intlSegmenter and ignoreCase).
fn test_unicode() {
    assert(diff_checks::unicode_is("Hello wörld äöü"[..], "Hello WÖRLD äöü!"[..], 1, "= Hello|=  |- wörld|+ WÖRLD|=  |= äöü|+ !|"[..]));
    assert(diff_checks::unicode_is("don't"[..], "don’t"[..], 1, "- don't|+ don’t|"[..]));
    assert(diff_checks::unicode_is("ab"[..], "ac"[..], 2, "= a|- b|+ c|"[..]));
    assert(diff_checks::unicode_is("Straße ΣΑΣ İstanbul"[..], "STRASSE σας istanbul"[..], 3, "- Straße ΣΑΣ İstanbul|+ STRASSE σας istanbul|"[..]));
    // The final sigma: each letter folds alone, as toLowerCase does.
    assert(diff_checks::unicode_is("ΣΑΣ x"[..], "σας x"[..], 4, "= σα|- Σ|+ ς|=  x|"[..]));
    assert(diff_checks::unicode_is("Straße"[..], "STRASSE"[..], 4, "- Straße|+ STRASSE|"[..]));
    // A text past the 1 MiB cap of the Unicode package splits after line feeds.
    var big: u8[>..] = [];
    for k in 3000 { for j in 700 { big.push('a'); } big.push(10); }
    var big2: u8[>..] = [];
    for c in big { big2.push(c); }
    big2.push('z');
    var o = diff::default_token_options();
    o.max_tokens = 8000000;
    var ch: diff::Change[>..] = [];
    let code, ex = diff::diff_unicode_words(big[..], big2[..], o, ch);
    assert(code == diff::ERR_OK);
    assert(ch.len == 2);
    // A long line without spaces still splits: a run of ASCII letters is
    // one word, and a line of Han characters cuts between the segments.
    var line: u8[>..] = [];
    for k in 1100000 { line.push('a'); }
    var one: u8[>..] = [];
    one.push('z');
    var ch2: diff::Change[>..] = [];
    let code2, ex2 = diff::diff_unicode_words(line[..], one[..], o, ch2);
    assert(code2 == diff::ERR_OK);
    assert(ch2.len == 2);
    var han: u8[>..] = [];
    for k in 400000 { han.push(0xE6); han.push(0x97); han.push(0xA5); }
    var ch3: diff::Change[>..] = [];
    let code3, ex3 = diff::diff_unicode_words(han[..], one[..], o, ch3);
    assert(code3 == diff::ERR_OK);
    // A text in a buffer against a literal works in every search.
    var mixed: u8[>..] = [];
    for c in "one two\nthree\n" { mixed.push(c); }
    var ch5: diff::Change[>..] = [];
    assert(diff::diff_lines_text(mixed[..], "one 2\nthree\n"[..], o, ch5) == diff::ERR_OK);
    assert(diff::diff_unicode_words(mixed[..], "one 2\nthree\n"[..], o, ch5) == diff::ERR_OK);
    // One word of more than 1 MiB that is no ASCII is one token.
    var wide: u8[>..] = [];
    for k in 600000 { wide.push(0xC3); wide.push(0xA9); }
    var ch4: diff::Change[>..] = [];
    let code4, ex4 = diff::diff_unicode_words(wide[..], one[..], o, ch4);
    assert(code4 == diff::ERR_OK);
    assert(ch4.len == 2);
    assert(ch4[0].len == 1200000);
}

fn test_jsdiff_options() {
    var changes: diff::Change[>..] = [];
    var o = diff::default_token_options();
    // The line end at the end of the text does not matter.
    o.ignore_newline_at_eof = true;
    assert(diff::diff_lines_text("a\nb"[..], "a\nb\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(diff_checks::check_change(changes[0], 0, 4, 2, 1, false, false));
    diff_checks::clear_changes(changes);
    o.ignore_newline_at_eof = false;
    assert(diff::diff_lines_text("a\nb"[..], "a\nb\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(diff_checks::check_change(changes[0], 0, 2, 1, 1, false, false));
    assert(diff_checks::check_change(changes[1], 2, 1, 1, 0, false, true));
    assert(diff_checks::check_change(changes[2], 2, 2, 1, 1, true, false));
    // Each line is a change of its own.
    diff_checks::clear_changes(changes);
    o.one_change_per_token = true;
    assert(diff::diff_lines_text("a\nb\nc\nd\n"[..], "a\nX\nY\nd\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 6);
    assert(diff_checks::check_change(changes[0], 0, 2, 1, 1, false, false));
    assert(diff_checks::check_change(changes[1], 2, 2, 1, 0, false, true));
    assert(diff_checks::check_change(changes[2], 4, 2, 1, 0, false, true));
    assert(diff_checks::check_change(changes[3], 2, 2, 1, 1, true, false));
    assert(diff_checks::check_change(changes[4], 4, 2, 1, 1, true, false));
    assert(diff_checks::check_change(changes[5], 6, 2, 1, 1, false, false));
    // Each character is a change of its own.
    diff_checks::clear_changes(changes);
    assert(diff::diff_chars("abcd"[..], "abXd"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 5);
    assert(diff_checks::check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(diff_checks::check_change(changes[1], 1, 1, 1, 1, false, false));
    assert(diff_checks::check_change(changes[2], 2, 1, 1, 0, false, true));
    assert(diff_checks::check_change(changes[3], 2, 1, 1, 1, true, false));
    assert(diff_checks::check_change(changes[4], 3, 1, 1, 1, false, false));
    // The word search keeps the white space of the tokens as they are.
    diff_checks::clear_changes(changes);
    assert(diff::diff_words("foo bar  baz"[..], "foo qux baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    assert(diff_checks::check_change(changes[0], 0, 4, 1, 1, false, false));
    assert(diff_checks::check_change(changes[1], 3, 6, 1, 0, false, true));
    assert(diff_checks::check_change(changes[2], 3, 5, 1, 1, true, false));
    assert(diff_checks::check_change(changes[3], 7, 4, 1, 1, false, false));
}
