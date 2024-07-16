# frozen_string_literal: true
# name: discourse-group-membership-ip-block
# about: Adds list of ip blocks that users starting sessions from will join the group
# version: 0.1
# authors: Falco
# url: https://github.com/discourse/discourse-group-membership-ip-block

enabled_site_setting :group_membership_ip_block_enabled
register_asset "stylesheets/group-settings.scss"

after_initialize do
  DiscoursePluginRegistry.register_editable_group_custom_field(:ip_blocks_list, self)
  register_group_custom_field_type("ip_blocks_list", :string, max_length: 1000)
  add_to_serializer(:basic_group, :custom_fields) do
    { ip_blocks_list: object.custom_fields[:ip_blocks_list] }
  end

  INTL_GROUP_NAME = "INTL"
  @intl_group = Group.find_by(name: INTL_GROUP_NAME)
  unless @intl_group
    Group.new(name: INTL_GROUP_NAME)
  end

  def handle_user_ip(user)
    ip_info = DiscourseIpInfo.get(user.ip_address, resolve_hostname: false)
    # ip_reg_info = DiscourseIpInfo.get(user.registration_ip_address, resolve_hostname: false)

    unless ip_info[:country_code] == "CN"
      @intl_group.add(user)
    end

    GroupCustomField
      .where(name: "ip_blocks_list")
      .each do |rule|
      ips = rule.value.split.map { |ip| IPAddr.new(ip) }
      ips.each { |ip| Group.find_by(id: rule.group).add(user) if ip.include?(user.ip_address) }
    end
  end

  on(:user_updated) do |user|
    return unless SiteSetting.group_membership_ip_block_enabled
    handle_user_ip(user)
  end

  on(:user_logged_in) do |user|
    return unless SiteSetting.group_membership_ip_block_enabled
    handle_user_ip(user)
  end
end
