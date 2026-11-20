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

using System.IO;

using NUnit.Framework;
using Tests.NAnt.Core;

namespace Tests.NAnt.Win32.Tasks {
    /// <summary>
    /// Tests the LocateVisualStudioTask, standing a batch file in for vswhere.
    /// </summary>
    [TestFixture]
    [Platform(Exclude="Unix,Linux,MacOsX,XBox")]
    public class LocateVisualStudioTest : BuildTestBase {
        private const string ProjectXml = @"
            <project name=""LocateVisualStudio"">
                <locatevisualstudio property=""vs"" vswhere=""%VSWHERE%"" %ATTRIBUTES% />
                <echo message=""exists=${property::exists('vs')};"" />
                <echo message=""vs=${vs};"" if=""${property::exists('vs')}"" />
            </project>";

        [Test]
        public void Test_SetsPropertyToInstallationPath() {
            string result = RunLocate("@echo C:\\VS\\2022\\BuildTools", string.Empty);

            StringAssert.Contains("vs=C:\\VS\\2022\\BuildTools;", result);
        }

        [Test]
        public void Test_IncludesBuildToolsAndRequiresMSBuild() {
            // the batch file echoes its arguments back as the installation path
            string result = RunLocate("@echo %*", string.Empty);

            StringAssert.Contains("-latest", result);
            StringAssert.Contains("-products *", result);
            StringAssert.Contains("-requires Microsoft.Component.MSBuild", result);
            StringAssert.Contains("-property installationPath", result);
        }

        [Test]
        public void Test_PassesRequiredComponents() {
            string result = RunLocate("@echo %*",
                "requires='Microsoft.VisualStudio.Component.VC.Tools.x86.x64'");

            StringAssert.Contains("-requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64", result);
        }

        [Test]
        public void Test_EmptyRequiresAcceptsAnyInstallation() {
            string result = RunLocate("@echo %*", "requires=''");

            StringAssert.DoesNotContain("-requires", result);
        }

        [Test]
        public void Test_NoInstallationLeavesPropertyUnset() {
            string result = RunLocate("@rem no matching installation", string.Empty);

            StringAssert.Contains("exists=False;", result);
        }

        [Test]
        public void Test_MissingVsWhereLeavesPropertyUnset() {
            string xml = ProjectXml
                .Replace("%VSWHERE%", Path.Combine(TempDirName, "missing-vswhere.exe"))
                .Replace("%ATTRIBUTES%", string.Empty);

            string result = RunBuild(xml);

            StringAssert.Contains("exists=False;", result);
        }

        [Test]
        public void Test_VsWhereFailureFailsTheBuild() {
            try {
                RunLocate("@echo invalid argument 1>&2\r\n@exit /b 87", string.Empty);
                Assert.Fail("A failing vswhere did not fail the build.");
            } catch (TestBuildException ex) {
                StringAssert.Contains("exited with code 87", ex.ToString());
            }
        }

        [Test]
        public void Test_VsWhereFailureIgnoredWhenNotFailOnError() {
            string result = RunLocate("@exit /b 87", "failonerror='false'");

            StringAssert.Contains("exists=False;", result);
        }

        private string RunLocate(string vsWhereScript, string attributes) {
            string vsWhere = CreateTempFile("vswhere.cmd", vsWhereScript);
            string xml = ProjectXml
                .Replace("%VSWHERE%", vsWhere)
                .Replace("%ATTRIBUTES%", attributes);
            return RunBuild(xml);
        }
    }
}
