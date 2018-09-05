# name: civically-user
# app: system
# about: User edits for Civically
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/civicallyhq/civically-user

register_asset 'stylesheets/common/civically-user.scss'
register_asset 'stylesheets/mobile/civically-user.scss'

DiscourseEvent.on(:custom_wizard_ready) do
  CustomWizard::Wizard.add_wizard(File.read(File.join(
    Rails.root, 'plugins', 'civically-user', 'config', 'wizards', 'welcome.json'
  )))

  CustomWizard::Builder.add_step_handler('welcome') do |builder|
    if builder.updater && builder.updater.step && builder.updater.step.id === 'submit'
      user = builder.wizard.user
      previous_steps = builder.submissions.last || {}
      final_step = builder.updater.fields.to_h

      CivicallyChecklist::Checklist.update_item(user, 'complete_welcome', checked: true, hideable: true)
    end
  end
end

after_initialize do
  load File.expand_path('../lib/admin_user.rb', __FILE__)
  load File.expand_path('../lib/checklist.rb', __FILE__)
  load File.expand_path('../lib/guardian.rb', __FILE__)
  load File.expand_path('../lib/user.rb', __FILE__)
  load File.expand_path('../controllers/checklist.rb', __FILE__)
  load File.expand_path('../serializers/checklist.rb', __FILE__)
  load File.expand_path('../controllers/admin_checklist.rb', __FILE__)
  load File.expand_path('../jobs/bulk_checklist_update.rb', __FILE__)
  load File.expand_path('../jobs/bulk_checklist_add.rb', __FILE__)
  load File.expand_path('../jobs/bulk_checklist_remove.rb', __FILE__)
  load File.expand_path('../jobs/bulk_unread_lists_update.rb', __FILE__)

  DiscoursePluginRegistry.serialized_current_user_fields << "position"
  add_to_serializer(:current_user, :position) { object.custom_fields["position"] }
  DiscoursePluginRegistry.serialized_current_user_fields << "linkedin"
  add_to_serializer(:current_user, :position) { object.custom_fields["linkedin"] }

  public_user_custom_fields = SiteSetting.public_user_custom_fields.split('|')
  public_user_custom_fields.push('position') unless public_user_custom_fields.include?('position')
  public_user_custom_fields.push('linkedin') unless public_user_custom_fields.include?('linkedin')
  SiteSetting.public_user_custom_fields = public_user_custom_fields.join('|')

  add_to_serializer(:current_user, :unread_lists) { object.unread_lists }
  add_to_serializer(:current_user, :checklist) { CivicallyChecklist::Serializer.new(object, root: false).as_json }

  getting_started_checklist_set = ::JSON.parse(File.read(File.join(
    Rails.root, 'plugins', 'civically-user', 'config', 'checklists', 'getting_started.json'
  )))

  DiscourseEvent.on(:user_created) do |user|
    CivicallyChecklist::Checklist.create_set(user, getting_started_checklist_set)
    CivicallyApp::App.add(user, 'civically-user', enabled: true, widget: { position: 'right', order: 0 })
    CivicallyApp::App.add(user, 'civically-navigation', enabled: true, widget: { position: 'left', order: 0 })
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
