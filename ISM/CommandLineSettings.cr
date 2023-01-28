module ISM

    class CommandLineSettings

        record Settings,
            rootPath : String,
            systemName : String,
            targetName : String,
            architecture : String,
            target : String,
            makeOptions : String,
            buildOptions : String,
            installByChroot : Bool,
            chrootSystemName : String,
            chrootTargetName : String,
            chrootArchitecture : String,
            chrootTarget : String,
            chrootMakeOptions : String,
            chrootBuildOptions : String do
            include JSON::Serializable
        end

        property    rootPath : String
        property    installByChroot : Bool
        property    chrootSystemName : String
        property    chrootTargetName : String
        property    chrootArchitecture : String
        property    chrootTarget : String
        property    chrootMakeOptions : String
        property    chrootBuildOptions : String

        def initialize( @rootPath = ISM::Default::CommandLineSettings::RootPath,
                        @systemName = ISM::Default::CommandLineSettings::SystemName,
                        @targetName = ISM::Default::CommandLineSettings::TargetName,
                        @architecture = ISM::Default::CommandLineSettings::Architecture,
                        @target = ISM::Default::CommandLineSettings::Target,
                        @makeOptions = ISM::Default::CommandLineSettings::MakeOptions,
                        @buildOptions = ISM::Default::CommandLineSettings::BuildOptions,
                        @installByChroot = ISM::Default::CommandLineSettings::InstallByChroot,
                        @chrootSystemName = ISM::Default::CommandLineSettings::ChrootSystemName,
                        @chrootTargetName = ISM::Default::CommandLineSettings::ChrootTargetName,
                        @chrootArchitecture = ISM::Default::CommandLineSettings::ChrootArchitecture,
                        @chrootTarget = ISM::Default::CommandLineSettings::ChrootTarget,
                        @chrootMakeOptions = ISM::Default::CommandLineSettings::ChrootMakeOptions,
                        @chrootBuildOptions = ISM::Default::CommandLineSettings::ChrootBuildOptions)
        end

        def loadSettingsFile
            information = Settings.from_json(File.read("/"+ISM::Default::CommandLineSettings::SettingsFilePath))
      
            @rootPath = information.rootPath
            @systemName = information.systemName
            @targetName = information.targetName
            @architecture = information.architecture
            @target = information.target
            @makeOptions = information.makeOptions
            @buildOptions = information.buildOptions
            @installByChroot = information.installByChroot
            @chrootSystemName = information.chrootSystemName
            @chrootTargetName = information.chrootTargetName
            @chrootArchitecture = information.chrootArchitecture
            @chrootTarget = information.chrootTarget
            @chrootMakeOptions = information.chrootMakeOptions
            @chrootBuildOptions = information.chrootBuildOptions
        end

        def writeSettingsFile
            settings = Settings.new(@rootPath,
                                    @systemName,
                                    @targetName,
                                    @architecture,
                                    @target,
                                    @makeOptions,
                                    @buildOptions,
                                    @installByChroot,
                                    @chrootSystemName,
                                    @chrootTargetName,
                                    @chrootArchitecture,
                                    @chrootTarget,
                                    @chrootMakeOptions,
                                    @chrootBuildOptions)

            file = File.open("/"+ISM::Default::CommandLineSettings::SettingsFilePath,"w")
            settings.to_json(file)
            file.close

            if Ism.settings.rootPath != "/"
                chrootFile = File.open(Ism.settings.rootPath+ISM::Default::CommandLineSettings::SettingsFilePath,"w")

                chrootSettings = Settings.new(  ISM::Default::CommandLineSettings::RootPath,
                                                @chrootSystemName,
                                                @chrootTargetName,
                                                @chrootArchitecture,
                                                @chrootTarget,
                                                @chrootMakeOptions,
                                                @chrootBuildOptions,
                                                ISM::Default::CommandLineSettings::InstallByChroot,
                                                ISM::Default::CommandLineSettings::SystemName,
                                                ISM::Default::CommandLineSettings::TargetName,
                                                ISM::Default::CommandLineSettings::Architecture,
                                                ISM::Default::CommandLineSettings::Target,
                                                ISM::Default::CommandLineSettings::MakeOptions,
                                                ISM::Default::CommandLineSettings::BuildOptions)
                chrootSettings.to_json(chrootFile)

                chrootFile.close
            end
        end

        def systemName : String
            return (Ism.settings.rootPath != "/" ? @chrootSystemName : @systemName)
        end

        def targetName : String
            return (Ism.settings.rootPath != "/" ? @chrootTargetName : @targetName)
        end

        def architecture : String
            return (Ism.settings.rootPath != "/" ? @chrootArchitecture : @architecture)
        end

        def target : String
            return (Ism.settings.rootPath != "/" ? @chrootTarget : @target)
        end

        def makeOptions : String
            return (Ism.settings.rootPath != "/" ? @chrootMakeOptions : @makeOptions)
        end

        def buildOptions : String
            return (Ism.settings.rootPath != "/" ? @chrootBuildOptions : @buildOptions)
        end

        def setRootPath(@rootPath)
            writeSettingsFile
        end

        def setSystemName(@systemName)
            writeSettingsFile
        end

        def setTargetName(@targetName)
            writeSettingsFile
            setTarget
        end

        def setArchitecture(@architecture)
            writeSettingsFile
            setTarget
        end

        def setTarget
            @target = @architecture + "-" + @targetName + "-" + "linux-gnu"
            writeSettingsFile
        end

        def setMakeOptions(@makeOptions)
            writeSettingsFile
        end

        def setBuildOptions(@buildOptions)
            writeSettingsFile
        end

        def setInstallByChroot(@installByChroot)
            writeSettingsFile
        end

        def setChrootSystemName(@chrootSystemName)
            writeSettingsFile
        end

        def setChrootTargetName(@chrootTargetName)
            writeSettingsFile
        end

        def setChrootArchitecture(@chrootArchitecture)
            writeSettingsFile
        end

        def setChrootTarget(@chrootTarget)
            writeSettingsFile
        end

        def setChrootMakeOptions(@chrootMakeOptions)
            writeSettingsFile
        end

        def setChrootBuildOptions(@chrootBuildOptions)
            writeSettingsFile
        end


        def temporaryPath
            return "#{@rootPath}#{ISM::Default::Path::TemporaryDirectory}"
        end

        def sourcesPath
            return "#{@rootPath}#{ISM::Default::Path::SourcesDirectory}"
        end

        def toolsPath
            return "#{@rootPath}#{ISM::Default::Path::ToolsDirectory}"
        end

    end

end
