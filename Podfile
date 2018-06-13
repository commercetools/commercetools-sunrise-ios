platform :ios, '10.0'
use_frameworks!

def common_pods
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :branch => 'nfc-sunrise'
  pod 'ReactiveCocoa'
  pod 'ReactiveObjC'
end

target 'Sunrise' do
  common_pods
  pod 'CardIO'
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
  pod 'DateToolsSwift'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '3.0'
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :branch => 'nfc-sunrise'
  pod 'ReactiveSwift'
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
