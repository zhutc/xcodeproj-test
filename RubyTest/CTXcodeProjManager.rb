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
    dependency_path = self.root_project_path.gsub(/XcodeProjTest.xcodeproj/, "Dependency")
    path = Pathname(path).realpath
    dependency_group = project.main_group["Dependency"]
    if dependency_group
      dependency_group.new_reference path #相对于主工程的路径
    end
    project.save
  end


end

root_path = "../XcodeProjTest/XcodeProjTest.xcodeproj"
manager = CTXcodeProjManager.new root_path

sub_path_a = "../XcodeProjLibA/XcodeProjLibA.xcodeproj"

# 添加subproject
manager.add_subproject sub_path_a

