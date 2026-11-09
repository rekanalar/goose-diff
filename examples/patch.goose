// Read a unified patch, and apply it to a text.
import std;
import diff from "..";

fn main() {
    // A patch as GNU diff writes it.
    let patch_text = "--- old.txt\n+++ new.txt\n@@ -1,3 +1,3 @@\n one\n-two\n+two point five\n three\n";
    let original = "one\ntwo\nthree\n";

    // The read gives the files and the hunks of the patch.
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    let code = diff::patch_parse(patch_text, files, hunks, body);
    print("parse   : ", diff::error_text(code), "\n");
    print("files   : ", files.len, "\n");
    print("hunks   : ", hunks.len, "\n");

    // The apply gives the text after the patch.
    var out: u8[>..] = [];
    let c2 = diff::patch_apply(original, patch_text, files[..], hunks[..], body[..], 0,
                                diff::default_apply_options(), out);
    print("apply   : ", diff::error_text(c2), "\n");
    print("--- the text after the patch ---\n");
    print(out[..]);

    // The same patch the other way: the text comes back.
    var back: u8[>..] = [];
    var o = diff::default_apply_options();
    o.reverse = true;
    let c3 = diff::patch_apply(out[..], patch_text, files[..], hunks[..], body[..], 0, o, back);
    print("reverse : ", diff::error_text(c3), "\n");
    print("--- the text after the reverse ---\n");
    print(back[..]);
}
