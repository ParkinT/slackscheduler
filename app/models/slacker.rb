class Slacker < ApplicationRecord

  def need_configuration?
    self.email.nil? || self.tz.nil?
  end
end
