using System.ComponentModel;

namespace NAnt.Contrib.Tasks.MSBuild
{
    /// <summary>
    /// 
    /// </summary>
    [TypeConverter(typeof (EnumGenericConverter<VerbosityLevel>))]
    public enum VerbosityLevel {
        NotSet, 
        Quiet,
        Minimal,
        Normal,
        Detailed,
        Diagnostic
    }
}