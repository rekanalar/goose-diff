// The tests of the group inline.
namespace inline_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import diff_checks;

// test_inline pins the inline changes against the results of the Rust
// library similar.
fn test_inline() {
    // Words that changed get a mark.
    let r1 = diff_checks::il_render("world world hello b foo\n", "x1 world bar baz x1 b\n", diff::ALG_PATIENCE);
    assert(r1[..] == "- 0 - .world |!world|. |!hello|. b|! foo|.\\n\n+ - 0 !x1 |.world |!bar baz|. |!x1|. b|.\\n\n");
    // Lines that share too few words stay plain.
    let r2 = diff_checks::il_render("aaa\nbbb", "ccc\nddd", diff::ALG_PATIENCE);
    assert(r2[..] == "- 0 - .aaa\\n\n- 1 - .bbb\n+ - 0 .ccc\\n\n+ - 1 .ddd\n");
    // Lines that share half of their words get marks, and the line end stays plain.
    let r3 = diff_checks::il_render("keep\nold one", "keep\nnew one", diff::ALG_PATIENCE);
    assert(r3[..] == "= 0 0 .keep\\n\n- 1 - !old|. one\n+ - 1 !new|. one\n");
    // Bytes that are no valid UTF-8, and a no-break space, give no fault.
    var bad: u8[>..] = [];
    for c in [97, 32, 255, 224, 160, 32, 98, 10] { bad.push(c as u8); }
    var bad2: u8[>..] = [];
    for c in [97, 194, 160, 98, 32, 240, 159, 10] { bad2.push(c as u8); }
    let r4 = diff_checks::il_render(bad[..], bad2[..], diff::ALG_PATIENCE);
    assert(r4.len > 0);
    // The word bounds of Unicode split the apostrophe words and the cases
    // of `similar` with its unicode feature.
    let r5 = diff_checks::il_render_u("don't wörld 日本 x\nsame\n", "don’t WÖRLD 日本 y\nsame\n", diff::ALG_PATIENCE, true);
    assert(r5[..] == "- 0 - !don't|. |!wörld|. 日本 |!x|.\\n\n+ - 0 !don’t|. |!WÖRLD|. 日本 |!y|.\\n\n= 1 1 .same\\n\n");
}

// test_compaction pins the opcodes of the patience search after the
// compaction pass of similar.
fn test_compaction() {
    var a: i32[>..] = [];
    for v in [0, 1, 0, 1, 2, 1, 3, 1, 4, 5] { a.push(v as i32); }
    var b: i32[>..] = [];
    for v in [6, 1, 0, 1, 7, 1, 8, 1, 6, 1, 3, 5] { b.push(v as i32); }
    var ops: diff::Op[>..] = [];
    let code, ex = diff::diff_ids_alg(a[..], b[..], diff::ALG_PATIENCE, 2000, 50000000, ops);
    assert(code == diff::ERR_OK);
    assert(ops.len == 8);
    assert(ops[0].tag == diff::OP_INSERT && ops[0].b_lo == 0 && ops[0].b_hi == 2);
    assert(ops[1].tag == diff::OP_EQUAL && ops[1].a_lo == 0 && ops[1].a_hi == 2 && ops[1].b_lo == 2 && ops[1].b_hi == 4);
    assert(ops[2].tag == diff::OP_REPLACE && ops[2].a_lo == 2 && ops[2].a_hi == 3 && ops[2].b_lo == 4 && ops[2].b_hi == 7);
    assert(ops[3].tag == diff::OP_EQUAL && ops[3].a_lo == 3 && ops[3].b_lo == 7);
}
