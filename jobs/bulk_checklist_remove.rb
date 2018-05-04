module Jobs
  class BulkChecklistRemove < Jobs::Base
    def execute(args)
      User.where(id: args['user_ids']).each do |user|
        CivicallyChecklist::Checklist.remove_item(user, args['item_id'])
      end
    end
  end
end
