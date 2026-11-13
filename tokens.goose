// The token searches of the package.
//
namespace diff;

import std;

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
    // The search of the diff: ALG_MYERS, ALG_RO, ALG_PATIENCE, ALG_LCS or ALG_MYERS_SPLIT.
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
    // The line end at the end of a line does not matter. It acts in
    // `diff_lines_text` when no other white space rule is set.
    ignore_newline_at_eof: bool,
    // Every token is a change of its own. A run of equal tokens does not
    // join, and the word search does not move white space.
    one_change_per_token: bool,
    // Compare the tokens with the full Unicode lower case mapping, as
    // `toLowerCase` of jsdiff does. It replaces `ignore_case`, which
    // folds the Latin letters of ASCII only.
    unicode_case: bool,
    // Split the words of `diff_words` at the word bounds of Unicode, as
    // the option `intlSegmenter` of jsdiff does.
    unicode_words: bool,
}

// default_token_options gives 2000 edits, 16 MiB of input and no switch.
fn default_token_options() -> TokenOptions {
    return TokenOptions { max_edits: 2000, max_input: 16777216, algorithm: ALG_MYERS,
                          max_work: 50000000, ignore_case: false, ignore_whitespace: false,
                          strip_trailing_cr: false, newline_is_token: false, max_tokens: 2000000,
                          ignore_newline_at_eof: false, one_change_per_token: false,
                          unicode_case: false, unicode_words: false };
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
              text: i64, added: bool, removed: bool, one: bool) {
    if from >= to { return; }
    if one {
        for k in from..to {
            changes.push(Change { at: toks[k].at, len: toks[k].len, count: 1, text: text,
                                  added: added, removed: removed });
        }
        return;
    }
    let first = toks[from];
    let last = toks[to - 1];
    changes.push(Change { at: first.at, len: last.at + last.len - first.at,
                          count: to - from, text: text, added: added, removed: removed });
}

// tok_longest adds the changes of one run of equal tokens. Each pair of
// equal tokens keeps the longer token of the two. A run that takes its
// tokens from one text is one change.
fn tok_longest(changes: Change[>..]&, ta: const Span[:], tb: const Span[:], op: Op, one: bool) {
    var run_from: i64 = op.b_lo;
    var run_text: i64 = -1;
    for j in op.b_lo..op.b_hi {
        let i = op.a_lo + (j - op.b_lo);
        var side: i64 = 1;
        if ta[i].len > tb[j].len { side = 0; }
        if run_text >= 0 && (side != run_text || one) {
            tok_run_change(changes, ta, tb, op, run_from, j, run_text, one);
            run_from = j;
        }
        run_text = side;
    }
    if run_text >= 0 { tok_run_change(changes, ta, tb, op, run_from, op.b_hi, run_text, one); }
}

// tok_run_change adds one change for the equal tokens from..to of the
// second text. The text 0 takes the tokens of the first text.
fn tok_run_change(changes: Change[>..]&, ta: const Span[:], tb: const Span[:], op: Op,
                  from: i64, to: i64, text: i64, one: bool) {
    if text == 1 {
        tok_change(changes, tb, from, to, 1, false, false, one);
    } else {
        let shift = op.a_lo - op.b_lo;
        tok_change(changes, ta, from + shift, to + shift, 0, false, false, one);
    }
}

// tok_lower appends the full lower case form of every part to `out`,
// and the place of each form into `spans`. It gives false when a part is
// too long for the Unicode package.
fn tok_lower(text: const u8[:], parts: const Span[:], out: u8[>..]&, spans: Span[>..]&) -> bool {
    for p in parts {
        var one: u8[>..] = [];
        let code, pos = unicode::to_lower_full(one, text[p.at..p.at + p.len]);
        if code != 0 { return false; }
        spans.push(Span { at: out.len, len: one.len });
        for ch in one { out.push(ch); }
    }
    return true;
}

// The most bytes that one call of the Unicode package takes.
const UNI_CAP: i64 = 1048576;

fn tok_ascii_alnum(c: u8) -> bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9');
}

// tok_cut gives the end of the next chunk of the text that starts at
// `from`, and a flag. The flag is true when the cut stands inside a run
// of ASCII letters and digits, so the words on both sides join. The cut
// stands after a line feed, or after a space that a letter or a digit
// follows. Every rule of UAX 29 gives a break there. It gives -1 when no
// cut exists.
fn tok_cut(text: const u8[:], from: i64) -> i64, bool {
    var to = from + UNI_CAP;
    if to >= text.len { return text.len, false; }
    var p = to;
    while p > from {
        if text[p - 1] == 10 { return p, false; }
        p = p - 1;
    }
    p = to;
    while p > from {
        if text[p - 1] == 32 && tok_ascii_alnum(text[p]) { return p, false; }
        p = p - 1;
    }
    p = to;
    while p > from {
        if tok_ascii_alnum(text[p - 1]) && tok_ascii_alnum(text[p]) { return p, true; }
        p = p - 1;
    }
    return -1, false;
}

// tok_segments gives the segments of the text at the word bounds of
// Unicode, or at the cluster bounds when `graphemes` is true. The Unicode
// package takes at most 1 MiB, so the text splits into chunks at places
// where the rules give a break. It gives false when no such place exists
// in a chunk, or when the Unicode package refuses.
fn tok_segments(text: const u8[:], graphemes: bool, o: TokenOptions, out: Span[>..]&) -> bool {
    var from: i64 = 0;
    var join = false;
    var seam = false;
    while from < text.len {
        if seam {
            // The last cut stood inside one token. A short window around
            // the cut tells whether the rules give a break there.
            join = !tok_break_at(text, from, graphemes);
            seam = false;
        }
        var to, inside = tok_cut(text, from);
        var offs: i64[>..] = [];
        var code: i64 = 0;
        var window = to;
        if to < 0 {
            window = from + UNI_CAP;
            while window > from && window < text.len && (text[window] & 192) == 128 { window = window - 1; }
        }
        if graphemes { code = unicode::grapheme_offsets(offs, text[from..window]); } else { code = unicode::word_offsets(offs, text[from..window]); }
        if code != 0 { return false; }
        if to < 0 {
            if offs.len < 3 {
                // One token fills the window: cut here and test the seam.
                to = window;
                seam = true;
            } else {
                // The last two segments may need more text.
                to = from + offs[offs.len - 2];
                offs.resize(offs.len - 2, 0);
            }
            inside = false;
        }
        if out.len + offs.len > o.max_tokens { return false; }
        for k in offs.len {
            var end = to - from;
            if k + 1 < offs.len { end = offs[k + 1]; }
            if k == 0 && join && out.len > 0 {
                out[out.len - 1] = Span { at: out[out.len - 1].at, len: from + end - out[out.len - 1].at };
            } else {
                out.push(Span { at: from + offs[k], len: end - offs[k] });
            }
        }
        join = inside && !graphemes;
        from = to;
    }
    return true;
}

// tok_break_at tells whether the rules of Unicode give a break at the
// place `at`. It segments a window of 64 bytes on each side of the place.
fn tok_break_at(text: const u8[:], at: i64, graphemes: bool) -> bool {
    var lo = at - 64;
    if lo < 0 { lo = 0; }
    while lo < at && (text[lo] & 192) == 128 { lo = lo + 1; }
    var hi = at + 64;
    if hi > text.len { hi = text.len; }
    while hi > at && hi < text.len && (text[hi] & 192) == 128 { hi = hi - 1; }
    var offs: i64[>..] = [];
    var code: i64 = 0;
    if graphemes { code = unicode::grapheme_offsets(offs, text[lo..hi]); } else { code = unicode::word_offsets(offs, text[lo..hi]); }
    if code != 0 { return true; }
    for k in offs.len { if lo + offs[k] == at { return true; } }
    return false;
}

// tok_segment_parts gives the parts of the word search from the word
// bounds of Unicode. The segments of white space that touch merge into
// one part, as `segment` of jsdiff does.
fn tok_segment_parts(text: const u8[:], o: TokenOptions, out: Span[>..]&) -> bool {
    var segs: Span[>..] = [];
    if !tok_segments(text, false, o, segs) { return false; }
    for s in segs {
        if out.len > 0 && tok_code_space(text, out[out.len - 1].at) && tok_code_space(text, s.at) {
            let last = out[out.len - 1];
            out[out.len - 1] = Span { at: last.at, len: s.at + s.len - last.at };
        } else {
            out.push(s);
        }
    }
    return true;
}
