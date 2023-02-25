// NAnt - A .NET build tool
// Copyright (C) 2002 Ryan Boggs
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
// Ryan Boggs (rmboggs@users.sourceforge.net)
// Simona Avornicesei (simona@avornicesei.com)

using Microsoft.Win32;
using NAnt.Core;
using NAnt.Core.Attributes;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text.RegularExpressions;
using System.Xml;

namespace NAnt.Win32.Tasks
{
    /// <summary>
    /// Reads the most recent Windows SDK InstallationFolder key into a NAnt property
    /// </summary>
    /// <example>
    ///   <code>
    ///     <![CDATA[
    /// <locatesdk property="dotNetFX" minsdk="v6.0" />
    ///     ]]>
    ///   </code>
    /// </example>
    [TaskName("locatesdk")]
    internal class LocateSdkTask : Task
    {
        #region Private Instance Fields

        private string _propName;
        private string _minWinSdkVer = "v6.0";
        private string _maxWinSdkVer;
        private string _minNetFxVer = "2.0";
        private string _maxNetFxVer;
        private readonly string _registryBase = @"SOFTWARE\Microsoft\Microsoft SDKs\Windows";
        private readonly string _registryBaseWow6432 = @"SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows";
        private readonly string _registryNDP = @"SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full";
        private readonly string _registryNetFxSdk = @"SOFTWARE\WOW6432Node\Microsoft\Microsoft SDKs\NETFXSDK";
        private readonly string _regexNetFxTools = @"^WinSDK.*NetFx.*Tools.*$";

        #endregion Private Instance Fields

        #region Public Instance Properties

        /// <summary>
        ///     <para>
        ///     The property to set to the value stored in the InstalledFolder key of the located WinSDK version.
        ///     </para>
        /// </summary>
        [TaskAttribute("property", Required = true)]
        [StringValidator(AllowEmpty = false)]
        public virtual string PropertyName
        {
            get { return _propName; }
            set { _propName = value; }
        }

        /// <summary>
        ///     <para>
        ///     The minimum acceptable Windows SDK version.
        ///     </para>
        /// </summary>
        [TaskAttribute("minwinsdkver")]
        public string MinWinSdkVersion
        {
            get { return _minWinSdkVer; }
            set { _minWinSdkVer = value; }
        }

        /// <summary>
        ///     <para>
        ///     The maximum acceptable Windows SDK version.
        ///     </para>
        /// </summary>
        [TaskAttribute("maxwinsdkver")]
        public string MaxWinSdkVersion
        {
            get { return _maxWinSdkVer; }
            set { _maxWinSdkVer = value; }
        }

        /// <summary>
        ///     <para>
        ///     The minimum acceptable .NET sdk version.
        ///     </para>
        /// </summary>
        [TaskAttribute("minnetfxver")]
        public string MinNetFxVersion
        {
            get { return _minNetFxVer; }
            set { _minNetFxVer = value; }
        }

        /// <summary>
        ///     <para>
        ///     The maximum acceptable .NET sdk version.
        ///     </para>
        /// </summary>
        [TaskAttribute("maxnetfxver")]
        public string MaxNetFxVersion
        {
            get { return _maxNetFxVer; }
            set { _maxNetFxVer = value; }
        }

        #endregion Public Instance Properties

        #region Override implementation of Task

        /// <summary>
        /// locate the most recent WinSDK installed
        /// </summary>
        protected override void ExecuteTask()
        {
            // Initialize all necessary Version objects
            // These will hold the min, max, and loop WinSDK versions found
            Version minSdkVersion = StringToVersion(_minWinSdkVer);
            Version maxSdkVersion = StringToVersion(_maxWinSdkVer);

            // These will hold the min, max, and loop .NET versions found
            Version minNetVersion = StringToVersion(_minNetFxVer);
            Version maxNetVersion = StringToVersion(_maxNetFxVer);

            // Bool variable used to indicate that a valid SDK was found
            bool sdkFound = false;

            bool is64BitProcess = IntPtr.Size == 8;

            // Get all of the WinSDK version keys from the user's registry and
            // load them into a string list. In 64 bit process, consider 32 bit
            // registry subkey as well
            List<string> installedWinSdkVersions = new List<string>();
            RegistryKey sdkRegSubKey = Registry.LocalMachine.OpenSubKey(_registryBase, false);
            if (sdkRegSubKey != null)
            {
                installedWinSdkVersions.AddRange(sdkRegSubKey.GetSubKeyNames());
            }
            RegistryKey sdkRegSubKey_x86 = null;

            if (is64BitProcess)
            {
                sdkRegSubKey_x86 = Registry.LocalMachine.OpenSubKey(_registryBaseWow6432, false);
                if (sdkRegSubKey_x86 != null)
                {
                    foreach (string installedWinSdkVersionX86 in sdkRegSubKey_x86.GetSubKeyNames())
                    {
                        if (!installedWinSdkVersions.Contains(installedWinSdkVersionX86))
                        {
                            installedWinSdkVersions.Add(installedWinSdkVersionX86);
                        }
                    }
                }
            }

            // Sort and reverse the WinSDK version key array to make sure that
            // the latest version is reviewed first before reviewing earlier versions.
            // Default Sort does not work properly if v10.0 SDK is installed so they need to be compared as Version objects
            installedWinSdkVersions.Sort(delegate (string sdk1, string sdk2)
            {
                if (string.IsNullOrEmpty(sdk1) && string.IsNullOrEmpty(sdk2)) return 0;
                if (string.IsNullOrEmpty(sdk1)) return -1;
                if (string.IsNullOrEmpty(sdk2)) return 1;

                Version sdk1Version = StringToVersion(sdk1);
                Version sdk2Version = StringToVersion(sdk2);
                return sdk1Version.CompareTo(sdk2Version);
            });
            installedWinSdkVersions.Reverse();

            // Loop through all of the WinSDK version keys.
            for (int i = 0; i < installedWinSdkVersions.Count; i++)
            {
                Version loopSdkVersion = StringToVersion(installedWinSdkVersions[i]);

                // If a maxVersion was indicated and the loopVersion is greater than
                // the maxVersion, skip to the next item in the installedVersion array.
                if (maxSdkVersion != null)
                {
                    if (loopSdkVersion > maxSdkVersion)
                    {
                        continue;
                    }
                }

                // If the loopVersion is greater than or equal to the minVersion, loop through the subkeys
                // for a valid .NET sdk path
                if (minSdkVersion <= loopSdkVersion)
                {
                    List<string> installedWinSdkSubKeys = new List<string>();
                    RegistryKey sdkVerRegSubKey = null;
                    RegistryKey sdkVerRegSubKey_x86 = null;

                    //If SDK v10 is installed then it has no subkeys and the NETFXSDK key must be checked 
                    //based on the .NET version installed
                    //see https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed
                    if (loopSdkVersion.Major >= 10)
                    {
                        using (RegistryKey ndpKey = Registry.LocalMachine.OpenSubKey(_registryNDP, false))
                        {
                            //this is an improbable case since SDK v10 means Windows 10 which comes with .NET 4.5 out of the box
                            if (ndpKey == null || ndpKey.GetValue("Release") == null) continue;
                            int release = (int)ndpKey.GetValue("Release");
                            string version = string.Empty;
                            if (release >= 528040)
                                version = "4.8";
                            else if (release >= 461808)
                                version = "4.7.2";
                            else if (release >= 461308)
                                version = "4.7.1";
                            else if (release >= 460798)
                                version = "4.7";
                            else if (release >= 394802)
                                version = "4.6.2";
                            else if (release >= 394254)
                                version = "4.6.1";
                            else if (release >= 393295)
                                version = "4.6";
                            else if (release >= 379893)
                                version = "4.5.2";
                            else if (release >= 378675)
                                version = "4.5.1";
                            else if (release >= 378389)
                                version = "4.5";

                            string key = _registryNetFxSdk + @"\" + version;
                            sdkVerRegSubKey_x86 = Registry.LocalMachine.OpenSubKey(key, false);
                        }
                    }
                    else
                    {
                        sdkVerRegSubKey = sdkRegSubKey.OpenSubKey(installedWinSdkVersions[i]);
                        // Gets all of the current WinSdk loop subkeys
                        if (sdkVerRegSubKey != null)
                        {
                            installedWinSdkSubKeys.AddRange(sdkVerRegSubKey.GetSubKeyNames());
                        }
                        if (sdkRegSubKey_x86 != null)
                        {
                            sdkVerRegSubKey_x86 = sdkRegSubKey_x86.OpenSubKey(installedWinSdkVersions[i]);
                        }
                    }

                    if (sdkVerRegSubKey_x86 != null)
                    {
                        foreach (string installedWinSdkSubKey in sdkVerRegSubKey_x86.GetSubKeyNames())
                        {
                            if (!installedWinSdkSubKeys.Contains(installedWinSdkSubKey))
                            {
                                installedWinSdkSubKeys.Add(installedWinSdkSubKey);
                            }
                        }
                    }

                    // Sort and reverse the order of the subkeys to go from greatest to least
                    installedWinSdkSubKeys.Sort();
                    installedWinSdkSubKeys.Reverse();

                    // Loop through all of the current WinSdk loop subkeys
                    for (int j = 0; j < installedWinSdkSubKeys.Count; j++)
                    {
                        // Check to see if the current subkey matches the RegEx string
                        if (!Regex.IsMatch(installedWinSdkSubKeys[j], _regexNetFxTools)) continue;

                        // Initialize the necessary string array to hold all 
                        // possible directory locations
                        // From Wow6432Node last so that value for 64 bit registry is used first
                        List<string> netFxDirs = new List<string>();

                        if (sdkVerRegSubKey != null)
                        {
                            RegistryKey winSdkRegKey = sdkVerRegSubKey.OpenSubKey(installedWinSdkSubKeys[j]);
                            if (winSdkRegKey != null)
                            {
                                string installDir = winSdkRegKey.GetValue("InstallationFolder").ToString();
                                netFxDirs.Add(installDir);
                                netFxDirs.Add(Path.Combine(installDir, "bin"));
                            }
                        }
                        if (sdkVerRegSubKey_x86 != null)
                        {
                            RegistryKey winSdkRegKey = sdkVerRegSubKey_x86.OpenSubKey(installedWinSdkSubKeys[j]);
                            if (winSdkRegKey != null)
                            {
                                string installDir = winSdkRegKey.GetValue("InstallationFolder").ToString();
                                netFxDirs.Add(installDir);
                                netFxDirs.Add(Path.Combine(installDir, "bin"));
                            }
                        }

                        // Loop through all of the directories in the possible directory
                        // locations array
                        foreach (string netFxDir in netFxDirs)
                        {
                            // Set the full path to the gacutil.exe.config file based on the current
                            // directory in the directories array
                            string netFxXmlFile = Path.Combine(netFxDir, "gacutil.exe.config");

                            if (!File.Exists(netFxXmlFile)) continue;

                            // If the full file path exists, load the gacutil.exe.config xml file
                            XmlDocument gacXmlDoc = new XmlDocument();
#if NET451_OR_LESSER
                            gacXmlDoc.XmlResolver = null;
#endif
                            gacXmlDoc.Load(netFxXmlFile);

                            // Get the supported runtime version from the version attribute
                            // and load it into the loopNetVersion Version object to use for
                            // comparisons
                            XmlNode gacVersion = gacXmlDoc.SelectSingleNode("/configuration/startup/requiredRuntime");
                            XmlAttribute versionAttribute = gacVersion.Attributes["version"];
                            Version loopNetVersion = StringToVersion(versionAttribute.Value);

                            // If the maxNetVersion object is not null and is less than
                            // the loopNetVersion, continue to the next iteration of the 
                            // inner loop
                            if (maxNetVersion != null && loopNetVersion > maxNetVersion) continue;

                            // If loopNetVersion is greater than or equal to minNetVersion
                            // assign the value of the InstallationFolder key of the current subfolder
                            // to the property name and exit the inner loop
                            if (minNetVersion > loopNetVersion) continue;
                            Properties[_propName] = netFxDir;
                            sdkFound = true;
                            break;
                        }
                    }

                    // If a valid Sdk version was found within the current Sdk subkeys, break
                    // the outer loop.
                    if (sdkFound)
                    {
                        break;
                    }
                }
            }

            // if the Properties dictionary does not contain the _propName as a key, throw an error.
            if (!sdkFound)
            {
                throw new BuildException(string.Format(CultureInfo.InvariantCulture, "System does not have minimum specified Windows SDK {0}!", _minWinSdkVer));
            }

            Log(Level.Debug, "Using NETFX SDK: {0}", Properties[_propName]);
        }

        #endregion Override implementation of Task

        #region Private Instance Methods

        /// <summary>
        /// Converts a version expressed as a string into a Version object 
        /// </summary>
        /// <param name="sdkVersion">
        /// A <see cref="T:System.String"/> containing the version to convert.
        /// </param>
        /// <returns>
        /// A <see cref="Version"/> object representing the version string.
        /// </returns>
        private Version StringToVersion(string sdkVersion)
        {
            // If the sdkVersion parameter is null or empty, return null
            if (string.IsNullOrEmpty(sdkVersion)) return null;

            // Make any non-numeric characters uppercase
            sdkVersion = sdkVersion.Trim().ToUpper();

            // Remove the leading v from the sdkVersion string
            if (sdkVersion.StartsWith("V"))
            {
                sdkVersion = sdkVersion.Substring(1);
            }

            // Return a new Version object based on the sdkVersion string
            // If the sdkVersion string ends with an alphanumeric, it is
            // converted to a revision number for comparison purposes
            if (char.IsNumber(sdkVersion, sdkVersion.Length - 1))
            {
                return new Version(sdkVersion);
            }

            string sdkVerFormat = sdkVersion.Substring(0, sdkVersion.Length - 1) + "." +
                                  ((int)sdkVersion.ToCharArray()[sdkVersion.Length - 1]);
            return new Version(sdkVerFormat);
        }

        #endregion Private Instance Methods
    }
}
