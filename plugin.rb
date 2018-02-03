# name: civically-user
# about: User edits for Civically
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/civicallyhq/civically-user

register_asset 'stylesheets/civically-user.scss'

DiscourseEvent.on(:custom_wizard_ready) do
  ## 'migration' to be removed
  PluginStore.remove('custom_wizard', 'welcome')

  CustomWizard::Wizard.add_wizard(File.read(File.join(
    Rails.root, 'plugins', 'civically-user', 'config', 'wizards', 'welcome.json'
  )))

  CustomWizard::Builder.add_step_handler('welcome') do |builder|
    if builder.updater && builder.updater.step && builder.updater.step.id === 'civically'
      user = builder.wizard.user
      previous_steps = builder.submissions.last || {}
      final_step = builder.updater.fields.to_h
      data = previous_steps.merge(final_step)

      if data.present?
        welcome_bookmark_ids = YAML.safe_load(File.read(File.join(
          Rails.root, 'plugins', 'civically-user', 'config', 'welcome_bookmark_ids.yml'
        )))
        bookmarks = []
        data.each do |k, v|
          if v === 'true'
            topic_id = welcome_bookmark_ids[k]

            if topic = Topic.find_by(id: topic_id)
              post = topic.ordered_posts.first

              unless PostAction.exists?(post_id: post.id, user_id: user.id, post_action_type_id: PostActionType.types[:bookmark])
                PostAction.act(user, post, PostActionType.types[:bookmark])
                CivicallyUser::User.add_unread_list(user, 'bookmarks')
              end
            end
          end
        end
      end

      CivicallyChecklist::Checklist.update_item(user, 'complete_welcome', checked: true)
    end
  end
end

after_initialize do
  DiscoursePluginRegistry.serialized_current_user_fields << "institution"
  DiscoursePluginRegistry.serialized_current_user_fields << "position"
  add_to_serializer(:current_user, :institution) { object.custom_fields["institution"] }
  add_to_serializer(:current_user, :position) { object.custom_fields["position"] }
  add_to_serializer(:current_user, :unread_lists) { object.unread_lists }

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

  load File.expand_path('../controllers/checklist.rb', __FILE__)
  load File.expand_path('../jobs/bulk_checklist_update.rb', __FILE__)
  load File.expand_path('../jobs/bulk_unread_lists_update.rb', __FILE__)
  load File.expand_path('../lib/checklist.rb', __FILE__)
  load File.expand_path('../lib/admin_user.rb', __FILE__)
  load File.expand_path('../lib/user.rb', __FILE__)

  DiscourseEvent.on(:user_created) do |user|
    CivicallyUser::User.checklist(user)
  end
end
