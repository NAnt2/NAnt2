using System;
using System.ComponentModel;
using System.Globalization;

namespace NAnt.Contrib.Tasks.MSBuild
{
    /// <summary>
    /// Provides a generic type converter to convert Enum objects to and from various other representations.
    /// </summary>
    /// <typeparam name="T">Type of the enumeration.</typeparam>
    public sealed class EnumGenericConverter<T> : EnumConverter
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="EnumGenericConverter{T}" />.
        /// class.
        /// </summary>
        public EnumGenericConverter() : base(typeof(T))
        {
        }

        /// <summary>
        /// Converts the given object to the type of this converter, using the 
        /// specified context and culture information.
        /// </summary>
        /// <param name="context">An <see cref="ITypeDescriptorContext"/> that provides a format context.</param>
        /// <param name="culture">A <see cref="CultureInfo"/> object. If a <see langword="null"/> is passed, the current culture is assumed.</param>
        /// <param name="value">The <see cref="object"/> to convert.</param>
        /// <returns>
        /// An <see cref="object"/> that represents the converted value.
        /// </returns>
        public override object ConvertFrom(ITypeDescriptorContext context, CultureInfo culture, object value)
        {
            return value is string stringValue
                ? Enum.Parse(typeof(T), stringValue, true)
                : base.ConvertFrom(context, culture, value); // default to EnumConverter behavior
        }
    }
}