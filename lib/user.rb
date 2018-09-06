class ::User
  def unread_lists
    if custom_fields['unread_lists']
      [*custom_fields['unread_lists']]
    else
      []
    end
  end

  def position
    if custom_fields['position']
      custom_fields['position']
    else
      nil
    end
  end

  def linkedin
    if custom_fields['linkedin']
      custom_fields['linkedin']
    else
      nil
    end
  end

  def hide_rules
    if custom_fields['hide_rules']
      custom_fields['hide_rules']
    else
      false
    end
  end

  def accepted_rules
    if custom_fields['accepted_rules']
      custom_fields['accepted_rules']
    else
      false
    end
  end

  def accepted_rules_at
    UserCustomField.where(name: 'accepted_rules', user_id: self.id)
      .pluck(:created_at)
      .first
  end
end

module ::CivicallyUser
  class Engine < ::Rails::Engine
    engine_name "civically_user"
    isolate_namespace CivicallyUser
  end
end

CivicallyUser::Engine.routes.draw do
  delete ':user/unread-list' => 'user#clear_unread_list'
  put ":user/toggle-rules" => "user#toggle_rules"
  put ":user/accept-rules" => "user#accept_rules"
end

Discourse::Application.routes.append do
  mount ::CivicallyUser::Engine, at: 'c-user'
end

class CivicallyUser::User
  def self.add_unread_list(user, list)
    unread_lists = user.unread_lists
    user.custom_fields['unread_lists'] = unread_lists.push(list) if unread_lists.exclude?(list)
    user.save_custom_fields(true)
  end

  def self.remove_unread_list(user, list)
    unread_lists = user.unread_lists
    user.custom_fields['unread_lists'] = unread_lists - [list]
    user.save_custom_fields(true)
  end
end

class CivicallyUser::UserController < ::ApplicationController
  def clear_unread_list
    params.require(:user)
    params.require(:list)

    result = CivicallyUser::User.remove_unread_list(current_user, params[:list])

    if result
      render json: success_json
    else
      render json: failed_json
    end
  end

  def toggle_rules
    params.require(:state)

    user = current_user

    user.custom_fields['hide_rules'] = ActiveModel::Type::Boolean.new.cast(params[:state])

    if user.save_custom_fields(true)
      render json: success_json
    else
      render json: failed_json
    end
  end

  def accept_rules
    user = current_user
    user.custom_fields['accepted_rules'] = true

    if user.save_custom_fields(true)
      CivicallyChecklist::Checklist.update_item(user, 'rules', checked: true, hideable: true)

      render json: success_json
    else
      render json: failed_json
    end
  end
end
