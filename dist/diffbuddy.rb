cask "diffbuddy" do
  version "1.0.0"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/REPLACE_OWNER/DiffBuddy/releases/download/v#{version}/DiffBuddy.dmg"
  name "DiffBuddy"
  desc "Side-by-side text diff viewer for macOS"
  homepage "https://github.com/REPLACE_OWNER/DiffBuddy"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "DiffBuddy.app"

  zap trash: [
    "~/Library/Preferences/app.diffbuddy.plist",
    "~/Library/Caches/app.diffbuddy",
    "~/Library/Containers/app.diffbuddy",
  ]
end
