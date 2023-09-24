// NMakeWriter.cs - a Makefile writer
// Copyright (C) 2001, 2002  Jason Diamond
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
using System.Collections;
using System.IO;

namespace SLiNgshoT.Core {
    [OutputFormat("nmake")]
    public class NMakeWriter : ISolutionWriter {
        public NMakeWriter() {
        }

        private TextWriter writer;
        private Project project;

        public void SetOutput(TextWriter output) {
            writer = output;
        }

        public void SetParameters(Hashtable parameters) {
        }

        private string GetProjectName(Project project) {
            return project.Name.Replace('.', '_').ToUpper();
        }

        public void WriteStartSolution(Solution solution) {
            writer.WriteLine("# Generated by SLiNgshoT <http://injektilo.org/>");
            writer.WriteLine();

            writer.WriteLine("!IFNDEF CFG");
            writer.WriteLine();

            writer.WriteLine("CFG = Debug");

            writer.WriteLine();
            writer.WriteLine("!ENDIF");
            writer.WriteLine();

            bool firstConfig = true;

            foreach (string configurationName in solution.GetConfigurationNames()) {
                if (firstConfig) {
                    writer.Write("!IF");
                    firstConfig = false;
                }
                else {
                    writer.Write("!ELSE IF");
                }

                writer.WriteLine(" \"$(CFG)\" == \"{0}\"", configurationName);
                writer.WriteLine();

                foreach (Project project in solution.GetProjects()) {
                    Configuration configuration = project.GetConfiguration(configurationName);

                    writer.WriteLine(
                        GetProjectName(project) +
                        "_DIRECTORY = " +
                        Path.GetDirectoryName(project.GetRelativeOutputPathForConfiguration(configurationName)));

                    writer.WriteLine(
                        GetProjectName(project) +
                        " = $(" + GetProjectName(project) + "_DIRECTORY)\\" +
                        Path.GetFileName(project.GetRelativeOutputPathForConfiguration(configurationName)));

                    writer.WriteLine(
                        GetProjectName(project) +
                        "_DEBUG = /debug" +
                        (configuration.DebugSymbols ? "+" : "-"));

                    writer.WriteLine(
                        GetProjectName(project) +
                        "_UNSAFE = /unsafe" +
                        (configuration.AllowUnsafeBlocks ? "+" : "-"));

                    writer.Write(GetProjectName(project) + "_DEFINES =");

                    string defineConstants = configuration.DefineConstants;

                    if (defineConstants != null && defineConstants.Length > 0) {
                        writer.Write(" /define:" + defineConstants);
                    }

                    writer.WriteLine();

                    string documentationFile = Path.GetFileName(project.GetRelativePathToDocumentationFile(configurationName));

                    if (documentationFile != null && documentationFile.Length > 0) {
                        writer.WriteLine(
                            GetProjectName(project) +
                            "_DOC = /doc:$(" +
                            GetProjectName(project) +
                            "_DIRECTORY)\\" +
                            documentationFile);
                    }
                    else {
                        writer.WriteLine("{0}_DOC =", GetProjectName(project));
                    }

                    writer.WriteLine();
                }
            }

            writer.WriteLine("!ENDIF");
            writer.WriteLine();

            writer.Write("all:");

            foreach (Project project in solution.GetProjects()) {
                if (project.CountFiles("Compile") > 0) {
                    writer.Write(" $(" + GetProjectName(project) + ")");
                }
            }

            writer.WriteLine();
            writer.WriteLine();
        }

        public void WriteStartProjectSourceFiles(Project project) {
            this.project = project;

            writer.Write("{0}_SOURCE_FILES =", GetProjectName(project));
        }

        public void WriteProjectSourceFile(File file) {
            writer.WriteLine(" \\");
            writer.Write("\t{0}", file.RelativePathFromSolutionDirectory);
        }

        public void WriteEndProjectSourceFiles() {
            writer.WriteLine();
            writer.WriteLine();
        }

        public void WriteStartProjectResXResourceFiles(Project project) {
            this.project = project;

            writer.Write("{0}_RESX_FILES =", GetProjectName(project));
        }

        public void WriteProjectResXResourceFile(File file) {
            writer.WriteLine(" \\");
            writer.Write("\t{0}", file.RelativePathFromSolutionDirectory);
        }

        public void WriteEndProjectResXResourceFiles() {
            writer.WriteLine();
            writer.WriteLine();
        }

        public void WriteStartProjectNonResXResourceFiles(Project project) {
            this.project = project;

            writer.Write("{0}_RESOURCE_FILES =", GetProjectName(project));
        }

        public void WriteProjectNonResXResourceFile(File file) {
            writer.WriteLine(" \\");
            writer.Write("\t{0}", file.RelativePathFromSolutionDirectory);
        }

        public void WriteEndProjectNonResXResourceFiles() {
            writer.WriteLine();
            writer.WriteLine();
        }

        public void WriteStartProject(Project project) {
            this.project = project;

            writer.Write("$(" + GetProjectName(project) + "):");
        }

        public void WriteStartProjectDependencies() {
        }

        public void WriteProjectDependency(Project project) {
            writer.Write(" $(" + GetProjectName(project) + ")");
        }

        public void WriteProjectDependency(File file) {
        }

        public void WriteEndProjectDependencies() {
            writer.Write(" $({0}_SOURCE_FILES)", GetProjectName(project));

            if (project.GetResXResourceFiles().Count > 0) {
                writer.Write(" $({0}_RESX_FILES)", GetProjectName(project));
            }

            if (project.GetNonResXResourceFiles().Count > 0) {
                writer.Write(" $({0}_RESOURCE_FILES)", GetProjectName(project));
            }

            writer.WriteLine();

            writer.WriteLine("\tif not exist $(" + GetProjectName(project) + "_DIRECTORY) md $(" + GetProjectName(project) + "_DIRECTORY)");
        }

        public void WriteStartResXFiles() {
        }

        public void WriteResXFile(File file) {
            writer.WriteLine("\tresgen " +
                file.RelativePathFromSolutionDirectory +
                " $(" + GetProjectName(project) + "_DIRECTORY)\\" +
                project.RootNamespace +
                "." +
                Path.GetFileNameWithoutExtension(file.RelativePath) +
                ".resources");
        }

        public void WriteEndResXFiles() {
        }

        public void WriteStartAssembly() {
            writer.Write("\tcsc /nologo /target:" +
                project.OutputType.ToLower() +
                " /out:" +
                "$(" + GetProjectName(project) + ")" +
                " $(" + GetProjectName(project) + "_DEBUG)" +
                " $(" + GetProjectName(project) + "_UNSAFE)" +
                " $(" + GetProjectName(project) + "_DEFINES)" +
                " $(" + GetProjectName(project) + "_DOC)");
        }

        public void WriteStartSourceFiles() {
            writer.Write(" $({0}_SOURCE_FILES)", GetProjectName(project));
        }

        public void WriteSourceFile(File file) {
        }

        public void WriteEndSourceFiles() {
        }

        public void WriteStartReferences() {
        }

        public void WriteReference(string name, bool built) {
            writer.Write(" /reference:");

            if (built) {
                writer.Write("$(" + GetProjectName(project) + "_DIRECTORY)\\");
            }

            writer.Write(name);
        }

        public void WriteReference(Project project) {
            writer.Write(" /reference:$(" + GetProjectName(project) + ")");
        }

        public void WriteEndReferences() {
            // <arg value="/lib:${build.dir}" />

            // writer.Write(" /reference:$(" + GetProjectName(project) + ")");
        }

        public void WriteStartResources() {
        }

        public void WriteResource(string path, string name, bool built) {
            writer.Write(" /resource:");

            if (built) {
                writer.Write("$(" + GetProjectName(project) + "_DIRECTORY)\\");
            }

            writer.Write(path);

            if (name != null) {
                writer.Write("," + name);
            }
        }

        public void WriteEndResources() {
        }

        public void WriteStartCopyProjectAssemblies() {
        }

        public void WriteCopyProjectAssembly(Project project) {
            writer.WriteLine(
                "\tcopy $({0}) $({1}_DIRECTORY)",
                GetProjectName(project),
                GetProjectName(this.project));
        }

        public void WriteEndCopyProjectAssemblies() {
        }

        public void WriteEndAssembly() {
            writer.WriteLine();
        }

        public void WriteEndProject() {
            writer.WriteLine();
        }

        public void WriteStartCleanTarget() {
            writer.WriteLine("clean:");
        }

        public void WriteCleanProject(Project project) {
            writer.WriteLine("\trd /s /q $({0}_DIRECTORY)", GetProjectName(project));
        }

        public void WriteEndCleanTarget() {
        }

        public void WriteEndSolution() {
        }
    }
}
