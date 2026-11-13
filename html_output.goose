// The HTML file and the HTML table of the side by side HTML diff.
//
namespace diff;

import std;

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
