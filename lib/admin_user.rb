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
  SORTABLE_MAPPING['town_category_id'] = "(SELECT value FROM user_custom_fields WHERE user_id = users.id AND name = 'town_category_id' LIMIT 1)"
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
