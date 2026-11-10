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

fn test_context() {
    var d: u8[>..] = [];
    let code, exact = diff::context_diff(d, "one\ntwo\nthree\nfour\n", "zero\none\ntree\nfour\n",
                                         "Original", "Current", diff::default_options());
    assert(code == diff::ERR_OK);
    assert(d[..] == "*** Original\n--- Current\n***************\n*** 1,4 ****\n  one\n! two\n! three\n  four\n--- 1,4 ----\n+ zero\n  one\n! tree\n  four\n");
    // A pure insert has no lines in the first part. A pure delete has none in the second.
    d.resize(0, 0);
    assert(diff::context_diff(d, "a\n", "a\nb\n", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d[..] == "*** x\n--- y\n***************\n*** 1 ****\n--- 1,2 ----\n  a\n+ b\n");
    d.resize(0, 0);
    assert(diff::context_diff(d, "a\nb\n", "a\n", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d[..] == "*** x\n--- y\n***************\n*** 1,2 ****\n  a\n- b\n--- 1 ----\n");
    // Equal texts give nothing.
    d.resize(0, 0);
    assert(diff::context_diff(d, "a\n", "a\n", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d.len == 0);
    // A name with a line end is a fault and the buffer stays.
    d.push('k');
    assert(diff::context_diff(d, "a\n", "b\n", "x\ny", "y", diff::default_options()) == diff::ERR_BAD_NAME);
    assert(d.len == 1);
    var small = diff::default_options();
    small.max_input = 1;
    assert(diff::context_diff(d, "aa\n", "b\n", "x", "y", small) == diff::ERR_TOO_LARGE);
    // A line without a line end gets the marker line.
    d.resize(0, 0);
    assert(diff::context_diff(d, "a", "b", "x", "y", diff::default_options()) == diff::ERR_OK);
    assert(d[..] == "*** x\n--- y\n***************\n*** 1 ****\n! a\n\\ No newline at end of file\n--- 1 ----\n! b\n\\ No newline at end of file\n");
}

// change_text gives the text of a change from the text that holds it.
fn change_text(c: diff::Change, a: const u8[:], b: const u8[:]) -> const u8[:] {
    if c.text == 1 { return b[c.at..c.at + c.len]; }
    return a[c.at..c.at + c.len];
}

fn test_css() {
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    let a = "a{b:c}";
    let b = "a{b:d}";
    assert(diff::diff_css(a, b, o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    check_change(changes[0], 0, 4, 4, 1, false, false);
    check_change(changes[1], 4, 1, 1, 0, false, true);
    check_change(changes[2], 4, 1, 1, 1, true, false);
    check_change(changes[3], 5, 1, 1, 1, false, false);
    // White space is a token of its own and it matters.
    clear_changes(changes);
    assert(diff::diff_css("a  b", "a b", o, changes) == diff::ERR_OK);
    assert(changes.len == 4);
    clear_changes(changes);
    assert(diff::diff_css(""[..], ""[..], o, changes) == diff::ERR_OK);
    assert(changes.len == 0);
}

fn json_form(text: const u8[:], out: u8[>..]&) -> i64 {
    return diff::json_canonical(text, diff::default_token_options(), out);
}

fn test_json_canonical() {
    var out: u8[>..] = [];
    assert(json_form("{\"b\":1,\"a\":[true,null,{}],\"c\":{}}", out) == diff::ERR_OK);
    assert(out[..] == "{\n  \"a\": [\n    true,\n    null,\n    {}\n  ],\n  \"b\": 1,\n  \"c\": {}\n}");
    // Array indexes come first, then the other keys. The last duplicate wins.
    out.resize(0, 0);
    assert(json_form("{\"b\":1,\"10\":2,\"2\":3,\"b\":4}", out) == diff::ERR_OK);
    assert(out[..] == "{\n  \"2\": 3,\n  \"10\": 2,\n  \"b\": 4\n}");
    // The numbers follow JavaScript.
    out.resize(0, 0);
    assert(json_form("[1.0,1e2,-0,1e21,1e-7,0.000001,123456789012345678901,1e400,0.1]", out) == diff::ERR_OK);
    assert(out[..] == "[\n  1,\n  100,\n  0,\n  1e+21,\n  1e-7,\n  0.000001,\n  123456789012345680000,\n  null,\n  0.1\n]");
    // The strings escape as JSON.stringify writes them.
    out.resize(0, 0);
    assert(json_form("\"a\\u0001\\ud800\\n/\"", out) == diff::ERR_OK);
    assert(out[..] == "\"a\\u0001\\ud800\\n/\"");
    // A UTF-16 sort puts U+FFFF before a character above U+FFFF.
    out.resize(0, 0);
    assert(json_form("{\"\\ud83d\\ude00\":1,\"\\uffee\":2}", out) == diff::ERR_OK);
    assert(out[..] == "{\n  \"😀\": 1,\n  \"￮\": 2\n}");
}

fn test_json_diff() {
    var ca: u8[>..] = ['x'];
    var cb: u8[>..] = [];
    var changes: diff::Change[>..] = [];
    let o = diff::default_token_options();
    let a = "{\"a\":1,\"b\":2}";
    let b = "{\"b\":2,\"a\":3}";
    let code, exact = diff::diff_json(a, b, o, ca, cb, changes);
    assert(code == diff::ERR_OK);
    assert(ca[..] == "{\n  \"a\": 1,\n  \"b\": 2\n}");
    assert(cb[..] == "{\n  \"a\": 3,\n  \"b\": 2\n}");
    assert(changes.len == 4);
    assert(change_text(changes[1], ca[..], cb[..]) == "  \"a\": 1,\n");
    assert(changes[1].removed);
    assert(change_text(changes[2], ca[..], cb[..]) == "  \"a\": 3,\n");
    assert(changes[2].added);
    // A line that differs by a comma is equal and the longer line stays.
    clear_changes(changes);
    assert(diff::diff_json_text("x,\ny\n", "x\ny,\n", o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(!changes[0].added && !changes[0].removed && changes[0].text == 0);
    assert(!changes[1].added && !changes[1].removed && changes[1].text == 1);
    // A fault leaves the buffers as they were.
    clear_changes(changes);
    assert(diff::diff_json("{", b, o, ca, cb, changes) == diff::ERR_BAD_JSON);
    assert(diff::diff_json(a, "[1,]", o, ca, cb, changes) == diff::ERR_BAD_JSON);
    assert(ca.len > 1 && changes.len == 0);
}

fn test_json_bounds() {
    // A text that nests very deep does not overflow the stack, and the
    // output cap stops its quadratic indent.
    var deep: u8[>..] = [];
    for i in 100000 { deep.push('['); }
    for i in 100000 { deep.push(']'); }
    var out: u8[>..] = ['k'];
    let c = diff::json_canonical(deep[..], diff::default_token_options(), out);
    assert(c == diff::ERR_TOO_LARGE || c == diff::ERR_OK);
    if c != diff::ERR_OK { assert(out.len == 1); }
    var o = diff::default_token_options();
    o.max_input = 20;
    assert(diff::json_canonical("[1,2,3,4,5,6,7,8,9,10,11,12]", o, out) == diff::ERR_TOO_LARGE);
    // Many equal keys keep one.
    var dup: u8[>..] = ['{'];
    for i in 5000 { dup.push('"'); dup.push('a'); dup.push('"'); dup.push(':'); dup.push('1'); dup.push(','); }
    dup.push('"'); dup.push('b'); dup.push('"'); dup.push(':'); dup.push('2'); dup.push('}');
    var d2: u8[>..] = [];
    assert(diff::json_canonical(dup[..], diff::default_token_options(), d2) == diff::ERR_OK);
    assert(d2[..] == "{\n  \"a\": 1,\n  \"b\": 2\n}");
    assert(diff::json_canonical("nul"[..], diff::default_token_options(), d2) == diff::ERR_BAD_JSON);
}

fn test_json_review() {
    var o = diff::default_token_options();
    var out: u8[>..] = [];
    // The cap holds while the containers close.
    var deep: u8[>..] = [];
    for i in 3000 { deep.push('['); }
    for i in 3000 { deep.push(']'); }
    o.max_input = 6000;
    assert(diff::json_canonical(deep[..], o, out) == diff::ERR_OK || out.len <= 6000 * 8 + 4096 + 4);
    var big: u8[>..] = [];
    for i in 20000 { big.push('['); }
    for i in 20000 { big.push(']'); }
    o.max_input = 40000;
    var tiny = o;
    tiny.max_input = 40000;
    assert(diff::json_canonical(big[..], tiny, out) == diff::ERR_TOO_LARGE);
    assert(out.len == 0);
    // A huge limit does not wrap the cap.
    var huge = diff::default_token_options();
    huge.max_input = 2305843009213693952;
    assert(diff::json_canonical("[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]"[..], huge, out) == diff::ERR_OK);
    // Keys that differ in broken bytes only still keep one of each.
    var raw: u8[>..] = [];
    var text: u8[>..] = [];
    text.push('{'); text.push('"'); text.push(0xC3); text.push(0x83); text.push('"'); text.push(':'); text.push('1'); text.push(',');
    text.push('"'); text.push(0xC3); text.push('"'); text.push(':'); text.push('2'); text.push(',');
    text.push('"'); text.push(0xC3); text.push(0x83); text.push('"'); text.push(':'); text.push('3'); text.push('}');
    var c: u8[>..] = [];
    assert(diff::json_canonical(text[..], diff::default_token_options(), c) == diff::ERR_OK);
    var keys: i64 = 0;
    for k in c.len { if c[k] == '"' { keys = keys + 1; } }
    assert(keys == 4);
}

// ids_of gives the ids of a list of small numbers.
fn ids_of(v: const i32[:], out: i32[>..]&) {
    for x in v { out.push(x); }
}

// ops_text writes the ops as the Rust crate similar names them.
recursive fn put_n(out: u8[>..]&, v: i64) {
    if v >= 10 { put_n(out, v / 10); }
    out.push('0' + (v % 10) as! u8);
}

fn ops_text(ops: const diff::Op[:], out: u8[>..]&) {
    for o in ops {
        if out.len > 0 { out.push(' '); }
        if o.tag == diff::OP_EQUAL { out.push('e'); put_n(out, o.a_lo); out.push(','); put_n(out, o.b_lo); out.push(','); put_n(out, o.a_hi - o.a_lo); }
        else if o.tag == diff::OP_DELETE { out.push('d'); put_n(out, o.a_lo); out.push(','); put_n(out, o.a_hi - o.a_lo); out.push(','); put_n(out, o.b_lo); }
        else if o.tag == diff::OP_INSERT { out.push('i'); put_n(out, o.a_lo); out.push(','); put_n(out, o.b_lo); out.push(','); put_n(out, o.b_hi - o.b_lo); }
        else { out.push('r'); put_n(out, o.a_lo); out.push(','); put_n(out, o.a_hi - o.a_lo); out.push(','); put_n(out, o.b_lo); out.push(','); put_n(out, o.b_hi - o.b_lo); }
    }
}

fn alg_run(a: const i32[:], b: const i32[:], alg: i64, out: u8[>..]&) -> i64 {
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_ids_alg(a, b, alg, 2000, 50000000, ops);
    ops_text(ops[..], out);
    return code;
}

fn test_patience_lcs() {
    // The cases come from the Rust crate similar 2.7.0.
    var a: i32[>..] = [];
    var b: i32[>..] = [];
    ids_of([11, 1, 2, 2, 3, 4, 4, 4, 5, 47, 19], a);
    ids_of([10, 1, 2, 2, 8, 9, 4, 4, 7, 47, 18], b);
    var out: u8[>..] = [];
    assert(alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(out[..] == "r0,1,0,1 e1,1,3 r4,1,4,2 e5,6,2 r7,2,8,1 e9,9,1 r10,1,10,1");
    out.resize(0, 0);
    assert(alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    assert(out[..] == "r0,1,0,1 e1,1,3 r4,2,4,2 e6,6,2 r8,1,8,1 e9,9,1 r10,1,10,1");
    // A case where the three searches differ.
    a.resize(0, 0);
    b.resize(0, 0);
    ids_of([0, 1, 1], a);
    ids_of([1, 0, 1], b);
    out.resize(0, 0);
    assert(alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(out[..] == "i0,0,1 e0,1,2 d2,1,3");
    out.resize(0, 0);
    assert(alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    assert(out[..] == "d0,1,0 e1,0,1 i2,1,1 e2,2,1");
    // The patience search finds the sole items of both texts.
    a.resize(0, 0);
    b.resize(0, 0);
    ids_of([1, 2, 3, 4], a);
    ids_of([1, 2, 3], b);
    out.resize(0, 0);
    assert(alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(out[..] == "e0,0,3 d3,1,3");
    // The LCS search gives the longest common subsequence, also when the
    // texts share a start. The crate similar builds its table from the
    // start of the texts and can miss it.
    a.resize(0, 0);
    b.resize(0, 0);
    ids_of([0, 0, 0, 0, 1, 0, 1, 0, 2, 0], a);
    ids_of([0, 0, 0, 2, 0, 1, 0, 1, 0, 0], b);
    out.resize(0, 0);
    assert(alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    var kept: i64 = 0;
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_ids_alg(a[..], b[..], diff::ALG_LCS, 2000, 50000000, ops);
    for o in ops { if o.tag == diff::OP_EQUAL { kept = kept + o.a_hi - o.a_lo; } }
    assert(kept == 9);
    // Empty and equal texts.
    a.resize(0, 0);
    b.resize(0, 0);
    out.resize(0, 0);
    assert(alg_run(a[..], b[..], diff::ALG_PATIENCE, out) == diff::ERR_OK);
    assert(alg_run(a[..], b[..], diff::ALG_LCS, out) == diff::ERR_OK);
    assert(out.len == 0);
}

fn test_patience_lcs_text() {
    var o = diff::default_options();
    o.algorithm = diff::ALG_PATIENCE;
    var out: u8[>..] = [];
    let code, exact = diff::unified_diff(out, "a\nb\nc\n", "a\nc\n", "x", "y", o);
    assert(code == diff::ERR_OK);
    assert(out[..] == "--- x\n+++ y\n@@ -1,3 +1,2 @@\n a\n-b\n c\n");
    o.algorithm = diff::ALG_LCS;
    out.resize(0, 0);
    let code2, exact2 = diff::unified_diff(out, "a\nb\nc\n", "a\nc\n", "x", "y", o);
    assert(code2 == diff::ERR_OK);
    assert(out[..] == "--- x\n+++ y\n@@ -1,3 +1,2 @@\n a\n-b\n c\n");
    // The token searches take the rule too.
    var to = diff::default_token_options();
    to.algorithm = diff::ALG_PATIENCE;
    var changes: diff::Change[>..] = [];
    assert(diff::diff_chars("abcd"[..], "abd"[..], to, changes) == diff::ERR_OK);
    assert(changes.len == 3);
    to.algorithm = 4;
    assert(diff::diff_chars("abcd"[..], "abd"[..], to, changes) == diff::ERR_BAD_OPTION);
    o.algorithm = -1;
    assert(diff::unified_diff(out, "a"[..], "b"[..], "x", "y", o) == diff::ERR_BAD_OPTION);
}

fn test_patience_lcs_bounds() {
    // The LCS table has a cap. A pair of texts that needs more is a fault.
    var a: i32[>..] = [];
    var b: i32[>..] = [];
    for i in 5000 { a.push((i * 7 % 13) as! i32); b.push((i * 5 % 11) as! i32); }
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_ids_alg(a[..], b[..], diff::ALG_LCS, 2000, 500000000, ops);
    assert(code == diff::ERR_TOO_MUCH_WORK);
    assert(ops.len == 0);
    // The budget also bounds a small table.
    let c2, e2 = diff::diff_ids_alg(a[..], b[..], diff::ALG_LCS, 2000, 1000, ops);
    assert(c2 == diff::ERR_TOO_MUCH_WORK);
    // A patience search that hits the budget gives a valid diff that is not minimal.
    var big_a: i32[>..] = [];
    var big_b: i32[>..] = [];
    for i in 3000 { big_a.push((i % 50) as! i32); big_b.push(((i * 3 + 1) % 50) as! i32); }
    var pops: diff::Op[>..] = [];
    let c3, e3 = diff::diff_ids_alg(big_a[..], big_b[..], diff::ALG_PATIENCE, 2000, 20000, pops);
    assert(c3 == diff::ERR_OK && !e3);
    // The flag of a small patience diff comes from the check of the minimality.
    var sa: i32[>..] = [];
    var sb: i32[>..] = [];
    ids_of([2, 3, 3, 0, 0], sa);
    ids_of([3, 3, 3, 2, 0], sb);
    var sops: diff::Op[>..] = [];
    let c4, e4 = diff::diff_ids_alg(sa[..], sb[..], diff::ALG_PATIENCE, 2000, 50000000, sops);
    assert(c4 == diff::ERR_OK && !e4);
    var an: i64 = 0;
    var bn: i64 = 0;
    for o in pops { an = an + (o.a_hi - o.a_lo); bn = bn + (o.b_hi - o.b_lo); }
    assert(an == 3000 && bn == 3000);
    // The Patience search maps the ids to a dense range. Sparse and
    // negative ids give the same diff as their dense forms, not a crash.
    var ha: i32[>..] = [];
    var hb: i32[>..] = [];
    ids_of([11, 1, 2, 2, 3, 4, 4, 4, 5, 47, 19], ha);
    ids_of([10, 1, 2, 2, 8, 9, 4, 4, 7, 47, 18], hb);
    var hops: diff::Op[>..] = [];
    let c5, e5 = diff::diff_ids_alg(ha[..], hb[..], diff::ALG_PATIENCE, 2000, 50000000, hops);
    assert(c5 == diff::ERR_OK);
    var hout: u8[>..] = [];
    ops_text(hops[..], hout);
    assert(hout[..] == "r0,1,0,1 e1,1,3 r4,1,4,2 e5,6,2 r7,2,8,1 e9,9,1 r10,1,10,1");
    var na2: i32[>..] = [];
    var nb2: i32[>..] = [];
    ids_of([-7, 2147483647, -7, 2147483647], na2);
    ids_of([2147483647, -7], nb2);
    var nops: diff::Op[>..] = [];
    let c6, e6 = diff::diff_ids_alg(na2[..], nb2[..], diff::ALG_PATIENCE, 2000, 50000000, nops);
    assert(c6 == diff::ERR_OK);
    hout.resize(0, 0);
    ops_text(nops[..], hout);
    assert(hout[..] == "d0,1,0 e1,0,2 d3,1,2");
}

fn put_text(out: u8[>..]&, s: const u8[:]) {
    for c in s { out.push(c); }
}

fn eof_run(a: const u8[:], b: const u8[:], rev: bool) -> bool {
    let o = diff::default_options();
    var sp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu: diff::Hunk[>..] = [];
    var nn: u8[>..] = [];
    var mk: u8[>..] = [];
    var bd: u8[>..] = [];
    var ls: diff::Span[>..] = [];
    assert(diff::structured_patch("f", "f", a, b, "", "", o, sp, hu, nn, mk, bd, ls) == diff::ERR_OK);
    var out: u8[>..] = [];
    let ao = diff::default_apply_options();
    if !rev {
        assert(diff::patch_apply_fuzz(a, sp, hu[..], mk[..], bd[..], ls[..], ao, out) == diff::ERR_OK);
        return out[..] == b;
    }
    var fsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fh: diff::Hunk[>..] = [];
    var fn2: u8[>..] = [];
    var fm: u8[>..] = [];
    assert(diff::patch_reverse(sp, hu[..], nn[..], mk[..], fsp, fh, fn2, fm) == diff::ERR_OK);
    assert(diff::patch_apply_fuzz(b, fsp, fh[..], fm[..], bd[..], ls[..], ao, out) == diff::ERR_OK);
    return out[..] == a;
}

fn test_spatch_eof() {
    // The last line end is part of the text. The apply keeps it, adds
    // it or drops it as the patch says, as jsdiff does.
    assert(eof_run("a\nb\n", "a\nB", false));
    assert(eof_run("a\nb", "a\nB\n", false));
    assert(eof_run("a\nb", "a\nb\nc", false));
    assert(eof_run("a\nb\n", "a\nb", false));
    assert(eof_run("a\nb\n", "a\nB", true));
    assert(eof_run("a\nb", "a\nB\n", true));
    assert(eof_run("", "x", false));
    assert(eof_run("x", "", false));
}


fn test_spatch() {
    // The bytes of jsdiff 8.0.4, pinned from a run of the library.
    var a1: u8[>..] = [];
    put_text(a1, "line one\nline two\nline three\n");
    var b1: u8[>..] = [];
    put_text(b1, "line one\nline 2!\nline three\n");
    var sp1: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu: diff::Hunk[>..] = [];
    var names: u8[>..] = [];
    var marks: u8[>..] = [];
    var body: u8[>..] = [];
    var lspans: diff::Span[>..] = [];
    var o = diff::default_options();
    o.context = 3;
    assert(diff::structured_patch("a.txt", "b.txt", a1[..], b1[..], "old h", "v1", o, sp1, hu, names, marks, body, lspans) == diff::ERR_OK);
    var out: u8[>..] = [];
    out.resize(0, 0);
    assert(diff::format_patch(sp1, hu[..], names[..], marks[..], body[..], lspans[..], out) == diff::ERR_OK);
    assert(out[..] == "===================================================================\n--- a.txt\told h\n+++ b.txt\tv1\n@@ -1,3 +1,3 @@\n line one\n-line two\n+line 2!\n line three\n");
    // The line of Index: appears when the two names are equal.
    var sp2: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu2: diff::Hunk[>..] = [];
    var names2: u8[>..] = [];
    var marks2: u8[>..] = [];
    var body2: u8[>..] = [];
    var lspans2: diff::Span[>..] = [];
    var a2: u8[>..] = [];
    put_text(a2, "alpha\nbeta\ngamma\ndelta\nepsilon\n");
    var b2: u8[>..] = [];
    put_text(b2, "alpha\nbeta\nGAMMA\ndelta\nepsilon\n");
    out.resize(0, 0);
    assert(diff::create_patch("f.c", a2[..], b2[..], "r1", "1.1", o, sp2, hu2, names2, marks2, body2, lspans2, out) == diff::ERR_OK);
    assert(out[..] == "Index: f.c\n===================================================================\n--- f.c\tr1\n+++ f.c\t1.1\n@@ -1,5 +1,5 @@\n alpha\n beta\n-gamma\n+GAMMA\n delta\n epsilon\n");
    // An empty header holds its tab. A count of one holds its comma.
    var sp3: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu3: diff::Hunk[>..] = [];
    var names3: u8[>..] = [];
    var marks3: u8[>..] = [];
    var body3: u8[>..] = [];
    var lspans3: diff::Span[>..] = [];
    var a3: u8[>..] = [];
    put_text(a3, "a\nb\nc\n");
    var b3: u8[>..] = [];
    put_text(b3, "a\nb\nC\nd\n");
    assert(diff::structured_patch("x.txt", "y.txt", a3[..], b3[..], "", "", o, sp3, hu3, names3, marks3, body3, lspans3) == diff::ERR_OK);
    out.resize(0, 0);
    assert(diff::format_patch(sp3, hu3[..], names3[..], marks3[..], body3[..], lspans3[..], out) == diff::ERR_OK);
    assert(out[..] == "===================================================================\n--- x.txt\t\n+++ y.txt\t\n@@ -1,3 +1,4 @@\n a\n b\n-c\n+C\n+d\n");
    // A text that ends without a line end adds the marker line.
    var a4: u8[>..] = [];
    put_text(a4, "a\nb\n");
    var b4: u8[>..] = [];
    put_text(b4, "a\nB");
    var sp4: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu4: diff::Hunk[>..] = [];
    var names4: u8[>..] = [];
    var marks4: u8[>..] = [];
    var body4: u8[>..] = [];
    var lspans4: diff::Span[>..] = [];
    out.resize(0, 0);
    assert(diff::create_patch("f", a4[..], b4[..], "x", "y", o, sp4, hu4, names4, marks4, body4, lspans4, out) == diff::ERR_OK);
    assert(out[..] == "Index: f\n===================================================================\n--- f\tx\n+++ f\ty\n@@ -1,2 +1,2 @@\n a\n-b\n+B\n\\ No newline at end of file\n");
    // An empty old file names the line before.
    var a5: u8[>..] = [];
    var b5: u8[>..] = [];
    put_text(b5, "x\n");
    var sp5: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu5: diff::Hunk[>..] = [];
    var names5: u8[>..] = [];
    var marks5: u8[>..] = [];
    var body5: u8[>..] = [];
    var lspans5: diff::Span[>..] = [];
    out.resize(0, 0);
    assert(diff::create_patch("f", a5[..], b5[..], "x", "y", o, sp5, hu5, names5, marks5, body5, lspans5, out) == diff::ERR_OK);
    assert(out[..] == "Index: f\n===================================================================\n--- f\tx\n+++ f\ty\n@@ -0,0 +1,1 @@\n+x\n");
    var a6: u8[>..] = [];
    put_text(a6, "x\n");
    var sp6: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu6: diff::Hunk[>..] = [];
    var names6: u8[>..] = [];
    var marks6: u8[>..] = [];
    var body6: u8[>..] = [];
    var lspans6: diff::Span[>..] = [];
    out.resize(0, 0);
    assert(diff::create_patch("f", a6[..], a5[..], "x", "y", o, sp6, hu6, names6, marks6, body6, lspans6, out) == diff::ERR_OK);
    assert(out[..] == "Index: f\n===================================================================\n--- f\tx\n+++ f\ty\n@@ -1,1 +0,0 @@\n-x\n");
    // Equal texts give no hunk.
    var sp7: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu7: diff::Hunk[>..] = [];
    var names7: u8[>..] = [];
    var marks7: u8[>..] = [];
    var body7: u8[>..] = [];
    var lspans7: diff::Span[>..] = [];
    assert(diff::structured_patch("a", "b", a1[..], a1[..], "", "", o, sp7, hu7, names7, marks7, body7, lspans7) == diff::ERR_OK);
    assert(sp7.hunks == 0);
    // The reader fills the same model, and the writer writes the same bytes.
    var ptext: u8[>..] = [];
    put_text(ptext, "===================================================================\n--- a.txt\told h\n+++ b.txt\tv1\n@@ -1,3 +1,3 @@\n line one\n-line two\n+line 2!\n line three\n");
    var rsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var rhu: diff::Hunk[>..] = [];
    var rnames: u8[>..] = [];
    var rmarks: u8[>..] = [];
    var rbody: u8[>..] = [];
    var rlspans: diff::Span[>..] = [];
    assert(diff::patch_parse_structured(ptext[..], 0, rsp, rhu, rnames, rmarks, rbody, rlspans) == diff::ERR_OK);
    assert(rsp.hunks == 1 && rhu[0].old_start == 1 && rhu[0].old_lines == 3 && rhu[0].new_start == 1 && rhu[0].new_lines == 3);
    out.resize(0, 0);
    assert(diff::format_patch(rsp, rhu[..], rnames[..], rmarks[..], rbody[..], rlspans[..], out) == diff::ERR_OK);
    assert(out[..] == "===================================================================\n--- a.txt\told h\n+++ b.txt\tv1\n@@ -1,3 +1,3 @@\n line one\n-line two\n+line 2!\n line three\n");
    // The flip swaps the names, the ranges and the marks. The apply of
    // the flip takes the text back.
    var fsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fhu: diff::Hunk[>..] = [];
    var fnames: u8[>..] = [];
    var fmarks: u8[>..] = [];
    assert(diff::patch_reverse(sp1, hu[..], names[..], marks[..], fsp, fhu, fnames, fmarks) == diff::ERR_OK);
    var ftxt: u8[>..] = [];
    assert(diff::format_patch(fsp, fhu[..], fnames[..], fmarks[..], body[..], lspans[..], ftxt) == diff::ERR_OK);
    assert(ftxt[..] == "===================================================================\n--- b.txt\tv1\n+++ a.txt\told h\n@@ -1,3 +1,3 @@\n line one\n+line two\n-line 2!\n line three\n");
    var ao = diff::default_apply_options();
    var back: u8[>..] = [];
    assert(diff::patch_apply_fuzz(b1[..], fsp, fhu[..], fmarks[..], body[..], lspans[..], ao, back) == diff::ERR_OK);
    assert(back[..] == "line one\nline two\nline three\n");
    // A leading context line that changed cannot take an added line, as in jsdiff.
    var oldf: u8[>..] = [];
    put_text(oldf, "a\nb\nXXXX\nd\ne\nf\ng\nh\n");
    var newf: u8[>..] = [];
    put_text(newf, "a\nb\nYYYY\nd\ne\nf\ng\nh\n");
    var spo: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var huo: diff::Hunk[>..] = [];
    var nno: u8[>..] = [];
    var mko: u8[>..] = [];
    var bdo: u8[>..] = [];
    var lso: diff::Span[>..] = [];
    o.context = 1;
    assert(diff::structured_patch("a", "b", oldf[..], newf[..], "", "", o, spo, huo, nno, mko, bdo, lso) == diff::ERR_OK);
    o.context = 3;
    var mut: u8[>..] = [];
    put_text(mut, "a\nB2\nXXXX\nd\ne\nf\ng\nh\n");
    ao.fuzz = 1;
    var fout: u8[>..] = [];
    assert(diff::patch_apply_fuzz(mut[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, fout) == diff::ERR_NO_MATCH);
    assert(fout.len == 0);
    // A source line before the leading context applies with fuzz, as in jsdiff.
    var extra: u8[>..] = [];
    put_text(extra, "a\nEXTRA\nb\nXXXX\nd\ne\nf\ng\nh\n");
    ao.fuzz = 1;
    var f3: u8[>..] = [];
    assert(diff::patch_apply_fuzz(extra[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, f3) == diff::ERR_OK);
    assert(f3[..] == "a\nEXTRA\nb\nYYYY\nd\ne\nf\ng\nh\n");
    // A removed line that changed never applies, at any fuzz.
    var mutd: u8[>..] = [];
    put_text(mutd, "a\nb\nXXXY\nd\ne\nf\ng\nh\n");
    ao.fuzz = 5;
    var f4: u8[>..] = [];
    assert(diff::patch_apply_fuzz(mutd[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, f4) == diff::ERR_NO_MATCH);
    // A value of fuzz past the cap is a fault.
    ao.fuzz = 101;
    var f5: u8[>..] = [];
    assert(diff::patch_apply_fuzz(oldf[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, f5) == diff::ERR_BAD_OPTION);
    // The budget stops a hostile patch.
    var big: u8[>..] = [];
    for i in 2000 { put_text(big, "z\n"); }
    var spb: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hub: diff::Hunk[>..] = [];
    var nnb: u8[>..] = [];
    var mkb: u8[>..] = [];
    var bdb: u8[>..] = [];
    var lsb: diff::Span[>..] = [];
    var newb: u8[>..] = [];
    put_text(newb, "y\n");
    assert(diff::structured_patch("a", "b", a6[..], newb[..], "", "", o, spb, hub, nnb, mkb, bdb, lsb) == diff::ERR_OK);
    ao.fuzz = 5;
    ao.max_work = 500;
    var f6: u8[>..] = [];
    assert(diff::patch_apply_fuzz(big[..], spb, hub[..], mkb[..], bdb[..], lsb[..], ao, f6) == diff::ERR_TOO_MUCH_WORK);
    assert(f6.len == 0);
    // The XML form escapes the hostile text, as jsdiff does.
    var ca: u8[>..] = [];
    put_text(ca, "a&b\"");
    var cb: u8[>..] = [];
    put_text(cb, "a<b>");
    var to = diff::default_token_options();
    var chs: diff::Change[>..] = [];
    assert(diff::diff_chars(ca[..], cb[..], to, chs) == diff::ERR_OK);
    var xout: u8[>..] = [];
    assert(diff::changes_xml(chs[..], ca[..], cb[..], xout) == diff::ERR_OK);
    assert(xout[..] == "a<del>&amp;</del><ins>&lt;</ins>b<del>&quot;</del><ins>&gt;</ins>");
    var dout: u8[>..] = [];
    assert(diff::changes_dmp(chs[..], ca[..], cb[..], dout) == diff::ERR_OK);
    assert(dout[..] == "[[0,\"a\"],[-1,\"&\"],[1,\"<\"],[0,\"b\"],[-1,\"\\\"\"],[1,\">\"]]");
    // A fault leaves every buffer as it was.
    var obad = diff::default_options();
    obad.max_work = -1;
    var spx: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hux: diff::Hunk[>..] = [];
    hux.push(diff::Hunk { old_start: 9, old_lines: 9, new_start: 9, new_lines: 9, first_line: 9, lines: 9 });
    var nnx: u8[>..] = [];
    var mkx: u8[>..] = [];
    var bdx: u8[>..] = [];
    var lsx: diff::Span[>..] = [];
    nnx.push(7);
    assert(diff::structured_patch("a", "b", a1[..], b1[..], "", "", obad, spx, hux, nnx, mkx, bdx, lsx) == diff::ERR_BAD_OPTION);
    assert(hux.len == 1 && nnx.len == 1 && mkx.len == 0 && spx.hunks == 0);
    // A source that is shorter than the hunk never reads past its end.
    var shortp: u8[>..] = [];
    put_text(shortp, "@@ -1,2 +1,2 @@\n a\n b\n");
    var ssp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var shu: diff::Hunk[>..] = [];
    var snm: u8[>..] = [];
    var smk: u8[>..] = [];
    var sbd: u8[>..] = [];
    var sls: diff::Span[>..] = [];
    assert(diff::patch_parse_structured(shortp[..], 0, ssp, shu, snm, smk, sbd, sls) == diff::ERR_OK);
    var ssrc: u8[>..] = [];
    put_text(ssrc, "x\n");
    var sfz = diff::default_apply_options();
    sfz.fuzz = 1;
    var sout: u8[>..] = [];
    assert(diff::patch_apply_fuzz(ssrc[..], ssp, shu[..], smk[..], sbd[..], sls[..], sfz, sout) == diff::ERR_NO_MATCH);
    assert(sout.len == 0);
    // A model with a range past its buffer is a fault, not a crash.
    var bsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 1 };
    var bhu: diff::Hunk[>..] = [];
    bhu.push(diff::Hunk { old_start: 1, old_lines: 1, new_start: 1, new_lines: 1, first_line: 0, lines: 5 });
    var bnm: u8[>..] = [];
    var bmk: u8[>..] = [];
    bmk.push(32);
    var bbd: u8[>..] = [];
    var bls: diff::Span[>..] = [];
    assert(diff::patch_apply_fuzz(ssrc[..], bsp, bhu[..], bmk[..], bbd[..], bls[..], sfz, sout) == diff::ERR_BAD_PATCH);
    assert(sout.len == 0);
    var bsp2: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 3 };
    var bhu2: diff::Hunk[>..] = [];
    var bnm2: u8[>..] = [];
    var bmk2: u8[>..] = [];
    var fsp2: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fhu2: diff::Hunk[>..] = [];
    var fnm2: u8[>..] = [];
    var fmk2: u8[>..] = [];
    assert(diff::patch_reverse(bsp2, bhu2[..], bnm2[..], bmk2[..], fsp2, fhu2, fnm2, fmk2) == diff::ERR_BAD_PATCH);
    assert(fhu2.len == 0);
    // A change that reaches past its text is a fault.
    var bchs: diff::Change[>..] = [];
    bchs.push(diff::Change { at: 10, len: 5, count: 1, text: 0, added: false, removed: false });
    var bout: u8[>..] = [];
    assert(diff::changes_xml(bchs[..], ca[..], cb[..], bout) == diff::ERR_BAD_OPTION);
    assert(bout.len == 0);
    assert(diff::changes_dmp(bchs[..], ca[..], cb[..], bout) == diff::ERR_BAD_OPTION);
    assert(bout.len == 0);
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
    test_context();
    test_css();
    test_json_canonical();
    test_json_diff();
    test_json_bounds();
    test_json_review();
    test_patience_lcs();
    test_patience_lcs_text();
    test_patience_lcs_bounds();

    test_spatch();
    test_spatch_eof();
    test_ndiff_restore();
    test_ndiff_bounds();
    print("all diff tests pass\n");
}
