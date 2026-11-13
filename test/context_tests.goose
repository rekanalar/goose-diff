// The context diff of the package.
//
namespace context_tests;

import std;
import diff from "..";

import diff_checks;
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
