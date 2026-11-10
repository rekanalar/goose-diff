// The word and grapheme diffs with the rules of Unicode, and the full case fold.
import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

fn show(a: const u8[:], b: const u8[:], o: diff::TokenOptions, words: bool) {
    var ch: diff::Change[>..] = [];
    var code: i64 = 0;
    var ex: bool = false;
    if words { code, ex = diff::diff_unicode_words(a, b, o, ch); } else { code, ex = diff::diff_graphemes(a, b, o, ch); }
    assert(code == diff::ERR_OK);
    for c in ch {
        var src: const u8[:] = b;
        if c.removed { src = a; }
        var line: u8[>..] = [];
        if c.added { line.push('+'); } else if c.removed { line.push('-'); } else { line.push('='); }
        line.push(' ');
        for k in c.len { line.push(src[c.at + k]); }
        print(line);
    }
}

fn main() {
    var o = diff::default_token_options();
    o.one_change_per_token = true;
    show("Hello wörld"[..], "Hello WÖRLD!"[..], o, true);
    show("éa"[..], "éb"[..], o, false);
    // The full case fold: the letter ß stays, the capital sigma folds alone.
    var ch: diff::Change[>..] = [];
    o.unicode_case = true;
    let code, ex = diff::diff_words("ΣΑΣ x"[..], "σας x"[..], o, ch);
    assert(code == diff::ERR_OK);
    print(ch.len);
}
