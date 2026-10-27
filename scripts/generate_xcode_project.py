"""Generate two native Xcode targets sharing the same SwiftUI source files."""
from hashlib import sha1
from pathlib import Path
import shutil
import json
import re

root = Path(__file__).resolve().parents[1] / "apps/apple"
(root / "Resources").mkdir(parents=True, exist_ok=True)
shutil.copyfile(Path(__file__).resolve().parents[1] / "planning/changelog.json", root / "Resources/changelog.json")
signing_path = root / "Signing.local.json"
signing = json.loads(signing_path.read_text()) if signing_path.exists() else {}
if signing.get("development_team"):
    assert re.fullmatch(r"[A-Z0-9]{10}", signing["development_team"]), "Invalid local development team ID"
def uid(value):
    return sha1(value.encode()).hexdigest()[:24].upper()
objects = []
def obj(name, body):
    objects.append(f"\t\t{uid(name)} = {{ {body} }};")
def refs(names):
    return "(" + ", ".join(uid(n) for n in names) + ",)"

sources = sorted((root / "OrcaPlayer").glob("*.swift"))
for source in sources:
    obj("file-" + source.name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{source.name}"; sourceTree = "<group>";')
obj("demo-audio", 'isa = PBXFileReference; lastKnownFileType = audio.wav; path = "Resources/Orca-Soundcheck.wav"; sourceTree = "<group>";')
obj("journal-data", 'isa = PBXFileReference; lastKnownFileType = text.json; path = "Resources/changelog.json"; sourceTree = "<group>";')

checks = []  # Vehicle identification tones retired; not shipped in the app.
for check in checks:
    obj(check, f'isa = PBXFileReference; lastKnownFileType = audio.wav; path = "Resources/{check}"; sourceTree = "<group>";')
targets = []
products = []
for platform in ["macOS", "iOS"]:
    name = "OrcaPlayer-" + platform
    targets.append(name)
    products.append("product-" + platform)
    obj("product-" + platform, 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = OrcaPlayer.app; sourceTree = BUILT_PRODUCTS_DIR;')
    for source in sources:
        obj(platform + "-build-" + source.name, f"isa = PBXBuildFile; fileRef = {uid('file-' + source.name)};")
    obj(platform + "-sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs([platform + '-build-' + s.name for s in sources])}; runOnlyForDeploymentPostprocessing = 0;")
    obj(platform + "-frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    obj(platform + "-demo-build", f'isa = PBXBuildFile; fileRef = {uid("demo-audio")};')
    obj(platform + "-journal-build", f'isa = PBXBuildFile; fileRef = {uid("journal-data")};')
    for check in checks:
        obj(platform + check, f'isa = PBXBuildFile; fileRef = {uid(check)};')
    obj(platform + "-resources", f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs([platform + "-demo-build", platform + "-journal-build"] + [platform + c for c in checks])}; runOnlyForDeploymentPostprocessing = 0;')
    for config in ["Debug", "Release"]:
        settings = {
            "PRODUCT_NAME": "OrcaPlayer", "PRODUCT_BUNDLE_IDENTIFIER": "com.orca.player.preview" + (".mac" if platform == "macOS" else ".ios"),
            "SWIFT_VERSION": "6.0", "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "Music Player",
            "MARKETING_VERSION": "0.12.0", "CURRENT_PROJECT_VERSION": "15", "CODE_SIGN_STYLE": "Automatic",
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if config == "Debug" else "-O",
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "ENABLE_HARDENED_RUNTIME": "YES",
            "SDKROOT": "macosx" if platform == "macOS" else "iphoneos",
            "SUPPORTED_PLATFORMS": "macosx" if platform == "macOS" else "iphoneos iphonesimulator",
        }
        if platform == "macOS":
            settings.update(MACOSX_DEPLOYMENT_TARGET="14.0", INFOPLIST_KEY_LSApplicationCategoryType="public.app-category.music")
        else:
            settings["INFOPLIST_FILE"] = "Resources/iOS-Info.plist"
            settings.update(IPHONEOS_DEPLOYMENT_TARGET="17.0", TARGETED_DEVICE_FAMILY="1,2", INFOPLIST_KEY_UILaunchScreen_Generation="YES", INFOPLIST_KEY_UIApplicationSceneManifest_Generation="YES", SUPPORTS_MACCATALYST="NO")
            if signing.get("development_team"):
                settings["DEVELOPMENT_TEAM"] = signing["development_team"]
        body = " ".join(f'{key} = "{value}";' for key, value in settings.items())
        obj(platform + "-" + config, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};')
    obj(platform + "-configs", f'isa = XCConfigurationList; buildConfigurations = {refs([platform + "-Debug", platform + "-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    obj(name, f'isa = PBXNativeTarget; buildConfigurationList = {uid(platform + "-configs")}; buildPhases = {refs([platform + "-sources", platform + "-frameworks", platform + "-resources"])}; buildRules = (); dependencies = (); name = "{name}"; productName = OrcaPlayer; productReference = {uid("product-" + platform)}; productType = "com.apple.product-type.application";')
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name)}" BuildableName="OrcaPlayer.app" BlueprintName="{name}" ReferencedContainer="container:OrcaPlayer.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name)}" BuildableName="OrcaPlayer.app" BlueprintName="{name}" ReferencedContainer="container:OrcaPlayer.xcodeproj"/></BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (root / f"OrcaPlayer.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme").write_text(scheme)

obj("sources", f'isa = PBXGroup; children = {refs(["file-" + s.name for s in sources])}; path = OrcaPlayer; sourceTree = "<group>";')
obj("products", f'isa = PBXGroup; children = {refs(products)}; name = Products; sourceTree = "<group>";')
obj("main", f'isa = PBXGroup; children = {refs(["sources", "demo-audio", "journal-data", "products"] + checks)}; sourceTree = "<group>";')
for config in ["Debug", "Release"]:
    obj("project-" + config, f'isa = XCBuildConfiguration; buildSettings = {{ CLANG_ENABLE_MODULES = YES; SWIFT_STRICT_CONCURRENCY = complete; }}; name = {config};')
obj("project-configs", f'isa = XCConfigurationList; buildConfigurations = {refs(["project-Debug", "project-Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj("project", f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {uid("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hant"; hasScannedForEncodings = 0; knownRegions = (en, Base, "zh-Hant"); mainGroup = {uid("main")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {refs(targets)};')
output = '// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {uid("project")};\n}}\n'
(root / "OrcaPlayer.xcodeproj/project.pbxproj").write_text(output)
print(f"Generated native macOS and iOS targets with {len(sources)} shared Swift files")
