#使用xcodeproj练习

require 'xcodeproj'

proj_path = "/Users/tczhu/work/CodeTest/xcodeproj-test/XcodeProjTest/XcodeProjTest.xcodeproj"

project = Xcodeproj::Project.open proj_path
puts "project.name = #{project.root_object.name}"
build_cofiguration_list = project.build_configuration_list


#这是操作的都是主工程PBXProject
# 判断class不要加域名~~~
if build_cofiguration_list.is_a?(Xcodeproj::Project::XCConfigurationList)
  puts "XCConfigurationList is XCConfigurationList class"
  # 获取root project下边的 configuration
  build_configurations = build_cofiguration_list.build_configurations
  if build_configurations.is_a?(Xcodeproj::Project::ObjectList)
      puts "build_cofigurations is ObjectList class"
      build_configurations.each do | configuration |
        puts "#{configuration.name}.uuid is #{configuration.uuid}"
        configuration.pretty_print
      end
  end
end

#操作主工程的PBXNativeTarget

native_targets = project.native_targets
if native_targets.kind_of?(Array)
  puts "native_targets is ObjectList class"
  native_targets.each do |target|
    build_configurations = target.build_configurations
    if build_configurations.is_a?(Xcodeproj::Project::ObjectList)
      build_configurations.each do |configuration|
        puts "======= #{configuration.name} builldsettting ==========="
        puts "uuid = #{configuration.uuid}"
        puts "buildsetting = #{configuration.build_settings}"
        puts "HEADER_SEARCH_PATHS = #{configuration.resolve_build_setting "HEADER_SEARCH_PATHS"}"
        puts "Modify Debug HEADER_SEARCH_PATHS ,Project is dirty #{project.dirty?}"
        if configuration.name == "Debug" # 尝试修改的header——searchpath
          configuration.build_settings["HEADER_SEARCH_PATHS"] = "../newDebug/header/**"
          project.save # 保存project文件
        end
      end
    end
  end
end


path_lib_a = "../XcodeProjLibA/XcodeProjLibA.xcodeproj"


# 1.添加target依赖
main_target =  native_targets.first
target_xcodeproj_test = main_target
if target_xcodeproj_test && target_xcodeproj_test.name == "XcodeProjTest"
  #给主工程的target配置dependency
  lib_a_project = Xcodeproj::Project.open(path_lib_a)
  lib_a_target = lib_a_project.native_targets.first
  if lib_a_project
    target_xcodeproj_test.add_dependency lib_a_target

    #2. 添加主target FrameworkBuildPhase
    #首先从maingorup中获取到PBXReferenceProxy
    referenceproxy_lib_a = nil
    project.objects_by_uuid.each do | uuid,ob |
      if ob.isa == "PBXReferenceProxy"
        referenceproxy_lib_a = ob
      end
    end

    # 给frameworkbuildphase 添加buildfile
    frameworkbuildphase_main_target = main_target.frameworks_build_phases
    # 添加buildfile
    frameworkbuildphase_main_target.add_file_reference(referenceproxy_lib_a)

  end
end

project.save







=begin

 rootobject is_a PBXProject 是主工程的配置
 我们操作的对象一般都是PBXNativeTarget

=end






