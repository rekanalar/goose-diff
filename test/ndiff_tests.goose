// The tests of the group ndiff.
namespace ndiff_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import common;

fn test_ndiff() {
    var d: u8[>..] = [];
    // The example of the Python documentation.
    assert(common::nd_run("one\ntwo\nthree\n", "ore\ntree\nemu\n", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "- one\n?  ^\n+ ore\n?  ^\n- two\n- three\n?  -\n+ tree\n+ emu\n");
    d.resize(0, 0);
    assert(common::nd_run("same\nalpha\nbravo\n", "same\nalpha\nbravo!\n", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "  same\n  alpha\n- bravo\n+ bravo!\n?      +\n");
    // The tab stays in the line of hints, so the marks line up.
    d.resize(0, 0);
    assert(common::nd_run("\tabcDefghiJkl\n", "\tabcdefGhijkl\n", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "- \tabcDefghiJkl\n? \t   ^  ^  ^\n+ \tabcdefGhijkl\n? \t   ^  ^  ^\n");
    // A line without a line end gets one.
    d.resize(0, 0);
    assert(common::nd_run("a", "b", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "- a\n+ b\n");
    // Empty texts.
    d.resize(0, 0);
    assert(common::nd_run(""[..], ""[..], diff::default_options(), d) == diff::ERR_OK);
    assert(d.len == 0);
}

fn test_ndiff_restore() {
    var d: u8[>..] = [];
    let a = "one\ntwo\nthree\n";
    let b = "ore\ntree\nemu\n";
    assert(common::nd_run(a, b, diff::default_options(), d) == diff::ERR_OK);
    var r1: u8[>..] = [];
    var r2: u8[>..] = [];
    assert(diff::ndiff_restore(d[..], 1, r1) == diff::ERR_OK);
    assert(diff::ndiff_restore(d[..], 2, r2) == diff::ERR_OK);
    assert(r1[..] == a);
    assert(r2[..] == b);
    // The number of a text is 1 or 2. A fault leaves the buffer alone.
    assert(diff::ndiff_restore(d[..], 3, r1) == diff::ERR_BAD_OPTION);
    assert(diff::ndiff_restore(d[..], 0, r1) == diff::ERR_BAD_OPTION);
    assert(r1[..] == a);
    // Lines with other codes give nothing.
    var r3: u8[>..] = [];
    assert(diff::ndiff_restore("? hint\n-x\n\n  keep\n"[..], 1, r3) == diff::ERR_OK);
    assert(r3[..] == "keep\n");
}

fn test_ndiff_bounds() {
    // Many close lines spend work. A small budget gives a fault and
    // leaves the buffer as it was.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for i in 300 {
        for k in 40 { a.push('a' + (k % 7) as! u8); b.push('a' + (k % 7) as! u8); }
        a.push('x');
        b.push('y');
        a.push(10);
        b.push(10);
    }
    var o = diff::default_options();
    o.max_work = 1000;
    var d: u8[>..] = ['k'];
    assert(diff::ndiff(a[..], b[..], o, d) == diff::ERR_TOO_MUCH_WORK);
    assert(d.len == 1);
    o.max_work = 50000000;
    assert(diff::ndiff(a[..], b[..], o, d) == diff::ERR_OK);
    assert(d.len > 1);
    var bad = diff::default_options();
    bad.max_work = -1;
    assert(diff::ndiff(a[..], b[..], bad, d) == diff::ERR_BAD_OPTION);
    var small = diff::default_options();
    small.max_input = 10;
    assert(diff::ndiff(a[..], b[..], small, d) == diff::ERR_TOO_LARGE);
    // The scan of pairs that a cheap ratio rules out spends work too.
    var p: u8[>..] = [];
    var q: u8[>..] = [];
    for i in 3000 { p.push('A'); p.push('A'); p.push('A'); p.push('A'); p.push(10); q.push('b'); q.push(10); }
    var ow = diff::default_options();
    ow.max_work = 20000;
    var pd: u8[>..] = [];
    assert(diff::ndiff(p[..], q[..], ow, pd) == diff::ERR_TOO_MUCH_WORK);
    assert(pd.len == 0);
    // The delta may grow to several times the input, so no cap on it.
    var c1: u8[>..] = [];
    var c2: u8[>..] = [];
    for i in 200 { for w in 4 { c1.push('a' + w as! u8); } c1.push(10); for w in 3 { c2.push('a' + w as! u8); } c2.push('z'); c2.push(10); }
    var oc = diff::default_options();
    oc.max_input = c1.len;
    var cd: u8[>..] = [];
    assert(diff::ndiff(c1[..], c2[..], oc, cd) == diff::ERR_OK);
    // Broken bytes and carriage returns do not stop the search.
    var h: u8[>..] = [];
    var g: u8[>..] = [];
    for i in 50 { h.push(0xff); h.push(13); h.push(10); g.push(0x80); g.push(13); g.push(10); }
    var hd: u8[>..] = [];
    assert(diff::ndiff(h[..], g[..], diff::default_options(), hd) == diff::ERR_OK);
}

fn test_context() {
    var d: u8[>..] = [];
    let code, exact = diff::context_diff(d, "one\ntwo\nthree\nfour\n", "zero\none\ntree\nfour\n",
                                         "Original", "Current", diff::default_options());
    assert(code == diff::ERR_OK);
    assert(d[..] == "*** Original\n--- Current\n***************\n*** 1,4 ****\n  one\n! two\n! three\n  four\n--- 1,4 ----\n+ zero\n  one\n! tree\n  four\n");
    // A pure insert has no lines in the first part. A pure delete has none in the second.
    d.resize(0, 0);
    assert(diff::context_diff(d, "a\n", "a\nb\n", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d[..] == "*** x\n--- y\n***************\n*** 1 ****\n--- 1,2 ----\n  a\n+ b\n");
    d.resize(0, 0);
    assert(diff::context_diff(d, "a\nb\n", "a\n", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d[..] == "*** x\n--- y\n***************\n*** 1,2 ****\n  a\n- b\n--- 1 ----\n");
    // Equal texts give nothing.
    d.resize(0, 0);
    assert(diff::context_diff(d, "a\n", "a\n", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d.len == 0);
    // A name with a line end is a fault and the buffer stays.
    d.push('k');
    assert(diff::context_diff(d, "a\n", "b\n", "x\ny", "y", diff::default_options()) == diff::ERR_BAD_NAME);
    assert(d.len == 1);
    var small = diff::default_options();
    small.max_input = 1;
    assert(diff::context_diff(d, "aa\n", "b\n", "x", "y", small) == diff::ERR_TOO_LARGE);
    // A line without a line end gets the marker line.
    d.resize(0, 0);
    assert(diff::context_diff(d, "a", "b", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d[..] == "*** x\n--- y\n***************\n*** 1 ****\n! a\n\\ No newline at end of file\n--- 1 ----\n! b\n\\ No newline at end of file\n");
}

fn test_css() {
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    let a = "a{b:c}";
    let b = "a{b:d}";
    assert(diff::diff_css(a, b, o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    common::check_change(changes[0], 0, 4, 4, 1, false, false);
    common::check_change(changes[1], 4, 1, 1, 0, false, true);
    common::check_change(changes[2], 4, 1, 1, 1, true, false);
    common::check_change(changes[3], 5, 1, 1, 1, false, false);
    // White space is a token of its own and it matters.
    common::clear_changes(changes);
    assert(diff::diff_css("a  b", "a b", o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    common::clear_changes(changes);
    assert(diff::diff_css(""[..], ""[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 0);
}
