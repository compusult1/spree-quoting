class CreateQuotes < ActiveRecord::Migration
  def self.up
    create_table :quotes do |t|
      t.references :order
      t.string :email
      t.string :ip_address
      t.text :special_instructions
      t.integer :bill_address_id
      t.datetime :completed_at
      t.timestamps
    end
  end

  def self.down
    drop_table :quotes
  end
end
