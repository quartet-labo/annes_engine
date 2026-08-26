class RenameAnneLoyaltyTablesToAnnesLoyaltyTables < ActiveRecord::Migration[8.1]
  TABLES = %i[
    loyalty_programs loyalty_locations loyalty_members loyalty_ledger_entries
    loyalty_point_lots loyalty_rewards loyalty_redemptions
  ].freeze

  def up
    TABLES.each { |name| rename(name, :anne_loyalty, :annes_loyalty) }
  end

  def down
    TABLES.reverse_each { |name| rename(name, :annes_loyalty, :anne_loyalty) }
  end

  private
    def rename(name, from_prefix, to_prefix)
      from = "#{from_prefix}_#{name}".to_sym
      to = "#{to_prefix}_#{name}".to_sym
      return unless table_exists?(from)
      raise ActiveRecord::MigrationError, "Both #{from} and #{to} exist; reconcile loyalty data before migrating" if table_exists?(to)

      rename_table from, to
    end
end
