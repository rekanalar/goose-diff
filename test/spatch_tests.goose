// The tests of the group spatch.
namespace spatch_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import diff_checks;

fn test_spatch_eof() {
    // The last line end is part of the text. The apply keeps it, adds
    // it or drops it as the patch says, as jsdiff does.
    assert(diff_checks::eof_run("a\nb\n", "a\nB", false));
    assert(diff_checks::eof_run("a\nb", "a\nB\n", false));
    assert(diff_checks::eof_run("a\nb", "a\nb\nc", false));
    assert(diff_checks::eof_run("a\nb\n", "a\nb", false));
    assert(diff_checks::eof_run("a\nb\n", "a\nB", true));
    assert(diff_checks::eof_run("a\nb", "a\nB\n", true));
    assert(diff_checks::eof_run("", "x", false));
    assert(diff_checks::eof_run("x", "", false));
}

fn test_apply_create_remove() {
    // The results of applyPatch in jsdiff 8.0.4 for a patch that adds a
    // file and for a patch that removes one.
    let add = "--- /dev/null\n+++ b.txt\n@@ -0,0 +1,2 @@\n+x\n+y\n";
    let del = "--- a.txt\n+++ /dev/null\n@@ -1,2 +0,0 @@\n-x\n-y\n";
    assert(diff_checks::apply_one("", add, "x\ny\n"));
    assert(diff_checks::apply_one("x\ny\n", del, ""));
    assert(diff_checks::apply_one("zzz\n", add, "x\ny\nzzz\n"));
}

fn test_header_options() {
    // The bytes of formatPatch in jsdiff 8.0.4 for each header option.
    var sp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu: diff::Hunk[>..] = [];
    var names: u8[>..] = [];
    var marks: u8[>..] = [];
    var body: u8[>..] = [];
    var lspans: diff::Span[>..] = [];
    var o = diff::default_options();
    o.context = 3;
    assert(diff::structured_patch("a.txt", "b.txt", "one\ntwo\n", "one\nthree\n", "h1", "h2", o, sp, hu, names, marks, body, lspans) == diff::ERR_OK);
    var full: u8[>..] = [];
    assert(diff::format_patch_opts(sp, hu[..], names[..], marks[..], body[..], lspans[..], diff::default_header_options(), full) == diff::ERR_OK);
    assert(full == "===================================================================\n--- a.txt\th1\n+++ b.txt\th2\n@@ -1,2 +1,2 @@\n one\n-two\n+three\n");
    var heads: u8[>..] = [];
    assert(diff::format_patch_opts(sp, hu[..], names[..], marks[..], body[..], lspans[..], diff::file_headers_only_options(), heads) == diff::ERR_OK);
    assert(heads == "--- a.txt\th1\n+++ b.txt\th2\n@@ -1,2 +1,2 @@\n one\n-two\n+three\n");
    var none: u8[>..] = [];
    assert(diff::format_patch_opts(sp, hu[..], names[..], marks[..], body[..], lspans[..], diff::omit_headers_options(), none) == diff::ERR_OK);
    assert(none == "@@ -1,2 +1,2 @@\n one\n-two\n+three\n");
    // The line of Index appears only with equal names.
    var sp2: diff::SPatch = sp;
    var hu2: diff::Hunk[>..] = [];
    var n2: u8[>..] = [];
    var m2: u8[>..] = [];
    var b2: u8[>..] = [];
    var l2: diff::Span[>..] = [];
    assert(diff::structured_patch("f", "f", "one\ntwo\n", "one\nthree\n", "h1", "h2", o, sp2, hu2, n2, m2, b2, l2) == diff::ERR_OK);
    var ix: u8[>..] = [];
    var hopt = diff::default_header_options();
    hopt.include_underline = false;
    assert(diff::format_patch_opts(sp2, hu2[..], n2[..], m2[..], b2[..], l2[..], hopt, ix) == diff::ERR_OK);
    assert(ix == "Index: f\n--- f\th1\n+++ f\th2\n@@ -1,2 +1,2 @@\n one\n-two\n+three\n");
    // An empty header text writes no tab with skip_empty_header.
    var sp3: diff::SPatch = sp;
    var hu3: diff::Hunk[>..] = [];
    var n3: u8[>..] = [];
    var m3: u8[>..] = [];
    var b3: u8[>..] = [];
    var l3: diff::Span[>..] = [];
    assert(diff::structured_patch("f", "g", "one\n", "two\n", "", "", o, sp3, hu3, n3, m3, b3, l3) == diff::ERR_OK);
    var bare: u8[>..] = [];
    var hb = diff::file_headers_only_options();
    hb.skip_empty_header = true;
    assert(diff::format_patch_opts(sp3, hu3[..], n3[..], m3[..], b3[..], l3[..], hb, bare) == diff::ERR_OK);
    assert(bare == "--- f\n+++ g\n@@ -1,1 +1,1 @@\n-one\n+two\n");
}

fn test_diff_ratio() {
    // The ratios of TextDiff in similar 2.7.0.
    var o = diff::default_options();
    let c1, r1 = diff::diff_ratio("a\nb\nc\n", "a\nX\nc\n", o);
    assert(c1 == diff::ERR_OK);
    assert(r1 > 0.6666 && r1 < 0.6667);
    let c2, r2 = diff::diff_ratio("", "", o);
    assert(c2 == diff::ERR_OK && r2 == 1.0);
    let c3, r3 = diff::diff_ratio("a\n", "b\n", o);
    assert(c3 == diff::ERR_OK && r3 == 0.0);
}

fn test_spatch() {
    // The bytes of jsdiff 8.0.4, pinned from a run of the library.
    var a1: u8[>..] = [];
    diff_checks::put_text(a1, "line one\nline two\nline three\n");
    var b1: u8[>..] = [];
    diff_checks::put_text(b1, "line one\nline 2!\nline three\n");
    var sp1: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu: diff::Hunk[>..] = [];
    var names: u8[>..] = [];
    var marks: u8[>..] = [];
    var body: u8[>..] = [];
    var lspans: diff::Span[>..] = [];
    var o = diff::default_options();
    o.context = 3;
    assert(diff::structured_patch("a.txt", "b.txt", a1[..], b1[..], "old h", "v1", o, sp1, hu, names, marks, body, lspans) == diff::ERR_OK);
    var out: u8[>..] = [];
    out.resize(0, 0);
    assert(diff::format_patch(sp1, hu[..], names[..], marks[..], body[..], lspans[..], out) == diff::ERR_OK);
    assert(out[..] == "===================================================================\n--- a.txt\told h\n+++ b.txt\tv1\n@@ -1,3 +1,3 @@\n line one\n-line two\n+line 2!\n line three\n");
    // The line of Index: appears when the two names are equal.
    var sp2: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu2: diff::Hunk[>..] = [];
    var names2: u8[>..] = [];
    var marks2: u8[>..] = [];
    var body2: u8[>..] = [];
    var lspans2: diff::Span[>..] = [];
    var a2: u8[>..] = [];
    diff_checks::put_text(a2, "alpha\nbeta\ngamma\ndelta\nepsilon\n");
    var b2: u8[>..] = [];
    diff_checks::put_text(b2, "alpha\nbeta\nGAMMA\ndelta\nepsilon\n");
    out.resize(0, 0);
    assert(diff::create_patch("f.c", a2[..], b2[..], "r1", "1.1", o, sp2, hu2, names2, marks2, body2, lspans2, out) == diff::ERR_OK);
    assert(out[..] == "Index: f.c\n===================================================================\n--- f.c\tr1\n+++ f.c\t1.1\n@@ -1,5 +1,5 @@\n alpha\n beta\n-gamma\n+GAMMA\n delta\n epsilon\n");
    // An empty header holds its tab. A count of one holds its comma.
    var sp3: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu3: diff::Hunk[>..] = [];
    var names3: u8[>..] = [];
    var marks3: u8[>..] = [];
    var body3: u8[>..] = [];
    var lspans3: diff::Span[>..] = [];
    var a3: u8[>..] = [];
    diff_checks::put_text(a3, "a\nb\nc\n");
    var b3: u8[>..] = [];
    diff_checks::put_text(b3, "a\nb\nC\nd\n");
    assert(diff::structured_patch("x.txt", "y.txt", a3[..], b3[..], "", "", o, sp3, hu3, names3, marks3, body3, lspans3) == diff::ERR_OK);
    out.resize(0, 0);
    assert(diff::format_patch(sp3, hu3[..], names3[..], marks3[..], body3[..], lspans3[..], out) == diff::ERR_OK);
    assert(out[..] == "===================================================================\n--- x.txt\t\n+++ y.txt\t\n@@ -1,3 +1,4 @@\n a\n b\n-c\n+C\n+d\n");
    // A text that ends without a line end adds the marker line.
    var a4: u8[>..] = [];
    diff_checks::put_text(a4, "a\nb\n");
    var b4: u8[>..] = [];
    diff_checks::put_text(b4, "a\nB");
    var sp4: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu4: diff::Hunk[>..] = [];
    var names4: u8[>..] = [];
    var marks4: u8[>..] = [];
    var body4: u8[>..] = [];
    var lspans4: diff::Span[>..] = [];
    out.resize(0, 0);
    assert(diff::create_patch("f", a4[..], b4[..], "x", "y", o, sp4, hu4, names4, marks4, body4, lspans4, out) == diff::ERR_OK);
    assert(out[..] == "Index: f\n===================================================================\n--- f\tx\n+++ f\ty\n@@ -1,2 +1,2 @@\n a\n-b\n+B\n\\ No newline at end of file\n");
    // An empty old file names the line before.
    var a5: u8[>..] = [];
    var b5: u8[>..] = [];
    diff_checks::put_text(b5, "x\n");
    var sp5: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu5: diff::Hunk[>..] = [];
    var names5: u8[>..] = [];
    var marks5: u8[>..] = [];
    var body5: u8[>..] = [];
    var lspans5: diff::Span[>..] = [];
    out.resize(0, 0);
    assert(diff::create_patch("f", a5[..], b5[..], "x", "y", o, sp5, hu5, names5, marks5, body5, lspans5, out) == diff::ERR_OK);
    assert(out[..] == "Index: f\n===================================================================\n--- f\tx\n+++ f\ty\n@@ -0,0 +1,1 @@\n+x\n");
    var a6: u8[>..] = [];
    diff_checks::put_text(a6, "x\n");
    var sp6: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu6: diff::Hunk[>..] = [];
    var names6: u8[>..] = [];
    var marks6: u8[>..] = [];
    var body6: u8[>..] = [];
    var lspans6: diff::Span[>..] = [];
    out.resize(0, 0);
    assert(diff::create_patch("f", a6[..], a5[..], "x", "y", o, sp6, hu6, names6, marks6, body6, lspans6, out) == diff::ERR_OK);
    assert(out[..] == "Index: f\n===================================================================\n--- f\tx\n+++ f\ty\n@@ -1,1 +0,0 @@\n-x\n");
    // Equal texts give no hunk.
    var sp7: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu7: diff::Hunk[>..] = [];
    var names7: u8[>..] = [];
    var marks7: u8[>..] = [];
    var body7: u8[>..] = [];
    var lspans7: diff::Span[>..] = [];
    assert(diff::structured_patch("a", "b", a1[..], a1[..], "", "", o, sp7, hu7, names7, marks7, body7, lspans7) == diff::ERR_OK);
    assert(sp7.hunks == 0);
    // The reader fills the same model, and the writer writes the same bytes.
    var ptext: u8[>..] = [];
    diff_checks::put_text(ptext, "===================================================================\n--- a.txt\told h\n+++ b.txt\tv1\n@@ -1,3 +1,3 @@\n line one\n-line two\n+line 2!\n line three\n");
    var rsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var rhu: diff::Hunk[>..] = [];
    var rnames: u8[>..] = [];
    var rmarks: u8[>..] = [];
    var rbody: u8[>..] = [];
    var rlspans: diff::Span[>..] = [];
    assert(diff::patch_parse_structured(ptext[..], 0, rsp, rhu, rnames, rmarks, rbody, rlspans) == diff::ERR_OK);
    assert(rsp.hunks == 1 && rhu[0].old_start == 1 && rhu[0].old_lines == 3 && rhu[0].new_start == 1 && rhu[0].new_lines == 3);
    out.resize(0, 0);
    assert(diff::format_patch(rsp, rhu[..], rnames[..], rmarks[..], rbody[..], rlspans[..], out) == diff::ERR_OK);
    assert(out[..] == "===================================================================\n--- a.txt\told h\n+++ b.txt\tv1\n@@ -1,3 +1,3 @@\n line one\n-line two\n+line 2!\n line three\n");
    // The flip swaps the names, the ranges and the marks. The apply of
    // the flip takes the text back.
    var fsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fhu: diff::Hunk[>..] = [];
    var fnames: u8[>..] = [];
    var fmarks: u8[>..] = [];
    assert(diff::patch_reverse(sp1, hu[..], names[..], marks[..], fsp, fhu, fnames, fmarks) == diff::ERR_OK);
    var ftxt: u8[>..] = [];
    assert(diff::format_patch(fsp, fhu[..], fnames[..], fmarks[..], body[..], lspans[..], ftxt) == diff::ERR_OK);
    assert(ftxt[..] == "===================================================================\n--- b.txt\tv1\n+++ a.txt\told h\n@@ -1,3 +1,3 @@\n line one\n+line two\n-line 2!\n line three\n");
    var ao = diff::default_apply_options();
    var back: u8[>..] = [];
    assert(diff::patch_apply_fuzz(b1[..], fsp, fhu[..], fmarks[..], body[..], lspans[..], ao, back) == diff::ERR_OK);
    assert(back[..] == "line one\nline two\nline three\n");
    // A leading context line that changed cannot take an added line, as in jsdiff.
    var oldf: u8[>..] = [];
    diff_checks::put_text(oldf, "a\nb\nXXXX\nd\ne\nf\ng\nh\n");
    var newf: u8[>..] = [];
    diff_checks::put_text(newf, "a\nb\nYYYY\nd\ne\nf\ng\nh\n");
    var spo: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var huo: diff::Hunk[>..] = [];
    var nno: u8[>..] = [];
    var mko: u8[>..] = [];
    var bdo: u8[>..] = [];
    var lso: diff::Span[>..] = [];
    o.context = 1;
    assert(diff::structured_patch("a", "b", oldf[..], newf[..], "", "", o, spo, huo, nno, mko, bdo, lso) == diff::ERR_OK);
    o.context = 3;
    var mut: u8[>..] = [];
    diff_checks::put_text(mut, "a\nB2\nXXXX\nd\ne\nf\ng\nh\n");
    ao.fuzz = 1;
    var fout: u8[>..] = [];
    assert(diff::patch_apply_fuzz(mut[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, fout) == diff::ERR_NO_MATCH);
    assert(fout.len == 0);
    // A source line before the leading context applies with fuzz, as in jsdiff.
    var extra: u8[>..] = [];
    diff_checks::put_text(extra, "a\nEXTRA\nb\nXXXX\nd\ne\nf\ng\nh\n");
    ao.fuzz = 1;
    var f3: u8[>..] = [];
    assert(diff::patch_apply_fuzz(extra[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, f3) == diff::ERR_OK);
    assert(f3[..] == "a\nEXTRA\nb\nYYYY\nd\ne\nf\ng\nh\n");
    // A removed line that changed never applies, at any fuzz.
    var mutd: u8[>..] = [];
    diff_checks::put_text(mutd, "a\nb\nXXXY\nd\ne\nf\ng\nh\n");
    ao.fuzz = 5;
    var f4: u8[>..] = [];
    assert(diff::patch_apply_fuzz(mutd[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, f4) == diff::ERR_NO_MATCH);
    // A value of fuzz past the cap is a fault.
    ao.fuzz = 101;
    var f5: u8[>..] = [];
    assert(diff::patch_apply_fuzz(oldf[..], spo, huo[..], mko[..], bdo[..], lso[..], ao, f5) == diff::ERR_BAD_OPTION);
    // The budget stops a hostile patch.
    var big: u8[>..] = [];
    for i in 2000 { diff_checks::put_text(big, "z\n"); }
    var spb: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hub: diff::Hunk[>..] = [];
    var nnb: u8[>..] = [];
    var mkb: u8[>..] = [];
    var bdb: u8[>..] = [];
    var lsb: diff::Span[>..] = [];
    var newb: u8[>..] = [];
    diff_checks::put_text(newb, "y\n");
    assert(diff::structured_patch("a", "b", a6[..], newb[..], "", "", o, spb, hub, nnb, mkb, bdb, lsb) == diff::ERR_OK);
    ao.fuzz = 5;
    ao.max_work = 500;
    var f6: u8[>..] = [];
    assert(diff::patch_apply_fuzz(big[..], spb, hub[..], mkb[..], bdb[..], lsb[..], ao, f6) == diff::ERR_TOO_MUCH_WORK);
    assert(f6.len == 0);
    // The XML form escapes the hostile text, as jsdiff does.
    var ca: u8[>..] = [];
    diff_checks::put_text(ca, "a&b\"");
    var cb: u8[>..] = [];
    diff_checks::put_text(cb, "a<b>");
    var to = diff::default_token_options();
    var chs: diff::Change[>..] = [];
    assert(diff::diff_chars(ca[..], cb[..], to, chs) == diff::ERR_OK);
    var xout: u8[>..] = [];
    assert(diff::changes_xml(chs[..], ca[..], cb[..], xout) == diff::ERR_OK);
    assert(xout[..] == "a<del>&amp;</del><ins>&lt;</ins>b<del>&quot;</del><ins>&gt;</ins>");
    var dout: u8[>..] = [];
    assert(diff::changes_dmp(chs[..], ca[..], cb[..], dout) == diff::ERR_OK);
    assert(dout[..] == "[[0,\"a\"],[-1,\"&\"],[1,\"<\"],[0,\"b\"],[-1,\"\\\"\"],[1,\">\"]]");
    // A fault leaves every buffer as it was.
    var obad = diff::default_options();
    obad.max_work = -1;
    var spx: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hux: diff::Hunk[>..] = [];
    hux.push(diff::Hunk { old_start: 9, old_lines: 9, new_start: 9, new_lines: 9, first_line: 9, lines: 9 });
    var nnx: u8[>..] = [];
    var mkx: u8[>..] = [];
    var bdx: u8[>..] = [];
    var lsx: diff::Span[>..] = [];
    nnx.push(7);
    assert(diff::structured_patch("a", "b", a1[..], b1[..], "", "", obad, spx, hux, nnx, mkx, bdx, lsx) == diff::ERR_BAD_OPTION);
    assert(hux.len == 1 && nnx.len == 1 && mkx.len == 0 && spx.hunks == 0);
    // A source that is shorter than the hunk never reads past its end.
    var shortp: u8[>..] = [];
    diff_checks::put_text(shortp, "@@ -1,2 +1,2 @@\n a\n b\n");
    var ssp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var shu: diff::Hunk[>..] = [];
    var snm: u8[>..] = [];
    var smk: u8[>..] = [];
    var sbd: u8[>..] = [];
    var sls: diff::Span[>..] = [];
    assert(diff::patch_parse_structured(shortp[..], 0, ssp, shu, snm, smk, sbd, sls) == diff::ERR_OK);
    var ssrc: u8[>..] = [];
    diff_checks::put_text(ssrc, "x\n");
    var sfz = diff::default_apply_options();
    sfz.fuzz = 1;
    var sout: u8[>..] = [];
    assert(diff::patch_apply_fuzz(ssrc[..], ssp, shu[..], smk[..], sbd[..], sls[..], sfz, sout) == diff::ERR_NO_MATCH);
    assert(sout.len == 0);
    // A model with a range past its buffer is a fault, not a crash.
    var bsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 1 };
    var bhu: diff::Hunk[>..] = [];
    bhu.push(diff::Hunk { old_start: 1, old_lines: 1, new_start: 1, new_lines: 1, first_line: 0, lines: 5 });
    var bnm: u8[>..] = [];
    var bmk: u8[>..] = [];
    bmk.push(32);
    var bbd: u8[>..] = [];
    var bls: diff::Span[>..] = [];
    assert(diff::patch_apply_fuzz(ssrc[..], bsp, bhu[..], bmk[..], bbd[..], bls[..], sfz, sout) == diff::ERR_BAD_PATCH);
    assert(sout.len == 0);
    var bsp2: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 3 };
    var bhu2: diff::Hunk[>..] = [];
    var bnm2: u8[>..] = [];
    var bmk2: u8[>..] = [];
    var fsp2: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fhu2: diff::Hunk[>..] = [];
    var fnm2: u8[>..] = [];
    var fmk2: u8[>..] = [];
    assert(diff::patch_reverse(bsp2, bhu2[..], bnm2[..], bmk2[..], fsp2, fhu2, fnm2, fmk2) == diff::ERR_BAD_PATCH);
    assert(fhu2.len == 0);
    // A change that reaches past its text is a fault.
    var bchs: diff::Change[>..] = [];
    bchs.push(diff::Change { at: 10, len: 5, count: 1, text: 0, added: false, removed: false });
    var bout: u8[>..] = [];
    assert(diff::changes_xml(bchs[..], ca[..], cb[..], bout) == diff::ERR_BAD_OPTION);
    assert(bout.len == 0);
    assert(diff::changes_dmp(bchs[..], ca[..], cb[..], bout) == diff::ERR_BAD_OPTION);
    assert(bout.len == 0);
}

// test_apply_all pins the apply of a patch of two files to two sources.
fn test_apply_all() {
    let patch = "--- a\n+++ a\n@@ -1,2 +1,2 @@\n x\n-y\n+Y\n--- b\n+++ b\n@@ -1,2 +1,2 @@\n p\n-q\n+Q\n";
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    assert(diff::patch_parse(patch, files, hunks, body) == diff::ERR_OK);
    var srcs: u8[>..] = [];
    diff_checks::put_text(srcs, "x\ny\np\nq\n");
    var spans: diff::Span[>..] = [];
    spans.push(diff::Span { at: 0, len: 4 });
    spans.push(diff::Span { at: 4, len: 4 });
    let o = diff::default_apply_options();
    var out: u8[>..] = [];
    var outs: diff::Span[>..] = [];
    let code, bad = diff::patch_apply_all(srcs[..], spans[..], patch, files[..], hunks[..], body[..], o, out, outs);
    assert(code == diff::ERR_OK && bad == -1);
    assert(out[..] == "x\nY\np\nQ\n");
    assert(outs.len == 2 && outs[1].at == 4 && outs[1].len == 4);
    // The second source does not fit: the call gives its index and changes nothing.
    var srcs2: u8[>..] = [];
    diff_checks::put_text(srcs2, "x\ny\np\nz\n");
    var out2: u8[>..] = [];
    var outs2: diff::Span[>..] = [];
    let code2, bad2 = diff::patch_apply_all(srcs2[..], spans[..], patch, files[..], hunks[..], body[..], o, out2, outs2);
    assert(code2 == diff::ERR_NO_MATCH && bad2 == 1);
    assert(out2.len == 0 && outs2.len == 0);
    // A count of sources that does not match the files is a fault.
    var one: diff::Span[>..] = [];
    one.push(diff::Span { at: 0, len: 4 });
    let code3, bad3 = diff::patch_apply_all(srcs[..], one[..], patch, files[..], hunks[..], body[..], o, out2, outs2);
    assert(code3 == diff::ERR_BAD_OPTION && bad3 == -1);
}

// test_split_myers pins the Myers search of similar on the case where it differs from the classic search.
fn test_split_myers() {
    var a: i32[>..] = [];
    for v in [0, 1, 0, 1, 2, 1] { a.push(v as i32); }
    var b: i32[>..] = [];
    for v in [6, 1, 0, 1, 7, 1, 8, 1, 6, 1] { b.push(v as i32); }
    var ops: diff::Op[>..] = [];
    let code, ex = diff::diff_ids_alg(a[..], b[..], diff::ALG_MYERS_SPLIT, 2000, 50000000, ops);
    assert(code == diff::ERR_OK && ex);
    assert(ops[0].tag == diff::OP_INSERT && ops[0].b_hi == 2);
    assert(ops[1].tag == diff::OP_EQUAL && ops[1].a_lo == 0 && ops[1].a_hi == 2 && ops[1].b_lo == 2 && ops[1].b_hi == 4);
    assert(ops[2].tag == diff::OP_REPLACE && ops[2].a_lo == 2 && ops[2].a_hi == 3 && ops[2].b_lo == 4 && ops[2].b_hi == 7);
    var o = diff::default_options();
    o.algorithm = diff::ALG_MYERS_SPLIT;
    var lops: diff::Op[>..] = [];
    let c2, e2 = diff::diff_lines("a\nb\nc\n", "a\nX\nc\n", o, lops);
    assert(c2 == diff::ERR_OK);
    assert(lops.len == 3 && lops[1].tag == diff::OP_REPLACE);
}
