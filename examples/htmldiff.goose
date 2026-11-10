// A side by side table of two texts, and a full page.
import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

fn main() {
    let a = "one\ntwo three four\n\tfive\n";
    let b = "one\ntwo three 4\n\tfive\nsix <b>\n";
    var h = diff::default_html_options();
    var table: u8[>..] = [];
    // The names of the files head the two columns. The call escapes them.
    let code = diff::html_table(a, b, "old.txt", "new <b>.txt", diff::default_options(), h, table);
    assert(code == diff::ERR_OK);
    print(table[..], "\n");
    // A page with the table, the style and the legend.
    var page: u8[>..] = [];
    assert(diff::html_file(a, b, "old.txt", "new.txt", "utf-8", diff::default_options(), h, page) == diff::ERR_OK);
    print("the page holds ", page.len, " bytes\n");
}
