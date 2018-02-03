class CivicallyChecklist::ChecklistController < ::ApplicationController
  before_action :can_use_list

  def list
    user = User.find_by(username: params[:username])
    list = CivicallyChecklist::Checklist.get_list(user)
    render_json_dump(list.take(5))
  end

  def toggle_checked
    params.require(:item_id)
    params.require(:checked)

    user = User.find_by(username: params[:username])

    result = CivicallyChecklist::Checklist.update_item(user, params[:item_id], checked: params[:checked])

    if result
      render json: success_json
    else
      render json: failed_json
    end
  end

  private

  def can_use_list
    params.require(:username)

    if !current_user.staff? && current_user.username != params[:username]
      raise Discourse::InvalidAccess.new
    end
  end
end
