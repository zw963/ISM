module ISM
  class Software
    property information : ISM::SoftwareInformation
    property mainSourceDirectoryName : String
    property buildDirectory : Bool
    property buildDirectoryNames : Hash(String, String)

    def initialize(informationPath : String)
      @information = ISM::SoftwareInformation.new
      @information.loadInformationFile(informationPath)
      @mainSourceDirectoryName = ISM::Default::Software::SourcesDirectoryName
      @buildDirectory = false
      @buildDirectoryNames = {ISM::Default::Software::MainBuildDirectoryEntry => "mainBuild"}
    end

    def workDirectoryPath(relatedToChroot = true) : String
      (relatedToChroot ? Ism.settings.installByChroot : false) ? "/#{ISM::Default::Path::SourcesDirectory}" + @information.port + "/" + @information.name + "/" + @information.version : Ism.settings.sourcesPath + @information.port + "/" + @information.name + "/" + @information.version
    end

    def mainWorkDirectoryPath(relatedToChroot = true) : String
      workDirectoryPath(relatedToChroot) + "/" + @mainSourceDirectoryName
    end

    def buildDirectoryPath(relatedToChroot = true, entry = ISM::Default::Software::MainBuildDirectoryEntry) : String
      mainWorkDirectoryPath(relatedToChroot) + "/" + "#{@buildDirectory ? @buildDirectoryNames[entry] : ""}"
    end

    def builtSoftwareDirectoryPath(relatedToChroot = true) : String
      (relatedToChroot ? Ism.settings.installByChroot : false) ? "/#{@information.builtSoftwareDirectoryPath}" : "#{Ism.settings.rootPath}#{@information.builtSoftwareDirectoryPath}"
    end

    def download
      Ism.notifyOfDownload(@information)

      cleanWorkDirectoryPath

      downloadSources
      downloadSourcesMd5sum

      if remoteFileIsAvailable(@information.patchesLink)
        downloadPatches
        downloadPatchesMd5sum
      end
    end

    def downloadSources
      downloadFile(@information.sourcesLink,
        ISM::Default::Software::SourcesArchiveBaseName,
        ISM::Default::Software::ArchiveExtensionName)
    end

    def downloadSourcesMd5sum
      downloadFile(@information.sourcesMd5sumLink,
        ISM::Default::Software::SourcesArchiveBaseName,
        ISM::Default::Software::ArchiveMd5sumExtensionName)
    end

    def remoteFileIsAvailable(fileUrl : String) : Bool
      response = HTTP::Client.get(fileUrl)

      response.status == HTTP::Status::OK
    end

    def downloadPatches
      downloadFile(@information.patchesLink,
        ISM::Default::Software::PatchesArchiveBaseName,
        ISM::Default::Software::ArchiveExtensionName)
    end

    def downloadPatchesMd5sum
      downloadFile(@information.patchesMd5sumLink,
        ISM::Default::Software::PatchesArchiveBaseName,
        ISM::Default::Software::ArchiveMd5sumExtensionName)
    end

    def downloadFile(link : String, filename : String, fileExtensionName : String)
      originalLink = link
      downloaded = false
      error = String.new

      # ACTUALLY BRING DOWNLOAD FAILURE
      # Checking if connexion is available
      # begin
      #     TCPSocket.new(link, port: 80, connect_timeout: 500.milliseconds).close
      # rescue ex : IO::Error
      #     Ism.notifyOfConnexionError(link)
      #     Ism.exitProgram
      # end

      until downloaded
        HTTP::Client.get(link) do |response|
          if response.status.redirection?
            begin
              link = response.headers["location"]
            rescue
              error = "#{ISM::Default::Software::DownloadSourceRedirectionErrorText1}#{response.status_code}#{ISM::Default::Software::DownloadSourceRedirectionErrorText2}"

              Ism.notifyOfDownloadError(link, error)
              Ism.exitProgram
            end
            break
          end

          filePath = "#{workDirectoryPath(false)}/#{filename + fileExtensionName}"
          colorizedFileFullName = "#{filename}#{fileExtensionName.colorize(Colorize::ColorRGB.new(255, 100, 100))}"
          colorizedLink = "#{link.colorize(:magenta)}"

          lastSpeedUpdate = Time.monotonic
          average = 0
          bytesLastPeriod = 0

          if response.status_code == 200
            buffer = Bytes.new(65536)
            totalRead = Int64.new(0)
            lenght = response.headers["Content-Length"]? ? response.headers["Content-Length"].to_i32 : Int64.new(0)

            File.open(filePath, "wb") do |data|
              while (pos = response.body_io.read(buffer)) > 0
                lapsed = Time.monotonic - lastSpeedUpdate

                if lapsed.total_seconds >= 1
                  div = lapsed.total_nanoseconds / 1_000_000_000
                  average = (bytesLastPeriod / div).to_i32!
                  bytesLastPeriod = 0
                  lastSpeedUpdate = Time.monotonic
                end

                data.write(buffer[0...pos])
                bytesLastPeriod += pos
                totalRead += pos

                if lenght > 0
                  text = "\t#{"| ".colorize(:green)} #{colorizedFileFullName} [#{(Int64.new(totalRead*100/lenght).to_s + "%").colorize(:green)}] #{"{".colorize(:green)}#{average.humanize_bytes}/s#{"}".colorize(:green)} (#{colorizedLink})"
                else
                  text = "\t#{"| ".colorize(:green)} #{colorizedFileFullName} [#{"0%".colorize(:green)}] #{"{".colorize(:green)}#{average.humanize_bytes}/s#{"}".colorize(:green)} (#{colorizedLink})"
                end

                print text + "\r"
              end
            end

            downloaded = true
          else
            error = "#{ISM::Default::Software::DownloadSourceCodeErrorText}#{response.status_code}"

            Ism.notifyOfDownloadError(link, error)
            Ism.exitProgram
          end
        end
      end

      puts
    end

    def check
      Ism.notifyOfCheck(@information)
      checkSourcesMd5sum
      if File.exists?(workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesMd5sumArchiveName)
        checkPatchesMd5sum
      end
    end

    def checkSourcesMd5sum
      checkFile(workDirectoryPath(false) + "/" + ISM::Default::Software::SourcesArchiveName,
        getFileContent(workDirectoryPath(false) + "/" + ISM::Default::Software::SourcesMd5sumArchiveName).strip)
    end

    def checkPatchesMd5sum
      checkFile(workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesArchiveName,
        getFileContent(workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesMd5sumArchiveName).strip)
    end

    def checkFile(archive : String, md5sum : String)
      digest = Digest::MD5.new
      digest.file(archive)
      archiveMd5sum = digest.hexfinal

      if archiveMd5sum != md5sum
        Ism.notifyOfCheckError(archive, md5sum)
        Ism.exitProgram
      end
    end

    def extract
      Ism.notifyOfExtract(@information)
      extractSources
      if File.exists?(workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesMd5sumArchiveName)
        extractPatches
      end
    end

    def extractSources
      extractArchive(workDirectoryPath(false) + "/" + ISM::Default::Software::SourcesArchiveName, workDirectoryPath(false))
      moveFile(workDirectoryPath(false) + "/" + @information.versionName, workDirectoryPath(false) + "/" + ISM::Default::Software::SourcesDirectoryName)
    end

    def extractPatches
      extractArchive(workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesArchiveName, workDirectoryPath(false))
      moveFile(workDirectoryPath(false) + "/" + @information.versionName, workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesDirectoryName)
    end

    def extractArchive(archivePath : String, destinationPath = workDirectoryPath(false))
      process = Process.run("tar -xf #{archivePath}",
        error: :inherit,
        shell: true,
        chdir: destinationPath)
      if !process.success?
        Ism.notifyOfExtractError(archivePath, destinationPath)
        Ism.exitProgram
      end
    end

    def patch
      Ism.notifyOfPatch(@information)

      if Dir.exists?("#{workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesDirectoryName}")
        Dir["#{workDirectoryPath(false) + "/" + ISM::Default::Software::PatchesDirectoryName}/*"].each do |patch|
          applyPatch(patch)
        end
      end

      if Dir.exists?(Ism.settings.rootPath + ISM::Default::Path::PatchesDirectory + "/#{@information.versionName}")
        Dir[Ism.settings.rootPath + ISM::Default::Path::PatchesDirectory + "/#{@information.versionName}/*"].each do |patch|
          patchName = patch.lchop(patch[0..patch.rindex("/")])
          Ism.notifyOfLocalPatch(patchName)
          applyPatch(patch)
        end
      end
    end

    def applyPatch(patch : String)
      process = Process.run("patch -Np1 -i #{patch}",
        error: :inherit,
        shell: true,
        chdir: mainWorkDirectoryPath(false))
      if !process.success?
        Ism.notifyOfApplyPatchError(patch)
        Ism.exitProgram
      end
    end

    def prepare
      Ism.notifyOfPrepare(@information)

      # Generate all build directories
      @buildDirectoryNames.keys.each do |key|
        if !Dir.exists?(buildDirectoryPath(false, key))
          makeDirectory(buildDirectoryPath(false, key))
        end
      end
    end

    def generateEmptyFile(path : String)
      FileUtils.touch(path)
    rescue error
      Ism.notifyOfGenerateEmptyFileError(path, error)
      Ism.exitProgram
    end

    def moveFile(path : String | Enumerable(String), newPath : String)
      FileUtils.mv(path, newPath)
    rescue error
      Ism.notifyOfMoveFileError(path, newPath, error)
      Ism.exitProgram
    end

    def makeDirectory(directory : String)
      FileUtils.mkdir_p(directory)
    rescue error
      Ism.notifyOfMakeDirectoryError(directory, error)
      Ism.exitProgram
    end

    def deleteDirectory(directory : String)
      Dir.delete(directory)
    rescue error
      Ism.notifyOfDeleteDirectoryError(directory, error)
      Ism.exitProgram
    end

    def deleteDirectoryRecursively(directory : String)
      FileUtils.rm_r(directory)
    rescue error
      Ism.notifyOfDeleteDirectoryRecursivelyError(directory, error)
      Ism.exitProgram
    end

    def setPermissions(path : String, permissions : Int)
      File.chmod(path, permissions)
    rescue error
      Ism.notifyOfSetPermissionsError(path, permissions, error)
      Ism.exitProgram
    end

    def setOwner(path : String, uid : Int | String, gid : Int | String)
      File.chown(path,
        (uid.is_a?(String) ? System::Group.find_by(name: uid).id : uid).to_i,
        (gid.is_a?(String) ? System::Group.find_by(name: gid).id : gid).to_i)
    rescue error
      Ism.notifyOfSetOwnerError(path, uid, gid, error)
      Ism.exitProgram
    end

    def setPermissionsRecursively(path : String, permissions : Int)
      Dir["#{path}/**/*"].each do |file_path|
        setPermissions(file_path, permissions)
      end
    rescue error
      Ism.notifyOfSetPermissionsRecursivelyError(path, permissions, error)
      Ism.exitProgram
    end

    def setOwnerRecursively(path : String, uid : Int | String, gid : Int | String)
      Dir["#{path}/**/*"].each do |file_path|
        setOwner(file_path, uid, gid)
      end
    rescue error
      Ism.notifyOfSetOwnerRecursivelyError(path, uid, gid, error)
      Ism.exitProgram
    end

    def fileReplaceText(filePath : String | Enumerable, text : String, newText : String)
      content = File.read_lines(filePath)

      File.open(filePath, "w") do |file|
        content.each do |line|
          if line.includes?(text)
            file << line.gsub(text, newText) + "\n"
          else
            file << line + "\n"
          end
        end
      end
    rescue error
      Ism.notifyOfFileReplaceTextError(filePath, text, newText, error)
      Ism.exitProgram
    end

    def fileReplaceLineContaining(filePath : String, text : String, newLine : String)
      content = File.read_lines(filePath)

      File.open(filePath, "w") do |file|
        content.each do |line|
          if line.includes?(text)
            file << newLine + "\n"
          else
            file << line + "\n"
          end
        end
      end
    rescue error
      Ism.notifyOfFileReplaceLineContainingError(filePath, text, newLine, error)
      Ism.exitProgram
    end

    def fileReplaceTextAtLineNumber(filePath : String, text : String, newText : String, lineNumber : UInt64)
      content = File.read_lines(filePath)

      File.open(filePath, "w") do |file|
        content.each_with_index do |line, index|
          if !(index + 1 == lineNumber)
            file << line + "\n"
          else
            file << line.gsub(text, newText) + "\n"
          end
        end
      end
    rescue error
      Ism.notifyOfReplaceTextAtLineNumberError(filePath, text, newText, lineNumber, error)
      Ism.exitProgram
    end

    def fileDeleteLine(filePath : String, lineNumber : UInt64)
      content = File.read_lines(filePath)

      File.open(filePath, "w") do |file|
        content.each_with_index do |line, index|
          if !(index + 1 == lineNumber)
            file << line + "\n"
          end
        end
      end
    rescue error
      Ism.notifyOfFileDeleteLineError(filePath, lineNumber, error)
      Ism.exitProgram
    end

    def getFileContent(filePath : String) : String
      begin
        content = File.read(filePath)
      rescue error
        Ism.notifyOfGetFileContentError(filePath, error)
        Ism.exitProgram
      end
      content
    end

    def fileWriteData(filePath : String, data : String)
      File.write(filePath, data)
    rescue error
      Ism.notifyOfFileWriteDataError(filePath, error)
      Ism.exitProgram
    end

    def fileAppendData(filePath : String, data : String)
      File.open(filePath, "a") do |file|
        file.puts(data)
      end
    rescue error
      Ism.notifyOfFileAppendDataError(filePath, error)
      Ism.exitProgram
    end

    def fileUpdateContent(filePath : String, data : String)
      content = getFileContent(filePath)
      if !content.includes?(data)
        fileAppendData(filePath, "\n" + data)
      end
    rescue error
      Ism.notifyOfFileUpdateContentError(filePath, error)
      Ism.exitProgram
    end

    def updateUserFile(data : String)
      userName = data.split(":")[0]
      filePath = "#{Ism.settings.rootPath}etc/passwd"
      userExist = false

      if !File.exists?(filePath)
        generateEmptyFile(filePath)
      end

      begin
        content = File.read_lines(filePath)

        content.each_with_index do |line, index|
          userExist = line.starts_with?(userName)

          if userExist
            break
          end
        end

        if !userExist
          fileAppendData(filePath, data + "\n")
        end
      rescue error
        Ism.notifyOfUpdateUserFileError(data, error)
        Ism.exitProgram
      end
    end

    def updateGroupFile(data : String)
      groupName = data.split(":")[0]
      filePath = "#{Ism.settings.rootPath}etc/group"
      groupExist = false

      if !File.exists?(filePath)
        generateEmptyFile(filePath)
      end

      begin
        content = File.read_lines(filePath)

        content.each_with_index do |line, index|
          groupExist = line.starts_with?(groupName)

          if groupExist
            break
          end
        end

        if !groupExist
          fileAppendData(filePath, data + "\n")
        end
      rescue error
        Ism.notifyOfUpdateGroupFileError(data, error)
        Ism.exitProgram
      end
    end

    def makeLink(path : String, targetPath : String, linkType : Symbol)
      if File.exists?(targetPath)
        Ism.notifyOfMakeLinkFileExistError(path, targetPath)
        Ism.exitProgram
      end

      if File.symlink?(targetPath) && File.symlink?(targetPath)
        deleteFile(targetPath)
      end

      begin
        case linkType
        when :hardLink
          FileUtils.ln(path, targetPath)
        when :symbolicLink
          FileUtils.ln_s(path, targetPath)
        when :symbolicLinkByOverwrite
          FileUtils.ln_sf(path, targetPath)
        else
          Ism.notifyOfMakeLinkUnknowTypeError(path, targetPath, linkType)
          Ism.exitProgram
        end
      rescue error
        Ism.notifyOfMakeLinkError(path, targetPath, error)
        Ism.exitProgram
      end
    end

    def copyFile(path : String | Enumerable(String), targetPath : String)
      FileUtils.cp(path, targetPath)
    rescue error
      Ism.notifyOfCopyFileError(path, targetPath, error)
      Ism.exitProgram
    end

    def copyAllFilesFinishing(path : String, destination : String, text : String)
      Dir["#{path}/*"].each do |filePath|
        filename = filePath.lchop(filePath[0..filePath.rindex("/")])
        destinationPath = "#{destination}/#{filename}"

        if File.file?(filePath) && filePath[-text.size..-1] == text
          copyFile(filePath, destinationPath)
        end
      end
    rescue error
      Ism.notifyOfCopyAllFilesFinishingError(path, destination, text, error)
      Ism.exitProgram
    end

    def copyAllFilesRecursivelyFinishing(path : String, destination : String, text : String)
      Dir["#{path}/**/*"].each do |filePath|
        filename = filePath.lchop(filePath[0..filePath.rindex("/")])
        destinationPath = "#{destination}/#{filename}"

        if File.file?(filePath) && filePath[-text.size..-1] == text
          copyFile(filePath, destinationPath)
        end
      end
    rescue error
      Ism.notifyOfCopyAllFilesRecursivelyFinishingError(path, destination, text, error)
      Ism.exitProgram
    end

    def copyDirectory(path : String, targetPath : String)
      FileUtils.cp_r(path, targetPath)
    rescue error
      Ism.notifyOfCopyDirectoryError(path, targetPath, error)
      Ism.exitProgram
    end

    def deleteFile(path : String | Enumerable(String))
      FileUtils.rm(path)
    rescue error
      Ism.notifyOfDeleteFileError(path, error)
      Ism.exitProgram
    end

    def replaceTextAllFilesNamed(path : String, filename : String, text : String, newText : String)
      Dir["#{path}/*"].each do |file_path|
        if File.file?(file_path) && file_path == "#{path}/#{filename}".squeeze("/")
          fileReplaceText(file_path, text, newText)
        end
      end
    rescue error
      Ism.notifyOfReplaceTextAllFilesNamedError(path, filename, text, newText, error)
      Ism.exitProgram
    end

    def replaceTextAllFilesRecursivelyNamed(path : String, filename : String, text : String, newText : String)
      Dir["#{path}/**/*"].each do |file_path|
        if File.file?(file_path) && file_path == "#{path}/#{filename}".squeeze("/")
          fileReplaceText(file_path, text, newText)
        end
      end
    rescue error
      Ism.notifyOfReplaceTextAllFilesRecursivelyNamedError(path, filename, text, newText, error)
      Ism.exitProgram
    end

    def deleteAllFilesFinishing(path : String, text : String)
      Dir["#{path}/*"].each do |file_path|
        if File.file?(file_path) && file_path[-text.size..-1] == text
          deleteFile(file_path)
        end
      end
    rescue error
      Ism.notifyOfDeleteAllFilesFinishingError(path, text, error)
      Ism.exitProgram
    end

    def deleteAllFilesRecursivelyFinishing(path : String, text : String)
      Dir["#{path}/**/*"].each do |file_path|
        if File.file?(file_path) && file_path[-text.size..-1] == text
          deleteFile(file_path)
        end
      end
    rescue error
      Ism.notifyOfDeleteAllFilesRecursivelyFinishingError(path, text, error)
      Ism.exitProgram
    end

    def deleteAllHiddenFiles(path : String)
      Dir.glob(["#{path}/.*"], match: :dot_files) do |file_path|
        if File.file?(file_path)
          deleteFile(file_path)
        end
      end
    rescue error
      Ism.notifyOfDeleteAllHiddenFilesError(path, error)
      Ism.exitProgram
    end

    def deleteAllHiddenFilesRecursively(path : String)
      Dir.glob(["#{path}/**/.*"], match: :dot_files) do |file_path|
        if File.file?(file_path)
          deleteFile(file_path)
        end
      end
    rescue error
      Ism.notifyOfDeleteAllHiddenFilesRecursivelyError(path, error)
      Ism.exitProgram
    end

    def runChrootTasks(chrootTasks) : Process::Status
      File.write(Ism.settings.rootPath + ISM::Default::Filename::Task, chrootTasks)

      process = Process.run("chmod +x #{Ism.settings.rootPath}#{ISM::Default::Filename::Task}",
        output: :inherit,
        error: :inherit,
        shell: true)

      process = Process.run("chroot #{Ism.settings.rootPath} ./#{ISM::Default::Filename::Task}",
        output: :inherit,
        error: :inherit,
        shell: true)

      File.delete(Ism.settings.rootPath + ISM::Default::Filename::Task)

      process
    end

    def runSystemCommand(arguments = Array(String).new, path = Ism.settings.installByChroot ? "/" : Ism.settings.rootPath, environment = Hash(String, String).new) : Process::Status
      environmentCommand = String.new

      environment.keys.each do |key|
        environmentCommand += " #{key}=\"#{environment[key]}\""
      end

      command = arguments.join(" ")

      if Ism.settings.installByChroot
        chrootCommand = <<-CODE
                #!/bin/bash
                cd #{path} && #{environmentCommand} #{command}
                CODE

        process = runChrootTasks(chrootCommand)
      else
        process = Process.run(command,
          output: :inherit,
          error: :inherit,
          shell: true,
          chdir: (path == "" ? nil : path),
          env: environment)
      end

      process
    end

    def runChmodCommand(arguments = Array(String).new, path = String.new)
      requestedCommands = ["chmod"] + arguments

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path)
        Ism.exitProgram
      end
    end

    def runUserAddCommand(arguments : Array(String))
      requestedCommands = ["useradd"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success? && process.exit_code != 9
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runUserDelCommand(arguments : Array(String))
      requestedCommands = ["userdel"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success? && process.exit_code != 9
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGroupAddCommand(arguments : Array(String))
      requestedCommands = ["groupadd"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success? && process.exit_code != 9
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGroupDelCommand(arguments : Array(String))
      requestedCommands = ["groupdel"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success? && process.exit_code != 9
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runScript(file : String, arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["./#{file}"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runPythonCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["python"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runCrystalCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["crystal"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runCmakeCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["cmake"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runMesonCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["meson"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runNinjaCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new, makeOptions = String.new, buildOptions = String.new)
      if Ism.settings.installByChroot
        arguments.unshift(makeOptions == "" ? Ism.settings.chrootMakeOptions : makeOptions)
      else
        arguments.unshift(makeOptions == "" ? Ism.settings.makeOptions : makeOptions)
      end

      requestedCommands = ["ninja"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runPwconvCommand(arguments = Array(String).new)
      requestedCommands = ["pwconv"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGrpconvCommand(arguments = Array(String).new)
      requestedCommands = ["grpconv"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runUdevadmCommand(arguments : Array(String))
      requestedCommands = ["udevadm"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runDbusUuidgenCommand(arguments = Array(String).new)
      requestedCommands = ["dbus-uuidgen"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runMakeinfoCommand(arguments : Array(String), path = String.new)
      requestedCommands = ["makeinfo"] + arguments

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path)
        Ism.exitProgram
      end
    end

    def runInstallInfoCommand(arguments : Array(String))
      requestedCommands = ["install-info"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runAutoconfCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["autoconf"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runAutoreconfCommand(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new)
      requestedCommands = ["autoreconf"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def runLocaledefCommand(arguments : Array(String))
      requestedCommands = ["localedef"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGunzipCommand(arguments : Array(String), path = String.new)
      requestedCommands = ["gunzip"] + arguments

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path)
        Ism.exitProgram
      end
    end

    def runMakeCaCommand(arguments : Array(String))
      requestedCommands = ["make-ca"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runInstallCatalogCommand(arguments : Array(String))
      requestedCommands = ["install-catalog"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runXmlCatalogCommand(arguments : Array(String))
      requestedCommands = ["xmlcatalog"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runLdconfigCommand(arguments = Array(String).new)
      requestedCommands = ["ldconfig"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGtkQueryImmodules2Command(arguments = Array(String).new)
      requestedCommands = ["gtk-query-immodules-2.0"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGtkQueryImmodules3Command(arguments = Array(String).new)
      requestedCommands = ["gtk-query-immodules-3.0"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGlibCompileSchemasCommand(arguments = Array(String).new)
      requestedCommands = ["glib-compile-schemas"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGdkPixbufQueryLoadersCommand(arguments = Array(String).new)
      requestedCommands = ["gdk-pixbuf-query-loaders"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runUpdateMimeDatabaseCommand(arguments = Array(String).new)
      requestedCommands = ["update-mime-database"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def sourceFile(arguments = Array(String).new)
      requestedCommands = ["source"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runCargoCommand(arguments : Array(String), path = String.new)
      requestedCommands = ["cargo"] + arguments

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path)
        Ism.exitProgram
      end
    end

    def runGccCommand(arguments = Array(String).new, path = String.new)
      requestedCommands = ["gcc"] + arguments

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path)
        Ism.exitProgram
      end
    end

    def runRcUpdateCommand(arguments = Array(String).new)
      requestedCommands = ["rc-update"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runAlsactlCommand(arguments = Array(String).new)
      requestedCommands = ["alsactl"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runGtkUpdateIconCacheCommand(arguments = Array(String).new)
      requestedCommands = ["gtk-update-icon-cache"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runUpdateDesktopDatabaseCommand(arguments = Array(String).new)
      requestedCommands = ["update-desktop-database"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runZicCommand(arguments : Array(String), path = String.new)
      requestedCommands = ["zic"] + arguments

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path)
        Ism.exitProgram
      end
    end

    def prepareOpenrcServiceInstallation(filePath : String, serviceName : String)
      servicesPath = "/etc/init.d/"

      makeDirectory("#{builtSoftwareDirectoryPath(false)}#{Ism.settings.rootPath}#{servicesPath}")
      moveFile(filePath, "#{builtSoftwareDirectoryPath(false)}#{Ism.settings.rootPath}#{servicesPath}#{serviceName}")
      runChmodCommand(["+x", serviceName], "#{builtSoftwareDirectoryPath}#{Ism.settings.rootPath}#{servicesPath}")
    end

    def configure
      Ism.notifyOfConfigure(@information)
    end

    def configureSource(arguments = Array(String).new, path = String.new, configureDirectory = String.new, environment = Hash(String, String).new, relatedToMainBuild = true)
      configureCommand = "#{@buildDirectory && relatedToMainBuild ? ".." : "."}/#{configureDirectory}/configure"

      requestedCommands = [configureCommand] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def build
      Ism.notifyOfBuild(@information)
    end

    def makePerlSource(path = String.new)
      requestedCommands = ["perl", "Makefile.PL"]

      process = runSystemCommand(requestedCommands, path)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands)
        Ism.exitProgram
      end
    end

    def runCpanCommand(arguments = Array(String).new)
      requestedCommands = ["cpan"] + arguments

      process = runSystemCommand(requestedCommands)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(arguments)
        Ism.exitProgram
      end
    end

    def makeSource(arguments = Array(String).new, path = String.new, environment = Hash(String, String).new, makeOptions = String.new, buildOptions = String.new)
      if Ism.settings.installByChroot
        arguments.unshift(makeOptions == "" ? Ism.settings.chrootMakeOptions : makeOptions)
      else
        arguments.unshift(makeOptions == "" ? Ism.settings.makeOptions : makeOptions)
      end

      requestedCommands = ["make"] + arguments

      process = runSystemCommand(requestedCommands, path, environment)

      if !process.success?
        Ism.notifyOfRunSystemCommandError(requestedCommands, path, environment)
        Ism.exitProgram
      end
    end

    def prepareInstallation
      Ism.notifyOfPrepareInstallation(@information)
    end

    def recordInstallationInformation : Tuple(UInt128, UInt128, UInt128, UInt128)
      directoryNumber = UInt128.new(0)
      symlinkNumber = UInt128.new(0)
      fileNumber = UInt128.new(0)
      totalSize = UInt128.new(0)

      filesList = Dir.glob(["#{builtSoftwareDirectoryPath(false)}/**/*"], match: :dot_files)

      directoryNumber = UInt128.new(0)
      symlinkNumber = UInt128.new(0)
      fileNumber = UInt128.new(0)
      totalSize = UInt128.new(0)

      filesList.each do |entry|
        finalDestination = "/#{entry.sub(builtSoftwareDirectoryPath(false), "")}"

        if File.directory?(entry)
          if !Dir.exists?(finalDestination)
            directoryNumber += 1
          end
        else
          if File.symlink?(entry)
            symlinkNumber += 1
          else
            fileNumber += 1
            totalSize += File.size(entry)
          end
        end
      end

      return directoryNumber, symlinkNumber, fileNumber, totalSize
    end

    def install
      Ism.notifyOfInstall(@information)

      filesList = Dir.glob(["#{builtSoftwareDirectoryPath(false)}/**/*"], match: :dot_files)
      installedFiles = Array(String).new

      filesList.each do |entry|
        finalDestination = "/#{entry.sub(builtSoftwareDirectoryPath(false), "")}"

        if File.directory?(entry)
          if !Dir.exists?(finalDestination)
            makeDirectory(finalDestination)
            installedFiles << "/#{finalDestination.sub(Ism.settings.rootPath, "")}".squeeze("/")
          end
        else
          # Delete existing file instead of overriding it to avoid any crash
          if File.exists?(finalDestination)
            deleteFile(finalDestination)
          end

          moveFile(entry, finalDestination)
          installedFiles << "/#{finalDestination.sub(Ism.settings.rootPath, "")}".squeeze("/")
        end
      end

      Ism.addInstalledSoftware(@information, installedFiles)
    end

    def kernelName : String
      "#{@information.versionName.downcase}"
    end

    def kernelSourcesPath : String
      "#{Ism.settings.rootPath}usr/src/#{kernelName}/"
    end

    def kernelSourcesArchitecturePath : String
      "#{kernelSourcesPath}arch/"
    end

    def kernelKconfigFilePath : String
      "#{kernelSourcesPath}Kconfig"
    end

    def kernelArchitectureKconfigFilePath : String
      "#{kernelSourcesArchitecturePath}Kconfig"
    end

    def kernelConfigFilePath : String
      "#{kernelSourcesPath}.config"
    end

    def kernelOptionsDatabasePath : String
      Ism.settings.rootPath + ISM::Default::Path::KernelOptionsDirectory + kernelName
    end

    def setKernelOption(symbol : String, state : Symbol, value = String.new)
      case state
      when :enable
        arguments = ["-e", "#{symbol}"]
      when :disable
        arguments = ["-d", "#{symbol}"]
      when :module
        arguments = ["-m", "#{symbol}"]
      when :string
        arguments = ["--set-str", "#{symbol}", value]
      when :value
        arguments = ["--set-val", "#{symbol}", value]
      end

      runScript("#{kernelSourcesPath}config", arguments, "#{kernelSourcesPath}scripts")
    end

    # Return an array splitted, except when there are conditions between parenthesis
    def getConditionArray(conditions : String) : Array(String)
      parenthesisArray = conditions.scan(/(!?\(.*?\))/)

      parenthesisArray.each do |old|
        new = old.to_s.gsub(" && ", "&&")
        new = new.gsub(" || ", "||")

        conditions = conditions.gsub(old.to_s, new)
      end

      conditions.split(" && ")
    end

    def parseKconfigConditions(conditions : String)
      conditionArray = getConditionArray(conditions)

      dependencies = Array(String).new
      singleChoiceDependencies = Array(Array(String)).new
      blockers = Array(String).new

      conditionArray.each_with_index do |word, index|
        parenthesis = word.includes?("(")

        if parenthesis
          reverseCondition = word.starts_with?("!")
        else
          if word.starts_with?("!")
            blockers.push(word)
          else
            dependencies.push(word)
          end
        end
      end

      return dependencies, singleChoiceDependencies, blockers
    end

    def getFullKernelKconfigFile(kconfigPath : String) : Array(String)
      content = File.read_lines(kernelKconfigFilePath)

      result = content.dup
      nextResult = result.dup

      loop do
        if !result.any? { |line| line.starts_with?(ISM::Default::Software::KconfigKeywords[:source]) }
          break
        end

        nextResult.clear

        result.each do |line|
          if line.starts_with?(ISM::Default::Software::KconfigKeywords[:source]) && !line.includes?("Kconfig.include")
            mainArchitecture = (Ism.settings.installByChroot ? Ism.settings.chrootArchitecture : Ism.settings.architecture).gsub(/_.*/, "")

            path = kernelSourcesPath + line
            path = path.gsub(ISM::Default::Software::KconfigKeywords[:source], "")
            path = path.gsub("\"", "")
            path = path.gsub("$(SRCARCH)", "#{mainArchitecture}")
            path = path.gsub("$(HEADER_ARCH)", "#{mainArchitecture}")

            begin
              temp = File.read_lines(path)
              nextResult += temp
            rescue
              nextResult += Array(String).new
            end
          elsif line.starts_with?(ISM::Default::Software::KconfigKeywords[:source]) && line.includes?("Kconfig.include")
            nextResult += Array(String).new
          else
            nextResult.push(line)
          end
        end

        result = nextResult.dup
      end

      result
    end

    def generateKernelOptionsFiles(kconfigContent : Array(String))
      kernelOption = ISM::KernelOption.new
      kernelOptions = Array(ISM::KernelOption).new

      lastIfIndex = 0
      lastEndIfIndex = 0
      lastMenuConfigIndex = 0
      lastIfContent = String.new
      lastMenuConfigContent = String.new

      kconfigContent.each_with_index do |line, index|
        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:menuconfig]) || line.starts_with?(ISM::Default::Software::KconfigKeywords[:config]) || line.starts_with?(ISM::Default::Software::KconfigKeywords[:if]) || line.starts_with?(ISM::Default::Software::KconfigKeywords[:endif])
          if index > 0
            # IF LAST DEPENDENCY IS A MENUCONFIG
            if lastIfIndex < lastEndIfIndex || lastIfIndex > lastEndIfIndex && lastMenuConfigIndex > lastIfIndex
              kernelOption.dependencies = kernelOption.dependencies + [lastMenuConfigContent]
            end

            # IF LAST DEPENDENCY IS A IF
            if lastIfIndex > lastEndIfIndex && lastIfIndex > lastMenuConfigIndex
              kernelOption.dependencies = kernelOption.dependencies + [lastIfContent]
            end

            kernelOptions.push(kernelOption.dup)
          end

          kernelOption = ISM::KernelOption.new
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:menuconfig])
          lastMenuConfigIndex = index
          lastMenuConfigContent = line.gsub(ISM::Default::Software::KconfigKeywords[:menuconfig], "")
          kernelOption.name = line.gsub(ISM::Default::Software::KconfigKeywords[:menuconfig], "")
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:config])
          kernelOption.name = line.gsub(ISM::Default::Software::KconfigKeywords[:config], "")
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:bool])
          kernelOption.tristate = false
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:tristate])
          kernelOption.tristate = true
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:dependsOn])
          newDependencies, newSingleChoiceDependencies, newBlockers = parseKconfigConditions(line.gsub(ISM::Default::Software::KconfigKeywords[:dependsOn], ""))

          kernelOption.dependencies += newDependencies
          kernelOption.singleChoiceDependencies += newSingleChoiceDependencies
          kernelOption.blockers += newBlockers
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:select])
          newDependencies, newSingleChoiceDependencies, newBlockers = parseKconfigConditions(line.gsub(ISM::Default::Software::KconfigKeywords[:select], ""))

          kernelOption.dependencies += newDependencies
          kernelOption.singleChoiceDependencies += newSingleChoiceDependencies
          kernelOption.blockers += newBlockers
        end

        if line.starts_with?(ISM::Default::Software::KconfigKeywords[:if])
          lastIfIndex = index
          lastIfContent = line.gsub(ISM::Default::Software::KconfigKeywords[:if], "")
        end
      end

      kernelOptions.each do |option|
        if !option.name.empty?
          option.writeInformationFile(Ism.settings.rootPath + ISM::Default::Path::KernelOptionsDirectory + "/" + kernelName + "/" + option.name + ".json")
        end
      end
    end

    def updateKernelOptionsDatabase
      Ism.notifyOfUpdateKernelOptionsDatabase(@information)

      if !Dir.exists?(kernelOptionsDatabasePath)
        makeDirectory(kernelOptionsDatabasePath)

        begin
          generateKernelOptionsFiles(getFullKernelKconfigFile(kernelKconfigFilePath))
          generateKernelOptionsFiles(getFullKernelKconfigFile(kernelArchitectureKconfigFilePath))
        rescue error
          deleteDirectory(kernelOptionsDatabasePath)

          Ism.notifyOfUpdateKernelOptionsDatabaseError(@information, error)
          Ism.exitProgram
        end
      end
    end

    def recordNeededKernelFeatures
      Ism.notifyOfRecordNeededKernelFeatures(@information)
      Ism.neededKernelFeatures += @information.kernelDependencies
    end

    def clean
      Ism.notifyOfClean(@information)
      cleanWorkDirectoryPath
    end

    def cleanWorkDirectoryPath
      if Dir.exists?(workDirectoryPath(false))
        deleteDirectoryRecursively(workDirectoryPath(false))
      end

      makeDirectory(workDirectoryPath(false))
    end

    def recordUnneededKernelFeatures
      Ism.notifyOfRecordUnneededKernelFeatures(@information)
      Ism.unneededKernelFeatures += @information.kernelDependencies
    end

    def showInformations
      puts
      Ism.printInformationNotificationTitle(@information.name, @information.version)
    end

    def uninstall
      Ism.notifyOfUninstall(@information)
      Ism.removeInstalledSoftware(@information)
    end

    def option(optionName : String) : Bool
      @information.option(optionName)
    end

    def softwareIsInstalled(softwareName : String) : Bool
      Ism.softwareAnyVersionInstalled(softwareName)
    end

    def architecture(architecture : String) : Bool
      Ism.settings.architecture == architecture
    end

    def showInfo(message : String)
      Ism.printInformationNotification(message)
    end

    def showInfoCode(message : String)
      Ism.printInformationCodeNotification(message)
    end
  end
end
