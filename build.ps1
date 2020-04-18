<#
    Main build script for NAnt
#>

#Steps:
#   1. detect OS version; use $IsWindows / !$IsWindows
#   2. detect installed versions of .NET framework, Mono, .NET Core
#   3. create 'bootstrap' and 'bootstrap\lib' folder
#   4. copy all from 'lib' to bootstrap\lib
#   5. copy 'lib\common\neutral\log4net' to 'bootstrap'
#   5. copy 'src\NAnt.Console\App.config' to 'bootstrap\NAnt.exe.config'
#   6. run 'csc  -target:exe -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.exe -r:bootstrap\log4net.dll  -r:System.Configuration.dll  -recurse:src\NAnt.Console\*.cs src\CommonAssemblyInfo.cs'
#   7. run 'resgen  src\NAnt.Core\Resources\Strings.resx bootstrap\NAnt.Core.Resources.Strings.resources'
#   8. csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.Core.dll -r:bootstrap\log4net.dll  -r:System.Web.dll -r:System.Configuration.dll -resource:bootstrap\NAnt.Core.Resources.Strings.resources  -recurse:src\NAnt.Core\*.cs src\CommonAssemblyInfo.cs
#   9. resgen.exe  src\NAnt.DotNet\Resources\Strings.resx bootstrap\NAnt.DotNet.Resources.Strings.resources
#   10. 'csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.DotNetTasks.dll  -r:bootstrap\NAnt.Core.dll -r:bootstrap/lib/common/neutral/NDoc.Core.dll  -resource:bootstrap\NAnt.DotNet.Resources.Strings.resources -recurse:src\NAnt.DotNet\*.cs  src\CommonAssemblyInfo.cs'
#   11. 'csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.CompressionTasks.dll  -r:bootstrap\NAnt.Core.dll -r:bootstrap\lib\common\neutral\ICSharpCode.SharpZipLib.dll -recurse:src\NAnt.Compression\*.cs src\CommonAssemblyInfo.cs'
#   12. 'csc  -target:library -warn:0 -define:NET,NET_1_0,NET_1_1,NET_2_0,NET_3_5,NET_4_0,ONLY_4_0 -out:bootstrap\NAnt.Win32Tasks.dll  -r:bootstrap\NAnt.Core.dll -r:bootstrap\NAnt.DotNetTasks.dll -r:System.ServiceProcess.dll  -recurse:src\NAnt.Win32\*.cs  src\CommonAssemblyInfo.cs'
#   13. 'bootstrap\NAnt.exe -j  -t:net-4.0 -f:NAnt.build install -D:prefix="d:\Simona Avornicesei\Projects\nant2\build"  -D:destdir="" -D:doc.prefix=""
