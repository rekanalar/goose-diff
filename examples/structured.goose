// The search of two style sheets and the search of two JSON documents.
import std;
import diff from "..";

fn show(changes: const diff::Change[:], a: const u8[:], b: const u8[:]) {
    for c in changes {
        var text = a;
        if c.text == 1 { text = b; }
        var kind = "stay";
        if c.added { kind = "add "; }
        if c.removed { kind = "drop"; }
        print(kind, " : ", text[c.at..c.at + c.len], "\n");
    }
}

fn main() {
    let o = diff::default_token_options();
    var changes: diff::Change[>..] = [];
    let css_a = "a { color: red; }";
    let css_b = "a { color: blue; }";
    assert(diff::diff_css(css_a, css_b, o, changes) == diff::ERR_OK);
    show(changes[..], css_a, css_b);
    // The two documents hold the same keys in another order. Only the
    // value of "a" differs.
    var ca: u8[>..] = [];
    var cb: u8[>..] = [];
    var jchanges: diff::Change[>..] = [];
    let code, exact = diff::diff_json("{\"a\":1,\"b\":2}", "{\"b\":2,\"a\":3}", o, ca, cb, jchanges);
    assert(code == diff::ERR_OK);
    show(jchanges[..], ca[..], cb[..]);
}
