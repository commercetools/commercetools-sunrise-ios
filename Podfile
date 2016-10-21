source 'https://github.com/nikola-mladenovic/Specs.git'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

def common_pods
    pod 'ReactiveCocoa', '~> 5.0.0-alpha.1'
    pod 'ReactiveObjC'
end

target 'Sunrise' do
    pod 'Commercetools', :git => 'https://github.com/commercetools/commercetools-ios-sdk.git', :commit => '893e6bfdbba145f55e9769df5d3d76519522797f'
    pod 'IQKeyboardManagerSwift'
    pod 'SDWebImage'
    pod 'IQDropDownTextField'
    pod 'SVProgressHUD'
    pod 'DZNEmptyDataSet'
    common_pods
end

def testing_pods
    pod 'Quick'
    pod 'Nimble'
    pod 'ObjectMapper'
end

target 'SunriseTests' do
    testing_pods
    common_pods
end

target 'SunriseUITests' do
    testing_pods
end
