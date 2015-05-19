#!/usr/bin/env python

import atexit
import glob
import os
import re
import shutil
import sys
import tempfile
import textwrap

from fabric.api import env, local, hide
from fabric.context_managers import lcd, settings, shell_env
from fabric.contrib.console import confirm
from fabric.contrib.files import exists
from fabric.decorators import runs_once
from fabric.utils import abort
from fabric import colors

sys.path.append('scripts')
from string_scripts.confirm_ready_for_release import confirm_ready_for_release as _confirm_ready_for_release


# --- Configuration ---------------------------------------------------------

env.verbose = False
env.libname = "libCardIO.a"
env.developer_dir = local("xcode-select -p", capture=True)

# --- Tasks -----------------------------------------------------------------


def verbose(be_verbose=True):
    """
    Makes all following tasks more verbose.
    """
    env.verbose = be_verbose


def developer_dir(dir):
    """
    Sets DEVELOPER_DIR environment variable to correct Xcode
    For example, `fab developer_dir:"/Applications/Xcode6.2.app"
    """
    if os.path.exists(dir):
        env.developer_dir = dir
    else:
        print(colors.red("{dir} is not a valid path".format(dir=dir), bold=True))
        sys.exit(1)


def _locate(fileset, root=os.curdir):
    # based on http://code.activestate.com/recipes/499305-locating-files-throughout-a-directory-tree/
    """
    Locate supplied files in supplied root directory.
    """
    for path, dirs, files in os.walk(os.path.abspath(root)):
        for filename in files:
            if filename in fileset:
                yield os.path.join(path, filename)


def _add_version_to_header_file(version_str, file):
    lines = []
    for line in file.readlines():
        lines.append(line)
        m = re.match("^(//\s+)CardIO.*\.h$", line)
        if m:
            lines.append("{0}Version {1}\n".format(m.groups()[0], version_str))
            lines.append("//\n")
    file.seek(0)
    file.truncate()
    for line in lines:
        file.write(line)


def _version_str(show_dirty=False):
    git_describe_cmd = "git describe --match='iOS_[0-9]*.[0-9]*' --tags --always --dirty"
    version_str = local(git_describe_cmd, capture=True).strip()[4:]
    if not show_dirty:
        version_str = version_str.replace('-dirty', '')
    return version_str


def _copy(source_files, dest_dir):
    for public_header_file in source_files:
        with open(public_header_file, "rb") as in_file:
            contents = in_file.read()
        unused, header_filename = os.path.split(public_header_file)
        header_filename = os.path.join(dest_dir, header_filename)
        with open(header_filename, "wb") as out_file:
            out_file.write(contents)
        with open(header_filename, "r+") as out_file:
            _add_version_to_header_file(_version_str(), out_file)


def build(outdir=None, device_sdk=None, simulator_sdk=None, **kwargs):
    """
    Build card.io SDK.
    """
    print(colors.white("Setup", bold=True))

    to_hide = [] if env.verbose else ["stdout", "stderr", "running"]

    xcode_preprocessor_flags = {}

    if not outdir:
        message = """
                     You must provide outdir=<sdk output parent dir>
                     Example usage:
                       `fab build:outdir=~` - normal build
                       `fab build:outdir=~,SCAN_EXPIRY=0` - to disable the experimental expiry-scan feature
                  """
        abort(textwrap.dedent(message).format(**locals()))

    if _confirm_ready_for_release("assets/strings"):
		sys.exit(1)

    outdir = os.path.abspath(os.path.expanduser(outdir))
    print colors.yellow("Will save release sdk to {outdir}".format(outdir=outdir))
    out_subdir = "card.io_ios_sdk_{0}".format(_version_str(show_dirty=True))

    xcode_preprocessor_flags.update(kwargs)
    formatted_xcode_preprocessor_flags = " ".join("{k}={v}".format(k=k, v=v) for k, v in xcode_preprocessor_flags.iteritems())
    extra_xcodebuild_settings = "GCC_PREPROCESSOR_DEFINITIONS='$(value) {formatted_xcode_preprocessor_flags}'".format(**locals())

    device_sdk = device_sdk or "iphoneos"
    simulator_sdk = simulator_sdk or "iphonesimulator"

    arch_to_sdk = (("armv7", device_sdk),
                   ("armv7s", device_sdk),
                   ("arm64", device_sdk),
                   ("i386", simulator_sdk),
                   ("x86_64", simulator_sdk)
                  )

    with settings(hide(*to_hide)):
        icc_root = local("git rev-parse --show-toplevel", capture=True)

    temp_dir = tempfile.mkdtemp() + os.sep
    atexit.register(shutil.rmtree, temp_dir, True)

    print(colors.white("Preparing dmz", bold=True))
    with settings(hide(*to_hide)):
        with lcd(os.path.join(icc_root, "dmz")):
            dmz_all_filename = os.path.join("dmz", "dmz_all.cpp")
            with open(dmz_all_filename) as f:
                old_dmz_all = f.read()
            local("fab concat")
            with open(dmz_all_filename) as f:
                new_dmz_all = f.read()
            if old_dmz_all != new_dmz_all:
                print(colors.red("WARNING: dmz_all.h was not up to date!", bold=True))
    
    print(colors.white("Building", bold=True))
    print(colors.white("Using temp dir {temp_dir}".format(**locals())))
    print(colors.white("Using extra Xcode flags: {formatted_xcode_preprocessor_flags}".format(**locals())))
    print(colors.white("Using developer directory: {}".format(env.developer_dir)))

    with lcd(icc_root):
        with shell_env(DEVELOPER_DIR=env.developer_dir):
            with settings(hide(*to_hide)):
                lipo_build_dirs = {}
                build_config = "Release"
                arch_build_dirs = {}
                for arch, sdk in arch_to_sdk:
                    print(colors.blue("({build_config}) Building {arch}".format(**locals())))

                    base_xcodebuild_command = "xcrun xcodebuild -target CardIO -arch {arch} -sdk {sdk} -configuration {build_config}".format(**locals())

                    clean_cmd =  "{base_xcodebuild_command} clean".format(**locals())
                    local(clean_cmd)

                    build_dir = os.path.join(temp_dir, build_config, arch)
                    arch_build_dirs[arch] = build_dir
                    os.makedirs(build_dir)
                    parallelize = "" if env.verbose else "-parallelizeTargets"  # don't parallelize verbose builds, it's hard to read the output
                    build_cmd = "{base_xcodebuild_command} {parallelize} CONFIGURATION_BUILD_DIR={build_dir}  {extra_xcodebuild_settings}".format(**locals())
                    local(build_cmd)

                print(colors.blue("({build_config}) Lipoing".format(**locals())))
                lipo_dir = os.path.join(temp_dir, build_config, "universal")
                lipo_build_dirs[build_config] = lipo_dir
                os.makedirs(lipo_dir)
                arch_build_dirs["universal"] = lipo_dir
                # in Xcode 4.5 GM, xcrun selects the wrong lipo to use, so circumventing xcrun for now :(
                lipo_cmd = "`xcode-select -print-path`/Platforms/iPhoneOS.platform/Developer/usr/bin/lipo " \
                           "           {armv7}/{libname}" \
                           "           -arch armv7s {armv7s}/{libname}" \
                           "           -arch arm64 {arm64}/{libname}" \
                           "           -arch i386 {i386}/{libname}" \
                           "           -arch x86_64 {x86_64}/{libname}" \
                           "           -create" \
                           "           -output {universal}/{libname}".format(libname=env.libname, **arch_build_dirs)
                local(lipo_cmd)

                print(colors.blue("({build_config}) Stripping debug symbols".format(**locals())))
                strip_cmd = "xcrun strip -S {universal}/{libname}".format(libname=env.libname, **arch_build_dirs)
                local(strip_cmd)

                out_subdir_suffix = "_".join("{k}-{v}".format(k=k, v=v) for k, v in kwargs.iteritems())
                if out_subdir_suffix:
                    out_subdir_suffix = "_" + out_subdir_suffix
                out_subdir += out_subdir_suffix
                sdk_dir = os.path.join(outdir, out_subdir)

                print(colors.white("Assembling release SDK in {sdk_dir}".format(sdk_dir=sdk_dir), bold=True))
                if os.path.isdir(sdk_dir):
                    shutil.rmtree(sdk_dir)
                cardio_dir = os.path.join(sdk_dir, "CardIO")
                os.makedirs(cardio_dir)

                header_files = glob.glob(os.path.join("CardIO_Public_API", "*.h"))
                _copy(header_files, cardio_dir)

                libfile = os.path.join(lipo_build_dirs["Release"], env.libname)
                shutil.copy2(libfile, cardio_dir)

                release_dir = os.path.join(icc_root, "Release")
                shutil.copy2(os.path.join(release_dir, "release_notes.txt"), sdk_dir)
                shutil.copy2(os.path.join(release_dir, "CardIO.podspec"), sdk_dir)
                shutil.copy2(os.path.join(release_dir, "acknowledgments.md"), sdk_dir)
                shutil.copy2(os.path.join(release_dir, "LICENSE.md"), sdk_dir)
                shutil.copy2(os.path.join(release_dir, "README.md"), sdk_dir)
                shutil.copytree(os.path.join(release_dir, "SampleApp"), os.path.join(sdk_dir, "SampleApp"), ignore=shutil.ignore_patterns(".DS_Store"))
                shutil.copytree(os.path.join(release_dir, "SampleApp-Swift"), os.path.join(sdk_dir, "SampleApp-Swift"), ignore=shutil.ignore_patterns(".DS_Store"))
