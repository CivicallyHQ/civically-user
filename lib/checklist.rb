module ::CivicallyChecklist
  class Engine < ::Rails::Engine
    engine_name "civically_checklist"
    isolate_namespace CivicallyChecklist
  end
end

CivicallyChecklist::Engine.routes.draw do
  get ":username" => "checklist#list"
  put ":username/:item_id/update" => "checklist#update"
  put ":username/add" => "checklist#add"
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
  def self.create_set(user, set)
    item_ids = []

    set['items'].each do |item|
      item['title'] = I18n.t("checklist.#{set['name']}.#{item['id']}.title")
      item['detail'] = I18n.t("checklist.#{set['name']}.#{item['id']}.detail")

      CivicallyChecklist::Checklist.add_item(user, item)

      item_ids.push(item['id'])
    end

    CivicallyChecklist::Checklist.add_set(user, set['name'], item_ids)
  end

  def self.get_list(user)
    stored = PluginStore.get('user_checklist', user.id)
    stored ? ::JSON.parse(stored) : []
  end

  def self.get_list_visible(user)
    list = get_list(user)
    list.select { |i| !i['hidden'] }
  end

  def self.set_list(user, list)
    PluginStore.set('user_checklist', user.id, ::JSON.generate(list))
  end

  def self.get_item(user, item_id)
    list = get_list(user)
    list.select { |i| i['id'].to_s === item_id.to_s }.first
  end

  def self.add_item(user, item, index = nil)
    list = get_list(user)

    item = self.standardise_item(item, true)

    unless list.any? { |i| i["id"].to_s === item['id'].to_s }
      item['created_at'] = Time.now.utc

      if index != nil
        list.insert(index, item)
      else
        list.push(item)
      end

      set_list(user, list)
    end

    get_item(user, item['id'])
  end

  def self.remove_item(user, item_id)
    list = get_list(user)

    list = list.reject { |item| item['id'].to_s === item_id.to_s }

    set_list(user, list)
  end

  def self.update_item(user, item_id, updates)
    list = get_list(user)

    values = self.standardise_item(updates)

    list.each do |item|
      if item['id'].to_s === item_id.to_s
        item['updated_at'] = Time.now.utc

        values.each do |k, v|
          item[k.to_s] = v
        end
      end
    end

    set_list(user, list)

    if set_name = item_in_set(user, item_id)
      update_set_complete(user, set_name)
    end

    get_item(user, item_id).select do |key, value|
      updates[key].present?
    end
  end

  def self.standardise_item(data, seed = false)
    data = data.with_indifferent_access
    values = {}

    if data['id'].present?
      values['id'] = data['id'].to_s
    elsif seed
      values['id'] = SecureRandom.hex(8)
    end

    booleans = ['checked', 'checkable', 'hidden', 'hideable', 'active']

    booleans.each do |v|
      if data[v] == nil
        if v == 'hidden' || v == 'checked'
          values[v] = false
        elsif seed
          values[v] = true
        end
      else
        values[v] = ActiveModel::Type::Boolean.new.cast(data[v])
      end
    end

    values['title'] = data['title'].to_s if data['title'].present?
    values['detail'] = data['detail'].to_s if data['detail'].present?

    values
  end

  def self.get_sets(user)
    stored = PluginStore.get('user_checklist_sets', user.id)
    stored ? ::JSON.parse(stored) : {}
  end

  def self.set_sets(user, sets)
    PluginStore.set("user_checklist_sets", user.id, ::JSON.generate(sets))
  end

  def self.add_set(user, set_name, item_ids)
    sets = get_sets(user)

    unless sets[set_name]
      sets[set_name] = {
        items: item_ids,
        completed: false,
        created_at: Time.now.utc
      }

      set_sets(user, sets)
    end
  end

  def self.remove_set(user, set_name)
    sets = get_sets(user)

    sets.delete(set_name)

    set_sets(user, sets)
  end

  def self.update_set(user, set_name, updates)
    sets = get_sets(user)

    if sets[set_name]
      sets[set_name].merge!(updates)
    end

    set_sets(user, sets)
  end

  def self.item_in_set(user, item_id)
    sets = get_sets(user)
    set_name = nil

    sets.each do |k, v|
      if v['items'] && v['items'].include?(item_id)
        set_name = k
      end
    end

    set_name
  end

  def self.update_set_complete(user, set_name)
    sets = get_sets(user)
    set = sets[set_name]

    if set
      complete = true

      set['items'].each do |item_id|
        item = get_item(user, item_id)
        complete = false if !item['checked']
      end

      update_set(user, set_name, complete: complete)
    else
      nil
    end
  end
end
