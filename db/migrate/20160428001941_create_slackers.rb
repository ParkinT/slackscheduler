class CreateSlackers < ActiveRecord::Migration[5.0]
  def change
    create_table :slackers do |t|
      t.string :name
      t.string :email
      t.string :passphrase
      t.string :slackid

      t.timestamps
    end
  end
end
