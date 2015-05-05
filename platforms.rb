#
# We now support the same platform names that ohai uses, please
# keep this API consistent with ohai.  The old "el" platform is still
# canonical for redhat, but should be considered deprecated.
#


# BASE platform classes
#
# - these are first-class platforms that we have builders and testers for
#

# NB: this platform name is deprecated, convert to using "redhat" like ohai
platform "el" do
  major_only true
  yolo true
end

platform "debian" do
  major_only true
end

platform "ubuntu"

# NB: this platform name is deprecated, convert to using "darwin" like ohai
platform "mac_os_x"

platform "solaris2"

platform "smartos" do
  remap "solaris2"
  version_remap "5.10"
end

platform "windows"

platform "freebsd" do
  major_only true
end

platform "redhat" do
  yolo true
  major_only true
  remap "el"
end

platform "centos" do
  yolo true
  major_only true
  remap "el"
end

platform "aix"

# Supported Variants
#
# These are RHEL clones that we know will work + SuSE that we test on
#

platform "darwin" do
  remap "mac_os_x"
end

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
  major_only true
  remap "el"
  version_remap do |version|
    version.to_f <= 11 ? "5" : "6"
  end
end

platform "sles" do
  major_only true
  remap "el"
  version_remap do |version|
    version.to_f <= 10 ? "5" : "6"
  end
end

platform "amazon" do
  remap "el"
  # FIXME: with some old enough version we should return 5
  version_remap 6
end

# Unsupported Variants
#
platform "xenserver" do
  remap "el"
  version_remap 5
end

platform "coreos" do
  remap "el"
  version_remap 6
end

platform "fedora" do
  remap "el"
  # FIXME: with some old enough version we should return 5
  version_remap 6
end

platform "linuxmint" do
  remap "ubuntu"
  version_remap do |version|
    minor_rev = ( version.to_i % 2 == 0 ) ? "10" : "04"
    major_rev = ( (version.to_i + 11) / 2 ).floor.to_s
    "#{major_rev}.#{minor_rev}"
  end
end

# Univention Corporate Server is predominantly used in German
# FIXME: version_remapping to correct debian version ideally needed
platform "univention" do
  remap "debian"
  version_remap 6
end

# this'll magically work if we ever publish ARM debian builds
platform "raspbian" do
  remap "debian"
end

# see #81
platform "cumulus networks" do
  remap "debian"
  version_remap 7
end

# these are unsupported because we have no build infrastructure for them:
# - slackware
# - arch
# - gentoo
# - debian/ubuntu/rhel ARM/PPC
# - redhat ARM/PPC
# - HPUX
# - openbsd
# - netbsd
