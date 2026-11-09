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
            if diff::span_equal(a, la[i], b, lb[j], diff::Compare { fold: false, strip_cr: false }) {
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
                assert(diff::span_equal(a, la[o.a_lo + k], b, lb[o.b_lo + k], diff::Compare { fold: false, strip_cr: false }));
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

// ro_options gives the rules of the Ratcliff-Obershelp matcher.
fn ro_options() -> diff::Options {
    var o = diff::default_options();
    o.algorithm = diff::ALG_RO;
    return o;
}

fn test_matcher_blocks() {
    let o = ro_options();
    // The blocks of the matcher, as the Python library difflib gives them.
    var blocks: diff::Match[>..] = [];
    assert(diff::matcher_blocks("a\nb\nc\nd\ne\n", "a\nx\nc\nd\ne\n", o, blocks) == diff::ERR_OK);
    assert(blocks.len == 3);
    assert(blocks[0].a == 0 && blocks[0].b == 0 && blocks[0].size == 1);
    assert(blocks[1].a == 2 && blocks[1].b == 2 && blocks[1].size == 3);
    assert(blocks[2].a == 5 && blocks[2].b == 5 && blocks[2].size == 0);
    // The opcodes of the same texts.
    var ops: diff::Op[>..] = [];
    let code, exact = diff::matcher_opcodes("a\nb\nc\nd\ne\n", "a\nx\nc\nd\ne\n", o, ops);
    assert(code == diff::ERR_OK && exact && ops.len == 3);
    assert(ops[0].tag == diff::OP_EQUAL && ops[0].a_lo == 0 && ops[0].a_hi == 1);
    assert(ops[1].tag == diff::OP_REPLACE && ops[1].a_lo == 1 && ops[1].a_hi == 2);
    assert(ops[1].b_lo == 1 && ops[1].b_hi == 2);
    assert(ops[2].tag == diff::OP_EQUAL && ops[2].a_lo == 2 && ops[2].a_hi == 5);
    // Equal texts give one equal opcode.
    var eq: diff::Op[>..] = [];
    let c2, x2 = diff::matcher_opcodes("a\nb\nc\n", "a\nb\nc\n", o, eq);
    assert(c2 == diff::ERR_OK && eq.len == 1 && eq[0].tag == diff::OP_EQUAL);
    // An empty text against a text gives one insert.
    var ins: diff::Op[>..] = [];
    let c3, x3 = diff::matcher_opcodes("", "a\nb\n", o, ins);
    assert(c3 == diff::ERR_OK && ins.len == 1 && ins[0].tag == diff::OP_INSERT && ins[0].b_hi == 2);
    // The same search in the diff of the package.
    var dops: diff::Op[>..] = [];
    let c4, x4 = diff::diff_lines("a\nb\nc\nd\ne\n", "a\nx\nc\nd\ne\n", o, dops);
    assert(c4 == diff::ERR_OK && x4 && dops.len == 3);
    assert(dops[1].tag == diff::OP_REPLACE && dops[1].a_lo == 1 && dops[1].a_hi == 2);
}

fn test_matcher_longest() {
    let o = ro_options();
    let a = "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10\n";
    let b = "x\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\ny\n";
    let code, m = diff::matcher_longest(a, b, o, 0, 5, 0, 5);
    assert(code == diff::ERR_OK && m.a == 1 && m.b == 1 && m.size == 4);
    let code2, m2 = diff::matcher_longest(a, b, o, 3, 10, 3, 10);
    assert(code2 == diff::ERR_OK && m2.a == 3 && m2.b == 3 && m2.size == 6);
    // A range that holds no equal line gives an empty block.
    let code3, m3 = diff::matcher_longest(a, b, o, 0, 1, 0, 1);
    assert(code3 == diff::ERR_OK && m3.size == 0);
    // A range outside the texts is a fault.
    let code4, m4 = diff::matcher_longest(a, b, o, 0, 99, 0, 1);
    assert(code4 == diff::ERR_BAD_OPTION && m4.size == 0);
}

fn test_matcher_grouped() {
    let o = ro_options();
    let a = "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10\n";
    let b = "x\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\ny\n";
    var ops: diff::Op[>..] = [];
    var ends: i64[>..] = [];
    assert(diff::matcher_grouped(a, b, o, 3, ops, ends) == diff::ERR_OK);
    assert(ends.len == 2 && ends[0] == 2 && ends[1] == 4);
    assert(ops.len == 4);
    assert(ops[0].tag == diff::OP_REPLACE && ops[0].a_lo == 0 && ops[0].a_hi == 1);
    assert(ops[1].tag == diff::OP_EQUAL && ops[1].a_lo == 1 && ops[1].a_hi == 4);
    assert(ops[2].tag == diff::OP_EQUAL && ops[2].a_lo == 6 && ops[2].a_hi == 9);
    assert(ops[3].tag == diff::OP_REPLACE && ops[3].a_lo == 9 && ops[3].a_hi == 10);
    // The same hunks in the unified output.
    var out: u8[>..] = [];
    let c, e = diff::unified_diff(out, a, b, "a", "b", o);
    assert(c == diff::ERR_OK && e);
    assert(out == "--- a\n+++ b\n@@ -1,4 +1,4 @@\n-l1\n+x\n l2\n l3\n l4\n@@ -7,4 +7,4 @@\n l7\n l8\n l9\n-l10\n+y\n");
}

fn test_matcher_ratios() {
    let o = ro_options();
    let c, r = diff::matcher_ratio("a\nb\nc\nd\ne\n", "a\nx\nc\nd\ne\n", o);
    assert(c == diff::ERR_OK && r > 0.7999999 && r < 0.8000001);
    let c2, q = diff::matcher_quick_ratio("a\nb\nc\nd\ne\n", "a\nx\nc\nd\ne\n", o);
    assert(c2 == diff::ERR_OK && q > 0.7999999 && q < 0.8000001);
    let c3, t = diff::matcher_real_quick_ratio("a\nb\nc\nd\ne\n", "a\nx\nc\nd\ne\n", o);
    assert(c3 == diff::ERR_OK && t > 0.9999999 && t < 1.0000001);
    // Two empty texts give the ratio one.
    let c4, t2 = diff::matcher_real_quick_ratio("", "", o);
    assert(c4 == diff::ERR_OK && t2 > 0.9999999 && t2 < 1.0000001);
    // A text against an empty text gives the ratio zero.
    let c5, t3 = diff::matcher_ratio("a\n", "", o);
    assert(c5 == diff::ERR_OK && t3 < 0.0000001);
}

fn test_matcher_junk() {
    // A blank line is junk under the rule JUNK_BLANK.
    var o = ro_options();
    o.junk = diff::JUNK_BLANK;
    var ops: diff::Op[>..] = [];
    let c, e = diff::matcher_opcodes("\n", "a\n\n", o, ops);
    assert(c == diff::ERR_OK && ops.len == 1 && ops[0].tag == diff::OP_REPLACE);
    // Without the rule the blank line matches.
    var plain: diff::Op[>..] = [];
    let c2, e2 = diff::matcher_opcodes("\n", "a\n\n", ro_options(), plain);
    assert(c2 == diff::ERR_OK && plain.len == 2);
    assert(plain[0].tag == diff::OP_INSERT && plain[1].tag == diff::OP_EQUAL);
    // A line of one hash sign is junk under the rule JUNK_COMMENT.
    var o3 = ro_options();
    o3.junk = diff::JUNK_COMMENT;
    var ops3: diff::Op[>..] = [];
    assert(diff::matcher_opcodes("#\n", "a\n#\n", o3, ops3) == diff::ERR_OK);
    assert(ops3.len == 1 && ops3[0].tag == diff::OP_REPLACE);
    // Under the rule JUNK_BLANK the hash sign is no junk.
    var ops4: diff::Op[>..] = [];
    assert(diff::matcher_opcodes("#\n", "a\n#\n", o, ops4) == diff::ERR_OK);
    assert(ops4.len == 2 && ops4[1].tag == diff::OP_EQUAL);
}

fn test_matcher_popular() {
    // A line that appears often in the second text is junk under the
    // popular rule.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for k in 250 { a.push('x'); a.push(10); b.push('x'); b.push(10); }
    b[0] = 'y';
    b[499] = 'z';
    var o = ro_options();
    o.autojunk = true;
    var blocks: diff::Match[>..] = [];
    assert(diff::matcher_blocks(a[..], b[..], o, blocks) == diff::ERR_OK);
    assert(blocks.len == 1);
    assert(blocks[0].a == 250 && blocks[0].b == 250 && blocks[0].size == 0);
    // Without the rule the equal lines match.
    o.autojunk = false;
    var blocks2: diff::Match[>..] = [];
    assert(diff::matcher_blocks(a[..], b[..], o, blocks2) == diff::ERR_OK);
    assert(blocks2.len == 2);
    assert(blocks2[0].a == 0 && blocks2[0].b == 1 && blocks2[0].size == 248);
}

fn test_matcher_close() {
    // The words that match a word best, as the Python library gives them.
    var got: diff::Span[>..] = [];
    let cands = "ape\napple\npeach\npunch";
    assert(diff::close_matches("appel", cands, 3, 0.6, got) == diff::ERR_OK);
    assert(got.len == 2);
    assert(cands[got[0].at..got[0].at + got[0].len] == "apple");
    assert(cands[got[1].at..got[1].at + got[1].len] == "ape");
    // The count of the words is a limit.
    var one: diff::Span[>..] = [];
    assert(diff::close_matches("appel", cands, 1, 0.6, one) == diff::ERR_OK);
    assert(one.len == 1);
    // A word that matches no word gives nothing.
    var none: diff::Span[>..] = [];
    assert(diff::close_matches("zzz", cands, 3, 0.6, none) == diff::ERR_OK);
    assert(none.len == 0);
    // A count of words below zero is a fault.
    var bad: diff::Span[>..] = [];
    assert(diff::close_matches("appel", cands, -1, 0.6, bad) == diff::ERR_BAD_OPTION);
}

fn test_matcher_bounds() {
    // A search that needs too much work is a fault.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for k in 500 { a.push('x'); a.push(10); b.push('x'); b.push(10); }
    var o = ro_options();
    o.autojunk = false;
    o.max_work = 1000;
    var ops: diff::Op[>..] = [];
    assert(diff::matcher_opcodes(a[..], b[..], o, ops) == diff::ERR_TOO_MUCH_WORK);
    assert(ops.len == 0);
    // The walk over the lines of the search spends from the budget too.
    var c: u8[>..] = [];
    var d: u8[>..] = [];
    for k in 3000 {
        c.push('a' + (k % 26) as! u8);
        c.push(10);
        d.push('a' + ((k + 1) % 26) as! u8);
        d.push(10);
    }
    o.max_work = 100;
    var ops2: diff::Op[>..] = [];
    assert(diff::matcher_opcodes(c[..], d[..], o, ops2) == diff::ERR_TOO_MUCH_WORK);
    assert(ops2.len == 0);
    // A rule out of range is a fault.
    var o2 = ro_options();
    o2.algorithm = 9;
    var ops3: diff::Op[>..] = [];
    assert(diff::matcher_opcodes("a\n", "b\n", o2, ops3) == diff::ERR_BAD_OPTION);
    var o3 = ro_options();
    o3.junk = 5;
    assert(diff::matcher_opcodes("a\n", "b\n", o3, ops3) == diff::ERR_BAD_OPTION);
    var o4 = ro_options();
    o4.max_work = 500000001;
    assert(diff::matcher_opcodes("a\n", "b\n", o4, ops3) == diff::ERR_BAD_OPTION);
}

// clear_changes empties the list of changes.
fn clear_changes(changes: diff::Change[>..]&) {
    changes.resize(0, diff::Change { at: 0, len: 0, count: 0, text: 0, added: false, removed: false });
}

// check_change tells whether a change holds the given values. The text
// of a change says which text it comes from.
fn check_change(c: diff::Change, at: i64, len: i64, count: i64, text: i64,
                added: bool, removed: bool) -> bool {
    return c.at == at && c.len == len && c.count == count && c.text == text &&
           c.added == added && c.removed == removed;
}

fn test_token_chars() {
    // The changes of the character search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_chars("hello world"[..], "hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 6);
    assert(check_change(changes[0], 0, 6, 6, 1, false, false));
    assert(check_change(changes[1], 6, 2, 2, 0, false, true));
    assert(check_change(changes[2], 6, 3, 3, 1, true, false));
    assert(check_change(changes[3], 9, 1, 1, 1, false, false));
    assert(check_change(changes[4], 9, 2, 2, 0, false, true));
    assert(check_change(changes[5], 10, 1, 1, 1, true, false));
    // The same text gives one change that stays.
    clear_changes(changes);
    assert(diff::diff_chars("abc"[..], "abc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 3, 3, 1, false, false));
    // Two texts with no character in common.
    clear_changes(changes);
    assert(diff::diff_chars("xy"[..], "ab"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(check_change(changes[0], 0, 2, 2, 0, false, true));
    assert(check_change(changes[1], 0, 2, 2, 1, true, false));
    // An empty text gives no change.
    clear_changes(changes);
    assert(diff::diff_chars(""[..], "abc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 3, 3, 1, true, false));
}

fn test_token_trimmed() {
    // The changes of the trimmed line search. It cuts the white space at
    // the ends of the lines.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_lines_trimmed("  a \n b  \n"[..], "  a \n b  \n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 10, 2, 1, false, false));
    // The white space at the ends of a line does not matter.
    clear_changes(changes);
    assert(diff::diff_lines_trimmed("one\n"[..], "two\nthree\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(check_change(changes[0], 0, 4, 1, 0, false, true));
    assert(check_change(changes[1], 0, 10, 2, 1, true, false));
    // The lines differ only in their white space.
    clear_changes(changes);
    assert(diff::diff_lines_trimmed("  a \n"[..], "a\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 2, 1, 1, false, false));
}

fn test_token_sentences() {
    // The changes of the sentence search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_sentences("One. Two! Three? Four."[..], "One. Two! Three? Five."[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 17, 6, 1, false, false));
    assert(check_change(changes[1], 17, 5, 1, 0, false, true));
    assert(check_change(changes[2], 17, 5, 1, 1, true, false));
    // A text of one sentence gives one change.
    clear_changes(changes);
    assert(diff::diff_sentences("Hello world"[..], "Hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(check_change(changes[0], 0, 11, 1, 0, false, true));
    assert(check_change(changes[1], 0, 11, 1, 1, true, false));
}

fn test_token_arrays() {
    // The changes of the array search. The tokens stand in the texts.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    var ta: diff::Span[>..] = [];
    var tb: diff::Span[>..] = [];
    ta.push(diff::Span { at: 0, len: 1 });
    ta.push(diff::Span { at: 1, len: 1 });
    tb.push(diff::Span { at: 0, len: 1 });
    tb.push(diff::Span { at: 1, len: 1 });
    assert(diff::diff_arrays("ab"[..], "xy"[..], ta[..], tb[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(check_change(changes[0], 0, 2, 2, 0, false, true));
    assert(check_change(changes[1], 0, 2, 2, 1, true, false));
    // One token on each side.
    clear_changes(changes);
    ta.resize(0, diff::Span { at: 0, len: 0 });
    tb.resize(0, diff::Span { at: 0, len: 0 });
    ta.push(diff::Span { at: 0, len: 1 });
    tb.push(diff::Span { at: 0, len: 1 });
    assert(diff::diff_arrays("a"[..], "b"[..], ta[..], tb[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(check_change(changes[0], 0, 1, 1, 0, false, true));
    assert(check_change(changes[1], 0, 1, 1, 1, true, false));
    // The same token on each side gives one change that stays.
    clear_changes(changes);
    assert(diff::diff_arrays("a"[..], "a"[..], ta[..], tb[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 1, 1, 1, false, false));
}

fn test_token_switches() {
    var changes: diff::Change[>..] = [];
    // The case switch. The fold covers the Latin letters of ASCII.
    var oc = diff::default_token_options();
    oc.ignore_case = true;
    assert(diff::diff_chars("Hello"[..], "hello"[..], oc, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 5, 5, 1, false, false));
    clear_changes(changes);
    let o = diff::default_token_options();
    assert(diff::diff_chars("Hello"[..], "hello"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 1, 1, 0, false, true));
    assert(check_change(changes[1], 0, 1, 1, 1, true, false));
    assert(check_change(changes[2], 1, 4, 4, 1, false, false));
    // The white space switch. It cuts the white space at the ends of a
    // token.
    clear_changes(changes);
    var ow = diff::default_token_options();
    ow.ignore_whitespace = true;
    assert(diff::diff_chars("a "[..], "a"[..], ow, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(check_change(changes[1], 1, 1, 1, 0, false, true));
    // The carriage return switch. It drops the carriage return that
    // stands before a line feed.
    clear_changes(changes);
    var ocr = diff::default_token_options();
    ocr.strip_trailing_cr = true;
    assert(diff::diff_chars("a\r\n"[..], "a\n"[..], ocr, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 2, 2, 1, false, false));
    clear_changes(changes);
    assert(diff::diff_chars("a\r\n"[..], "a\n"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(check_change(changes[1], 1, 1, 1, 0, false, true));
    assert(check_change(changes[2], 1, 1, 1, 1, false, false));
    // The line end switch. It gives the line end a token of its own.
    clear_changes(changes);
    var onl = diff::default_token_options();
    onl.newline_is_token = true;
    assert(diff::diff_lines_trimmed("a\nb"[..], "a\nc"[..], onl, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 2, 2, 1, false, false));
    assert(check_change(changes[1], 2, 1, 1, 0, false, true));
    assert(check_change(changes[2], 2, 1, 1, 1, true, false));
    // The carriage return switch of the line search.
    clear_changes(changes);
    var ol = diff::default_options();
    ol.strip_trailing_cr = true;
    var ops: diff::Op[>..] = [];
    assert(diff::diff_lines("a\r\n"[..], "a\n"[..], ol, ops) == diff::ERR_OK);
    assert(ops.len == 1);
    assert(ops[0].tag == diff::OP_EQUAL);
    var ol2 = diff::default_options();
    var ops2: diff::Op[>..] = [];
    assert(diff::diff_lines("a\r\n"[..], "a\n"[..], ol2, ops2) == diff::ERR_OK);
    assert(ops2.len == 1);
    assert(ops2[0].tag == diff::OP_REPLACE);
}

fn test_token_broken() {
    // A text with a broken code point keeps the bytes of the broken point
    // in one character.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_chars("a\x80b"[..], "a\x80c"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 2, 2, 1, false, false));
    assert(check_change(changes[1], 2, 1, 1, 0, false, true));
    assert(check_change(changes[2], 2, 1, 1, 1, true, false));
}

fn test_token_bounds() {
    var changes: diff::Change[>..] = [];
    // A rule out of range is a fault.
    let o = diff::default_token_options();
    var ob = diff::default_token_options();
    ob.max_edits = 0;
    assert(diff::diff_chars("a"[..], "b"[..], ob, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    var ob2 = diff::default_token_options();
    ob2.algorithm = 9;
    assert(diff::diff_chars("a"[..], "b"[..], ob2, changes) == diff::ERR_BAD_OPTION);
    var ob3 = diff::default_token_options();
    ob3.max_work = 500000001;
    assert(diff::diff_chars("a"[..], "b"[..], ob3, changes) == diff::ERR_BAD_OPTION);
    // An input over the limit is a fault.
    var ob4 = diff::default_token_options();
    ob4.max_input = 1;
    assert(diff::diff_chars("ab"[..], "b"[..], ob4, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    // The search spends from the budget of the work.
    var ob5 = diff::default_token_options();
    ob5.algorithm = diff::ALG_RO;
    ob5.max_work = 1;
    assert(diff::diff_chars("abc"[..], "abd"[..], ob5, changes) == diff::ERR_TOO_MUCH_WORK);
    assert(changes.len == 0);
    // More tokens than the rule allows is a fault.
    var ob6 = diff::default_token_options();
    ob6.max_tokens = 1;
    assert(diff::diff_chars("ab"[..], "ab"[..], ob6, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    var ob7 = diff::default_token_options();
    ob7.max_tokens = 8000001;
    assert(diff::diff_chars("ab"[..], "ab"[..], ob7, changes) == diff::ERR_BAD_OPTION);
    // A span outside its text is a fault.
    var bad: diff::Span[>..] = [];
    bad.push(diff::Span { at: 0, len: 100 });
    assert(diff::diff_arrays("ab"[..], "cd"[..], bad[..], bad[..], o, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    var bad2: diff::Span[>..] = [];
    bad2.push(diff::Span { at: -1, len: 1 });
    assert(diff::diff_arrays("ab"[..], "cd"[..], bad2[..], bad2[..], o, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    // The line search counts its lines too.
    var ol = diff::default_options();
    ol.max_tokens = 1;
    var ops: diff::Op[>..] = [];
    assert(diff::diff_lines("a\nb\n"[..], "a\nc\n"[..], ol, ops) == diff::ERR_TOO_LARGE);
    assert(ops.len == 0);
    // The Myers search spends from the budget of the work. The diff
    // stays valid, but it is not minimal.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for k in 200 {
        a.push('a' + (k % 26) as! u8);
        a.push(10);
        b.push('a' + ((k + 1) % 26) as! u8);
        b.push(10);
    }
    var ow = diff::default_options();
    ow.max_work = 100;
    var ops2: diff::Op[>..] = [];
    let code, exact = diff::diff_lines(a[..], b[..], ow, ops2);
    assert(code == diff::ERR_OK);
    assert(!exact);
}

fn test_token_words() {
    // The changes of the word search. The white space between the words
    // does not matter to the search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_words("hello world"[..], "hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 6, 1, 1, false, false));
    assert(check_change(changes[1], 6, 5, 1, 0, false, true));
    assert(check_change(changes[2], 6, 5, 1, 1, true, false));
    // A word in the middle.
    clear_changes(changes);
    assert(diff::diff_words("foo bar baz"[..], "foo qux baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    assert(check_change(changes[0], 0, 4, 1, 1, false, false));
    assert(check_change(changes[1], 4, 3, 1, 0, false, true));
    assert(check_change(changes[2], 4, 3, 1, 1, true, false));
    assert(check_change(changes[3], 7, 4, 1, 1, false, false));
    // The white space between the words does not matter.
    clear_changes(changes);
    assert(diff::diff_words("a  b"[..], "a b"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 3, 2, 1, false, false));
    // The line end is a part of the white space.
    clear_changes(changes);
    assert(diff::diff_words("foo\nbar baz"[..], "foo baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 3, 1, 1, false, false));
    assert(check_change(changes[1], 3, 4, 1, 0, false, true));
    assert(check_change(changes[2], 3, 4, 1, 1, false, false));
    // A word with a letter outside ASCII.
    clear_changes(changes);
    assert(diff::diff_words("caf\xC3\xA9 noir"[..], "caf\xC3\xA9 blanc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 6, 1, 1, false, false));
    assert(check_change(changes[1], 6, 4, 1, 0, false, true));
    assert(check_change(changes[2], 6, 5, 1, 1, true, false));
}

fn test_token_words_with_space() {
    // The changes of the word search with space. The white space between
    // the words matters to the search.
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    assert(diff::diff_words_with_space("hello world"[..], "hello there"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 6, 2, 1, false, false));
    assert(check_change(changes[1], 6, 5, 1, 0, false, true));
    assert(check_change(changes[2], 6, 5, 1, 1, true, false));
    // The white space between the words matters.
    clear_changes(changes);
    assert(diff::diff_words_with_space("a  b"[..], "a b"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    assert(check_change(changes[0], 0, 1, 1, 1, false, false));
    assert(check_change(changes[1], 1, 2, 1, 0, false, true));
    assert(check_change(changes[2], 1, 1, 1, 1, true, false));
    assert(check_change(changes[3], 2, 1, 1, 1, false, false));
    // The line end is a token of its own.
    clear_changes(changes);
    assert(diff::diff_words_with_space("foo\nbar baz"[..], "foo baz"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 3, 1, 1, false, false));
    assert(check_change(changes[1], 3, 4, 2, 0, false, true));
    assert(check_change(changes[2], 3, 4, 2, 1, false, false));
    // A word with a letter outside ASCII.
    clear_changes(changes);
    assert(diff::diff_words_with_space("caf\xC3\xA9 noir"[..], "caf\xC3\xA9 blanc"[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    assert(check_change(changes[0], 0, 6, 2, 1, false, false));
    assert(check_change(changes[1], 6, 4, 1, 0, false, true));
    assert(check_change(changes[2], 6, 5, 1, 1, true, false));
}

fn test_token_word_bounds() {
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    // More words than the rule allows is a fault.
    var ob = diff::default_token_options();
    ob.max_tokens = 1;
    assert(diff::diff_words("a b"[..], "a b"[..], ob, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    assert(diff::diff_words_with_space("a b"[..], "a b"[..], ob, changes) == diff::ERR_TOO_LARGE);
    assert(changes.len == 0);
    // A rule out of range is a fault.
    var ob2 = diff::default_token_options();
    ob2.max_edits = 0;
    assert(diff::diff_words("a"[..], "b"[..], ob2, changes) == diff::ERR_BAD_OPTION);
    assert(changes.len == 0);
    // An empty text gives no change.
    let o2 = diff::default_token_options();
    assert(diff::diff_words(""[..], ""[..], o2, changes) == diff::ERR_OK);
    assert(changes.len == 0);
    // The move of the white space sees only the changes of this call.
    // A change of an earlier call stays as it is.
    let long = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    assert(diff::diff_words(long[..], "aaa"[..], o2, changes) == diff::ERR_OK);
    let after = changes.len;
    assert(diff::diff_words("y"[..], " x"[..], o2, changes) == diff::ERR_OK);
    assert(changes.len == after + 2);
    // A carriage return that stands alone is a part of its own.
    clear_changes(changes);
    assert(diff::diff_words_with_space("x\r"[..], "x\r"[..], o2, changes) == diff::ERR_OK);
    assert(changes.len == 1);
    assert(check_change(changes[0], 0, 2, 2, 1, false, false));
}

// nd_run runs ndiff and gives the code.
fn nd_run(a: const u8[:], b: const u8[:], o: diff::Options, out: u8[>..]&) -> i64 {
    return diff::ndiff(a, b, o, out);
}

fn test_ndiff() {
    var d: u8[>..] = [];
    // The example of the Python documentation.
    assert(nd_run("one\ntwo\nthree\n", "ore\ntree\nemu\n", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "- one\n?  ^\n+ ore\n?  ^\n- two\n- three\n?  -\n+ tree\n+ emu\n");
    d.resize(0, 0);
    assert(nd_run("same\nalpha\nbravo\n", "same\nalpha\nbravo!\n", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "  same\n  alpha\n- bravo\n+ bravo!\n?      +\n");
    // The tab stays in the line of hints, so the marks line up.
    d.resize(0, 0);
    assert(nd_run("\tabcDefghiJkl\n", "\tabcdefGhijkl\n", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "- \tabcDefghiJkl\n? \t   ^  ^  ^\n+ \tabcdefGhijkl\n? \t   ^  ^  ^\n");
    // A line without a line end gets one.
    d.resize(0, 0);
    assert(nd_run("a", "b", diff::default_options(), d) == diff::ERR_OK);
    assert(d[..] == "- a\n+ b\n");
    // Empty texts.
    d.resize(0, 0);
    assert(nd_run(""[..], ""[..], diff::default_options(), d) == diff::ERR_OK);
    assert(d.len == 0);
}

fn test_ndiff_restore() {
    var d: u8[>..] = [];
    let a = "one\ntwo\nthree\n";
    let b = "ore\ntree\nemu\n";
    assert(nd_run(a, b, diff::default_options(), d) == diff::ERR_OK);
    var r1: u8[>..] = [];
    var r2: u8[>..] = [];
    assert(diff::ndiff_restore(d[..], 1, r1) == diff::ERR_OK);
    assert(diff::ndiff_restore(d[..], 2, r2) == diff::ERR_OK);
    assert(r1[..] == a);
    assert(r2[..] == b);
    // The number of a text is 1 or 2. A fault leaves the buffer alone.
    assert(diff::ndiff_restore(d[..], 3, r1) == diff::ERR_BAD_OPTION);
    assert(diff::ndiff_restore(d[..], 0, r1) == diff::ERR_BAD_OPTION);
    assert(r1[..] == a);
    // Lines with other codes give nothing.
    var r3: u8[>..] = [];
    assert(diff::ndiff_restore("? hint\n-x\n\n  keep\n"[..], 1, r3) == diff::ERR_OK);
    assert(r3[..] == "keep\n");
}

fn test_ndiff_bounds() {
    // Many close lines spend work. A small budget gives a fault and
    // leaves the buffer as it was.
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    for i in 300 {
        for k in 40 { a.push('a' + (k % 7) as! u8); b.push('a' + (k % 7) as! u8); }
        a.push('x');
        b.push('y');
        a.push(10);
        b.push(10);
    }
    var o = diff::default_options();
    o.max_work = 1000;
    var d: u8[>..] = ['k'];
    assert(diff::ndiff(a[..], b[..], o, d) == diff::ERR_TOO_MUCH_WORK);
    assert(d.len == 1);
    o.max_work = 50000000;
    assert(diff::ndiff(a[..], b[..], o, d) == diff::ERR_OK);
    assert(d.len > 1);
    var bad = diff::default_options();
    bad.max_work = -1;
    assert(diff::ndiff(a[..], b[..], bad, d) == diff::ERR_BAD_OPTION);
    var small = diff::default_options();
    small.max_input = 10;
    assert(diff::ndiff(a[..], b[..], small, d) == diff::ERR_TOO_LARGE);
    // The scan of pairs that a cheap ratio rules out spends work too.
    var p: u8[>..] = [];
    var q: u8[>..] = [];
    for i in 3000 { p.push('A'); p.push('A'); p.push('A'); p.push('A'); p.push(10); q.push('b'); q.push(10); }
    var ow = diff::default_options();
    ow.max_work = 20000;
    var pd: u8[>..] = [];
    assert(diff::ndiff(p[..], q[..], ow, pd) == diff::ERR_TOO_MUCH_WORK);
    assert(pd.len == 0);
    // The delta may grow to several times the input, so no cap on it.
    var c1: u8[>..] = [];
    var c2: u8[>..] = [];
    for i in 200 { for w in 4 { c1.push('a' + w as! u8); } c1.push(10); for w in 3 { c2.push('a' + w as! u8); } c2.push('z'); c2.push(10); }
    var oc = diff::default_options();
    oc.max_input = c1.len;
    var cd: u8[>..] = [];
    assert(diff::ndiff(c1[..], c2[..], oc, cd) == diff::ERR_OK);
    // Broken bytes and carriage returns do not stop the search.
    var h: u8[>..] = [];
    var g: u8[>..] = [];
    for i in 50 { h.push(0xff); h.push(13); h.push(10); g.push(0x80); g.push(13); g.push(10); }
    var hd: u8[>..] = [];
    assert(diff::ndiff(h[..], g[..], diff::default_options(), hd) == diff::ERR_OK);
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
    test_matcher_blocks();
    test_matcher_longest();
    test_matcher_grouped();
    test_matcher_ratios();
    test_matcher_junk();
    test_matcher_popular();
    test_matcher_close();
    test_matcher_bounds();
    test_token_chars();
    test_token_trimmed();
    test_token_sentences();
    test_token_arrays();
    test_token_switches();
    test_token_broken();
    test_token_bounds();
    test_token_words();
    test_token_words_with_space();
    test_token_word_bounds();
    test_ndiff();
    test_ndiff_restore();
    test_ndiff_bounds();
    print("all diff tests pass\n");
}
