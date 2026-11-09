// The JSON search of the Node library diff.
//
// The search writes both texts in one canonical form, then compares the
// lines. The canonical form sorts the keys of every object and writes two
// blanks of indent for each level. The search ignores a comma at the end
// of a line.
namespace diff;

import std;
import json;

// The code of a text that is no JSON.
const ERR_BAD_JSON: i64 = 8;

// The canonical text may be this many times as long as the input.
const JSON_GROWTH: i64 = 8;

// SortKey is one member of an object: its place in the pool of nodes and
// its key.
struct SortKey {
    key: const u8[:],
    node: i64,
}

// Frame is one open container of the writer: its node, the next child to
// write and the end of its children.
struct Frame {
    node: i64,
    next: i64,
    end: i64,
}

// js_unit gives the first UTF-16 unit of a code point.
fn js_unit(cp: i64) -> i64 {
    if cp < 0x10000 { return cp; }
    return 0xD800 + ((cp - 0x10000) >> 10);
}

// js_less tells whether the key x sorts before the key y in the order of
// the UTF-16 code units. A code point above U+FFFF counts as its two
// surrogates.
fn js_less(x: const u8[:], y: const u8[:]) -> bool {
    var i: i64 = 0;
    var j: i64 = 0;
    while i < x.len && j < y.len {
        let wx = tok_width(x, i);
        let wy = tok_width(y, j);
        let cx = tok_code(x, i, wx);
        let cy = tok_code(y, j, wy);
        if cx != cy {
            let ux = js_unit(cx);
            let uy = js_unit(cy);
            if ux != uy { return ux < uy; }
            return cx < cy;
        }
        i = i + wx;
        j = j + wy;
    }
    return x.len - i < y.len - j;
}

// js_index gives the value of a key that JavaScript treats as an array
// index: no sign, no leading zero, and a value below 4294967295. It gives
// -1 for any other key.
fn js_index(k: const u8[:]) -> i64 {
    if k.len == 0 || k.len > 10 { return -1; }
    if k[0] == '0' && k.len > 1 { return -1; }
    var v: i64 = 0;
    for c in k {
        if c < '0' || c > '9' { return -1; }
        v = v * 10 + (c - '0');
    }
    if v >= 4294967295 { return -1; }
    return v;
}

// js_key_less orders the members as a JavaScript object lists them. The
// keys that are array indexes come first, in the order of their values.
// The other keys follow in the order of the sort. Equal keys go by place.
fn js_key_less(x: SortKey, y: SortKey) -> bool {
    let ix = js_index(x.key);
    let iy = js_index(y.key);
    if ix >= 0 && iy >= 0 {
        if ix != iy { return ix < iy; }
        return x.node < y.node;
    }
    if ix >= 0 { return true; }
    if iy >= 0 { return false; }
    if js_less(x.key, y.key) { return true; }
    if js_less(y.key, x.key) { return false; }
    // The keys have the same code points. Broken bytes can still differ,
    // so the bytes decide, and equal keys stand side by side.
    let n = if x.key.len < y.key.len { x.key.len } else { y.key.len };
    for t in n {
        if x.key[t] != y.key[t] { return x.key[t] < y.key[t]; }
    }
    if x.key.len != y.key.len { return x.key.len < y.key.len; }
    return x.node < y.node;
}

// json_hex appends four lowercase hex digits.
fn json_hex(out: u8[>..]&, v: i64) {
    for k in 4 {
        let d = (v >> (12 - 4 * k)) & 15;
        if d < 10 { out.push('0' + d as! u8); } else { out.push('a' + (d - 10) as! u8); }
    }
}

// json_string appends a string as JSON.stringify writes it.
fn json_string(out: u8[>..]&, s: const u8[:]) {
    out.push('"');
    var i: i64 = 0;
    while i < s.len {
        let c = s[i];
        if c == '"' { out.push(92); out.push('"'); }
        else if c == 92 { out.push(92); out.push(92); }
        else if c == 8 { out.push(92); out.push('b'); }
        else if c == 12 { out.push(92); out.push('f'); }
        else if c == 10 { out.push(92); out.push('n'); }
        else if c == 13 { out.push(92); out.push('r'); }
        else if c == 9 { out.push(92); out.push('t'); }
        else if c < 32 {
            out.push(92);
            out.push('u');
            json_hex(out, c);
        } else if c == 0xED && i + 2 < s.len && s[i + 1] >= 0xA0 && s[i + 1] <= 0xBF
                  && s[i + 2] >= 0x80 && s[i + 2] <= 0xBF {
            // A half of a surrogate pair stands alone: JSON.stringify
            // writes it as an escape.
            out.push(92);
            out.push('u');
            json_hex(out, tok_code(s, i, 3));
            i = i + 2;
        } else { out.push(c); }
        i = i + 1;
    }
    out.push('"');
}

// js_digits gives the shortest digits of a number above zero and the
// power of ten that they are a fraction of: 0.d1 d2 ... dk * 10^point.
// The standard library writes the shortest form, and the digits come from
// that text.
fn js_digits(x: f64, d: u8[>..]&) -> i64 {
    var t: u8[>..] = [];
    json::format_number(t, x);
    var point: i64 = 0;
    var frac = false;
    var lead = true;
    var i: i64 = 0;
    while i < t.len && t[i] != 'e' && t[i] != 'E' {
        let c = t[i];
        i = i + 1;
        if c == '.' { frac = true; continue; }
        if lead && c == '0' {
            if frac { point = point - 1; }
            continue;
        }
        lead = false;
        d.push(c);
        if !frac { point = point + 1; }
    }
    if i < t.len {
        i = i + 1;
        var neg = false;
        if i < t.len && (t[i] == '-' || t[i] == '+') { neg = t[i] == '-'; i = i + 1; }
        var e: i64 = 0;
        while i < t.len {
            e = e * 10 + (t[i] - '0');
            i = i + 1;
        }
        if neg { point = point - e; } else { point = point + e; }
    }
    while d.len > 1 && d[d.len - 1] == '0' { d.pop(); }
    return point;
}

// json_number appends a number as JavaScript writes it.
fn json_number(out: u8[>..]&, v: f64) {
    if v - v != 0.0 || v != v {
        put_text(out, "null");
        return;
    }
    if v == 0.0 {
        out.push('0');
        return;
    }
    var x = v;
    if x < 0.0 {
        out.push('-');
        x = 0.0 - x;
    }
    var d: u8[>..] = [];
    let n = js_digits(x, d);
    let k = d.len;
    if k <= n && n <= 21 {
        for t in k { out.push(d[t]); }
        for t in k..n { out.push('0'); }
    } else if 0 < n && n <= 21 {
        for t in n { out.push(d[t]); }
        out.push('.');
        for t in n..k { out.push(d[t]); }
    } else if -6 < n && n <= 0 {
        out.push('0');
        out.push('.');
        for t in 0..(0 - n) { out.push('0'); }
        for t in k { out.push(d[t]); }
    } else {
        let e = n - 1;
        out.push(d[0]);
        if k > 1 {
            out.push('.');
            for t in 1..k { out.push(d[t]); }
        }
        out.push('e');
        if e < 0 { out.push('-'); } else { out.push('+'); }
        var m = e;
        if m < 0 { m = 0 - m; }
        digits_of(out, m);
    }
}

// json_indent appends the line end and the indent of a level.
fn json_indent(out: u8[>..]&, level: i64) {
    out.push(10);
    for t in level { out.push(' '); out.push(' '); }
}

// json_links fills the children of every container. The nodes of the
// pool stand in text order, so the children of a container follow it. A
// stack of open containers finds each parent. The children of an object
// go in the order of the keys, and the last of equal keys stays.
fn json_links(doc: json::Node[>..]&, lo: i64[>..]&, hi: i64[>..]&, kids: i64[>..]&) {
    let n = doc.len;
    lo.resize(n, 0);
    hi.resize(n, 0);
    var size: i64[>..] = [];
    size.resize(n, 1);
    var parent: i64[>..] = [];
    parent.resize(n, -1);
    var open: i64[>..] = [];
    var left: i64[>..] = [];
    for i in n {
        while open.len > 0 && left[left.len - 1] == 0 {
            open.pop();
            left.pop();
        }
        if open.len > 0 {
            parent[i] = open[open.len - 1];
            left[left.len - 1] = left[left.len - 1] - 1;
        }
        let c = json_count(doc[i]);
        if c > 0 {
            open.push(i);
            left.push(c);
        }
    }
    var i = n - 1;
    while i > 0 {
        if parent[i] >= 0 { size[parent[i]] = size[parent[i]] + size[i]; }
        i = i - 1;
    }
    var keys: SortKey[>..] = [];
    for c in n {
        let count = json_count(doc[c]);
        lo[c] = kids.len;
        if count > 0 {
            keys.resize(0, SortKey { key: "", node: 0 });
            var j = c + 1;
            for t in count {
                keys.push(SortKey { key: doc[j].key, node: j });
                j = j + size[j];
            }
            if json_is_object(doc[c]) {
                sort(keys[..]) { x, y => js_key_less(x, y) };
                for t in keys.len {
                    if t + 1 == keys.len || keys[t].key != keys[t + 1].key {
                        kids.push(keys[t].node);
                    }
                }
            } else {
                for t in keys.len { kids.push(keys[t].node); }
            }
        }
        hi[c] = kids.len;
    }
}

// json_count gives the count of the children of a node.
fn json_count(n: json::Node&) -> i64 {
    match n.val {
        Arr a => { return a.count; },
        Obj o => { return o.count; },
        _ => { return 0; },
    }
}

// json_is_object tells whether a node is an object.
fn json_is_object(n: json::Node&) -> bool {
    match n.val {
        Obj => { return true; },
        _ => { return false; },
    }
}

// json_scalar appends a value that holds no children. It gives false when
// the node is a container.
fn json_scalar(out: u8[>..]&, n: json::Node&) -> bool {
    match n.val {
        Null => { put_text(out, "null"); },
        Bool b => { if b.v { put_text(out, "true"); } else { put_text(out, "false"); } },
        Int i => {
            if i.v > -9007199254740992 && i.v < 9007199254740992 {
                if i.v < 0 { out.push('-'); digits_of(out, 0 - i.v); } else { digits_of(out, i.v); }
            } else {
                json_number(out, i.v);
            }
        },
        Num x => { json_number(out, x.v); },
        Str s => { json_string(out, s.s); },
        _ => { return false; },
    }
    return true;
}

// json_write appends the canonical text of the tree. It gives a code. The
// output may not pass `cap` bytes.
fn json_write(doc: json::Node[>..]&, lo: const i64[:], hi: const i64[:], kids: const i64[:],
              cap: i64, out: u8[>..]&) -> i64 {
    var stack: Frame[>..] = [];
    var node: i64 = 0;
    // The value at `node` starts here.
    loop {
        let n .= doc[node];
        if !json_scalar(out, n) {
            let open: u8 = if json_is_object(n) { '{' } else { '[' };
            let close: u8 = if json_is_object(n) { '}' } else { ']' };
            out.push(open);
            if lo[node] == hi[node] {
                out.push(close);
            } else {
                stack.push(Frame { node: node, next: lo[node], end: hi[node] });
            }
        }
        if out.len > cap { return ERR_TOO_LARGE; }
        // Close the containers that are done, then step to the next child.
        var more = false;
        while stack.len > 0 {
            let f = stack[stack.len - 1];
            if f.next == f.end {
                stack.pop();
                json_indent(out, stack.len);
                if json_is_object(doc[f.node]) { out.push('}'); } else { out.push(']'); }
                if out.len > cap { return ERR_TOO_LARGE; }
                continue;
            }
            if f.next > lo[f.node] { out.push(','); }
            json_indent(out, stack.len);
            if out.len > cap { return ERR_TOO_LARGE; }
            let child = kids[f.next];
            if json_is_object(doc[f.node]) {
                json_string(out, doc[child].key);
                out.push(':');
                out.push(' ');
            }
            stack[stack.len - 1].next = f.next + 1;
            node = child;
            more = true;
            break;
        }
        if !more { break; }
    }
    return ERR_OK;
}

// json_cap gives the most bytes of a canonical text for an input limit.
fn json_cap(max_input: i64) -> i64 {
    if max_input > 1152921504606846976 { return 4611686018427387904; }
    return max_input * JSON_GROWTH + 4096;
}

// json_canonical_cap is json_canonical with the cap of the output given.
fn json_canonical_cap(text: const u8[:], o: TokenOptions, cap: i64, out: u8[>..]&) -> i64 {
    if !token_options_ok(o) { return ERR_BAD_OPTION; }
    if text.len > o.max_input { return ERR_TOO_LARGE; }
    var src: u8[>..] = [];
    for c in text { src.push(c); }
    var doc: json::Node[>..] = [];
    var decoded: u8[>..] = [];
    let root, err = json::parse(src[..], doc, decoded);
    if !root { return ERR_BAD_JSON; }
    var lo: i64[>..] = [];
    var hi: i64[>..] = [];
    var kids: i64[>..] = [];
    json_links(doc, lo, hi, kids);
    var buf: u8[>..] = [];
    let code = json_write(doc, lo[..], hi[..], kids[..], cap, buf);
    if code != ERR_OK { return code; }
    for c in buf { out.push(c); }
    return ERR_OK;
}

// json_canonical adds the canonical text of a JSON text to `out`. The keys
// of every object stand in the order of the UTF-16 code units. A key that
// appears twice keeps its last value. A number gets the text that
// JavaScript gives it. The text may not pass eight times the rule
// `max_input`. It gives a code. A fault leaves `out` as it was.
fn json_canonical(text: const u8[:], o: TokenOptions, out: u8[>..]&) -> i64 {
    return json_canonical_cap(text, o, json_cap(o.max_input), out);
}

// json_flatten gives a copy of a text without the commas that stand
// before a line end.
fn json_flatten(text: const u8[:], out: u8[>..]&) {
    for i in text.len {
        if text[i] == ',' && i + 1 < text.len && (text[i + 1] == 10 || text[i + 1] == 13) { continue; }
        out.push(text[i]);
    }
}

// diff_json_text adds the changes of a against b to `changes`. The search
// compares the lines of the two texts. It ignores a comma before a line
// end. A change that stays holds the longer line of the two. It gives a
// code and a flag. The flag is true when the diff is minimal.
fn diff_json_text(a: const u8[:], b: const u8[:], o: TokenOptions, changes: Change[>..]&) -> i64, bool {
    if !token_options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var ta: Span[>..] = [];
    var tb: Span[>..] = [];
    var lines = o;
    lines.newline_is_token = false;
    if !tok_lines(a, lines, ta) || !tok_lines(b, lines, tb) { return ERR_TOO_LARGE, false; }
    if ta.len + tb.len > o.max_tokens { return ERR_TOO_LARGE, false; }
    var na: u8[>..] = [];
    var nb: u8[>..] = [];
    json_flatten(a, na);
    json_flatten(b, nb);
    var sa: Span[>..] = [];
    var sb: Span[>..] = [];
    assert(tok_lines(na[..], lines, sa) && tok_lines(nb[..], lines, sb));
    return tok_changes(na[..], ta[..], sa[..], nb[..], tb[..], sb[..], o, true, changes);
}

// diff_json adds the changes of the JSON text a against the JSON text b to
// `changes`. It writes both texts in the canonical form first. The
// buffers `ca` and `cb` take the two canonical texts, which hold the
// places of the changes. The call replaces what the buffers held. It
// gives a code and a flag. A fault leaves every buffer as it was.
fn diff_json(a: const u8[:], b: const u8[:], o: TokenOptions, ca: u8[>..]&, cb: u8[>..]&,
             changes: Change[>..]&) -> i64, bool {
    var xa: u8[>..] = [];
    var xb: u8[>..] = [];
    let c1 = json_canonical_cap(a, o, o.max_input, xa);
    if c1 != ERR_OK { return c1, false; }
    let c2 = json_canonical_cap(b, o, o.max_input, xb);
    if c2 != ERR_OK { return c2, false; }
    var found: Change[>..] = [];
    let code, exact = diff_json_text(xa[..], xb[..], o, found);
    if code != ERR_OK { return code, false; }
    ca.resize(0, 0);
    cb.resize(0, 0);
    for c in xa { ca.push(c); }
    for c in xb { cb.push(c); }
    for c in found { changes.push(c); }
    return ERR_OK, exact;
}
