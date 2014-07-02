# Makes testing a lot easier due to Chef code gen

module BswTech
  class ComplexUpdateChecker
    def updated_by_last_action?(instance)
      instance.updated_by_last_action?
    end
  end
end