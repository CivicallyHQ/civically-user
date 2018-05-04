module Jobs
  class BulkChecklistUpdate < Jobs::Base
    def execute(args)
      item = args['item']

      User.where(id: args['user_ids']).each do |user|
        CivicallyChecklist::Checklist.update_item(user, item[:id], item.except(:id))
      end
    end
  end
end
