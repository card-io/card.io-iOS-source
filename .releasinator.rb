#### releasinator config ####
configatron.product_name = "card.io iOS SDK "

# The directory where all distributed docs are.  Default is '.'
configatron.base_docs_dir = 'Release'

configatron.release_to_github = false

configatron.use_git_flow = true

# List of items to confirm from the person releasing.  Required, but empty list is ok.
configatron.prerelease_checklist_items = [
  "Test on a device in release mode",
  "Check the header files.",
  "Sanity check the develop branch.",
]

def no_task(version="")
end

def podspec_version()
  File.open("Release/CardIO.podspec", 'r') do |f|
    f.each_line do |line|
      if line.match (/spec.version\s*=\s*'\d*\.\d*\.\d*'/)
        return line.strip.split('\'')[1]
      end
    end
  end
  return 0
end  

def validate_podspec_version()
  if podspec_version() != @current_release.version
    Printer.fail("podspec version #{podspec_version()} does not match changelog version #{@current_release.version}.")
    abort()
  end
    Printer.success("podspec version #{podspec_version()} matches latest changelog version #{@current_release.version}.")
end

def validate_paths()
  @validator.validate_in_path("pip")
  @validator.validate_in_path("virtualenv")
  @validator.validate_in_path("type mkvirtualenv")
end

# Custom validation methods.  Optional.
configatron.custom_validation_methods = [
  method(:validate_paths),
  method(:validate_podspec_version)
]

# build process moved to releasinator.sh file 
def build_cardio()
  CommandProcessor.command("VERSION=#{@current_release.version} ./releasinator.sh", live_output=true)
end

# The method that builds the sdk.  Required.
configatron.build_method = method(:build_cardio)

# steps to push cocoapods moved after downstreamrepo code push
def publish_to_cocoapods()
  command = "cd downstream_repos/card.io-iOS-SDK;"
  command += "pod trunk push CardIO.podspec"
  
  CommandProcessor.command(command, live_output=true)
end

# The method that publishes the sdk to the package manager.  Required.
configatron.publish_to_package_manager_method = method(:no_task)

def wait_for_cocoapods()
    CommandProcessor.wait_for("wget -U \"non-empty-user-agent\" -qO- https://github.com/CocoaPods/Specs/blob/master/Specs/CardIO/#{podspec_version()}/CardIO.podspec.json | cat")
end

# the method that waits for published artifact 
configatron.wait_for_package_manager_method = method(:no_task)

def add_content_to_file (filepath, location, new_content)
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

def update_cordova_plugin_release_notes(new_version)
  current_changelog = @current_release.changelog.dup
  add_content_to_file("CHANGELOG.md", "===================================", "TODO\n")
  add_content_to_file("CHANGELOG.md", "TODO", "-----\n")
  add_content_to_file("CHANGELOG.md", "-----", (current_changelog.gsub! /^\*/,'* iOS:')+"\n\n")
end

def build_app()
  CommandProcessor.command("pod lib lint", live_output=true)
end 

# Distribution GitHub repo if different from the source repo. Optional.
configatron.downstream_repos = [
  DownstreamRepo.new(
    name="card.io-iOS-SDK",
    url="git@github.com:card-io/card.io-iOS-SDK.git",
    branch="master",
    :release_to_github => true,
    :full_file_sync => false,
    :files_to_copy => [
      CopyFile.new("card.io_ios_sdk_#{podspec_version}*/*", ".", ".")
    ],
    :build_methods => [
      method(:build_app)
    ]
  ),
  DownstreamRepo.new(
    name="card.io-Cordova-Plugin",
    url="git@github.com:card-io/card.io-Cordova-Plugin.git",
    branch="master",
    :full_file_sync => false,
    :release_to_github => true,
    :new_branch_name => "ios-__VERSION__",
    :files_to_copy => [
      CopyFile.new("card.io_ios_sdk_#{podspec_version}\*/CardIO/*", ".", "src/ios/CardIO")
    ],
    :post_copy_methods => [
      method(:update_cordova_plugin_release_notes)
    ]
  )
]

task :"local:push" do
  publish_to_cocoapods()
  wait_for_cocoapods()
end  
