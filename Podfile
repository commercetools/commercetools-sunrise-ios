platform :ios, '9.0'
use_frameworks!

def common_pods
    pod 'ReactiveCocoa', '~> 4.1'
    pod 'ObjectMapper', '~> 1.3'
end

target 'Sunrise' do
    pod 'Commercetools', '~> 0.2'    
    pod 'IQKeyboardManagerSwift', '4.0.3'
    pod 'SDWebImage', '~> 3.7'
    pod 'IQDropDownTextField'
    pod 'SVProgressHUD'
    pod 'DZNEmptyDataSet'
    common_pods
    # PushTech SDK requires MagicalRecord
    pod 'MagicalRecord', '~> 2.2'
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
