// The tests of the group matcher.
namespace matcher_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import diff_checks;

fn test_matcher_blocks() {
    let o = diff_checks::ro_options();
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
    let o = diff_checks::ro_options();
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
    let o = diff_checks::ro_options();
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
    let o = diff_checks::ro_options();
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
    var o = diff_checks::ro_options();
    o.junk = diff::JUNK_BLANK;
    var ops: diff::Op[>..] = [];
    let c, e = diff::matcher_opcodes("\n", "a\n\n", o, ops);
    assert(c == diff::ERR_OK && ops.len == 1 && ops[0].tag == diff::OP_REPLACE);
    // Without the rule the blank line matches.
    var plain: diff::Op[>..] = [];
    let c2, e2 = diff::matcher_opcodes("\n", "a\n\n", diff_checks::ro_options(), plain);
    assert(c2 == diff::ERR_OK && plain.len == 2);
    assert(plain[0].tag == diff::OP_INSERT && plain[1].tag == diff::OP_EQUAL);
    // A line of one hash sign is junk under the rule JUNK_COMMENT.
    var o3 = diff_checks::ro_options();
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
    var o = diff_checks::ro_options();
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
    var o = diff_checks::ro_options();
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
    var o2 = diff_checks::ro_options();
    o2.algorithm = 9;
    var ops3: diff::Op[>..] = [];
    assert(diff::matcher_opcodes("a\n", "b\n", o2, ops3) == diff::ERR_BAD_OPTION);
    var o3 = diff_checks::ro_options();
    o3.junk = 5;
    assert(diff::matcher_opcodes("a\n", "b\n", o3, ops3) == diff::ERR_BAD_OPTION);
    var o4 = diff_checks::ro_options();
    o4.max_work = 500000001;
    assert(diff::matcher_opcodes("a\n", "b\n", o4, ops3) == diff::ERR_BAD_OPTION);
}
