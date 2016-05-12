#
# Cookbook Name:: omnitruck
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'omnitruck::_users'
include_recipe 'cia_infra::ruby'
include_recipe 'omnitruck::_nginx'
include_recipe 'omnitruck::_application'
