// The context diff of two texts.
import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

fn main() {
    var out: u8[>..] = [];
    let code, exact = diff::context_diff(out, "one\ntwo\nthree\nfour\n", "zero\none\ntree\nfour\n",
                                         "Original", "Current", diff::default_options());
    assert(code == diff::ERR_OK && exact);
    print(out[..]);
}
