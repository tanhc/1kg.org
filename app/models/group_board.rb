# == Schema Information
# Schema version: 20090430155946
#
# Table name: group_boards
#
#  id       :integer(4)      not null, primary key
#  group_id :integer(4)      not null
#

class GroupBoard < ActiveRecord::Base
  
  has_one :board, :as => :talkable, :dependent => :destroy
  belongs_to :group
    
  def board_id
    board.id
  end
  
end
