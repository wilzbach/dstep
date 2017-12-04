module test;

import std.process;
import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.string;
import std.exception;

int main ()
{
    return TestRunner().run;
}

/**
 * The available test groups.
 *
 * The tests will be run in the order specified here.
 */
enum TestGroup
{
    unit = "unit",
    library = "library",
    functional = "functional"
}

struct TestRunner
{
    private string wd;
    private bool clangVersionPrinted;

    int run ()
    {
        import std.traits : EnumMembers;

        downloadClang();
        activate();

        foreach (test ; EnumMembers!TestGroup)
        {
            immutable result = runTest(test);

            if (result != 0)
                return result;
        }

        stdout.flush();

        return 0;
    }

    string workingDirectory ()
    {
        if (wd.length)
            return wd;

        return wd = getcwd();
    }

    string clangBasePath ()
    {
        return buildNormalizedPath(workingDirectory, "clangs");
    }

    void activate ()
    {
        version (Windows)
        {
            auto src = buildNormalizedPath(workingDirectory, clang.versionedLibclang);
            auto dest = buildNormalizedPath(workingDirectory, clang.libclang);

            if (exists(dest))
                remove(dest);

            copy(src, dest);

            auto staticSrc = buildNormalizedPath(workingDirectory, clang.staticVersionedLibclang);
            auto staticDest = buildNormalizedPath(workingDirectory, clang.staticLibclang);

            if (exists(staticDest))
                remove(staticDest);

            copy(staticSrc, staticDest);
        }
        else
            execute(["./configure", "--llvm-path", "clangs/clang/lib"]);
    }

    void downloadClang()
    {
        executeCommand("./download_llvm.sh");
    }

    /**
     * Run a single group of tests, i.e. functional, library or unit test.
     *
     * Params:
     *  testGroup = the test group to run
     *
     * Returns: the exist code of the test run
     */
    int runTest (TestGroup testGroup)
    {
        printClangVersion();
        writefln("Running %s tests ", testGroup);

        immutable command = dubShellCommand("--config=test:" ~ testGroup);
        immutable result = executeShell(command);

        if (result.status != 0)
            writeln(result.output);

        return result.status;
    }

    void printClangVersion()
    {
        import std.file : exists;

        if (clangVersionPrinted || !exists("bin/dstep"))
            return;

        auto output = execute(["./bin/dstep", "--clang-version"]);
        writeln("Testing with ", strip(output.output));
        clangVersionPrinted = true;
    }
}

void executeCommand(string[] args ...)
{
    import std.process : spawnProcess, wait;
    import std.array : join;

    if (spawnProcess(args).wait() != 0)
        throw new Exception("Failed to execute command: " ~ args.join(' '));
}

private string dubShellCommand(string subCommand) @safe pure nothrow
{
    return "dub " ~ subCommand ~ dubArch;
}

private string dubArch() @safe pure nothrow
{
    version (Windows)
    {
        version (X86_64)
            return " --arch=x86_64";
        else
            return " --arch=x86_mscoff";
    }
    else
    {
        return "";
    }
}
