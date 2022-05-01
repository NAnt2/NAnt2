using System.Reflection;
using System.Security.Permissions;

[assembly: AssemblyTitleAttribute("NAnt.Win32Tasks")]
[assembly: AssemblyDescriptionAttribute("")]

#if (!NET40_OR_GREATER)
[assembly: RegistryPermissionAttribute(SecurityAction.RequestMinimum , Unrestricted=true)]
#endif