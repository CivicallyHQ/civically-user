# name: civically-user
# about: User edits for Civically
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/civicallyhq/civically-user

DiscourseEvent.on(:custom_wizard_ready) do
  unless PluginStoreRow.exists?(plugin_name: 'custom_wizard', key: 'welcome')
    CustomWizard::Wizard.add_wizard(File.read(File.join(
      Rails.root, 'plugins', 'civically-user', 'config', 'wizards', 'welcome.json'
    )))
  end

  CustomWizard::Builder.add_step_handler('welcome') do |builder|
    if builder.updater && builder.updater.step && builder.updater.step.id === 'run'
      user = builder.wizard.user
      CivicallyChecklist::Checklist.toggle_checked(user, 'complete_welcome', true)
    end
  end
end

after_initialize do
  DiscoursePluginRegistry.serialized_current_user_fields << "institution"
  DiscoursePluginRegistry.serialized_current_user_fields << "position"
  add_to_serializer(:current_user, :institution) { object.custom_fields["institution"] }
  add_to_serializer(:current_user, :position) { object.custom_fields["position"] }

  require_dependency 'guardian'
  Guardian.class_eval do
    def can_invite_to_forum?(groups = nil)
      authenticated? &&
      (SiteSetting.max_invites_per_day.to_i > 0 || is_staff?) &&
      !SiteSetting.enable_sso &&
      SiteSetting.enable_local_logins &&
      (
        (!SiteSetting.must_approve_users? && @user.has_trust_level?(TrustLevel[1])) ||
        is_staff?
      ) &&
      (groups.blank? || is_admin?)
    end

    def can_invite_to?(object, groups = nil)
      return false unless authenticated?
      return true if is_admin?
      return false unless SiteSetting.enable_private_messages?
      return false if (SiteSetting.max_invites_per_day.to_i == 0 && !is_staff?)
      return false unless can_see?(object)
      return false if groups.present?

      if object.is_a?(Topic) && object.category
        if object.category.groups.any?
          return true if object.category.groups.all? { |g| can_edit_group?(g) }
        end
      end

      user.has_trust_level?(TrustLevel[1])
    end

    def can_delete_user?(user)
      return false if user.nil? || user.admin?
      if is_me?(user)
        user.post_count <= 1
      else
        is_admin? && (user.first_post_created_at.nil? || user.first_post_created_at > SiteSetting.delete_user_max_post_age.to_i.days.ago)
      end
    end

    def can_delete_all_posts?(user)
      is_admin? &&
      user &&
      !user.admin? &&
      (user.first_post_created_at.nil? || user.first_post_created_at >= SiteSetting.delete_user_max_post_age.days.ago) &&
      user.post_count <= SiteSetting.delete_all_posts_max.to_i
    end

    def can_change_trust_level?(user)
      user && is_admin?
    end
  end

  Admin::AdminController.class_eval do
    def ensure_admin
      raise Discourse::InvalidAccess.new unless current_user && current_user.admin?
    end
  end

  Admin::StaffActionLogsController.class_eval do
    before_action :ensure_admin
  end

  Admin::ScreenedEmailsController.class_eval do
    before_action :ensure_admin
  end

  Admin::ScreenedIpAddressesController.class_eval do
    before_action :ensure_admin
  end

  Admin::ScreenedUrlsController.class_eval do
    before_action :ensure_admin
  end

  Admin::WatchedWordsController.class_eval do
    before_action :ensure_admin
  end

  Admin::SearchLogsController.class_eval do
    before_action :ensure_admin
  end

  Admin::PluginsController.class_eval do
    before_action :ensure_admin
  end

  module AdminFindUsersQueryExtension
    def filter_by_custom_fields
      if params[:custom_fields].present?
        params[:custom_fields].each do |k, v|
          @query = @query.where("users.id in (
            SELECT user_id FROM user_custom_fields WHERE name = '#{k}' AND value = ?
          )", v)
        end
      end
      @query
    end

    def find_users_query
      append filter_by_custom_fields
      super
    end
  end

  require_dependency 'admin_user_index_query'
  class ::AdminUserIndexQuery
    prepend AdminFindUsersQueryExtension
    SORTABLE_MAPPING['place_category_id'] = "(SELECT value FROM user_custom_fields WHERE user_id = users.id AND name = 'place_category_id' LIMIT 1)"
  end

  Admin::UsersController.class_eval do
    def index
      users = ::AdminUserIndexQuery.new(params).find_users

      if current_user.admin? && params[:show_emails] == "true"
        guardian.can_see_emails = true
        StaffActionLogger.new(current_user).log_show_emails(users)
      end

      render_serialized(users, AdminUserListSerializer)
    end
  end

  module ::CivicallyUser
    class Engine < ::Rails::Engine
      engine_name "civically_user"
      isolate_namespace CivicallyUser
    end
  end

  class CivicallyUser::Setup
    def self.checklist(user)
      CivicallyApp::App.add_app(user, 'action_checklist', 'right')
      list = ::JSON.parse(File.read(File.join(
        Rails.root, 'plugins', 'civically-user', 'config', 'checklists', 'getting_started.json'
      )))
      list['items'].each do |item|
        item['title'] = I18n.t("checklist.getting_started.#{item['id']}.title")
        item['detail'] = I18n.t("checklist.getting_started.#{item['id']}.detail")
      end
      CivicallyChecklist::Checklist.set_list(user, list['items'])
    end
  end

  DiscourseEvent.on(:user_created) do |user|
    CivicallyUser::Setup.checklist(user)
  end

  ## migration - to be removed

  User.all.human_users.each do |user|
    unless PluginStoreRow.where(plugin_name: 'action_checklist', key: user.id).exists?
      CivicallyUser::Setup.checklist(user)

      if user.custom_fields['place_topic_id']
        CivicallyPlace::User.add_pass_petition_to_checklist(user)
      end
    end
  end
end
