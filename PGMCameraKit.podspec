Pod::Spec.new do |s|
s.name             = "PGMCameraKit"
s.version          = "0.1.4"
s.summary          = "Camera library to record video (inc pause and resume features), compress video and fully customize the camera."
s.description      = <<-DESC
Swift library to provide all the configurations you need to create a camera view: start / pause / resume / stop recording, video compression, max video duration threshold, it follows camera orientation change, front and back camera, flash modes, video / still image modes, output quality, etc...
DESC

s.homepage         = "https://github.com/pablogm/CameraKit"
# s.screenshots     = "www.example.com/screenshots_1", "www.example.com/screenshots_2"
s.license          = 'MIT'
s.author           = { "Pablo GM" => "invanzert@gmail.com" }
s.source           = { :git => "https://github.com/pablogm/CameraKit.git", :tag => s.version.to_s }
# s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

s.platform     = :ios, '8.0'
s.requires_arc = true

s.source_files = 'Pod/Classes/**/*'
s.resource_bundles = {
'CameraKit' => ['Pod/Assets/*.png']
}

# s.public_header_files = 'Pod/Classes/**/*.h'
# s.frameworks = 'UIKit', 'MapKit'
s.dependency 'PGMTimer'
end
