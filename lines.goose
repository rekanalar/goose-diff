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

// Compare holds the rules of the comparison of two lines.
struct Compare {
    // The case of the bytes does not matter.
    fold: bool,
    // The carriage return before a line feed does not matter.
    strip_cr: bool,
}

// fold_byte gives the byte with its case folded. Only the Latin letters
// of ASCII fold.
fn fold_byte(c: u8) -> u8 {
    if c >= 'A' && c <= 'Z' { return c + 32; }
    return c;
}

// is_cr_before_lf tells whether the byte at the place is a carriage
// return that stands before a line feed. The rule of the carriage
// return cuts it.
fn is_cr_before_lf(text: const u8[:], at: i64, end: i64) -> bool {
    return text[at] == 13 && at + 1 < end && text[at + 1] == 10;
}

// hash_span gives a seeded FNV-1a hash of the bytes of a line. The seed
// changes on every call, so no input can force many collisions. The
// fold says that the case of the bytes does not matter.
fn hash_span(text: const u8[:], s: Span, seed: u64, c: Compare) -> u64 {
    var h: u64 = 14695981039346656037 ^ seed;
    let end = s.at + s.len;
    for k in s.len {
        let b = text[s.at + k];
        if c.strip_cr && is_cr_before_lf(text, s.at + k, end) { continue; }
        var v = b;
        if c.fold { v = fold_byte(v); }
        h = (h ^ v) * 1099511628211;
    }
    return h;
}

// skip_cr gives the place after the carriage returns that stand before a
// line feed. The rule of the carriage return cuts them.
fn skip_cr(text: const u8[:], at: i64, end: i64) -> i64 {
    var i = at;
    while i < end && is_cr_before_lf(text, i, end) { i = i + 1; }
    return i;
}

// span_equal tells whether two lines hold the same bytes. The fold says
// that the case of the bytes does not matter. The rule of the carriage
// return cuts the carriage return that stands before a line feed, so two
// lines of different length can still hold the same bytes.
fn span_equal(ta: const u8[:], sa: Span, tb: const u8[:], sb: Span, c: Compare) -> bool {
    if !c.fold && !c.strip_cr {
        if sa.len != sb.len { return false; }
        for k in sa.len {
            if ta[sa.at + k] != tb[sb.at + k] { return false; }
        }
        return true;
    }
    let ea = sa.at + sa.len;
    let eb = sb.at + sb.len;
    var i = sa.at;
    var j = sb.at;
    while i < ea && j < eb {
        if c.strip_cr {
            i = skip_cr(ta, i, ea);
            j = skip_cr(tb, j, eb);
            if i >= ea || j >= eb { break; }
        }
        var c1 = ta[i];
        var c2 = tb[j];
        if c.fold {
            c1 = fold_byte(c1);
            c2 = fold_byte(c2);
        }
        if c1 != c2 { return false; }
        i = i + 1;
        j = j + 1;
    }
    if c.strip_cr {
        i = skip_cr(ta, i, ea);
        j = skip_cr(tb, j, eb);
    }
    return i >= ea && j >= eb;
}

// intern gives every distinct line an id, from 0 up. Two lines with the
// same bytes get the same id, in either text. The ids go to ida and idb.
fn intern(a: const u8[:], la: const Span[:], b: const u8[:], lb: const Span[:],
          ida: i32[>..]&, idb: i32[>..]&, cmp: Compare) {
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
            var slot = (hash_span(text, s, seed, cmp) & (mask as u64)) as i64;
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
                    if span_equal(text, s, other, rep_span[t], cmp) {
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
