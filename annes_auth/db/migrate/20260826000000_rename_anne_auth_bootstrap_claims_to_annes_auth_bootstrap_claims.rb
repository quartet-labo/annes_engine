class RenameAnneAuthBootstrapClaimsToAnnesAuthBootstrapClaims < ActiveRecord::Migration[8.1]
  OLD_TABLE = :anne_auth_bootstrap_claims
  NEW_TABLE = :annes_auth_bootstrap_claims

  INDEX_RENAMES = {
    "idx_anne_auth_bootstrap_claims_on_purpose" => "idx_annes_auth_bootstrap_claims_on_purpose",
    "idx_anne_auth_bootstrap_claims_on_account" => "idx_annes_auth_bootstrap_claims_on_account"
  }.freeze

  def up
    rename_table_if_needed(OLD_TABLE, NEW_TABLE)
    rename_indexes(NEW_TABLE, INDEX_RENAMES)
    rename_default_account_class("AnneAuth::Account", "AnnesAuth::Account")
  end

  def down
    rename_default_account_class("AnnesAuth::Account", "AnneAuth::Account")
    rename_indexes(NEW_TABLE, INDEX_RENAMES.invert)
    rename_table_if_needed(NEW_TABLE, OLD_TABLE)
  end

  private
    def rename_table_if_needed(from, to)
      return unless table_exists?(from)
      raise "Both #{from} and #{to} exist; resolve the bootstrap claim table migration manually" if table_exists?(to)

      rename_table(from, to)
    end

    def rename_indexes(table, renames)
      return unless table_exists?(table)

      renames.each do |from, to|
        next unless connection.indexes(table).any? { |index| index.name == from }

        rename_index(table, from, to)
      end
    end

    def rename_default_account_class(from, to)
      return unless table_exists?(NEW_TABLE)

      quoted_from = connection.quote(from)
      quoted_to = connection.quote(to)
      execute <<~SQL
        UPDATE #{connection.quote_table_name(NEW_TABLE)}
        SET account_class_name = #{quoted_to}
        WHERE account_class_name = #{quoted_from}
      SQL
    end
end
