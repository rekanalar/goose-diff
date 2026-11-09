// The CSS search of the Node library diff.
namespace diff;

import std;

// tok_css gives the tokens of a style sheet. A token is one of the
// characters { } : ; and a comma, or a run of white space, or a run of
// other characters.
fn tok_css(text: const u8[:], o: TokenOptions, out: Span[>..]&) -> bool {
    var i: i64 = 0;
    while i < text.len {
        let c = text[i];
        var end = i + 1;
        if c == '{' || c == '}' || c == ':' || c == ';' || c == ',' {
            // One delimiter is one token.
        } else if tok_code_space(text, i) {
            end = i;
            while end < text.len && tok_code_space(text, end) { end = end + tok_width(text, end); }
        } else {
            end = i;
            while end < text.len {
                let d = text[end];
                if d == '{' || d == '}' || d == ':' || d == ';' || d == ',' || tok_code_space(text, end) { break; }
                end = end + tok_width(text, end);
            }
        }
        if end > text.len { end = text.len; }
        if out.len >= o.max_tokens { return false; }
        out.push(Span { at: i, len: end - i });
        i = end;
    }
    return true;
}

// diff_css adds the changes of a against b to `changes`. The search
// compares the tokens of two style sheets. It gives a code and a flag.
// The flag is true when the diff is minimal.
fn diff_css(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    if !tok_css(a, o, ta) || !tok_css(b, o, tb) { return ERR_TOO_LARGE, false; }
    return tok_run(a, ta[..], b, tb[..], o, false, changes);
}
