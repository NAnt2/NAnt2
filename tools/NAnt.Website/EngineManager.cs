﻿using System;
using System.Collections.Generic;
using System.Linq;
using Wyam.Commands;
using Wyam.Common.IO;
using Wyam.Common.Meta;
using Wyam.Common.Tracing;
using Wyam.Configuration;
using Wyam.Configuration.ConfigScript;
using Wyam.Configuration.Preprocessing;
using Wyam.Core.Execution;

namespace Wyam
{
    internal class EngineManager : IDisposable
    {
        private readonly ConfigOptions _configOptions;
        private bool _disposed;

        public Engine Engine { get; }
        public Configurator Configurator { get; }

        public static EngineManager Get(Preprocessor preprocessor, ConfigOptions configOptions)
        {
            try
            {
                return new EngineManager(preprocessor, configOptions);
            }
            catch (Exception ex)
            {
                Trace.Critical("Error while instantiating engine: {0}", ex.Message);
                return null;
            }
        }

        public EngineManager(Preprocessor preprocessor, ConfigOptions configOptions)
        {
            _configOptions = configOptions;
            Engine = new Engine();
            Configurator = new Configurator(Engine, preprocessor);

            // Set no cache if requested
            if (_configOptions.NoCache)
            {
                Engine.Settings[Keys.UseCache] = false;
            }

            // Set folders
            Engine.FileSystem.RootPath = _configOptions.RootPath;
            if (_configOptions.InputPaths?.Count > 0)
            {
                // Clear existing default paths if new ones are set
                // and reverse the inputs so the last one is first to match the semantics of multiple occurrence single options
                Engine.FileSystem.InputPaths.Clear();
                Engine.FileSystem.InputPaths.AddRange(_configOptions.InputPaths.Reverse());
            }
            if (_configOptions.OutputPath != null)
            {
                Engine.FileSystem.OutputPath = _configOptions.OutputPath;
            }
            if (_configOptions.NoClean)
            {
                Engine.Settings[Keys.CleanOutputPath] = false;
            }
            if (_configOptions.Settings != null)
            {
                foreach (KeyValuePair<string, object> item in _configOptions.Settings)
                {
                    Engine.Settings.Add(item);
                }
            }

            // Set NuGet settings
            Configurator.PackageInstaller.UpdatePackages = _configOptions.UpdatePackages;
            Configurator.PackageInstaller.UseLocalPackagesFolder = _configOptions.UseLocalPackages;
            Configurator.PackageInstaller.UseGlobalPackageSources = _configOptions.UseGlobalSources;
            Configurator.PackageInstaller.IgnoreDefaultSources = _configOptions.IgnoreDefaultSources;
            if (_configOptions.PackagesPath != null)
            {
                Configurator.PackageInstaller.PackagesPath = _configOptions.PackagesPath;
            }

            // Metadata
            Configurator.Settings = configOptions.Settings;

            // Script output
            Configurator.OutputScript = _configOptions.OutputScript;

            // Config caching options
            Configurator.NoOutputConfigAssembly = _configOptions.NoOutputConfigAssembly;
            Configurator.IgnoreConfigHash = _configOptions.IgnoreConfigHash;

            // Application input
            Engine.ApplicationInput = _configOptions.Stdin;
        }

        public void Dispose()
        {
            if (_disposed)
            {
                throw new ObjectDisposedException(nameof(EngineManager));
            }
            Configurator.Dispose();
            Engine.Dispose();
            _disposed = true;
        }

        public bool Configure()
        {
            try
            {
                // make sure we clear out anything in the JavaScriptEngineSwitcher instance
                Engine.ResetJsEngines();

                // Make sure the root path exists
                if (!Engine.FileSystem.GetRootDirectory().Exists)
                {
                    throw new InvalidOperationException(
                        $"The root path {Engine.FileSystem.RootPath.FullPath} does not exist.");
                }

                // If we have a configuration file use it, otherwise configure with defaults
                Trace.Information($"Loading configuration from {_configOptions.ConfigFilePath}");
                if (!Configurator.Configure(_configOptions.ConfigFilePath))
                {
                    Trace.Information($"Could not find configuration file at {_configOptions.ConfigFilePath}");
                    Configurator.Configure((string)null);
                }
            }
            catch (ScriptCompilationException)
            {
                // Don't need to show exception message since it was already reported via trace
                Trace.Critical("Error while compiling configuration");
                return false;
            }
            catch (Exception ex)
            {
                Trace.Critical("Error while loading configuration: {0}", ex);
                return false;
            }

            return true;
        }

        public bool Execute()
        {
            try
            {
                Engine.Execute();
            }
            catch (Exception)
            {
                return false;
            }

            return true;
        }
    }
}
