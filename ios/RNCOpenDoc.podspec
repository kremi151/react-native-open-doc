
Pod::Spec.new do |s|
  s.name         = "RNCOpenDoc"
  s.version      = "1.0.0"
  s.summary      = "React Native module for openning documents"
  s.description  = <<-DESC
                  RNCOpenDoc
                   DESC
  s.homepage     = "n/a"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "author" => "guy.blank@capriza.com" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/capriza/react-native-open-doc.git", :tag => "master" }
  s.source_files  = "*.{h,m}"
  s.requires_arc = true


  s.dependency "React"
  s.dependency "NSTiffSplitter"

end

  