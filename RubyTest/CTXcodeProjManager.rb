require 'xcodeproj'

class CTXcodeProjManager
  # 主工程的路径
  attr_accessor :root_project_path
  attr_reader :main_target
  attr_reader :project # 主工程PBXProject

  def main_target
    return project.native_targets.first
  end

  def initialize(path)
    self.root_project_path = path
    @project = Xcodeproj::Project.open(path)

  end

  #添加一个sub project
  # main_target dependency sub
  # main_target link sub product
  def add_subproject(path)
    # 添加sub到Dependency group中
    path = Pathname(path).realpath
    dependency_group = project.main_group["Dependency"]

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


end

root_path = "../XcodeProjTest/XcodeProjTest.xcodeproj"
manager = CTXcodeProjManager.new root_path

sub_path_a = "../XcodeProjLibA/XcodeProjLibA.xcodeproj"
sub_path_b = "../XcodeProjLibB/XcodeProjLibB.xcodeproj"

# 添加subproject
manager.add_subproject sub_path_a
manager.add_subproject sub_path_b
