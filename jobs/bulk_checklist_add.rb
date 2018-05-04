module Jobs
  class BulkChecklistAdd < Jobs::Base
    def execute(args)
      item = args['item']
      users = User.where(id: args['user_ids'])
      index = args[:index].to_i || nil

      users.each do |user|
        CivicallyChecklist::Checklist.add_item(user, item, index)
      end
    end
  end
end
