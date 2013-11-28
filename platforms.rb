#
# We now support the same platform names that ohai uses, please
# keep this API consistent with ohai.  The old "el" platform is still
# canonical for redhat, but should be considered deprecated.
#


# BASE platform classes
#
# - these are first-class platforms that we have builders and testers for
#
platform "el" do
  major_only true
end

platform "debian" do
  major_only true
end

platform "ubuntu"

platform "mac_os_x"

platform "solaris2"

platform "windows"

platform "freebsd" do
  major_only true
end

platform "redhat" do
  major_only true
  remap "el"
end

platform "centos" do
  major_only true
  remap "el"
end

platform "aix" do
  major_only true
end

# Supported Variants
#
# These are RHEL clones that we know will work + SuSE that we test on
#
platform "enterpriseenterprise" do  # alias for "oracle"
  major_only true
  remap "el"
end

platform "oracle" do
  major_only true
  remap "el"
end

platform "scientific" do
  major_only true
  remap "el"
end

platform "suse" do
  remap "el"
  # FIXME: with some old enough version we should return 5
  version_remap 6
end

platform "sles" do
  remap "el"
  # FIXME: with some old enough version we should return 5
  version_remap 6
end

# Unsupported Variants
#
# These most likely work, everything below this line has yolo on for all versions
# so that it prints a warning when installing.
#
platform "xenserver" do
  yolo true
  remap "el"
  version_remap 5
end

platform "amazon" do
  yolo true
  remap "el"
  # FIXME: with some old enough version we should return 5
  version_remap 6
end

platform "fedora" do
  yolo true
  remap "el"
  # FIXME: with some old enough version we should return 5
  version_remap 6
end

platform "linuxmint" do
  yolo true
  remap "ubuntu"
  version_remap do |version|
    minor_rev = ( version.to_i % 2 == 0 ) ? "10" : "04"
    major_rev = ( (version.to_i + 11) / 2 ).floor.to_s
    "#{major_rev}.#{minor_rev}"
  end
end

# this'll magically work if we ever publish ARM debian builds
platform "raspbian" do
  yolo true
  remap "debian"
end

# these are unsupported because we have no build infrastructure for them:
# - slackware
# - arch
# - gentoo
# - debian/ubuntu/rhel ARM/PPC
# - redhat ARM/PPC

