// NAnt - A .NET build tool
// Copyright (C) 2001-2004 Gerry Shaw
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
// Matthew Mastracci (matt@aclaro.com)
// Scott Ford (sford@RJKTECH.com)
// Gert Driesen (gert.driesen@ardatis.com)

using System;
using System.Collections;
using System.Collections.Specialized;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;
using System.Xml;

using Microsoft.Win32;

using NAnt.Core;
using NAnt.Core.Tasks;
using NAnt.Core.Util;
using NAnt.Core.Types;

using NAnt.Win32.Tasks;

namespace NAnt.VSNet {
    public class WrapperReference : FileReferenceBase {
        #region Public Instance Constructors

        public WrapperReference(XmlElement xmlDefinition, ReferencesResolver referencesResolver, ProjectBase parent, GacCache gacCache, ProjectSettings projectSettings) : base(xmlDefinition, referencesResolver, parent, gacCache) {
            if (projectSettings == null) {
                throw new ArgumentNullException("projectSettings");
            }

            _projectSettings = projectSettings;

            // determine name of wrapper reference
            XmlAttribute wrapperNameAttribute = XmlDefinition.Attributes["Name"];
            if (wrapperNameAttribute != null) {
                _name = wrapperNameAttribute.Value;
            }

            // determine wrapper tool
            XmlAttribute toolAttribute = XmlDefinition.Attributes["WrapperTool"];
            if (toolAttribute == null) {
                throw new BuildException("Wrapper tool could not be determined.",
                    Location.UnknownLocation);
            }
            _wrapperTool = toolAttribute.Value;

            // determine if there's a primary interop assembly for the typelib
            _primaryInteropAssembly = GetPrimaryInteropAssembly(
                GetTypeLibVersionKey(XmlDefinition));

            // determine filename of wrapper assembly
            _wrapperAssembly = ResolveWrapperAssembly();
        }

        #endregion Public Instance Constructors

        #region Override implementation of ReferenceBase

        /// <summary>
        /// Gets a value indicating whether the output file(s) of this reference 
        /// should be copied locally.
        /// </summary>
        /// <value>
        /// <see langword="false" /> if the reference wraps a Primary Interop 
        /// Assembly; otherwise, <see langword="true" />.
        /// </value>
        public override bool CopyLocal {
            get { return (WrapperTool != "primary"); }
        }

        /// <summary>
        /// Gets the name of the referenced assembly.
        /// </summary>
        /// <value>
        /// The name of the referenced assembly, or <see langword="null" /> if
        /// the name could not be determined.
        /// </value>
        public override string Name {
            get { return _name; }
        }

        /// <summary>
        /// Gets a value indicating whether this reference represents a system 
        /// assembly.
        /// </summary>
        /// <value>
        /// <see langword="false" /> as none of the system assemblies are wrappers
        /// or Primary Interop Assemblies anyway.
        /// </value>
        protected override bool IsSystem {
            get { return false; }
        }

        /// <summary>
        /// Gets the path of the reference, without taking the "copy local"
        /// setting into consideration.
        /// </summary>
        /// <param name="config">The project configuration.</param>
        /// <returns>
        /// The output path of the reference.
        /// </returns>
        public override string GetPrimaryOutputFile(ConfigurationBase config) {
            return WrapperAssembly;
        }

        /// <summary>
        /// Gets the complete set of output files for the referenced project.
        /// </summary>
        /// <param name="config">The project configuration.</param>
        /// <returns>
        /// The complete set of output files for the referenced project.
        /// </returns>
        /// <remarks>
        /// The key of the case-insensitive <see cref="Hashtable" /> is the 
        /// full path of the output file and the value is the path relative to
        /// the output directory.
        /// </remarks>
        public override Hashtable GetOutputFiles(ConfigurationBase config) {
            return base.GetAssemblyOutputFiles(CreateWrapper(config));
        }

        /// <summary>
        /// Gets the complete set of assemblies that need to be referenced when
        /// a project references this component.
        /// </summary>
        /// <param name="config">The project configuration.</param>
        /// <returns>
        /// The complete set of assemblies that need to be referenced when a 
        /// project references this component.
        /// </returns>
        public override StringCollection GetAssemblyReferences(ConfigurationBase config) {
            // ensure wrapper is actually created
            string assemblyFile = CreateWrapper(config);
            if (!File.Exists(assemblyFile)) {
                throw new BuildException(string.Format(CultureInfo.InvariantCulture,
                    "Couldn't find referenced assembly '{0}'.", assemblyFile), 
                    Location.UnknownLocation);
            }

            // add referenced assembly to list of reference assemblies
            StringCollection assemblyReferences = new StringCollection();
            assemblyReferences.Add(assemblyFile);

            return assemblyReferences;
        }

        /// <summary>
        /// Gets the timestamp of the reference.
        /// </summary>
        /// <param name="config">The build configuration of the reference.</param>
        /// <returns>
        /// The timestamp of the reference.
        /// </returns>
        public override DateTime GetTimestamp(ConfigurationBase config) {
            return GetTimestamp(WrapperAssembly);
        }

        #endregion Override implementation of ReferenceBase

        #region Private Instance Properties

        private ProjectSettings ProjectSettings {
            get { return _projectSettings; }
        }

        private string WrapperTool {
            get { return _wrapperTool; }
        }

        /// <summary>
        /// Gets the path of the wrapper assembly.
        /// </summary>
        /// <value>
        /// The path of the wrapper assembly.
        /// </value>
        /// <remarks>
        /// The wrapper assembly is stored in the object directory of the 
        /// project.
        /// </remarks>
        private string WrapperAssembly {
            get { return _wrapperAssembly; }
        }

        /// <summary>
        /// Gets a value indicating whether the wrapper assembly has already been
        /// created.
        /// </summary>
        private bool IsCreated {
            get { return _isCreated; }
        }

        /// <summary>
        /// Gets the path of the Primary Interop Assembly.
        /// </summary>
        /// <value>
        /// The path of the Primary Interop Assembly, or <see langword="null" />
        /// if not available.
        /// </value>
        private string PrimaryInteropAssembly {
            get { return _primaryInteropAssembly; }
        }

        #endregion Private Instance Properties

        #region Private Instance Methods

        private string CreateWrapper(ConfigurationBase config) {
            // if wrapper assembly was created during the current build, then
            // there's no need to create it again
            if (IsCreated) {
                return WrapperAssembly;
            }

            // synchronize build and output directory
            Sync(config);

            switch (WrapperTool) {
                case "primary":
                    // nothing to do for Primary Interop Assembly
                    break;
                case "tlbimp":
                    if (PrimaryInteropAssembly != null) {
                        // if tlbimp is defined as import tool, but a primary
                        // interop assembly is available, then output a 
                        // warning
                        Log(Level.Warning, "The reference component"
                            + " '{0}' has an updated custom wrapper available.", 
                            Name);
                    }

                    TlbImpTask tlbImp = new TlbImpTask();

                    // parent is solution task
                    tlbImp.Parent = SolutionTask;

                    // inherit project from solution task
                    tlbImp.Project = SolutionTask.Project;

                    // inherit namespace manager from solution task
                    tlbImp.NamespaceManager = SolutionTask.NamespaceManager;

                    // inherit verbose setting from solution task
                    tlbImp.Verbose = SolutionTask.Verbose;

                    // make sure framework specific information is set
                    tlbImp.InitializeTaskConfiguration();

                    tlbImp.TypeLib = new FileInfo(GetTypeLibrary());
                    tlbImp.OutputFile = new FileInfo(WrapperAssembly);
                    tlbImp.Namespace = Name;

                    // according to "COM Programming with Microsoft .NET" (page 59)
                    // the /sysarray option should always be set in order to 
                    // generate wrappers that match those generated by VS.NET
                    tlbImp.SysArray = true;

                    if (ProjectSettings.AssemblyOriginatorKeyFile != null) {
                        tlbImp.KeyFile = new FileInfo(Path.Combine(Parent.ProjectDirectory.FullName, 
                            ProjectSettings.AssemblyOriginatorKeyFile));
                    }

                    // increment indentation level
                    tlbImp.Project.Indent();
                    try {
                        // execute task
                        tlbImp.Execute();
                    } finally {
                        // restore indentation level
                        tlbImp.Project.Unindent();
                    }
                    break;
                case "aximp":
                    AxImpTask axImp = new AxImpTask();

                    // parent is solution task
                    axImp.Parent = SolutionTask;

                    // inherit project from solution task
                    axImp.Project = SolutionTask.Project;

                    // inherit namespace manager from solution task
                    axImp.NamespaceManager = SolutionTask.NamespaceManager;

                    // inherit verbose setting from solution task
                    axImp.Verbose = SolutionTask.Verbose;

                    // make sure framework specific information is set
                    axImp.InitializeTaskConfiguration();

                    axImp.OcxFile = new FileInfo(GetTypeLibrary());
                    axImp.OutputFile = new FileInfo(WrapperAssembly);

                    if (ProjectSettings.AssemblyOriginatorKeyFile != null) {
                        axImp.KeyFile = new FileInfo(Path.Combine(Parent.ProjectDirectory.FullName, 
                            ProjectSettings.AssemblyOriginatorKeyFile));
                    }

                    string rcw = PrimaryInteropAssembly;
                    if (rcw == null) {
                        // if no primary interop assembly is provided for ActiveX control,
                        // trust the fact that VS.NET uses Interop.<name of the tlbimp reference>.dll
                        // for the imported typelibrary
                        rcw = Path.Combine(Parent.ObjectDir.FullName, 
                            "Interop." + Name.Substring(2, Name.Length - 2) 
                            + ".dll");
                    }
                    if (File.Exists(rcw)) {
                        axImp.RcwFile = new FileInfo(rcw);
                    }

                    // increment indentation level
                    axImp.Project.Indent();
                    try {
                        // execute task
                        axImp.Execute();
                    } finally {
                        // restore indentation level
                        axImp.Project.Unindent();
                    }
                    break;
                default:
                    throw new BuildException(string.Format(CultureInfo.InvariantCulture,
                        "Wrapper tool '{0}' is not supported.", WrapperTool),
                        Location.UnknownLocation);
            }

            // mark wrapper as completed
            _isCreated = true;

            return WrapperAssembly;
        }

        private string ResolveWrapperAssembly() {
            string wrapperAssembly = null;

            switch (WrapperTool) {
                case "primary":
                    wrapperAssembly = PrimaryInteropAssembly;
                    if (wrapperAssembly == null) {
                        throw new BuildException(string.Format(CultureInfo.InvariantCulture, 
                            "Couldn't find Primary Interop Assembly '{0}'.", 
                            Name), Location.UnknownLocation);
                    }

                    return wrapperAssembly;
                case "aximp":
                    wrapperAssembly = "AxInterop." + Name.Substring(2, 
                        Name.Length - 2) + ".dll";
                    break;
                default:
                    wrapperAssembly = "Interop." + Name + ".dll";
                    break;
            }

            // resolve to full path
            return Path.Combine(Parent.ObjectDir.FullName,
                wrapperAssembly);
        }

        /// <summary>
        /// Removes wrapper assembly from build directory, if wrapper assembly 
        /// no longer exists in output directory or is not in sync with build 
        /// directory, to force rebuild.
        /// </summary>
        /// <param name="config">The project configuration.</param>
        private void Sync(ConfigurationBase config) {
            if (!CopyLocal || !File.Exists(WrapperAssembly)) {
                // nothing to synchronize
                return;
            }

            // determine path where wrapper assembly should be deployed to
            string outputFile = Path.Combine(config.OutputDir.FullName,
                Path.GetFileName(WrapperAssembly));

            // determine last modification date/time of built wrapper assembly
            DateTime wrapperModTime = File.GetLastWriteTime(WrapperAssembly);

            // rebuild wrapper assembly if output assembly is more recent, 
            // or have been removed (by the user) to force a rebuild
            if (FileSet.FindMoreRecentLastWriteTime(outputFile, wrapperModTime) != null) {
                // remove wrapper assembly to ensure a rebuild is performed
                DeleteTask deleteTask = new DeleteTask();
                deleteTask.Project = SolutionTask.Project;
                deleteTask.Parent = SolutionTask;
                deleteTask.InitializeTaskConfiguration();
                deleteTask.File = new FileInfo(WrapperAssembly);
                deleteTask.Threshold = Level.None; // no output in build log
                deleteTask.Execute();
            }
        }

        private string GetTypeLibVersionKey(XmlElement elemReference) {
            string majorVersion = (int.Parse(elemReference.Attributes["VersionMajor"].Value, 
                CultureInfo.InvariantCulture)).ToString("x", CultureInfo.InvariantCulture);
            string minorVersion = (int.Parse(elemReference.Attributes["VersionMinor"].Value, 
                CultureInfo.InvariantCulture)).ToString("x", CultureInfo.InvariantCulture);

            return string.Format(CultureInfo.InvariantCulture, @"TYPELIB\{0}\{1}.{2}",
                elemReference.Attributes["Guid"].Value, majorVersion, minorVersion);
        }

        private string GetTypeLibKey(XmlElement elemReference, string typeLibVersionKey) {
            string lcid = (int.Parse(elemReference.Attributes["Lcid"].Value, 
                CultureInfo.InvariantCulture)).ToString("x", CultureInfo.InvariantCulture);

            return string.Format(CultureInfo.InvariantCulture, @"{0}\{1}\win32",
                typeLibVersionKey, lcid);
        }

        private string GetPrimaryInteropAssembly(string typeLibVersionKey) {
            string assemblyFile = null;

            using (RegistryKey registryKey = Registry.ClassesRoot.OpenSubKey(typeLibVersionKey)) {
                if (registryKey != null && registryKey.GetValue("PrimaryInteropAssemblyName") != null) {
                    string primaryInteropAssemblyName = (string) registryKey.GetValue("PrimaryInteropAssemblyName");

                    try {
                        // get filename of primary interop assembly
                        assemblyFile = ReferencesResolver.GetAssemblyFileName(
                            primaryInteropAssemblyName);
                    } catch (Exception ex) {
                        throw new BuildException(string.Format(CultureInfo.InvariantCulture,
                            "Primary Interop Assembly '{0}' could not be loaded.", 
                            primaryInteropAssemblyName), Location.UnknownLocation, 
                            ex);
                    }
                }
            }

            return assemblyFile;
        }

        private string GetTypeLibrary() {
            // determine typelib key
            string typeLibKey = GetTypeLibKey(XmlDefinition, 
                GetTypeLibVersionKey(XmlDefinition));

            using (RegistryKey registryKey = Registry.ClassesRoot.OpenSubKey(typeLibKey)) {
                if (registryKey == null) {
                    throw new BuildException(string.Format(CultureInfo.InvariantCulture, 
                        "Couldn't find reference to type library '{0}' ({1}).", 
                        Name, typeLibKey), Location.UnknownLocation);
                }

                string typeLibValue = (string) registryKey.GetValue(null);
                if (StringUtils.IsNullOrEmpty(typeLibValue)) {
                    throw new BuildException(string.Format(CultureInfo.InvariantCulture, 
                        "Couldn't find path of referenced type library '{0}' ({1})."
                        + " Ensure the type library is registered correctly.", 
                        Name, typeLibKey), Location.UnknownLocation);
                }

                // extract path to type library from reg value
				string typeLib = ExtractTypeLibPath(typeLibValue);
				// check if the typelib actually exists
                if (!File.Exists(typeLib)) {
                    throw new BuildException(string.Format(CultureInfo.InvariantCulture, 
                        "Type library '{0}' no longer exists at registered path"
                        + " '{1}'.", Name, typeLib), Location.UnknownLocation);
                }
                return typeLib;
            }
        }

        /// <summary>
        /// Extracts the path of the type library or the file containing the type 
        /// libary.
        /// </summary>
        /// <remarks>
        /// <para>
        /// If the path refers to a DLL, then it is possible that the DLL
        /// contains more than one type library resource.  The number of the 
        /// resource is appended to the Win32 value.
        /// </para>
        /// <para>
        /// We required the path to the DLL without the trailing resource 
        /// identifier.
        /// </para>
        /// </remarks>
        private string ExtractTypeLibPath(string typeLibraryWin32Value) {
            string regex = "([A-Z]:\\\\[^/:\\*\\?<>\\|]+\\.\\w{2,6})|(\\\\{2}[^/:\\*\\?<>\\|]+\\.\\w{2,6})";
            Regex reg = new Regex(regex, RegexOptions.IgnorePatternWhitespace 
                | RegexOptions.Multiline | RegexOptions.IgnoreCase);
            if (reg.IsMatch(typeLibraryWin32Value)) {
                return reg.Match(typeLibraryWin32Value).Value;
            } else {
                return typeLibraryWin32Value;
            }
        }

        #endregion Private Instance Methods

        #region Private Instance Fields

        private bool _isCreated;
        private readonly string _name = string.Empty;
        private readonly string _wrapperTool;
        private readonly string _wrapperAssembly;
        private readonly ProjectSettings _projectSettings;
        private readonly string _primaryInteropAssembly;
        
        #endregion Private Instance Fields
    }
}