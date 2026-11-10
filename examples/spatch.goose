// The structured patch: build one, flip it, apply it back.
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

fn put_text(out: u8[>..]&, s: const u8[:]) {
    for c in s { out.push(c); }
}

fn main() {
    var a: u8[>..] = [];
    put_text(a, "alpha\nbeta\ngamma\ndelta\nepsilon\n");
    var b: u8[>..] = [];
    put_text(b, "alpha\nbeta\nGAMMA\ndelta\nepsilon\n");
    let o = diff::default_options();
    var sp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hunks: diff::Hunk[>..] = [];
    var names: u8[>..] = [];
    var marks: u8[>..] = [];
    var body: u8[>..] = [];
    var lspans: diff::Span[>..] = [];
    // The structured patch of the two texts.
    assert(diff::structured_patch("f.c", "f.c", a[..], b[..], "1.0", "1.1", o, sp, hunks, names, marks, body, lspans) == diff::ERR_OK);
    var text: u8[>..] = [];
    assert(diff::format_patch(sp, hunks[..], names[..], marks[..], body[..], lspans[..], text) == diff::ERR_OK);
    print(text[..]);
    // The flip of the patch takes the text back.
    var fsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fhunks: diff::Hunk[>..] = [];
    var fnames: u8[>..] = [];
    var fmarks: u8[>..] = [];
    assert(diff::patch_reverse(sp, hunks[..], names[..], marks[..], fsp, fhunks, fnames, fmarks) == diff::ERR_OK);
    var back: u8[>..] = [];
    let ao = diff::default_apply_options();
    assert(diff::patch_apply_fuzz(b[..], fsp, fhunks[..], fmarks[..], body[..], lspans[..], ao, back) == diff::ERR_OK);
    print(back[..]);
    // A line that the patch does not hold may sit inside the hunk.
    // The rule fuzz takes one such mismatch.
    var mut: u8[>..] = [];
    put_text(mut, "alpha\nEXTRA\nbeta\ngamma\ndelta\nepsilon\n");
    var ao2 = diff::default_apply_options();
    ao2.fuzz = 1;
    var out2: u8[>..] = [];
    let code = diff::patch_apply_fuzz(mut[..], sp, hunks[..], marks[..], body[..], lspans[..], ao2, out2);
    print("apply with fuzz 1: code ", code, "\n");
    print(out2[..]);
}
