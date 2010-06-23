class CoDonation < ActiveRecord::Base
  belongs_to :school
  belongs_to :user
  
  attr_accessor :agree_feedback_terms

  has_many :sub_donations,:order => "created_at desc"
  has_many :comments, :as => 'commentable', :dependent => :destroy
  has_many :photos, :order => "id desc", :dependent => :destroy
    
  has_attached_file :image, :styles => {:medium => "300x300>", :thumb => "150x150>" }
  
  validates_presence_of :school_id, :goods_name, :goal_number, :end_at,:description, :plan, :address, :receiver, :zipcode, :phone_number,:goods_requirements,:message=> "此项是必填项"
  validates_acceptance_of :agree_feedback_terms,:message => "只有承诺按要求管理和反馈，才能发起团捐"
  
  named_scope :validated, :conditions => {:validated => true}, :order => "created_at desc"
  named_scope :not_validated, :conditions => {:validated => false}, :order => "created_at desc"  
  acts_as_paranoid
  
  
  def validate
      if end_at && (end_at > ((created_at.nil?? Time.now : created_at) + 3.month))
        errors.add(:end_at,"捐赠截止时间必须在三个月内")
      end
  end
   
  def still_need
    if (self.goal_number > self.number)
      self.goal_number - self.number
    else
      false
    end
  end
  
  def records
    self.sub_donations.by_state("received") + self.sub_donations.by_state("proved") + self.sub_donations.by_state("ordered") + self.sub_donations.by_state("missed") + self.sub_donations.by_state("refused")
  end
  
  def title
    "为#{self.school.title}捐赠#{self.goods_name}"
  end
  
  def clean_html
    self.description
  end
  
  def end?
    self.end_at < Time.now
  end
  
  def matched_percent
    self.done ? 100 : (self.number.to_f*100/self.goal_number).to_i
  end
    
  def update_number!
    self.number = (self.sub_donations.nil?? 0 : self.sub_donations.find(:all,:conditions => ["state in (?)",["ordered","received","proved"]]).map(&:quantity).sum)
    if self.number >= self.goal_number
      self.done = true
    else
      self.done = false
    end
    self.save
  end
  
end