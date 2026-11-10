// The inline changes of two texts: every line, with the changed words marked.
import std;
import diff from "..";

fn main() {
    let a = "keep this line\nthe quick brown fox\n";
    let b = "keep this line\nthe quick red fox\n";
    var changes: diff::InlineChange[>..] = [];
    var segs: diff::InlineSeg[>..] = [];
    let code = diff::inline_changes(a, b, diff::default_options(), changes, segs);
    print("code : ", diff::error_text(code), "\n");
    for c in changes {
        // An equal line and a deleted line read from the first text.
        var text = a;
        var line: u8[>..] = [];
        diff::put_text(line, "  ");
        if c.tag == diff::INL_INSERT { text = b; line[0] = '+'; }
        if c.tag == diff::INL_DELETE { line[0] = '-'; }
        for k in c.count {
            let s = segs[c.first + k];
            // A changed word stands between two stars.
            if s.emph { line.push('*'); }
            var n = s.len;
            // The line end stays out of the print.
            if text[s.at + n - 1] == 10 { n = n - 1; }
            for x in n { line.push(text[s.at + x]); }
            if s.emph { line.push('*'); }
        }
        print(line[..]);
    }
}
