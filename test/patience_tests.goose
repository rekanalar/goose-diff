// The tests of the group patience.
namespace patience_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import common;

fn test_patience_lcs() {
    // The cases come from the Rust crate similar 2.7.0.
    var a: i32[>..] = [];
    var b: i32[>..] = [];
    common::ids_of([11, 1, 2, 2, 3, 4, 4, 4, 5, 47, 19], a);
    common::ids_of([10, 1, 2, 2, 8, 9, 4, 4, 7, 47, 18], b);
    var out: u8[>..] = [];
    assert(common::alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(out[..] == "r0,1,0,1 e1,1,3 r4,1,4,2 e5,6,2 r7,2,8,1 e9,9,1 r10,1,10,1");
    out.resize(0, 0);
    assert(common::alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    assert(out[..] == "r0,1,0,1 e1,1,3 r4,2,4,2 e6,6,2 r8,1,8,1 e9,9,1 r10,1,10,1");
    // A case where the three searches differ.
    a.resize(0, 0);
    b.resize(0, 0);
    common::ids_of([0, 1, 1], a);
    common::ids_of([1, 0, 1], b);
    out.resize(0, 0);
    assert(common::alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(out[..] == "i0,0,1 e0,1,2 d2,1,3");
    out.resize(0, 0);
    assert(common::alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    assert(out[..] == "d0,1,0 e1,0,1 i2,1,1 e2,2,1");
    // The patience search finds the sole items of both texts.
    a.resize(0, 0);
    b.resize(0, 0);
    common::ids_of([1, 2, 3, 4], a);
    common::ids_of([1, 2, 3], b);
    out.resize(0, 0);
    assert(common::alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(out[..] == "e0,0,3 d3,1,3");
    // The LCS search gives the longest common subsequence, also when the
    // texts share a start. The crate similar builds its table from the
    // start of the texts and can miss it.
    a.resize(0, 0);
    b.resize(0, 0);
    common::ids_of([0, 0, 0, 0, 1, 0, 1, 0, 2, 0], a);
    common::ids_of([0, 0, 0, 2, 0, 1, 0, 1, 0, 0], b);
    out.resize(0, 0);
    assert(common::alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    var kept: i64 = 0;
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_ids_alg(a[..], b[..], diff::ALG_LCS, 2000, 50000000, ops);
    for o in ops { if o.tag == diff::OP_EQUAL { kept = kept + o.a_hi - o.a_lo; } }
    assert(kept == 9);
    // Empty and equal texts.
    a.resize(0, 0);
    b.resize(0, 0);
    out.resize(0, 0);
    assert(common::alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(common::alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    assert(out.len == 0);
}

fn test_patience_lcs_text() {
    var o = diff::default_options();
    o.algorithm = diff::ALG_PATIENCE;
    var out: u8[>..] = [];
    let code, exact = diff::unified_diff(out, "a\nb\nc\n", "a\nc\n", "x", "y", o);
    assert(code == diff::ERR_OK);
    assert(out[..] == "--- x\n+++ y\n@@ -1,3 +1,2 @@\n a\n-b\n c\n");
    o.algorithm = diff::ALG_LCS;
    out.resize(0, 0);
    let code2, exact2 = diff::unified_diff(out, "a\nb\nc\n", "a\nc\n", "x", "y", o);
    assert(code2 == diff::ERR_OK);
    assert(out[..] == "--- x\n+++ y\n@@ -1,3 +1,2 @@\n a\n-b\n c\n");
    // The token searches take the rule too.
    var to = diff::default_token_options();
    to.algorithm = diff::ALG_PATIENCE;
    var changes: diff::Change[>..] = [];
    assert(diff::diff_chars("abcd"[..], "abd"[..], to, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    to.algorithm = 5;
    assert(diff::diff_chars("abcd"[..], "abd"[..], to, changes) == diff::ERR_BAD_OPTION);
    o.algorithm = -1;
    assert(diff::unified_diff(out, "a"[..], "b"[..], "x", "y", o) == diff::ERR_BAD_OPTION);
}

fn test_patience_lcs_bounds() {
    // The LCS table has a cap. A pair of texts that needs more is a fault.
    var a: i32[>..] = [];
    var b: i32[>..] = [];
    for i in 5000 { a.push((i * 7 % 13) as! i32); b.push((i * 5 % 11) as! i32); }
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_ids_alg(a[..], b[..], diff::ALG_LCS, 2000, 500000000, ops);
    assert(code == diff::ERR_TOO_MUCH_WORK);
    assert(ops.len == 0);
    // The budget also bounds a small table.
    let c2, e2 = diff::diff_ids_alg(a[..], b[..], diff::ALG_LCS, 2000, 1000, ops);
    assert(c2 == diff::ERR_TOO_MUCH_WORK);
    // A patience search that hits the budget gives a valid diff that is not minimal.
    var big_a: i32[>..] = [];
    var big_b: i32[>..] = [];
    for i in 3000 { big_a.push((i % 50) as! i32); big_b.push(((i * 3 + 1) % 50) as! i32); }
    var pops: diff::Op[>..] = [];
    let c3, e3 = diff::diff_ids_alg(big_a[..], big_b[..], diff::ALG_PATIENCE, 2000, 20000, pops);
    assert(c3 == diff::ERR_OK && !e3);
    // The flag of a small patience diff comes from the check of the minimality.
    var sa: i32[>..] = [];
    var sb: i32[>..] = [];
    common::ids_of([2, 3, 3, 0, 0], sa);
    common::ids_of([3, 3, 3, 2, 0], sb);
    var sops: diff::Op[>..] = [];
    let c4, e4 = diff::diff_ids_alg(sa[..], sb[..], diff::ALG_PATIENCE, 2000, 50000000, sops);
    assert(c4 == diff::ERR_OK && !e4);
    var an: i64 = 0;
    var bn: i64 = 0;
    for o in pops { an = an + (o.a_hi - o.a_lo); bn = bn + (o.b_hi - o.b_lo); }
    assert(an == 3000 && bn == 3000);
    // The Patience search maps the ids to a dense range. Sparse and
    // negative ids give the same diff as their dense forms, not a crash.
    var ha: i32[>..] = [];
    var hb: i32[>..] = [];
    common::ids_of([11, 1, 2, 2, 3, 4, 4, 4, 5, 47, 19], ha);
    common::ids_of([10, 1, 2, 2, 8, 9, 4, 4, 7, 47, 18], hb);
    var hops: diff::Op[>..] = [];
    let c5, e5 = diff::diff_ids_alg(ha[..], hb[..], diff::ALG_PATIENCE, 2000, 50000000, hops);
    assert(c5 == diff::ERR_OK);
    var hout: u8[>..] = [];
    common::ops_text(hops[..], hout);
    assert(hout[..] == "r0,1,0,1 e1,1,3 r4,1,4,2 e5,6,2 r7,2,8,1 e9,9,1 r10,1,10,1");
    var na2: i32[>..] = [];
    var nb2: i32[>..] = [];
    common::ids_of([-7, 2147483647, -7, 2147483647], na2);
    common::ids_of([2147483647, -7], nb2);
    var nops: diff::Op[>..] = [];
    let c6, e6 = diff::diff_ids_alg(na2[..], nb2[..], diff::ALG_PATIENCE, 2000, 50000000, nops);
    assert(c6 == diff::ERR_OK);
    hout.resize(0, 0);
    common::ops_text(nops[..], hout);
    assert(hout[..] == "d0,1,0 e1,0,2 d3,1,2");
}
