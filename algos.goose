// The Patience and LCS searches of the Rust crate similar.
//
// The searches work on ids, as the other searches of the package do. Each
// gives opcodes in which a delete and an insert between two equal runs
// join into one replace.
namespace diff;

import std;
import dictionary;

// The values of the rule `algorithm` that this file adds.
const ALG_PATIENCE: i64 = 2;
const ALG_LCS: i64 = 3;
// The Myers search of the Rust crate `similar`: it splits at the middle snake.
const ALG_MYERS_SPLIT: i64 = 4;

// The most cells of the table of the LCS search: 64 MB of i32.
const MAX_LCS_TABLE: i64 = 16777216;

// sim_raw adds one raw step. A step is an equal run, a delete or an insert.
fn sim_equal(raw: Op[>..]&, a: i64, b: i64, len: i64) {
    raw.push(Op { tag: OP_EQUAL, a_lo: a, a_hi: a + len, b_lo: b, b_hi: b + len });
}

fn sim_delete(raw: Op[>..]&, a: i64, len: i64, b: i64) {
    raw.push(Op { tag: OP_DELETE, a_lo: a, a_hi: a + len, b_lo: b, b_hi: b });
}

fn sim_insert(raw: Op[>..]&, a: i64, b: i64, len: i64) {
    raw.push(Op { tag: OP_INSERT, a_lo: a, a_hi: a, b_lo: b, b_hi: b + len });
}

// sim_replace joins the raw steps. Equal runs that touch merge. The
// deletes and the inserts between two equal runs join into one replace.
fn sim_replace(raw: const Op[:], ops: Op[>..]&) {
    var eq = false;
    var ea: i64 = 0;
    var eb: i64 = 0;
    var el: i64 = 0;
    var del = false;
    var da: i64 = 0;
    var dl: i64 = 0;
    var db: i64 = 0;
    var ins = false;
    var ia: i64 = 0;
    var ib: i64 = 0;
    var il: i64 = 0;
    for r in raw {
        if r.tag == OP_EQUAL {
            if del || ins {
                sim_flush(ops, del, da, dl, db, ins, ia, ib, il);
                del = false;
                ins = false;
            }
            if eq {
                el = el + (r.a_hi - r.a_lo);
            } else {
                eq = true;
                ea = r.a_lo;
                eb = r.b_lo;
                el = r.a_hi - r.a_lo;
            }
        } else {
            if eq {
                ops.push(Op { tag: OP_EQUAL, a_lo: ea, a_hi: ea + el, b_lo: eb, b_hi: eb + el });
                eq = false;
            }
            if r.tag == OP_DELETE {
                if del {
                    dl = dl + (r.a_hi - r.a_lo);
                } else {
                    del = true;
                    da = r.a_lo;
                    dl = r.a_hi - r.a_lo;
                    db = r.b_lo;
                }
            } else {
                if ins {
                    il = il + (r.b_hi - r.b_lo);
                } else {
                    ins = true;
                    ia = r.a_lo;
                    ib = r.b_lo;
                    il = r.b_hi - r.b_lo;
                }
            }
        }
    }
    if del || ins { sim_flush(ops, del, da, dl, db, ins, ia, ib, il); }
    if eq { ops.push(Op { tag: OP_EQUAL, a_lo: ea, a_hi: ea + el, b_lo: eb, b_hi: eb + el }); }
}

// sim_flush writes the pending delete and insert as one op.
fn sim_flush(ops: Op[>..]&, del: bool, da: i64, dl: i64, db: i64,
             ins: bool, ia: i64, ib: i64, il: i64) {
    if del && ins {
        ops.push(Op { tag: OP_REPLACE, a_lo: da, a_hi: da + dl, b_lo: ib, b_hi: ib + il });
    } else if del {
        ops.push(Op { tag: OP_DELETE, a_lo: da, a_hi: da + dl, b_lo: db, b_hi: db });
    } else if ins {
        ops.push(Op { tag: OP_INSERT, a_lo: ia, a_hi: ia, b_lo: ib, b_hi: ib + il });
    }
}

// sim_prefix gives the count of the equal ids at the start of two ranges.
fn sim_prefix(a: const i32[:], alo: i64, ahi: i64, b: const i32[:], blo: i64, bhi: i64) -> i64 {
    var n: i64 = 0;
    while alo + n < ahi && blo + n < bhi && a[alo + n] == b[blo + n] { n = n + 1; }
    return n;
}

// sim_suffix gives the count of the equal ids at the end of two ranges.
fn sim_suffix(a: const i32[:], alo: i64, ahi: i64, b: const i32[:], blo: i64, bhi: i64) -> i64 {
    var n: i64 = 0;
    while ahi - n > alo && bhi - n > blo && a[ahi - 1 - n] == b[bhi - 1 - n] { n = n + 1; }
    return n;
}

// sim_max_d gives the most rounds that the search of the middle snake runs.
fn sim_max_d(n: i64, m: i64) -> i64 {
    return (n + m + 1) / 2 + 1;
}

// sim_snake finds the middle snake of the Myers search of similar. It
// gives a flag and the start of the snake in both texts. It gives false
// when the budget ends. `vf` and `vb` hold the furthest points, indexed
// from `off`.
fn sim_snake(a: const i32[:], alo: i64, ahi: i64, b: const i32[:], blo: i64, bhi: i64,
             vf: i64[>..]&, vb: i64[>..]&, off: i64, max_work: i64, work: i64&) -> bool, i64, i64 {
    let n = ahi - alo;
    let m = bhi - blo;
    let delta = n - m;
    let odd = (delta & 1) == 1;
    vf[1 + off] = 0;
    vb[1 + off] = 0;
    let d_max = sim_max_d(n, m);
    var d: i64 = 0;
    while d < d_max {
        work = work + 2 * d + 2;
        if work > max_work { return false, 0, 0; }
        // The forward path.
        var k = d;
        while k >= -d {
            var x: i64 = 0;
            if k == -d || (k != d && vf[k - 1 + off] < vf[k + 1 + off]) {
                x = vf[k + 1 + off];
            } else {
                x = vf[k - 1 + off] + 1;
            }
            let y = x - k;
            let x0 = x;
            let y0 = y;
            if x < n && y < m {
                let adv = sim_prefix(a, alo + x, ahi, b, blo + y, bhi);
                work = work + adv;
                x = x + adv;
            }
            vf[k + off] = x;
            if odd {
                var kd = k - delta;
                if kd < 0 { kd = 0 - kd; }
                if kd <= d - 1 {
                    if vf[k + off] + vb[(0 - (k - delta)) + off] >= n {
                        return true, x0 + alo, y0 + blo;
                    }
                }
            }
            k = k - 2;
        }
        // The backward path.
        k = d;
        while k >= -d {
            var x: i64 = 0;
            if k == -d || (k != d && vb[k - 1 + off] < vb[k + 1 + off]) {
                x = vb[k + 1 + off];
            } else {
                x = vb[k - 1 + off] + 1;
            }
            var y = x - k;
            if x < n && y < m {
                let adv = sim_suffix(a, alo, alo + n - x, b, blo, blo + m - y);
                work = work + adv;
                x = x + adv;
                y = y + adv;
            }
            vb[k + off] = x;
            if !odd {
                var kd = k - delta;
                if kd < 0 { kd = 0 - kd; }
                if kd <= d {
                    if vb[k + off] + vf[(0 - (k - delta)) + off] >= n {
                        return true, n - x + alo, m - y + blo;
                    }
                }
            }
            k = k - 2;
        }
        d = d + 1;
    }
    return false, 0, 0;
}

// sim_conquer runs the Myers search of similar over two ranges and adds
// the raw steps. The flag `capped` turns true when the budget ends and a
// range becomes one delete and one insert.
recursive fn sim_conquer(a: const i32[:], alo0: i64, ahi0: i64, b: const i32[:], blo0: i64, bhi0: i64,
                         vf: i64[>..]&, vb: i64[>..]&, off: i64, max_work: i64, work: i64&,
                         raw: Op[>..]&, capped: bool&) {
    var alo = alo0;
    var ahi = ahi0;
    var blo = blo0;
    var bhi = bhi0;
    let p = sim_prefix(a, alo, ahi, b, blo, bhi);
    if p > 0 { sim_equal(raw, alo, blo, p); }
    alo = alo + p;
    blo = blo + p;
    let s = sim_suffix(a, alo, ahi, b, blo, bhi);
    let sa = ahi - s;
    let sb = bhi - s;
    ahi = ahi - s;
    bhi = bhi - s;
    if alo >= ahi && blo >= bhi {
        // Nothing is left.
    } else if blo >= bhi {
        sim_delete(raw, alo, ahi - alo, blo);
    } else if alo >= ahi {
        sim_insert(raw, alo, blo, bhi - blo);
    } else {
        let found, x, y = sim_snake(a, alo, ahi, b, blo, bhi, vf, vb, off, max_work, work);
        if found {
            sim_conquer(a, alo, x, b, blo, y, vf, vb, off, max_work, work, raw, capped);
            sim_conquer(a, x, ahi, b, y, bhi, vf, vb, off, max_work, work, raw, capped);
        } else {
            capped = true;
            sim_delete(raw, alo, ahi - alo, blo);
            sim_insert(raw, alo, blo, bhi - blo);
        }
    }
    if s > 0 { sim_equal(raw, sa, sb, s); }
}

// sim_run runs the Myers search of similar over two ranges with fresh
// work arrays. The Rust library makes new arrays for every call, and a
// reused array would hold old values that change the tie breaks.
fn sim_run(a: const i32[:], alo: i64, ahi: i64, b: const i32[:], blo: i64, bhi: i64,
           vf: i64[>..]&, vb: i64[>..]&, max_work: i64, work: i64&, raw: Op[>..]&, capped: bool&) {
    let off = sim_max_d(ahi - alo, bhi - blo) + 2;
    vf.resize(0, 0);
    vb.resize(0, 0);
    vf.resize(2 * off + 2, 0);
    vb.resize(2 * off + 2, 0);
    sim_conquer(a, alo, ahi, b, blo, bhi, vf, vb, off, max_work, work, raw, capped);
}

// sim_patience adds the opcodes of the Patience search to `ops`. It gives
// false when the budget ended and a range became one replace.
fn sim_patience(a: const i32[:], b: const i32[:], max_work: i64, ops: Op[>..]&) -> bool {
    let na = a.len;
    let nb = b.len;
    // The ids may be sparse or negative. The map gives every distinct
    // id a dense one, so the counts stay small whatever the caller
    // passes.
    var map: dictionary<i32, i64> = dictionary<i32, i64> {};
    var next: i64 = 0;
    var da: i32[>..] = [];
    var db: i32[>..] = [];
    for x in a {
        let slot = get_or_insert(map, x, next);
        if slot == next { next = next + 1; }
        da.push(slot as! i32);
    }
    for y in b {
        let slot = get_or_insert(map, y, next);
        if slot == next { next = next + 1; }
        db.push(slot as! i32);
    }
    var ca: i64[>..] = [];
    var cb: i64[>..] = [];
    ca.resize(next, 0);
    cb.resize(next, 0);
    for x in da { ca[x as i64] = ca[x as i64] + 1; }
    for y in db { cb[y as i64] = cb[y as i64] + 1; }
    // The items that appear once in each text, with their places.
    var ua: i64[>..] = [];
    var ub: i64[>..] = [];
    var ia: i32[>..] = [];
    var ib: i32[>..] = [];
    for i in na { if ca[da[i] as i64] == 1 { ua.push(i); ia.push(da[i]); } }
    for j in nb { if cb[db[j] as i64] == 1 { ub.push(j); ib.push(db[j]); } }
    var vf: i64[>..] = [];
    var vb: i64[>..] = [];
    var work: i64 = 0;
    var capped = false;
    // The Myers search over the unique items gives the anchors.
    var anchors: Op[>..] = [];
    sim_run(ia[..], 0, ia.len, ib[..], 0, ib.len, vf, vb, max_work, work, anchors, capped);
    var raw: Op[>..] = [];
    var cur_a: i64 = 0;
    var cur_b: i64 = 0;
    for r in anchors {
        if r.tag != OP_EQUAL { continue; }
        for t in (r.a_hi - r.a_lo) {
            let pa = ua[r.a_lo + t];
            let pb = ub[r.b_lo + t];
            let a0 = cur_a;
            let b0 = cur_b;
            while cur_a < pa && cur_b < pb && db[cur_b] == da[cur_a] {
                cur_a = cur_a + 1;
                cur_b = cur_b + 1;
            }
            if cur_a > a0 { sim_equal(raw, a0, b0, cur_a - a0); }
            sim_run(a, cur_a, pa, b, cur_b, pb, vf, vb, max_work, work, raw, capped);
            cur_a = pa;
            cur_b = pb;
        }
    }
    sim_run(a, cur_a, na, b, cur_b, nb, vf, vb, max_work, work, raw, capped);
    sim_finish(raw, a, b, ops);
    return !capped;
}

// sim_lcs adds the opcodes of the LCS search to `ops`. It gives a code. A
// pair of texts that needs a table past the cap, or past the budget,
// gives ERR_TOO_MUCH_WORK.
fn sim_lcs(a: const i32[:], b: const i32[:], max_work: i64, ops: Op[>..]&) -> i64 {
    let na = a.len;
    let nb = b.len;
    var raw: Op[>..] = [];
    if nb == 0 {
        if na > 0 { sim_delete(raw, 0, na, 0); }
        sim_replace(raw[..], ops);
        return ERR_OK;
    }
    if na == 0 {
        sim_insert(raw, 0, 0, nb);
        sim_replace(raw[..], ops);
        return ERR_OK;
    }
    let p = sim_prefix(a, 0, na, b, 0, nb);
    let s = sim_suffix(a, p, na, b, p, nb);
    if p == na && na == nb {
        sim_equal(raw, 0, 0, na);
        sim_replace(raw[..], ops);
        return ERR_OK;
    }
    let old_len = na - p - s;
    let new_len = nb - p - s;
    let width = old_len + 1;
    if new_len + 1 > MAX_LCS_TABLE / width { return ERR_TOO_MUCH_WORK; }
    let cells = (new_len + 1) * width;
    if cells > max_work { return ERR_TOO_MUCH_WORK; }
    var table: i32[>..] = [];
    table.resize(cells, 0);
    var i = new_len - 1;
    while i >= 0 {
        var j = old_len - 1;
        while j >= 0 {
            var v: i32 = 0;
            if b[p + i] == a[p + j] {
                v = table[(i + 1) * width + j + 1] + 1;
            } else {
                v = table[(i + 1) * width + j];
                let r = table[i * width + j + 1];
                if r > v { v = r; }
            }
            table[i * width + j] = v;
            j = j - 1;
        }
        i = i - 1;
    }
    if p > 0 { sim_equal(raw, 0, 0, p); }
    var oi: i64 = 0;
    var ni: i64 = 0;
    while ni < new_len && oi < old_len {
        let oo = p + oi;
        let no = p + ni;
        if b[no] == a[oo] {
            sim_equal(raw, oo, no, 1);
            oi = oi + 1;
            ni = ni + 1;
        } else if table[ni * width + oi + 1] >= table[(ni + 1) * width + oi] {
            sim_delete(raw, oo, 1, no);
            oi = oi + 1;
        } else {
            sim_insert(raw, oo, no, 1);
            ni = ni + 1;
        }
    }
    if oi < old_len { sim_delete(raw, p + oi, old_len - oi, p + ni); }
    oi = old_len;
    if ni < new_len { sim_insert(raw, p + oi, p + ni, new_len - ni); }
    if s > 0 { sim_equal(raw, p + old_len, p + new_len, s); }
    sim_finish(raw, a, b, ops);
    return ERR_OK;
}

// diff_ids_alg adds the opcodes of the search that the rule `algorithm`
// names to `ops`. It gives a code and the minimality flag. The rule
// ALG_RO is not here: it needs the junk rules.
fn diff_ids_alg(a: const i32[:], b: const i32[:], algorithm: i64, max_edits: i64, max_work: i64,
                ops: Op[>..]&) -> i64, bool {
    if algorithm == ALG_PATIENCE {
        var found: Op[>..] = [];
        let complete = sim_patience(a, b, max_work, found);
        var equal: i64 = 0;
        for o in found {
            if o.tag == OP_EQUAL { equal = equal + (o.a_hi - o.a_lo); }
            ops.push(o);
        }
        // Patience does not promise the smallest diff, so the flag holds
        // only when the check of the minimality says so.
        return ERR_OK, complete && ro_is_minimal(a, b, equal);
    }
    if algorithm == ALG_MYERS_SPLIT {
        var raw: Op[>..] = [];
        var vf: i64[>..] = [];
        var vb: i64[>..] = [];
        var work: i64 = 0;
        var capped = false;
        sim_run(a, 0, a.len, b, 0, b.len, vf, vb, max_work, work, raw, capped);
        sim_finish(raw, a, b, ops);
        return ERR_OK, !capped;
    }
    if algorithm == ALG_LCS {
        var found: Op[>..] = [];
        let code = sim_lcs(a, b, max_work, found);
        if code != ERR_OK { return code, false; }
        for o in found { ops.push(o); }
        return ERR_OK, true;
    }
    return ERR_OK, diff_ids(a, b, max_edits, max_work, ops);
}
