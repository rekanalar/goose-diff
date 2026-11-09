import std;
import diff from "..";

var seed: u64 = 12345;

fn rnd(n: i64) -> i64 {
    seed = seed * 6364136223846793005 + 1442695040888963407;
    return ((seed >> 33) as i64) % n;
}

// make_text builds a text of n lines drawn from `alpha` distinct lines.
fn make_text(out: u8[>..]&, n: i64, alpha: i64) {
    for i in n {
        out.push('a' + rnd(alpha) as! u8);
        if rnd(7) == 0 { out.push('b'); }
        if i + 1 < n || rnd(2) == 0 { out.push(10); }
    }
}

// lcs_len gives the length of the longest common subsequence of lines.
fn lcs_len(a: const u8[:], b: const u8[:]) -> i64 {
    var la: diff::Span[>..] = [];
    var lb: diff::Span[>..] = [];
    diff::split_lines(a, la);
    diff::split_lines(b, lb);
    var prev: i64[>..] = [];
    var cur: i64[>..] = [];
    prev.resize(lb.len + 1, 0);
    cur.resize(lb.len + 1, 0);
    for i in la.len {
        cur[0] = 0;
        for j in lb.len {
            if diff::span_equal(a, la[i], b, lb[j]) {
                cur[j + 1] = prev[j] + 1;
            } else if prev[j + 1] >= cur[j] {
                cur[j + 1] = prev[j + 1];
            } else {
                cur[j + 1] = cur[j];
            }
        }
        for j in lb.len + 1 { prev[j] = cur[j]; }
    }
    return prev[lb.len];
}

// check_ops tests that the opcodes tile both inputs, that the equal
// ranges hold equal lines, and gives the count of equal lines.
fn check_ops(a: const u8[:], b: const u8[:], ops: const diff::Op[:]) -> i64 {
    var la: diff::Span[>..] = [];
    var lb: diff::Span[>..] = [];
    diff::split_lines(a, la);
    diff::split_lines(b, lb);
    var ai: i64 = 0;
    var bi: i64 = 0;
    var equal: i64 = 0;
    for o in ops {
        assert(o.a_lo == ai && o.b_lo == bi);
        assert(o.a_hi >= o.a_lo && o.b_hi >= o.b_lo);
        if o.tag == diff::OP_EQUAL {
            assert(o.a_hi - o.a_lo == o.b_hi - o.b_lo && o.a_hi > o.a_lo);
            for k in o.a_hi - o.a_lo {
                assert(diff::span_equal(a, la[o.a_lo + k], b, lb[o.b_lo + k]));
            }
            equal = equal + (o.a_hi - o.a_lo);
        } else if o.tag == diff::OP_DELETE {
            assert(o.a_hi > o.a_lo && o.b_hi == o.b_lo);
        } else if o.tag == diff::OP_INSERT {
            assert(o.b_hi > o.b_lo && o.a_hi == o.a_lo);
        } else {
            assert(o.tag == diff::OP_REPLACE && o.a_hi > o.a_lo && o.b_hi > o.b_lo);
        }
        ai = o.a_hi;
        bi = o.b_hi;
    }
    assert(ai == la.len && bi == lb.len);
    return equal;
}

fn test_basic() {
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_lines("a\nb\nc\n", "a\nx\nc\n", diff::default_options(), ops);
    assert(code == diff::ERR_OK && exact && ops.len == 3);
    assert(ops[1].tag == diff::OP_REPLACE && ops[1].a_lo == 1 && ops[1].a_hi == 2);
    var e: diff::Op[>..] = [];
    let c2, x2 = diff::diff_lines("", "", diff::default_options(), e);
    assert(c2 == diff::ERR_OK && e.len == 0);
    let c3, x3 = diff::diff_lines("a\n", "", diff::default_options(), e);
    assert(e.len == 1 && e[0].tag == diff::OP_DELETE);
    var e4: diff::Op[>..] = [];
    let c4, x4 = diff::diff_lines("", "a\nb\n", diff::default_options(), e4);
    assert(e4.len == 1 && e4[0].tag == diff::OP_INSERT && e4[0].b_hi == 2);
    // A last line with no line end differs from the same line with one.
    var e5: diff::Op[>..] = [];
    let c5, x5 = diff::diff_lines("a\nb", "a\nb\n", diff::default_options(), e5);
    assert(e5.len == 2 && e5[1].tag == diff::OP_REPLACE);
}

fn test_random() {
    for round in 300 {
        var a: u8[>..] = [];
        var b: u8[>..] = [];
        make_text(a, rnd(40), 1 + rnd(8));
        make_text(b, rnd(40), 1 + rnd(8));
        var ops: diff::Op[>..] = [];
        let code, exact = diff::diff_lines(a[..], b[..], diff::default_options(), ops);
        assert(code == diff::ERR_OK && exact);
        let equal = check_ops(a[..], b[..], ops[..]);
        assert(equal == lcs_len(a[..], b[..]));
    }
}

fn test_bounds() {
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for i in 400 { a.push('a'); a.push(10); b.push('b'); b.push(10); }
    var o = diff::default_options();
    o.max_edits = 10;
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_lines(a[..], b[..], o, ops);
    assert(code == diff::ERR_OK && !exact);
    check_ops(a[..], b[..], ops[..]);
    o.max_input = 100;
    var keep: diff::Op[>..] = [];
    let c2, x2 = diff::diff_lines(a[..], b[..], o, keep);
    assert(c2 == diff::ERR_TOO_LARGE && keep.len == 0);
    o = diff::default_options();
    o.max_edits = 0;
    let c3, x3 = diff::diff_lines("a", "b", o, keep);
    assert(c3 == diff::ERR_BAD_OPTION && keep.len == 0);
    // A rule beyond its cap is a fault. A huge context or edit count
    // would wrap the arithmetic of the output or of the search trace.
    o = diff::default_options();
    o.context = 9223372036854775807;
    var ub: u8[>..] = [];
    let c4, x4 = diff::unified_diff(ub, a[..], b[..], "a", "b", o);
    assert(c4 == diff::ERR_BAD_OPTION && ub.len == 0);
    o.context = 3;
    o.max_edits = 3001;
    let c5, x5 = diff::diff_lines("a", "b", o, keep);
    assert(c5 == diff::ERR_BAD_OPTION && keep.len == 0);
}


const OLD: const u8[:] = "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl\n";
const NEW: const u8[:] = "a\nB\nc\nd\ne\nf\ng\nh\ni\nj\nk2\nl\nm";

// apply_text parses a patch and applies its first file to src.
fn apply_text(src: const u8[:], patch: const u8[:], reverse: bool, out: u8[>..]&) -> i64 {
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    let code = diff::patch_parse(patch, files, hunks, body);
    if code != diff::ERR_OK { return code; }
    var o = diff::default_apply_options();
    o.reverse = reverse;
    return diff::patch_apply(src, patch, files[..], hunks[..], body[..], 0, o, out);
}

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
    assert(apply_text(OLD, "--- o.txt\n+++ n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", false, out) == diff::ERR_OK);
    assert(out == NEW);
    var out2: u8[>..] = [];
    assert(apply_text(OLD, "Index: o.txt\n===================================================================\n--- o.txt\n+++ o.txt\n@@ -1,12 +1,13 @@\n a\n-b\n+B\n c\n d\n e\n f\n g\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", false, out2) == diff::ERR_OK);
    assert(out2 == NEW);
    var out3: u8[>..] = [];
    assert(apply_text(OLD, "diff --git a/o.txt b/n.txt\nindex 2f0b8ee..5199a9a 100644\n--- a/o.txt\n+++ b/n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@ g\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", false, out3) == diff::ERR_OK);
    assert(out3 == NEW);
    // The reverse apply gives the old text back.
    var back: u8[>..] = [];
    assert(apply_text(NEW, "--- o.txt\n+++ n.txt\n@@ -1,5 +1,5 @@\n a\n-b\n+B\n c\n d\n e\n@@ -8,5 +8,6 @@\n h\n i\n j\n-k\n+k2\n l\n+m\n\\ No newline at end of file\n", true, back) == diff::ERR_OK);
    assert(back == OLD);
}

fn test_patch_round_trip() {
    for round in 200 {
        var a: u8[>..] = [];
        var b: u8[>..] = [];
        make_text(a, rnd(60), 1 + rnd(10));
        make_text(b, rnd(60), 1 + rnd(10));
        var o = diff::default_options();
        o.context = rnd(5);
        var p: u8[>..] = [];
        let c, e = diff::unified_diff(p, a[..], b[..], "a", "b", o);
        assert(c == diff::ERR_OK);
        var out: u8[>..] = [];
        if p.len == 0 {
            assert(a.len == b.len);
        } else {
            assert(apply_text(a[..], p[..], false, out) == diff::ERR_OK);
            assert(out == b[..]);
            var back: u8[>..] = [];
            assert(apply_text(b[..], p[..], true, back) == diff::ERR_OK);
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
    assert(apply_text(moved[..], p[..], false, out) == diff::ERR_OK);
    var want: u8[>..] = [];
    for k in 10 { want.push('z'); want.push(10); }
    for ch in NEW { want.push(ch); }
    assert(out == want[..]);
    // A text that differs in a context line is a fault and writes nothing.
    var keep: u8[>..] = [7];
    assert(apply_text("a\nb\nc\nd\ne\nf\ng\nh\ni\nJ\nk\nl\n", p[..], false, keep) == diff::ERR_NO_MATCH);
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
    assert(apply_text("x\n", "--- a\n+++ b\n@@ -999999999999999 +1 @@\n-x\n+y\n", false, out) == diff::ERR_OK);
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

fn main() {
    test_basic();
    test_random();
    test_bounds();
    test_unified();
    test_patch_fixtures();
    test_patch_round_trip();
    test_patch_shift();
    test_patch_hostile();
    test_multi_file();
    print("all diff tests pass\n");
}
