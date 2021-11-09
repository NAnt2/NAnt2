using System;
using System.Collections.Generic;
using System.CommandLine;
using Wyam.Common.IO;
using Wyam.Common.Tracing;
using Wyam.Configuration.Preprocessing;

namespace Wyam.Commands
{
    internal class PreviewCommand : Command
    {
        private readonly Dictionary<string, string> _contentTypes = new Dictionary<string, string>();

        private int _port = 5080;
        private bool _forceExtension = false;
        private DirectoryPath _path = null;
        private DirectoryPath _virtualDirectory = null;

        public override string Description => "Runs the preview server without generating anything.";

        protected override void ParseOptions(ArgumentSyntax syntax)
        {
            syntax.DefineOption("p|port", ref _port, "Start the preview web server on the specified port (default is " + _port + ").");
            syntax.DefineOption("force-ext", ref _forceExtension, "Force the use of extensions in the preview web server (by default, extensionless URLs may be used).");
            syntax.DefineOption("virtual-dir", ref _virtualDirectory, DirectoryPathFromArg, "Serve files in the preview web server under the specified virtual directory.");
            IReadOnlyList<string> contentTypes = null;
            if (syntax.DefineOptionList("content-type", ref contentTypes, "Specifies additional supported content types for the preview server as extension=contenttype.").IsSpecified)
            {
                AddContentTypes(contentTypes, _contentTypes, syntax);
            }
        }

        protected override void ParseParameters(ArgumentSyntax syntax)
        {
            syntax.DefineParameter("path", ref _path, DirectoryPathFromArg, "The path that the server should preview (defaults to \"output\").");
        }

        protected override ExitCode RunCommand(Preprocessor preprocessor)
        {
            _path = new DirectoryPath(Environment.CurrentDirectory).Combine(_path ?? "output");
            using (PreviewServer.Start(_path, _port, _forceExtension, _virtualDirectory, false, _contentTypes))
            {
                Trace.Information("Hit Ctrl-C to exit");
                Console.TreatControlCAsInput = true;
                while (true)
                {
                    // Would have prefered to use Console.CancelKeyPress, but that bubbles up to calling batch files
                    // The (ConsoleKey)3 check is to support a bug in VS Code: https://github.com/Microsoft/vscode/issues/9347
                    ConsoleKeyInfo consoleKey = Console.ReadKey(true);
                    if (consoleKey.Key == (ConsoleKey)3 || (consoleKey.Key == ConsoleKey.C && (consoleKey.Modifiers & ConsoleModifiers.Control) != 0))
                    {
                        break;
                    }
                }
                Trace.Information("Shutting down");
            }
            return ExitCode.Normal;
        }

        public static void AddContentTypes(IReadOnlyList<string> contentTypes, IDictionary<string, string> contentTypeDictionary, ArgumentSyntax syntax)
        {
            foreach (string contentType in contentTypes)
            {
                string[] splitContentType = contentType.Split('=');
                if (splitContentType.Length != 2)
                {
                    syntax.ReportError($"Invalid content type {contentType} specified.");
                    continue;
                }
                contentTypeDictionary[splitContentType[0].Trim().Trim('\"')] = splitContentType[1].Trim().Trim('\"');
            }
        }
    }
}