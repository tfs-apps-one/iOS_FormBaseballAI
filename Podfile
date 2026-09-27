# Podfile — AI Baseball Form Coach (iOS)
# Run: pod install   then open FormBaseballAI.xcworkspace

platform :ios, '17.0'
use_frameworks!

target 'FormBaseballAI' do
  # ── ML Kit Pose Detection ──────────────────────────────────────────────────
  # Accurate mode (same model used in the Android version)
  pod 'GoogleMLKit/PoseDetectionAccurate', '~> 7.0'

  # ── Ads ────────────────────────────────────────────────────────────────────
  pod 'Google-Mobile-Ads-SDK'

end

target 'FormBaseballAITests' do
  inherit! :search_paths
end

target 'FormBaseballAIUITests' do
  inherit! :search_paths
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end
