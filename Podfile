platform :ios, '11.0'
use_frameworks!

def common_pods
  pod 'Commercetools'
  pod 'ReactiveSwift'
end

target 'Sunrise' do
  common_pods
  pod 'ReactiveCocoa', '~> 9.0'
  pod 'CardIO'
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
  pod 'DateToolsSwift'
  pod 'AWSS3'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage'
end

target 'SunriseIntents' do
  common_pods
end

target 'SunriseOrderIntentUI' do
  common_pods
  pod 'ReactiveCocoa'
  pod 'SDWebImage'
end

target 'SunriseReserveIntentUI' do
  common_pods
  pod 'ReactiveCocoa'
  pod 'SDWebImage'
end

target 'Sunrise Watch Extension' do
  platform :watchos, '4.0'
  common_pods
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
