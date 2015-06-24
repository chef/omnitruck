Chef::Log.level = :info

install_dir = '/opt/chefdk'
install_env = {
  "LDFLAGS" => "-Wl,-rpath,#{install_dir}/embedded/lib -L#{install_dir}/embedded/lib",
  "CFLAGS" => "-I#{install_dir}/embedded/include",
}

remote_install 'postgresql' do
  source 'http://ftp.postgresql.org/pub/source/v9.3.4/postgresql-9.3.4.tar.gz'
  checksum '7155b94c2abec7d05638463839ff403fdee8274d72a2bd280a7becdee4941540'
  version '9.3.4'
  build_command "./configure" \
    " --prefix=#{install_dir}/embedded" \
    " --with-libedit-preferred" \
    " --with-openssl --with-includes=#{install_dir}/embedded/include" \
    " --with-libraries=#{install_dir}/embedded/lib"
  compile_command "make -j #{node['cpu']['total']}"
  install_command "make install"
  environment install_env
  not_if { File.exist?("#{install_dir}/embedded/lib/libpg.so") }
end

