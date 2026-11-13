// The tests of the group token.
namespace token_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import common;

fn test_token_chars() {
    // The changes of the character search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_chars("hello world"[..], "hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 6);
    assert(common::check_change(changes[0], 0, 6, 6, 1, false, false));
    assert(common::check_change(changes[1], 6, 2, 2, 0, false, true));
    assert(common::check_change(changes[2], 6, 3, 3, 1, true, false));
    assert(common::check_change(changes[3], 9, 1, 1, 1, false, false));
    assert(common::check_change(changes[4], 9, 2, 2, 0, false, true));
    assert(common::check_change(changes[5], 10, 1, 1, 1, true, false));
    // The same text gives one change that stays.
    common::clear_changes(changes);
    assert(diff::diff_chars("abc"[..], "abc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 3, 3, 1, false, false));
    // Two texts with no character in common.
    common::clear_changes(changes);
    assert(diff::diff_chars("xy"[..], "ab"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(common::check_change(changes[0], 0, 2, 2, 0, false, true));
    assert(common::check_change(changes[1], 0, 2, 2, 1, true, false));
    // An empty text gives no change.
    common::clear_changes(changes);
    assert(diff::diff_chars(""[..], "abc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 3, 3, 1, true, false));
}

fn test_token_trimmed() {
    // The changes of the trimmed line search. It cuts the white space at
    // the ends of the lines.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_lines_trimmed("  a \n b  \n"[..], "  a \n b  \n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 10, 2, 1, false, false));
    // The white space at the ends of a line does not matter.
    common::clear_changes(changes);
    assert(diff::diff_lines_trimmed("one\n"[..], "two\nthree\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(common::check_change(changes[0], 0, 4, 1, 0, false, true));
    assert(common::check_change(changes[1], 0, 10, 2, 1, true, false));
    // The lines differ only in their white space.
    common::clear_changes(changes);
    assert(diff::diff_lines_trimmed("  a \n"[..], "a\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 2, 1, 1, false, false));
}

fn test_token_sentences() {
    // The changes of the sentence search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_sentences("One. Two! Three? Four."[..], "One. Two! Three? Five."[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 17, 6, 1, false, false));
    assert(common::check_change(changes[1], 17, 5, 1, 0, false, true));
    assert(common::check_change(changes[2], 17, 5, 1, 1, true, false));
    // A text of one sentence gives one change.
    common::clear_changes(changes);
    assert(diff::diff_sentences("Hello world"[..], "Hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(common::check_change(changes[0], 0, 11, 1, 0, false, true));
    assert(common::check_change(changes[1], 0, 11, 1, 1, true, false));
}

fn test_token_arrays() {
    // The changes of the array search. The tokens stand in the texts.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    var ta: diff::Span[>..] = [];
    var tb: diff::Span[>..] = [];
    ta.push(diff::Span { at: 0, len: 1 });
    ta.push(diff::Span { at: 1, len: 1 });
    tb.push(diff::Span { at: 0, len: 1 });
    tb.push(diff::Span { at: 1, len: 1 });
    assert(diff::diff_arrays("ab"[..], "xy"[..], ta[..], tb[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(common::check_change(changes[0], 0, 2, 2, 0, false, true));
    assert(common::check_change(changes[1], 0, 2, 2, 1, true, false));
    // One token on each side.
    common::clear_changes(changes);
    ta.resize(0, diff::Span { at: 0, len: 0 });
    tb.resize(0, diff::Span { at: 0, len: 0 });
    ta.push(diff::Span { at: 0, len: 1 });
    tb.push(diff::Span { at: 0, len: 1 });
    assert(diff::diff_arrays("a"[..], "b"[..], ta[..], tb[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(common::check_change(changes[0], 0, 1, 1, 0, false, true));
    assert(common::check_change(changes[1], 0, 1, 1, 1, true, false));
    // The same token on each side gives one change that stays.
    common::clear_changes(changes);
    assert(diff::diff_arrays("a"[..], "a"[..], ta[..], tb[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 1, 1, 1, false, false));
}

fn test_token_switches() {
    var changes: diff::Change[>..] = [];
    // The case switch. The fold covers the Latin letters of ASCII.
    var oc = diff::default_token_options();
    oc.ignore_case = true;
    assert(diff::diff_chars("Hello"[..], "hello"[..], oc, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 5, 5, 1, false, false));
    common::clear_changes(changes);
    let o = diff::default_token_options();
    assert(diff::diff_chars("Hello"[..], "hello"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 1, 1, 0, false, true));
    assert(common::check_change(changes[1], 0, 1, 1, 1, true, false));
    assert(common::check_change(changes[2], 1, 4, 4, 1, false, false));
    // The white space switch. It cuts the white space at the ends of a
    // token.
    common::clear_changes(changes);
    var ow = diff::default_token_options();
    ow.ignore_whitespace = true;
    assert(diff::diff_chars("a "[..], "a"[..], ow, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(common::check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(common::check_change(changes[1], 1, 1, 1, 0, false, true));
    // The carriage return switch. It drops the carriage return that
    // stands before a line feed.
    common::clear_changes(changes);
    var ocr = diff::default_token_options();
    ocr.strip_trailing_cr = true;
    assert(diff::diff_chars("a\r\n"[..], "a\n"[..], ocr, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 2, 2, 1, false, false));
    common::clear_changes(changes);
    assert(diff::diff_chars("a\r\n"[..], "a\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(common::check_change(changes[1], 1, 1, 1, 0, false, true));
    assert(common::check_change(changes[2], 1, 1, 1, 1, false, false));
    // The line end switch. It gives the line end a token of its own.
    common::clear_changes(changes);
    var onl = diff::default_token_options();
    onl.newline_is_token = true;
    assert(diff::diff_lines_trimmed("a\nb"[..], "a\nc"[..], onl, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 2, 2, 1, false, false));
    assert(common::check_change(changes[1], 2, 1, 1, 0, false, true));
    assert(common::check_change(changes[2], 2, 1, 1, 1, true, false));
    // The carriage return switch of the line search.
    common::clear_changes(changes);
    var ol = diff::default_options();
    ol.strip_trailing_cr = true;
    var ops: diff::Op[>..] = [];
    assert(diff::diff_lines("a\r\n"[..], "a\n"[..], ol, ops) == diff::ERR_OK);
    assert(ops.len == 1);
    assert(ops[0].tag == diff::OP_EQUAL);
    var ol2 = diff::default_options();
    var ops2: diff::Op[>..] = [];
    assert(diff::diff_lines("a\r\n"[..], "a\n"[..], ol2, ops2) == diff::ERR_OK);
    assert(ops2.len == 1);
    assert(ops2[0].tag == diff::OP_REPLACE);
}

fn test_token_broken() {
    // A text with a broken code point keeps the bytes of the broken point
    // in one character.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_chars("a\x80b"[..], "a\x80c"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 2, 2, 1, false, false));
    assert(common::check_change(changes[1], 2, 1, 1, 0, false, true));
    assert(common::check_change(changes[2], 2, 1, 1, 1, true, false));
}

fn test_token_bounds() {
    var changes: diff::Change[>..] = [];
    // A rule out of range is a fault.
    let o = diff::default_token_options();
    var ob = diff::default_token_options();
    ob.max_edits = 0;
    assert(diff::diff_chars("a"[..], "b"[..], ob, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    var ob2 = diff::default_token_options();
    ob2.algorithm = 9;
    assert(diff::diff_chars("a"[..], "b"[..], ob2, changes) == diff::ERR_BAD_OPTION);
    var ob3 = diff::default_token_options();
    ob3.max_work = 500000001;
    assert(diff::diff_chars("a"[..], "b"[..], ob3, changes) == diff::ERR_BAD_OPTION);
    // An input over the limit is a fault.
    var ob4 = diff::default_token_options();
    ob4.max_input = 1;
    assert(diff::diff_chars("ab"[..], "b"[..], ob4, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    // The search spends from the budget of the work.
    var ob5 = diff::default_token_options();
    ob5.algorithm = diff::ALG_RO;
    ob5.max_work = 1;
    assert(diff::diff_chars("abc"[..], "abd"[..], ob5, changes) == diff::ERR_TOO_MUCH_WORK);
    assert(changes.len == 0);
    // More tokens than the rule allows is a fault.
    var ob6 = diff::default_token_options();
    ob6.max_tokens = 1;
    assert(diff::diff_chars("ab"[..], "ab"[..], ob6, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    var ob7 = diff::default_token_options();
    ob7.max_tokens = 8000001;
    assert(diff::diff_chars("ab"[..], "ab"[..], ob7, changes) == diff::ERR_BAD_OPTION);
    // A span outside its text is a fault.
    var bad: diff::Span[>..] = [];
    bad.push(diff::Span { at: 0, len: 100 });
    assert(diff::diff_arrays("ab"[..], "cd"[..], bad[..], bad[..], o, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    var bad2: diff::Span[>..] = [];
    bad2.push(diff::Span { at: -1, len: 1 });
    assert(diff::diff_arrays("ab"[..], "cd"[..], bad2[..], bad2[..], o, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    // The line search counts its lines too.
    var ol = diff::default_options();
    ol.max_tokens = 1;
    var ops: diff::Op[>..] = [];
    assert(diff::diff_lines("a\nb\n"[..], "a\nc\n"[..], ol, ops) == diff::ERR_TOO_LARGE);
    assert(ops.len == 0);
    // The Myers search spends from the budget of the work. The diff
    // stays valid, but it is not minimal.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for k in 200 {
        a.push('a' + (k % 26) as! u8);
        a.push(10);
        b.push('a' + ((k + 1) % 26) as! u8);
        b.push(10);
    }
    var ow = diff::default_options();
    ow.max_work = 100;
    var ops2: diff::Op[>..] = [];
    let code, exact = diff::diff_lines(a[..], b[..], ow, ops2);
    assert(code == diff::ERR_OK);
    assert(!exact);
}

fn test_token_words() {
    // The changes of the word search. The white space between the words
    // does not matter to the search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_words("hello world"[..], "hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 6, 1, 1, false, false));
    assert(common::check_change(changes[1], 6, 5, 1, 0, false, true));
    assert(common::check_change(changes[2], 6, 5, 1, 1, true, false));
    // A word in the middle.
    common::clear_changes(changes);
    assert(diff::diff_words("foo bar baz"[..], "foo qux baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    assert(common::check_change(changes[0], 0, 4, 1, 1, false, false));
    assert(common::check_change(changes[1], 4, 3, 1, 0, false, true));
    assert(common::check_change(changes[2], 4, 3, 1, 1, true, false));
    assert(common::check_change(changes[3], 7, 4, 1, 1, false, false));
    // The white space between the words does not matter.
    common::clear_changes(changes);
    assert(diff::diff_words("a  b"[..], "a b"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 3, 2, 1, false, false));
    // The line end is a part of the white space.
    common::clear_changes(changes);
    assert(diff::diff_words("foo\nbar baz"[..], "foo baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 3, 1, 1, false, false));
    assert(common::check_change(changes[1], 3, 4, 1, 0, false, true));
    assert(common::check_change(changes[2], 3, 4, 1, 1, false, false));
    // A word with a letter outside ASCII.
    common::clear_changes(changes);
    assert(diff::diff_words("caf\xC3\xA9 noir"[..], "caf\xC3\xA9 blanc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 6, 1, 1, false, false));
    assert(common::check_change(changes[1], 6, 4, 1, 0, false, true));
    assert(common::check_change(changes[2], 6, 5, 1, 1, true, false));
}

fn test_token_words_with_space() {
    // The changes of the word search with space. The white space between
    // the words matters to the search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_words_with_space("hello world"[..], "hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 6, 2, 1, false, false));
    assert(common::check_change(changes[1], 6, 5, 1, 0, false, true));
    assert(common::check_change(changes[2], 6, 5, 1, 1, true, false));
    // The white space between the words matters.
    common::clear_changes(changes);
    assert(diff::diff_words_with_space("a  b"[..], "a b"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    assert(common::check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(common::check_change(changes[1], 1, 2, 1, 0, false, true));
    assert(common::check_change(changes[2], 1, 1, 1, 1, true, false));
    assert(common::check_change(changes[3], 2, 1, 1, 1, false, false));
    // The line end is a token of its own.
    common::clear_changes(changes);
    assert(diff::diff_words_with_space("foo\nbar baz"[..], "foo baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 3, 1, 1, false, false));
    assert(common::check_change(changes[1], 3, 4, 2, 0, false, true));
    assert(common::check_change(changes[2], 3, 4, 2, 1, false, false));
    // A word with a letter outside ASCII.
    common::clear_changes(changes);
    assert(diff::diff_words_with_space("caf\xC3\xA9 noir"[..], "caf\xC3\xA9 blanc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(common::check_change(changes[0], 0, 6, 2, 1, false, false));
    assert(common::check_change(changes[1], 6, 4, 1, 0, false, true));
    assert(common::check_change(changes[2], 6, 5, 1, 1, true, false));
}

fn test_token_word_bounds() {
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    // More words than the rule allows is a fault.
    var ob = diff::default_token_options();
    ob.max_tokens = 1;
    assert(diff::diff_words("a b"[..], "a b"[..], ob, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    assert(diff::diff_words_with_space("a b"[..], "a b"[..], ob, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    // A rule out of range is a fault.
    var ob2 = diff::default_token_options();
    ob2.max_edits = 0;
    assert(diff::diff_words("a"[..], "b"[..], ob2, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    // An empty text gives no change.
    let o2 = diff::default_token_options();
    assert(diff::diff_words(""[..], ""[..], o2, changes) == diff::ERR_OK);
    assert(changes.len == 0);
    // The move of the white space sees only the changes of this call.
    // A change of an earlier call stays as it is.
    let long = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    assert(diff::diff_words(long[..], "aaa"[..], o2, changes) == diff::ERR_OK);
    let after = changes.len;
    assert(diff::diff_words("y"[..], " x"[..], o2, changes) == diff::ERR_OK);
    assert(changes.len == after + 2);
    // A carriage return that stands alone is a part of its own.
    common::clear_changes(changes);
    assert(diff::diff_words_with_space("x\r"[..], "x\r"[..], o2, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(common::check_change(changes[0], 0, 2, 2, 1, false, false));
}
