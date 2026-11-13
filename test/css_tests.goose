// The CSS diff of the package.
//
namespace css_tests;

import std;
import diff from "..";

import diff_checks;
fn test_css() {
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    let a = "a{b:c}";
    let b = "a{b:d}";
    assert(diff::diff_css(a, b, o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    diff_checks::check_change(changes[0], 0, 4, 4, 1, false, false);
    diff_checks::check_change(changes[1], 4, 1, 1, 0, false, true);
    diff_checks::check_change(changes[2], 4, 1, 1, 1, true, false);
    diff_checks::check_change(changes[3], 5, 1, 1, 1, false, false);
    // White space is a token of its own and it matters.
    diff_checks::clear_changes(changes);
    assert(diff::diff_css("a  b", "a b", o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    diff_checks::clear_changes(changes);
    assert(diff::diff_css(""[..], ""[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 0);
}
