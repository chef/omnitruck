#
# Cookbook Name:: build-cookbook
# Library:: _helper
#
# Copyright (C) Chef Software, Inc. 2015
#
include Chef::Mixin::DeepMerge

Chef::Resource.send(:include, Chef::Mixin::ShellOut)

def bundler_cache_dir
  File.join(
    node['delivery']['workspace']['root'],
    'bundler-cache'
  )
end

def load_data_bag_item(data_bag, item)
  dbag = Chef::DataBag.new
  dbag.name(data_bag)
  dbag.save
  dbag_data = Chef::JSONCompat.from_json(File.read(File.join(File.dirname(__FILE__), "..", "files", "data_bags", data_bag, "#{item}.json")))
  dbag_item = Chef::DataBagItem.new
  dbag_item.data_bag(data_bag)
  dbag_item.raw_data = dbag_data
  dbag_item.save
end

def make_link(url)
  "<a href=\"#{url}\">#{url}</a>"
end

def change_url
  "https://delivery.chef.co/e/#{node['delivery']['change']['enterprise']}/#/organizations/#{node['delivery']['change']['organization']}/projects/#{node['delivery']['change']['project']}/changes/#{node['delivery']['change']['change_id']}/status/verify"
end


def prev_stage(stage)
  case stage
  when 'build'
    nil
  when 'acceptance'
    'build'
  when 'union'
    'acceptance'
  when 'rehearsal'
    'union'
  when 'delivered'
    'rehearsal'
  end
end

def next_stage(stage)
  case stage
  when 'build'
    'acceptance'
  when 'acceptance'
    'union'
  when 'union'
    'rehearsal'
  when 'rehearsal'
    'delivered'
  when 'delivered'
    nil
  end
end

def instance_quantity
  if delivered_stage?
    3
  else
    3
  end
end

def delivered_stage?
  if node['delivery']['change']['stage'] == 'delivered'
    true
  else
    false
  end
end

def sns_topic
  if delivered_stage?
    'arn:aws:sns:us-west-2:109983887395:cia-alert'
  else
    'arn:aws:sns:us-west-2:109983887395:cia-notify'
  end
end

def machine_opts(instance_num)
  deep_merge(
    CIAInfra.machine_options(node, 'us-west-2', instance_num),
    convergence_options: {
      chef_server: chef_server_details
    }
  )
end
