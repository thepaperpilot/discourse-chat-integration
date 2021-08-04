# frozen_string_literal: true

# name: discourse-chat-integration
# about: This plugin integrates discourse with a number of chat providers
# version: 0.1
# url: https://github.com/discourse/discourse-chat-integration
# author: David Taylor

enabled_site_setting :chat_integration_enabled

register_asset "stylesheets/chat-integration-admin.scss"

register_svg_icon "rocket" if respond_to?(:register_svg_icon)
register_svg_icon "fa-arrow-circle-o-right" if respond_to?(:register_svg_icon)

DiscoursePluginRegistry.serialized_current_user_fields << 'chat_integration_discord_message_content'

# Site setting validators must be loaded before initialize
require_relative "lib/discourse_chat_integration/provider/slack/slack_enabled_setting_validator"

after_initialize do
  require_relative "app/initializers/discourse_chat_integration"

  User.register_custom_field_type('chat_integration_discord_message_content', :text)

  register_editable_user_custom_field :chat_integration_discord_message_content

  # TODO Drop after Discourse 2.6.0 release
  if respond_to?(:allow_public_user_custom_field)
    allow_public_user_custom_field :chat_integration_discord_message_content
  else
    whitelist_public_user_custom_field :chat_integration_discord_message_content
  end

  on(:post_created) do |post|
    # This will run for every post, even PMs. Don't worry, they're filtered out later.
    time = SiteSetting.chat_integration_delay_seconds.seconds
    Jobs.enqueue_in(time, :notify_chats, post_id: post.id)
  end

  add_admin_route 'chat_integration.menu_title', 'chat'

  AdminDashboardData.add_problem_check do
    error = false
    DiscourseChatIntegration::Channel.find_each do |channel|
      error = true unless channel.error_key.blank?
    end

    if error
      base_path = Discourse.respond_to?(:base_path) ? Discourse.base_path : Discourse.base_uri
      I18n.t("chat_integration.admin_error", base_path: base_path)
    end
  end

  DiscourseChatIntegration::Provider.mount_engines
end

register_asset "javascripts/discourse/templates/connectors/user-custom-preferences/webhook-preferences.hbs"
