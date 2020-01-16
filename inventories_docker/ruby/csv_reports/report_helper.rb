def open_file(filepath, always_overwrite, timestamp)
  if timestamp
    filepath = Time.now.strftime("%d-%m-%Y-%H%M") + "_sg.txt"
  end
  goaheadandopen = true

  if File.exist?(filepath)
    if always_overwrite
      goaheadandopen = true
    elsif File.file?(filepath)
      goaheadandopen = confirm_if_overwriting_file(filepath)
    else
      goaheadandopen = false
    end
  end

  return nil unless goaheadandopen

  begin
    f = File.open(filepath, "w")
  rescue StandardException => e
    f = None
    $stdout.write("Could not open file #{filepath}. reason: #{e}\n")
  end
  return f
end

def confirm_if_overwriting_file(filepath)
  overwriting = true
  valid = { 'yes': true, 'y': true, 'no': false, 'n': false }
  loop do
    $stdout.write("file #{filepath} exists, overwrite it? [y/n] ")
    choice = STDIN.gets.strip.downcase.to_sym
    if valid.keys().include?(choice)
      if !valid[choice]
        overwriting = false
      end
      break
    end
    $stdout.write("Please respond with \'yes\' or \'no\' (or \'y\' or \'n\').\n")
  end
  return overwriting
end

# https://rosettacode.org/wiki/Sort_stability#Stable_sort_in_Ruby
class Array
  def stable_sort
    n = -1
    if block_given?
      collect {|x| n += 1; [x, n]
      }.sort! {|a, b|
        c = yield a[0], b[0]
        if c.nonzero? then c else a[1] <=> b[1] end
      }.collect! {|x| x[0]}
    else
      sort_by {|x| n += 1; [x, n]}
    end
  end

  def stable_sort_by
    block_given? or return enum_for(:stable_sort_by)
    n = -1
    sort_by {|x| n += 1; [(yield x), n]}
  end
end

# TODO: Expand
def extract_ips_open_to_a_port(ec2, instance, ips_allowed_string, port)
  instance.security_groups.each do |security_group|
    filters = [{"Name" => "group-id", "Values" => [security_group["GroupId"]]}]
    ec2.security_groups.filter(Filters: filters).each do |security_group_dict|
      security_group_dict.ip_permissions.each do |ip_permission|
        if is_bool(ip_permission.get("FromPort", "") == port && ip_permission.get("ToPort", "") == port)
          ip_ranges_string = ip_permission["IpRanges"].map{ |ip_range| ip_range["CidrIp"] }.join(", ")
          ips_allowed_string += ip_ranges_string
        end
      end
    end
  end
  return ips_allowed_string
end

def convert_list_of_tag_dicts_to_dict(resource)
  resource_tag_dict = {}
  unless resource.equal?(nil)
    ["Name", "Department"].each do |tag_name|
      next if resource.tags.equal?(nil)

      resource.tags.each do |tag|
        if tag["key"] == tag_name
          resource_tag_dict[tag_name] = tag["value"]
        end
      end
    end
  end
  return resource_tag_dict
end
