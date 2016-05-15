module SetOperations
  extend ActiveSupport::Concern

  module ClassMethods

    def union_scope(*scopes)
      apply_operation 'UNION', scopes
    end

    def intersect_scope(*scopes)
      apply_operation 'INTERSECT', scopes
    end

    def except_scope(*scopes)
      apply_operation 'EXCEPT', scopes
    end

    private

    def apply_operation(operation, scopes)
      id_column = "#{table_name}.#{primary_key}"
      sub_query = scopes
                      .map { |s| s.select(id_column).to_sql }
                      .join(" #{operation} ")

      where "#{id_column} IN (#{sub_query})"
    end

  end
end
