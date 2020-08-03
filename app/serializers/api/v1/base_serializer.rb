# frozen_string_literal: true

module Api
  module V1
    class BaseSerializer < ActiveModel::Serializer

      def editable
        return false unless current_user
        Pundit.policy!(current_user, object).update?
      end

      def show_personal_info?
        scope.authorized_to_edit?(object)
      end
    end
  end
end
