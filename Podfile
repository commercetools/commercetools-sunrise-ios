platform :ios, '10.0'
use_frameworks!

def common_pods
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '13d8ecad395a562c57039eceb58da64e7cd29b83'
  pod 'ReactiveCocoa', :git => 'https://github.com/ReactiveCocoa/ReactiveCocoa.git', :tag => '6.0.0-rc.3'
  pod 'ReactiveObjC'
  pod 'DZNEmptyDataSet'
end

target 'Sunrise' do
  common_pods
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '3.0'
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '13d8ecad395a562c57039eceb58da64e7cd29b83'
  pod 'ReactiveSwift', :git => 'https://github.com/ReactiveCocoa/ReactiveSwift.git', :tag => '2.0.0-rc.3'
  pod 'SDWebImage'
  pod 'NKWatchActivityIndicator'
end

def testing_pods
  pod 'Quick'
  pod 'Nimble'
end

target 'SunriseTests' do
  testing_pods
  common_pods
end

target 'SunriseUITests' do
  testing_pods
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['SWIFT_VERSION'] = '3.2' unless target.name.include? 'Commercetools'
      end
    end
end
