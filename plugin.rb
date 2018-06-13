# name: civically-user
# app: system
# about: User edits for Civically
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/civicallyhq/civically-user

register_asset 'stylesheets/civically-user.scss'

DiscourseEvent.on(:custom_wizard_ready) do
  if !CustomWizard::Wizard.find('welcome') || Rails.env.development?
    CustomWizard::Wizard.add_wizard(File.read(File.join(
      Rails.root, 'plugins', 'civically-user', 'config', 'wizards', 'welcome.json'
    )))
  end

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

  DiscoursePluginRegistry.serialized_current_user_fields << "institution"
  DiscoursePluginRegistry.serialized_current_user_fields << "position"
  add_to_serializer(:current_user, :institution) { object.custom_fields["institution"] }
  add_to_serializer(:current_user, :position) { object.custom_fields["position"] }
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
