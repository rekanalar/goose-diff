// The blocks of equal lines of two texts, and the ratios of the texts.
import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

fn main() {
    let a = "one\ntwo\nthree\nfour\nfive\n";
    let b = "one\ntwo\nthree point five\nfour\nfive\nsix\n";

    // The matcher of the Python library difflib. The rule `algorithm`
    // names the search.
    var o = diff::default_options();
    o.algorithm = diff::ALG_RO;

    // The blocks of equal lines. The last block is the empty block at
    // the end of the texts.
    var blocks: diff::Match[>..] = [];
    let code = diff::matcher_blocks(a, b, o, blocks);
    print("code    : ", diff::error_text(code), "\n");
    for m in blocks {
        print("block   : lines ", m.a, " to ", m.a + m.size,
              " against ", m.b, " to ", m.b + m.size, "\n");
    }

    // The three ratios of the two texts. They count the lines.
    let c1, ratio = diff::matcher_ratio(a, b, o);
    let c2, quick = diff::matcher_quick_ratio(a, b, o);
    let c3, real = diff::matcher_real_quick_ratio(a, b, o);
    assert(c1 == diff::ERR_OK && c2 == diff::ERR_OK && c3 == diff::ERR_OK);
    print("ratio   : ", ratio, "\n");
    print("quick   : ", quick, "\n");
    print("real    : ", real, "\n");

    // The words that match a word best. The words stand in one text,
    // one per line.
    var words: diff::Span[>..] = [];
    let cands = "ape\napple\npeach\npunch";
    let c4 = diff::close_matches("appel", cands, 3, 0.6, words);
    print("close   : ", diff::error_text(c4), "\n");
    for w in words {
        print("word    : ", cands[w.at..w.at + w.len], "\n");
    }
}
