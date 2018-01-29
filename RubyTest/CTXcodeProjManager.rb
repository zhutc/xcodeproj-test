require 'xcodeproj'

# MCD Bundle 类型定义
class CTCtripBundle
  attr_accessor :name # 名称 如： CTChat
  attr_accessor :path # 根目录
  attr_accessor :has_bundle # 是否拥有资源
  attr_accessor :libraries # 所有的静态库 , [ "libxxx.a" , "other/libxxx.a" ] , 格式为相对于根目录的路径
  attr_accessor :bundles # 所有的bundle ， [ "xxxbundle.Bundle" , "other/xxxBundle.Bundle" ]  , 格式为相对于根目录路径
  attr_accessor :system_frameworks # 依赖的系统的framework
  attr_accessor :system_libraries # 依赖的系统的libraries
  attr_accessor :uncopy_resource # 不拷贝资源
  attr_accessor :has_include # 是否有头文件，默认为true

  def initialize(config)
    self.name = config[:name]
    self.path = config[:path]
    self.has_bundle = config[:has_bundle]
    self.libraries = config[:libraries]
    self.bundles = config[:bundles]
    self.system_frameworks = config[:system_frameworks]
    self.system_libraries = config[:system_libraries]
    self.uncopy_resource = config[:uncopy_resource] || false
    self.has_include = config[:has_include] || true
  end

  #获取library的绝对路径
  def real_library_path(relative_path)
      File.join(self.path , relative_path)
  end

end

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

  def main_group # 自定义main_group
    group = project.main_group["Dependency"]
    if group
      return group
    end
    project.main_group
  end

  def initialize(path)
    self.root_project_path = path
    @project = Xcodeproj::Project.open(path)

  end

  # 创建对应的group
  def create_group_if_need(group_name)
    if not self.main_group[group_name]
      self.main_group.new_group group_name
    end
    self.main_group[group_name]
  end

  # 创建 library 下的子bundle group
  def create_bundle_group_if_need(group_name)
    library_group = self.create_group_if_need self.group_name_for_library
    if not library_group[group_name]
      library_group.new_group group_name
    end
    library_group[group_name]
  end


  def add_search_path(path)
    search_path = path
    case File.extname(path).downcase
      when '.xcodeproj' # xcodeproj方式配置搜索路径
        # search_path = File.join(File.split(path).first,"**")
        # 为了能delete search path 直接追加父目录
        search_path = File.join(path, "../**") # ../text.xcodeproj  =>  ../text.xcodeproj/../**
      when "" # and File.directory?(path)
        # 静态库类型
        search_path = File.join path , "/**"
      else

    end

    # build_configuraiton 配置search_path
    self.main_target.build_configurations.each do |configuration|
      if configuration.is_a?(Xcodeproj::Project::XCBuildConfiguration)
        # 暂时无脑配置三端路径
        ["HEADER_SEARCH_PATHS" , "FRAMEWORK_SEARCH_PATHS" , "LIBRARY_SEARCH_PATHS" ].each do | type |
          header_search_paths = configuration.build_settings[ type ]
          puts header_search_paths
          if header_search_paths.is_a?(String)
            if header_search_paths == ""
              header_search_paths = []
            else
              header_search_paths = [header_search_paths]
            end
          end
          header_search_paths = [] unless (header_search_paths != "")
          if header_search_paths.is_a?(Array)
            new_header_search_paths = Array.new header_search_paths
            if not header_search_paths.include?(search_path)
              new_header_search_paths << search_path
            end
            configuration.build_settings[ type ] = new_header_search_paths
          end
        end
      end

    end
    self.project.save
  end

  def remove_search_path(path)
    search_path = path

    # build_configuraiton 配置search_path
    self.main_target.build_configurations.each do |configuration|
      if configuration.is_a?(Xcodeproj::Project::XCBuildConfiguration)
        ["HEADER_SEARCH_PATHS" , "FRAMEWORK_SEARCH_PATHS" , "LIBRARY_SEARCH_PATHS" ].each do | type |
          header_search_paths = configuration.build_settings[ type ]
          if header_search_paths.is_a?(Array)
            new_header_search_paths = Array.new(header_search_paths)
            header_search_paths.each do |value|
              if value.include?(search_path)
                new_header_search_paths.delete value
              end
            end
            configuration.build_settings[ type ] = new_header_search_paths
          elsif  header_search_paths.is_a?(String) and header_search_paths.include? search_path
            header_search_paths = ""
            configuration.build_settings[ type ] = header_search_paths
          end
        end

      end
    end
    self.project.save
  end


  #添加一个sub project
  # main_target dependency sub
  # main_target link sub product
  # main_frameworks_build_phase add new reference_proxy build_file
  # @path : 子工程的project path , ex : "../XcodeProjLibA/XcodeProjLibA.xcodeproj"

  def add_subproject(path, add_search_path = true)
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
        product_group_ref.children.each do |ob|
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

    #默认配置头文件
    if add_search_path
      self.add_search_path path
    end

    project.save
  end


  # remove file_reference target_dependency and frameworks_build_phase
  # @xcodeProj_name 传入子工程的project_name ex : "XcodeProjLibA.xcodeproj"

  def remove_subproject(xcodeProj_name, remove_search_path = true)
    # 获取子工程的project_reference
    project_references = self.project.root_object.project_references

    main_target_frameworks_buikd_phase = self.main_target.frameworks_build_phase

    # 移除framework_build_phase
    if project_references.is_a? Xcodeproj::Project::ObjectList
      project_references.each do |project_reference|
        if project_reference[:project_ref].name == xcodeProj_name
          product_group = project_reference[:product_group]
          product_group.children.each do |reference_proxy|
            if reference_proxy.is_a?(Xcodeproj::Project::PBXReferenceProxy)
              main_target_frameworks_buikd_phase.files.each do |build_file|
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

    if remove_search_path
      self.remove_search_path xcodeProj_name
    end

    self.project.save
  end

  # 引用ctrip bundle
  # Bundle => {
  #   include : header
  #   xxxx.bundle :  resource
  #   xxxx.a : statice library
  # }
  def add_bundle(bundle)

    if bundle and bundle.is_a?( CTCtripBundle )
      # bundle = CTCtripBundle.new({}) #仅仅是为了代码补全
      # dependency_group = Xcodeproj::Project::PBXGroup.new(self.project , "") #仅仅是为了代码补全
      # target = Xcodeproj::Project::PBXNativeTarget.new(project,"") #仅仅是为了代码补全s

      dependency_group = create_bundle_group_if_need bundle.name
      target = self.main_target

      # 暂时不处理 system frameworks libraries
      # 1. add libraries
      if bundle.libraries and bundle.libraries.is_a?(Array)
        bundle.libraries.each do | library_path |
          real_path = bundle.real_library_path library_path
          library_file_reference =  dependency_group.new_reference real_path
          target.frameworks_build_phase.add_file_reference library_file_reference , true
        end
      end
      # 2. add .bundle
      if bundle.has_bundle and not bundle.uncopy_resource
        bundle.bundles.each do | bundle_path |
          real_path = bundle.real_library_path bundle_path
          bundle_file_reference = dependency_group.new_reference real_path
          target.resources_build_phase.add_file_reference bundle_file_reference
        end
      end
      # 3. add include
      if bundle.has_include
        include_name = "include"
        include_path = bundle.real_library_path include_name
        include_file_reference = dependency_group.new_reference include_path
        include_file_reference.last_known_file_type = "folder" # 为了加快 xcode indexing 使用folder形式
      end

      self.add_search_path bundle.path
      self.project.save
    end

  end


  def remove_bundle(bundle)

    dependency_group = self.create_group_if_need group_name_for_library
    bundle_group = self.create_bundle_group_if_need bundle.name
    target = self.main_target

    # bundle = CTCtripBundle.new({}) #仅仅是为了代码补全
    # dependency_group = Xcodeproj::Project::PBXGroup.new(self.project , "") #仅仅是为了代码补全
    # target = Xcodeproj::Project::PBXNativeTarget.new(project,"") #仅仅是为了代码补全

    if bundle.has_bundle and not bundle.uncopy_resource
      bundle_group.files.each do | bundle_files_reference |
        if target.resources_build_phase.include? bundle_files_reference
            target.resources_build_phase.remove_file_reference bundle_files_reference
        end
      end
    end

    if bundle.libraries and bundle.libraries.is_a?(Array)
      bundle_group.files.each do | bundle_files_reference |
        if target.frameworks_build_phase.include? bundle_files_reference
          target.frameworks_build_phase.remove_file_reference bundle_files_reference
        end
      end
    end
    bundle_group.clear
    dependency_group.children.delete bundle_group

    self.remove_search_path bundle.path

    self.project.save
  end

end


def test_add_project()
  root_path = "../XcodeProjTest/XcodeProjTest.xcodeproj"
  manager = CTXcodeProjManager.new root_path


  sub_path_a = "../XcodeProjLibA/XcodeProjLibA.xcodeproj"
  sub_path_b = "../XcodeProjLibB/XcodeProjLibB.xcodeproj"

  manager.remove_subproject "XcodeProjLibA.xcodeproj"
  manager.remove_subproject "XcodeProjLibB.xcodeproj"
#
# # 添加subprojectsub_path_a
  manager.add_subproject sub_path_a
  manager.add_subproject sub_path_b
end

def test_add_library()
  root_path = "../XcodeProjTest/XcodeProjTest.xcodeproj"
  manager = CTXcodeProjManager.new root_path
  test_bundle = CTCtripBundle.new({
                                      :name => "XcodeProjLibC" ,
                                      :path => "/Users/tczhu/work/CodeTest/xcodeproj-test/libraries/libC",
                                      :has_bundle => true,
                                      :libraries => [ "libXcodeProjLibC.a" ],
                                      :bundles => [ "ARBundle.bundle" ],
                                      :has_include => true,
                                      :uncopy_resource => true,
                                  })
  manager.remove_bundle test_bundle
  manager.add_bundle test_bundle
end


test_add_library

test_add_project



