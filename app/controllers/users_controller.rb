class UsersController < ApplicationController
  include Util
  # Be sure to include AuthenticationSystem in Application Controller instead
  #include AuthenticatedSystem
  
  # Protect these actions behind an admin login
  # before_filter :admin_required, :only => [:suspend, :unsuspend, :destroy, :purge]
  before_filter :find_user, :only => [:suspend, :unsuspend, :destroy, :purge, :show, :shares, :neighbors, :participated_activities, :submitted_activities, :submitted_schools, :visited_schools, :group_topics, :visited,:envoy, :submitted_topics,:participated_topics,:friends,:groups]
  before_filter :login_required, :only => [:edit, :update, :suspend, :unsuspend, :destroy, :purge]

  # render new.rhtml
  def new
  end
  
  def groups
    @groups = @user.joined_groups.paginate :page => params[:page] || 1, :per_page =>36
  end

  def create
    cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with 
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    if in_black_list?
      flash[:notice] = "对不起，你的IP地址由于发布垃圾信息已被列入黑名单，不能注册新用户，如果你确认这是一个错误，请联系我们的管理员"
      redirect_to root_path
    else
      unless params[:terms] == "1"
        flash[:notice] = "认真阅读免责声明并同意其中条款后, 请在最后一项上打钩"      
        render :action => "new"
      else
        @user = User.new(params[:user])
        @user.register! if @user.valid?
        if @user.errors.empty?
          @user.activate!
          @user.update_attribute(:ip, request.remote_ip)
          cookies[:onekg_id] = { :value => @user.id , :expires => 1.year.from_now }
          self.current_user = @user
          flash[:notice] = "注册成功！欢迎你来到多背一公斤, 补充一下你的个人信息吧"
          #redirect_to "/setting"
          redirect_back_or_default CGI.unescape(params[:to] || '/setting')
          #render :action => "wait_activation"
        else
          render :action => 'new'
        end
      end
    end
  end

  def activate
    self.current_user = params[:activation_code].blank? ? false : User.find_by_activation_code(params[:activation_code])
    if logged_in? && !self.current_user.active?
      self.current_user.activate!
      flash[:notice] = "注册成功！欢迎你来到多背一公斤, 补充一下你的个人信息吧"
      redirect_back_or_default CGI.unescape(params[:to] || '/setting')
    else
      flash[:notice] = "激活码不正确，请联系 feedback@1kg.org"
      redirect_back_or_default("/")
    end
    
  end
  
  def edit
    @page_title = "编辑个人信息"
    @user = current_user
    
    if params[:type] == "account"
      @type = "account"
      render :action => "setting_account"
    elsif params[:type] == 'profile'
      @type = "profile"
      @profile = @user.profile || Profile.new
      render :action => "setting_profile"
    else
      @type = "avatar"
      render :action => "setting_avatar" 
    end
  end
  
  def update
    @user = current_user
    
    if params[:for] == 'account'
      unless params[:user].blank?
        @user.geo_id       = params[:user][:geo_id]
        @user.login        = params[:user][:login]
        @user.email_notify = params[:user][:email_notify]
        @user.save
        flash[:notice] = "帐号设置更新成功"
      else
        flash[:notice] = "信息不完整，请重新填写"
      end
      redirect_to setting_url(:type => 'account')
    elsif params[:for] == 'password'
      @user.update_attributes!(params[:user])
      #self.current_user = @user
      flash[:notice] = "密码修改成功"
      redirect_to setting_url(:type => 'account')
    
  
      
    elsif params[:for] == 'avatar'
      avatar_convert(:user, :avatar)
      @user.update_attributes!(params[:user])
      flash[:notice] = "头像修改成功"
      redirect_to setting_url(:type => "avatar")
    

    elsif params[:for] == 'profile'
      if @user.profile
        @user.profile.update_attributes!(params[:profile])
      else
        # 用户第一次填个人资料
        profile = Profile.new(params[:profile])
        @user.profile = profile
        @user.save!
      end
      flash[:notice] = "个人资料修改成功"
      redirect_to setting_url(:type => 'profile')
      
    end
  end

  def suspend
    @user.suspend! 
    redirect_to users_path
  end

  def unsuspend
    @user.unsuspend! 
    redirect_to users_path
  end

  def destroy
    @user.delete!
    redirect_to users_path
  end

  def purge
    @user.destroy
    redirect_to users_path
  end
  
  def show
    get_user_record(@user)
    # postcard
    @donations = @user.donations
    @shares = @user.shares.find(:all, :limit => 5, :include => [:user, :tags])
    @visiteds = @user.visiteds.find(:all,:limit => 4,:order => "created_at desc",:include => [:school])
    @envoys = @user.envoy_schools(4)
    @submitted_topics = @user.topics.find :all, :limit => 6,:include => [:board, :user]
    @participated_topics = @user.participated_topics.paginate(:page => 1, :per_page => 6)
    
    # 目前只支持学校动态
    #@feed_items = FeedItem.find(:all, :conditions => ['((owner_type = ? and owner_id in (?)) or (user_id in (?))) and user_id <> ?', 'School', @user.followings.schools.map(&:followable_id), @user.followings.users.map(&:followable_id), @user.id], :order => 'created_at DESC', :limit => 10)
  end
  
  def shares
    @shares = @user.shares.find(:all, :conditions => ["hidden=?", false]).paginate(:page => params[:page] || 1, :per_page => 6)
  end


  def friends
    @followings = @user.neighbors.paginate(:page => params[:page] || 1, :per_page => 36)
    # 关注此用户的人
    @followers = Neighborhood.paginate(:page => params[:page] || 1, :per_page => 36, :limit => 8, :conditions => {:neighbor_id => @user.id}, :include => [:user])
  end
  
  def participated_activities
    @activities = @user.participated_activities.paginate(:page => params[:page] || 1, :per_page => 10)
  end
  
  def participated_topics
     @topics = @user.participated_topics.paginate(:page => params[:page] || 1, :per_page => 10)
  end
  
  def submitted_activities
    @activities = @user.submitted_activities.paginate(:page => params[:page] || 1, :per_page => 10)
  end
  
  def submitted_topics
    @topics = @user.topics.paginate(:page => params[:page] || 1, :per_page => 10)
  end
  
  def submitted_schools
    @schools = @user.submitted_schools.paginate(:page => params[:page] || 1, :per_page => 10)
  end
  
  def group_topics
    @topics = @user.joined_groups_topics.paginate :page => params[:page] || 1, :per_page => 10, :order => "last_replied_at desc"
  end
  
  def visited
    @visits = Visited.find(:all,:conditions => {:user_id => @user,:status => 1},:include => [:school])
    @wannas = Visited.find(:all,:conditions => ['user_id = ? and status = ? and visited_at > ?', @user.id, 3, Time.now], :include => [:school])
    @interests = Visited.find(:all,:conditions => {:user_id => @user,:status => 2},:include => [:school])
  end
  
  def envoy
    @schools = @user.envoy_schools
  end

  protected
  def find_user
    @user = User.find(params[:id])
  end
  
  def get_user_record(user)
    # user's published activities
    @submitted    = @user.submitted_activities.find(:all, :limit => 6,:include => [:main_photo, :departure])
    @participated = @user.participated_activities.find(:all, :limit => 6, :include => [:main_photo, :departure])
    
    # 用户关注的人
    @followings = user.neighbors.find :all, :limit => 8
    # 关注此用户的人
    @followers = Neighborhood.find(:all, :limit => 8, :conditions => {:neighbor_id => @user.id}, :include => [:user]).map(&:user)
    
    @groups = user.joined_groups.find :all, :limit => 8
  end
  
  def in_black_list?
    blocked_ids = User.find_only_deleted(:all, :conditions => ['state = ?', 'deleted']).map(&:id)
    cookies[:onekg_id] && blocked_ids.include?(cookies[:onekg_id].to_i)
  end
  
end