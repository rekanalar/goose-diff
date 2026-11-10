// The structured patch of jsdiff.
//
// The model holds one file: the two names, the two headers and the
// hunks. Each hunk holds its four range numbers and its body lines.
// The body lines sit in flat buffers the caller owns, one mark byte and
// one place per line, in the way the patch reader fills its own
// buffers. A line holds no line end. A line with no line end in its
// file is followed by a line that carries the marker of GNU diff,
// as the structured patch of jsdiff holds it.
namespace diff;

import std;

// SPatch is the structured patch of one file. The four places go into
// the buffer `names`.
struct SPatch {
    old_name: Span,
    new_name: Span,
    old_header: Span,
    new_header: Span,
    // The first hunk of the file and the count of its hunks.
    first_hunk: i64,
    hunks: i64,
}

// structured_patch fills the structured patch of a against b. It
// splits the texts, finds the opcodes and groups them into hunks with
// the context rule. It gives a code. A fault leaves every buffer as it
// was.
fn structured_patch(a_name: const u8[:], b_name: const u8[:], a: const u8[:], b: const u8[:],
                    a_header: const u8[:], b_header: const u8[:], o: Options, sp: SPatch&,
                    hunks: Hunk[>..]&, names: u8[>..]&, marks: u8[>..]&, body: u8[>..]&,
                    lspans: Span[>..]&) -> i64 {
    if !options_ok(o) { return ERR_BAD_OPTION; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE; }
    if !name_ok(a_name) || !name_ok(b_name) || !name_ok(a_header) || !name_ok(b_header) {
        return ERR_BAD_NAME;
    }
    let n0 = names.len;
    let m0 = marks.len;
    let b0 = body.len;
    let l0 = lspans.len;
    let h0 = hunks.len;
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ops: Op[>..] = [];
    let ocode, _ = output_ops(a, b, o, la, lb, ops);
    if ocode != ERR_OK { return ocode; }
    sp.old_name = Span { at: names.len, len: a_name.len };
    for c in a_name { names.push(c); }
    sp.new_name = Span { at: names.len, len: b_name.len };
    for c in b_name { names.push(c); }
    sp.old_header = Span { at: names.len, len: a_header.len };
    for c in a_header { names.push(c); }
    sp.new_header = Span { at: names.len, len: b_header.len };
    for c in b_header { names.push(c); }
    var groups: Op[>..] = [];
    var ends: i64[>..] = [];
    group_ops(ops, o.context, groups, ends);
    sp.first_hunk = hunks.len;
    sp.hunks = 0;
    var from: i64 = 0;
    for e in ends {
        if hunks.len >= MAX_HUNKS || lspans.len + (e - from) > o.max_tokens { return sp_fault(n0, m0, b0, l0, h0, sp, hunks, names, marks, body, lspans); }
        let h = Hunk { old_start: groups[from].a_lo + 1,
                       old_lines: groups[e - 1].a_hi - groups[from].a_lo,
                       new_start: groups[from].b_lo + 1,
                       new_lines: groups[e - 1].b_hi - groups[from].b_lo,
                       first_line: lspans.len, lines: 0 };
        var i = from;
        while i < e {
            let op = groups[i];
            if op.tag == OP_EQUAL {
                for k in op.a_hi - op.a_lo { sp_put_line(marks, body, lspans, ' ', a, la[op.a_lo + k]); }
            } else {
                if op.tag == OP_REPLACE || op.tag == OP_DELETE {
                    for k in op.a_hi - op.a_lo { sp_put_line(marks, body, lspans, '-', a, la[op.a_lo + k]); }
                }
                if op.tag == OP_REPLACE || op.tag == OP_INSERT {
                    for k in op.b_hi - op.b_lo { sp_put_line(marks, body, lspans, '+', b, lb[op.b_lo + k]); }
                }
            }
            i = i + 1;
        }
        var nh = h;
        nh.lines = lspans.len - h.first_line;
        hunks.push(nh);
        sp.hunks = sp.hunks + 1;
        from = e;
    }
    return ERR_OK;
}

// sp_fault rolls every buffer back and gives the fault.
fn sp_fault(n0: i64, m0: i64, b0: i64, l0: i64, h0: i64, sp: SPatch&, hunks: Hunk[>..]&,
            names: u8[>..]&, marks: u8[>..]&, body: u8[>..]&, lspans: Span[>..]&) -> i64 {
    names.resize(n0, 0);
    marks.resize(m0, 0);
    body.resize(b0, 0);
    lspans.resize(l0, Span { at: 0, len: 0 });
    hunks.resize(h0, Hunk { old_start: 0, old_lines: 0, new_start: 0, new_lines: 0, first_line: 0, lines: 0 });
    sp.hunks = 0;
    return ERR_TOO_LARGE;
}

// sp_put_line appends one body line. The line goes in without its line
// end. A line with no line end is followed by the marker line.
fn sp_put_line(marks: u8[>..]&, body: u8[>..]&, lspans: Span[>..]&, mark: u8,
               text: const u8[:], s: Span) {
    marks.push(mark);
    let at = body.len;
    var len = s.len;
    var no_end = false;
    if len > 0 && text[s.at + len - 1] == 10 { len = len - 1; } else { no_end = true; }
    for k in len { body.push(text[s.at + k]); }
    lspans.push(Span { at: at, len: body.len - at });
    if no_end {
        // The marker line of GNU diff. The mark holds the backslash,
        // the text holds the rest.
        marks.push('\\');
        let at2 = body.len;
        put_text(body, " No newline at end of file");
        lspans.push(Span { at: at2, len: body.len - at2 });
    }
}

// sp_span_ok tells whether a span lies inside a buffer of `n` bytes.
fn sp_span_ok(s: Span, n: i64) -> bool {
    return s.at >= 0 && s.len >= 0 && s.at <= n && s.len <= n - s.at;
}

// sp_model_ok tells whether every range of a hand-built model lies
// inside its buffers. A negative `nbody` or `nspans` skips that check.
fn sp_model_ok(sp: SPatch, hunks: const Hunk[:], names: const u8[:], marks: const u8[:],
               body: const u8[:], lspans: const Span[:], check_body: bool) -> bool {
    if !sp_span_ok(sp.old_name, names.len) || !sp_span_ok(sp.new_name, names.len) { return false; }
    if !sp_span_ok(sp.old_header, names.len) || !sp_span_ok(sp.new_header, names.len) { return false; }
    if sp.first_hunk < 0 || sp.hunks < 0 || sp.first_hunk > hunks.len || sp.hunks > hunks.len - sp.first_hunk { return false; }
    var i = sp.first_hunk;
    while i < sp.first_hunk + sp.hunks {
        let h = hunks[i];
        if h.first_line < 0 || h.lines < 0 || h.first_line > marks.len || h.lines > marks.len - h.first_line { return false; }
        if check_body {
            if h.first_line > lspans.len || h.lines > lspans.len - h.first_line { return false; }
            var k = h.first_line;
            while k < h.first_line + h.lines {
                if !sp_span_ok(lspans[k], body.len) { return false; }
                k = k + 1;
            }
        }
        i = i + 1;
    }
    return true;
}

// patch_text writes the structured patch as patch text. The line of
// "Index:" appears when the two names are equal, as jsdiff writes it.
// Every header takes its tab. It gives a code.
fn patch_text(sp: SPatch, hunks: const Hunk[:], names: const u8[:], marks: const u8[:],
              body: const u8[:], lspans: const Span[:], out: u8[>..]&) -> i64 {
    if !sp_model_ok(sp, hunks, names, marks, body, lspans, true) { return ERR_BAD_PATCH; }
    if sp_eq(names, sp.old_name, names, sp.new_name) {
        put_text(out, "Index: ");
        put_span(out, names, sp.old_name);
        out.push(10);
    }
    for k in 67 { out.push('='); }
    out.push(10);
    put_text(out, "--- ");
    put_span(out, names, sp.old_name);
    put_header(out, names, sp.old_header);
    put_text(out, "+++ ");
    put_span(out, names, sp.new_name);
    put_header(out, names, sp.new_header);
    var hi = sp.first_hunk;
    while hi < sp.first_hunk + sp.hunks {
        let h = hunks[hi];
        // A count of zero names the line before, as the format asks.
        var os = h.old_start;
        if h.old_lines == 0 { os = os - 1; }
        var ns = h.new_start;
        if h.new_lines == 0 { ns = ns - 1; }
        put_text(out, "@@ -");
        digits_of(out, os);
        out.push(',');
        digits_of(out, h.old_lines);
        put_text(out, " +");
        digits_of(out, ns);
        out.push(',');
        digits_of(out, h.new_lines);
        put_text(out, " @@\n");
        var li = h.first_line;
        while li < h.first_line + h.lines {
            out.push(marks[li]);
            put_span(out, body, lspans[li]);
            out.push(10);
            li = li + 1;
        }
        hi = hi + 1;
    }
    return ERR_OK;
}

// put_header appends the tab and the header of a file line. The tab
// appears even when the header holds no text, as jsdiff writes it.
fn put_header(out: u8[>..]&, names: const u8[:], s: Span) {
    out.push(9);
    put_span(out, names, s);
    out.push(10);
}

// put_span appends the bytes of a place.
fn put_span(out: u8[>..]&, text: const u8[:], s: Span) {
    for k in s.len { out.push(text[s.at + k]); }
}

// sp_eq tells whether two places hold the same bytes.
fn sp_eq(text: const u8[:], a: Span, btext: const u8[:], b: Span) -> bool {
    if a.len != b.len { return false; }
    for k in a.len {
        if text[a.at + k] != btext[b.at + k] { return false; }
    }
    return true;
}

// format_patch writes a structured patch as patch text. It is the
// formatPatch of jsdiff.
fn format_patch(sp: SPatch, hunks: const Hunk[:], names: const u8[:], marks: const u8[:],
                body: const u8[:], lspans: const Span[:], out: u8[>..]&) -> i64 {
    return patch_text(sp, hunks, names, marks, body, lspans, out);
}

// create_patch builds the structured patch of one file and writes it
// in the form with the line of "Index:". It is the createPatch of
// jsdiff.
fn create_patch(name: const u8[:], a: const u8[:], b: const u8[:], a_header: const u8[:],
                b_header: const u8[:], o: Options, sp: SPatch&, hunks: Hunk[>..]&,
                names: u8[>..]&, marks: u8[>..]&, body: u8[>..]&, lspans: Span[>..]&,
                out: u8[>..]&) -> i64 {
    let base = out.len;
    let code = structured_patch(name, name, a, b, a_header, b_header, o, sp, hunks, names, marks, body, lspans);
    if code != ERR_OK { return code; }
    let wcode = patch_text(sp, hunks[..], names[..], marks[..], body[..], lspans[..], out);
    if wcode != ERR_OK {
        out.resize(base, 0);
        return wcode;
    }
    return ERR_OK;
}

// patch_parse_structured reads one file of a patch text into the
// structured model. The file is the index into the files of the patch.
// The line texts lose their marker and their line end. A line with the
// marker of GNU diff keeps its text. It gives a code.
fn patch_parse_structured(text: const u8[:], file: i64, sp: SPatch&, hunks: Hunk[>..]&,
                          names: u8[>..]&, marks: u8[>..]&, body: u8[>..]&,
                          lspans: Span[>..]&) -> i64 {
    var pf: FilePatch[>..] = [];
    var ph: Hunk[>..] = [];
    var pb: Span[>..] = [];
    let code = patch_parse(text, pf, ph, pb);
    if code != ERR_OK { return code; }
    if file < 0 || file >= pf.len { return ERR_NO_FILE; }
    let f = pf[file];
    sp.old_name = sp_copy_name(names, text, f.old_name);
    sp.new_name = sp_copy_name(names, text, f.new_name);
    sp.old_header = sp_copy_name(names, text, sp_header_of(text, f.old_name));
    sp.new_header = sp_copy_name(names, text, sp_header_of(text, f.new_name));
    sp.first_hunk = hunks.len;
    sp.hunks = 0;
    var hi = f.first_hunk;
    while hi < f.first_hunk + f.hunks {
        let h = ph[hi];
        var nh = h;
        nh.first_line = lspans.len;
        var li = h.first_line;
        while li < h.first_line + h.lines {
            let b = pb[li];
            let m = marker_of(text, b);
            marks.push(m);
            lspans.push(Span { at: body.len, len: 0 });
            if m == '\\' {
                // The marker line holds its text without its backslash
                // and without the end.
                var from = b.at + 1;
                var e = b.at + b.len;
                if e > b.at && text[e - 1] == 10 { e = e - 1; }
                for k in from..e { body.push(text[k]); }
            } else {
                let c = content_of(text, b);
                for k in c.len { body.push(text[c.at + k]); }
            }
            lspans[lspans.len - 1].len = body.len - lspans[lspans.len - 1].at;
            li = li + 1;
        }
        nh.lines = lspans.len - nh.first_line;
        hunks.push(nh);
        sp.hunks = sp.hunks + 1;
        hi = hi + 1;
    }
    return ERR_OK;
}

// sp_header_of gives the header text that follows the tab after a name.
// It gives an empty span when no tab follows.
fn sp_header_of(text: const u8[:], name: Span) -> Span {
    var at = name.at + name.len;
    if at >= text.len || text[at] != 9 { return Span { at: at, len: 0 }; }
    at = at + 1;
    var e = at;
    while e < text.len && text[e] != 10 && text[e] != 13 { e = e + 1; }
    return Span { at: at, len: e - at };
}

// sp_copy_name copies a name into the buffer and gives its place.
fn sp_copy_name(names: u8[>..]&, text: const u8[:], s: Span) -> Span {
    let at = names.len;
    for k in s.len { names.push(text[s.at + k]); }
    return Span { at: at, len: s.len };
}

// patch_reverse fills the flipped patch: the names and headers swap,
// the ranges swap, and every mark of a change flips. The flipped patch
// shares the body lines and their places with the patch. It gives a
// code. A fault leaves every buffer as it was.
fn patch_reverse(sp: SPatch, hunks: const Hunk[:], names: const u8[:], marks: const u8[:],
                 fsp: SPatch&, fhunks: Hunk[>..]&, fnames: u8[>..]&, fmarks: u8[>..]&) -> i64 {
    if !sp_model_ok(sp, hunks, names, marks, marks, [], false) { return ERR_BAD_PATCH; }
    fsp.old_name = sp_copy_name(fnames, names, sp.new_name);
    fsp.new_name = sp_copy_name(fnames, names, sp.old_name);
    fsp.old_header = sp_copy_name(fnames, names, sp.new_header);
    fsp.new_header = sp_copy_name(fnames, names, sp.old_header);
    fsp.first_hunk = fhunks.len;
    fsp.hunks = 0;
    var hi = sp.first_hunk;
    while hi < sp.first_hunk + sp.hunks {
        let h = hunks[hi];
        fhunks.push(Hunk { old_start: h.new_start, old_lines: h.new_lines,
                           new_start: h.old_start, new_lines: h.old_lines,
                           first_line: h.first_line, lines: h.lines });
        fsp.hunks = fsp.hunks + 1;
        var li = h.first_line;
        while li < h.first_line + h.lines {
            let m = marks[li];
            if m == '-' { fmarks.push('+'); }
            else if m == '+' { fmarks.push('-'); }
            else { fmarks.push(m); }
            li = li + 1;
        }
        hi = hi + 1;
    }
    return ERR_OK;
}
