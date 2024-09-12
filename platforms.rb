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
end

platform "debian" do
  major_only true
end

platform "ubuntu"

# NB: this platform name is deprecated, convert to using "darwin" like ohai
# If we don't have an arm64 build yet, fall back to x86_64
platform "mac_os_x" do
  fallback_arch "x86_64"
end

platform "solaris2"

platform "smartos" do
  remap "solaris2"
  version_remap "5.10"
end

# We map all the windows versions to 2008r2
platform "windows"

platform "freebsd" do
  major_only true
end

platform "redhat" do
  major_only true
  remap "el"
end

platform "aix"

platform "nexus" do
  major_only true
end

platform "ios_xr" do
  major_only true
end

platform "darwin" do
  remap "mac_os_x"
end

platform "sled" do
  major_only true
  remap "sles"
end

platform "suse" do
  major_only true
  remap "sles"
end

platform "opensuse-leap" do
  major_only true
  remap "sles"
end

platform "sles" do
  major_only true
end


# Supported RHEL Variants
#
# These are RHEL clones that we know will work + SuSE that we test on
#

platform "rocky"

platform "centos" do
  major_only true
  remap "el"
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


platform "amazon" do
   # map "version 2" amazon linux and amazon linux 2 to amazon
    if product == "chef-server" && version >= "15.10.12"
      major_only true
    else
    remap do |opts|
      # map "version 1" amazon linux and amazon linux 2 to RHEL
      if /201\d\.\d/.match?(opts[:version]) || opts[:version] == "2"
        "el"
      else
        "amazon"
      end
    end

    version_remap do |opts|
      if /201\d\.\d/.match?(opts[:version])
        # map "version 1" amazon linux to RHEL 6. These are named by the year/month ubuntu style
        "6"
      elsif opts[:version] == "2"
        # map Amazon Linux 2 to RHEL 7
        "7"
      else
        opts[:version]
      end
    end
  end
end
# Unsupported Variants
#
platform "xenserver" do
  remap "el"
  major_only true
end

platform "coreos" do
  remap "el"
  version_remap 6
end

platform "fedora" do
  remap "el"
  version_remap do |opts|
    # A combo of Fedora 19/20 was used to create RHEL 7 so when we're on Fedora 20 use the RHEL 7 packages
    # https://docs.fedoraproject.org/quick-docs/en-US/fedora-and-red-hat-enterprise-linux.html
    (opts[:version].to_i >= 20) ? "7" : "6"
  end
end

platform "linuxmint" do
  remap "ubuntu"
  version_remap do |opts|
    minor_rev = ( opts[:version].to_i % 2 == 0 ) ? "10" : "04"
    major_rev = ( (opts[:version].to_i + 11) / 2 ).floor.to_s
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

platform "arista_eos" do
  major_only true
  remap "el"
  version_remap 6
end

# cumulus linux 3.0.0 and later is debian 8
platform "cumulus_linux" do
  remap "debian"
  version_remap do |opts|
    (opts[:version].split('.')[0].to_i >= 3) ? "8" : "7"
  end
end

platform "cumulus_networks" do
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
