/**
 * Authors: Pedro Tacla Yamada
 * Date: August 1, 2014
 * License: Licensed under the GPLv3 license. See LICENSE for more information
 */
import std.file;
import std.stdio : writeln;

import bed;

import redo;

void main()
{
  describe("redo", {
    // Create a redo test environment:
    before({
      mkdir("mock_env");
      write("mock_env/target.do", "echo 'target' > target");
      write("mock_env/default.js.do", "echo 'extension_target' > extension_target");
    });

    after({
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

    describe("upToDate(topDir, target)", {
      before({
        chdir("mock_env");
      });

      after({
        chdir("..");
      });

      describe("if the target doesn't exist", {
        it("returns false if the target doesn't exist", {
          assert(!upToDate("./", "doesnt_exist"));
        });
      });

      describe("if the target exists", {
        before({
          write("target", "target");
          write("uptodate", "uptodate");
          write("uptodate.do", "mockdo");
          write("notuptodate", "notuptodate");
          write("notuptodate.do", "mockdo");
        });

        describe("but there's no entry in the db for it", {
          it("returns false", {
            assert(!upToDate("./", "target"));
          });
        });

        describe("and there's an entry in the db for it", {
          before({
            setValue("./", "uptodate", "uptodate.do");
            setValue("./", "uptodate:uptodate.do", "uptodate.do".hash);
            setValue("./", "notuptodate", "notuptodate.do");
            setValue("./", "notuptodate:notuptodate.do", "asdf");
          });

          it("returns whether the entries match the dependencies' hashes", {
            assert(upToDate("./", "uptodate"));
            assert(!upToDate("./", "notuptodte"));
          });
        });
      });
    });
  });
}
