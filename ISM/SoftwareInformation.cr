module ISM

  class SoftwareInformation

    def_clone

    record Option,
        name : String,
        description : String,
        active : Bool,
        dependencies : Array(Dependency),
        downloadLinks : Array(String),
        md5sums : Array(String) do
        include JSON::Serializable
    end
    
    record Dependency,
        name : String,
        version : String,
        options : Array(String) do
        include JSON::Serializable
    end
    
    record Information,
        port : String,
        name : String,
        version : String,
        architectures : Array(String),
        description : String,
        website : String,
        downloadLinks : Array(String),
        md5sums : Array(String),
        patchesLinks : Array(String),
        installedFiles : Array(String),
        dependencies : Array(Dependency),
        options : Array(Option) do
        include JSON::Serializable
    end

    property port : String
    property name : String
    property version : String
    property architectures : Array(String)
    property description : String
    property website : String
    property downloadLinks : Array(String)
    property md5sums : Array(String)
    property patchesLinks : Array(String)
    setter options : Array(ISM::SoftwareOption)
    property installedFiles : Array(String)
    setter dependencies : Array(ISM::SoftwareDependency)
    property options : Array(ISM::SoftwareOption)

    def initialize
        @port = String.new
        @name = String.new
        @version = String.new
        @architectures = Array(String).new
        @description = String.new
        @website = String.new
        @downloadLinks = Array(String).new
        @md5sums = Array(String).new
        @patchesLinks = Array(String).new
        @installedFiles = Array(String).new
        @dependencies = Array(ISM::SoftwareDependency).new
        @options = Array(ISM::SoftwareOption).new
    end

    def getEnabledPass : String
        @options.each do |option|
            if option.isPass && option.active
                return option.name
            end
        end

        return String.new
    end

    def loadInformationFile(loadInformationFilePath : String)
        begin
            information = Information.from_json(File.read(loadInformationFilePath))
        rescue error : JSON::ParseException
            puts    "#{ISM::Default::SoftwareInformation::FileLoadProcessSyntaxErrorText1 +
                    loadInformationFilePath +
                    ISM::Default::SoftwareInformation::FileLoadProcessSyntaxErrorText2 +
                    error.line_number.to_s}".colorize(:yellow)
            return
        end

        @port = information.port
        @name = information.name
        @version = information.version
        @architectures = information.architectures
        @description = information.description
        @website = information.website
        @downloadLinks = information.downloadLinks
        @md5sums = information.md5sums
        @patchesLinks = information.patchesLinks
        @installedFiles = information.installedFiles

        information.dependencies.each do |data|
            dependency = ISM::SoftwareDependency.new
            dependency.name = data.name
            dependency.version = data.version
            dependency.options = data.options
            @dependencies << dependency
        end

        information.options.each do |data|
            dependenciesArray = Array(ISM::SoftwareDependency).new
            data.dependencies.each do |dependency|
                temporary = ISM::SoftwareDependency.new
                temporary.name = dependency.name
                temporary.version = dependency.version
                temporary.options = dependency.options
                dependenciesArray << temporary
            end

            option = ISM::SoftwareOption.new
            option.name = data.name
            option.description = data.description
            option.active = data.active
            option.dependencies = dependenciesArray
            option.downloadLinks = data.downloadLinks
            option.md5sums = data.md5sums
            @options << option
        end

    end

    def writeInformationFile(writeInformationFilePath : String)
        path = writeInformationFilePath.chomp(writeInformationFilePath[writeInformationFilePath.rindex("/")..-1])

        if !Dir.exists?(path)
            Dir.mkdir_p(path)
        end


        dependenciesArray = Array(Dependency).new
        @dependencies.each do |data|
            dependenciesArray << Dependency.new(data.name,data.version,data.options)
        end

        optionsArray = Array(Option).new
        @options.each do |data|
            optionsDependenciesArray = Array(Dependency).new
            data.dependencies.each do |dependencyData|
                dependency = Dependency.new(dependencyData.name,dependencyData.version,dependencyData.options)
                optionsDependenciesArray << dependency
            end

            optionsArray << Option.new(data.name,data.description,data.active,optionsDependenciesArray,data.downloadLinks,data.md5sums)
        end

        information = Information.new(  @port,
                                        @name,
                                        @version,
                                        @architectures,
                                        @description,
                                        @website,
                                        @downloadLinks,
                                        @md5sums,
                                        @patchesLinks,
                                        @installedFiles,
                                        dependenciesArray,
                                        optionsArray)

        file = File.open(writeInformationFilePath,"w")
        information.to_json(file)
        file.close
    end

    def versionName
        return @name+"-"+@version
    end

    def builtSoftwareDirectoryPath
        return "#{ISM::Default::Path::BuiltSoftwaresDirectory}#{@port}/#{@name}/#{@version}/"
    end

    def filePath : String
        return Ism.settings.rootPath +
               ISM::Default::Path::SoftwaresDirectory +
               @port + "/" +
               @name + "/" +
               @version + "/" +
               ISM::Default::Filename::Information
    end

    def requireFilePath : String
        return Ism.settings.rootPath +
               ISM::Default::Path::SoftwaresDirectory +
               @port + "/" +
               @name + "/" +
               @version + "/" +
               @version + ".cr"
    end

    def settingsFilePath : String
        return  Ism.settings.rootPath +
                ISM::Default::Path::SettingsSoftwaresDirectory +
                @port + "/" +
                @name + "/" +
                @version + "/" +
                ISM::Default::Filename::SoftwareSettings
    end

    def installedFilePath : String
        return Ism.settings.rootPath +
               ISM::Default::Path::InstalledSoftwaresDirectory +
               @port + "/" +
               @name + "/" +
               @version + "/" +
               ISM::Default::Filename::Information
    end

    def option(optionName : String) : Bool
        @options.each do |option|
            if optionName == option.name
                return option.active
            end
        end

        return false
    end

    def enableOption(optionName : String)
        @options.each_with_index do |option, index|
            if optionName == option.name
                if option.isPass
                    currentEnabledPass = getEnabledPass

                    if passEnabled && currentEnabledPass != optionName
                        disableOption(currentEnabledPass)
                    end

                end

                @options[index].active = true
            end
        end
    end

    def disableOption(optionName : String)
        @options.each_with_index do |option, index|
            if optionName == option.name
                @options[index].active = false
            end
        end
    end

    def passEnabled : Bool
        @options.each do |option|
            if option.isPass && option.active
                return true
            end
        end

        return false
    end

    def dependencies : Array(ISM::SoftwareDependency)
        dependenciesArray = Array(ISM::SoftwareDependency).new

        @options.each do |option|

            if passEnabled
                if option.active
                    if option.isPass
                        return option.dependencies
                    else
                        dependenciesArray += option.dependencies
                    end
                end
            else
                if option.active || option.isPass
                    dependenciesArray += option.dependencies
                end

                if !option.active && option.isPass
                    requiredPassDependency = self.toSoftwareDependency
                    requiredPassDependency.options.push(option.name)
                    dependenciesArray.push(requiredPassDependency)
                end
            end

        end

        return @dependencies+dependenciesArray
    end

    def toSoftwareDependency : ISM::SoftwareDependency
        softwareDependency = ISM::SoftwareDependency.new

        softwareDependency.name = @name
        softwareDependency.version = @version

        @options.each do |option|
            if option.active
                softwareDependency.options << option.name
            end
        end

        return softwareDependency
    end

    def == (other : ISM::SoftwareInformation) : Bool
        return @name == other.name &&
            @version == other.version &&
            @options == other.options
    end

  end

end
