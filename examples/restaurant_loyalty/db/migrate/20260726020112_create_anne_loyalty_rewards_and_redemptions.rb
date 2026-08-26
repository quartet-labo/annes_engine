class CreateAnnesLoyaltyRewardsAndRedemptions < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_loyalty_loyalty_rewards do |t|
      t.references :loyalty_program, null: false, foreign_key: { to_table: :annes_loyalty_loyalty_programs }, index: false
      t.string :code, null: false
      t.string :name, null: false
      t.integer :required_points, null: false
      t.integer :valid_minutes, null: false
      t.boolean :active, null: false, default: true

      t.timestamps

      t.index [ :loyalty_program_id, :code ], unique: true, name: "index_loyalty_rewards_on_program_and_code"
      t.index :active
    end

    add_check_constraint :annes_loyalty_loyalty_rewards,
      "required_points > 0 AND valid_minutes > 0",
      name: "annes_loyalty_rewards_positive_settings"

    create_table :annes_loyalty_loyalty_redemptions do |t|
      t.references :loyalty_member, null: false, foreign_key: { to_table: :annes_loyalty_loyalty_members }, index: false
      t.references :loyalty_reward, null: false, foreign_key: { to_table: :annes_loyalty_loyalty_rewards }, index: false
      t.references :redeemed_loyalty_location, null: true, foreign_key: { to_table: :annes_loyalty_loyalty_locations }, index: false
      t.string :status, null: false
      t.string :token_digest, null: false
      t.datetime :issued_at, null: false
      t.datetime :redeemed_at
      t.datetime :expires_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps

      t.index :token_digest, unique: true, name: "index_loyalty_redemptions_on_token_digest"
      t.index [ :loyalty_member_id, :status ], name: "index_loyalty_redemptions_on_member_and_status"
      t.index [ :loyalty_reward_id, :status ], name: "index_loyalty_redemptions_on_reward_and_status"
    end

    add_check_constraint :annes_loyalty_loyalty_redemptions,
      "status IN ('issued', 'redeemed', 'expired', 'canceled')",
      name: "annes_loyalty_redemptions_known_status"
    add_check_constraint :annes_loyalty_loyalty_redemptions,
      "expires_at > issued_at",
      name: "annes_loyalty_redemptions_expiry_after_issue"
    add_check_constraint :annes_loyalty_loyalty_redemptions,
      "redeemed_at IS NULL OR redeemed_at >= issued_at",
      name: "annes_loyalty_redemptions_redeemed_after_issue"
  end
end
