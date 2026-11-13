// The diff engine over tokens.
//
namespace diff;

import std;

// tok_changes turns the opcodes of the search into the changes. The
// parts `sa` and `sb` are the parts that the search compares. The parts
// `ta` and `tb` are the tokens of the texts.
fn tok_changes(a: const u8[:], ta: const Span[:], sa: const Span[:],
               b: const u8[:], tb: const Span[:], sb: const Span[:],
               o: TokenOptions, longest: bool, changes: Change[>..]&) -> i64, bool {
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    if o.unicode_case {
        var fa: u8[>..] = [];
        var fb: u8[>..] = [];
        var fsa: Span[>..] = [];
        var fsb: Span[>..] = [];
        if !tok_lower(a, sa, fa, fsa) || !tok_lower(b, sb, fb, fsb) { return ERR_TOO_LARGE, false; }
        intern(fa[..], fsa[..], fb[..], fsb[..], ida, idb, Compare { fold: false, strip_cr: o.strip_trailing_cr });
    } else {
        intern(a, sa, b, sb, ida, idb, tok_compare(o));
    }
    var ops: Op[>..] = [];
    var exact = false;
    if o.algorithm == ALG_RO {
        var junk: u8[>..] = [];
        junk.resize(ro_ids(ida[..], idb[..]), 0);
        let code, minimal = ro_ops(ida[..], idb[..], junk[..], false, o.max_work, ops);
        if code != ERR_OK { return code, false; }
        exact = minimal;
    } else {
        let acode, minimal = diff_ids_alg(ida[..], idb[..], o.algorithm, o.max_edits, o.max_work, ops);
        if acode != ERR_OK { return acode, false; }
        exact = minimal;
    }
    for op in ops {
        if op.tag == OP_EQUAL {
            if longest {
                tok_longest(changes, ta, tb, op, o.one_change_per_token);
            } else {
                tok_change(changes, tb, op.b_lo, op.b_hi, 1, false, false, o.one_change_per_token);
            }
        } else if op.tag == OP_DELETE {
            tok_change(changes, ta, op.a_lo, op.a_hi, 0, false, true, o.one_change_per_token);
        } else if op.tag == OP_INSERT {
            tok_change(changes, tb, op.b_lo, op.b_hi, 1, true, false, o.one_change_per_token);
        } else {
            tok_change(changes, ta, op.a_lo, op.a_hi, 0, false, true, o.one_change_per_token);
            tok_change(changes, tb, op.b_lo, op.b_hi, 1, true, false, o.one_change_per_token);
        }
    }
    return ERR_OK, exact;
}

// tok_run runs the search over the tokens of the two texts. The parts
// that the search compares are the tokens themselves, unless the rule
// `ignore_whitespace` asks for the tokens without the white space at
// their ends. It gives a code and the minimality flag.
fn tok_run(a: const u8[:], ta: const Span[:], b: const u8[:], tb: const Span[:],
           o: TokenOptions, trim: bool, changes: Change[>..]&) -> i64, bool {
    if ta.len + tb.len > o.max_tokens { return ERR_TOO_LARGE, false; }
    if !trim {
        return tok_changes(a, ta[..], ta[..], b, tb[..], tb[..], o, false, changes);
    }
    var sa: Span[>..] = [];
    var sb: Span[>..] = [];
    tok_same(a, ta[..], true, o, sa);
    tok_same(b, tb[..], true, o, sb);
    return tok_changes(a, ta[..], sa[..], b, tb[..], sb[..], o, false, changes);
}

// diff_chars adds the changes of a against b to `changes`. The search
// compares the characters of the two texts. It gives a code and a flag.
// The flag is true when the diff is minimal.
fn diff_chars(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_chars(a, o, ta) || !tok_chars(b, o, tb) { return ERR_TOO_LARGE, false; }
    return tok_run(a, ta[..], b, tb[..], o, o.ignore_whitespace, changes);
}

// diff_lines_trimmed adds the changes of a against b to `changes`. The
// search compares the lines of the two texts. It ignores the white space
// at the ends of a line. It gives a code and a flag.
fn diff_lines_trimmed(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_lines(a, o, ta) || !tok_lines(b, o, tb) { return ERR_TOO_LARGE, false; }
    return tok_run(a, ta[..], b, tb[..], o, true, changes);
}

// diff_lines_text adds the changes of a against b to `changes`, as the
// function diffLines of jsdiff does. The rules `ignore_whitespace`,
// `ignore_newline_at_eof`, `ignore_case`, `strip_trailing_cr`,
// `newline_is_token` and `one_change_per_token` apply. It gives a code
// and a flag.
fn diff_lines_text(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_lines(a, o, ta) || !tok_lines(b, o, tb) { return ERR_TOO_LARGE, false; }
    if o.ignore_whitespace || !o.ignore_newline_at_eof || o.newline_is_token {
        return tok_run(a, ta[..], b, tb[..], o, o.ignore_whitespace, changes);
    }
    if ta.len + tb.len > o.max_tokens { return ERR_TOO_LARGE, false; }
    var sa: Span[>..] = [];
    var sb: Span[>..] = [];
    for s in ta {
        if s.len > 0 && a[s.at + s.len - 1] == 10 { sa.push(Span { at: s.at, len: s.len - 1 }); } else { sa.push(s); }
    }
    for s in tb {
        if s.len > 0 && b[s.at + s.len - 1] == 10 { sb.push(Span { at: s.at, len: s.len - 1 }); } else { sb.push(s); }
    }
    return tok_changes(a, ta[..], sa[..], b, tb[..], sb[..], o, false, changes);
}

// diff_sentences adds the changes of a against b to `changes`. The search
// compares the sentences of the two texts. It gives a code and a flag.
fn diff_sentences(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_sentences(a, o, ta) || !tok_sentences(b, o, tb) { return ERR_TOO_LARGE, false; }
    return tok_run(a, ta[..], b, tb[..], o, o.ignore_whitespace, changes);
}

// diff_unicode_words adds the changes of the Unicode words of a against
// b to `changes`, as `from_unicode_words` of the Rust crate `similar`
// does. Every segment is a token, and the white space is a token too.
fn diff_unicode_words(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    return diff_segments(a, b, false, o, changes);
}

// diff_graphemes adds the changes of the grapheme clusters of a against
// b to `changes`, as `from_graphemes` of `similar` does.
fn diff_graphemes(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    return diff_segments(a, b, true, o, changes);
}

fn diff_segments(a: const u8[:], b: const u8[:], graphemes: bool, o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_segments(a, graphemes, o, ta) || !tok_segments(b, graphemes, o, tb) { return ERR_TOO_LARGE, false; }
    return tok_run(a, ta[..], b, tb[..], o, o.ignore_whitespace, changes);
}
