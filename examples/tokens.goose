// The changes of the token searches of two texts.
import std;
import diff from "..";

// show_changes prints the changes of a search. The change holds the
// place of its text in the text it comes from.
fn show_changes(changes: const diff::Change[:], a: const u8[:], b: const u8[:]) {
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
    let a = "The quick brown fox.\n";
    let b = "The slow brown fox!\n";

    // The rules of a token search. The rule `algorithm` names the search.
    let o = diff::default_token_options();

    // The character search. Every character is one token.
    var changes: diff::Change[>..] = [];
    let code = diff::diff_chars(a, b, o, changes);
    print("code    : ", diff::error_text(code), "\n");
    show_changes(changes[..], a, b);

    // The trimmed line search. It cuts the white space at the ends of
    // the lines.
    changes.resize(0, diff::Change { at: 0, len: 0, count: 0, text: 0, added: false, removed: false });
    let code2 = diff::diff_lines_trimmed(a, b, o, changes);
    print("code    : ", diff::error_text(code2), "\n");
    show_changes(changes[..], a, b);

    // The sentence search. A sentence ends at a point, a mark or a
    // question mark.
    changes.resize(0, diff::Change { at: 0, len: 0, count: 0, text: 0, added: false, removed: false });
    let code3 = diff::diff_sentences(a, b, o, changes);
    print("code    : ", diff::error_text(code3), "\n");
    show_changes(changes[..], a, b);
}
