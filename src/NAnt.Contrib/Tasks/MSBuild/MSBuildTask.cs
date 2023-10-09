// NAnt - A .NET build tool
// Copyright (C) 2001-2006 Gerry Shaw
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
//

// Martin Aliger (martin_aliger@myrealbox.com)
// Gert Driesen  (drieseng@users.sourceforge.net)
// Simona Avornicesei (simona@avornicesei.com)

using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.IO;

using NAnt.Core;
using NAnt.Core.Tasks;
using NAnt.Core.Attributes;
using NAnt.Core.Types;

namespace NAnt.Contrib.Tasks.MSBuild {
    /// <summary>
    /// Builds the specified targets in the project file using <c>MSBuild</c>.
    /// </summary>
    /// <remarks>
    ///   <para>    
    ///   If a project file is not specified, MSBuild searches the current 
    ///   working directory for a file that has a file extension that ends in
    ///   "proj" and uses that file.
    ///   </para>
    /// </remarks>
    [TaskName("msbuild")]
    [ProgramLocation(LocationType.FrameworkDir)]
    public class MsbuildTask : ExternalProgramBase {

        #region Private Instance Fields

        private string _responseFileName;
        private FileInfo _projectFile;
        private ArrayList _properties = new ArrayList();
        private string _target;
        private bool _noautoresponse;
        private VerbosityLevel _verbosity = VerbosityLevel.NotSet;
        private MSBuildVersion _msBuildVersion = MSBuildVersion.v4;

        #endregion Private Instance Fields

        #region Public Instance Properties
        
        /// <summary>
        /// Do not auto-include the MSBuild.rsp file.
        /// </summary>
        /// <remarks>
        /// <para>
        /// From MSBuild official documentation <see href="https://learn.microsoft.com/en-us/visualstudio/msbuild/msbuild-response-files?view=vs-2022"/>:
        /// <i>Response (.rsp) files are text files that contain MSBuild.exe command-line switches. Each switch can be on a separate line
        /// or all switches can be on one line. Comment lines are prefaced with a # symbol.
        /// The @ switch is used to pass another response file to MSBuild.exe.</i>
        /// </para>
        /// </remarks>
        [TaskAttribute("noautoresponse")]
        [BooleanValidator()]
        public bool NoAutoResponse {
            get { return _noautoresponse; }
            set { _noautoresponse = value; }
        }

        /// <summary>
        /// The project to build.
        /// </summary>
        [TaskAttribute("project")]
        public FileInfo ProjectFile {
            get { return _projectFile; }
            set { _projectFile = value; }
        }

        /// <summary>
        /// Set or override these project-level properties.
        /// </summary>
        [BuildElementArray("property", ElementType=typeof(PropertyTask))]
        public new ArrayList Properties {
            get { return _properties; }
        }

        /// <summary>
        /// Build these targets in this project. Use a semicolon or a comma
        /// comma to separate multiple targets.
        /// </summary>
        [TaskAttribute("target")]
        public string Target {
            get { return _target;}
            set { _target = value;}
        }

        /// <summary>
        /// Specifies the amount of information to display in the MSBuild log.
        /// </summary>
        [TaskAttribute("verbosity")]
        public VerbosityLevel Verbosity {
            get { return _verbosity; }
            set { _verbosity = value; }
        }
        
        /// <summary>
        /// Specifies the version of MSBuild that should be used.
        /// </summary>
        [TaskAttribute("version")]
        public MSBuildVersion Version {
            get { return _msBuildVersion; }
            set { _msBuildVersion = value; }
        }

        #endregion Public Instance Properties

        #region Override implementation of ExternalProgramBase
        
        public override string ProgramFileName { 
            get { return DetermineFilePath(); }
        }

        /// <summary>
        /// Gets the command line arguments for the external program.
        /// </summary>
        /// <value>
        /// The command line arguments for the external program.
        /// </value>
        public override string ProgramArguments { 
            get { return "@" + "\"" + _responseFileName + "\""; }
        }

        /// <summary>
        /// Starts the external process and captures its output.
        /// </summary>
        protected override void ExecuteTask() {
            // create temp response file to hold compiler options
            _responseFileName = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());

            try {
                using (FileStream fileStream = new FileStream(
                           _responseFileName,
                           FileMode.CreateNew, FileAccess.Write, FileShare.None,
                           4096,
                           FileOptions.None))
                {
                    using (StreamWriter writer = new StreamWriter(fileStream))
                    {
                        writer.WriteLine("/nologo");

                        if (!Verbose)
                        {
                            if (Verbosity != VerbosityLevel.NotSet)
                            {
                                writer.WriteLine("/verbosity:" + Verbosity.ToString().ToLower(CultureInfo.InvariantCulture));
                            }
                        }
                        else
                        {
                            writer.WriteLine("/verbosity:detailed");
                        }

                        foreach (PropertyTask property in Properties)
                        {
                            string val;
                            // expand properties in context of current project for non-dynamic properties
                            if (!property.Dynamic)
                            {
                                val = Project.ExpandProperties(property.Value, Location);
                            }
                            else
                            {
                                val = property.Value;
                            }

                            writer.WriteLine("/property:\"{0}\"=\"{1}\"", property.PropertyName, val);
                        }

                        if (Target != null)
                        {
                            string[] targets = Target.Split(';');
                            for (int i = 0; i < targets.Length; i++)
                            {
                                if (targets[i].IndexOf(" ") >= 0)
                                {
                                    targets[i] = String.Format("\"{0}\"", targets[i]);
                                }
                            }

                            writer.WriteLine("/target:{0}", String.Join(";", targets));
                        }

                        if (NoAutoResponse)
                        {
                            writer.WriteLine("/noautoresponse");
                        }

                        if (ProjectFile != null)
                        {
                            writer.WriteLine("\"{0}\"", ProjectFile.FullName);
                        }

                        Log(Level.Verbose, "Starting MSBuild...");
                    }
                }

                base.ExecuteTask();
            } catch (Exception ex) {
                throw new BuildException("Failed to start MSBuild.", Location, ex);
            } finally {
                // make sure we delete response file even if an exception is thrown
                File.Delete(_responseFileName);
                _responseFileName = null;
            }
        }

        #endregion Override implementation of ExternalProgramBase
        
        #region Private Instance Methods

        private string DetermineFilePath()
        {
            if (PlatformHelper.IsMono) 
            {
                if (ExeName.Equals("msbuild", StringComparison.InvariantCultureIgnoreCase))
                {
                    return ExeName;
                }
            }
            else if (PlatformHelper.IsWindows)
            {
                
            }

            return base.ProgramFileName;
        }

        #endregion
        
        #region MSBuild detection
        #endregion
    }
}
