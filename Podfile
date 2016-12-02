platform :ios, '10.0'
use_frameworks!

def common_pods
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '1894ab275ced503c2503aba4786efc1efc12af48'
  pod 'ReactiveCocoa', '~> 5.0.0-alpha.3'
  pod 'ReactiveObjC'
end

target 'Sunrise' do
  common_pods
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage', '4.0.0-beta2'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
  pod 'DZNEmptyDataSet'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage', '4.0.0-beta2'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '3.0'
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '1894ab275ced503c2503aba4786efc1efc12af48'
  pod 'ReactiveCocoa', '~> 5.0.0-alpha.3'
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
