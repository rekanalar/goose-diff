// The delta of the Python library difflib: ndiff and restore.
//
// The delta holds one line of output for each line of the two texts. A
// line of the first text begins with "- ". A line of the second text
// begins with "+ ". A line that both texts hold begins with two blanks.
// Two lines that come close get a line of hints, which begins with "? ".
// The hints mark the characters that differ: "^" for a changed part, "-"
// for a part that only the first line holds and "+" for a part that only
// the second line holds.
namespace diff;

import std;

// The rule of the junk characters of a delta: the blank and the tab, as
// the function IS_CHARACTER_JUNK of Python takes them, or none.
const CHARJUNK_BLANK: i64 = 0;
const CHARJUNK_NONE: i64 = 1;

// The lines that the search of a close pair looks at, on each side.
const NDIFF_WINDOW: i64 = 10;

// nd_space tells whether a code point is white space. The set is the set
// of the Python method str.isspace.
fn nd_space(c: i64) -> bool {
    if c >= 9 && c <= 13 { return true; }
    if c >= 28 && c <= 32 { return true; }
    if c == 0x85 || c == 0xA0 || c == 0x1680 { return true; }
    if c >= 0x2000 && c <= 0x200A { return true; }
    if c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000 { return true; }
    return false;
}

// nd_cont gives the six low bits of a continuation byte.
fn nd_cont(text: const u8[:], k: i64) -> i64 {
    let v: i64 = text[k];
    return v & 63;
}

// nd_code gives the code point of a span. A broken byte gives the value
// of the byte.
fn nd_code(text: const u8[:], s: Span) -> i64 {
    let c: i64 = text[s.at];
    if s.len == 1 { return c; }
    if s.len == 2 { return ((c & 31) << 6) | nd_cont(text, s.at + 1); }
    if s.len == 3 {
        return ((c & 15) << 12) | (nd_cont(text, s.at + 1) << 6) | nd_cont(text, s.at + 2);
    }
    return ((c & 7) << 18) | (nd_cont(text, s.at + 1) << 12)
           | (nd_cont(text, s.at + 2) << 6) | nd_cont(text, s.at + 3);
}

// nd_pair gives the ids of the code points of two lines, and the junk
// table. The blank and the tab are junk.
fn nd_pair(a: const u8[:], sa: const Span[:], b: const u8[:], sb: const Span[:],
           ida: i32[>..]&, idb: i32[>..]&, junk: u8[>..]&, char_junk: i64) {
    ida.resize(0, 0);
    idb.resize(0, 0);
    intern(a, sa, b, sb, ida, idb, Compare { fold: false, strip_cr: false });
    junk.resize(0, 0);
    junk.resize(ro_ids(ida[..], idb[..]), 0);
    if char_junk == CHARJUNK_NONE { return; }
    for i in sa.len {
        if sa[i].len == 1 && (a[sa[i].at] == ' ' || a[sa[i].at] == 9) { junk[ida[i] as i64] = 1; }
    }
    for i in sb.len {
        if sb[i].len == 1 && (b[sb[i].at] == ' ' || b[sb[i].at] == 9) { junk[idb[i] as i64] = 1; }
    }
}

// nd_line adds a line of the delta: the code of two letters, the line
// and a line end when the line holds none.
fn nd_line(out: u8[>..]&, tag: u8, text: const u8[:], s: Span) {
    out.push(tag);
    out.push(' ');
    for k in s.len { out.push(text[s.at + k]); }
    if s.len == 0 || text[s.at + s.len - 1] != 10 { out.push(10); }
}

// nd_dump adds the lines lo..hi of a text with one code.
fn nd_dump(out: u8[>..]&, tag: u8, text: const u8[:], lines: const Span[:], lo: i64, hi: i64) {
    for i in lo..hi { nd_line(out, tag, text, lines[i]); }
}

// nd_plain adds a plain replace. The shorter block goes first.
fn nd_plain(out: u8[>..]&, a: const u8[:], la: const Span[:], alo: i64, ahi: i64,
            b: const u8[:], lb: const Span[:], blo: i64, bhi: i64) {
    if bhi - blo < ahi - alo {
        nd_dump(out, '+', b, lb, blo, bhi);
        nd_dump(out, '-', a, la, alo, ahi);
    } else {
        nd_dump(out, '-', a, la, alo, ahi);
        nd_dump(out, '+', b, lb, blo, bhi);
    }
}

// nd_helper adds the lines between two close pairs.
fn nd_helper(out: u8[>..]&, a: const u8[:], la: const Span[:], alo: i64, ahi: i64,
             b: const u8[:], lb: const Span[:], blo: i64, bhi: i64) {
    if alo < ahi {
        if blo < bhi {
            nd_plain(out, a, la, alo, ahi, b, lb, blo, bhi);
        } else {
            nd_dump(out, '-', a, la, alo, ahi);
        }
    } else if blo < bhi {
        nd_dump(out, '+', b, lb, blo, bhi);
    }
}

// nd_hints adds a line of hints. Where a mark is a blank and the line
// holds white space, the white space stays, so tabs line up.
fn nd_hints(out: u8[>..]&, text: const u8[:], spans: const Span[:], marks: const u8[:]) {
    var buf: u8[>..] = [];
    var keep: i64 = 0;
    for i in spans.len {
        let s = spans[i];
        if marks[i] == ' ' && nd_space(nd_code(text, s)) {
            for k in s.len { buf.push(text[s.at + k]); }
        } else {
            buf.push(marks[i]);
            if marks[i] != ' ' { keep = buf.len; }
        }
    }
    if keep == 0 { return; }
    out.push('?');
    out.push(' ');
    for k in keep { out.push(buf[k]); }
    out.push(10);
}

// nd_ratio_ok tells whether the ratio of the pair is over the cutoff.
// It gives a code and the ratio, or -1 when a cheaper ratio ruled the
// pair out. The three ratios run from the cheapest to the dearest.
fn nd_ratio(ida: const i32[:], idb: const i32[:], junk: const u8[:], best: f64, max_work: i64, work: i64&) -> i64, f64 {
    let total = ida.len + idb.len;
    if total == 0 { return ERR_OK, 1.0; }
    var small = ida.len;
    if idb.len < small { small = idb.len; }
    if 2.0 * small / total <= best { return ERR_OK, -1.0; }
    work = work + total;
    if work > max_work { return ERR_TOO_MUCH_WORK, -1.0; }
    let n_ids = ro_ids(ida, idb);
    if 2.0 * ro_quick(ida, idb, n_ids) / total <= best { return ERR_OK, -1.0; }
    var blocks: Match[>..] = [];
    let code = ro_blocks(ida, idb, junk, true, max_work, work, blocks);
    if code != ERR_OK { return code, -1.0; }
    var matches: i64 = 0;
    for m in blocks { matches = matches + m.size; }
    return ERR_OK, 2.0 * matches / total;
}

// nd_cmp gives the part of a line that the search compares. A bare
// search leaves the line end out, as the Python library does when its
// lines hold no line end.
fn nd_cmp(text: const u8[:], s: Span, bare: bool) -> Span {
    if bare && s.len > 0 && text[s.at + s.len - 1] == 10 { return Span { at: s.at, len: s.len - 1 }; }
    return s;
}

// nd_replace adds a replace block. It looks for close pairs of lines and
// marks the characters that differ inside each pair.
fn nd_replace(out: u8[>..]&, a: const u8[:], la: const Span[:], alo: i64, ahi: i64,
              b: const u8[:], lb: const Span[:], blo: i64, bhi: i64,
              max_work: i64, work: i64&, bare: bool, char_junk: i64) -> i64 {
    let cutoff: f64 = 0.74999;
    var tok = default_token_options();
    tok.max_tokens = 1 << 40;
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    var junk: u8[>..] = [];
    var sa: Span[>..] = [];
    var sb: Span[>..] = [];
    var best_i: i64 = -1;
    var best_j: i64 = -1;
    var dump_i = alo;
    var dump_j = blo;
    for j in blo..bhi {
        sb.resize(0, Span { at: 0, len: 0 });
        let sj = nd_cmp(b, lb[j], bare);
        let cj = b[sj.at..sj.at + sj.len];
        tok_chars(cj, tok, sb);
        let aequiv = alo + (j - blo);
        var lo = aequiv - NDIFF_WINDOW;
        if lo < dump_i { lo = dump_i; }
        var hi = aequiv + NDIFF_WINDOW + 1;
        if hi > ahi { hi = ahi; }
        if lo >= hi { break; }
        var best = cutoff;
        for i in lo..hi {
            // The scan of a pair costs the length of both lines, even
            // when a cheap ratio rules the pair out.
            work = work + la[i].len + lb[j].len + 1;
            if work > max_work { return ERR_TOO_MUCH_WORK; }
            sa.resize(0, Span { at: 0, len: 0 });
            let si = nd_cmp(a, la[i], bare);
            let ci = a[si.at..si.at + si.len];
            tok_chars(ci, tok, sa);
            nd_pair(ci, sa[..], cj, sb[..], ida, idb, junk, char_junk);
            let code, r = nd_ratio(ida[..], idb[..], junk[..], best, max_work, work);
            if code != ERR_OK { return code; }
            if r > best {
                best = r;
                best_i = i;
                best_j = j;
            }
        }
        if best_i < 0 { continue; }
        nd_helper(out, a, la, dump_i, best_i, b, lb, dump_j, best_j);
        let sai = nd_cmp(a, la[best_i], bare);
        let sbj = nd_cmp(b, lb[best_j], bare);
        let ca = a[sai.at..sai.at + sai.len];
        let cb = b[sbj.at..sbj.at + sbj.len];
        if ca != cb {
            sa.resize(0, Span { at: 0, len: 0 });
            sb.resize(0, Span { at: 0, len: 0 });
            tok_chars(ca, tok, sa);
            tok_chars(cb, tok, sb);
            nd_pair(ca, sa[..], cb, sb[..], ida, idb, junk, char_junk);
            var ops: Op[>..] = [];
            let code = ro_opcodes(ida[..], idb[..], junk[..], true, max_work, work, ops);
            if code != ERR_OK { return code; }
            var ma: u8[>..] = [];
            var mb: u8[>..] = [];
            for op in ops {
                for k in op.a_lo..op.a_hi {
                    if op.tag == OP_EQUAL { ma.push(' '); }
                    else if op.tag == OP_DELETE { ma.push('-'); }
                    else { ma.push('^'); }
                }
                for k in op.b_lo..op.b_hi {
                    if op.tag == OP_EQUAL { mb.push(' '); }
                    else if op.tag == OP_INSERT { mb.push('+'); }
                    else { mb.push('^'); }
                }
            }
            nd_line(out, '-', a, la[best_i]);
            nd_hints(out, ca, sa[..], ma[..]);
            nd_line(out, '+', b, lb[best_j]);
            nd_hints(out, cb, sb[..], mb[..]);
        } else {
            nd_line(out, ' ', a, la[best_i]);
        }
        dump_i = best_i + 1;
        dump_j = best_j + 1;
        best_i = -1;
        best_j = -1;
    }
    nd_helper(out, a, la, dump_i, ahi, b, lb, dump_j, bhi);
    return ERR_OK;
}

// ndiff adds the delta of a against b to `out`. The search of the lines
// is the matcher of the package. The rules `autojunk`, `strip_trailing_cr`,
// `max_work`, `max_input` and `max_tokens` apply. A line without a line
// end gets one in the delta. A call that fails leaves `out` as it was.
fn ndiff(a: const u8[:], b: const u8[:], o: Options, out: u8[>..]&) -> i64 {
    return ndiff_into(a, b, o, false, out);
}

// ndiff_into is ndiff with the choice of the bare search. A bare search
// compares the lines without their line ends.
fn ndiff_into(a: const u8[:], b: const u8[:], o: Options, bare: bool, out: u8[>..]&) -> i64 {
    if !options_ok(o) { return ERR_BAD_OPTION; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    let pcode = lines_of(a, b, la, lb, ida, idb, o);
    if pcode != ERR_OK { return pcode; }
    var junk: u8[>..] = [];
    junk.resize(ro_ids(ida[..], idb[..]), 0);
    ro_junk_lines(a, la[..], ida[..], b, lb[..], idb[..], o.junk, junk);
    var work: i64 = 0;
    var ops: Op[>..] = [];
    let ocode = ro_opcodes(ida[..], idb[..], junk[..], o.autojunk, o.max_work, work, ops);
    if ocode != ERR_OK { return ocode; }
    var buf: u8[>..] = [];
    for op in ops {
        if op.tag == OP_EQUAL {
            nd_dump(buf, ' ', a, la[..], op.a_lo, op.a_hi);
        } else if op.tag == OP_DELETE {
            nd_dump(buf, '-', a, la[..], op.a_lo, op.a_hi);
        } else if op.tag == OP_INSERT {
            nd_dump(buf, '+', b, lb[..], op.b_lo, op.b_hi);
        } else {
            let code = nd_replace(buf, a, la[..], op.a_lo, op.a_hi, b, lb[..], op.b_lo, op.b_hi,
                                  o.max_work, work, bare, o.char_junk);
            if code != ERR_OK { return code; }
        }
    }
    for c in buf { out.push(c); }
    return ERR_OK;
}

// ndiff_restore adds the lines of one text of a delta to `out`. The
// number `which` is 1 for the first text and 2 for the second. A line of
// hints and a line with another code give nothing.
fn ndiff_restore(delta: const u8[:], which: i64, out: u8[>..]&) -> i64 {
    if which != 1 && which != 2 { return ERR_BAD_OPTION; }
    var tag: u8 = '-';
    if which == 2 { tag = '+'; }
    var buf: u8[>..] = [];
    var i: i64 = 0;
    while i < delta.len {
        var end = i;
        while end < delta.len && delta[end] != 10 { end = end + 1; }
        if end < delta.len { end = end + 1; }
        if end - i >= 2 && delta[i + 1] == ' ' && (delta[i] == ' ' || delta[i] == tag) {
            for k in (i + 2)..end { buf.push(delta[k]); }
        }
        i = end;
    }
    for c in buf { out.push(c); }
    return ERR_OK;
}
