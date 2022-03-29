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
            string buildFragment = @"
                        <project default='A'>
                            <target name='A'>
                                <property name='path1' value='C:\' />
                                <property name='path2' value='Windows' />
                                <property name='path.combine' value='${path::combine(path1, path2)}' />
                            </target>
                        </project>";

            Project project = CreateFilebasedProject(buildFragment);
            ExecuteProject(project);

            // check whether all expected properties exist
            Assert.IsTrue(project.Properties.Contains("path.combine"), "Property \"path.combine\" does not exist.");

            // check values
            Assert.AreEqual(@"C:\Windows", project.Properties["path.combine"], @"C:\Windows");
            System.Console.WriteLine("Test_Combine_2Paths was successful");
        }

        [Test]
        public void Test_Combine_3Paths()
        {
            string buildFragment = @"
                     <project default='A'>
                         <target name='A'>
                             <property name='path1' value='C:\' />
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
            Assert.AreEqual(@"C:\Windows\system32", project.Properties["path.combine"], @"C:\Windows\system32");
        }

        [Test]
        public void Test_Combine_4Paths()
        {
            string buildFragment = @"
             <project default='A'>
                 <target name='A'>
                     <property name='path1' value='C:\' />
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
            Assert.AreEqual(@"C:\Windows\system32\drivers", project.Properties["path.combine"], @"C:\Windows\system32\drivers");
        }

        [Test]
        public void Test_Combine_VariousPaths()
        {
            string buildFragment = @"
                <project default='all'>
                    <target name='all'>
                        <property name='path1' value='C:\' />
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
            Assert.AreEqual(@"C:\Windows", project.Properties["path.combine12"], @"C:\Windows\system32\drivers");
            Assert.AreEqual(@"C:\Windows\system32", project.Properties["path.combine123"], @"C:\Windows\system32\drivers");
            Assert.AreEqual(@"C:\Dev", project.Properties["path.combine124"], @"C:\Windows\system32\drivers");
            Assert.AreEqual(@"C:\Dev\system32", project.Properties["path.combine1243"], @"C:\Windows\system32\drivers");
            Assert.AreEqual(@"C:\Dev", project.Properties["path.combine123a4"], @"C:\Windows\system32\drivers");
        }

        #endregion
    }
}
