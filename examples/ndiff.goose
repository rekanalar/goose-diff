// The delta of two texts, and the first text back out of the delta.
import std;
import diff from "..";

fn main() {
    let a = "one\ntwo\nthree\n";
    let b = "ore\ntree\nemu\n";
    var delta: u8[>..] = [];
    let code = diff::ndiff(a, b, diff::default_options(), delta);
    assert(code == diff::ERR_OK);
    print(delta[..]);
    var first: u8[>..] = [];
    assert(diff::ndiff_restore(delta[..], 1, first) == diff::ERR_OK);
    assert(first[..] == a);
    print("restored the first text\n");
}
