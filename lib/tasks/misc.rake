namespace :misc do

  desc "备份数据库"
  task :backup do
    '/usr/ruby /home/jill/mysql_backup/mysql_tools.rb backup'
  end
 
  desc "为没有坐标的团队设定初始位置"
  task :set_team_position  => :environment do
    Team.find(:all,:conditions => {:latitude => nil}).each do |t|
      t.latitude,t.longitude = t.geo.latitude,t.geo.longitude
      t.save
    end
  end

  
  desc "判定一周内没有上传证明的捐赠无效"
  task :check_sub_donation => :environment do
    SubDonation.all.each do |s|
      if (s.state == "ordered") && (s.created_at < 7.days.ago)
        s.refuse
        message = Message.new(
          :subject => "你为#{s.co_donation.school.title}捐赠的#{s.quantity}件#{s.co_donation.goods_name}失效了",
          :content => "<p>亲爱的用户：<br/>由于你没有在一周内按时上传捐赠证明，你的捐赠失效了。<br/>团捐页面地址 => http://www.1kg.org/co_donations/#{s.co_donation.id} </p><br/><p>多背一公斤团队</p>"
          )
        message.author_id = 0
        message.to = [s.user]
        message.save!
      end
    end
  end
  
  desc "公益项目数据迁移"
  task :projects_data_copy => :environment do
    RequirementType.non_exchangable.validated.each do |r|
      a = Project.new(
                  :user_id  => r.creator_id,
                  :title => r.title,
                  :validated_at => r.validated_at,
                  :created_at => r.created_at,
                  :updated_at => r.updated_at,
                  :description => r.description_html,
                  :support => r.support_html,
                  :condition => r.condition_html,
                  :feedback_require => r.feedback_require,
                  :start_at => r.start_at,
                  :end_at => r.end_at,
                  :for_envoy => r.must,
                  :apply_end_at => r.apply_end_at,
                  :feedback_at => r.feedback_at
                  )
      a.save
      r.requirements.each do |s|
        b = SubProject.new(
          :project_id => a.id,
          :user_id => s.applicator_id,
          :school_id => s.school_id,
          :status =>  s.status,
          :validated_at => s.validated_at,
          :validated => s.validated,
          :validated_by_id => s.validated_by_id,
          :plan => s.apply_plan,
          :reason => s.apply_reason,
          :feedback => s.feedback,
          :problem => s.problem,
          :budget => s.budget,
          :start_at => s.start_at,
          :end_at => s.end_at,
          :telephone => s.applicator_telephone,
          :created_at => s.created_at,
          :last_modified_at => s.last_modified_at
        )
        b.save
        s.shares.each do |x|
          x.sub_project_id = b.id
          x.save
        end
        s.comments.each do |c|
          c.commentable_id = b.id
          c.commentable_type = 'SubProject'
          c.save
        end
        
      end
      
    end
  end  

  
  desc "为有分享的结束活动标记"
  task :activity_done => :environment do
    Activity.find(:all,:conditions => {:done => false}).each do |a|
      if a.end_at < 1.day.ago
        done = true
        a.update_attribute(:done,done)
        $stdout.putc('.')
      end
    end
  end


  desc "删除失效的大使权限"
  task :role_delete => :environment do
    roles = Role.all.map{|r| r if r.identifier =~ /^roles.school.moderator./}.compact
    roles.each do |r|
      if School.find(:first,:conditions => {:id => (r.identifier).split('.').last.to_i}) == nil
        r.delete 
        $stdout.putc('.')
        $stdout.flush
      end
    end
  end  
  
  desc "删除失效的用户动态"
  task :visited_delete => :environment do
    Visited.all.each do |r|
      if School.find(:first,:conditions => {:id => r.school_id}) == nil
        r.delete 
        $stdout.putc('.')
        $stdout.flush
      end
    end
  end  

end