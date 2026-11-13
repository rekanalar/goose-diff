// The tests of the group patch.
namespace patch_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import common;

const OLD: const u8[:] = "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl\n";
const NEW: const u8[:] = "a\nB\nc\nd\ne\nf\ng\nh\ni\nj\nk2\nl\nm";

fn test_unified() {
    var out: u8[>..] = [];
    let c, e = diff::unified_diff(out, OLD, NEW, "o.txt", "n.txt", diff::default_options());
    // The text of GNU diff -u, without the time stamps.
    assert(c == diff::ERR_OK && e);
    assert(out == "--- o.txt\n+++ n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n");
    // Equal texts give no output. No change at all, with context 0 too.
    var none: u8[>..] = [];
    let c2, e2 = diff::unified_diff(none, OLD, OLD, "a", "b", diff::default_options());
    assert(c2 == diff::ERR_OK && none.len == 0);
    // A name with a line end is a fault and writes nothing.
    var keep: u8[>..] = [1];
    let c3, e3 = diff::unified_diff(keep, OLD, NEW, "a\n+++ evil", "b", diff::default_options());
    assert(c3 == diff::ERR_BAD_NAME && keep.len == 1);
    // Context 0 gives hunks with no context lines.
    var zero: u8[>..] = [];
    var o0 = diff::default_options();
    o0.context = 0;
    let c4, e4 = diff::unified_diff(zero, "a\nb\nc\n", "a\nX\nc\n", "a", "b", o0);
    assert(zero == "--- a\n+++ b\n@@ -2 +2 @@\n-b\n+X\n");
    // An insert at the start names the line before it: 0.
    var ins: u8[>..] = [];
    let c5, e5 = diff::unified_diff(ins, "", "x\n", "a", "b", o0);
    assert(ins == "--- a\n+++ b\n@@ -0,0 +1 @@\n+x\n");
}

fn test_patch_fixtures() {
    // Patches from GNU diff, jsdiff and git diff apply to the old text.
    var out: u8[>..] = [];
    assert(common::apply_text(OLD, "--- o.txt\n+++ n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", false, out) == diff::ERR_OK);
    assert(out == NEW);
    var out2: u8[>..] = [];
    assert(common::apply_text(OLD, "Index: o.txt\n===================================================================\n--- o.txt\n+++ o.txt\n@@ -1,12 +1,13 @@\n a\n-b\n+B\n c\n d\n e\n f\n g\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", false, out2) == diff::ERR_OK);
    assert(out2 == NEW);
    var out3: u8[>..] = [];
    assert(common::apply_text(OLD, "diff --git a/o.txt b/n.txt\nindex 2f0b8ee..5199a9a 100644\n--- a/o.txt\n+++ b/n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@ g\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", false, out3) == diff::ERR_OK);
    assert(out3 == NEW);
    // The reverse apply gives the old text back.
    var back: u8[>..] = [];
    assert(common::apply_text(NEW, "--- o.txt\n+++ n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", true, back) == diff::ERR_OK);
    assert(back == OLD);
}

fn test_patch_round_trip() {
    for round in 200 {
        var a: u8[>..] = [];
        var b: u8[>..] = [];
        common::make_text(a, common::rnd(60), 1 + common::rnd(10));
        common::make_text(b, common::rnd(60), 1 + common::rnd(10));
        var o = diff::default_options();
        o.context = common::rnd(5);
        var p: u8[>..] = [];
        let c, e = diff::unified_diff(p, a[..], b[..], "a", "b", o);
        assert(c == diff::ERR_OK);
        var out: u8[>..] = [];
        if p.len == 0 {
            assert(a.len == b.len);
        } else {
            assert(common::apply_text(a[..], p[..], false, out) == diff::ERR_OK);
            assert(out == b[..]);
            var back: u8[>..] = [];
            assert(common::apply_text(b[..], p[..], true, back) == diff::ERR_OK);
            assert(back == a[..]);
        }
    }
}

fn test_patch_shift() {
    // A hunk finds its place when lines come before it.
    var p: u8[>..] = [];
    let c, e = diff::unified_diff(p, OLD, NEW, "a", "b", diff::default_options());
    var moved: u8[>..] = [];
    for k in 10 { moved.push('z'); moved.push(10); }
    for ch in OLD { moved.push(ch); }
    var out: u8[>..] = [];
    assert(common::apply_text(moved[..], p[..], false, out) == diff::ERR_OK);
    var want: u8[>..] = [];
    for k in 10 { want.push('z'); want.push(10); }
    for ch in NEW { want.push(ch); }
    assert(out == want[..]);
    // A text that differs in a context line is a fault and writes nothing.
    var keep: u8[>..] = [7];
    assert(common::apply_text("a\nb\nc\nd\ne\nf\ng\nh\ni\nJ\nk\nl\n", p[..], false, keep) == diff::ERR_NO_MATCH);
    assert(keep.len == 1);
}

fn test_patch_hostile() {
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    // The counts must match the lines.
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1,2 +1,2 @@\n x\n-y\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1 +1 @@\n-x\n+y\n+z\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    // A line that the counts do not ask for is a fault, as GNU patch reads it.
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1 +1 @@\n a\n+after\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    // Text between files, a new hunk and a marker line may follow a hunk.
    assert(diff::patch_parse("Index: f\n=== text\n--- a\n+++ b\n@@ -1 +1 @@\n-x\n+y\n\\ No newline at end of file\n--- c\n+++ d\n@@ -1 +1 @@\n-p\n+q\n", files, hunks, body) == diff::ERR_OK);
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1 +1 @@\n-x\n-z\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    // A huge count with few lines is a fault, with no allocation to match.
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1,999999999999999 +1 @@\n-x\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1,9999999999999999999 +1 @@\n-x\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    assert(diff::patch_parse("--- a\n+++ b\n@@ -x +1 @@\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1 +1\n-x\n+y\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1 +1 @@\n?x\n", files, hunks, body) == diff::ERR_BAD_PATCH);
    // A fault leaves the three buffers as they were.
    var f2: diff::FilePatch[>..] = [];
    var h2: diff::Hunk[>..] = [];
    var b2: diff::Span[>..] = [];
    assert(diff::patch_parse("--- a\n+++ b\n@@ -1 +1 @@\n?x\n", f2, h2, b2) == diff::ERR_BAD_PATCH);
    assert(f2.len == 0 && h2.len == 0 && b2.len == 0);
    // A hunk header far past the text is clamped, not searched step by step.
    var out: u8[>..] = [];
    assert(common::apply_text("x\n", "--- a\n+++ b\n@@ -999999999999999 +1 @@\n-x\n+y\n", false, out) == diff::ERR_OK);
    assert(out == "y\n");
    // A search over many equal lines spends from the budget.
    var big: u8[>..] = [];
    for k in 3000 { big.push('a'); big.push(10); }
    var pt: u8[>..] = [];
    pt.push('@'); pt.push('@'); pt.push(' '); pt.push('-'); pt.push('1'); pt.push(','); pt.push('1'); pt.push('0'); pt.push('0'); pt.push('0');
    pt.push(' '); pt.push('+'); pt.push('1'); pt.push(','); pt.push('9'); pt.push('9'); pt.push('9'); pt.push(' '); pt.push('@'); pt.push('@'); pt.push(10);
    for k in 999 { pt.push(' '); pt.push('a'); pt.push(10); }
    pt.push('-'); pt.push('b'); pt.push(10);
    var fl: diff::FilePatch[>..] = [];
    var hk: diff::Hunk[>..] = [];
    var bd: diff::Span[>..] = [];
    assert(diff::patch_parse(pt[..], fl, hk, bd) == diff::ERR_OK);
    var ao = diff::default_apply_options();
    ao.max_work = 100000;
    var sink: u8[>..] = [];
    assert(diff::patch_apply(big[..], pt[..], fl[..], hk[..], bd[..], 0, ao, sink) == diff::ERR_TOO_MUCH_WORK);
    assert(sink.len == 0);
    assert(diff::patch_apply(big[..], pt[..], fl[..], hk[..], bd[..], 3, ao, sink) == diff::ERR_NO_FILE);
}

fn test_multi_file() {
    let p = "diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-1\n+2\n--- a/y\n+++ b/y\n@@ -1 +1 @@\n-3\n+4\n";
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    assert(diff::patch_parse(p, files, hunks, body) == diff::ERR_OK);
    assert(files.len == 2 && hunks.len == 2);
    assert(p[files[1].new_name.at..files[1].new_name.at + files[1].new_name.len] == "b/y");
    var out: u8[>..] = [];
    assert(diff::patch_apply("3\n", p, files[..], hunks[..], body[..], 1, diff::default_apply_options(), out) == diff::ERR_OK);
    assert(out == "4\n");
}
