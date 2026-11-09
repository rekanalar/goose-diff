// The Myers diff of two sequences of ids.
//
// The result is a list of opcodes as the Python library difflib gives
// them: equal, delete, insert and replace, with ranges in both sequences.
// The search keeps a trace of O(D squared) values for D edits, so the
// caller bounds D. When the bound is hit, the result is still a valid
// diff, but not a minimal one.
namespace diff;

import std;

const OP_EQUAL: i64 = 0;
const OP_DELETE: i64 = 1;
const OP_INSERT: i64 = 2;
const OP_REPLACE: i64 = 3;

// Op is one opcode: the ranges a[a_lo..a_hi] and b[b_lo..b_hi].
struct Op {
    tag: i64,
    a_lo: i64,
    a_hi: i64,
    b_lo: i64,
    b_hi: i64,
}

// myers_moves finds a shortest edit script for a[a_lo..a_hi] against
// b[b_lo..b_hi]. It adds one move per step to `moves`: 0 for a common
// element, 1 for a delete from a and 2 for an insert from b. It gives
// false when the bound max_edits or the bound max_work stops the search
// and adds nothing.
fn myers_moves(a: const i32[:], b: const i32[:], max_edits: i64, max_work: i64,
               moves: u8[>..]&) -> bool {
    let n = a.len;
    let m = b.len;
    var dmax = n + m;
    if max_edits < dmax { dmax = max_edits; }
    let off = dmax + 1;
    var v: i64[>..] = [];
    v.resize(2 * dmax + 3, 0);
    // The snapshot of step d holds v[-d..d] and starts at d * d.
    var trace: i32[>..] = [];
    var found: i64 = -1;
    var d: i64 = 0;
    var work: i64 = 0;
    while d <= dmax && found < 0 {
        var kk: i64 = -d;
        while kk <= d {
            trace.push(v[off + kk] as i32);
            kk = kk + 1;
        }
        var k: i64 = -d;
        while k <= d && found < 0 {
            work = work + 1;
            if work > max_work { return false; }
            var x: i64 = 0;
            if k == -d || (k != d && v[off + k - 1] < v[off + k + 1]) {
                x = v[off + k + 1];
            } else {
                x = v[off + k - 1] + 1;
            }
            var y = x - k;
            while x < n && y < m && a[x] == b[y] {
                work = work + 1;
                if work > max_work { return false; }
                x = x + 1;
                y = y + 1;
            }
            v[off + k] = x;
            if x >= n && y >= m { found = d; }
            k = k + 2;
        }
        d = d + 1;
    }
    if found < 0 { return false; }
    // Walk back from (n, m) and write the moves in reverse.
    var rev: u8[>..] = [];
    var x = n;
    var y = m;
    var step = found;
    while step >= 1 {
        let base = step * step;
        let k = x - y;
        var insert = false;
        if k == -step {
            insert = true;
        } else if k != step && trace[base + (k - 1) + step] < trace[base + (k + 1) + step] {
            insert = true;
        }
        var prev_k = k - 1;
        if insert { prev_k = k + 1; }
        let prev_x = trace[base + prev_k + step] as i64;
        let prev_y = prev_x - prev_k;
        var mid_x = prev_x + 1;
        var mid_y = prev_y;
        if insert {
            mid_x = prev_x;
            mid_y = prev_y + 1;
        }
        while x > mid_x && y > mid_y {
            rev.push(0);
            x = x - 1;
            y = y - 1;
        }
        if insert { rev.push(2); } else { rev.push(1); }
        x = prev_x;
        y = prev_y;
        step = step - 1;
    }
    while x > 0 && y > 0 {
        rev.push(0);
        x = x - 1;
        y = y - 1;
    }
    var i = rev.len;
    while i > 0 {
        i = i - 1;
        moves.push(rev[i]);
    }
    return true;
}

// diff_ids adds the opcodes of a against b to `ops`. It gives false when
// the bound on edits or the bound on work was hit. The opcodes are then
// valid but not minimal: the part between the common start and the
// common end is one replace.
fn diff_ids(a: const i32[:], b: const i32[:], max_edits: i64, max_work: i64,
            ops: Op[>..]&) -> bool {
    let na = a.len;
    let nb = b.len;
    var pre: i64 = 0;
    while pre < na && pre < nb && a[pre] == b[pre] { pre = pre + 1; }
    var suf: i64 = 0;
    while suf < na - pre && suf < nb - pre && a[na - 1 - suf] == b[nb - 1 - suf] { suf = suf + 1; }
    let n = na - pre - suf;
    let m = nb - pre - suf;
    var moves: u8[>..] = [];
    var exact = true;
    if n == 0 || m == 0 {
        for i in n { moves.push(1); }
        for i in m { moves.push(2); }
    } else if !myers_moves(a[pre..na - suf], b[pre..nb - suf], max_edits, max_work, moves) {
        exact = false;
        for i in n { moves.push(1); }
        for i in m { moves.push(2); }
    }
    // Join the moves into opcodes.
    var ai = pre;
    var bi = pre;
    if pre > 0 { ops.push(Op { tag: OP_EQUAL, a_lo: 0, a_hi: pre, b_lo: 0, b_hi: pre }); }
    var i: i64 = 0;
    while i < moves.len {
        let a0 = ai;
        let b0 = bi;
        if moves[i] == 0 {
            while i < moves.len && moves[i] == 0 {
                ai = ai + 1;
                bi = bi + 1;
                i = i + 1;
            }
            ops.push(Op { tag: OP_EQUAL, a_lo: a0, a_hi: ai, b_lo: b0, b_hi: bi });
        } else {
            while i < moves.len && moves[i] != 0 {
                if moves[i] == 1 { ai = ai + 1; } else { bi = bi + 1; }
                i = i + 1;
            }
            var tag = OP_REPLACE;
            if ai == a0 { tag = OP_INSERT; }
            if bi == b0 { tag = OP_DELETE; }
            ops.push(Op { tag: tag, a_lo: a0, a_hi: ai, b_lo: b0, b_hi: bi });
        }
    }
    if suf > 0 { ops.push(Op { tag: OP_EQUAL, a_lo: na - suf, a_hi: na, b_lo: nb - suf, b_hi: nb }); }
    return exact;
}
