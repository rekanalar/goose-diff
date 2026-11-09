// The Ratcliff-Obershelp matcher.
//
// The Python library difflib uses this search in its SequenceMatcher.
// The search finds the longest block of equal elements that holds no
// junk. It then finds the longest block in the parts on each side of
// that block.
//
// The blocks that the search finds read well to a person. They do not
// give the smallest diff. The Myers search of the file myers.goose gives
// the smallest diff.
//
// The search works on ids. The package gives an id to every line, so
// the search compares lines. The id of a character is its byte value,
// so the same search compares characters.
namespace diff;

import std;

// Match is one block of equal elements. It holds the place of the first
// element in the first text, the place of the first element in the
// second text, and the count of the equal elements.
struct Match {
    a: i64,
    b: i64,
    size: i64,
}

// Scored is one word with its score.
struct Scored {
    score: f64,
    span: Span,
}

// The searches of a diff.
const ALG_MYERS: i64 = 0;
const ALG_RO: i64 = 1;

// The junk rules of the matcher.
const JUNK_NONE: i64 = 0;
const JUNK_BLANK: i64 = 1;
const JUNK_COMMENT: i64 = 2;

// The most pairs of lines that the check of the smallest diff may use.
const MAX_LCS_CELLS: i64 = 1000000;

// The most compares that the search of the close words spends.
const MAX_CLOSE_WORK: i64 = 50000000;

// ro_ids gives the count of the ids that the two texts use.
fn ro_ids(a: const i32[:], b: const i32[:]) -> i64 {
    var n: i64 = 0;
    for id in a {
        let v = id as i64;
        if v + 1 > n { n = v + 1; }
    }
    for id in b {
        let v = id as i64;
        if v + 1 > n { n = v + 1; }
    }
    return n;
}

// ro_is_junk tells whether a line is junk under the rule. The rule
// JUNK_BLANK takes a line of white space. The rule JUNK_COMMENT takes
// that line and a line of one hash sign.
fn ro_is_junk(text: const u8[:], s: Span, mode: i64) -> bool {
    var hash = false;
    var other = false;
    for k in s.len {
        let c = text[s.at + k];
        if c == ' ' || c == 9 || c == 10 || c == 11 || c == 12 || c == 13 { continue; }
        if c == '#' && mode == JUNK_COMMENT && !hash { hash = true; continue; }
        other = true;
    }
    if other { return false; }
    if mode == JUNK_COMMENT { return true; }
    return !hash;
}

// ro_junk_lines marks the junk lines of the two texts.
fn ro_junk_lines(a: const u8[:], la: const Span[:], ida: const i32[:],
                 b: const u8[:], lb: const Span[:], idb: const i32[:],
                 mode: i64, junk: u8[>..]&) {
    if mode == JUNK_NONE { return; }
    for i in la.len {
        if ro_is_junk(a, la[i], mode) { junk[ida[i] as i64] = 1; }
    }
    for i in lb.len {
        if ro_is_junk(b, lb[i], mode) { junk[idb[i] as i64] = 1; }
    }
}

// ro_build fills the index of the second text. For every id that the
// matcher keeps, it gives the place of the first position in `positions`
// and the count of the positions. The positions of one id rise.
//
// The popular rule drops an id that appears more often than one percent
// of the lines. The rule starts at 200 lines.
fn ro_build(b: const i32[:], n_ids: i64, junk: const u8[:], autojunk: bool,
            starts: i64[>..]&, counts: i64[>..]&, positions: i64[>..]&) {
    starts.resize(n_ids, 0);
    counts.resize(n_ids, 0);
    for j in b.len { counts[b[j] as i64] = counts[b[j] as i64] + 1; }
    // The popular rule drops an id that appears more often than one
    // percent of the lines. The rule starts at 200 lines.
    let ntest = b.len / 100 + 1;
    let popular = autojunk && b.len >= 200;
    var total: i64 = 0;
    for id in n_ids {
        starts[id] = total;
        if junk[id] == 0 && !(popular && counts[id] > ntest) {
            total = total + counts[id];
        } else {
            counts[id] = 0;
        }
    }
    positions.resize(total, 0);
    var fill: i64[>..] = [];
    fill.resize(n_ids, 0);
    for j in b.len {
        let id = b[j] as i64;
        if counts[id] > 0 {
            positions[starts[id] + fill[id]] = j;
            fill[id] = fill[id] + 1;
        }
    }
}

// Cell is one cell of the map of the search. It holds the values of the
// last two rows of the search.
struct Cell {
    v0: i64,
    s0: i64,
    v1: i64,
    s1: i64,
}

// ro_longest gives the longest block of equal elements that holds no
// junk. The block lies in the given ranges. It gives the place in the
// first text, the place in the second text, and the count of the
// elements.
//
// The map of the previous row of the search lies in `cells`. Every cell
// holds the values of two rows. The stamp of a cell tells the row that
// wrote it. A cell of an older row counts as empty.
fn ro_longest(a: const i32[:], b: const i32[:], junk: const u8[:],
              starts: const i64[:], counts: const i64[:], positions: const i64[:],
              alo: i64, ahi: i64, blo: i64, bhi: i64, max_work: i64,
              cells: Cell[>..]&, epoch: i64&, work: i64&) -> i64, i64, i64 {
    var besti = alo;
    var bestj = blo;
    var bestsize: i64 = 0;
    let base = epoch + 1;
    var iter: i64 = 0;
    var i = alo;
    while i < ahi {
        work = work + 1;
        if work > max_work { break; }
        iter = iter + 1;
        let id = a[i] as i64;
        let s = starts[id];
        let c = counts[id];
        var t: i64 = 0;
        while t < c {
            let j = positions[s + t];
            if j >= bhi { break; }
            if j >= blo {
                var k: i64 = 1;
                if iter > 1 && j > 0 {
                    if iter % 2 == 0 {
                        if cells[j - 1].s1 == base + iter - 2 { k = cells[j - 1].v1 + 1; }
                    } else {
                        if cells[j - 1].s0 == base + iter - 2 { k = cells[j - 1].v0 + 1; }
                    }
                }
                if iter % 2 == 0 {
                    cells[j].v0 = k;
                    cells[j].s0 = base + iter - 1;
                } else {
                    cells[j].v1 = k;
                    cells[j].s1 = base + iter - 1;
                }
                if k > bestsize {
                    bestsize = k;
                    besti = i - k + 1;
                    bestj = j - k + 1;
                }
            }
            t = t + 1;
            work = work + 1;
            if work > max_work { break; }
        }
        i = i + 1;
    }
    epoch = base + iter - 1;
    // The block grows over the equal elements around it.
    while besti > alo && bestj > blo && junk[b[bestj - 1]] == 0 && a[besti - 1] == b[bestj - 1] {
        work = work + 1;
        besti = besti - 1;
        bestj = bestj - 1;
        bestsize = bestsize + 1;
    }
    while besti + bestsize < ahi && bestj + bestsize < bhi &&
          junk[b[bestj + bestsize]] == 0 && a[besti + bestsize] == b[bestj + bestsize] {
        work = work + 1;
        bestsize = bestsize + 1;
    }
    // The block takes in the junk around it.
    while besti > alo && bestj > blo && junk[b[bestj - 1]] != 0 && a[besti - 1] == b[bestj - 1] {
        work = work + 1;
        besti = besti - 1;
        bestj = bestj - 1;
        bestsize = bestsize + 1;
    }
    while besti + bestsize < ahi && bestj + bestsize < bhi &&
          junk[b[bestj + bestsize]] != 0 && a[besti + bestsize] == b[bestj + bestsize] {
        work = work + 1;
        bestsize = bestsize + 1;
    }
    return besti, bestj, bestsize;
}

// ro_blocks gives the blocks of equal elements of the two texts. The
// last block is the empty block at the end of the texts. The work of
// the search adds to `work`.
fn ro_blocks(a: const i32[:], b: const i32[:], junk: const u8[:], autojunk: bool,
             max_work: i64, work: i64&, out: Match[>..]&) -> i64 {
    let n_ids = ro_ids(a, b);
    var starts: i64[>..] = [];
    var counts: i64[>..] = [];
    var positions: i64[>..] = [];
    ro_build(b, n_ids, junk, autojunk, starts, counts, positions);
    var cells: Cell[>..] = [];
    cells.resize(b.len + 1, Cell { v0: 0, s0: 0, v1: 0, s1: 0 });
    var epoch: i64 = 0;
    // The ranges to search. The last range comes first.
    var ra: i64[>..] = [];
    var rb: i64[>..] = [];
    var rc: i64[>..] = [];
    var rd: i64[>..] = [];
    ra.push(0);
    rb.push(a.len);
    rc.push(0);
    rd.push(b.len);
    var found: Match[>..] = [];
    while ra.len > 0 {
        let alo = ra[ra.len - 1];
        let ahi = rb[rb.len - 1];
        let blo = rc[rc.len - 1];
        let bhi = rd[rd.len - 1];
        ra.resize(ra.len - 1, 0);
        rb.resize(rb.len - 1, 0);
        rc.resize(rc.len - 1, 0);
        rd.resize(rd.len - 1, 0);
        let i, j, k = ro_longest(a, b, junk, starts[..], counts[..], positions[..],
                                  alo, ahi, blo, bhi, max_work, cells, epoch, work);
        if work > max_work { return ERR_TOO_MUCH_WORK; }
        if k > 0 {
            found.push(Match { a: i, b: j, size: k });
            if alo < i && blo < j {
                ra.push(alo);
                rb.push(i);
                rc.push(blo);
                rd.push(j);
            }
            if i + k < ahi && j + k < bhi {
                ra.push(i + k);
                rb.push(ahi);
                rc.push(j + k);
                rd.push(bhi);
            }
        }
    }
    // The blocks lie in the order of the first text.
    sort(found[..]) { x, y => x.a < y.a };
    // The blocks that touch each other join into one block.
    var joined: Match[>..] = [];
    var have = false;
    var cur = Match { a: 0, b: 0, size: 0 };
    for m in found {
        if have && cur.a + cur.size == m.a && cur.b + cur.size == m.b {
            cur.size = cur.size + m.size;
        } else {
            if have { joined.push(cur); }
            cur = m;
            have = true;
        }
    }
    if have { joined.push(cur); }
    for m in joined { out.push(m); }
    out.push(Match { a: a.len, b: b.len, size: 0 });
    return ERR_OK;
}

// ro_opcodes gives the opcodes of the change between the two texts.
fn ro_opcodes(a: const i32[:], b: const i32[:], junk: const u8[:], autojunk: bool,
              max_work: i64, work: i64&, out: Op[>..]&) -> i64 {
    var blocks: Match[>..] = [];
    let code = ro_blocks(a, b, junk, autojunk, max_work, work, blocks);
    if code != ERR_OK { return code; }
    var i: i64 = 0;
    var j: i64 = 0;
    for m in blocks {
        var tag: i64 = 0;
        if i < m.a && j < m.b { tag = OP_REPLACE; }
        else if i < m.a { tag = OP_DELETE; }
        else if j < m.b { tag = OP_INSERT; }
        if tag != 0 {
            out.push(Op { tag: tag, a_lo: i, a_hi: m.a, b_lo: j, b_hi: m.b });
        }
        i = m.a + m.size;
        j = m.b + m.size;
        if m.size > 0 {
            out.push(Op { tag: OP_EQUAL, a_lo: m.a, a_hi: i, b_lo: m.b, b_hi: j });
        }
    }
    return ERR_OK;
}

// lcs_ids gives the count of the longest common subsequence of the two
// sequences of ids.
fn lcs_ids(a: const i32[:], b: const i32[:]) -> i64 {
    var row: i64[>..] = [];
    row.resize(b.len + 1, 0);
    for i in a.len {
        var diag: i64 = 0;
        for j in b.len {
            let up = row[j + 1];
            let left = row[j];
            if a[i] == b[j] {
                row[j + 1] = diag + 1;
            } else if up >= left {
                row[j + 1] = up;
            } else {
                row[j + 1] = left;
            }
            diag = up;
        }
    }
    return row[b.len];
}

// ro_is_minimal tells whether the equal lines of the diff are the most
// that any diff can hold. The check runs only for small texts.
fn ro_is_minimal(a: const i32[:], b: const i32[:], equal: i64) -> bool {
    if a.len > MAX_LCS_CELLS || b.len > MAX_LCS_CELLS { return false; }
    if a.len * b.len > MAX_LCS_CELLS { return false; }
    return lcs_ids(a, b) == equal;
}

// ro_quick gives the count of the elements that the two texts share.
fn ro_quick(a: const i32[:], b: const i32[:], n_ids: i64) -> i64 {
    var count: i64[>..] = [];
    count.resize(n_ids, 0);
    for id in b { count[id as i64] = count[id as i64] + 1; }
    var left: i64[>..] = [];
    left.resize(n_ids, 0);
    var matches: i64 = 0;
    for id in a {
        let i = id as i64;
        if left[i] < count[i] {
            left[i] = left[i] + 1;
            matches = matches + 1;
        }
    }
    return matches;
}

// ro_prepare splits two texts into lines, gives an id to every line,
// and marks the junk lines.
fn ro_prepare(a: const u8[:], b: const u8[:], o: Options,
              la: Span[>..]&, lb: Span[>..]&, ida: i32[>..]&, idb: i32[>..]&, junk: u8[>..]&) {
    lines_of(a, b, la, lb, ida, idb);
    junk.resize(ro_ids(ida[..], idb[..]), 0);
    ro_junk_lines(a, la[..], ida[..], b, lb[..], idb[..], o.junk, junk);
}

// matcher_blocks adds the blocks of equal lines of a against b to
// `blocks`. The last block is the empty block at the end of the texts.
fn matcher_blocks(a: const u8[:], b: const u8[:], o: Options, blocks: Match[>..]&) -> i64 {
    if !options_ok(o) { return ERR_BAD_OPTION; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    var junk: u8[>..] = [];
    ro_prepare(a, b, o, la, lb, ida, idb, junk);
    var work: i64 = 0;
    var found: Match[>..] = [];
    let code = ro_blocks(ida[..], idb[..], junk[..], o.autojunk, o.max_work, work, found);
    if code != ERR_OK { return code; }
    for m in found { blocks.push(m); }
    return ERR_OK;
}

// ro_ops adds the opcodes of the matcher of the two lists of ids to
// `ops`. It gives a code and a flag. The flag is true when the diff is
// minimal.
fn ro_ops(a: const i32[:], b: const i32[:], junk: const u8[:], o: Options,
          ops: Op[>..]&) -> i64, bool {
    var work: i64 = 0;
    var found: Op[>..] = [];
    let code = ro_opcodes(a, b, junk, o.autojunk, o.max_work, work, found);
    if code != ERR_OK { return code, false; }
    var equal: i64 = 0;
    for op in found {
        if op.tag == OP_EQUAL { equal = equal + (op.a_hi - op.a_lo); }
    }
    for op in found { ops.push(op); }
    return ERR_OK, ro_is_minimal(a, b, equal);
}

// matcher_opcodes adds the opcodes of a against b to `ops`. It gives a
// code and a flag. The flag is true when the diff is minimal.
fn matcher_opcodes(a: const u8[:], b: const u8[:], o: Options, ops: Op[>..]&) -> i64, bool {
    if !options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    var junk: u8[>..] = [];
    ro_prepare(a, b, o, la, lb, ida, idb, junk);
    return ro_ops(ida[..], idb[..], junk[..], o, ops);
}

// matcher_longest gives the longest block of equal lines in a range of
// the two texts. The range holds a start and an end for each text. It
// gives a code and the block.
fn matcher_longest(a: const u8[:], b: const u8[:], o: Options,
                   alo: i64, ahi: i64, blo: i64, bhi: i64) -> i64, Match {
    if !options_ok(o) { return ERR_BAD_OPTION, Match { a: 0, b: 0, size: 0 }; }
    if a.len > o.max_input || b.len > o.max_input {
        return ERR_TOO_LARGE, Match { a: 0, b: 0, size: 0 };
    }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    var junk: u8[>..] = [];
    ro_prepare(a, b, o, la, lb, ida, idb, junk);
    if alo < 0 || blo < 0 || ahi > la.len || bhi > lb.len || alo > ahi || blo > bhi {
        return ERR_BAD_OPTION, Match { a: 0, b: 0, size: 0 };
    }
    let n_ids = ro_ids(ida[..], idb[..]);
    var starts: i64[>..] = [];
    var counts: i64[>..] = [];
    var positions: i64[>..] = [];
    ro_build(idb[..], n_ids, junk[..], o.autojunk, starts, counts, positions);
    var cells: Cell[>..] = [];
    cells.resize(lb.len + 1, Cell { v0: 0, s0: 0, v1: 0, s1: 0 });
    var epoch: i64 = 0;
    var work: i64 = 0;
    let i, j, k = ro_longest(ida[..], idb[..], junk[..], starts[..], counts[..], positions[..],
                              alo, ahi, blo, bhi, o.max_work, cells, epoch, work);
    if work > o.max_work { return ERR_TOO_MUCH_WORK, Match { a: 0, b: 0, size: 0 }; }
    return ERR_OK, Match { a: i, b: j, size: k };
}

// matcher_grouped adds the opcodes of a against b to `ops` and the ends
// of the hunks to `ends`. Each hunk holds n lines of context around a
// change.
fn matcher_grouped(a: const u8[:], b: const u8[:], o: Options, n: i64,
                    ops: Op[>..]&, ends: i64[>..]&) -> i64 {
    if n < 0 || n > MAX_CONTEXT { return ERR_BAD_OPTION; }
    var found: Op[>..] = [];
    let code, exact = matcher_opcodes(a, b, o, found);
    if code != ERR_OK { return code; }
    var groups: Op[>..] = [];
    var group_ends: i64[>..] = [];
    group_ops(found[..], n, groups, group_ends);
    let base = ops.len;
    for g in groups { ops.push(g); }
    for e in group_ends { ends.push(base + e); }
    return ERR_OK;
}

// matcher_ratio gives the ratio of a against b. The ratio is twice the
// count of the equal lines over the count of all lines.
fn matcher_ratio(a: const u8[:], b: const u8[:], o: Options) -> i64, f64 {
    if !options_ok(o) { return ERR_BAD_OPTION, 0.0; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, 0.0; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    var junk: u8[>..] = [];
    ro_prepare(a, b, o, la, lb, ida, idb, junk);
    var work: i64 = 0;
    var blocks: Match[>..] = [];
    let code = ro_blocks(ida[..], idb[..], junk[..], o.autojunk, o.max_work, work, blocks);
    if code != ERR_OK { return code, 0.0; }
    var matches: i64 = 0;
    for m in blocks { matches = matches + m.size; }
    let total = la.len + lb.len;
    if total == 0 { return ERR_OK, 1.0; }
    return ERR_OK, 2.0 * matches / total;
}

// matcher_quick_ratio gives the quick ratio of a against b. The ratio
// counts the lines that the two texts share.
fn matcher_quick_ratio(a: const u8[:], b: const u8[:], o: Options) -> i64, f64 {
    if !options_ok(o) { return ERR_BAD_OPTION, 0.0; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, 0.0; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    lines_of(a, b, la, lb, ida, idb);
    let matches = ro_quick(ida[..], idb[..], ro_ids(ida[..], idb[..]));
    let total = la.len + lb.len;
    if total == 0 { return ERR_OK, 1.0; }
    return ERR_OK, 2.0 * matches / total;
}

// matcher_real_quick_ratio gives the real quick ratio of a against b.
// The ratio counts only the lengths of the two texts.
fn matcher_real_quick_ratio(a: const u8[:], b: const u8[:], o: Options) -> i64, f64 {
    if !options_ok(o) { return ERR_BAD_OPTION, 0.0; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, 0.0; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    split_lines(a, la);
    split_lines(b, lb);
    let total = la.len + lb.len;
    if total == 0 { return ERR_OK, 1.0; }
    var small = la.len;
    if lb.len < small { small = lb.len; }
    return ERR_OK, 2.0 * small / total;
}

// ro_span_greater tells whether the bytes of the first span come after
// the bytes of the second span.
fn ro_span_greater(text: const u8[:], s1: Span, s2: Span) -> bool {
    var n = s1.len;
    if s2.len < n { n = s2.len; }
    var k: i64 = 0;
    while k < n {
        if text[s1.at + k] != text[s2.at + k] { return text[s1.at + k] > text[s2.at + k]; }
        k = k + 1;
    }
    return s1.len > s2.len;
}

// close_matches adds the places of the words that match the word best
// to `out`. The words stand in the text, one per line. The places come
// in the order of the score. It gives a code and the count of the words.
fn close_matches(word: const u8[:], cands: const u8[:], n: i64, cutoff: f64,
                 out: Span[>..]&) -> i64 {
    if n < 0 { return ERR_BAD_OPTION; }
    var ls: Span[>..] = [];
    split_lines(cands, ls);
    var wid: i32[>..] = [];
    for c in word { wid.push(c); }
    var junk: u8[>..] = [];
    junk.resize(256, 0);
    var work: i64 = 0;
    var found: Scored[>..] = [];
    for s in ls {
        var end = s.at + s.len;
        if end > s.at && cands[end - 1] == 10 { end = end - 1; }
        var cid: i32[>..] = [];
        for k in end - s.at { cid.push(cands[s.at + k]); }
        let total = wid.len + cid.len;
        if total == 0 { continue; }
        var small = wid.len;
        if cid.len < small { small = cid.len; }
        let real = 2.0 * small / total;
        if real < cutoff { continue; }
        let n_ids = ro_ids(cid[..], wid[..]);
        let quick = 2.0 * ro_quick(cid[..], wid[..], n_ids) / total;
        if quick < cutoff { continue; }
        var blocks: Match[>..] = [];
        let code = ro_blocks(cid[..], wid[..], junk[..], true, MAX_CLOSE_WORK, work, blocks);
        if code != ERR_OK { return code; }
        var matches: i64 = 0;
        for m in blocks { matches = matches + m.size; }
        let score = 2.0 * matches / total;
        if score < cutoff { continue; }
        found.push(Scored { score: score, span: Span { at: s.at, len: end - s.at } });
    }
    sort(found[..]) { x, y => x.score > y.score || (x.score == y.score && ro_span_greater(cands, x.span, y.span)) };
    var count: i64 = 0;
    var i: i64 = 0;
    while i < found.len && count < n {
        out.push(found[i].span);
        count = count + 1;
        i = i + 1;
    }
    return ERR_OK;
}
