// The tests of the group html.
namespace html_tests;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";
import diff_checks;

// test_html pins the bytes of Python 3.14 and the safe behavior.
fn test_html() {
    var t1a: u8[>..] = [];
    var t1h = diff::default_html_options();
    t1h.context = false;
    t1h.numlines = 5;
    t1h.tabsize = 8;
    t1h.wrapcolumn = 0;
    t1h.prefix = 0;
    assert(diff::html_table("a\nb<&>\nc\n", "a\nb2\nd\n", "F", "T", diff::default_options(), t1h, t1a) == diff::ERR_OK);
    assert(t1a[..] == "\n    <table class=\"diff\" id=\"difflib_chg_to0__top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <thead><tr><th class=\"diff_next\"><br /></th><th colspan=\"2\" class=\"diff_header\">F</th><th class=\"diff_next\"><br /></th><th colspan=\"2\" class=\"diff_header\">T</th></tr></thead>\n        <tbody>\n            <tr><td class=\"diff_next\" id=\"difflib_chg_to0__0\"><a href=\"#difflib_chg_to0__0\">f</a></td><td class=\"diff_header\" id=\"from0_1\">1</td><td nowrap=\"nowrap\">a</td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__0\">f</a></td><td class=\"diff_header\" id=\"to0_1\">1</td><td nowrap=\"nowrap\">a</td></tr>\n            <tr><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td class=\"diff_header\" id=\"from0_2\">2</td><td nowrap=\"nowrap\"><span class=\"diff_sub\">b&lt;&amp;&gt;</span></td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td class=\"diff_header\" id=\"to0_2\">2</td><td nowrap=\"nowrap\"><span class=\"diff_add\">b2</span></td></tr>\n            <tr><td class=\"diff_next\"></td><td class=\"diff_header\" id=\"from0_3\">3</td><td nowrap=\"nowrap\"><span class=\"diff_sub\">c</span></td><td class=\"diff_next\"></td><td class=\"diff_header\" id=\"to0_3\">3</td><td nowrap=\"nowrap\"><span class=\"diff_add\">d</span></td></tr>\n        </tbody>\n    </table>");
    var t2a: u8[>..] = [];
    var t2h = diff::default_html_options();
    t2h.context = true;
    t2h.numlines = 1;
    t2h.tabsize = 4;
    t2h.wrapcolumn = 0;
    t2h.prefix = 0;
    assert(diff::html_table("one\ntwo three four\n	five six\nseven\neight\nnine\nten\neleven\n", "one\ntwo three 4\n	five six\nseven\neight\nnine\nten\nelevenX\n", "", "", diff::default_options(), t2h, t2a) == diff::ERR_OK);
    assert(t2a[..] == "\n    <table class=\"diff\" id=\"difflib_chg_to0__top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        \n        <tbody>\n            <tr><td class=\"diff_next\" id=\"difflib_chg_to0__0\"><a href=\"#difflib_chg_to0__0\">f</a></td><td class=\"diff_header\" id=\"from0_1\">1</td><td nowrap=\"nowrap\">one</td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__0\">f</a></td><td class=\"diff_header\" id=\"to0_1\">1</td><td nowrap=\"nowrap\">one</td></tr>\n            <tr><td class=\"diff_next\"><a href=\"#difflib_chg_to0__1\">n</a></td><td class=\"diff_header\" id=\"from0_2\">2</td><td nowrap=\"nowrap\">two&nbsp;three&nbsp;<span class=\"diff_chg\">four</span></td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__1\">n</a></td><td class=\"diff_header\" id=\"to0_2\">2</td><td nowrap=\"nowrap\">two&nbsp;three&nbsp;<span class=\"diff_chg\">4</span></td></tr>\n            <tr><td class=\"diff_next\"></td><td class=\"diff_header\" id=\"from0_3\">3</td><td nowrap=\"nowrap\">&nbsp;&nbsp;&nbsp;&nbsp;five&nbsp;six</td><td class=\"diff_next\"></td><td class=\"diff_header\" id=\"to0_3\">3</td><td nowrap=\"nowrap\">&nbsp;&nbsp;&nbsp;&nbsp;five&nbsp;six</td></tr>\n        </tbody>        \n        <tbody>\n            <tr><td class=\"diff_next\" id=\"difflib_chg_to0__1\"></td><td class=\"diff_header\" id=\"from0_7\">7</td><td nowrap=\"nowrap\">ten</td><td class=\"diff_next\"></td><td class=\"diff_header\" id=\"to0_7\">7</td><td nowrap=\"nowrap\">ten</td></tr>\n            <tr><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td class=\"diff_header\" id=\"from0_8\">8</td><td nowrap=\"nowrap\">eleven</td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td class=\"diff_header\" id=\"to0_8\">8</td><td nowrap=\"nowrap\">eleven<span class=\"diff_add\">X</span></td></tr>\n        </tbody>\n    </table>");
    var t3a: u8[>..] = [];
    var t3h = diff::default_html_options();
    t3h.context = false;
    t3h.numlines = 5;
    t3h.tabsize = 8;
    t3h.wrapcolumn = 12;
    t3h.prefix = 3;
    assert(diff::html_table("the quick brown fox jumps over the lazy dog\n", "the quick brown cat jumps over the lazy dog!\n", "", "", diff::default_options(), t3h, t3a) == diff::ERR_OK);
    assert(t3a[..] == "\n    <table class=\"diff\" id=\"difflib_chg_to3__top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        \n        <tbody>\n            <tr><td class=\"diff_next\" id=\"difflib_chg_to3__0\"><a href=\"#difflib_chg_to3__top\">t</a></td><td class=\"diff_header\" id=\"from3_1\">1</td><td nowrap=\"nowrap\">the&nbsp;quick&nbsp;br</td><td class=\"diff_next\"><a href=\"#difflib_chg_to3__top\">t</a></td><td class=\"diff_header\" id=\"to3_1\">1</td><td nowrap=\"nowrap\">the&nbsp;quick&nbsp;br</td></tr>\n            <tr><td class=\"diff_next\"></td><td class=\"diff_header\">></td><td nowrap=\"nowrap\">own&nbsp;<span class=\"diff_chg\">fox</span>&nbsp;jump</td><td class=\"diff_next\"></td><td class=\"diff_header\">></td><td nowrap=\"nowrap\">own&nbsp;<span class=\"diff_chg\">cat</span>&nbsp;jump</td></tr>\n            <tr><td class=\"diff_next\"></td><td class=\"diff_header\">></td><td nowrap=\"nowrap\">s&nbsp;over&nbsp;the&nbsp;l</td><td class=\"diff_next\"></td><td class=\"diff_header\">></td><td nowrap=\"nowrap\">s&nbsp;over&nbsp;the&nbsp;l</td></tr>\n            <tr><td class=\"diff_next\"></td><td class=\"diff_header\">></td><td nowrap=\"nowrap\">azy&nbsp;dog</td><td class=\"diff_next\"></td><td class=\"diff_header\">></td><td nowrap=\"nowrap\">azy&nbsp;dog<span class=\"diff_add\">!</span></td></tr>\n        </tbody>\n    </table>");
    var t4a: u8[>..] = [];
    var t4h = diff::default_html_options();
    t4h.context = false;
    t4h.numlines = 5;
    t4h.tabsize = 8;
    t4h.wrapcolumn = 0;
    t4h.prefix = 0;
    assert(diff::html_table("", "", "", "", diff::default_options(), t4h, t4a) == diff::ERR_OK);
    assert(t4a[..] == "\n    <table class=\"diff\" id=\"difflib_chg_to0__top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        \n        <tbody>\n            <tr><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td></td><td>&nbsp;Empty File&nbsp;</td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td></td><td>&nbsp;Empty File&nbsp;</td></tr>\n        </tbody>\n    </table>");
    var t5a: u8[>..] = [];
    var t5h = diff::default_html_options();
    t5h.context = true;
    t5h.numlines = 5;
    t5h.tabsize = 8;
    t5h.wrapcolumn = 0;
    t5h.prefix = 0;
    assert(diff::html_table("x\n", "x\n", "", "", diff::default_options(), t5h, t5a) == diff::ERR_OK);
    assert(t5a[..] == "\n    <table class=\"diff\" id=\"difflib_chg_to0__top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        \n        <tbody>\n            <tr><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td></td><td>&nbsp;No Differences Found&nbsp;</td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td></td><td>&nbsp;No Differences Found&nbsp;</td></tr>\n        </tbody>\n    </table>");
    var pg: u8[>..] = [];
    assert(diff::html_file("a\nb\n", "a\nc\n", "F", "T", "utf-8", diff::default_options(), diff::default_html_options(), pg) == diff::ERR_OK);
    assert(pg[..] == "\n<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\"\n          \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n\n<html>\n\n<head>\n    <meta http-equiv=\"Content-Type\"\n          content=\"text/html; charset=utf-8\" />\n    <title></title>\n    <style type=\"text/css\">\n        :root {color-scheme: light dark}\n        table.diff {font-family: Menlo, Consolas, Monaco, Liberation Mono, Lucida Console, monospace; border:medium}\n        .diff_header {background-color:#e0e0e0}\n        td.diff_header {text-align:right}\n        .diff_next {background-color:#c0c0c0}\n        .diff_add {background-color:palegreen}\n        .diff_chg {background-color:#ffff77}\n        .diff_sub {background-color:#ffaaaa}\n\n        @media (prefers-color-scheme: dark) {\n            .diff_header {background-color:#666}\n            .diff_next {background-color:#393939}\n            .diff_add {background-color:darkgreen}\n            .diff_chg {background-color:#847415}\n            .diff_sub {background-color:darkred}\n        }\n    </style>\n</head>\n\n<body>\n    \n    <table class=\"diff\" id=\"difflib_chg_to0__top\"\n           cellspacing=\"0\" cellpadding=\"0\" rules=\"groups\" >\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <colgroup></colgroup> <colgroup></colgroup> <colgroup></colgroup>\n        <thead><tr><th class=\"diff_next\"><br /></th><th colspan=\"2\" class=\"diff_header\">F</th><th class=\"diff_next\"><br /></th><th colspan=\"2\" class=\"diff_header\">T</th></tr></thead>\n        <tbody>\n            <tr><td class=\"diff_next\" id=\"difflib_chg_to0__0\"><a href=\"#difflib_chg_to0__0\">f</a></td><td class=\"diff_header\" id=\"from0_1\">1</td><td nowrap=\"nowrap\">a</td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__0\">f</a></td><td class=\"diff_header\" id=\"to0_1\">1</td><td nowrap=\"nowrap\">a</td></tr>\n            <tr><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td class=\"diff_header\" id=\"from0_2\">2</td><td nowrap=\"nowrap\"><span class=\"diff_sub\">b</span></td><td class=\"diff_next\"><a href=\"#difflib_chg_to0__top\">t</a></td><td class=\"diff_header\" id=\"to0_2\">2</td><td nowrap=\"nowrap\"><span class=\"diff_add\">c</span></td></tr>\n        </tbody>\n    </table>\n    <table class=\"diff\" summary=\"Legends\">\n        <tr> <th colspan=\"2\"> Legends </th> </tr>\n        <tr> <td> <table border=\"\" summary=\"Colors\">\n                      <tr><th> Colors </th> </tr>\n                      <tr><td class=\"diff_add\">&nbsp;Added&nbsp;</td></tr>\n                      <tr><td class=\"diff_chg\">Changed</td> </tr>\n                      <tr><td class=\"diff_sub\">Deleted</td> </tr>\n                  </table></td>\n             <td> <table border=\"\" summary=\"Links\">\n                      <tr><th colspan=\"2\"> Links </th> </tr>\n                      <tr><td>(f)irst change</td> </tr>\n                      <tr><td>(n)ext change</td> </tr>\n                      <tr><td>(t)op</td> </tr>\n                  </table></td> </tr>\n    </table>\n</body>\n\n</html>");
    // The text and the descriptions are escaped. Python escapes neither description.
    var hd: u8[>..] = [];
    assert(diff::html_table("<script>alert(1)</script>\n", "b\n", "<i onclick=\"x\">&", "'y'>", diff::default_options(), diff::default_html_options(), hd) == diff::ERR_OK);
    assert(!diff_checks::has(hd[..], "<script>") && !diff_checks::has(hd[..], "<i onclick"));
    assert(diff_checks::has(hd[..], "&lt;script&gt;alert(1)&lt;/script&gt;"));
    assert(diff_checks::has(hd[..], "&lt;i onclick=&quot;x&quot;&gt;&amp;"));
    // The bytes that serve as marks are a fault and change nothing.
    var nb: u8[>..] = ['k'];
    var bad: u8[>..] = ['a', 0, 'b', 10];
    assert(diff::html_table(bad[..], "a\n", "", "", diff::default_options(), diff::default_html_options(), nb) == diff::ERR_BAD_TEXT);
    var bad1: u8[>..] = ['\x01'];
    assert(diff::html_table("a\n", "a\n", bad1[..], "", diff::default_options(), diff::default_html_options(), nb) == diff::ERR_BAD_TEXT);
    assert(nb.len == 1);
    // The charset holds only the bytes of a name.
    assert(diff::html_file("a\n", "b\n", "", "", "utf-8\"><script>", diff::default_options(), diff::default_html_options(), nb) == diff::ERR_BAD_OPTION);
    assert(diff::html_file("a\n", "b\n", "", "", "", diff::default_options(), diff::default_html_options(), nb) == diff::ERR_BAD_OPTION);
    // The rules stay in range.
    var bo = diff::default_html_options();
    bo.numlines = -1;
    assert(diff::html_table("a\n", "b\n", "", "", diff::default_options(), bo, nb) == diff::ERR_BAD_OPTION);
    bo = diff::default_html_options();
    bo.wrapcolumn = -1;
    assert(diff::html_table("a\n", "b\n", "", "", diff::default_options(), bo, nb) == diff::ERR_BAD_OPTION);
    // The output has a cap, and a break at column 1 cannot pass it.
    var long: u8[>..] = [];
    for i in 4000 { long.push('x'); }
    long.push(10);
    var co = diff::default_html_options();
    co.wrapcolumn = 1;
    co.max_output = 20000;
    assert(diff::html_table(long[..], "y\n", "", "", diff::default_options(), co, nb) == diff::ERR_TOO_LARGE);
    co.tabsize = 1000;
    var tabs: u8[>..] = [];
    for i in 100 { tabs.push(9); }
    tabs.push(10);
    assert(diff::html_table(tabs[..], "y\n", "", "", diff::default_options(), co, nb) == diff::ERR_TOO_LARGE);
    assert(nb.len == 1);
}

// test_line_ends pins the conversion of the line ends of a patch, as the
// rule autoConvertLineEndings of jsdiff does it.
fn test_line_ends() {
    // A patch with LF applies to a text with CRLF, and the result keeps CRLF.
    let c1, r1 = diff_checks::le_apply("a\nb\nc\n", "a\nB\nc\n", "a\r\nb\r\nc\r\n", true);
    assert(c1 == diff::ERR_OK);
    assert(r1[..] == "a\r\nB\r\nc\r\n");
    let c2, r2 = diff_checks::le_apply("a\nb\nc\n", "a\nB\nc\n", "a\r\nb\r\nc\r\n", false);
    assert(c2 == diff::ERR_NO_MATCH);
    assert(r2.len == 0);
    // A patch with CRLF applies to a text with LF, and the result keeps LF.
    let c3, r3 = diff_checks::le_apply("a\r\nb\r\nc\r\n", "a\r\nB\r\nc\r\n", "a\nb\nc\n", true);
    assert(c3 == diff::ERR_OK);
    assert(r3[..] == "a\nB\nc\n");
    let c4, r4 = diff_checks::le_apply("a\r\nb\r\nc\r\n", "a\r\nB\r\nc\r\n", "a\nb\nc\n", false);
    assert(c4 == diff::ERR_NO_MATCH);
    // The last line has no line end: no carriage return is added.
    let c5, r5 = diff_checks::le_apply("a\nb\nc", "a\nb\nC", "a\r\nb\r\nc", true);
    assert(c5 == diff::ERR_OK);
    assert(r5[..] == "a\r\nb\r\nC");
    // A text with mixed line ends gets no conversion.
    let c6, r6 = diff_checks::le_apply("a\nb\nc\n", "a\nB\nc\n", "a\r\nb\nc\n", true);
    assert(c6 == diff::ERR_NO_MATCH);
    assert(r6.len == 0);
}

fn test_dated() {
    var dro = diff::default_options();
    dro.algorithm = diff::ALG_RO;
    dro.context = 1;
    var dua: u8[>..] = [];
    let duac, duae = diff::unified_diff_dated(dua, "one\ntwo\nthree\nfour\nfive\nsix\nseven\n", "one\n2\nthree\nfour\nfive\nsix\nseven!\n", "a.txt", "b.txt", "2024-01-01", "2024-01-02", "\r\n", dro);
    assert(duac == diff::ERR_OK && duae);
    assert(dua[..] == "--- a.txt\t2024-01-01\r\n+++ b.txt\t2024-01-02\r\n@@ -1,3 +1,3 @@\r\n one\n-two\n+2\n three\n@@ -6,2 +6,2 @@\r\n six\n-seven\n+seven!\n");
    var dub: u8[>..] = [];
    let dubc, dube = diff::unified_diff_dated(dub, "one\ntwo\nthree\nfour\nfive\nsix\nseven\n", "one\n2\nthree\nfour\nfive\nsix\nseven!\n", "a.txt", "b.txt", "", "now", "", dro);
    assert(dubc == diff::ERR_OK && dube);
    assert(dub[..] == "--- a.txt+++ b.txt\tnow@@ -1,3 +1,3 @@ one\n-two\n+2\n three\n@@ -6,2 +6,2 @@ six\n-seven\n+seven!\n");
    var dca: u8[>..] = [];
    let dcac, dcae = diff::context_diff_dated(dca, "one\ntwo\nthree\nfour\nfive\nsix\nseven\n", "one\n2\nthree\nfour\nfive\nsix\nseven!\n", "a.txt", "b.txt", "t1", "t2", "\r\n", dro);
    assert(dcac == diff::ERR_OK && dcae);
    assert(dca[..] == "*** a.txt\tt1\r\n--- b.txt\tt2\r\n***************\r\n*** 1,3 ****\r\n  one\n! two\n  three\n--- 1,3 ----\r\n  one\n! 2\n  three\n***************\r\n*** 6,7 ****\r\n  six\n! seven\n--- 6,7 ----\r\n  six\n! seven!\n");
    var ndo = diff::default_options();
    var ndd: u8[>..] = [];
    assert(diff::ndiff("#\n\n#\na  b  c  d  e  f\nx y z w\n", "x y z w\nthe quick brown fox\n  # \na  b  c  d  e  f\n\n", ndo, ndd) == diff::ERR_OK);
    assert(ndd[..] == "- #\n+ x y z w\n+ the quick brown fox\n+   # \n+ a  b  c  d  e  f\n  \n- #\n- a  b  c  d  e  f\n- x y z w\n");
    ndo.junk = diff::JUNK_COMMENT;
    var ndl: u8[>..] = [];
    assert(diff::ndiff("#\n\n#\na  b  c  d  e  f\nx y z w\n", "x y z w\nthe quick brown fox\n  # \na  b  c  d  e  f\n\n", ndo, ndl) == diff::ERR_OK);
    assert(ndl[..] == "- #\n- \n- #\n+ x y z w\n+ the quick brown fox\n+   # \n  a  b  c  d  e  f\n- x y z w\n+ \n");
    assert(ndl[..] != ndd[..]);
    ndo.junk = diff::JUNK_NONE;
    var ndc: u8[>..] = [];
    assert(diff::ndiff("a b c d e f\n", "   \na  b  c  d  e  f\n   \n", ndo, ndc) == diff::ERR_OK);
    assert(ndc[..] == "+    \n- a b c d e f\n+ a  b  c  d  e  f\n?   +  +  +  + +\n+    \n");
    ndo.char_junk = diff::CHARJUNK_NONE;
    var ndn: u8[>..] = [];
    assert(diff::ndiff("a b c d e f\n", "   \na  b  c  d  e  f\n   \n", ndo, ndn) == diff::ERR_OK);
    assert(ndn[..] == "+    \n- a b c d e f\n+ a  b  c  d  e  f\n?  +   + +   + +\n+    \n");
    assert(ndn[..] != ndc[..]);
    ndo.char_junk = 7;
    assert(diff::ndiff("a\n", "b\n", ndo, ndn) == diff::ERR_BAD_OPTION);
    // A date with a line end or a terminator with other bytes is a fault.
    var bad: u8[>..] = ['k'];
    let bc1, be1 = diff::unified_diff_dated(bad, "a\n", "b\n", "x", "y", "d\n+++ forged", "", "\n", dro);
    assert(bc1 == diff::ERR_BAD_NAME);
    let bc2, be2 = diff::unified_diff_dated(bad, "a\n", "b\n", "x", "y", "", "", "\n+++ forged\n", dro);
    assert(bc2 == diff::ERR_BAD_OPTION);
    let bc3, be3 = diff::context_diff_dated(bad, "a\n", "b\n", "x", "y", "", "", "\n\n\n", dro);
    assert(bc3 == diff::ERR_BAD_OPTION && bad.len == 1);
}
