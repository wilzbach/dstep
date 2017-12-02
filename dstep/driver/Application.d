/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import std.getopt;
import std.stdio : writeln, stderr;
import Path = std.path;
import std.file;
import std.parallelism;

import clang.c.Index;

import clang.Compiler;
import clang.Index;
import clang.TranslationUnit;
import clang.Util;

import dstep.Configuration;
import dstep.translator.Options;
import dstep.core.Exceptions;
import dstep.translator.Options;
import dstep.translator.Translator;

class Application
{
    private
    {
        Configuration config;
    }

    public this (Configuration config)
    {
        this.config = config;
    }

    public void run ()
    {
        import std.exception : enforce;

        import dstep.driver.Util : defaultOutputFilename;

        enforce!DStepException(config.inputFiles.length > 0,
            "dstep: error: must supply at least one input file\n");

        enforceInputFilesExist(config);

        // when only one input file is supplied, -o argument is
        // interpreted as file path, otherwise as base directory path
        bool singleFileInput = config.inputFiles.length == 1;

        Task!(
            startParsingFile,
            Configuration,
            string,
            string)*[] conversionTasks;

        conversionTasks.length = config.inputFiles.length;

        // parallel generation of D modules for each of input files
        foreach (size_t index, fileName; config.inputFiles)
        {
            string outputFilename;

            if (singleFileInput)
            {
                if (config.output.length)
                    outputFilename = config.output;
                else
                    outputFilename = defaultOutputFilename(fileName, false);
            }
            else
            {
                outputFilename = Path.buildPath(config.output,
                    defaultOutputFilename(fileName, false));
            }

            string outputDir = Path.dirName(outputFilename);

            if (!exists(outputDir))
                mkdirRecurse(outputDir);

            conversionTasks[index] = task!startParsingFile(
                config,
                fileName,
                outputFilename);

            conversionTasks[index].executeInNewThread();
        }

        foreach (conversionTask; conversionTasks)
            conversionTask.yieldForce();
    }

    static void enforceInputFilesExist(const Configuration config)
    {
        import std.exception : enforce;
        import std.format : format;

        foreach (inputFile; config.inputFiles)
        {
            enforce!DStepException(
                exists(inputFile),
                format("dstep: error: file '%s' doesn't exist\n", inputFile));

            enforce!DStepException(
                isFile(inputFile),
                format("dstep: error: '%s' is not a file\n", inputFile));
        }
    }

    static void startParsingFile (const Configuration config, string fileName,
        string outputFilename)
    {
        ParseFile(config, fileName, outputFilename)
            .startConversion();
    }
}

private struct ParseFile
{
    private
    {
        string inputFile;
        string outputFile;
        Index index;
        TranslationUnit translationUnit;
        DiagnosticVisitor diagnostics;

        const Configuration config;
        Compiler compiler;
    }

    this (
        const Configuration config,
        string inputFile,
        string outputFile)
    {
        this.config = config;
        this.inputFile = inputFile;
        this.outputFile = outputFile;
    }

    void startConversion ()
    {
        import std.algorithm.iteration : map;
        import std.array;

        index = Index(false, false);

        auto include_flags = compiler
            .extraIncludePaths.map!(e => "-I" ~ e).array();
        translationUnit = TranslationUnit.parse(
            index,
            inputFile,
            config.clangParams ~ include_flags,
            compiler.extraHeaders);

        diagnostics = translationUnit.diagnostics;

        enforceCompiled();

        if (exists(inputFile))
        {
            import std.algorithm : map;
            import std.array : array;

            Options options = this.config.toOptions(inputFile, outputFile);

            auto translator = new Translator(translationUnit, options);
            translator.translate;
        }
    }

    ~this ()
    {
        clean();
    }

private:

    void clean ()
    {
        translationUnit.dispose;
        index.dispose;
    }

    bool anyErrors ()
    {
        return diagnostics.length > 0;
    }

    void enforceCompiled ()
    {
        import std.array : Appender;
        import std.exception : enforce;

        bool translate = true;
        auto message = Appender!string();

        foreach (diag ; diagnostics)
        {
            auto severity = diag.severity;

            with (CXDiagnosticSeverity)
                if (translate)
                    translate = !(severity == error || severity == fatal);

            message.put(diag.format);
            message.put("\n");
        }

        enforce!DStepException(translate, message.data);
    }
}
