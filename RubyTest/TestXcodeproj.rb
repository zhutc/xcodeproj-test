#使用xcodeproj练习

require 'xcodeproj'

proj_path = "/Users/tczhu/work/CodeTest/XcodeProjTest/XcodeProjTest.xcodeproj"

project = Xcodeproj::Project.open proj_path
puts "project.name = #{project.root_object.name}"
build_cofiguration_list = project.build_configuration_list

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


