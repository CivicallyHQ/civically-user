# name: civically-user
# about: User edits for Civically
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/civicallyhq/civically-user

register_asset 'stylesheets/civically-user.scss'

DiscourseEvent.on(:custom_wizard_ready) do
  ## 'migration' to be wrapped in conditional
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

  load File.expand_path('../lib/admin_user.rb', __FILE__)
  load File.expand_path('../lib/checklist.rb', __FILE__)
  load File.expand_path('../lib/guardian.rb', __FILE__)
  load File.expand_path('../lib/user.rb', __FILE__)
  load File.expand_path('../controllers/checklist.rb', __FILE__)
  load File.expand_path('../jobs/bulk_checklist_update.rb', __FILE__)
  load File.expand_path('../jobs/bulk_unread_lists_update.rb', __FILE__)

  DiscourseEvent.on(:user_created) do |user|
    CivicallyUser::User.checklist(user)
  end

  require_dependency 'application_controller'
  class ::ApplicationController
    def set_locale
      if !current_user
        if cookies[:discourse_guest_locale]
          locale = cookies[:discourse_guest_locale]
        elsif SiteSetting.set_locale_from_accept_language_header
          locale = locale_from_header
        else
          locale = SiteSetting.default_locale
        end
      else
        locale = current_user.effective_locale
      end

      I18n.locale = I18n.locale_available?(locale) ? locale : :en
      I18n.ensure_all_loaded!
    end
  end
end
