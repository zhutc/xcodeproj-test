require 'xcodeproj'

class CTXcodeProjManager
  # 主工程的路径
  attr_accessor :root_project_path
  attr_reader :main_target
  attr_reader :project # 主工程PBXProject
  attr_reader :group_name_for_project
  attr_reader :group_name_for_library

  def group_name_for_library
    "CTLibraryDependency"
  end

  def group_name_for_project
    "CTProjectDependency"
  end

  def main_target
    return project.native_targets.first
  end

  def initialize(path)
    self.root_project_path = path
    @project = Xcodeproj::Project.open(path)

  end

  # 创建对应的group
  def create_group_if_need(group_name)
    if not project.main_group[group_name]
        project.new_group group_name
    end
    project.main_group[group_name]
  end

  def add_search_path(path)
    search_path = path
    case File.extname(path).downcase
      when '.xcodeproj' # xcodeproj方式配置搜索路径
        # search_path = File.join(File.split(path).first,"**")
        # 为了能delete search path 直接追加父目录
        search_path = File.join(path , "../**") # ../text.xcodeproj  =>  ../text.xcodeproj/../**
      else
        # 静态库类型
    end

    # build_configuraiton 配置search_path
    self.main_target.build_configurations.each do | configuration |
      if configuration.is_a?(Xcodeproj::Project::XCBuildConfiguration)
        header_search_paths = configuration.build_settings["HEADER_SEARCH_PATHS"]
        puts header_search_paths
        header_search_paths = [] unless (header_search_paths != "")
        if header_search_paths.is_a?(Array) and not header_search_paths.include?(search_path)
          header_search_paths << search_path
        end
        configuration.build_settings["HEADER_SEARCH_PATHS"] =  header_search_paths
      end
    end
    self.project.save

  end

  #添加一个sub project
  # main_target dependency sub
  # main_target link sub product
  # main_frameworks_build_phase add new reference_proxy build_file
  # @path : 子工程的project path , ex : "../XcodeProjLibA/XcodeProjLibA.xcodeproj"

  def add_subproject(path)
    # 添加sub到Dependency group中
    path = Pathname(path).realpath
    dependency_group = create_group_if_need group_name_for_project

    sub_filereference = nil
    if dependency_group
      sub_filereference = dependency_group.new_reference path #相对于主工程的路径
    end

    # 添加target dependency
    sub_project = Xcodeproj::Project.open path
    sub_target = sub_project.native_targets.first #todo: first target is static library, second target is bundle if has

    main_target.add_dependency sub_target # 添加 PBXContainerProxyItem type = 1

    # 根据filereference 找到 referenceproxy
    sub_referenceproxy = nil
    project.root_object.project_references.each do |project_reference|
      if project_reference[:project_ref].uuid == sub_filereference.uuid
          product_group_ref = project_reference[:product_group]
          product_group_ref.children.each do | ob |
            if ob.is_a?(Xcodeproj::Project::PBXReferenceProxy)
              if ob.remote_ref.container_portal == sub_filereference.uuid and ob.file_type == Xcodeproj::Constants::FILE_TYPES_BY_EXTENSION["a"]
                sub_referenceproxy = ob
              end
            end
          end

      end
    end

    # 添加frameworkbuildphase
    main_frameworkbuildphase = main_target.frameworks_build_phase
    main_frameworkbuildphase.add_file_reference sub_referenceproxy

    project.save
  end


  # remove file_reference target_dependency and frameworks_build_phase
  # @xcodeProj_name 传入子工程的project_name ex : "XcodeProjLibA.xcodeproj"

  def remove_subproject(xcodeProj_name )
    # 获取子工程的project_reference
    project_references = self.project.root_object.project_references

    main_target_frameworks_buikd_phase =  self.main_target.frameworks_build_phase

    # 移除framework_build_phase
    if project_references.is_a? Xcodeproj::Project::ObjectList
        project_references.each do | project_reference |
          if project_reference[:project_ref].name == xcodeProj_name
              product_group = project_reference[:product_group]
              product_group.children.each do | reference_proxy |
                if reference_proxy.is_a?(Xcodeproj::Project::PBXReferenceProxy)
                    main_target_frameworks_buikd_phase.files.each do | build_file |
                        if build_file.file_ref.uuid == reference_proxy.uuid
                            main_target_frameworks_buikd_phase.remove_build_file(build_file)
                        end
                    end
                end
              end
              project_reference[:project_ref].remove_from_project
          end
        end
    end

    #移除文件引用
    self.project.save
  end

end

root_path = "../XcodeProjTest/XcodeProjTest.xcodeproj"
manager = CTXcodeProjManager.new root_path


sub_path_a = "../XcodeProjLibA/XcodeProjLibA.xcodeproj"
sub_path_b = "../XcodeProjLibB/XcodeProjLibB.xcodeproj"

manager.remove_subproject "XcodeProjLibA.xcodeproj"
# manager.remove_subproject "XcodeProjLibB.xcodeproj"
#
# # 添加subproject
manager.add_subproject sub_path_a
# manager.add_subproject sub_path_b

manager.add_search_path sub_path_a

