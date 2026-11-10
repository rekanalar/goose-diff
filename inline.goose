// Inline changes: the lines of a diff with the changed words marked.
//
// The lines come from the line search. A block of changed lines gets a
// second search over its words, as `iter_inline_changes` of the Rust
// library `similar` does it. The second search uses the Patience
// algorithm. A word is a run of white space or a run of other
// characters. The package reads UTF-8. A byte that is not part of a valid
// character counts as a character that is not white space. The result is
// plain data: a list of changes, and a list of segments for them.
namespace diff;

import std;

// The tags of an inline change.
const INL_EQUAL: i64 = 0;
const INL_DELETE: i64 = 1;
const INL_INSERT: i64 = 2;

// InlineChange is one line of the result. The tag tells the side: an
// equal line and a deleted line read from the first text, an inserted
// line reads from the second text. The index of the other side is -1.
// The segments of the line are `count` entries from `first`.
struct InlineChange {
    tag: i64,
    old_index: i64,
    new_index: i64,
    first: i64,
    count: i64,
}

// InlineSeg is a part of a line. The part is a place in the text of its
// change. The flag `emph` is true for the words that changed.
struct InlineSeg {
    at: i64,
    len: i64,
    emph: bool,
}

// in_white tells whether the character at the place is white space in
// the sense of Unicode, and gives the byte length of the character.
fn in_white(text: const u8[:], i: i64, end: i64) -> i64, bool {
    let c = text[i];
    if c < 128 { return 1, c == 32 || (c >= 9 && c <= 13); }
    var n: i64 = 0;
    if c >= 194 && c < 224 { n = 2; } else if c >= 224 && c < 240 { n = 3; } else if c >= 240 && c < 245 { n = 4; }
    if n == 0 || i + n > end { return 1, false; }
    var cp: i64 = 0;
    if n == 2 { cp = c & 31; } else if n == 3 { cp = c & 15; } else { cp = c & 7; }
    for k in 1..n {
        let d = text[i + k];
        if (d & 192) != 128 { return 1, false; }
        cp = cp * 64 + (d & 63);
    }
    let ws = cp == 133 || cp == 160 || cp == 5760 || (cp >= 8192 && cp <= 8202) || cp == 8232 ||
             cp == 8233 || cp == 8239 || cp == 8287 || cp == 12288;
    return n, ws;
}

// in_words adds the words of the line `s` to `out`, and the number of
// the line to `lines`.
fn in_words(text: const u8[:], s: Span, line: i64, out: Span[>..]&, lines: i64[>..]&) {
    let end = s.at + s.len;
    var i = s.at;
    while i < end {
        let n0, ws = in_white(text, i, end);
        var j = i + n0;
        var more = true;
        while more && j < end {
            let n1, ws1 = in_white(text, j, end);
            if ws1 != ws { more = false; } else { j = j + n1; }
        }
        out.push(Span { at: i, len: j - i });
        lines.push(line);
        i = j;
    }
}

// in_push adds the segments of the slice at..at+len of a line. A slice
// that changed splits at its line ends, and the line ends are not marked.
fn in_push(text: const u8[:], at: i64, len: i64, emph: bool, line: i64,
           segs: InlineSeg[>..]&, seg_line: i64[>..]&) {
    if !emph {
        segs.push(InlineSeg { at: at, len: len, emph: false });
        seg_line.push(line);
        return;
    }
    let end = at + len;
    var i = at;
    while i < end {
        let nl = text[i] == 10 || text[i] == 13;
        var j = i + 1;
        while j < end && (text[j] == 10 || text[j] == 13) == nl { j = j + 1; }
        segs.push(InlineSeg { at: i, len: j - i, emph: !nl });
        seg_line.push(line);
        i = j;
    }
}

// in_range adds the segments of the words from..to. The words of one
// line merge into one slice.
fn in_range(text: const u8[:], toks: const Span[:], lines: const i64[:], from: i64, to: i64,
            emph: bool, segs: InlineSeg[>..]&, seg_line: i64[>..]&) {
    var k = from;
    while k < to {
        var e = k + 1;
        while e < to && lines[e] == lines[k] { e = e + 1; }
        let last = toks[e - 1];
        in_push(text, toks[k].at, last.at + last.len - toks[k].at, emph, lines[k], segs, seg_line);
        k = e;
    }
}

// in_emit adds the lines `n` of one side to the result, from the segments
// of the block. The segments stand in the order of the lines.
fn in_emit(tag: i64, first_index: i64, n: i64, segs: const InlineSeg[:], seg_line: const i64[:],
           changes: InlineChange[>..]&, out: InlineSeg[>..]&) {
    var p: i64 = 0;
    for k in n {
        let first = out.len;
        while p < segs.len && seg_line[p] == k {
            out.push(segs[p]);
            p = p + 1;
        }
        var oi: i64 = -1;
        var ni: i64 = -1;
        if tag == INL_DELETE { oi = first_index + k; } else { ni = first_index + k; }
        changes.push(InlineChange { tag: tag, old_index: oi, new_index: ni, first: first, count: out.len - first });
    }
}

// in_plain adds the lines a_lo..a_hi as deleted lines and b_lo..b_hi as
// inserted lines, with no mark.
fn in_plain(op: Op, la: const Span[:], lb: const Span[:], changes: InlineChange[>..]&,
            segs: InlineSeg[>..]&) {
    for i in op.a_lo..op.a_hi {
        changes.push(InlineChange { tag: INL_DELETE, old_index: i, new_index: -1, first: segs.len, count: 1 });
        segs.push(InlineSeg { at: la[i].at, len: la[i].len, emph: false });
    }
    for j in op.b_lo..op.b_hi {
        changes.push(InlineChange { tag: INL_INSERT, old_index: -1, new_index: j, first: segs.len, count: 1 });
        segs.push(InlineSeg { at: lb[j].at, len: lb[j].len, emph: false });
    }
}

// in_block marks the words of one block of changed lines.
fn in_block(a: const u8[:], b: const u8[:], op: Op, la: const Span[:], lb: const Span[:],
            o: Options, changes: InlineChange[>..]&, segs: InlineSeg[>..]&) -> i64 {
    let n_old = op.a_hi - op.a_lo;
    let n_new = op.b_hi - op.b_lo;
    var lo = n_old;
    if n_new < lo { lo = n_new; }
    // The cheap bound: too few lines on one side.
    if 4 * lo < n_old + n_new {
        in_plain(op, la, lb, changes, segs);
        return ERR_OK;
    }
    var ta: Span[>..] = [];
    var tla: i64[>..] = [];
    var tb: Span[>..] = [];
    var tlb: i64[>..] = [];
    for i in n_old { in_words(a, la[op.a_lo + i], i, ta, tla); }
    for j in n_new { in_words(b, lb[op.b_lo + j], j, tb, tlb); }
    if ta.len + tb.len > o.max_tokens { return ERR_TOO_LARGE; }
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    intern(a, ta[..], b, tb[..], ida, idb, Compare { fold: false, strip_cr: false });
    var ops: Op[>..] = [];
    let code, exact = diff_ids_alg(ida[..], idb[..], ALG_PATIENCE, o.max_edits, o.max_work, ops);
    if code != ERR_OK { return code; }
    var same: i64 = 0;
    for w in ops { if w.tag == OP_EQUAL { same = same + (w.a_hi - w.a_lo); } }
    if 4 * same < ta.len + tb.len {
        in_plain(op, la, lb, changes, segs);
        return ERR_OK;
    }
    var os: InlineSeg[>..] = [];
    var osl: i64[>..] = [];
    var ns: InlineSeg[>..] = [];
    var nsl: i64[>..] = [];
    for w in ops {
        let eq = w.tag == OP_EQUAL;
        let del = w.tag == OP_DELETE || w.tag == OP_REPLACE;
        let ins = w.tag == OP_INSERT || w.tag == OP_REPLACE;
        if eq || del { in_range(a, ta[..], tla[..], w.a_lo, w.a_hi, !eq, os, osl); }
        if eq || ins { in_range(b, tb[..], tlb[..], w.b_lo, w.b_hi, !eq, ns, nsl); }
    }
    in_emit(INL_DELETE, op.a_lo, n_old, os[..], osl[..], changes, segs);
    in_emit(INL_INSERT, op.b_lo, n_new, ns[..], nsl[..], changes, segs);
    return ERR_OK;
}

// inline_changes adds the lines of the diff of a against b to `changes`,
// with the segments in `segs`. A block of changed lines that share enough
// words gets its changed words marked. The rule `algorithm` of the
// options names the line search. A fault leaves both buffers as they
// were. It gives a code.
fn inline_changes(a: const u8[:], b: const u8[:], o: Options, changes: InlineChange[>..]&,
                  segs: InlineSeg[>..]&) -> i64 {
    var ops: Op[>..] = [];
    let code, exact = diff_lines(a, b, o, ops);
    if code != ERR_OK { return code; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    split_lines(a, la);
    split_lines(b, lb);
    let c0 = changes.len;
    let s0 = segs.len;
    for op in ops {
        if op.tag == OP_REPLACE {
            let r = in_block(a, b, op, la[..], lb[..], o, changes, segs);
            if r != ERR_OK {
                changes.resize(c0, InlineChange { tag: 0, old_index: 0, new_index: 0, first: 0, count: 0 });
                segs.resize(s0, InlineSeg { at: 0, len: 0, emph: false });
                return r;
            }
        } else if op.tag == OP_EQUAL {
            for i in op.a_lo..op.a_hi {
                changes.push(InlineChange { tag: INL_EQUAL, old_index: i, new_index: op.b_lo + (i - op.a_lo),
                                            first: segs.len, count: 1 });
                segs.push(InlineSeg { at: la[i].at, len: la[i].len, emph: false });
            }
        } else if op.tag == OP_DELETE {
            in_plain(op, la[..], lb[..], changes, segs);
        } else {
            in_plain(op, la[..], lb[..], changes, segs);
        }
    }
    return ERR_OK;
}

// inline_missing_newline tells whether the last segment of a change does
// not end with a line end.
fn inline_missing_newline(a: const u8[:], b: const u8[:], c: InlineChange, segs: const InlineSeg[:]) -> bool {
    if c.count == 0 { return false; }
    let s = segs[c.first + c.count - 1];
    var text = a;
    if c.tag == INL_INSERT { text = b; }
    let last = text[s.at + s.len - 1];
    return !(last == 10 || last == 13);
}
