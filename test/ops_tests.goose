// The tests of the group ops.
namespace ops_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import common;

fn test_basic() {
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_lines("a\nb\nc\n", "a\nx\nc\n", diff::default_options(), ops);
    assert(code == diff::ERR_OK && exact && ops.len == 3);
    assert(ops[1].tag == diff::OP_REPLACE && ops[1].a_lo == 1 && ops[1].a_hi == 2);
    var e: diff::Op[>..] = [];
    let c2, x2 = diff::diff_lines("", "", diff::default_options(), e);
    assert(c2 == diff::ERR_OK && e.len == 0);
    let c3, x3 = diff::diff_lines("a\n", "", diff::default_options(), e);
    assert(e.len == 1 && e[0].tag == diff::OP_DELETE);
    var e4: diff::Op[>..] = [];
    let c4, x4 = diff::diff_lines("", "a\nb\n", diff::default_options(), e4);
    assert(e4.len == 1 && e4[0].tag == diff::OP_INSERT && e4[0].b_hi == 2);
    // A last line with no line end differs from the same line with one.
    var e5: diff::Op[>..] = [];
    let c5, x5 = diff::diff_lines("a\nb", "a\nb\n", diff::default_options(), e5);
    assert(e5.len == 2 && e5[1].tag == diff::OP_REPLACE);
}

fn test_random() {
    for round in 300 {
        var a: u8[>..] = [];
        var b: u8[>..] = [];
        common::make_text(a, common::rnd(40), 1 + common::rnd(8));
        common::make_text(b, common::rnd(40), 1 + common::rnd(8));
        var ops: diff::Op[>..] = [];
        let code, exact = diff::diff_lines(a[..], b[..], diff::default_options(), ops);
        assert(code == diff::ERR_OK && exact);
        let equal = common::check_ops(a[..], b[..], ops[..]);
        assert(equal == common::lcs_len(a[..], b[..]));
    }
}

fn test_bounds() {
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for i in 400 { a.push('a'); a.push(10); b.push('b'); b.push(10); }
    var o = diff::default_options();
    o.max_edits = 10;
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_lines(a[..], b[..], o, ops);
    assert(code == diff::ERR_OK && !exact);
    common::check_ops(a[..], b[..], ops[..]);
    o.max_input = 100;
    var keep: diff::Op[>..] = [];
    let c2, x2 = diff::diff_lines(a[..], b[..], o, keep);
    assert(c2 == diff::ERR_TOO_LARGE && keep.len == 0);
    o = diff::default_options();
    o.max_edits = 0;
    let c3, x3 = diff::diff_lines("a", "b", o, keep);
    assert(c3 == diff::ERR_BAD_OPTION && keep.len == 0);
    // A rule beyond its cap is a fault. A huge context or edit count
    // would wrap the arithmetic of the output or of the search trace.
    o = diff::default_options();
    o.context = 9223372036854775807;
    var ub: u8[>..] = [];
    let c4, x4 = diff::unified_diff(ub, a[..], b[..], "a", "b", o);
    assert(c4 == diff::ERR_BAD_OPTION && ub.len == 0);
    o.context = 3;
    o.max_edits = 3001;
    let c5, x5 = diff::diff_lines("a", "b", o, keep);
    assert(c5 == diff::ERR_BAD_OPTION && keep.len == 0);
}
