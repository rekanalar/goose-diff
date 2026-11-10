// The side by side HTML diff of the Python library difflib: HtmlDiff.
//
// The table has one row for each pair of lines. The middle columns hold
// the links to the changes. The text comes from the delta of `ndiff`:
// the lines with a code and the lines of hints. A change inside a line
// goes into a span. The call escapes every text and every description.
namespace diff;

import std;

// The code of a text that holds a byte that the table uses as a mark.
const ERR_BAD_TEXT: i64 = 9;

// The most that a rule of a table may hold.
const MAX_HTML_RULE: i64 = 1073741824;

// HtmlOptions holds the rules of a table.
struct HtmlOptions {
    // The tab stop spacing. A value of zero or less removes the tabs.
    tabsize: i64,
    // The column where a line breaks. Zero means no break.
    wrapcolumn: i64,
    // Show only the lines near a change.
    context: bool,
    // The lines of context, or the lines before a link anchor.
    numlines: i64,
    // The number of the anchor prefix. Give each table of a page its own.
    prefix: i64,
    // The most bytes of the output.
    max_output: i64,
}

// default_html_options gives the rules of Python: a tab stop of 8, no
// break, all lines, 5 lines, the prefix 0 and 64 MiB of output.
fn default_html_options() -> HtmlOptions {
    return HtmlOptions { tabsize: 8, wrapcolumn: 0, context: false, numlines: 5,
                         prefix: 0, max_output: 67108864 };
}

// HLine is one side of a row: the line number, the place of the text in
// the text buffer and the change flag. The number 0 is a blank line and
// the number -1 is the mark of a wrapped line. The fields `pre` and
// `post` hold an open span at the start and a close at the end.
struct HLine {
    num: i64,
    at: i64,
    len: i64,
    flag: bool,
    pre: u8,
    post: bool,
}

// HRow is one pair of lines. The flag is 0 for equal text, 1 for a
// change and 2 for the separator of the context form.
struct HRow {
    from: HLine,
    to: HLine,
    flag: i64,
}

// HEnt is a row of the table with its cells written. The cells are
// places in the cell buffer.
struct HEnt {
    fat: i64,
    flen: i64,
    tat: i64,
    tlen: i64,
    flag: i64,
}

fn hd_blank() -> HLine {
    return HLine { num: 0, at: 0, len: 0, flag: false, pre: 0, post: false };
}

// hd_bad_byte tells whether a text holds a byte that the table uses as a
// mark.
fn hd_bad_byte(text: const u8[:]) -> bool {
    for c in text {
        if c == 0 || c == 1 { return true; }
    }
    return false;
}

// hd_expand writes the lines of a text without line end and with the tabs
// expanded to tab bytes, as _tab_newline_replace does. Every line ends
// with a line feed. The column counts code points.
fn hd_expand(src: const u8[:], tabsize: i64, cap: i64, out: u8[>..]&) -> i64 {
    var ls: Span[>..] = [];
    split_lines(src, ls);
    for li in ls.len {
        let s = ls[li];
        var end = s.at + s.len;
        if src[end - 1] == 10 { end = end - 1; }
        var col: i64 = 0;
        var i = s.at;
        while i < end {
            let c = src[i];
            if c == 9 {
                if tabsize > 0 {
                    let n = tabsize - col % tabsize;
                    if out.len + n > cap { return ERR_TOO_LARGE; }
                    for k in n { out.push(9); }
                    col = col + n;
                }
                i = i + 1;
            } else {
                var w: i64 = 1;
                if c != 13 { w = tok_width(src, i); }
                if i + w > end { w = end - i; }
                for k in w { out.push(src[i + k]); }
                if c == 13 { col = 0; } else { col = col + 1; }
                i = i + w;
            }
            if out.len > cap { return ERR_TOO_LARGE; }
        }
        out.push(10);
    }
    return ERR_OK;
}

// hd_content gives the text of a delta line without its code and its
// line end.
fn hd_content(delta: const u8[:], d: Span) -> Span {
    var at = d.at + 2;
    var end = d.at + d.len;
    if end > d.at && delta[end - 1] == 10 { end = end - 1; }
    if at > end { at = end; }
    return Span { at: at, len: end - at };
}

// hd_make builds one line of a row from the delta lines at `p`, as
// _make_line does. The key is 0 for a plain line, '-' or '+' for a whole
// line and '?' for a line with the hints in the next line.
fn hd_make(delta: const u8[:], dl: const Span[:], p: i64&, key: u8, num: i64&,
           tx: u8[>..]&) -> HLine {
    num = num + 1;
    let start = tx.len;
    if key == '?' {
        let t = dl[p];
        let m = dl[p + 1];
        p = p + 2;
        var tend = t.at + t.len;
        if tend > t.at && delta[tend - 1] == 10 { tend = tend - 1; }
        var mend = m.at + m.len;
        if mend > m.at && delta[mend - 1] == 10 { mend = mend - 1; }
        // The kind of every code point of the hint line.
        var kinds: u8[>..] = [];
        var mi = m.at;
        while mi < mend {
            let w = tok_width(delta, mi);
            let c = delta[mi];
            if w == 1 && (c == '+' || c == '-' || c == '^') { kinds.push(c); } else { kinds.push(0); }
            mi = mi + w;
        }
        var cur: u8 = 0;
        var k: i64 = 0;
        var ti = t.at;
        while ti < tend {
            let w = tok_width(delta, ti);
            if k >= 2 {
                var kind: u8 = 0;
                if k < kinds.len { kind = kinds[k]; }
                if kind != cur {
                    if cur != 0 { tx.push(1); }
                    if kind != 0 { tx.push(0); tx.push(kind); }
                    cur = kind;
                }
                for j in w { tx.push(delta[ti + j]); }
            }
            ti = ti + w;
            k = k + 1;
        }
        if cur != 0 { tx.push(1); }
    } else {
        let c = hd_content(delta, dl[p]);
        p = p + 1;
        if key == 0 {
            for j in c.len { tx.push(delta[c.at + j]); }
        } else {
            tx.push(0);
            tx.push(key);
            if c.len == 0 { tx.push(' '); }
            for j in c.len { tx.push(delta[c.at + j]); }
            tx.push(1);
        }
    }
    return HLine { num: num, at: start, len: tx.len - start, flag: false, pre: 0, post: false };
}

// hd_push queues the lines of an event and pairs what both queues hold.
fn hd_push(fq: HLine[>..]&, tq: HLine[>..]&, fh: i64&, th: i64&, rows: HRow[>..]&,
           has_from: bool, f: HLine, has_to: bool, t: HLine, flag: bool) {
    if has_from {
        var x = f;
        x.flag = flag;
        fq.push(x);
    }
    if has_to {
        var y = t;
        y.flag = flag;
        tq.push(y);
    }
    while fh < fq.len && th < tq.len {
        let a = fq[fh];
        let b = tq[th];
        fh = fh + 1;
        th = th + 1;
        var fl: i64 = 0;
        if a.flag || b.flag { fl = 1; }
        rows.push(HRow { from: a, to: b, flag: fl });
    }
}

// hd_tag gives the code of the delta line `k` or 'X' past the end.
fn hd_tag(delta: const u8[:], dl: const Span[:], k: i64) -> u8 {
    if k >= dl.len { return 'X'; }
    return delta[dl[k].at];
}

// hd_pairs reads the delta and gives the pairs of lines, as _mdiff does
// before the context rule.
fn hd_pairs(delta: const u8[:], dl: const Span[:], tx: u8[>..]&, rows: HRow[>..]&) {
    var fq: HLine[>..] = [];
    var tq: HLine[>..] = [];
    var fh: i64 = 0;
    var th: i64 = 0;
    var p: i64 = 0;
    var n0: i64 = 0;
    var n1: i64 = 0;
    var pending: i64 = 0;
    let none = hd_blank();
    while true {
        let c0 = hd_tag(delta, dl, p);
        let c1 = hd_tag(delta, dl, p + 1);
        let c2 = hd_tag(delta, dl, p + 2);
        let c3 = hd_tag(delta, dl, p + 3);
        var to_yield: i64 = 0;
        var from_line = none;
        var to_line = none;
        var has_from = false;
        var has_to = false;
        if c0 == 'X' {
            to_yield = pending;
        } else if c0 == '-' && c1 == '?' && c2 == '+' && c3 == '?' {
            let f = hd_make(delta, dl, p, '?', n0, tx);
            let t = hd_make(delta, dl, p, '?', n1, tx);
            hd_push(fq, tq, fh, th, rows, true, f, true, t, true);
            continue;
        } else if c0 == '-' && c1 == '-' && c2 == '+' && c3 == '+' {
            pending = pending - 1;
            let f = hd_make(delta, dl, p, '-', n0, tx);
            hd_push(fq, tq, fh, th, rows, true, f, false, none, true);
            continue;
        } else if c0 == '-' && ((c1 == '-' && c2 == '?' && c3 == '+') || (c1 == '-' && c2 == '+') || c1 == ' ') {
            from_line = hd_make(delta, dl, p, '-', n0, tx);
            has_from = true;
            to_yield = pending - 1;
            pending = 0;
        } else if c0 == '-' && c1 == '+' && c2 == '?' {
            let f = hd_make(delta, dl, p, 0, n0, tx);
            let t = hd_make(delta, dl, p, '?', n1, tx);
            hd_push(fq, tq, fh, th, rows, true, f, true, t, true);
            continue;
        } else if c0 == '-' && c1 == '?' && c2 == '+' {
            let f = hd_make(delta, dl, p, '?', n0, tx);
            let t = hd_make(delta, dl, p, 0, n1, tx);
            hd_push(fq, tq, fh, th, rows, true, f, true, t, true);
            continue;
        } else if c0 == '-' {
            pending = pending - 1;
            let f = hd_make(delta, dl, p, '-', n0, tx);
            hd_push(fq, tq, fh, th, rows, true, f, false, none, true);
            continue;
        } else if c0 == '+' && c1 == '-' && c2 == '-' {
            pending = pending + 1;
            let t = hd_make(delta, dl, p, '+', n1, tx);
            hd_push(fq, tq, fh, th, rows, false, none, true, t, true);
            continue;
        } else if c0 == '+' && (c1 == ' ' || c1 == '-') {
            to_line = hd_make(delta, dl, p, '+', n1, tx);
            has_to = true;
            to_yield = pending + 1;
            pending = 0;
        } else if c0 == '+' {
            pending = pending + 1;
            let t = hd_make(delta, dl, p, '+', n1, tx);
            hd_push(fq, tq, fh, th, rows, false, none, true, t, true);
            continue;
        } else if c0 == ' ' {
            var q = p;
            let f = hd_make(delta, dl, q, 0, n0, tx);
            let t = hd_make(delta, dl, p, 0, n1, tx);
            hd_push(fq, tq, fh, th, rows, true, f, true, t, false);
            continue;
        } else {
            // A line with another code: the delta of the package holds none.
            p = p + 1;
            continue;
        }
        while to_yield < 0 {
            to_yield = to_yield + 1;
            hd_push(fq, tq, fh, th, rows, false, none, true, none, true);
        }
        while to_yield > 0 {
            to_yield = to_yield - 1;
            hd_push(fq, tq, fh, th, rows, true, none, false, none, true);
        }
        if c0 == 'X' { return; }
        hd_push(fq, tq, fh, th, rows, has_from, from_line, has_to, to_line, true);
    }
}

// hd_context keeps the rows near a change, as _mdiff does with a count of
// lines of context. A separator row stands for the lines left out.
fn hd_context(rows: const HRow[:], numlines: i64, out: HRow[>..]&) {
    let ctx = numlines + 1;
    let sep = HRow { from: hd_blank(), to: hd_blank(), flag: 2 };
    var pos: i64 = 0;
    while true {
        let start = pos;
        var q = pos;
        while q < rows.len && rows[q].flag == 0 { q = q + 1; }
        if q >= rows.len { return; }
        let count = q - start + 1;
        var first = start;
        if count > ctx {
            out.push(sep);
            first = q - ctx + 1;
        }
        var r = first;
        while r <= q {
            out.push(rows[r]);
            r = r + 1;
        }
        pos = q + 1;
        var w = ctx - 1;
        while w > 0 && pos < rows.len {
            let row = rows[pos];
            pos = pos + 1;
            if row.flag != 0 { w = ctx - 1; } else { w = w - 1; }
            out.push(row);
        }
        if w > 0 { return; }
    }
}

// hd_count counts the code points of a span of the text buffer and the
// marks that open a span.
fn hd_count(tx: const u8[:], at: i64, len: i64, zeros: i64&) -> i64 {
    var n: i64 = 0;
    var i = at;
    let end = at + len;
    zeros = 0;
    while i < end {
        if tx[i] == 0 { zeros = zeros + 1; }
        i = i + tok_width(tx, i);
        n = n + 1;
    }
    return n;
}

// hd_split breaks a line at the wrap column, as _split_line does. The
// pieces hold places of the text buffer. A break inside a change span
// closes the span in one piece and opens it in the next.
fn hd_split(tx: const u8[:], l: HLine, w: i64, pieces: HLine[>..]&) {
    if l.num == 0 {
        pieces.push(l);
        return;
    }
    var zeros: i64 = 0;
    var size = hd_count(tx, l.at, l.len, zeros);
    var bp = l.at;
    let end = l.at + l.len;
    var num = l.num;
    var pre: u8 = 0;
    while true {
        if size <= w || size - zeros * 3 <= w {
            pieces.push(HLine { num: num, at: bp, len: end - bp, flag: false, pre: pre, post: false });
            return;
        }
        var i: i64 = 0;
        var n: i64 = 0;
        var mark: u8 = 0;
        var took: i64 = 0;
        if pre != 0 {
            mark = pre;
            i = 2;
        }
        var q = bp;
        while n < w && i < size {
            let b = tx[q];
            if b == 0 {
                mark = tx[q + 1];
                q = q + 2;
                i = i + 2;
                took = took + 1;
            } else if b == 1 {
                q = q + 1;
                i = i + 1;
                mark = 0;
            } else {
                q = q + tok_width(tx, q);
                i = i + 1;
                n = n + 1;
            }
        }
        pieces.push(HLine { num: num, at: bp, len: q - bp, flag: false, pre: pre, post: mark != 0 });
        // The rest holds the marks that the scan did not meet.
        if pre != 0 { zeros = zeros - 1; }
        zeros = zeros - took;
        size = size - i;
        if mark != 0 {
            size = size + 2;
            zeros = zeros + 1;
        }
        pre = mark;
        bp = q;
        num = -1;
    }
}

// hd_text writes the text of a line: the escape of the markup, the
// non-breaking space and the spans of the changes. White space at the
// end goes out, except the blank.
fn hd_text(out: u8[>..]&, tx: const u8[:], l: HLine) {
    var end = l.at + l.len;
    if !l.post {
        var last = l.at;
        var i = l.at;
        while i < end {
            let w = tok_width(tx, i);
            var code = tx[i] as i64;
            if w > 1 { code = nd_code(tx, Span { at: i, len: w }); }
            if !nd_space(code) || code == 32 { last = i + w; }
            i = i + w;
        }
        end = last;
    }
    if l.pre == '+' { put_text(out, "<span class=\"diff_add\">"); }
    else if l.pre == '-' { put_text(out, "<span class=\"diff_sub\">"); }
    else if l.pre == '^' { put_text(out, "<span class=\"diff_chg\">"); }
    var i = l.at;
    while i < end {
        let c = tx[i];
        if c == 0 {
            let k = tx[i + 1];
            if k == '+' { put_text(out, "<span class=\"diff_add\">"); }
            else if k == '-' { put_text(out, "<span class=\"diff_sub\">"); }
            else { put_text(out, "<span class=\"diff_chg\">"); }
            i = i + 2;
        } else if c == 1 { put_text(out, "</span>"); i = i + 1; }
        else if c == '&' { put_text(out, "&amp;"); i = i + 1; }
        else if c == '<' { put_text(out, "&lt;"); i = i + 1; }
        else if c == '>' { put_text(out, "&gt;"); i = i + 1; }
        else if c == ' ' || c == 9 { put_text(out, "&nbsp;"); i = i + 1; }
        else { out.push(c); i = i + 1; }
    }
    if l.post { put_text(out, "</span>"); }
}

// hd_cell writes the two cells of one side of a row.
fn hd_cell(out: u8[>..]&, tx: const u8[:], side: i64, prefix: i64, l: HLine) {
    put_text(out, "<td class=\"diff_header\"");
    if l.num > 0 {
        if side == 0 { put_text(out, " id=\"from"); } else { put_text(out, " id=\"to"); }
        digits_of(out, prefix);
        put_text(out, "_");
        digits_of(out, l.num);
        put_text(out, "\"");
    }
    out.push('>');
    if l.num > 0 { digits_of(out, l.num); }
    else if l.num < 0 { out.push('>'); }
    put_text(out, "</td><td nowrap=\"nowrap\">");
    hd_text(out, tx, l);
    put_text(out, "</td>");
}

// hd_desc writes a description. It escapes the quote too.
fn hd_desc(out: u8[>..]&, d: const u8[:]) {
    for c in d {
        if c == '&' { put_text(out, "&amp;"); }
        else if c == '<' { put_text(out, "&lt;"); }
        else if c == '>' { put_text(out, "&gt;"); }
        else if c == '"' { put_text(out, "&quot;"); }
        else if c == 9 { put_text(out, "&nbsp;"); }
        else { out.push(c); }
    }
}

// hd_anchor writes the name of an anchor of a change.
fn hd_anchor(out: u8[>..]&, prefix: i64) {
    put_text(out, "difflib_chg_to");
    digits_of(out, prefix);
    put_text(out, "__");
}

// hd_link writes the link of a row.
fn hd_link(out: u8[>..]&, prefix: i64, kind: u8, num: i64) {
    if kind == 0 { return; }
    put_text(out, "<a href=\"#");
    hd_anchor(out, prefix);
    if kind == 't' { put_text(out, "top"); } else { digits_of(out, num); }
    put_text(out, "\">");
    out.push(kind);
    put_text(out, "</a>");
}

// html_body builds the rows, the cells and the table text in `out`.
fn html_body(a: const u8[:], b: const u8[:], from_desc: const u8[:], to_desc: const u8[:],
             o: Options, h: HtmlOptions, out: u8[>..]&) -> i64 {
    if !options_ok(o) { return ERR_BAD_OPTION; }
    if h.numlines < 0 || h.numlines > MAX_HTML_RULE || h.wrapcolumn < 0 || h.wrapcolumn > MAX_HTML_RULE { return ERR_BAD_OPTION; }
    if h.prefix < 0 || h.max_output < 0 || h.tabsize > MAX_HTML_RULE { return ERR_BAD_OPTION; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE; }
    if hd_bad_byte(a) || hd_bad_byte(b) || hd_bad_byte(from_desc) || hd_bad_byte(to_desc) { return ERR_BAD_TEXT; }
    var ta: u8[>..] = [];
    var tb: u8[>..] = [];
    var code = hd_expand(a, h.tabsize, h.max_output, ta);
    if code != ERR_OK { return code; }
    code = hd_expand(b, h.tabsize, h.max_output, tb);
    if code != ERR_OK { return code; }
    var delta: u8[>..] = [];
    code = ndiff_into(ta[..], tb[..], o, true, delta);
    if code != ERR_OK { return code; }
    var dl: Span[>..] = [];
    split_lines(delta[..], dl);
    var tx: u8[>..] = [];
    var rows: HRow[>..] = [];
    hd_pairs(delta[..], dl[..], tx, rows);
    var shown: HRow[>..] = [];
    if h.context { hd_context(rows[..], h.numlines, shown); } else { for r in rows { shown.push(r); } }
    // Wrap the lines and write the cells.
    var cells: u8[>..] = [];
    var ents: HEnt[>..] = [];
    let fill = HLine { num: 0, at: tx.len, len: 1, flag: false, pre: 0, post: false };
    tx.push(' ');
    for r in shown {
        if r.flag == 2 {
            ents.push(HEnt { fat: 0, flen: 0, tat: 0, tlen: 0, flag: 2 });
            continue;
        }
        var fp: HLine[>..] = [];
        var tp: HLine[>..] = [];
        if h.wrapcolumn > 0 {
            hd_split(tx[..], r.from, h.wrapcolumn, fp);
            hd_split(tx[..], r.to, h.wrapcolumn, tp);
        } else {
            fp.push(r.from);
            tp.push(r.to);
        }
        var k: i64 = 0;
        while k < fp.len || k < tp.len {
            var f = fill;
            var t = fill;
            if k < fp.len { f = fp[k]; }
            if k < tp.len { t = tp[k]; }
            let fat = cells.len;
            hd_cell(cells, tx[..], 0, h.prefix, f);
            let flen = cells.len - fat;
            let tat = cells.len;
            hd_cell(cells, tx[..], 1, h.prefix, t);
            ents.push(HEnt { fat: fat, flen: flen, tat: tat, tlen: cells.len - tat, flag: r.flag });
            if cells.len > h.max_output { return ERR_TOO_LARGE; }
            k = k + 1;
        }
    }
    // The links of the middle columns.
    var n = ents.len;
    var nid: i64[>..] = [];
    var nhk: u8[>..] = [];
    var nhn: i64[>..] = [];
    var empty = false;
    if n == 0 {
        empty = true;
        n = 1;
    }
    for i in n {
        nid.push(-1);
        nhk.push(0);
        nhn.push(0);
    }
    var last: i64 = 0;
    var chg: i64 = 0;
    var in_change = false;
    var first_flag: i64 = 0;
    if !empty { first_flag = ents[0].flag; }
    for i in ents.len {
        if ents[i].flag == 1 {
            if !in_change {
                in_change = true;
                last = i;
                var j = i - h.numlines;
                if j < 0 { j = 0; }
                nid[j] = chg;
                chg = chg + 1;
                nhk[last] = 'n';
                nhn[last] = chg;
            }
        } else {
            in_change = false;
        }
    }
    if first_flag != 1 {
        nhk[0] = 'f';
        nhn[0] = 0;
    }
    nhk[last] = 't';
    // The table.
    put_text(out, "\n    <table class=\"diff\" id=\"");
    hd_anchor(out, h.prefix);
    put_text(out, "top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n");
    put_text(out, "        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n");
    put_text(out, "        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        ");
    if from_desc.len > 0 || to_desc.len > 0 {
        put_text(out, "<thead><tr><th class=\"diff_next\"><br /></th><th colspan=\"2\" class=\"diff_header\">");
        hd_desc(out, from_desc);
        put_text(out, "</th><th class=\"diff_next\"><br /></th><th colspan=\"2\" class=\"diff_header\">");
        hd_desc(out, to_desc);
        put_text(out, "</th></tr></thead>");
    }
    put_text(out, "\n        <tbody>\n");
    var i: i64 = 0;
    while i < n {
        if !empty && ents[i].flag == 2 {
            if i > 0 { put_text(out, "        </tbody>        \n        <tbody>\n"); }
            i = i + 1;
            continue;
        }
        put_text(out, "            <tr><td class=\"diff_next\"");
        if nid[i] >= 0 {
            put_text(out, " id=\"");
            hd_anchor(out, h.prefix);
            digits_of(out, nid[i]);
            put_text(out, "\"");
        }
        out.push('>');
        hd_link(out, h.prefix, nhk[i], nhn[i]);
        put_text(out, "</td>");
        if empty {
            if h.context { put_text(out, "<td></td><td>&nbsp;No Differences Found&nbsp;</td>"); }
            else { put_text(out, "<td></td><td>&nbsp;Empty File&nbsp;</td>"); }
        } else {
            for c in ents[i].flen { out.push(cells[ents[i].fat + c]); }
        }
        put_text(out, "<td class=\"diff_next\">");
        hd_link(out, h.prefix, nhk[i], nhn[i]);
        put_text(out, "</td>");
        if empty {
            if h.context { put_text(out, "<td></td><td>&nbsp;No Differences Found&nbsp;</td>"); }
            else { put_text(out, "<td></td><td>&nbsp;Empty File&nbsp;</td>"); }
        } else {
            for c in ents[i].tlen { out.push(cells[ents[i].tat + c]); }
        }
        put_text(out, "</tr>\n");
        if out.len > h.max_output { return ERR_TOO_LARGE; }
        i = i + 1;
    }
    put_text(out, "        </tbody>\n    </table>");
    return ERR_OK;
}

// html_table appends the table of the side by side diff of a against b,
// as HtmlDiff.make_table of Python does. The descriptions head the two
// columns. It gives a code. A fault leaves `out` as it was.
fn html_table(a: const u8[:], b: const u8[:], from_desc: const u8[:], to_desc: const u8[:],
              o: Options, h: HtmlOptions, out: u8[>..]&) -> i64 {
    var buf: u8[>..] = [];
    let code = html_body(a, b, from_desc, to_desc, o, h, buf);
    if code != ERR_OK { return code; }
    for c in buf { out.push(c); }
    return ERR_OK;
}

// charset_ok tells whether a charset name holds only the bytes that a
// name needs.
fn charset_ok(s: const u8[:]) -> bool {
    if s.len == 0 || s.len > 64 { return false; }
    for c in s {
        let ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
                 c == '-' || c == '_' || c == '.' || c == ':';
        if !ok { return false; }
    }
    return true;
}

// html_file appends a full page with the table and the legend, as
// HtmlDiff.make_file of Python does. The charset names the page. The
// bytes of the page are UTF-8. It gives a code.
fn html_file(a: const u8[:], b: const u8[:], from_desc: const u8[:], to_desc: const u8[:],
             charset: const u8[:], o: Options, h: HtmlOptions, out: u8[>..]&) -> i64 {
    if !charset_ok(charset) { return ERR_BAD_OPTION; }
    var table: u8[>..] = [];
    let code = html_body(a, b, from_desc, to_desc, o, h, table);
    if code != ERR_OK { return code; }
    put_text(out, HTML_FILE_HEAD);
    put_text(out, charset);
    put_text(out, HTML_FILE_MID);
    put_text(out, HTML_STYLES);
    put_text(out, HTML_FILE_TAIL);
    for c in table { out.push(c); }
    put_text(out, HTML_LEGEND);
    put_text(out, HTML_FILE_END);
    return ERR_OK;
}

// The text of the page, as Python 3.14 holds it.
const HTML_FILE_HEAD: const u8[:] = "\n<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n          \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n\n<html>\n\n<head>\n    <meta http-equiv=\"Content-Type\"\n          content=\"text/html; charset=";
const HTML_FILE_MID: const u8[:] = "\" />\n    <title></title>\n    <style type=\"text/css\">";
const HTML_STYLES: const u8[:] = "\n        :root {color-scheme: light dark}\n        table.diff {font-family: Menlo, Consolas, Monaco, Liberation Mono, Lucida Console, monospace; border:medium}\n        .diff_header {background-color:#e0e0e0}\n        td.diff_header {text-align:right}\n        .diff_next {background-color:#c0c0c0}\n        .diff_add {background-color:palegreen}\n        .diff_chg {background-color:#ffff77}\n        .diff_sub {background-color:#ffaaaa}\n\n        @media (prefers-color-scheme: dark) {\n            .diff_header {background-color:#666}\n            .diff_next {background-color:#393939}\n            .diff_add {background-color:darkgreen}\n            .diff_chg {background-color:#847415}\n            .diff_sub {background-color:darkred}\n        }";
const HTML_FILE_TAIL: const u8[:] = "\n    </style>\n</head>\n\n<body>\n    ";
const HTML_FILE_END: const u8[:] = "\n</body>\n\n</html>";
const HTML_LEGEND: const u8[:] = "\n    <table class=\"diff\" summary=\"Legends\">\n        <tr> <th colspan=\"2\"> Legends </th> </tr>\n        <tr> <td> <table border=\"\" summary=\"Colors\">\n                      <tr><th> Colors </th> </tr>\n                      <tr><td class=\"diff_add\">&nbsp;Added&nbsp;</td></tr>\n                      <tr><td class=\"diff_chg\">Changed</td> </tr>\n                      <tr><td class=\"diff_sub\">Deleted</td> </tr>\n                  </table></td>\n             <td> <table border=\"\" summary=\"Links\">\n                      <tr><th colspan=\"2\"> Links </th> </tr>\n                      <tr><td>(f)irst change</td> </tr>\n                      <tr><td>(n)ext change</td> </tr>\n                      <tr><td>(t)op</td> </tr>\n                  </table></td> </tr>\n    </table>";
