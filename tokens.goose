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
    // The search of the diff: ALG_MYERS, ALG_RO, ALG_PATIENCE or ALG_LCS.
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

// tok_longest adds the changes of one run of equal tokens. Each pair of
// equal tokens keeps the longer token of the two. A run that takes its
// tokens from one text is one change.
fn tok_longest(changes: Change[>..]&, ta: const Span[:], tb: const Span[:], op: Op) {
    var run_from: i64 = op.b_lo;
    var run_text: i64 = -1;
    for j in op.b_lo..op.b_hi {
        let i = op.a_lo + (j - op.b_lo);
        var side: i64 = 1;
        if ta[i].len > tb[j].len { side = 0; }
        if run_text >= 0 && side != run_text {
            tok_run_change(changes, ta, tb, op, run_from, j, run_text);
            run_from = j;
        }
        run_text = side;
    }
    if run_text >= 0 { tok_run_change(changes, ta, tb, op, run_from, op.b_hi, run_text); }
}

// tok_run_change adds one change for the equal tokens from..to of the
// second text. The text 0 takes the tokens of the first text.
fn tok_run_change(changes: Change[>..]&, ta: const Span[:], tb: const Span[:], op: Op,
                  from: i64, to: i64, text: i64) {
    if text == 1 {
        tok_change(changes, tb, from, to, 1, false, false);
    } else {
        let shift = op.a_lo - op.b_lo;
        tok_change(changes, ta, from + shift, to + shift, 0, false, false);
    }
}

// tok_changes turns the opcodes of the search into the changes. The
// parts `sa` and `sb` are the parts that the search compares. The parts
// `ta` and `tb` are the tokens of the texts.
fn tok_changes(a: const u8[:], ta: const Span[:], sa: const Span[:],
               b: const u8[:], tb: const Span[:], sb: const Span[:],
               o: TokenOptions, longest: bool, changes: Change[>..]&) -> i64, bool {
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
        let acode, minimal = diff_ids_alg(ida[..], idb[..], o.algorithm, o.max_edits, o.max_work, ops);
        if acode != ERR_OK { return acode, false; }
        exact = minimal;
    }
    for op in ops {
        if op.tag == OP_EQUAL {
            if longest {
                tok_longest(changes, ta, tb, op);
            } else {
                tok_change(changes, tb, op.b_lo, op.b_hi, 1, false, false);
            }
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


// tok_word tells whether the code point is a word character. The table
// follows the Latin script in Unicode that jsdiff uses.
fn tok_word(code: i64) -> bool {
    // The Latin letters, the digits and the mark of the underline.
    if code >= 'a' && code <= 'z' { return true; }
    if code >= 'A' && code <= 'Z' { return true; }
    if code >= '0' && code <= '9' { return true; }
    if code == 95 { return true; }
    // The soft hyphen.
    if code == 0xAD { return true; }
    // The Latin-1 Supplement, without the multiplication sign and the
    // division sign.
    if code >= 0xC0 && code <= 0xD6 { return true; }
    if code >= 0xD8 && code <= 0xF6 { return true; }
    if code >= 0xF8 && code <= 0x2C6 { return true; }
    // The spacing modifier letters, without the caron, the breve, the
    // dot above, the ring above, the ogonek, the small tilde and the
    // double acute accent.
    if code >= 0x2C8 && code <= 0x2D7 { return true; }
    if code >= 0x2DE && code <= 0x2FF { return true; }
    // The Latin Extended Additional.
    if code >= 0x1E00 && code <= 0x1EFF { return true; }
    return false;
}

// tok_parts gives the parts of a word tokenizer. A part is a run of the
// word characters, a run of white space, or one other character.
//
// The rule `nl_own` gives the line end a part of its own. The carriage
// return and the line feed then stand in one part. A carriage return
// alone is a part of its own. The runs of white space hold no line end.
fn tok_parts(text: const u8[:], o: TokenOptions, nl_own: bool, out: Span[>..]&) -> bool {
    var i: i64 = 0;
    while i < text.len {
        if out.len >= o.max_tokens { return false; }
        if nl_own && text[i] == 13 && i + 1 < text.len && text[i + 1] == 10 {
            out.push(Span { at: i, len: 2 });
            i = i + 2;
            continue;
        }
        if nl_own && text[i] == 10 {
            out.push(Span { at: i, len: 1 });
            i = i + 1;
            continue;
        }
        if nl_own && text[i] == 13 {
            // A carriage return that stands alone is a part of its own.
            out.push(Span { at: i, len: 1 });
            i = i + 1;
            continue;
        }
        if tok_code_space(text, i) {
            var j = i;
            while j < text.len {
                if nl_own && (text[j] == 10 || text[j] == 13) { break; }
                if !tok_code_space(text, j) { break; }
                j = j + tok_width(text, j);
            }
            out.push(Span { at: i, len: j - i });
            i = j;
            continue;
        }
        let w = tok_width(text, i);
        var end = i + w;
        if end > text.len { end = text.len; }
        if tok_word(tok_code(text, i, end - i)) {
            var j = i;
            while j < text.len {
                let w2 = tok_width(text, j);
                var e2 = j + w2;
                if e2 > text.len { e2 = text.len; }
                if !tok_word(tok_code(text, j, e2 - j)) { break; }
                j = e2;
            }
            out.push(Span { at: i, len: j - i });
            i = j;
            continue;
        }
        out.push(Span { at: i, len: end - i });
        i = end;
    }
    return true;
}

// tok_stitch joins the parts into the tokens of the word search. A run
// of white space joins the token before it. A word after a lone run of
// white space joins that run. The tokens then hold the white space
// twice, as the tokens of the Node library do.
fn tok_stitch(text: const u8[:], parts: const Span[:], tokens: Span[>..]&) {
    var has_prev = false;
    var prev_ws = false;
    var prev = Span { at: 0, len: 0 };
    for p in parts {
        let ws = tok_code_space(text, p.at);
        if ws {
            if !has_prev {
                tokens.push(p);
            } else {
                let last = tokens[tokens.len - 1];
                tokens[tokens.len - 1] = Span { at: last.at, len: p.at + p.len - last.at };
            }
        } else if has_prev && prev_ws {
            let last = tokens[tokens.len - 1];
            if last.at == prev.at && last.len == prev.len {
                tokens[tokens.len - 1] = Span { at: last.at, len: p.at + p.len - last.at };
            } else {
                tokens.push(Span { at: prev.at, len: p.at + p.len - prev.at });
            }
        } else {
            tokens.push(p);
        }
        has_prev = true;
        prev_ws = ws;
        prev = p;
    }
}

// ws_lead gives the count of the bytes of the white space at the start
// of a change value.
fn ws_lead(text: const u8[:], s: Span) -> i64 {
    var k = s.at;
    let end = s.at + s.len;
    while k < end && tok_code_space(text, k) { k = k + tok_width(text, k); }
    return k - s.at;
}

// ws_tail gives the count of the bytes of the white space at the end of
// a change value.
fn ws_tail(text: const u8[:], s: Span) -> i64 {
    var e = s.at + s.len;
    while e > s.at {
        let p = tok_lead(text, e - 1, s.at);
        if !tok_code_space(text, p) { break; }
        e = p;
    }
    return s.at + s.len - e;
}

// ws_prefix gives the count of the bytes of the longest common prefix of
// two runs of white space. The runs may stand in two texts.
fn ws_prefix(ta: const u8[:], sa: Span, tb: const u8[:], sb: Span) -> i64 {
    var i = sa.at;
    var j = sb.at;
    var n: i64 = 0;
    while i < sa.at + sa.len && j < sb.at + sb.len {
        let wa = tok_width(ta, i);
        let wb = tok_width(tb, j);
        if wa != wb { break; }
        var same = true;
        var k: i64 = 0;
        while k < wa {
            if ta[i + k] != tb[j + k] { same = false; break; }
            k = k + 1;
        }
        if !same { break; }
        i = i + wa;
        j = j + wb;
        n = n + wa;
    }
    return n;
}

// ws_suffix gives the count of the bytes of the longest common suffix of
// two runs of white space. The runs may stand in two texts.
fn ws_suffix(ta: const u8[:], sa: Span, tb: const u8[:], sb: Span) -> i64 {
    var i = sa.at + sa.len;
    var j = sb.at + sb.len;
    var n: i64 = 0;
    while i > sa.at && j > sb.at {
        let p = tok_lead(ta, i - 1, sa.at);
        let q = tok_lead(tb, j - 1, sb.at);
        let wa = i - p;
        if wa != j - q { break; }
        var same = true;
        var k: i64 = 0;
        while k < wa {
            if ta[p + k] != tb[q + k] { same = false; break; }
            k = k + 1;
        }
        if !same { break; }
        i = p;
        j = q;
        n = n + wa;
    }
    return n;
}

// ws_count gives the count of the code points of a run of white space.
fn ws_count(text: const u8[:], s: Span) -> i64 {
    var n: i64 = 0;
    var i = s.at;
    while i < s.at + s.len {
        i = i + tok_width(text, i);
        n = n + 1;
    }
    return n;
}

// ws_val gives the code point of one part of a run of white space. The
// parts stand in the text at the places of the table.
fn ws_val(text: const u8[:], s: Span, off: const i32[:], j: i64) -> i64 {
    let at = s.at + off[j];
    let w = tok_width(text, at);
    return tok_code(text, at, w);
}

// ws_overlap gives the count of the bytes of the longest prefix of the
// second run that is a suffix of the first run. The runs hold only white
// space, so the search walks their code points. The table holds the
// places of the parts of one run only, and the parts past the shorter
// run take no place in it.
fn ws_overlap(ta: const u8[:], sa: Span, tb: const u8[:], sb: Span) -> i64 {
    let na = ws_count(ta, sa);
    let nb = ws_count(tb, sb);
    var w = na;
    if nb < w { w = nb; }
    if w == 0 { return 0; }
    // The places of the parts of the second run.
    var off: i32[>..] = [];
    off.resize(w, 0);
    var p = sb.at;
    var j: i64 = 0;
    while j < w {
        off[j] = (p - sb.at) as i32;
        p = p + tok_width(tb, p);
        j = j + 1;
    }
    // The table of the search.
    var map: i32[>..] = [];
    map.resize(w, 0);
    var k: i64 = 0;
    j = 1;
    while j < w {
        if ws_val(tb, sb, off[..], j) == ws_val(tb, sb, off[..], k) {
            map[j] = map[k];
        } else {
            map[j] = k as i32;
        }
        while k > 0 && ws_val(tb, sb, off[..], j) != ws_val(tb, sb, off[..], k) {
            k = map[k];
        }
        if ws_val(tb, sb, off[..], j) == ws_val(tb, sb, off[..], k) { k = k + 1; }
        j = j + 1;
    }
    // The walk over the parts of the first run starts at the part that
    // leaves w parts to the end.
    var i: i64 = 0;
    var skip = na - w;
    p = sa.at;
    while i < skip {
        p = p + tok_width(ta, p);
        i = i + 1;
    }
    k = 0;
    i = 0;
    while i < w {
        while k > 0 && tok_code(ta, p, tok_width(ta, p)) != ws_val(tb, sb, off[..], k) {
            k = map[k];
        }
        if tok_code(ta, p, tok_width(ta, p)) == ws_val(tb, sb, off[..], k) { k = k + 1; }
        p = p + tok_width(ta, p);
        i = i + 1;
    }
    // The count of the parts goes back to a count of bytes.
    var n: i64 = 0;
    var u: i64 = 0;
    var q = sb.at;
    while u < k {
        let wd = tok_width(tb, q);
        q = q + wd;
        n = n + wd;
        u = u + 1;
    }
    return n;
}

// tok_ends_with tells whether the value of a change ends with a run of
// bytes.
fn tok_ends_with(text: const u8[:], s: Span, tail: const u8[:], t: Span) -> bool {
    if t.len == 0 { return true; }
    if s.len < t.len { return false; }
    let from = s.at + s.len - t.len;
    var k: i64 = 0;
    while k < t.len {
        if text[from + k] != tail[t.at + k] { return false; }
        k = k + 1;
    }
    return true;
}

// tok_starts_with tells whether the value of a change starts with a run
// of bytes.
fn tok_starts_with(text: const u8[:], s: Span, head: const u8[:], t: Span) -> bool {
    if t.len == 0 { return true; }
    if s.len < t.len { return false; }
    var k: i64 = 0;
    while k < t.len {
        if text[s.at + k] != head[t.at + k] { return false; }
        k = k + 1;
    }
    return true;
}

// tok_cut moves the start of a change forward and its end back. The
// value of `front` moves the start. The value of `back` cuts the end.
fn tok_cut(changes: Change[>..]&, k: i64, front: i64, back: i64) {
    var m = changes[k];
    m.at = m.at + front;
    m.len = m.len - front - back;
    changes[k] = m;
}

// tok_dedupe_one moves the white space between the changes of one group.
// The change holds a place and a count of bytes, so the move changes the
// place or the count. A value of -1 says that the change is not there.
//
// A move that does not fit the change is left out. The Node library
// raises an error in that case. The package keeps the change as it was.
fn tok_dedupe_one(changes: Change[>..]&, a: const u8[:], b: const u8[:],
                  keep0: i64, del: i64, ins: i64, keep1: i64) {
    if del >= 0 && ins >= 0 {
        let ds = Span { at: changes[del].at, len: changes[del].len };
        let is = Span { at: changes[ins].at, len: changes[ins].len };
        let old_pre = ws_lead(a, ds);
        let old_suf = ws_tail(a, ds);
        let new_pre = ws_lead(b, is);
        let new_suf = ws_tail(b, is);
        let ins_pre = Span { at: is.at, len: new_pre };
        let ins_suf = Span { at: is.at + is.len - new_suf, len: new_suf };
        if keep0 >= 0 {
            let ks = Span { at: changes[keep0].at, len: changes[keep0].len };
            let common = ws_prefix(a, Span { at: ds.at, len: old_pre },
                                   b, Span { at: is.at, len: new_pre });
            if tok_ends_with(b, ks, b, ins_pre) && changes[keep0].len >= new_pre - common &&
               changes[del].len >= common && changes[ins].len >= common {
                changes[keep0].len = changes[keep0].len - (new_pre - common);
                tok_cut(changes, del, common, 0);
                tok_cut(changes, ins, common, 0);
            }
        }
        if keep1 >= 0 {
            let ks = Span { at: changes[keep1].at, len: changes[keep1].len };
            let common = ws_suffix(a, Span { at: ds.at + ds.len - old_suf, len: old_suf },
                                   b, Span { at: is.at + is.len - new_suf, len: new_suf });
            if tok_starts_with(b, ks, b, ins_suf) && changes[keep1].len >= new_suf - common &&
               changes[del].len >= common && changes[ins].len >= common {
                tok_cut(changes, keep1, new_suf - common, 0);
                tok_cut(changes, del, 0, common);
                tok_cut(changes, ins, 0, common);
            }
        }
    } else if ins >= 0 {
        if keep0 >= 0 {
            let ws = ws_lead(b, Span { at: changes[ins].at, len: changes[ins].len });
            tok_cut(changes, ins, ws, 0);
        }
        if keep1 >= 0 {
            let ws = ws_lead(b, Span { at: changes[keep1].at, len: changes[keep1].len });
            tok_cut(changes, keep1, ws, 0);
        }
    } else if keep0 >= 0 && keep1 >= 0 {
        let ds = Span { at: changes[del].at, len: changes[del].len };
        let ek = Span { at: changes[keep1].at, len: changes[keep1].len };
        let new_ws_full = ws_lead(b, ek);
        let del_ws_start = ws_lead(a, ds);
        let del_ws_end = ws_tail(a, ds);
        let new_ws_start = ws_prefix(a, Span { at: ds.at, len: del_ws_start },
                                     b, Span { at: ek.at, len: new_ws_full });
        let rest = Span { at: ek.at + new_ws_start, len: new_ws_full - new_ws_start };
        let del_end = Span { at: ds.at + ds.len - del_ws_end, len: del_ws_end };
        let new_ws_end = ws_suffix(a, del_end, b, rest);
        if changes[del].len >= new_ws_start + new_ws_end &&
           changes[keep1].len >= new_ws_full - new_ws_end &&
           changes[keep0].len >= new_ws_end {
            tok_cut(changes, del, new_ws_start, new_ws_end);
            tok_cut(changes, keep1, new_ws_full - new_ws_end, 0);
            changes[keep0].len = changes[keep0].len - new_ws_end;
        }
    } else if keep1 >= 0 {
        let ds = Span { at: changes[del].at, len: changes[del].len };
        let ek = Span { at: changes[keep1].at, len: changes[keep1].len };
        let ek_pre = ws_lead(b, ek);
        let del_suf = ws_tail(a, ds);
        let k = ws_overlap(a, Span { at: ds.at + ds.len - del_suf, len: del_suf },
                           b, Span { at: ek.at, len: ek_pre });
        if changes[del].len >= k { tok_cut(changes, del, 0, k); }
    } else if keep0 >= 0 {
        let ds = Span { at: changes[del].at, len: changes[del].len };
        let sk = Span { at: changes[keep0].at, len: changes[keep0].len };
        let sk_suf = ws_tail(b, sk);
        let del_pre = ws_lead(a, ds);
        let k = ws_overlap(b, Span { at: sk.at + sk.len - sk_suf, len: sk_suf },
                           a, Span { at: ds.at, len: del_pre });
        if changes[del].len >= k { tok_cut(changes, del, k, 0); }
    }
}

// tok_dedupe moves the white space between the changes of the word
// search. The white space between two words stands in two tokens, so the
// changes would hold it twice. The Node library moves it to the keep
// before or after the change. The package does the same. The move sees
// only the changes that start at the place `from`. The changes before it
// belong to the caller.
fn tok_dedupe(changes: Change[>..]&, from: i64, a: const u8[:], b: const u8[:]) {
    var keep0: i64 = -1;
    var del: i64 = -1;
    var ins: i64 = -1;
    var k = from;
    while k < changes.len {
        let c = changes[k];
        if c.added { ins = k; }
        else if c.removed { del = k; }
        else {
            if ins >= 0 || del >= 0 { tok_dedupe_one(changes, a, b, keep0, del, ins, k); }
            keep0 = k;
            ins = -1;
            del = -1;
        }
        k = k + 1;
    }
    if ins >= 0 || del >= 0 { tok_dedupe_one(changes, a, b, keep0, del, ins, -1); }
}

// diff_words adds the changes of the words of a against b to `changes`.
// The white space between the words does not matter to the search. It
// gives a code and a flag. The flag is true when the diff is minimal.
fn diff_words(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    let start = changes.len;
    var pa: Span[>..] = [];
    var pb: Span[>..] = [];
    if !tok_parts(a, o, false, pa) || !tok_parts(b, o, false, pb) { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    tok_stitch(a, pa[..], ta);
    tok_stitch(b, pb[..], tb);
    if ta.len + tb.len > o.max_tokens { return ERR_TOO_LARGE, false; }
    var sa: Span[>..] = [];
    var sb: Span[>..] = [];
    for t in ta { sa.push(tok_trim(a, t)); }
    for t in tb { sb.push(tok_trim(b, t)); }
    let code, exact = tok_changes(a, ta[..], sa[..], b, tb[..], sb[..], o, false, changes);
    if code != ERR_OK { return code, false; }
    tok_dedupe(changes, start, a, b);
    return ERR_OK, exact;
}

// tok_parts_wsnl gives the parts of the word search with space. The line
// end is a part of its own. A run of white space holds no line end.
fn tok_parts_wsnl(text: const u8[:], o: TokenOptions, out: Span[>..]&) -> bool {
    var i: i64 = 0;
    while i < text.len {
        if out.len >= o.max_tokens { return false; }
        if text[i] == 13 && i + 1 < text.len && text[i + 1] == 10 {
            out.push(Span { at: i, len: 2 });
            i = i + 2;
            continue;
        }
        if text[i] == 10 {
            out.push(Span { at: i, len: 1 });
            i = i + 1;
            continue;
        }
        if tok_code_space(text, i) {
            var j = i;
            while j < text.len {
                if text[j] == 10 || text[j] == 13 { break; }
                if !tok_code_space(text, j) { break; }
                j = j + tok_width(text, j);
            }
            out.push(Span { at: i, len: j - i });
            i = j;
            continue;
        }
        let w = tok_width(text, i);
        var end = i + w;
        if end > text.len { end = text.len; }
        if tok_word(tok_code(text, i, end - i)) {
            var j = i;
            while j < text.len {
                let w2 = tok_width(text, j);
                var e2 = j + w2;
                if e2 > text.len { e2 = text.len; }
                if !tok_word(tok_code(text, j, e2 - j)) { break; }
                j = e2;
            }
            out.push(Span { at: i, len: j - i });
            i = j;
            continue;
        }
        out.push(Span { at: i, len: end - i });
        i = end;
    }
    return true;
}

// diff_words_with_space adds the changes of the words of a against b to
// `changes`. The white space between the words matters to the search.
// It gives a code and a flag. The flag is true when the diff is minimal.
fn diff_words_with_space(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_parts(a, o, true, ta) || !tok_parts(b, o, true, tb) { return ERR_TOO_LARGE, false; }
    if ta.len + tb.len > o.max_tokens { return ERR_TOO_LARGE, false; }
    return tok_changes(a, ta[..], ta[..], b, tb[..], tb[..], o, false, changes);
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
