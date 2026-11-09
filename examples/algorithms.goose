// The four searches of a line diff.
import std;
import diff from "..";

fn main() {
    let a = "one\ntwo\nthree\nfour\n";
    let b = "one\nthree\nfive\nfour\n";
    for alg in [diff::ALG_MYERS, diff::ALG_RO, diff::ALG_PATIENCE, diff::ALG_LCS] {
        var o = diff::default_options();
        o.algorithm = alg;
        var out: u8[>..] = [];
        let code, exact = diff::unified_diff(out, a, b, "a", "b", o);
        assert(code == diff::ERR_OK);
        print("search ", alg, "\n", out[..]);
    }
}
