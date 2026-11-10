// The apply of a structured patch with a fuzz rule.
//
// The walk follows the apply of jsdiff. A context line that mismatches
// costs one of the errors of the rule `fuzz`, and the walk then tries
// the three cases: the line is a substitution, an insertion or a
// deletion that the patch does not hold. A removed line must always
// match exactly. The places walk around the place of the hunk header,
// near first. The place that sat becomes the base of the next hunk.
// Every try spends from the budget.
namespace diff;

import std;

// The most errors that one hunk may spend.
const MAX_FUZZ: i64 = 100;

// Applied is one line of the result of a hunk. The field `src` holds
// the place in the source when the line comes from there, or -1 when
// it comes from the hunk. The field `hunk_line` holds the place of the
// line in the hunk.
struct Applied {
    src: i64,
    hunk_line: i64,
}

// patch_apply_fuzz appends the text of the source after the patch is
// applied. The rule `fuzz` of the options gives the most context lines
// that may mismatch. A fault leaves the buffer as it was. It gives a
// code.
fn patch_apply_fuzz(src: const u8[:], sp: SPatch, hunks: const Hunk[:], marks: const u8[:],
                    body: const u8[:], lspans: const Span[:], o: ApplyOptions,
                    out: u8[>..]&) -> i64 {
    if src.len > o.max_input { return ERR_TOO_LARGE; }
    if o.max_work < 0 || o.max_shift < 0 || o.fuzz < 0 || o.fuzz > MAX_FUZZ { return ERR_BAD_OPTION; }
    // The apply reads no name, so the check sees the names as empty.
    var nb: u8[>..] = [];
    var sz = sp;
    sz.old_name = Span { at: 0, len: 0 };
    sz.new_name = Span { at: 0, len: 0 };
    sz.old_header = Span { at: 0, len: 0 };
    sz.new_header = Span { at: 0, len: 0 };
    if !sp_model_ok(sz, hunks, nb[..], marks, body, lspans, true) { return ERR_BAD_PATCH; }
    let base = out.len;
    var cm: i64 = 0;
    if o.auto_line_ends { cm = sp_mode(src, sp, hunks, marks, body, lspans); }
    let code = spatch_apply_into(src, sp, hunks, marks, body, lspans, cm, o, out);
    if code != ERR_OK { out.resize(base, 0); }
    return code;
}

// sp_line_at appends the bytes of the source line `p`, with its line
// end.
fn sp_line_at(src: const u8[:], ls: const Span[:], p: i64, out: u8[>..]&) {
    let s = ls[p];
    for k in s.len { out.push(src[s.at + k]); }
}

// sp_no_end tells whether the body line `li` has no line end in its
// file. The marker line of GNU diff follows such a line.
fn sp_no_end(marks: const u8[:], li: i64) -> bool {
    return li + 1 < marks.len && marks[li + 1] == '\\';
}

// sp_cr_extra tells whether the conversion mode 1 adds a carriage return
// to the hunk line `li`. The line must not end in one, and no marker
// line may follow it.
fn sp_cr_extra(body: const u8[:], lspans: const Span[:], marks: const u8[:], li: i64, cm: i64) -> bool {
    if cm != 1 || marks[li] == '\\' || sp_no_end(marks, li) { return false; }
    let c = lspans[li];
    return !(c.len > 0 && body[c.at + c.len - 1] == 13);
}

// sp_cr_cut tells whether the conversion mode 2 cuts a carriage return
// from the end of the hunk line `li`.
fn sp_cr_cut(body: const u8[:], lspans: const Span[:], marks: const u8[:], li: i64, cm: i64) -> bool {
    if cm != 2 || marks[li] == '\\' { return false; }
    let c = lspans[li];
    return c.len > 0 && body[c.at + c.len - 1] == 13;
}

// sp_matches tells whether the source line `p` is the hunk line `li`.
// A hunk line holds no line end. A source line must have a line end
// unless a marker line follows the hunk line. The mode `cm` converts the
// line ends of the hunk line first.
fn sp_matches(src: const u8[:], ls: const Span[:], body: const u8[:], lspans: const Span[:],
              li: i64, p: i64, marks: const u8[:], cm: i64) -> bool {
    if p >= ls.len { return false; }
    // A line with the marker of GNU diff counts for neither side.
    if marks[li] == '\\' { return false; }
    let s = ls[p];
    let c = lspans[li];
    var slen = s.len;
    let has_end = slen > 0 && src[s.at + slen - 1] == 10;
    if has_end { slen = slen - 1; }
    if has_end == sp_no_end(marks, li) { return false; }
    var clen = c.len;
    if sp_cr_cut(body, lspans, marks, li, cm) { clen = clen - 1; }
    let extra = sp_cr_extra(body, lspans, marks, li, cm);
    if extra { clen = clen + 1; }
    if slen != clen { return false; }
    var real = clen;
    if extra { real = clen - 1; }
    for k in real {
        if src[s.at + k] != body[c.at + k] { return false; }
    }
    if extra && src[s.at + real] != 13 { return false; }
    return true;
}

// sp_mode gives the conversion mode of the line ends: 0 for none, 1 to
// give the patch the CRLF of the text, 2 to cut the CRLF of the patch.
fn sp_mode(src: const u8[:], sp: SPatch, hunks: const Hunk[:], marks: const u8[:],
           body: const u8[:], lspans: const Span[:]) -> i64 {
    var crlf = false;
    var bare = false;
    for i in src.len {
        if src[i] == 13 && i + 1 < src.len && src[i + 1] == 10 { crlf = true; }
        if src[i] == 10 && (i == 0 || src[i - 1] != 13) { bare = true; }
    }
    var lf = false;
    for i in src.len { if src[i] == 10 { lf = true; } }
    let win_src = crlf && !bare;
    let unix_src = !crlf && lf;
    if !win_src && !unix_src { return 0; }
    var any_cr = false;
    var all_cr = true;
    for hi in sp.hunks {
        let h = hunks[sp.first_hunk + hi];
        for k in h.lines {
            let li = h.first_line + k;
            if marks[li] == '\\' { continue; }
            let c = lspans[li];
            if c.len > 0 && body[c.at + c.len - 1] == 13 { any_cr = true; }
            else if !sp_no_end(marks, li) { all_cr = false; }
        }
    }
    if win_src && !any_cr { return 1; }
    if unix_src && any_cr && all_cr { return 2; }
    return 0;
}

// spatch_apply_into walks the hunks and writes the result.
fn spatch_apply_into(src: const u8[:], sp: SPatch, hunks: const Hunk[:], marks: const u8[:],
                     body: const u8[:], lspans: const Span[:], cm: i64, o: ApplyOptions,
                     out: u8[>..]&) -> i64 {
    var ls: Span[>..] = [];
    split_lines(src, ls);
    var min_line: i64 = 0;
    var prev_offset: i64 = 0;
    var work: i64 = 0;
    var hi = sp.first_hunk;
    while hi < sp.first_hunk + sp.hunks {
        let h = hunks[hi];
        // The count of the old lines that the hunk needs, without the
        // lines with the marker of GNU diff.
        var need: i64 = 0;
        var li = h.first_line;
        while li < h.first_line + h.lines {
            if marks[li] == ' ' || marks[li] == '-' { need = need + 1; }
            li = li + 1;
        }
        var max_line = ls.len - need + o.fuzz;
        if max_line > ls.len { max_line = ls.len; }
        var found: i64 = -1;
        var found_pos: i64 = -1;
        var found_next: i64 = -1;
        var found_len: i64 = 0;
        var patched: Applied[>..] = [];
        var errors: i64 = 0;
        while errors <= o.fuzz && found < 0 && work <= o.max_work {
            // The places walk near the place of the header first.
            let start = h.old_start + prev_offset - 1;
            var step: i64 = 0;
            while step <= o.max_shift && found < 0 && work <= o.max_work {
                var side: i64 = 0;
                while side < 2 && found < 0 {
                    var pos = start + step;
                    if side == 1 { pos = start - step; }
                    if (side == 0 || step > 0) && pos >= min_line && pos <= max_line {
                        patched.resize(0, Applied { src: -1, hunk_line: 0 });
                        let r = hunk_walk(src, ls, h, marks, body, lspans, 0, pos, errors,
                                          true, false, patched, 0, work, o.max_work, cm);
                        if r >= 0 {
                            found = 1;
                            found_pos = pos;
                            found_next = r;
                            found_len = patched.len;
                        }
                    }
                    side = side + 1;
                }
                step = step + 1;
            }
            errors = errors + 1;
        }
        if found < 0 {
            if work > o.max_work { return ERR_TOO_MUCH_WORK; }
            return ERR_NO_MATCH;
        }
        // The lines before the hunk stay as they are.
        var k = min_line;
        while k < found_pos {
            sp_line_at(src, ls, k, out);
            k = k + 1;
        }
        k = 0;
        while k < found_len {
            let e = patched[k];
            if e.src >= 0 {
                sp_line_at(src, ls, e.src, out);
            } else {
                let c = lspans[h.first_line + e.hunk_line];
                var n = c.len;
                if sp_cr_cut(body, lspans, marks, h.first_line + e.hunk_line, cm) { n = n - 1; }
                for b in n { out.push(body[c.at + b]); }
                if sp_cr_extra(body, lspans, marks, h.first_line + e.hunk_line, cm) { out.push(13); }
                if !sp_no_end(marks, h.first_line + e.hunk_line) { out.push(10); }
            }
            k = k + 1;
        }
        min_line = found_next;
        prev_offset = found_pos + 1 - h.old_start;
        hi = hi + 1;
    }
    var k = min_line;
    while k < ls.len {
        sp_line_at(src, ls, k, out);
        k = k + 1;
    }
    return ERR_OK;
}

// hunk_walk tries to sit the hunk lines from `li` at the place `pos`.
// It gives the first line of the source that follows the hunk, or -1
// when it cannot sit. The result lines go into `patched` from `pbase`.
// A context line that mismatches costs one error and the walk tries
// the three cases of jsdiff.
recursive fn hunk_walk(src: const u8[:], ls: const Span[:], h: Hunk, marks: const u8[:],
                       body: const u8[:], lspans: const Span[:], li: i64, pos: i64,
                       errors: i64, last_ok: bool, next_must: bool, patched: Applied[>..]&,
                       pbase: i64, work: i64&, max_work: i64, cm: i64) -> i64 {
    work = work + 1;
    if work > max_work { return -1; }
    var p = pos;
    var i = li;
    var errs = errors;
    var last = last_ok;
    var must = next_must;
    var streak: i64 = 0;
    while i < h.lines {
        let lix = h.first_line + i;
        let m = marks[lix];
        if m == '\\' {
            // The marker line counts for neither side.
            i = i + 1;
        } else if m == '-' {
            if sp_matches(src, ls, body, lspans, lix, p, marks, cm) {
                p = p + 1;
                i = i + 1;
                streak = 0;
            } else {
                if errs <= 0 || p >= ls.len { return -1; }
                // The source line stays. The walk retries the same
                // hunk line at the next place.
                patched.push(Applied { src: p, hunk_line: i });
                errs = errs - 1;
                last = false;
                p = p + 1;
            }
        } else if m == '+' {
            if !last { return -1; }
            patched.push(Applied { src: -1, hunk_line: i });
            streak = 0;
            must = true;
            i = i + 1;
        } else {
            if p >= ls.len { return -1; }
            patched.push(Applied { src: p, hunk_line: i });
            if sp_matches(src, ls, body, lspans, lix, p, marks, cm) {
                p = p + 1;
                streak = streak + 1;
                last = true;
                must = false;
                i = i + 1;
            } else {
                if next_must || errs <= 0 { return -1; }
                // The line may be a substitution, an insertion or a
                // deletion that the patch does not hold.
                let here = patched.len;
                let r1 = hunk_walk(src, ls, h, marks, body, lspans, i + 1, p + 1, errs - 1,
                                   false, false, patched, here, work, max_work, cm);
                if r1 >= 0 { return r1; }
                patched.resize(here, Applied { src: -1, hunk_line: 0 });
                let r2 = hunk_walk(src, ls, h, marks, body, lspans, i, p + 1, errs - 1,
                                   false, false, patched, here, work, max_work, cm);
                if r2 >= 0 { return r2; }
                patched.resize(here, Applied { src: -1, hunk_line: 0 });
                let r3 = hunk_walk(src, ls, h, marks, body, lspans, i + 1, p, errs - 1,
                                   false, false, patched, here, work, max_work, cm);
                if r3 >= 0 { return r3; }
                patched.resize(pbase, Applied { src: -1, hunk_line: 0 });
                return -1;
            }
        }
    }
    return sp_trim(patched, pbase, p, h, marks);
}

// sp_trim takes the trailing context lines of the hunk off the result
// and gives the first line of the source that follows the hunk. A
// later hunk may then start inside the trailing context of this one.
fn sp_trim(patched: Applied[>..]&, from: i64, p: i64, h: Hunk, marks: const u8[:]) -> i64 {
    // The walk counted the context in `streak`, but the recursion
    // forgot it, so the walk counts again from the end of the hunk.
    var streak: i64 = 0;
    var i = h.lines - 1;
    while i >= 0 && marks[h.first_line + i] == ' ' {
        streak = streak + 1;
        i = i - 1;
    }
    if patched.len - from < streak { streak = patched.len - from; }
    patched.resize(patched.len - streak, Applied { src: -1, hunk_line: 0 });
    return p - streak;
}
