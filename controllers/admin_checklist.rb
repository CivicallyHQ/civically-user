class CivicallyChecklist::AdminChecklistController < ::ApplicationController
  attr_accessor :users

  before_action :ensure_admin
  before_action :get_users, only: [:items, :update, :add, :remove]

  def index
    render_blank
  end

  def items
    item_ids = []

    @users.each do |user|
      CivicallyChecklist::Checklist.get_list(user).each do |item|
        item_ids.push(item['id']) if item_ids.exclude?(item['id'])
      end
    end

    render json: { item_ids: item_ids.uniq }
  end

  def update
    if @users.any?
      Jobs.enqueue(:bulk_checklist_update,
        user_ids: @users.pluck(:id),
        item: item_params.to_h
      )

      render json: success_json
    else
      render json: failed_json.merge(message: I18n.t("checklist.update.error"))
    end
  end

  def add
    if @users.any?
      job_params = {
        user_ids: @users.pluck(:id),
        item: item_params.to_h
      }

      job_params[:index] = params[:index] if params[:index]

      Jobs.enqueue(:bulk_checklist_add, job_params)

      render json: success_json
    else
      render json: failed_json.merge(message: I18n.t("checklist.add.error"))
    end
  end

  def remove
    if @users.any?
      job_params = {
        user_ids: @users.pluck(:id),
        item_id: remove_params[:item_id]
      }

      Jobs.enqueue(:bulk_checklist_remove, job_params)

      render json: success_json
    else
      render json: failed_json.merge(message: I18n.t("checklist.add.error"))
    end
  end

  private

  def target_params
    params.require(:target).permit(:place_category_id, :usernames)
  end

  def item_params
    params.require(:item).permit(:id, :active, :checked, :checkable, :hidden, :hideable, :title, :detail)
  end

  def remove_params
    params.require(:item_id)
    params.permit(:item_id)
  end

  def get_users
    if target_params[:place_category_id] && target_params[:usernames]
      raise Discourse::InvalidParameters, "Target can't be both place and usernames."
    end

    users = []

    if category_id = target_params[:place_category_id]
      users = CivicallyPlace::Place.members(category_id)
    end

    if usernames = target_params[:usernames]
      users = User.where(username: usernames.split(','))
    end

    @users = users
  end
end
