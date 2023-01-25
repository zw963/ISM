module ISM

    module Default

        module Option

            module SoftwareRemove

                ShortText = "-r"
                LongText = "remove"
                Description = "Remove specific(s) software(s)"
                CalculationTitle = "ISM start to calculate depencies: "
                CalculationWaitingText = "Checking dependencies tree"
                CalculationDoneText = "Done !"
                DependOfText = " depend of "
                SummaryText = " softwares will be uninstall"
                UninstallQuestion = "Would you like to uninstall these softwares ?"
                YesReplyOption = "y"
                NoReplyOption = "n"
                UninstallingText = "Uninstalling"
                NotInstalledText = "All requested softwares are not installed. Task cancelled."
                RequestedSoftwaresAreDependenciesText = "Removal impossible for some requested softwares. Task cancelled."
                NoInstalledMatchFound = "No match found with the database for "
                NoInstalledMatchFoundAdvice = "Maybe it's needed of refresh the database?"
                RequestedSoftwaresAreDependencies = "Some requested softwares are dependencies for others installed softwares:"
                RequestedSoftwaresAreDependenciesAdvice = "If you really would like to remove them, remove them first."
                UninstalledText = "is uninstalled"

            end
            
        end

    end

end
