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
      secureMode : Bool,
      installByChroot : Bool,
      chrootSystemName : String,
      chrootTargetName : String,
      chrootArchitecture : String,
      chrootTarget : String,
      chrootMakeOptions : String,
      chrootBuildOptions : String,
      defaultMirror : String do
      include JSON::Serializable
    end

    property rootPath : String
    property secureMode : Bool
    property installByChroot : Bool
    property chrootSystemName : String
    property chrootTargetName : String
    property chrootArchitecture : String
    property chrootTarget : String
    property chrootMakeOptions : String
    property chrootBuildOptions : String
    property defaultMirror : String

    def initialize(@rootPath = ISM::Default::CommandLineSettings::RootPath,
                   @systemName = ISM::Default::CommandLineSettings::SystemName,
                   @targetName = ISM::Default::CommandLineSettings::TargetName,
                   @architecture = ISM::Default::CommandLineSettings::Architecture,
                   @target = ISM::Default::CommandLineSettings::Target,
                   @makeOptions = ISM::Default::CommandLineSettings::MakeOptions,
                   @buildOptions = ISM::Default::CommandLineSettings::BuildOptions,
                   @secureMode = ISM::Default::CommandLineSettings::SecureMode,
                   @installByChroot = ISM::Default::CommandLineSettings::InstallByChroot,
                   @chrootSystemName = ISM::Default::CommandLineSettings::ChrootSystemName,
                   @chrootTargetName = ISM::Default::CommandLineSettings::ChrootTargetName,
                   @chrootArchitecture = ISM::Default::CommandLineSettings::ChrootArchitecture,
                   @chrootTarget = ISM::Default::CommandLineSettings::ChrootTarget,
                   @chrootMakeOptions = ISM::Default::CommandLineSettings::ChrootMakeOptions,
                   @chrootBuildOptions = ISM::Default::CommandLineSettings::ChrootBuildOptions,
                   @defaultMirror = ISM::Default::CommandLineSettings::DefaultMirror)
    end

    def loadSettingsFile
      if !File.exists?("/" + ISM::Default::CommandLineSettings::SettingsFilePath)
        writeSettingsFile
      end

      information = Settings.from_json(File.read("/" + ISM::Default::CommandLineSettings::SettingsFilePath))

      @rootPath = information.rootPath
      @systemName = information.systemName
      @targetName = information.targetName
      @architecture = information.architecture
      @target = information.target
      @makeOptions = information.makeOptions
      @buildOptions = information.buildOptions
      @secureMode = information.secureMode
      @installByChroot = information.installByChroot
      @chrootSystemName = information.chrootSystemName
      @chrootTargetName = information.chrootTargetName
      @chrootArchitecture = information.chrootArchitecture
      @chrootTarget = information.chrootTarget
      @chrootMakeOptions = information.chrootMakeOptions
      @chrootBuildOptions = information.chrootBuildOptions
      @defaultMirror = information.defaultMirror
    end

    def writeSettings(filePath : String,
                      rootPath : String,
                      systemName : String,
                      targetName : String,
                      architecture : String,
                      target : String,
                      makeOptions : String,
                      buildOptions : String,
                      secureMode : Bool,
                      installByChroot : Bool,
                      chrootSystemName : String,
                      chrootTargetName : String,
                      chrootArchitecture : String,
                      chrootTarget : String,
                      chrootMakeOptions : String,
                      chrootBuildOptions : String,
                      defaultMirror : String)
      path = filePath.chomp(filePath[filePath.rindex("/")..-1])

      if !Dir.exists?(path)
        Dir.mkdir_p(path)
      end

      settings = Settings.new(rootPath,
        systemName,
        targetName,
        architecture,
        target,
        makeOptions,
        buildOptions,
        secureMode,
        installByChroot,
        chrootSystemName,
        chrootTargetName,
        chrootArchitecture,
        chrootTarget,
        chrootMakeOptions,
        chrootBuildOptions,
        defaultMirror)

      file = File.open(filePath, "w")
      settings.to_json(file)
      file.close
    end

    def writeChrootSettingsFile
      writeSettings(@rootPath + ISM::Default::CommandLineSettings::SettingsFilePath,
        ISM::Default::CommandLineSettings::RootPath,
        @chrootSystemName,
        @chrootTargetName,
        @chrootArchitecture,
        @chrootTarget,
        @chrootMakeOptions,
        @chrootBuildOptions,
        ISM::Default::CommandLineSettings::SecureMode,
        ISM::Default::CommandLineSettings::InstallByChroot,
        ISM::Default::CommandLineSettings::SystemName,
        ISM::Default::CommandLineSettings::TargetName,
        ISM::Default::CommandLineSettings::Architecture,
        ISM::Default::CommandLineSettings::Target,
        ISM::Default::CommandLineSettings::MakeOptions,
        ISM::Default::CommandLineSettings::BuildOptions,
        @defaultMirror)
    end

    def writeSettingsFile
      writeSettings("/" + ISM::Default::CommandLineSettings::SettingsFilePath,
        @rootPath,
        @systemName,
        @targetName,
        @architecture,
        @target,
        @makeOptions,
        @buildOptions,
        @secureMode,
        @installByChroot,
        @chrootSystemName,
        @chrootTargetName,
        @chrootArchitecture,
        @chrootTarget,
        @chrootMakeOptions,
        @chrootBuildOptions,
        @defaultMirror)

      if @rootPath != "/"
        writeChrootSettingsFile
      end
    end

    def systemName(relatedToChroot = true) : String
      if relatedToChroot
        (@rootPath != "/" ? @chrootSystemName : @systemName)
      else
        @systemName
      end
    end

    def targetName(relatedToChroot = true) : String
      if relatedToChroot
        (@rootPath != "/" ? @chrootTargetName : @targetName)
      else
        @targetName
      end
    end

    def architecture(relatedToChroot = true) : String
      if relatedToChroot
        (@rootPath != "/" ? @chrootArchitecture : @architecture)
      else
        @architecture
      end
    end

    def target(relatedToChroot = true) : String
      if relatedToChroot
        (@rootPath != "/" ? @chrootTarget : @target)
      else
        @target
      end
    end

    def makeOptions(relatedToChroot = true) : String
      if relatedToChroot
        (@rootPath != "/" ? @chrootMakeOptions : @makeOptions)
      else
        @makeOptions
      end
    end

    def buildOptions(relatedToChroot = true) : String
      if relatedToChroot
        (@rootPath != "/" ? @chrootBuildOptions : @buildOptions)
      else
        @buildOptions
      end
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
      match, invalidValue = Ism.inputMatchWithFilter(@makeOptions, ISM::Default::CommandLineSettings::MakeOptionsFilter)

      if match
        writeSettingsFile
      else
        puts "#{ISM::Default::CommandLineSettings::ErrorInvalidValueText.colorize(:red)}#{invalidValue.colorize(:red)}"
        puts "#{ISM::Default::CommandLineSettings::ErrorMakeOptionsInvalidValueAdviceText.colorize(:green)}"
        Ism.exitProgram
      end
    end

    def setBuildOptions(@buildOptions)
      writeSettingsFile
    end

    def setSecureMode(@secureMode)
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
      match, invalidValue = Ism.inputMatchWithFilter(@chrootMakeOptions, ISM::Default::CommandLineSettings::ChrootMakeOptionsFilter)

      if match
        writeSettingsFile
      else
        puts "#{ISM::Default::CommandLineSettings::ErrorInvalidValueText.colorize(:red)}#{invalidValue.colorize(:red)}"
        puts "#{ISM::Default::CommandLineSettings::ErrorChrootMakeOptionsInvalidValueAdviceText.colorize(:green)}"
        Ism.exitProgram
      end
    end

    def setChrootBuildOptions(@chrootBuildOptions)
      writeSettingsFile
    end

    def setDefaultMirror(@defaultMirror)
      writeSettingsFile
    end

    def temporaryPath
      "#{@rootPath}#{ISM::Default::Path::TemporaryDirectory}"
    end

    def sourcesPath
      "#{@rootPath}#{ISM::Default::Path::SourcesDirectory}"
    end

    def toolsPath
      "#{@rootPath}#{ISM::Default::Path::ToolsDirectory}"
    end
  end
end
