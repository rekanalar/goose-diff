// The compaction of the raw steps of a search.
//
// The Rust library `similar` runs this pass over every diff that
// `TextDiff` captures. A delete or an insert slides up and down over the
// equal runs next to it, while the ids at the edges match. Runs that
// touch then merge. The port follows the steps of the library, so the
// opcodes come out the same.
namespace diff;

import std;

// cp_adjust moves the offsets of a step by `off` and changes the length
// of its range by `dlen`. A delete holds an empty range in the second
// text, and an insert holds an empty range in the first text.
fn cp_adjust(op: Op&, off: i64, dlen: i64) {
    if op.tag == OP_EQUAL {
        let len = op.a_hi - op.a_lo + dlen;
        op.a_lo = op.a_lo + off;
        op.b_lo = op.b_lo + off;
        op.a_hi = op.a_lo + len;
        op.b_hi = op.b_lo + len;
    } else if op.tag == OP_DELETE {
        let len = op.a_hi - op.a_lo + dlen;
        op.a_lo = op.a_lo + off;
        op.a_hi = op.a_lo + len;
        op.b_lo = op.b_lo + off;
        op.b_hi = op.b_lo;
    } else {
        let len = op.b_hi - op.b_lo + dlen;
        op.a_lo = op.a_lo + off;
        op.a_hi = op.a_lo;
        op.b_lo = op.b_lo + off;
        op.b_hi = op.b_lo + len;
    }
}

fn cp_empty(op: Op) -> bool {
    return op.a_hi == op.a_lo && op.b_hi == op.b_lo;
}

// cp_insert puts a step at a place of the list.
fn cp_insert(ops: Op[>..]&, at: i64, op: Op) {
    ops.push(op);
    var k = ops.len - 1;
    while k > at {
        ops[k] = ops[k - 1];
        k = k - 1;
    }
    ops[at] = op;
}

// cp_remove takes the step at a place out of the list.
fn cp_remove(ops: Op[>..]&, at: i64) {
    var k = at;
    while k + 1 < ops.len {
        ops[k] = ops[k + 1];
        k = k + 1;
    }
    ops.resize(ops.len - 1, Op { tag: 0, a_lo: 0, a_hi: 0, b_lo: 0, b_hi: 0 });
}

// cp_prefix gives the count of the equal ids at the start of two ranges.
// An empty range gives 0.
fn cp_prefix(a: const i32[:], alo: i64, ahi: i64, b: const i32[:], blo: i64, bhi: i64) -> i64 {
    return sim_prefix(a, alo, ahi, b, blo, bhi);
}

fn cp_suffix(a: const i32[:], alo: i64, ahi: i64, b: const i32[:], blo: i64, bhi: i64) -> i64 {
    return sim_suffix(a, alo, ahi, b, blo, bhi);
}

// cp_up slides the step at `pointer` up over the equal runs before it.
fn cp_up(ops: Op[>..]&, a: const i32[:], b: const i32[:], p0: i64) -> i64 {
    var pointer = p0;
    var go = true;
    while go && pointer >= 1 {
        let this = ops[pointer];
        let prev = ops[pointer - 1];
        let this_ins = this.tag == OP_INSERT;
        if prev.tag == OP_EQUAL {
            // An insert reads its second range, a delete has none.
            let suffix = cp_suffix(a, prev.a_lo, prev.a_hi, b, this.b_lo, this.b_hi);
            if suffix > 0 {
                if pointer + 1 < ops.len && ops[pointer + 1].tag == OP_EQUAL {
                    cp_adjust(ops[pointer + 1], 0 - suffix, suffix);
                } else {
                    var len = suffix;
                    if !this_ins { len = prev.a_hi - prev.a_lo - suffix; }
                    cp_insert(ops, pointer + 1, Op { tag: OP_EQUAL, a_lo: prev.a_hi - suffix,
                                                      a_hi: prev.a_hi - suffix + len, b_lo: this.b_hi - suffix,
                                                      b_hi: this.b_hi - suffix + len });
                }
                cp_adjust(ops[pointer], 0 - suffix, 0);
                cp_adjust(ops[pointer - 1], 0, 0 - suffix);
                if cp_empty(ops[pointer - 1]) {
                    cp_remove(ops, pointer - 1);
                    pointer = pointer - 1;
                }
            } else if cp_empty(ops[pointer - 1]) {
                cp_remove(ops, pointer - 1);
                pointer = pointer - 1;
            } else {
                go = false;
            }
        } else if prev.tag != this.tag {
            let t = ops[pointer];
            ops[pointer] = ops[pointer - 1];
            ops[pointer - 1] = t;
            pointer = pointer - 1;
        } else {
            if this_ins { cp_adjust(ops[pointer - 1], 0, this.b_hi - this.b_lo); } else { cp_adjust(ops[pointer - 1], 0, this.a_hi - this.a_lo); }
            cp_remove(ops, pointer);
            pointer = pointer - 1;
        }
    }
    return pointer;
}

// cp_down slides the step at `pointer` down over the equal runs after it.
fn cp_down(ops: Op[>..]&, a: const i32[:], b: const i32[:], p0: i64) -> i64 {
    var pointer = p0;
    var go = true;
    while go && pointer + 1 < ops.len {
        let this = ops[pointer];
        let next = ops[pointer + 1];
        if next.tag == OP_EQUAL {
            let prefix = cp_prefix(a, next.a_lo, next.a_hi, b, this.b_lo, this.b_hi);
            if prefix > 0 {
                if pointer >= 1 && ops[pointer - 1].tag == OP_EQUAL {
                    cp_adjust(ops[pointer - 1], 0, prefix);
                } else {
                    cp_insert(ops, pointer, Op { tag: OP_EQUAL, a_lo: next.a_lo, a_hi: next.a_lo + prefix,
                                                  b_lo: this.b_lo, b_hi: this.b_lo + prefix });
                    pointer = pointer + 1;
                }
                cp_adjust(ops[pointer], prefix, 0);
                cp_adjust(ops[pointer + 1], prefix, 0 - prefix);
                if cp_empty(ops[pointer + 1]) { cp_remove(ops, pointer + 1); }
            } else if cp_empty(ops[pointer + 1]) {
                cp_remove(ops, pointer + 1);
            } else {
                go = false;
            }
        } else if next.tag != this.tag {
            let t = ops[pointer];
            ops[pointer] = ops[pointer + 1];
            ops[pointer + 1] = t;
            pointer = pointer + 1;
        } else {
            if this.tag == OP_INSERT { cp_adjust(ops[pointer], 0, next.b_hi - next.b_lo); } else { cp_adjust(ops[pointer], 0, next.a_hi - next.a_lo); }
            cp_remove(ops, pointer + 1);
        }
    }
    return pointer;
}

// sim_compact runs the compaction over the raw steps.
fn sim_compact(raw: Op[>..]&, a: const i32[:], b: const i32[:]) {
    for tag in [OP_DELETE, OP_INSERT] {
        var pointer: i64 = 0;
        while pointer < raw.len {
            if raw[pointer].tag == tag {
                pointer = cp_up(raw, a, b, pointer);
                pointer = cp_down(raw, a, b, pointer);
            }
            pointer = pointer + 1;
        }
    }
}

// sim_finish compacts the raw steps and joins them into opcodes.
fn sim_finish(raw: Op[>..]&, a: const i32[:], b: const i32[:], ops: Op[>..]&) {
    sim_compact(raw, a, b);
    sim_replace(raw[..], ops);
}
