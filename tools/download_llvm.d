/+ dub.sdl:
    name "download_llvm"
+/
module download_llvm;

import std.stdio : println = writeln;

enum Platform
{
    darwin,
    freebsd,
    windows,

    debian,
    fedora,
    ubuntu,
}

enum llvmArchives = [
    Platform.darwin: [
        64: "clang+llvm-%s-x86_64-apple-darwin.tar.xz"
    ],
    Platform.freebsd: [
        64: "clang+llvm-%s-amd64-unknown-freebsd10.tar.xz",
        32: "clang+llvm-%s-i386-unknown-freebsd10.tar.xz"
    ],
    Platform.debian: [
        64: "clang+llvm-%s-x86_64-linux-gnu-debian8.tar.xz"
    ],
    Platform.fedora: [
        64: "clang+llvm-%s-x86_64-fedora23.tar.xz",
        32: "clang+llvm-%s-i686-fedora23.tar.xz"
    ],
    Platform.ubuntu: [
        64: "clang+llvm-%s-x86_64-linux-gnu-ubuntu-14.04.tar.xz"
    ],
    Platform.windows: [
        64: "LLVM-%s-win64.exe",
        32: "LLVM-%s-win32.exe"
    ]
];

void main()
{
    downloadLLVM();
    extractArchive();
}

void downloadLLVM()
{
    import std.file : exists, mkdirRecurse;
    import std.net.curl : download;
    import std.path : buildPath;
    import std.stdio : writefln;

    auto archivePath = buildPath("clangs", llvmArchive);

    if (!exists(archivePath))
    {
        writefln("Downloading LLVM %s to %s", llvmVersion, archivePath);
        mkdirRecurse("clangs");
        download(llvmUrl, archivePath);
    }

    else
        writefln("LLVM %s already exists", llvmVersion);
}

void extractArchive()
{
    import std.path : buildPath;
    import std.stdio : writefln;
    import std.file : mkdirRecurse;

    auto archivePath = buildPath("clangs", llvmArchive);
    auto targetPath = buildPath("clangs", "clang");

    writefln("Extracting %s to %s", archivePath, targetPath);

    mkdirRecurse(targetPath);

    version (Posix)
        execute("tar", "xf", archivePath, "-C", targetPath, "--strip-components=1");
    else
        execute("7z", "x", archivePath, "-y", "-o" ~ targetPath);
}

string llvmVersion()
{
    import std.process : environment;

    return environment.get("LLVM_VERSION", "4.0.0");
}

string llvmUrl()
{
    import std.array : join;

    return ["https://releases.llvm.org", llvmVersion, llvmArchive].join("/");
}

string llvmArchive()
{
    import std.format : format;

    return llvmArchives
        .tryGet(platform)
        .tryGet(architecture)
        .format(llvmVersion);
}

int architecture()
{
    version (X86_64)
        return 64;
    else version (X86)
        return 32;
    else
        static assert("unsupported architecture");
}

Platform platform()
{
    import std.traits : EnumMembers;

    version (OSX)
        return Platform.darwin;
    else version (FreeBSD)
        return Platform.freebsd;
    else version (Windows)
        return Platform.windows;
    else version (linux)
        return linuxPlatform();
    else
        static assert("unsupported platform");
}

Platform linuxPlatform()
{
    import std.algorithm : canFind;

    static struct System
    {
    static:
        import core.sys.posix.sys.utsname : utsname, uname;

        import std.exception : assumeUnique;
        import std.string : fromStringz;
        import std.uni : toLower;

        private utsname data_;

        private utsname data()
        {
            import std.exception;

            if (data_ != data_.init)
                return data_;

            errnoEnforce(!uname(&data_));
            return data_;
        }

        string update ()
        {
            return data.update.ptr.fromStringz.toLower.assumeUnique;
        }

        string nodename ()
        {
            return data.nodename.ptr.fromStringz.toLower.assumeUnique;
        }
    }

    if (System.nodename.canFind("fedora"))
        return Platform.fedora;
    else if (System.nodename.canFind("ubuntu") || System.update.canFind("ubuntu"))
        return Platform.ubuntu;
    else if (System.nodename.canFind("debian"))
        return Platform.debian;
    else
        throw new Exception("Failed to identify the Linux platform");
}

void execute(string[] args ...)
{
    import std.process : spawnProcess, wait;
    import std.array : join;

    if (spawnProcess(args).wait() != 0)
        throw new Exception("Failed to execute command: " ~ args.join(' '));
}

inout(V) tryGet(K, V)(inout(V[K]) aa, K key)
{
    import std.format : format;

    if (auto value = key in aa)
        return *value;
    else
    {
        auto message = format("The key '%s' did not exist in the associative " ~
            "array: %s", key, aa
        );

        throw new Exception(message);
    }
}
