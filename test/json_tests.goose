// The tests of the group json.
namespace json_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import common;

fn test_json_canonical() {
    var out: u8[>..] = [];
    assert(common::json_form("{\"b\":1,\"a\":[true,null,{}],\"c\":{}}", out) == diff::ERR_OK);
    assert(out[..] == "{\n  \"a\": [\n    true,\n    null,\n    {}\n  ],\n  \"b\": 1,\n  \"c\": {}\n}");
    // Array indexes come first, then the other keys. The last duplicate wins.
    out.resize(0, 0);
    assert(common::json_form("{\"b\":1,\"10\":2,\"2\":3,\"b\":4}", out) == diff::ERR_OK);
    assert(out[..] == "{\n  \"2\": 3,\n  \"10\": 2,\n  \"b\": 4\n}");
    // The numbers follow JavaScript.
    out.resize(0, 0);
    assert(common::json_form("[1.0,1e2,-0,1e21,1e-7,0.000001,123456789012345678901,1e400,0.1]", out) == diff::ERR_OK);
    assert(out[..] == "[\n  1,\n  100,\n  0,\n  1e+21,\n  1e-7,\n  0.000001,\n  123456789012345680000,\n  null,\n  0.1\n]");
    // The strings escape as JSON.stringify writes them.
    out.resize(0, 0);
    assert(common::json_form("\"a\\u0001\\ud800\\n/\"", out) == diff::ERR_OK);
    assert(out[..] == "\"a\\u0001\\ud800\\n/\"");
    // A UTF-16 sort puts U+FFFF before a character above U+FFFF.
    out.resize(0, 0);
    assert(common::json_form("{\"\\ud83d\\ude00\":1,\"\\uffee\":2}", out) == diff::ERR_OK);
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
    assert(common::change_text(changes[1], ca[..], cb[..]) == "  \"a\": 1,\n");
    assert(changes[1].removed);
    assert(common::change_text(changes[2], ca[..], cb[..]) == "  \"a\": 3,\n");
    assert(changes[2].added);
    // A line that differs by a comma is equal and the longer line stays.
    common::clear_changes(changes);
    assert(diff::diff_json_text("x,\ny\n", "x\ny,\n", o, changes) == diff::ERR_OK);
    assert(changes.len == 2);
    assert(!changes[0].added && !changes[0].removed && changes[0].text == 0);
    assert(!changes[1].added && !changes[1].removed && changes[1].text == 1);
    // A fault leaves the buffers as they were.
    common::clear_changes(changes);
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
