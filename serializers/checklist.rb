class CivicallyChecklist::Serializer < ::ApplicationSerializer
  attributes :sets, :can_add

  def sets
    CivicallyChecklist::Checklist.get_sets(object)
  end

  def can_add
    object.staff? || (sets['getting_started'] && sets['getting_started']['complete'])
  end
end
