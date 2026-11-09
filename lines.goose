// Lines of a text, and an id for every distinct line.
//
// A line keeps its line end. The last line of a text may have none.
// Only the byte 10 ends a line, so a carriage return stays in the line.
namespace diff;

import std;
import os;

// Span is a range of bytes in a text.
struct Span {
    at: i64,
    len: i64,
}

// split_lines adds the lines of the text to the buffer.
fn split_lines(text: const u8[:], out: Span[>..]&) {
    var start: i64 = 0;
    var i: i64 = 0;
    while i < text.len {
        if text[i] == 10 {
            out.push(Span { at: start, len: i + 1 - start });
            start = i + 1;
        }
        i = i + 1;
    }
    if start < text.len { out.push(Span { at: start, len: text.len - start }); }
}

// hash_span gives a seeded FNV-1a hash of the bytes of a line. The seed
// changes on every call, so no input can force many collisions.
fn hash_span(text: const u8[:], s: Span, seed: u64) -> u64 {
    var h: u64 = 14695981039346656037 ^ seed;
    for k in s.len { h = (h ^ text[s.at + k]) * 1099511628211; }
    return h;
}

// span_equal tells whether two lines hold the same bytes.
fn span_equal(ta: const u8[:], sa: Span, tb: const u8[:], sb: Span) -> bool {
    if sa.len != sb.len { return false; }
    for k in sa.len {
        if ta[sa.at + k] != tb[sb.at + k] { return false; }
    }
    return true;
}

// intern gives every distinct line an id, from 0 up. Two lines with the
// same bytes get the same id, in either text. The ids go to ida and idb.
fn intern(a: const u8[:], la: const Span[:], b: const u8[:], lb: const Span[:],
          ida: i32[>..]&, idb: i32[>..]&) {
    let total = la.len + lb.len;
    var size: i64 = 16;
    while size < total * 2 { size = size * 2; }
    let mask = size - 1;
    var table: i32[>..] = [];
    table.resize(size, -1);
    // The line that stands for each id: the text (0 or 1) and the span.
    var rep_text: u8[>..] = [];
    var rep_span: Span[>..] = [];
    let seed = time_ns() as u64;
    for pass in 2 {
        var text = a;
        var n = la.len;
        if pass == 1 { text = b; n = lb.len; }
        for i in n {
            var s = Span { at: 0, len: 0 };
            if pass == 0 { s = la[i]; } else { s = lb[i]; }
            var slot = (hash_span(text, s, seed) & (mask as u64)) as i64;
            var id: i32 = -1;
            while id < 0 {
                let t = table[slot];
                if t < 0 {
                    id = rep_span.len as i32;
                    table[slot] = id;
                    rep_text.push(pass as u8);
                    rep_span.push(s);
                } else {
                    var other = a;
                    if rep_text[t] == 1 { other = b; }
                    if span_equal(text, s, other, rep_span[t]) {
                        id = t;
                    } else {
                        slot = (slot + 1) & mask;
                    }
                }
            }
            if pass == 0 { ida.push(id); } else { idb.push(id); }
        }
    }
}
