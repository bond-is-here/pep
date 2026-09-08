#!/usr/bin/env python3
"""Regenerate Pep's dependency-free Xcode project from its legacy source paths."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Pep.xcodeproj"

def uid(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()

def quoted(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'

def generate():
    sources = sorted((ROOT / "RepComet").rglob("*.swift"))
    ui_tests = sorted((ROOT / "Tests/PepUITests").rglob("*.swift"))
    if not ui_tests:
        raise RuntimeError("PepUITests must contain native UI tests")
    resources = [ROOT / "RepComet/Assets.xcassets", ROOT / "RepComet/PrivacyInfo.xcprivacy"]
    objects = []
    def obj(key, body):
        objects.append(f"\t\t{uid(key)} = {{ {body} }};")
    source_builds, resource_builds, test_builds, refs, test_refs = [], [], [], [], []
    for file in sources + resources + ui_tests:
        path = file.relative_to(ROOT).as_posix()
        file_type = "sourcecode.swift" if file.suffix == ".swift" else "folder.assetcatalog" if file.suffix == ".xcassets" else "text.xml"
        obj(path, f"isa = PBXFileReference; lastKnownFileType = {file_type}; path = {quoted(path)}; sourceTree = SOURCE_ROOT;")
        obj(path + ":build", f"isa = PBXBuildFile; fileRef = {uid(path)};")
        if file in ui_tests:
            test_refs.append(uid(path))
            test_builds.append(uid(path + ":build"))
        else:
            refs.append(uid(path))
            (source_builds if file.suffix == ".swift" else resource_builds).append(uid(path + ":build"))
    obj("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Pep.app; sourceTree = BUILT_PRODUCTS_DIR;')
    obj("test:product", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = PepUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
    obj("group:source", f"isa = PBXGroup; children = ({','.join(refs)},); name = Pep; sourceTree = \"<group>\";")
    obj("group:tests", f'isa = PBXGroup; children = ({",".join(test_refs)},); name = PepUITests; sourceTree = "<group>";')
    obj("group:products", f'isa = PBXGroup; children = ({uid("product")},{uid("test:product")},); name = Products; sourceTree = "<group>";')
    obj("group:main", f'isa = PBXGroup; children = ({uid("group:source")},{uid("group:tests")},{uid("group:products")},); sourceTree = "<group>";')
    obj("phase:sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(source_builds)},); runOnlyForDeploymentPostprocessing = 0;")
    obj("phase:resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(resource_builds)},); runOnlyForDeploymentPostprocessing = 0;")
    obj("phase:frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    obj("test:phase:sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(test_builds)},); runOnlyForDeploymentPostprocessing = 0;")
    obj("test:phase:resources", "isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    obj("test:phase:frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    project_settings = {
        "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    }
    app_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "", "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": "Pep",
        "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.healthcare-fitness",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        "MARKETING_VERSION": "1.0.0", "PRODUCT_BUNDLE_IDENTIFIER": "app.repcomet.ios",
        "PRODUCT_NAME": "$(TARGET_NAME)", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2", "SWIFT_EMIT_LOC_STRINGS": "YES",
    }
    test_settings = {
        "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "",
        "GENERATE_INFOPLIST_FILE": "YES", "PRODUCT_BUNDLE_IDENTIFIER": "app.repcomet.ios.uitests",
        "PRODUCT_NAME": "$(TARGET_NAME)", "TEST_TARGET_NAME": "Pep",
        "TARGETED_DEVICE_FAMILY": "1,2", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks",
    }
    for scope, base in [("project", project_settings), ("app", app_settings), ("test", test_settings)]:
        for config in ["Debug", "Release"]:
            settings = dict(base)
            if scope == "project":
                settings.update({"DEBUG_INFORMATION_FORMAT": "dwarf" if config == "Debug" else "dwarf-with-dsym", "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if config == "Debug" else "-O"})
                if config == "Debug":
                    settings.update({"SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG", "ENABLE_TESTABILITY": "YES", "ONLY_ACTIVE_ARCH": "YES"})
            body = " ".join(f"{key} = {quoted(value)};" for key, value in settings.items())
            obj(f"{scope}:{config}", f"isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};")
        obj(f"{scope}:config", f'isa = XCConfigurationList; buildConfigurations = ({uid(scope + ":Debug")},{uid(scope + ":Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    obj("target", f'isa = PBXNativeTarget; buildConfigurationList = {uid("app:config")}; buildPhases = ({uid("phase:sources")},{uid("phase:frameworks")},{uid("phase:resources")},); buildRules = (); dependencies = (); name = Pep; productName = Pep; productReference = {uid("product")}; productType = "com.apple.product-type.application";')
    obj("test:proxy", f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target")}; remoteInfo = Pep;')
    obj("test:dependency", f'isa = PBXTargetDependency; target = {uid("target")}; targetProxy = {uid("test:proxy")};')
    obj("test:target", f'isa = PBXNativeTarget; buildConfigurationList = {uid("test:config")}; buildPhases = ({uid("test:phase:sources")},{uid("test:phase:frameworks")},{uid("test:phase:resources")},); buildRules = (); dependencies = ({uid("test:dependency")},); name = PepUITests; productName = PepUITests; productReference = {uid("test:product")}; productType = "com.apple.product-type.bundle.ui-testing";')
    obj("project", f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("target")} = {{ CreatedOnToolsVersion = 16.0; }}; {uid("test:target")} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {uid("target")}; }}; }}; }}; buildConfigurationList = {uid("project:config")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {uid("group:main")}; productRefGroup = {uid("group:products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},{uid("test:target")},);')
    PROJECT.mkdir(exist_ok=True)
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + "\n\t};\n\trootObject = " + uid("project") + ";\n}\n")
    scheme_dir = PROJECT / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    # Keep source paths and the bundle identifier stable so existing users retain
    # their installed app and saved workouts while the visible brand becomes Pep.
    (scheme_dir / "RepComet.xcscheme").unlink(missing_ok=True)
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target")}" BuildableName="Pep.app" BlueprintName="Pep" ReferencedContainer="container:Pep.xcodeproj"/>'
    test_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("test:target")}" BuildableName="PepUITests.xctest" BlueprintName="PepUITests" ReferencedContainer="container:Pep.xcodeproj"/>'
    (scheme_dir / "Pep.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry><BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{test_reference}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{test_reference}</TestableReference></Testables></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
    print(f"Generated Pep.xcodeproj: {len(sources)} app Swift files, {len(ui_tests)} UI test files, {len(resources)} resources")

if __name__ == "__main__":
    generate()
