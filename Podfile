platform :ios, '17.0'
use_frameworks!

target 'SanadApp' do
  # لا توجد تبعيات Firebase الآن
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ALWAYS_SEARCH_USER_PATHS'] = 'NO'
      config.build_settings['USE_HEADERMAP'] = 'NO'
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['HEADER_SEARCH_PATHS'] << '"${PODS_ROOT}/PromisesObjC/Sources/FBLPromises/include"'
    end
  end
end
