// The change list in the forms of jsdiff.
//
// The XML form wraps removed text in <del> and added text in <ins>.
// It escapes the text as jsdiff does. The diff-match-patch form is a
// JSON array of pairs of a tag and a text.
namespace diff;

import std;

// esc_html appends the text with the escape of &, <, > and the quote.
fn esc_html(out: u8[>..]&, text: const u8[:], s: Span) {
    var i = s.at;
    let end = s.at + s.len;
    while i < end {
        let c = text[i];
        if c == '&' { put_text(out, "&amp;"); }
        else if c == '<' { put_text(out, "&lt;"); }
        else if c == '>' { put_text(out, "&gt;"); }
        else if c == '"' { put_text(out, "&quot;"); }
        else { out.push(c); }
        i = i + 1;
    }
}

// changes_ok tells whether every change lies inside its text.
fn changes_ok(changes: const Change[:], a: const u8[:], b: const u8[:]) -> bool {
    for ch in changes {
        var n = a.len;
        if ch.text != 0 { n = b.len; }
        if !sp_span_ok(Span { at: ch.at, len: ch.len }, n) { return false; }
    }
    return true;
}

// changes_xml writes the change list in the form of jsdiff
// convertChangesToXML. Removed text goes into <del>, added text into
// <ins>. Equal text stays plain, with the escape. It gives a code.
fn changes_xml(changes: const Change[:], a: const u8[:], b: const u8[:], out: u8[>..]&) -> i64 {
    if !changes_ok(changes, a, b) { return ERR_BAD_OPTION; }
    for ch in changes {
        var text = a;
        if ch.text != 0 { text = b; }
        if ch.added {
            put_text(out, "<ins>");
            esc_html(out, text, Span { at: ch.at, len: ch.len });
            put_text(out, "</ins>");
        } else if ch.removed {
            put_text(out, "<del>");
            esc_html(out, text, Span { at: ch.at, len: ch.len });
            put_text(out, "</del>");
        } else {
            esc_html(out, text, Span { at: ch.at, len: ch.len });
        }
    }
    return ERR_OK;
}

// changes_dmp writes the change list as the array of jsdiff
// convertChangesToDMP. The tag is 0 for equal, -1 for removed and 1
// for added. The text follows as a JSON string. It gives a code.
fn changes_dmp(changes: const Change[:], a: const u8[:], b: const u8[:], out: u8[>..]&) -> i64 {
    if !changes_ok(changes, a, b) { return ERR_BAD_OPTION; }
    out.push('[');
    var first = true;
    for ch in changes {
        if !first { out.push(','); }
        first = false;
        out.push('[');
        if ch.added { out.push('1'); }
        else if ch.removed { out.push('-'); out.push('1'); }
        else { out.push('0'); }
        out.push(',');
        var text = a;
        if ch.text != 0 { text = b; }
        json_string(out, text[ch.at..ch.at + ch.len]);
        out.push(']');
    }
    out.push(']');
    return ERR_OK;
}
