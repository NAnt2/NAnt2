using System.IO;
using NUnit.Framework;
using NAnt.Core;

namespace Tests.NAnt.Core.Functions
{
    [TestFixture]
    public class PathFunctionsTest : BuildTestBase
    {
        #region Public Instance Methods

        [Test]
        public void Test_Combine_2Paths()
        {
            string expectedPath = Path.Combine("C:", "Windows");
            string buildFragment = @"
                        <project default='A'>
                            <target name='A'>
                                <property name='path1' value='C:' />
                                <property name='path2' value='Windows' />
                                <property name='path.combine' value='${path::combine(path1, path2)}' />
                            </target>
                        </project>";

            Project project = CreateFilebasedProject(buildFragment);
            ExecuteProject(project);

            // check whether all expected properties exist
            Assert.IsTrue(project.Properties.Contains("path.combine"), "Property \"path.combine\" does not exist.");

            // check values
            Assert.AreEqual(expectedPath, project.Properties["path.combine"], expectedPath);
            System.Console.WriteLine("Test_Combine_2Paths was successful");
        }

        [Test]
        public void Test_Combine_3Paths()
        {
            string expectedPath = Path.Combine(Path.Combine("C:", "Windows"), "system32");
            string buildFragment = @"
                     <project default='A'>
                         <target name='A'>
                             <property name='path1' value='C:' />
                             <property name='path2' value='Windows' />
                             <property name='path3' value='system32' />
                             <property name='path.combine' value='${path::combine(path1, path2, path3)}' />
                         </target>
                     </project>";

            Project project = CreateFilebasedProject(buildFragment);
            ExecuteProject(project);

            // check whether all expected properties exist
            Assert.IsTrue(project.Properties.Contains("path.combine"), "Property \"path.combine\" does not exist.");

            // check values
            Assert.AreEqual(expectedPath, project.Properties["path.combine"], expectedPath);
        }

        [Test]
        public void Test_Combine_4Paths()
        {
            string expectedPath = Path.Combine(Path.Combine(Path.Combine("C:", "Windows"), "system32"), "drivers");
            string buildFragment = @"
             <project default='A'>
                 <target name='A'>
                     <property name='path1' value='C:' />
                     <property name='path2' value='Windows' />
                     <property name='path3' value='system32' />
                     <property name='path4' value='drivers' />
                     <property name='path.combine' value='${path::combine(path1, path2, path3, path4)}' />
                 </target>
             </project>";

            Project project = CreateFilebasedProject(buildFragment);
            ExecuteProject(project);

            // check whether all expected properties exist
            Assert.IsTrue(project.Properties.Contains("path.combine"), "Property \"path.combine\" does not exist.");

            // check values
            Assert.AreEqual(expectedPath, project.Properties["path.combine"], expectedPath);
        }

        [Test]
        public void Test_Combine_VariousPaths()
        {
            string expectedPath12 = Path.Combine("C:", "Windows");
            string expectedPath123 = Path.Combine(Path.Combine("C:", "Windows"), "system32");
            string expectedPath124 = Path.Combine(Path.Combine("C:", "Windows"), @"C:\Dev");
            string expectedPath1243 = Path.Combine(Path.Combine(Path.Combine("C:", "Windows"), @"C:\Dev"), "system32");
            string expectedPath123a4 = Path.Combine(Path.Combine(Path.Combine("C:", "Windows"), @"D:\Dev"), @"C:\Dev");
            string buildFragment = @"
                <project default='all'>
                    <target name='all'>
                        <property name='path1' value='C:' />
                        <property name='path2' value='Windows' />
                        <property name='path3' value='system32' />
                        <property name='path3a' value='D:\Dev' />
                        <property name='path4' value='C:\Dev' />                

                        <property name='path.combine12' value='${path::combine(path1, path2)}' />
                        <property name='path.combine123' value='${path::combine(path1, path2, path3)}' />
                        <property name='path.combine124' value='${path::combine(path1, path2, path4)}' />
                        <property name='path.combine1243' value='${path::combine(path1, path2, path4, path3)}' />
                        <property name='path.combine123a4' value='${path::combine(path1, path2, path3a, path4)}' />

                        <echo>${ path.combine12}</echo>
                        <echo>${ path.combine123}</echo>
                        <echo>${ path.combine124}</echo>
                        <echo>${ path.combine1243}</echo>
                        <echo>${ path.combine123a4}</echo>                         
                    </target>
                </project>";

            Project project = CreateFilebasedProject(buildFragment);
            ExecuteProject(project);

            // check whether all expected properties exist
            Assert.IsTrue(project.Properties.Contains("path.combine12"), "Property \"path.combine12\" does not exist.");
            Assert.IsTrue(project.Properties.Contains("path.combine123"), "Property \"path.combine123\" does not exist.");
            Assert.IsTrue(project.Properties.Contains("path.combine124"), "Property \"path.combine124\" does not exist.");
            Assert.IsTrue(project.Properties.Contains("path.combine1243"), "Property \"path.combine1243\" does not exist.");
            Assert.IsTrue(project.Properties.Contains("path.combine123a4"), "Property \"path.combine123a4\" does not exist.");

            // check values
            Assert.AreEqual(expectedPath12, project.Properties["path.combine12"], expectedPath12);
            Assert.AreEqual(expectedPath123, project.Properties["path.combine123"], expectedPath123);
            Assert.AreEqual(expectedPath124, project.Properties["path.combine124"], expectedPath124);
            Assert.AreEqual(expectedPath1243, project.Properties["path.combine1243"], expectedPath1243);
            Assert.AreEqual(expectedPath123a4, project.Properties["path.combine123a4"], expectedPath123a4);
        }

        #endregion
    }
}
