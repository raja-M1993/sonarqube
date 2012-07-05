#
# Sonar, entreprise quality control tool.
# Copyright (C) 2008-2012 SonarSource
# mailto:contact AT sonarsource DOT com
#
# Sonar is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# Sonar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with Sonar; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02
#
class RolesController < ApplicationController
  helper RolesHelper

  SECTION=Navigation::SECTION_CONFIGURATION
  PER_PAGE = 2

  before_filter :admin_required
  verify :method => :post, :only => [:set_users, :set_groups, :set_default_project_groups, :set_default_project_users], :redirect_to => {:action => 'global'}


  # GET REQUESTS

  def global
  end

  def projects
    # for backward-compatibility with versions of views plugin that do not depend on sonar 3.0
    if java_facade.hasPlugin('views')
      @qualifiers = (['VW', 'SVW'] + java_facade.getQualifiersWithProperty('hasRolePolicy').to_a).compact.uniq
    else
      @qualifiers = java_facade.getQualifiersWithProperty('hasRolePolicy')
    end
    @qualifier = params[:qualifier] || 'TRK'


    conditions_sql = 'projects.enabled=:enabled and projects.qualifier=:qualifier and projects.copy_resource_id is null'
    conditions_values = {:enabled => true, :qualifier => @qualifier}
    joins = nil
    if params[:q].present?
      joins = "INNER JOIN resource_index on resource_index.resource_id=projects.id and resource_index.qualifier=#{ActiveRecord::Base::sanitize(@qualifier)} and resource_index.kee like #{ActiveRecord::Base::sanitize(params[:q] + '%')}"
    end

    @pagination = Api::Pagination.new(params)
    @projects=Project.find(:all,
                           :joins => joins,
                           :conditions => [conditions_sql, conditions_values],
                           :order => 'projects.name',
                           :offset => @pagination.offset,
                           :limit => @pagination.limit)
    @pagination.count=Project.count(:joins => joins, :conditions => [conditions_sql, conditions_values])
  end

  def edit_users
    @project=Project.by_key(params[:resource]) if params[:resource].present?
    @role = params[:role]
  end

  def edit_groups
    @project=Project.by_key(params[:resource]) if params[:resource].present?
    @role = params[:role]
  end

  def edit_default_project_groups
    bad_request('Missing role') if params[:role].blank?
    bad_request('Missing qualifier') if params[:qualifier].blank?
  end

  def edit_default_project_users
    bad_request('Missing role') if params[:role].blank?
    bad_request('Missing qualifier') if params[:qualifier].blank?
  end

  # POST REQUESTS

  def set_users
    bad_request('Missing role') if params[:role].blank?
    UserRole.grant_users(params[:users], params[:role], params[:resource])
    redirect
  end

  def set_groups
    bad_request('Missing role') if params[:role].blank?
    GroupRole.grant_groups(params[:groups], params[:role], params[:resource])
    redirect
  end

  def set_default_project_groups
    bad_request('Missing role') if params[:role].blank?
    bad_request('Missing qualifier') if params[:qualifier].blank?
    Property.set("sonar.role.#{params[:role]}.#{params[:qualifier]}.defaultGroups", params[:groups].join(','))
    redirect
  end

  def set_default_project_users
    bad_request('Missing role') if params[:role].blank?
    bad_request('Missing qualifier') if params[:qualifier].blank?
    Property.set("sonar.role.#{params[:role]}.#{params[:qualifier]}.defaultUsers", params[:users].join(','))
    redirect
  end

  private
  def redirect
    redirect_to(:action => params['redirect'] || 'global', :q => params[:q], :qualifier => params[:qualifier], :page => params[:page])
  end
end
