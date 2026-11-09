// The unified diff format.
//
// The output follows the Python library difflib: the hunks come from the
// opcodes grouped with a context size, and a range of one line shows one
// number. A line with no line end at the end of a text gets the marker
// "\ No newline at end of file", as GNU diff writes it.
namespace diff;

import std;

// The codes of the faults of the unified output.
const ERR_BAD_NAME: i64 = 3;

// digits_of appends the decimal text of a number that is not negative.
fn digits_of(out: u8[>..]&, v: i64) {
    var t: u8[20] = [0; 20];
    var n: i64 = 0;
    var x = v;
    while x > 0 {
        t[n] = '0' + (x % 10) as! u8;
        n = n + 1;
        x = x / 10;
    }
    if n == 0 { out.push('0'); }
    var j = n - 1;
    while j >= 0 {
        out.push(t[j]);
        j = j - 1;
    }
}

// put_text appends the bytes of a text.
fn put_text(out: u8[>..]&, s: const u8[:]) {
    for c in s { out.push(c); }
}

// put_range appends a range as difflib does: the first line number, and
// the count unless it is 1. An empty range names the line before it.
fn put_range(out: u8[>..]&, start: i64, stop: i64) {
    var first = start + 1;
    let length = stop - start;
    if length == 1 {
        digits_of(out, first);
        return;
    }
    if length == 0 { first = first - 1; }
    digits_of(out, first);
    out.push(',');
    digits_of(out, length);
}

// put_line appends a marker and a line. A line with no line end gets the
// marker line of GNU diff.
fn put_line(out: u8[>..]&, marker: u8, text: const u8[:], s: Span) {
    out.push(marker);
    for k in s.len { out.push(text[s.at + k]); }
    if s.len == 0 || text[s.at + s.len - 1] != 10 {
        out.push(10);
        put_text(out, "\\ No newline at end of file\n");
    }
}

// name_ok tells whether a file name can stand in a header: it holds no
// line end.
fn name_ok(s: const u8[:]) -> bool {
    for c in s { if c == 10 || c == 13 { return false; } }
    return true;
}

// group_ops cuts the opcodes into the groups of the hunks, each with n
// lines of context. It is the get_grouped_opcodes of difflib. The groups
// go to `out`, and `ends` holds the end index of each group in `out`.
fn group_ops(ops: const Op[:], n: i64, out: Op[>..]&, ends: i64[>..]&) {
    var codes: Op[>..] = [];
    for o in ops { codes.push(o); }
    if codes.len == 0 { codes.push(Op { tag: OP_EQUAL, a_lo: 0, a_hi: 1, b_lo: 0, b_hi: 1 }); }
    if codes[0].tag == OP_EQUAL {
        let c = codes[0];
        var a_lo = c.a_hi - n;
        if c.a_lo > a_lo { a_lo = c.a_lo; }
        var b_lo = c.b_hi - n;
        if c.b_lo > b_lo { b_lo = c.b_lo; }
        codes[0] = Op { tag: OP_EQUAL, a_lo: a_lo, a_hi: c.a_hi, b_lo: b_lo, b_hi: c.b_hi };
    }
    let last = codes.len - 1;
    if codes[last].tag == OP_EQUAL {
        let c = codes[last];
        var a_hi = c.a_lo + n;
        if c.a_hi < a_hi { a_hi = c.a_hi; }
        var b_hi = c.b_lo + n;
        if c.b_hi < b_hi { b_hi = c.b_hi; }
        codes[last] = Op { tag: OP_EQUAL, a_lo: c.a_lo, a_hi: a_hi, b_lo: c.b_lo, b_hi: b_hi };
    }
    var start = out.len;
    for c in codes {
        var cur = c;
        if cur.tag == OP_EQUAL && cur.a_hi - cur.a_lo > 2 * n {
            var a_hi = cur.a_lo + n;
            if cur.a_hi < a_hi { a_hi = cur.a_hi; }
            var b_hi = cur.b_lo + n;
            if cur.b_hi < b_hi { b_hi = cur.b_hi; }
            out.push(Op { tag: OP_EQUAL, a_lo: cur.a_lo, a_hi: a_hi, b_lo: cur.b_lo, b_hi: b_hi });
            ends.push(out.len);
            var a_lo = cur.a_hi - n;
            if cur.a_lo > a_lo { a_lo = cur.a_lo; }
            var b_lo = cur.b_hi - n;
            if cur.b_lo > b_lo { b_lo = cur.b_lo; }
            cur = Op { tag: OP_EQUAL, a_lo: a_lo, a_hi: cur.a_hi, b_lo: b_lo, b_hi: cur.b_hi };
        }
        out.push(cur);
    }
    // The last group stands unless it is one run of equal lines.
    let count = out.len - start;
    var keep = true;
    if ends.len > 0 {
        if ends[ends.len - 1] == out.len { keep = false; }
    }
    var from = start;
    if ends.len > 0 { from = ends[ends.len - 1]; }
    if out.len - from == 1 && out[from].tag == OP_EQUAL { keep = false; }
    if out.len == from { keep = false; }
    if keep { ends.push(out.len); }
}

// write_unified appends the unified diff of the opcodes to the buffer.
fn write_unified(out: u8[>..]&, a: const u8[:], la: const Span[:], b: const u8[:], lb: const Span[:],
                 ops: const Op[:], a_name: const u8[:], b_name: const u8[:], context: i64) {
    var groups: Op[>..] = [];
    var ends: i64[>..] = [];
    group_ops(ops, context, groups, ends);
    var from: i64 = 0;
    var first = true;
    for e in ends {
        if first {
            put_text(out, "--- ");
            put_text(out, a_name);
            out.push(10);
            put_text(out, "+++ ");
            put_text(out, b_name);
            out.push(10);
            first = false;
        }
        put_text(out, "@@ -");
        put_range(out, groups[from].a_lo, groups[e - 1].a_hi);
        put_text(out, " +");
        put_range(out, groups[from].b_lo, groups[e - 1].b_hi);
        put_text(out, " @@\n");
        var i = from;
        while i < e {
            let o = groups[i];
            if o.tag == OP_EQUAL {
                for k in o.a_hi - o.a_lo { put_line(out, ' ', a, la[o.a_lo + k]); }
            } else {
                if o.tag == OP_REPLACE || o.tag == OP_DELETE {
                    for k in o.a_hi - o.a_lo { put_line(out, '-', a, la[o.a_lo + k]); }
                }
                if o.tag == OP_REPLACE || o.tag == OP_INSERT {
                    for k in o.b_hi - o.b_lo { put_line(out, '+', b, lb[o.b_lo + k]); }
                }
            }
            i = i + 1;
        }
        from = e;
    }
}
