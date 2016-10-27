source 'https://github.com/nikola-mladenovic/Specs.git'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

def common_pods
    pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '997e480559ae6c4aef4ae906158a9ded531bdf14'
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
