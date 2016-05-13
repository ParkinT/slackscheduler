class AddTimezoneToSlacker < ActiveRecord::Migration[5.0]
  def change
    add_column :slackers, :tz, :string, default: nil
  end
end
