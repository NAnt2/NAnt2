using System.ComponentModel;

namespace NAnt.Contrib.Tasks.MSBuild
{
    /// <summary>
    /// 
    /// </summary>
    [TypeConverter(typeof (EnumGenericConverter<MSBuildVersion>))]
    public enum MSBuildVersion 
    {
        /// <summary>
        /// Auto-detect MSBuild version to use.
        /// </summary>
        Auto,
            
        /// <summary>
        /// MSBuild v4.0
        /// </summary>
        v4,
            
        /// <summary>
        /// MSBuild v12.0
        /// </summary>
        v12,
            
        /// <summary>
        /// MSBuild v14.0
        /// </summary>
        v14,
            
        /// <summary>
        /// MSBuild v15.0
        /// </summary>
        v15,
            
        /// <summary>
        /// MSBuild v16.0
        /// </summary>
        v16,
            
        /// <summary>
        /// MSBuild v17.0
        /// </summary>
        v17
    }
}