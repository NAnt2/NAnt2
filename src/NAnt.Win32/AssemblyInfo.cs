using System.Reflection;
using System.Security.Permissions;

[assembly: AssemblyTitleAttribute("NAnt.Win32Tasks")]
[assembly: AssemblyDescriptionAttribute("")]

#if (!NET_4_0)
[assembly: RegistryPermissionAttribute(SecurityAction.RequestMinimum , Unrestricted=true)]
#endif