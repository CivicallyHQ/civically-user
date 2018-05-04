module ::CivicallyChecklist
  class Engine < ::Rails::Engine
    engine_name "civically_checklist"
    isolate_namespace CivicallyChecklist
  end
end

CivicallyChecklist::Engine.routes.draw do
  get ":username" => "checklist#list"
  post ":username/:item_id/toggle_checked" => "checklist#toggle_checked"
end

require_dependency 'admin_constraint'
Discourse::Application.routes.append do
  mount ::CivicallyChecklist::Engine, at: "checklist"

  scope module: 'civically_checklist', constraints: AdminConstraint.new do
    get 'admin/checklists' => 'admin_checklist#index'
    get 'admin/checklists/items' => 'admin_checklist#items'
    post 'admin/checklists/add' => 'admin_checklist#add'
    post 'admin/checklists/remove' => 'admin_checklist#remove'
    post 'admin/checklists/update' => 'admin_checklist#update'
  end
end

class CivicallyChecklist::Checklist
  def self.get_list(user)
    ::JSON.parse(PluginStore.get('action_checklist', user.id))
  end

  def self.set_list(user, list)
    PluginStore.set('action_checklist', user.id, ::JSON.generate(list))
  end

  def self.add_item(user, item, index = nil)
    list = get_list(user)

    item = self.standardise(item)

    unless list.any? { |i| i["id"].to_s === item['id'].to_s }
      if index != nil
        list.insert(index, item)
      else
        list.push(item)
      end

      set_list(user, list)
    end
  end

  def self.remove_item(user, item_id)
    list = get_list(user)

    list = list.reject { |item| item['id'].to_s === item_id.to_s }

    set_list(user, list)
  end

  def self.update_item(user, item_id, updates)
    list = get_list(user)

    values = self.standardise(updates)

    list.each do |item|
      if item['id'].to_s === item_id.to_s
        values.each do |k, v|
          item[k.to_s] = v
        end
      end
    end

    set_list(user, list)
  end

  def self.standardise(data)
    data = data.with_indifferent_access
    values = {}

    values['id'] = data['id'].to_s if data['id'].present?
    values['checked'] = ActiveModel::Type::Boolean.new.cast(data['checked']) if data['checked'] != nil
    values['checkable'] = ActiveModel::Type::Boolean.new.cast(data['checkable']) if data['checkable'] != nil
    values['active'] = ActiveModel::Type::Boolean.new.cast(data['active']) if data['active'] != nil
    values['title'] = data['title'].to_s if data['title'].present?
    values['detail'] = data['detail'].to_s if data['detail'].present?

    values
  end
end
