// The helpers of the tests of the package.
namespace sample_texts;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

const OLD: const u8[:] = "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl\n";
const NEW: const u8[:] = "a\nB\nc\nd\ne\nf\ng\nh\ni\nj\nk2\nl\nm";


