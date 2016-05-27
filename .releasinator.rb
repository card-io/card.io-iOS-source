#### releasinator config ####
configatron.product_name = "card.io iOS SDK "

# List of items to confirm from the person releasing.  Required, but empty list is ok.
configatron.prerelease_checklist_items = [
  "Test on a device in release mode.",
  "Sanity check the master branch.",
  "Review the release folder contents."
]

def podspec_version()
  File.open("Release/CardIO.podspec", 'r') do |f|
    f.each_line do |line|
      puts line
      if line.match (/spec.version          = '\d*\.\d*\.\d*'/)
        puts line
        return line.strip.split('\'')[1]
      end
    end
  end
end  

def validate_podspec_version()
  if podspec_version() != @current_release.version
    Printer.fail("podspec version #{podspec_version} does not match changelog version #{@current_release.version}.")
    abort()
  end
    Printer.success("podspec version version #{podspec_version} matches latest changelog version #{@current_release.version}.")
end

def validate_paths
  @validator.validate_in_path("pip")
  @validator.validate_in_path("virtualenv")
  @validator.validate_in_path("type mkvirtualenv")
end

def validate_virtualenvwrapper
  if !File.exist?("/usr/local/bin/virtualenvwrapper.sh")
    Printer.fail("mkvirtualenv is not setup in this system")
    abort()
  end 
    Printer.success("mkvirtualenv setup properly in this system")
end 

# Custom validation methods.  Optional.
configatron.custom_validation_methods = [
  method(:validate_paths),
  method(:validate_virtualenvwrapper),
  method(:validate_podspec_version)
]

# The directory where all distributed docs are.  Default is '.'
configatron.base_docs_dir = 'Release'

configatron.release_to_github = false

configatron.use_git_flow = true

def build_cardio()
  CommandProcessor.command("VERSION=#{@current_release.version} ./releasinator.sh", live_output=true)
  
  # below step failing need to understand why it is failing 
  #CommandProcessor.command("pod lib lint", live_output=true)
end

# The method that builds the sdk.  Required.
configatron.build_method = method(:build_cardio)

# all the code moved to sumodule so this is just empty function 
def publish_to_cocoapods(version)
  #if File.exist?(File.expand_path("..", Dir.pwd)+"/card.io-iOS-SDK")
  #  CommandProcessor.command("rm -rf "+File.expand_path("..", Dir.pwd)+"/card.io-iOS-SDK", live_output=true)
  #end 
  #CommandProcessor.command("git clone git@github.com:card-io/card.io-iOS-SDK.git "+ File.expand_path("..", Dir.pwd)+"/card.io-iOS-SDK", live_output=true)
  #copy all file from relesae folder  to sdk folder 
  
  #CommandProcessor.command("python -u "+File.expand_path("pod trunk push CardIO.podspec ..", Dir.pwd)+"/card.io-iOS-SDK", live_output=true)
end

# The method that publishes the sdk to the package manager.  Required.
configatron.publish_to_package_manager_method = method(:publish_to_cocoapods)

def wait_for_cocoapods(version)
  # need to get wait for cocopods command  
end

# the method that waits for published artifact 
configatron.wait_for_package_manager_method = method(:wait_for_cocoapods)

def replace_version(new_tag)
  replace_string("./SampleApp/build.gradle", "REPLACE_VERSION", "#{new_tag}")
  replace_string("./README.md", "REPLACE_VERSION", "#{new_tag}")
end

def replace_gradle_package(filename, package_id, version)
  regex = /#{package_id}:\d\d*\.\d\d*\.\d\d*/
  replace_string(filename, regex, "#{package_id}:#{version}")
end

def replace_version_in_cordova(version)
  replace_gradle_package("src/android/build.gradle", "io.card:android-sdk", version)
end

def add_new_line (filepath, location, new_content)
  require 'fileutils'
  tempfile=File.open("file.tmp", 'w')
  File.open(filepath, 'r') do |f|
    f.each_line do |line|
      tempfile<<line
      if line.strip == location.strip
        tempfile << new_content
      end
    end
  end
  tempfile.close
  FileUtils.mv("file.tmp", filepath)
end

def update_release_notes(new_version)
  add_new_line("CHANGELOG.md", "===================================", "TODO\n")
  add_new_line("CHANGELOG.md", "TODO", "-----\n")
  add_new_line("CHANGELOG.md", "-----", (@current_release.changelog.gsub! /^\*/,'* iOS:')+"\n\n")
end

def compile_sample_app()
  Dir.chdir("SampleApp") do
    CommandProcessor.command("gradlew clean assembleDebug", live_output=true)
  end
end

def build_app()
  CommandProcessor.command("pod lib lint", live_output=true)
  CommandProcessor.command("pod trunk push CardIO.podspec", live_output=true)
end 

# Distribution GitHub repo if different from the source repo. Optional.
configatron.downstream_repos = [
  DownstreamRepo.new(
    name="card.io-iOS-SDK",
    url="git@github.com:sankarbhavanib/card.io-iOS-SDK.git",
    branch="master",
    :release_to_github => true,
    :full_file_sync => true,
    :files_to_copy => [
      CopyFile.new("card.io_ios_sdk_#{podspec_version}*/*", ".", ".")
    ],
    :build_methods => [
      method(:build_app)
    ]
  ),
  DownstreamRepo.new(
    name="card.io-Cordova-Plugin",
    url="git@github.com:sankarbhavanib/card.io-Cordova-Plugin.git",
    branch="master",
    :full_file_sync => true,
    :release_to_github => true,
    :new_branch_name => "ios-__VERSION__",
    :files_to_copy => [
      CopyFile.new("card.io_ios_sdk_#{podspec_version}*/CardIO/*", ".", "src/ios/CardIO/")
    ],
    :post_copy_methods => [
      method(:replace_version_in_cordova),
      method(:update_release_notes)
    ]
  )
]