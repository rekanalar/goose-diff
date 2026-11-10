// A unified diff of two texts, and the opcodes of the change.
import std;
import diff from "..";

fn main() {
    let a = "one\ntwo\nthree\nfour\nfive\n";
    let b = "one\ntwo\nthree point five\nfour\nfive\nsix\n";

    // The opcodes of the change. The ranges are half open: the end is
    // the first line that the opcode does not hold.
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_lines(a, b, diff::default_options(), ops);
    print("code    : ", diff::error_text(code), "\n");
    print("minimal : ", exact, "\n");
    for o in ops {
        print("op      : tag ", o.tag, " lines ", o.a_lo, " to ", o.a_hi,
              " against ", o.b_lo, " to ", o.b_hi, "\n");
    }

    // The same change in the unified format.
    var out: u8[>..] = [];
    let c2, x2 = diff::unified_diff(out, a, b, "old.txt", "new.txt", diff::default_options());
    assert(c2 == diff::ERR_OK && x2);
    print("--- the unified diff ---\n");
    print(out[..]);

    // The same diff with a date after each name.
    var dated: u8[>..] = [];
    let c3, x3 = diff::unified_diff_dated(dated, a, b, "old.txt", "new.txt", "2026-11-09 10:00",
                                          "2026-11-10 10:00", "\n", diff::default_options());
    assert(c3 == diff::ERR_OK && x3);
    print("--- the dated header ---\n");
    print(dated[..]);
}
