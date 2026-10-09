// NAnt - A .NET build tool
// Copyright (C) 2002-2003 Scott Hernandez (ScottHernandez@hotmail.com)
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

// Scott Hernandez (ScottHernandez@hotmail.com)
// Simona Avornicesei (simona@avornicesei.com)

using System;
using NAnt.Core;

using NUnit.Framework;

namespace Tests.NAnt.Core.Tasks {
    [TestFixture]
    public class ScriptTest : BuildTestBase {
        [Test]
        [Category ("NotMono")]
        public void Test_VB() {
            string _xml = @"
            <project>
               <script language='VB'>
                    <code>
                        <![CDATA[
                            Public Shared Sub ScriptMain(p As NAnt.Core.Project)
                                p.Properties(""foo"")=1
                            End Sub
                        ]]>
                    </code>
                </script>
                <echo message='CSFoo=${foo}'/>
            </project>";

            string result = RunBuild(_xml);
            Assert.IsTrue(result.IndexOf("CSFoo=1") != -1, "VB script should have updated prop." + Environment.NewLine + result);
        }

        [Test]
        public void Test_CSharp() {
            string _xml = @"
            <project>
                <script language='C#'>
                    <code>
                        <![CDATA[
                            public static void ScriptMain(Project project) {
                                Console.WriteLine(""Hello"");
                                project.Properties[""from.script""] = ""script.me"";
                            }
                        ]]>
                    </code>
                </script>
                <echo message='hi from ${from.script}'/>
            </project>";

            string result = RunBuild(_xml);
            Assert.IsTrue(result.IndexOf("Hello") != -1, "CSharp script should written something." + Environment.NewLine + result);
            Assert.IsTrue(result.IndexOf("script.me") != -1, "CSharp script should have updated prop." + Environment.NewLine + result);
        }

        /// <summary>
        /// Ensures the langversion attribute is passed on to the compiler that
        /// backs the code provider.
        /// </summary>
        [Test]
        public void Test_CSharp_LangVersion() {
            // generics are not part of the C# 1.0 language specification, so
            // restricting the compiler to that specification should cause the
            // build to fail
            string _xml = @"
            <project>
                <script language='C#' langversion='ISO-1'>
                    <code>
                        <![CDATA[
                            public static void ScriptMain(Project project) {
                                System.Collections.Generic.List<string> messages =
                                    new System.Collections.Generic.List<string>();
                                messages.Add(""generics"");
                                project.Properties[""from.script""] = messages[0];
                            }
                        ]]>
                    </code>
                </script>
            </project>";

            try {
                RunBuild(_xml);
                Assert.Fail("Script using C# 2.0 features should not have"
                    + " compiled when the compiler is restricted to the C# 1.0"
                    + " language specification.");
            } catch (TestBuildException ex) {
                Assert.IsTrue(ex.ToString().IndexOf("CS1644") != -1,
                    "Compiler should have reported that a language feature is"
                    + " not available." + Environment.NewLine + ex);
            }
        }

        /// <summary>
        /// Ensures the compileroptions attribute is passed on to the compiler
        /// that backs the code provider.
        /// </summary>
        [Test]
        public void Test_CSharp_CompilerOptions() {
            string _xml = @"
            <project>
                <script language='C#' compileroptions='/define:SCRIPT_PROBE'>
                    <code>
                        <![CDATA[
                            public static void ScriptMain(Project project) {
                            #if SCRIPT_PROBE
                                project.Properties[""from.script""] = ""options.passed"";
                            #else
                                project.Properties[""from.script""] = ""options.dropped"";
                            #endif
                            }
                        ]]>
                    </code>
                </script>
                <echo message='result=${from.script}'/>
            </project>";

            string result = RunBuild(_xml);
            Assert.IsTrue(result.IndexOf("result=options.passed") != -1,
                "compileroptions should have been passed on to the compiler."
                + Environment.NewLine + result);
        }
        
        /// <summary>
        /// Test for bug #1187957.
        /// </summary>
        [Test]
        public void Test_Tasks() {
            const string _xml = @"
                <project name=""customtasks"">
                    <script language=""c#"">
                        <code><![CDATA[
                            [TaskName(""testtask1"")]
                            public class TestTask1: Task
                            {
                                protected override void ExecuteTask()
                                {
                                    Log(Level.Info, ""Message from testtask1."");
                                }
                            }
                        ]]></code>
                    </script>

                    <script language=""c#"">
                        <code><![CDATA[
                            [TaskName(""testtask2"")]
                            public class TestTask2: Task
                            {
                                protected override void ExecuteTask()
                                {
                                    Log(Level.Info, ""Message from testtask2."");
                                }
                            }
                        ]]></code>
                    </script>

                    <testtask1 />
                    <testtask2 />
                </project>";
            //RunBuild(_xml);
            
            Assert.DoesNotThrow(() => RunBuild(_xml), "Script with tasks should run");
        }

        [Test]
        public void Test_Functions() {
            string _xml = @"
                <project>
                    <script language='C#'>
                        <code>
                        <![CDATA[
                                [Function(""test-func"")]
                                public static string Testfunc() {
                                    return ""some result!!!!!!!!"";
                                }
                            ]]>
                        </code>
                    </script>
                    <script language='C#' prefix='whatever'>
                        <code>
                        <![CDATA[
                                [Function(""test"")]
                                public static string Testfunc() {
                                    return ""some other result!!!!!!!!"";
                                }
                            ]]>
                        </code>
                    </script>
                    <echo message='${script::test-func()}'/>
                    <echo message='${whatever::test()}'/>
                </project>";
            Project project = CreateFilebasedProject(_xml);
            string result = ExecuteProject(project);
            Assert.IsTrue(result.IndexOf("some result") != -1,
                "Function script should written something #1." + Environment.NewLine + result);
            Assert.IsTrue(result.IndexOf("some other result") != -1,
                "Function script should written something #2." + Environment.NewLine + result);
        }

        [Test]
        public void NamespaceImports () {
            string xml = @"
                <project>
                    <script language='C#'>
                        <imports>
                            <import namespace='System.Xml.Schema' />
                        </imports>
                        <references>
                            <include name='System.Xml.dll' />
                        </references>
                        <code>
                            <![CDATA[
                                public static void ScriptMain(Project project) {
                                    // ensure System.Collections namespace is imported
                                    ArrayList list = new ArrayList ();
                                    if (list == null) {
                                        // avoid compiler warning
                                    }

                                    // ensure System.IO namespace is imported
                                    MemoryStream ms = new MemoryStream ();
                                    if (ms == null) {
                                        // avoid compiler warning
                                    }

                                    // ensure System.Text namespace is imported
                                    StringBuilder sb = new StringBuilder ();
                                    if (sb == null) {
                                        // avoid compiler warning
                                    }

                                    XmlSchemaType stype = new XmlSchemaType ();
                                    project.Properties[""schema.type""] = stype.GetType ().FullName;
                                }
                            ]]>
                        </code>
                    </script>
                    <fail unless=""${schema.type=='System.Xml.Schema.XmlSchemaType'}"" />
                </project>";

            //RunBuild(xml);
            Assert.DoesNotThrow(() => RunBuild(xml), "Script with namespace imports should run");
        }

        [Test]
        public void Test_2ScriptsInOneProject() {
            string _xml = @"
            <project>
                <script language='C#'>
                    <code>
                        <![CDATA[
                            public static void ScriptMain(Project project) {
                                int v = 1;
                                int p = 1;
                                v += p;
                                //do nothing.
                            }
                        ]]>
                    </code>
                </script>
                <script language='C#'>
                    <code>
                        <![CDATA[
                            public static void ScriptMain(Project project) {
                                int v = 1;
                                int p = 1;
                                v += p;
                                //do nothing.
                            }
                        ]]>
                    </code>
                </script>
            </project>";

            //RunBuild(_xml);
            Assert.DoesNotThrow(() => RunBuild(_xml), "Script with ScriptMain should run");
        }
        
        /// <summary>
        /// Test for bug #1187957.
        /// </summary>
        [Test]
        public void Test_GH_53() {
            const string _xml = @"<?xml version=""1.0""?>
                <project xmlns=""http://nant.sf.net/release/0.92/nant.xsd"">
                <script language=""C#"" prefix=""timski"">
                <code />
                </script>
                </project>";
            //RunBuild(_xml);
            
            Assert.DoesNotThrow(() => RunBuild(_xml), "Script for GH-53 should run");
        }
    }
}
