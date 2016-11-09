source 'https://github.com/nikola-mladenovic/Specs.git'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

def common_pods
  pod 'Commercetools'
  pod 'ReactiveCocoa', '~> 5.0.0-alpha.1'
  pod 'ReactiveObjC'
end

target 'Sunrise' do
  common_pods
  pod 'IQKeyboardManagerSwift'
  pod 'SDWebImage'
  pod 'IQDropDownTextField'
  pod 'SVProgressHUD'
  pod 'DZNEmptyDataSet'
end

target 'ReservationNotification' do
  common_pods
  pod 'SDWebImage'
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
