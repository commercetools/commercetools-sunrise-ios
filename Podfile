platform :ios, '11.0'
use_frameworks!

def common_pods
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :branch => 'master'
  pod 'ReactiveCocoa', '~> 7.2'
end

target 'Sunrise' do
  common_pods
  pod 'CardIO'
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
  pod 'DateToolsSwift'
  pod 'AWSS3'
end

target 'ReservationNotification' do
pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :branch => 'master'
pod 'ReactiveCocoa', '~> 7.2'
  pod 'SDWebImage'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '4.0'
  pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :branch => 'master'
  pod 'ReactiveSwift'
  pod 'SDWebImage'
  pod 'NKWatchActivityIndicator'
end

def testing_pods
  pod 'Quick'
  pod 'Nimble'
  pod 'CardIO'
end

target 'SunriseTests' do
  testing_pods
  common_pods
end
