import std.file;
import std.stdio : writeln;

import bed;

import redo;

void main()
{
  describe("redo", {
    // Create a redo test environment:
    beforeEach({
      mkdir("mock_env");
      write("mock_env/target.do", "echo 'target' > target");
      write("mock_env/default.js.do", "echo 'extension_target' > extension_target");
    });

    afterEach({
      rmdirRecurse("mock_env");
    });

    describe("redoPath(path)", {
      it("returns `{path}.do` if it exists and is a file", {
        auto ret = redoPath("mock_env/target");
        assert(ret == "mock_env/target.do");
      });

      it("returns `default.{extension}.do` if it exists and `{path}.do` " ~
        "doesn't exist", {
        auto ret = redoPath("mock_env/extension_target.js");
        assert(ret == "mock_env/default.js.do");
      });

      it("returns null otherwise", {
        string ret;
        ret = redoPath("mock_env/null");
        assert(ret is null);
        ret = redoPath("mock_env");
        assert(ret is null);
      });
    });
  });
}
