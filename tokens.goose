// The token searches.
//
// The Node library diff (jsdiff) compares texts by tokens. The package
// holds the same searches: the characters, the trimmed lines, the
// sentences and the tokens that the caller gives.
//
// Every search splits the two texts into tokens, gives an id to every
// token, and runs the search of the package over the two lists of ids.
// The opcodes of the search give the changes.
namespace diff;

import std;

// Change is one part of the change between two texts. It holds the place
// of its text in the text it comes from, the count of its bytes, the
// count of its tokens, and the flags of the change.
struct Change {
    at: i64,
    len: i64,
    count: i64,
    // The text of the change: 0 for the first text, 1 for the second.
    text: i64,
    added: bool,
    removed: bool,
}

// TokenOptions holds the rules of a token search.
struct TokenOptions {
    // The most edits that the search takes.
    max_edits: i64,
    // The most bytes of one input.
    max_input: i64,
    // The search of the diff: ALG_MYERS or ALG_RO.
    algorithm: i64,
    // The most compares that the search spends.
    max_work: i64,
    // The case of the tokens does not matter.
    ignore_case: bool,
    // The white space at the ends of a token does not matter.
    ignore_whitespace: bool,
    // The carriage return before a line feed does not matter.
    strip_trailing_cr: bool,
    // The line end is a token of its own.
    newline_is_token: bool,
    // The most tokens of the two texts. Past it, the call is a fault.
    max_tokens: i64,
}

// default_token_options gives 2000 edits, 16 MiB of input and no switch.
fn default_token_options() -> TokenOptions {
    return TokenOptions { max_edits: 2000, max_input: 16777216, algorithm: ALG_MYERS,
                          max_work: 50000000, ignore_case: false, ignore_whitespace: false,
                          strip_trailing_cr: false, newline_is_token: false, max_tokens: 2000000 };
}

// token_options_ok tells whether the rules are in range.
fn token_options_ok(o: TokenOptions) -> bool {
    return search_ok(o.max_edits, o.max_input, o.algorithm, o.max_work, o.max_tokens);
}

// tok_compare gives the rules of the comparison of the tokens. The case
// and the carriage return matter there.
fn tok_compare(o: TokenOptions) -> Compare {
    return Compare { fold: o.ignore_case, strip_cr: o.strip_trailing_cr };
}

// tok_width gives the count of the bytes of the code point that starts
// at the place. A byte that starts no code point gives one. The bytes
// after the lead byte must be the continuation bytes of the code point,
// or the lead byte starts no code point.
fn tok_width(text: const u8[:], at: i64) -> i64 {
    let c = text[at];
    if c < 0x80 { return 1; }
    var w: i64 = 0;
    if c >= 0xC2 && c <= 0xDF { w = 2; }
    else if c >= 0xE0 && c <= 0xEF { w = 3; }
    else if c >= 0xF0 && c <= 0xF4 { w = 4; }
    else { return 1; }
    if at + w > text.len { return 1; }
    var k: i64 = 1;
    while k < w {
        let b = text[at + k];
        if b < 0x80 || b > 0xBF { return 1; }
        k = k + 1;
    }
    return w;
}

// tok_code gives the code point of the bytes at the place.
fn tok_code(text: const u8[:], at: i64, len: i64) -> i64 {
    let c = text[at] as i64;
    if len == 1 { return c; }
    if len == 2 { return ((c & 0x1F) << 6) | ((text[at + 1] as i64) & 0x3F); }
    if len == 3 {
        return ((c & 0x0F) << 12) | (((text[at + 1] as i64) & 0x3F) << 6) |
               ((text[at + 2] as i64) & 0x3F);
    }
    return ((c & 0x07) << 18) | (((text[at + 1] as i64) & 0x3F) << 12) |
           (((text[at + 2] as i64) & 0x3F) << 6) | ((text[at + 3] as i64) & 0x3F);
}

// tok_space tells whether the code point is white space. The set is the
// set of the JavaScript library.
fn tok_space(code: i64) -> bool {
    if code == 9 || code == 10 || code == 11 || code == 12 || code == 13 || code == 32 { return true; }
    if code == 160 || code == 5760 || code == 8232 || code == 8233 || code == 8239 { return true; }
    if code == 8287 || code == 12288 || code == 65279 { return true; }
    if code >= 8192 && code <= 8202 { return true; }
    return false;
}

// tok_code_space tells whether the bytes at the place are white space.
fn tok_code_space(text: const u8[:], at: i64) -> bool {
    let w = tok_width(text, at);
    var end = at + w;
    if end > text.len { end = text.len; }
    return tok_space(tok_code(text, at, end - at));
}

// tok_lead gives the place of the lead byte of the code point that ends
// at the place.
fn tok_lead(text: const u8[:], at: i64, from: i64) -> i64 {
    var p = at;
    while p > from && (text[p] & 0xC0) == 0x80 { p = p - 1; }
    return p;
}

// tok_trim gives the place and the count of the bytes of a text with the
// white space at its ends removed.
fn tok_trim(text: const u8[:], s: Span) -> Span {
    var from = s.at;
    var end = s.at + s.len;
    while from < end && tok_code_space(text, from) { from = from + tok_width(text, from); }
    while end > from {
        let p = tok_lead(text, end - 1, from);
        if !tok_code_space(text, p) { break; }
        end = p;
    }
    return Span { at: from, len: end - from };
}

// tok_chars gives the code points of the text. Every code point is one
// token. The rule `strip_trailing_cr` drops the carriage return that
// stands before a line feed.
fn tok_chars(text: const u8[:], o: TokenOptions, out: Span[>..]&) -> bool {
    var i: i64 = 0;
    while i < text.len {
        let w = tok_width(text, i);
        var end = i + w;
        if end > text.len { end = text.len; }
        if o.strip_trailing_cr && text[i] == 13 && end < text.len && text[end] == 10 {
            i = end;
            continue;
        }
        if out.len >= o.max_tokens { return false; }
        out.push(Span { at: i, len: end - i });
        i = end;
    }
    return true;
}

// tok_lines gives the lines of the text. Every line holds its line end,
// unless the rule `newline_is_token` gives the line end a token of its
// own.
fn tok_lines(text: const u8[:], o: TokenOptions, out: Span[>..]&) -> bool {
    var start: i64 = 0;
    var i: i64 = 0;
    while i < text.len {
        if text[i] == 10 {
            if o.newline_is_token {
                if out.len + 2 > o.max_tokens { return false; }
                out.push(Span { at: start, len: i - start });
                out.push(Span { at: i, len: 1 });
            } else {
                if out.len >= o.max_tokens { return false; }
                out.push(Span { at: start, len: i + 1 - start });
            }
            start = i + 1;
        }
        i = i + 1;
    }
    if start < text.len {
        if out.len >= o.max_tokens { return false; }
        out.push(Span { at: start, len: text.len - start });
    }
    return true;
}

// tok_sentences gives the sentences of the text. A sentence ends at a
// point, a mark or a question mark. The white space after the end is a
// token of its own.
fn tok_sentences(text: const u8[:], o: TokenOptions, out: Span[>..]&) -> bool {
    var start: i64 = 0;
    var i: i64 = 0;
    while i < text.len {
        if i == text.len - 1 {
            if out.len >= o.max_tokens { return false; }
            out.push(Span { at: start, len: text.len - start });
            break;
        }
        let c = text[i];
        if (c == '.' || c == '!' || c == '?') && tok_code_space(text, i + 1) {
            if out.len + 2 > o.max_tokens { return false; }
            out.push(Span { at: start, len: i + 1 - start });
            var j = i + 1;
            while j < text.len && tok_code_space(text, j) { j = j + tok_width(text, j); }
            out.push(Span { at: i + 1, len: j - i - 1 });
            start = j;
            i = j;
        } else {
            i = i + 1;
        }
    }
    return true;
}

// tok_trim_line gives the token of the text without the white space at
// its ends. A token that holds a line end keeps it, when the rule
// `newline_is_token` gives the line end a token of its own.
fn tok_trim_line(text: const u8[:], s: Span, o: TokenOptions) -> Span {
    if o.newline_is_token {
        var k = s.at;
        while k < s.at + s.len {
            if text[k] == 10 { return s; }
            k = k + 1;
        }
    }
    return tok_trim(text, s);
}

// tok_same gives the parts that the search compares. They are the tokens
// themselves, unless the rule asks for the tokens without the white
// space at their ends.
fn tok_same(text: const u8[:], toks: const Span[:], trim: bool, o: TokenOptions,
            out: Span[>..]&) {
    for t in toks {
        if trim {
            out.push(tok_trim_line(text, t, o));
        } else {
            out.push(t);
        }
    }
}

// tok_change adds one change to the list. The change holds the place of
// its text in the text it comes from.
fn tok_change(changes: Change[>..]&, toks: const Span[:], from: i64, to: i64,
              text: i64, added: bool, removed: bool) {
    if from >= to { return; }
    let first = toks[from];
    let last = toks[to - 1];
    changes.push(Change { at: first.at, len: last.at + last.len - first.at,
                          count: to - from, text: text, added: added, removed: removed });
}

// tok_changes turns the opcodes of the search into the changes. The
// parts `sa` and `sb` are the parts that the search compares. The parts
// `ta` and `tb` are the tokens of the texts.
fn tok_changes(a: const u8[:], ta: const Span[:], sa: const Span[:],
               b: const u8[:], tb: const Span[:], sb: const Span[:],
               o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    intern(a, sa, b, sb, ida, idb, tok_compare(o));
    var ops: Op[>..] = [];
    var exact = false;
    if o.algorithm == ALG_RO {
        var junk: u8[>..] = [];
        junk.resize(ro_ids(ida[..], idb[..]), 0);
        let code, minimal = ro_ops(ida[..], idb[..], junk[..], false, o.max_work, ops);
        if code != ERR_OK { return code, false; }
        exact = minimal;
    } else {
        exact = diff_ids(ida[..], idb[..], o.max_edits, o.max_work, ops);
    }
    for op in ops {
        if op.tag == OP_EQUAL {
            tok_change(changes, tb, op.b_lo, op.b_hi, 1, false, false);
        } else if op.tag == OP_DELETE {
            tok_change(changes, ta, op.a_lo, op.a_hi, 0, false, true);
        } else if op.tag == OP_INSERT {
            tok_change(changes, tb, op.b_lo, op.b_hi, 1, true, false);
        } else {
            tok_change(changes, ta, op.a_lo, op.a_hi, 0, false, true);
            tok_change(changes, tb, op.b_lo, op.b_hi, 1, true, false);
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
        return tok_changes(a, ta[..], ta[..], b, tb[..], tb[..], o, changes);
    }
    var sa: Span[>..] = [];
    var sb: Span[>..] = [];
    tok_same(a, ta[..], true, o, sa);
    tok_same(b, tb[..], true, o, sb);
    return tok_changes(a, ta[..], sa[..], b, tb[..], sb[..], o, changes);
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

// tok_span_ok tells whether a span of a token stands inside its text.
fn tok_span_ok(text: const u8[:], s: Span) -> bool {
    if s.at < 0 || s.len < 0 { return false; }
    if s.at > text.len - s.len { return false; }
    return true;
}

// diff_arrays adds the changes of the two lists of tokens to `changes`.
// The tokens stand in the two texts. The places of the tokens go in the
// two lists. It gives a code and a flag.
fn diff_arrays(a: const u8[:], b: const u8[:], ta: const Span[:], tb: const Span[:],
               o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    for t in ta {
        if !tok_span_ok(a, t) { return ERR_BAD_OPTION, false; }
    }
    for t in tb {
        if !tok_span_ok(b, t) { return ERR_BAD_OPTION, false; }
    }
    return tok_run(a, ta, b, tb, o, o.ignore_whitespace, changes);
}
