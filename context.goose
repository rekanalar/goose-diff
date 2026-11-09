// The context diff of the Python library difflib.
namespace diff;

import std;

// put_context_range appends a range as the context format writes it. A
// range of one line or none gives one number. An empty range names the
// line before it.
fn put_context_range(out: u8[>..]&, start: i64, stop: i64) {
    var first = start + 1;
    let length = stop - start;
    if length == 0 { first = first - 1; }
    digits_of(out, first);
    if length > 1 {
        out.push(',');
        digits_of(out, first + length - 1);
    }
}

// write_context appends the context diff of the opcodes to the buffer.
fn write_context(out: u8[>..]&, a: const u8[:], la: const Span[:], b: const u8[:], lb: const Span[:],
                 ops: const Op[:], a_name: const u8[:], b_name: const u8[:], context: i64) {
    var groups: Op[>..] = [];
    var ends: i64[>..] = [];
    group_ops(ops, context, groups, ends);
    var from: i64 = 0;
    var first = true;
    for e in ends {
        if first {
            put_text(out, "*** ");
            put_text(out, a_name);
            out.push(10);
            put_text(out, "--- ");
            put_text(out, b_name);
            out.push(10);
            first = false;
        }
        put_text(out, "***************\n*** ");
        put_context_range(out, groups[from].a_lo, groups[e - 1].a_hi);
        put_text(out, " ****\n");
        var old = false;
        var new = false;
        for i in from..e {
            if groups[i].tag == OP_REPLACE || groups[i].tag == OP_DELETE { old = true; }
            if groups[i].tag == OP_REPLACE || groups[i].tag == OP_INSERT { new = true; }
        }
        if old {
            for i in from..e {
                let g = groups[i];
                if g.tag == OP_INSERT { continue; }
                var mark: u8 = ' ';
                if g.tag == OP_REPLACE { mark = '!'; }
                if g.tag == OP_DELETE { mark = '-'; }
                for k in g.a_lo..g.a_hi {
                    out.push(mark);
                    put_line(out, ' ', a, la[k]);
                }
            }
        }
        put_text(out, "--- ");
        put_context_range(out, groups[from].b_lo, groups[e - 1].b_hi);
        put_text(out, " ----\n");
        if new {
            for i in from..e {
                let g = groups[i];
                if g.tag == OP_DELETE { continue; }
                var mark: u8 = ' ';
                if g.tag == OP_REPLACE { mark = '!'; }
                if g.tag == OP_INSERT { mark = '+'; }
                for k in g.b_lo..g.b_hi {
                    out.push(mark);
                    put_line(out, ' ', b, lb[k]);
                }
            }
        }
        from = e;
    }
}

// context_diff appends the context diff of a against b to `out`. The
// names go in the two header lines. Equal texts give no output. It gives
// a code and a flag. The flag is true when the diff is minimal. The rule
// `algorithm` names the search.
fn context_diff(out: u8[>..]&, a: const u8[:], b: const u8[:], a_name: const u8[:], b_name: const u8[:],
                o: Options) -> i64, bool {
    if !options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    if !name_ok(a_name) || !name_ok(b_name) { return ERR_BAD_NAME, false; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ops: Op[>..] = [];
    let code, exact = output_ops(a, b, o, la, lb, ops);
    if code != ERR_OK { return code, false; }
    write_context(out, a, la[..], b, lb[..], ops[..], a_name, b_name, o.context);
    return ERR_OK, exact;
}
