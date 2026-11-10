// Unified patches: read them, and apply them.
//
// The read takes the output of GNU diff, git diff, difflib and jsdiff.
// It skips the lines before a file header, such as "Index:" and
// "diff --git". A hunk must hold exactly the lines that its header
// counts. The apply checks every context line and every removed line,
// and it searches for a hunk that sits at another line than its header
// says. Work stays bounded: the search spends from a budget.
namespace diff;

import std;

// The codes of the faults of the patch.
const ERR_BAD_PATCH: i64 = 4;
const ERR_NO_MATCH: i64 = 5;
const ERR_TOO_MUCH_WORK: i64 = 6;
const ERR_NO_FILE: i64 = 7;

// The most files and hunks that a parse takes.
const MAX_FILES: i64 = 10000;
const MAX_HUNKS: i64 = 100000;

// FilePatch is the patch of one file. The names are places in the text
// of the patch. A name stops at a tab.
struct FilePatch {
    old_name: Span,
    new_name: Span,
    // The first hunk of the file and the count of its hunks.
    first_hunk: i64,
    hunks: i64,
}

// Hunk is one hunk. The body lines are places in the list of body
// lines. A body line holds its marker, its text and its line end.
struct Hunk {
    old_start: i64,
    old_lines: i64,
    new_start: i64,
    new_lines: i64,
    first_line: i64,
    lines: i64,
}

// starts_with tells whether the line begins with the prefix.
fn starts_with(text: const u8[:], s: Span, prefix: const u8[:]) -> bool {
    if s.len < prefix.len { return false; }
    for k in prefix.len {
        if text[s.at + k] != prefix[k] { return false; }
    }
    return true;
}

// number_at reads a decimal number from a line at a place. It gives the
// number, the place after it, and a flag that is false when no digit
// stands there or the number is longer than 15 digits.
fn number_at(text: const u8[:], s: Span, at: i64) -> i64, i64, bool {
    var v: i64 = 0;
    var i = at;
    while i < s.len && text[s.at + i] - '0' < 10 {
        if i - at >= 15 { return 0, i, false; }
        v = v * 10 + (text[s.at + i] - '0');
        i = i + 1;
    }
    return v, i, i > at;
}

// name_of reads a file name from the rest of a header line. The name
// stops at a tab or at the line end.
fn name_of(text: const u8[:], s: Span, from: i64) -> Span {
    var end = from;
    while end < s.len && text[s.at + end] != 9 && text[s.at + end] != 10 && text[s.at + end] != 13 {
        end = end + 1;
    }
    return Span { at: s.at + from, len: end - from };
}

// parse_range reads "-12,3" or "+12" after the marker. The count is 1
// when it is missing.
fn parse_range(text: const u8[:], s: Span, at: i64, marker: u8) -> i64, i64, i64, bool {
    if at >= s.len || text[s.at + at] != marker { return 0, 0, at, false; }
    let start, p, ok = number_at(text, s, at + 1);
    if !ok { return 0, 0, at, false; }
    var count: i64 = 1;
    var q = p;
    if p < s.len && text[s.at + p] == ',' {
        let c, p2, ok2 = number_at(text, s, p + 1);
        if !ok2 { return 0, 0, at, false; }
        count = c;
        q = p2;
    }
    return start, count, q, true;
}

// patch_parse reads a patch. The files, the hunks and the body lines go
// to the three buffers. A fault leaves them as they were.
fn patch_parse(text: const u8[:], files: FilePatch[>..]&, hunks: Hunk[>..]&, body: Span[>..]&) -> i64 {
    let files0 = files.len;
    let hunks0 = hunks.len;
    let body0 = body.len;
    let code = patch_parse_into(text, files, hunks, body);
    if code != ERR_OK {
        files.resize(files0, FilePatch { old_name: Span { at: 0, len: 0 }, new_name: Span { at: 0, len: 0 },
                                         first_hunk: 0, hunks: 0 });
        hunks.resize(hunks0, Hunk { old_start: 0, old_lines: 0, new_start: 0, new_lines: 0, first_line: 0, lines: 0 });
        body.resize(body0, Span { at: 0, len: 0 });
    }
    return code;
}

fn patch_parse_into(text: const u8[:], files: FilePatch[>..]&, hunks: Hunk[>..]&, body: Span[>..]&) -> i64 {
    var ls: Span[>..] = [];
    split_lines(text, ls);
    var i: i64 = 0;
    var have_file = false;
    while i < ls.len {
        let s = ls[i];
        if starts_with(text, s, "--- ") && i + 1 < ls.len && starts_with(text, ls[i + 1], "+++ ") {
            if files.len >= MAX_FILES { return ERR_TOO_LARGE; }
            let n = ls[i + 1];
            files.push(FilePatch { old_name: name_of(text, s, 4), new_name: name_of(text, n, 4),
                                   first_hunk: hunks.len, hunks: 0 });
            have_file = true;
            i = i + 2;
        } else if starts_with(text, s, "@@ ") {
            if hunks.len >= MAX_HUNKS { return ERR_TOO_LARGE; }
            let os, oc, p1, ok1 = parse_range(text, s, 3, '-');
            if !ok1 { return ERR_BAD_PATCH; }
            if p1 >= s.len || text[s.at + p1] != ' ' { return ERR_BAD_PATCH; }
            let ns, nc, p2, ok2 = parse_range(text, s, p1 + 1, '+');
            if !ok2 { return ERR_BAD_PATCH; }
            if !starts_with(text, Span { at: s.at + p2, len: s.len - p2 }, " @@") { return ERR_BAD_PATCH; }
            if !have_file {
                files.push(FilePatch { old_name: Span { at: 0, len: 0 }, new_name: Span { at: 0, len: 0 },
                                       first_hunk: hunks.len, hunks: 0 });
                have_file = true;
            }
            // The body holds the lines that the counts ask for.
            let first = body.len;
            var old_seen: i64 = 0;
            var new_seen: i64 = 0;
            i = i + 1;
            while (old_seen < oc || new_seen < nc) && i < ls.len {
                let b = ls[i];
                var marker: u8 = ' ';
                if b.len > 0 && text[b.at] != 10 && text[b.at] != 13 { marker = text[b.at]; }
                if marker == '\\' {
                    // A marker for the line before it. It counts for neither side.
                } else if marker == ' ' {
                    old_seen = old_seen + 1;
                    new_seen = new_seen + 1;
                } else if marker == '-' {
                    old_seen = old_seen + 1;
                } else if marker == '+' {
                    new_seen = new_seen + 1;
                } else {
                    return ERR_BAD_PATCH;
                }
                if old_seen > oc || new_seen > nc { return ERR_BAD_PATCH; }
                body.push(b);
                i = i + 1;
            }
            if old_seen != oc || new_seen != nc { return ERR_BAD_PATCH; }
            // A marker line may follow the last line of the hunk.
            while i < ls.len && ls[i].len > 0 && text[ls[i].at] == '\\' {
                body.push(ls[i]);
                i = i + 1;
            }
            // After the counts are met, a line that looks like a body
            // line is a fault, as GNU patch reads it. A hunk header or
            // a file header may follow. Other text between files is
            // skipped.
            if i < ls.len {
                let b = ls[i];
                if b.len > 0 && !starts_with(text, b, "@@ ") &&
                   !(starts_with(text, b, "--- ") && i + 1 < ls.len && starts_with(text, ls[i + 1], "+++ ")) {
                    let c = text[b.at];
                    if c == ' ' || c == '+' || c == '-' { return ERR_BAD_PATCH; }
                }
            }
            hunks.push(Hunk { old_start: os, old_lines: oc, new_start: ns, new_lines: nc,
                              first_line: first, lines: body.len - first });
            files[files.len - 1].hunks = files[files.len - 1].hunks + 1;
        } else {
            i = i + 1;
        }
    }
    return ERR_OK;
}

// ApplyOptions holds the rules of a patch apply.
struct ApplyOptions {
    // Apply the patch the other way: the added lines go, the removed
    // lines come back.
    reverse: bool,
    // The most line compares that the search spends.
    max_work: i64,
    // The most lines that a hunk may move from the place of its header.
    max_shift: i64,
    // The most bytes of the text.
    max_input: i64,
    // The most context lines of a hunk that may mismatch. A removed
    // line must always match. The rule of the fuzz factor of jsdiff.
    fuzz: i64,
    // Convert the line ends of the patch to the line ends of the text
    // when one side uses only CRLF and the other only LF. Acts in
    // `patch_apply_fuzz`. The rule `autoConvertLineEndings` of jsdiff.
    auto_line_ends: bool,
}

// default_apply_options gives a forward apply with 50 million compares.
fn default_apply_options() -> ApplyOptions {
    return ApplyOptions { reverse: false, max_work: 50000000, max_shift: 1000000, max_input: 16777216, fuzz: 0,
                          auto_line_ends: true };
}

// marker_of gives the marker of a body line. An empty line counts as a
// context line, as GNU patch reads it.
fn marker_of(text: const u8[:], b: Span) -> u8 {
    if b.len == 0 { return ' '; }
    let c = text[b.at];
    if c == ' ' || c == '-' || c == '+' || c == '\\' { return c; }
    return ' ';
}

// content_of gives the text of a body line without its marker and its
// line end.
fn content_of(text: const u8[:], b: Span) -> Span {
    var from = b.at;
    var end = b.at + b.len;
    let c = text[b.at];
    if c == ' ' || c == '-' || c == '+' { from = from + 1; }
    if end > from && text[end - 1] == 10 { end = end - 1; }
    return Span { at: from, len: end - from };
}

// line_matches tells whether a line of the text is the line of a hunk.
// A hunk line with no line end must meet a line with none.
fn line_matches(src: const u8[:], s: Span, text: const u8[:], c: Span, no_end: bool) -> bool {
    var len = s.len;
    let has_end = len > 0 && src[s.at + len - 1] == 10;
    if has_end { len = len - 1; }
    if has_end == no_end { return false; }
    if len != c.len { return false; }
    for k in len {
        if src[s.at + k] != text[c.at + k] { return false; }
    }
    return true;
}

// patch_apply appends the text of a source after one file of a patch is
// applied. The file is the index into `files`. A fault leaves the buffer
// as it was.
fn patch_apply(src: const u8[:], text: const u8[:], files: const FilePatch[:], hunks: const Hunk[:],
               body: const Span[:], file: i64, o: ApplyOptions, out: u8[>..]&) -> i64 {
    if file < 0 || file >= files.len { return ERR_NO_FILE; }
    if src.len > o.max_input { return ERR_TOO_LARGE; }
    if o.max_work < 0 || o.max_shift < 0 { return ERR_BAD_OPTION; }
    let base = out.len;
    let code = patch_apply_into(src, text, files[file], hunks, body, o, out);
    if code != ERR_OK { out.resize(base, 0); }
    return code;
}

fn patch_apply_into(src: const u8[:], text: const u8[:], fp: FilePatch, hunks: const Hunk[:],
                    body: const Span[:], o: ApplyOptions, out: u8[>..]&) -> i64 {
    var ls: Span[>..] = [];
    split_lines(src, ls);
    var pos: i64 = 0;
    var shift: i64 = 0;
    var work: i64 = 0;
    var hi = fp.first_hunk;
    while hi < fp.first_hunk + fp.hunks {
        let h = hunks[hi];
        // The lines of the old side and the lines of the new side.
        var old_side: i64[>..] = [];
        var new_side: i64[>..] = [];
        var j: i64 = 0;
        while j < h.lines {
            let b = body[h.first_line + j];
            let m = marker_of(text, b);
            if m == ' ' {
                old_side.push(j);
                new_side.push(j);
            } else if m == '-' {
                if o.reverse { new_side.push(j); } else { old_side.push(j); }
            } else if m == '+' {
                if o.reverse { old_side.push(j); } else { new_side.push(j); }
            }
            j = j + 1;
        }
        var start = h.old_start;
        var count = h.old_lines;
        if o.reverse {
            start = h.new_start;
            count = h.new_lines;
        }
        var expected = start - 1;
        if count == 0 { expected = start; }
        let maxp = ls.len - old_side.len;
        // Start from the nearest place that can hold the hunk.
        var want = expected + shift;
        if want > maxp { want = maxp; }
        if want < pos { want = pos; }
        var found: i64 = -1;
        var d: i64 = 0;
        while found < 0 && d <= o.max_shift && (want + d <= maxp || want - d >= pos) {
            var side: i64 = 0;
            while side < 2 && found < 0 {
                var p = want + d;
                if side == 1 { p = want - d; }
                if (side == 0 || d > 0) && p >= pos && p <= maxp {
                    var ok = true;
                    var q: i64 = 0;
                    work = work + 1;
                    while ok && q < old_side.len {
                        work = work + 1;
                        if work > o.max_work { return ERR_TOO_MUCH_WORK; }
                        let bi = old_side[q];
                        var no_end = false;
                        if bi + 1 < h.lines && marker_of(text, body[h.first_line + bi + 1]) == '\\' { no_end = true; }
                        if !line_matches(src, ls[p + q], text, content_of(text, body[h.first_line + bi]), no_end) {
                            ok = false;
                        }
                        q = q + 1;
                    }
                    if ok { found = p; }
                }
                side = side + 1;
            }
            d = d + 1;
        }
        if found < 0 { return ERR_NO_MATCH; }
        shift = found - expected;
        // The lines before the hunk stay as they are.
        var k = pos;
        while k < found {
            for c in ls[k].len { out.push(src[ls[k].at + c]); }
            k = k + 1;
        }
        for bi in new_side {
            let c = content_of(text, body[h.first_line + bi]);
            for x in c.len { out.push(text[c.at + x]); }
            var no_end = false;
            if bi + 1 < h.lines && marker_of(text, body[h.first_line + bi + 1]) == '\\' { no_end = true; }
            if !no_end { out.push(10); }
        }
        pos = found + old_side.len;
        hi = hi + 1;
    }
    var k = pos;
    while k < ls.len {
        for c in ls[k].len { out.push(src[ls[k].at + c]); }
        k = k + 1;
    }
    return ERR_OK;
}
