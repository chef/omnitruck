module OmnitruckDist
  # This class is not fully implemented, depending it is not recommended!
  # Client name
  CLIENT_NAME = "chef".freeze
  # Here we map specific project versions that started building
  # native SLES packages. This is used to determine which projects
  # need to be remapped to EL before a certain version.
  SLES_PROJECT_VERSIONS = {
    "automate" => "0.8.5",
    "chef" => "12.21.1",
    "angrychef" => "12.21.1",
    "chef-server" => "12.14.0",
    "chefdk" => "1.3.43",
    "inspec" => "1.20.0",
    "angry-omnibus-toolchain" => "1.1.66",
    "omnibus-toolchain" => "1.1.66",
  }.freeze
end
