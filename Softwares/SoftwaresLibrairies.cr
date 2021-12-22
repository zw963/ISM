require "colorize"
require "json"
require "../ISM/Default/SoftwareOption"
require "../ISM/SoftwareOption"
require "../ISM/Default/SoftwareDependency"
require "../ISM/SoftwareDependency"
require "../ISM/Default/SoftwareInformation"
require "../ISM/SoftwareInformation"
require "../ISM/Default/AvailableSoftware"
require "../ISM/AvailableSoftware"
require "../ISM/Default/Software"
require "../ISM/Software"
require "../ISM/Default/CommandLineOption"
require "../ISM/CommandLineOption"
require "../ISM/Default/CommandLineSettings"
require "../ISM/CommandLineSettings"
require "../ISM/Default/CommandLineSystemSettings"
require "../ISM/CommandLineSystemSettings"
require "../ISM/Default/CommandLine"
require "../ISM/CommandLine"

Ism = ISM::CommandLine.new
Ism.loadSoftwareDatabase
Ism.loadSettingsFiles