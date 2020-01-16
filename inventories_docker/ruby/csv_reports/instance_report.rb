require 'optparse'
require 'aws-sdk-ec2'  # v2: require 'aws-sdk'
require_relative 'report_helper'
require 'csv'

def get_instance_hash(instance, region)
  image = instance.image
  image_name = "NA"
  begin
    image_name = image.name
  rescue NoMethodError => e
    $stderr.write("Could not get name for image: #{image}. Skipping (problem: #{e})\n")
  end
  vpc = instance.vpc
  vpc_tag_dict = convert_list_of_tag_dicts_to_dict(vpc)
  vpc_name = vpc_tag_dict.fetch("Name", "")
  instance_tag_dict = convert_list_of_tag_dicts_to_dict(instance)
  security_groups_string = instance.security_groups.map {|sg| sg["group_name"] }.join(", ")
  result =
    {
      "Region" => region,
      "Image Id" => instance.image_id,
      "Image Name" => image_name,
      "Instance Id" => instance.id,
      "State" => instance.state.name,
      "platform" => instance.platform,
      "public_ip_address" => instance.public_ip_address,
      "private_ip_address" => instance.private_ip_address,
      "key_name" => instance.key_name,
      "security_groups" => security_groups_string,
      "vpc_id" => instance.vpc_id,
      "vpc_name" => vpc_name,
      "Name" => instance_tag_dict.fetch("Name", ""),
      "Department" => instance_tag_dict.fetch("Department", ""),
      "AvailabilityZone" => instance.placement["availability_zone"],
      "instance_type" => instance.instance_type
    }
  result
end

def create_sg_report(regions, filepath, always_overwrite, timestamp)
  #
  #   Creates the actual report, first into a  data structure
  #   Then write into a csv file
  #
  f = open_file(filepath, always_overwrite, timestamp)
  return false unless f

  first_region_parsed = false
  regions.each do |region|
    ec2 = Aws::EC2::Resource.new(region: region)
    if !ec2
      $stderr.write("Could not connect to region: #{region}. Skipping")
    end

    instance_list = []
    ec2.instances.each do |instance|
      instance_list << get_instance_hash(instance, region)
    end
    instance_list.sort_by! { |hsh| hsh[:"Instance Id"] }
    keys = nil
    unless first_region_parsed
      # Get all unique keys into an array. This would be csv header
      keys = instance_list.flat_map(&:keys).uniq
    end
    CSV.open(f, "a") do |csv|
      unless first_region_parsed
        csv << keys
        first_region_parsed = true
      end
      instance_list.each do |hash|
        # fetch values at keys location, inserting null if not found.
        csv << hash.values_at(*keys)
      end
    end
  end
  return true
end
if $PROGRAM_NAME == __FILE__
  options = {}
  optparse = OptionParser.new do |opts|
    opts.banner = "Creates a CSV report about instances and images"
    opts.on("-f FILE", "--file FILE", "Path for output CSV file") do |file|
      options[:file] = file
    end
    opts.on("-o", "--overwrite", "Overwrite file") do
      options[:overwrite] = true
    end
    opts.on("-t", "--timestamp", "Create filename using current time") do
      options[:timestamp] = true
    end
  end
  optparse.parse(ARGV)
  retval = create_sg_report(["eu-west-1", "us-east-2"],
                            options[:file], options[:overwrite], options[:timestamp])
  if retval
    exit(0)
  else
    exit(1)
  end
end
