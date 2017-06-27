platform :ios, '10.0'
use_frameworks!

def common_pods
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '023bbb24f8efa4b789c187af33050ab01f9415af'
  pod 'ReactiveCocoa'
  pod 'ReactiveObjC'
  pod 'DZNEmptyDataSet'
end

target 'Sunrise' do
  common_pods
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage', '4.0.0-beta2'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage', '4.0.0-beta2'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '3.0'
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '023bbb24f8efa4b789c187af33050ab01f9415af'
  pod 'ReactiveSwift'
  pod 'SDWebImage', '4.0.0-beta2'
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
