// NAnt - A .NET build tool
// Copyright (C) 2026 Porter Wood
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;

using NAnt.Core;
using NAnt.Core.Attributes;
using NAnt.Core.Util;

namespace NAnt.Win32.Tasks {
    /// <summary>
    /// Locates the most recent Visual Studio 2017 or later installation using
    /// <c>vswhere</c>, and stores its installation directory in a property.
    /// </summary>
    /// <remarks>
    ///   <para>
    ///   Every edition is considered, including the Build Tools, which do not
    ///   register themselves anywhere else that NAnt can look.
    ///   </para>
    ///   <para>
    ///   <c>vswhere</c> is installed by the Visual Studio installer at a fixed
    ///   location. If it is not there, no Visual Studio 2017 or later is
    ///   installed, and the property is left unset.
    ///   </para>
    /// </remarks>
    /// <example>
    ///   <para>Locate an installation that includes MSBuild.</para>
    ///   <code>
    ///     <![CDATA[
    /// <locatevisualstudio property="vsInstallRoot" />
    ///     ]]>
    ///   </code>
    /// </example>
    /// <example>
    ///   <para>Locate an installation that includes the C++ compilers.</para>
    ///   <code>
    ///     <![CDATA[
    /// <locatevisualstudio property="vcInstallRoot" requires="Microsoft.VisualStudio.Component.VC.Tools.x86.x64" />
    ///     ]]>
    ///   </code>
    /// </example>
    [TaskName("locatevisualstudio")]
    internal class LocateVisualStudioTask : Task {
        #region Private Instance Fields

        private string _propName;
        private string _requires = "Microsoft.Component.MSBuild";
        private FileInfo _vsWhere;

        #endregion Private Instance Fields

        #region Public Instance Properties

        /// <summary>
        /// The property to set to the installation directory of the located
        /// Visual Studio. It is left unset when none is found.
        /// </summary>
        [TaskAttribute("property", Required=true)]
        [StringValidator(AllowEmpty=false)]
        public string PropertyName {
            get { return _propName; }
            set { _propName = value; }
        }

        /// <summary>
        /// The workload or component IDs, separated by spaces, that the
        /// installation must include. The default is
        /// <c>Microsoft.Component.MSBuild</c>. An empty value accepts any
        /// installation.
        /// </summary>
        [TaskAttribute("requires")]
        public string Requires {
            get { return _requires; }
            set { _requires = StringUtils.ConvertEmptyToNull(value); }
        }

        /// <summary>
        /// The <c>vswhere</c> executable to run. The default is the copy the
        /// Visual Studio installer places in
        /// <c>%ProgramFiles(x86)%\Microsoft Visual Studio\Installer</c>.
        /// </summary>
        [TaskAttribute("vswhere")]
        public FileInfo VsWhere {
            get {
                if (_vsWhere == null) {
                    return GetDefaultVsWhere();
                }
                return _vsWhere;
            }
            set { _vsWhere = value; }
        }

        #endregion Public Instance Properties

        #region Override implementation of Task

        /// <summary>
        /// Runs <c>vswhere</c> and stores the installation directory it
        /// reports.
        /// </summary>
        protected override void ExecuteTask() {
            FileInfo vsWhere = VsWhere;
            if (vsWhere == null || !vsWhere.Exists) {
                Log(Level.Verbose, "vswhere was not found{0}, so no Visual Studio"
                    + " 2017 or later is installed.", vsWhere == null ? string.Empty
                    : " at \"" + vsWhere.FullName + "\"");
                return;
            }

            string installPath = RunVsWhere(vsWhere.FullName, GetArguments());
            if (installPath == null) {
                Log(Level.Verbose, "vswhere found no Visual Studio installation{0}.",
                    Requires == null ? string.Empty : " that includes " + Requires);
                return;
            }

            Properties[PropertyName] = installPath;
            Log(Level.Verbose, "Located Visual Studio at \"{0}\".", installPath);
        }

        #endregion Override implementation of Task

        #region Private Instance Methods

        private string GetArguments() {
            // -products * includes the Build Tools, which are left out by default
            StringBuilder arguments = new StringBuilder("-latest -products * -nologo");
            if (Requires != null) {
                arguments.Append(" -requires ").Append(Requires);
            }
            arguments.Append(" -property installationPath");
            return arguments.ToString();
        }

        private string RunVsWhere(string fileName, string arguments) {
            ProcessStartInfo startInfo = new ProcessStartInfo(fileName, arguments);
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;

            Log(Level.Debug, "Running \"{0}\" {1}", fileName, arguments);

            Process process;
            try {
                process = Process.Start(startInfo);
            } catch (Win32Exception ex) {
                throw new BuildException(string.Format(CultureInfo.InvariantCulture,
                    "vswhere could not be started from \"{0}\".", fileName), Location, ex);
            }

            using (process) {
                // read standard error asynchronously, so that vswhere cannot
                // block on a full pipe while standard output is being read
                StringBuilder errors = new StringBuilder();
                process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) {
                    if (e.Data != null) {
                        errors.AppendLine(e.Data);
                    }
                };
                process.BeginErrorReadLine();

                string output = process.StandardOutput.ReadToEnd();
                process.WaitForExit();

                if (process.ExitCode != 0) {
                    throw new BuildException(string.Format(CultureInfo.InvariantCulture,
                        "vswhere exited with code {0}. {1}", process.ExitCode,
                        errors.ToString().Trim()), Location);
                }

                return GetFirstLine(output);
            }
        }

        #endregion Private Instance Methods

        #region Private Static Methods

        private static FileInfo GetDefaultVsWhere() {
            // the installer is always 32-bit, so it lives in "Program Files"
            // only on a 32-bit Windows
            string programFiles = Environment.GetEnvironmentVariable("ProgramFiles(x86)");
            if (string.IsNullOrEmpty(programFiles)) {
                programFiles = Environment.GetEnvironmentVariable("ProgramFiles");
            }
            if (string.IsNullOrEmpty(programFiles)) {
                return null;
            }
            return new FileInfo(Path.Combine(programFiles,
                @"Microsoft Visual Studio\Installer\vswhere.exe"));
        }

        private static string GetFirstLine(string output) {
            foreach (string line in output.Split('\r', '\n')) {
                string trimmed = line.Trim();
                if (trimmed.Length > 0) {
                    return trimmed;
                }
            }
            return null;
        }

        #endregion Private Static Methods
    }
}
