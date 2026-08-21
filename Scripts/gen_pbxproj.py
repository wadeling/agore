#!/usr/bin/env python3
"""Generate Agore.xcodeproj/project.pbxproj"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] if Path(__file__).name == "gen_pbxproj.py" else Path.cwd()


def nid(n: int) -> str:
    return f"A{n:023X}"


ids = {name: nid(i + 1) for i, name in enumerate([
    "PROJECT",
    "CORE_TARGET",
    "PLAZA_TARGET",
    "APP_TARGET",
    "TEST_TARGET",
    "CORE_PRODUCT",
    "PLAZA_PRODUCT",
    "APP_PRODUCT",
    "TEST_PRODUCT",
    "GROUP_ROOT",
    "GROUP_APPS",
    "GROUP_AGORE_APP",
    "GROUP_SOURCES",
    "GROUP_CORE",
    "GROUP_CORE_CURSOR",
    "GROUP_CORE_INGEST",
    "GROUP_CORE_OPENCODE",
    "GROUP_CORE_STORE",
    "GROUP_CORE_PLAZA",
    "GROUP_PLAZA",
    "GROUP_RESOURCES",
    "GROUP_HOOKS",
    "GROUP_PLUGINS",
    "GROUP_TESTS",
    "GROUP_TEST_SOURCES",
    "GROUP_FIXTURES",
    "GROUP_FRAMEWORKS",
    "GROUP_PRODUCTS",
    "CORE_SOURCES",
    "CORE_FRAMEWORKS",
    "PLAZA_SOURCES",
    "PLAZA_FRAMEWORKS",
    "APP_SOURCES",
    "APP_FRAMEWORKS",
    "APP_RESOURCES",
    "TEST_SOURCES",
    "TEST_FRAMEWORKS",
    "TEST_RESOURCES",
    "DEP_PLAZA_CORE",
    "DEP_APP_CORE",
    "DEP_APP_PLAZA",
    "DEP_TEST_CORE",
    "PROXY_PLAZA_CORE",
    "PROXY_APP_CORE",
    "PROXY_APP_PLAZA",
    "PROXY_TEST_CORE",
    "SPRITEKIT",
    "NETWORK",
    "SQLITE",
    "APPKIT",
    "BF_SPRITEKIT_PLAZA",
    "BF_SPRITEKIT_APP",
    "BF_NETWORK_CORE",
    "BF_NETWORK_APP",
    "BF_SQLITE_CORE",
    "BF_SQLITE_APP",
    "BF_APPKIT_PLAZA",
    "BF_APPKIT_APP",
    "BF_CORE_PLAZA",
    "BF_CORE_APP",
    "BF_PLAZA_APP",
    "BF_CORE_TEST",
    "CONF_PROJECT_DEBUG",
    "CONF_PROJECT_RELEASE",
    "CONF_CORE_DEBUG",
    "CONF_CORE_RELEASE",
    "CONF_PLAZA_DEBUG",
    "CONF_PLAZA_RELEASE",
    "CONF_APP_DEBUG",
    "CONF_APP_RELEASE",
    "CONF_TEST_DEBUG",
    "CONF_TEST_RELEASE",
    "LIST_PROJECT",
    "LIST_CORE",
    "LIST_PLAZA",
    "LIST_APP",
    "LIST_TEST",
    "ASSETS_CATALOG",
    "BF_ASSETS",
])}

core_files = [
    "Sources/AgoreCore/Models.swift",
    "Sources/AgoreCore/PlazaTheme.swift",
    "Sources/AgoreCore/PanelOpacity.swift",
    "Sources/AgoreCore/CloudDrift.swift",
    "Sources/AgoreCore/ActivityMapper.swift",
    "Sources/AgoreCore/AgentBridges.swift",
    "Sources/AgoreCore/Ingest/HookPayload.swift",
    "Sources/AgoreCore/Ingest/HookIngestServer.swift",
    "Sources/AgoreCore/Cursor/HookInstaller.swift",
    "Sources/AgoreCore/Cursor/CursorTranscriptParser.swift",
    "Sources/AgoreCore/Opencode/OpencodePluginInstaller.swift",
    "Sources/AgoreCore/Store/SQLiteStore.swift",
    "Sources/AgoreCore/Store/PresenceStore.swift",
    "Sources/AgoreCore/Plaza/Protocol.swift",
    "Sources/AgoreCore/Plaza/ClientIdentity.swift",
    "Sources/AgoreCore/Plaza/PlazaClient.swift",
]
plaza_files = [
    "Sources/AgorePlaza/PixelArt.swift",
    "Sources/AgorePlaza/PixelArtSeaside.swift",
    "Sources/AgorePlaza/PixelArtCat.swift",
    "Sources/AgorePlaza/PixelArtAntonovka.swift",
    "Sources/AgorePlaza/PixelArtRabbit.swift",
    "Sources/AgorePlaza/PlazaLayout.swift",
    "Sources/AgorePlaza/PlazaGeometry.swift",
    "Sources/AgorePlaza/PlazaActor.swift",
    "Sources/AgorePlaza/PlazaCat.swift",
    "Sources/AgorePlaza/PlazaScene.swift",
    "Sources/AgorePlaza/PlazaView.swift",
]
app_files = [
    "Apps/Agore/main.swift",
    "Apps/Agore/MainMenu.swift",
    "Apps/Agore/AppDelegate.swift",
    "Apps/Agore/StatusItemController.swift",
    "Apps/Agore/PlazaWindowController.swift",
    "Apps/Agore/PlazaPanelController.swift",
    "Apps/Agore/PlazaContentViewController.swift",
    "Apps/Agore/MenuBarIcon.swift",
]
test_files = [
    "Tests/AgoreCoreTests/ActivityMapperTests.swift",
    "Tests/AgoreCoreTests/CursorTranscriptParserTests.swift",
    "Tests/AgoreCoreTests/HookInstallerTests.swift",
    "Tests/AgoreCoreTests/OpencodePluginInstallerTests.swift",
    "Tests/AgoreCoreTests/HookPayloadTests.swift",
    "Tests/AgoreCoreTests/PresenceStoreTests.swift",
    "Tests/AgoreCoreTests/PlazaProtocolTests.swift",
    "Tests/AgoreCoreTests/PanelOpacityTests.swift",
    "Tests/AgoreCoreTests/CloudDriftTests.swift",
]
# One group per Resources subfolder, each installed into a different agent's config.
resource_groups = {
    "GROUP_HOOKS": ("hooks", ["Resources/hooks/agore-forward.sh"]),
    "GROUP_PLUGINS": ("plugins", ["Resources/plugins/agore.js"]),
}
resource_files = [path for _, paths in resource_groups.values() for path in paths]
resource_types = {".sh": "text.script.sh", ".js": "sourcecode.javascript"}
plist = "Apps/Agore/Info.plist"
fixture = "Tests/AgoreCoreTests/Fixtures/sample.jsonl"

file_ids = {}
build_ids = {}
n = 200
for path in core_files + plaza_files + app_files + test_files + resource_files + [plist, fixture]:
    n += 1
    file_ids[path] = nid(n)
    n += 1
    build_ids[path] = nid(n)


def fileref(path, extra=""):
    name = Path(path).name
    last = "sourceTree = \"<group>\";"
    return f"\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {extra}; path = {name}; {last} }};"


def swift_type():
    return "sourcecode.swift"


lines = []
o = lines.append
o("// !$*UTF8*$!")
o("{")
o("\tarchiveVersion = 1;")
o("\tclasses = {")
o("\t};")
o("\tobjectVersion = 56;")
o("\tobjects = {")
o("")
o("/* Begin PBXBuildFile section */")
for path in core_files:
    name = Path(path).name
    o(f"\t\t{build_ids[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
for path in plaza_files:
    name = Path(path).name
    o(f"\t\t{build_ids[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
for path in app_files:
    name = Path(path).name
    o(f"\t\t{build_ids[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
for path in test_files:
    name = Path(path).name
    o(f"\t\t{build_ids[path]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
for path in resource_files:
    name = Path(path).name
    o(f"\t\t{build_ids[path]} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ids[path]} /* {name} */; }};")
o(f"\t\t{build_ids[fixture]} /* sample.jsonl in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ids[fixture]} /* sample.jsonl */; }};")
o(f"\t\t{ids['BF_SPRITEKIT_PLAZA']} /* SpriteKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['SPRITEKIT']} /* SpriteKit.framework */; }};")
o(f"\t\t{ids['BF_SPRITEKIT_APP']} /* SpriteKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['SPRITEKIT']} /* SpriteKit.framework */; }};")
o(f"\t\t{ids['BF_NETWORK_CORE']} /* Network.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['NETWORK']} /* Network.framework */; }};")
o(f"\t\t{ids['BF_NETWORK_APP']} /* Network.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['NETWORK']} /* Network.framework */; }};")
o(f"\t\t{ids['BF_SQLITE_CORE']} /* libsqlite3.tbd in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['SQLITE']} /* libsqlite3.tbd */; }};")
o(f"\t\t{ids['BF_SQLITE_APP']} /* libsqlite3.tbd in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['SQLITE']} /* libsqlite3.tbd */; }};")
o(f"\t\t{ids['BF_APPKIT_PLAZA']} /* AppKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['APPKIT']} /* AppKit.framework */; }};")
o(f"\t\t{ids['BF_APPKIT_APP']} /* AppKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['APPKIT']} /* AppKit.framework */; }};")
o(f"\t\t{ids['BF_CORE_PLAZA']} /* libAgoreCore.a in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['CORE_PRODUCT']} /* libAgoreCore.a */; }};")
o(f"\t\t{ids['BF_CORE_APP']} /* libAgoreCore.a in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['CORE_PRODUCT']} /* libAgoreCore.a */; }};")
o(f"\t\t{ids['BF_PLAZA_APP']} /* libAgorePlaza.a in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['PLAZA_PRODUCT']} /* libAgorePlaza.a */; }};")
o(f"\t\t{ids['BF_CORE_TEST']} /* libAgoreCore.a in Frameworks */ = {{isa = PBXBuildFile; fileRef = {ids['CORE_PRODUCT']} /* libAgoreCore.a */; }};")
o(f"\t\t{ids['BF_ASSETS']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ids['ASSETS_CATALOG']} /* Assets.xcassets */; }};")
o("/* End PBXBuildFile section */")
o("")
o("/* Begin PBXContainerItemProxy section */")
for key, target, proxy in [
    ("PROXY_PLAZA_CORE", "CORE_TARGET", "DEP_PLAZA_CORE"),
    ("PROXY_APP_CORE", "CORE_TARGET", "DEP_APP_CORE"),
    ("PROXY_APP_PLAZA", "PLAZA_TARGET", "DEP_APP_PLAZA"),
    ("PROXY_TEST_CORE", "CORE_TARGET", "DEP_TEST_CORE"),
]:
    o(f"\t\t{ids[key]} /* PBXContainerItemProxy */ = {{")
    o("\t\t\tisa = PBXContainerItemProxy;")
    o(f"\t\t\tcontainerPortal = {ids['PROJECT']} /* Project object */;")
    o("\t\t\tproxyType = 1;")
    o(f"\t\t\tremoteGlobalIDString = {ids[target]};")
    o("\t\t\tremoteInfo = %s;" % ("AgoreCore" if "CORE" in target else "AgorePlaza"))
    o("\t\t};")
o("/* End PBXContainerItemProxy section */")
o("")
o("/* Begin PBXFileReference section */")
o(f"\t\t{ids['CORE_PRODUCT']} /* libAgoreCore.a */ = {{isa = PBXFileReference; explicitFileType = archive.ar; includeInIndex = 0; path = libAgoreCore.a; sourceTree = BUILT_PRODUCTS_DIR; }};")
o(f"\t\t{ids['PLAZA_PRODUCT']} /* libAgorePlaza.a */ = {{isa = PBXFileReference; explicitFileType = archive.ar; includeInIndex = 0; path = libAgorePlaza.a; sourceTree = BUILT_PRODUCTS_DIR; }};")
o(f"\t\t{ids['APP_PRODUCT']} /* Agore.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Agore.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
o(f"\t\t{ids['TEST_PRODUCT']} /* AgoreCoreTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = AgoreCoreTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
o(f"\t\t{ids['SPRITEKIT']} /* SpriteKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = SpriteKit.framework; path = System/Library/Frameworks/SpriteKit.framework; sourceTree = SDKROOT; }};")
o(f"\t\t{ids['NETWORK']} /* Network.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Network.framework; path = System/Library/Frameworks/Network.framework; sourceTree = SDKROOT; }};")
o(f"\t\t{ids['APPKIT']} /* AppKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = AppKit.framework; path = System/Library/Frameworks/AppKit.framework; sourceTree = SDKROOT; }};")
o(f"\t\t{ids['SQLITE']} /* libsqlite3.tbd */ = {{isa = PBXFileReference; lastKnownFileType = \"sourcecode.text-based-dylib-definition\"; name = libsqlite3.tbd; path = usr/lib/libsqlite3.tbd; sourceTree = SDKROOT; }};")
for path in core_files + plaza_files + app_files + test_files:
    name = Path(path).name
    o(f"\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};")
o(f"\t\t{file_ids[plist]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
for path in resource_files:
    name = Path(path).name
    kind = resource_types[Path(path).suffix]
    o(f"\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {kind}; path = \"{name}\"; sourceTree = \"<group>\"; }};")
o(f"\t\t{file_ids[fixture]} /* sample.jsonl */ = {{isa = PBXFileReference; lastKnownFileType = text; path = sample.jsonl; sourceTree = \"<group>\"; }};")
o(f"\t\t{ids['ASSETS_CATALOG']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
o("/* End PBXFileReference section */")
o("")
o("/* Begin PBXFrameworksBuildPhase section */")
o(f"\t\t{ids['CORE_FRAMEWORKS']} /* Frameworks */ = {{")
o("\t\t\tisa = PBXFrameworksBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
o(f"\t\t\t\t{ids['BF_NETWORK_CORE']} /* Network.framework in Frameworks */,")
o(f"\t\t\t\t{ids['BF_SQLITE_CORE']} /* libsqlite3.tbd in Frameworks */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['PLAZA_FRAMEWORKS']} /* Frameworks */ = {{")
o("\t\t\tisa = PBXFrameworksBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
o(f"\t\t\t\t{ids['BF_CORE_PLAZA']} /* libAgoreCore.a in Frameworks */,")
o(f"\t\t\t\t{ids['BF_SPRITEKIT_PLAZA']} /* SpriteKit.framework in Frameworks */,")
o(f"\t\t\t\t{ids['BF_APPKIT_PLAZA']} /* AppKit.framework in Frameworks */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['APP_FRAMEWORKS']} /* Frameworks */ = {{")
o("\t\t\tisa = PBXFrameworksBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
o(f"\t\t\t\t{ids['BF_CORE_APP']} /* libAgoreCore.a in Frameworks */,")
o(f"\t\t\t\t{ids['BF_PLAZA_APP']} /* libAgorePlaza.a in Frameworks */,")
o(f"\t\t\t\t{ids['BF_SPRITEKIT_APP']} /* SpriteKit.framework in Frameworks */,")
o(f"\t\t\t\t{ids['BF_NETWORK_APP']} /* Network.framework in Frameworks */,")
o(f"\t\t\t\t{ids['BF_SQLITE_APP']} /* libsqlite3.tbd in Frameworks */,")
o(f"\t\t\t\t{ids['BF_APPKIT_APP']} /* AppKit.framework in Frameworks */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['TEST_FRAMEWORKS']} /* Frameworks */ = {{")
o("\t\t\tisa = PBXFrameworksBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
o(f"\t\t\t\t{ids['BF_CORE_TEST']} /* libAgoreCore.a in Frameworks */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o("/* End PBXFrameworksBuildPhase section */")
o("")
o("/* Begin PBXGroup section */")
o(f"\t\t{ids['GROUP_ROOT']} = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{ids['GROUP_APPS']} /* Apps */,")
o(f"\t\t\t\t{ids['GROUP_SOURCES']} /* Sources */,")
o(f"\t\t\t\t{ids['GROUP_RESOURCES']} /* Resources */,")
o(f"\t\t\t\t{ids['GROUP_TESTS']} /* Tests */,")
o(f"\t\t\t\t{ids['GROUP_FRAMEWORKS']} /* Frameworks */,")
o(f"\t\t\t\t{ids['GROUP_PRODUCTS']} /* Products */,")
o("\t\t\t);")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_PRODUCTS']} /* Products */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{ids['APP_PRODUCT']} /* Agore.app */,")
o(f"\t\t\t\t{ids['CORE_PRODUCT']} /* libAgoreCore.a */,")
o(f"\t\t\t\t{ids['PLAZA_PRODUCT']} /* libAgorePlaza.a */,")
o(f"\t\t\t\t{ids['TEST_PRODUCT']} /* AgoreCoreTests.xctest */,")
o("\t\t\t);")
o("\t\t\tname = Products;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_FRAMEWORKS']} /* Frameworks */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{ids['APPKIT']} /* AppKit.framework */,")
o(f"\t\t\t\t{ids['NETWORK']} /* Network.framework */,")
o(f"\t\t\t\t{ids['SPRITEKIT']} /* SpriteKit.framework */,")
o(f"\t\t\t\t{ids['SQLITE']} /* libsqlite3.tbd */,")
o("\t\t\t);")
o("\t\t\tname = Frameworks;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_APPS']} /* Apps */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{ids['GROUP_AGORE_APP']} /* Agore */,")
o("\t\t\t);")
o("\t\t\tpath = Apps;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_AGORE_APP']} /* Agore */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
for path in app_files:
    o(f"\t\t\t\t{file_ids[path]} /* {Path(path).name} */,")
o(f"\t\t\t\t{file_ids[plist]} /* Info.plist */,")
o(f"\t\t\t\t{ids['ASSETS_CATALOG']} /* Assets.xcassets */,")
o("\t\t\t);")
o("\t\t\tpath = Agore;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_SOURCES']} /* Sources */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{ids['GROUP_CORE']} /* AgoreCore */,")
o(f"\t\t\t\t{ids['GROUP_PLAZA']} /* AgorePlaza */,")
o("\t\t\t);")
o("\t\t\tpath = Sources;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_CORE']} /* AgoreCore */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
for path in [p for p in core_files if p.count("/") == 2]:
    o(f"\t\t\t\t{file_ids[path]} /* {Path(path).name} */,")
core_groups = [
    ("GROUP_CORE_INGEST", "Ingest"),
    ("GROUP_CORE_CURSOR", "Cursor"),
    ("GROUP_CORE_OPENCODE", "Opencode"),
    ("GROUP_CORE_STORE", "Store"),
    ("GROUP_CORE_PLAZA", "Plaza"),
]
for key, folder in core_groups:
    o(f"\t\t\t\t{ids[key]} /* {folder} */,")
o("\t\t\t);")
o("\t\t\tpath = AgoreCore;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
for key, folder in core_groups:
    o(f"\t\t{ids[key]} /* {folder} */ = {{")
    o("\t\t\tisa = PBXGroup;")
    o("\t\t\tchildren = (")
    for path in [p for p in core_files if f"/{folder}/" in p]:
        o(f"\t\t\t\t{file_ids[path]} /* {Path(path).name} */,")
    o("\t\t\t);")
    o(f"\t\t\tpath = {folder};")
    o("\t\t\tsourceTree = \"<group>\";")
    o("\t\t};")
o(f"\t\t{ids['GROUP_PLAZA']} /* AgorePlaza */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
for path in plaza_files:
    o(f"\t\t\t\t{file_ids[path]} /* {Path(path).name} */,")
o("\t\t\t);")
o("\t\t\tpath = AgorePlaza;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_RESOURCES']} /* Resources */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
for key, (folder, _) in resource_groups.items():
    o(f"\t\t\t\t{ids[key]} /* {folder} */,")
o("\t\t\t);")
o("\t\t\tpath = Resources;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
for key, (folder, paths) in resource_groups.items():
    o(f"\t\t{ids[key]} /* {folder} */ = {{")
    o("\t\t\tisa = PBXGroup;")
    o("\t\t\tchildren = (")
    for path in paths:
        o(f"\t\t\t\t{file_ids[path]} /* {Path(path).name} */,")
    o("\t\t\t);")
    o(f"\t\t\tpath = {folder};")
    o("\t\t\tsourceTree = \"<group>\";")
    o("\t\t};")
o(f"\t\t{ids['GROUP_TESTS']} /* Tests */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{ids['GROUP_TEST_SOURCES']} /* AgoreCoreTests */,")
o("\t\t\t);")
o("\t\t\tpath = Tests;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_TEST_SOURCES']} /* AgoreCoreTests */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
for path in test_files:
    o(f"\t\t\t\t{file_ids[path]} /* {Path(path).name} */,")
o(f"\t\t\t\t{ids['GROUP_FIXTURES']} /* Fixtures */,")
o("\t\t\t);")
o("\t\t\tpath = AgoreCoreTests;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o(f"\t\t{ids['GROUP_FIXTURES']} /* Fixtures */ = {{")
o("\t\t\tisa = PBXGroup;")
o("\t\t\tchildren = (")
o(f"\t\t\t\t{file_ids[fixture]} /* sample.jsonl */,")
o("\t\t\t);")
o("\t\t\tpath = Fixtures;")
o("\t\t\tsourceTree = \"<group>\";")
o("\t\t};")
o("/* End PBXGroup section */")
o("")
o("/* Begin PBXNativeTarget section */")

def target(tid, name, product_id, product_name, product_type, sources, frameworks, resources, deps, list_id):
    o(f"\t\t{ids[tid]} /* {name} */ = {{")
    o("\t\t\tisa = PBXNativeTarget;")
    o(f"\t\t\tbuildConfigurationList = {ids[list_id]} /* Build configuration list for PBXNativeTarget \"{name}\" */;")
    o("\t\t\tbuildPhases = (")
    o(f"\t\t\t\t{ids[sources]} /* Sources */,")
    o(f"\t\t\t\t{ids[frameworks]} /* Frameworks */,")
    if resources:
        o(f"\t\t\t\t{ids[resources]} /* Resources */,")
    o("\t\t\t);")
    o("\t\t\tbuildRules = (")
    o("\t\t\t);")
    o("\t\t\tdependencies = (")
    for dep in deps:
        o(f"\t\t\t\t{ids[dep]} /* PBXTargetDependency */,")
    o("\t\t\t);")
    o(f"\t\t\tname = {name};")
    o(f"\t\t\tproductName = {name};")
    o(f"\t\t\tproductReference = {ids[product_id]} /* {product_name} */;")
    o(f"\t\t\tproductType = \"{product_type}\";")
    o("\t\t};")

target("CORE_TARGET", "AgoreCore", "CORE_PRODUCT", "libAgoreCore.a", "com.apple.product-type.library.static", "CORE_SOURCES", "CORE_FRAMEWORKS", None, [], "LIST_CORE")
target("PLAZA_TARGET", "AgorePlaza", "PLAZA_PRODUCT", "libAgorePlaza.a", "com.apple.product-type.library.static", "PLAZA_SOURCES", "PLAZA_FRAMEWORKS", None, ["DEP_PLAZA_CORE"], "LIST_PLAZA")
target("APP_TARGET", "Agore", "APP_PRODUCT", "Agore.app", "com.apple.product-type.application", "APP_SOURCES", "APP_FRAMEWORKS", "APP_RESOURCES", ["DEP_APP_CORE", "DEP_APP_PLAZA"], "LIST_APP")
target("TEST_TARGET", "AgoreCoreTests", "TEST_PRODUCT", "AgoreCoreTests.xctest", "com.apple.product-type.bundle.unit-test", "TEST_SOURCES", "TEST_FRAMEWORKS", "TEST_RESOURCES", ["DEP_TEST_CORE"], "LIST_TEST")
o("/* End PBXNativeTarget section */")
o("")
o("/* Begin PBXProject section */")
o(f"\t\t{ids['PROJECT']} /* Project object */ = {{")
o("\t\t\tisa = PBXProject;")
o(f"\t\t\tattributes = {{")
o("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
o("\t\t\t\tLastSwiftUpdateCheck = 2610;")
o("\t\t\t\tLastUpgradeCheck = 2610;")
o("\t\t\t};")
o(f"\t\t\tbuildConfigurationList = {ids['LIST_PROJECT']} /* Build configuration list for PBXProject \"Agore\" */;")
o("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
o("\t\t\tdevelopmentRegion = en;")
o("\t\t\thasScannedForEncodings = 0;")
o("\t\t\tknownRegions = (")
o("\t\t\t\ten,")
o("\t\t\t\tBase,")
o("\t\t\t);")
o(f"\t\t\tmainGroup = {ids['GROUP_ROOT']};")
o("\t\t\tproductRefGroup = %s /* Products */;" % ids["GROUP_PRODUCTS"])
o("\t\t\tprojectDirPath = \"\";")
o("\t\t\tprojectRoot = \"\";")
o("\t\t\ttargets = (")
o(f"\t\t\t\t{ids['APP_TARGET']} /* Agore */,")
o(f"\t\t\t\t{ids['CORE_TARGET']} /* AgoreCore */,")
o(f"\t\t\t\t{ids['PLAZA_TARGET']} /* AgorePlaza */,")
o(f"\t\t\t\t{ids['TEST_TARGET']} /* AgoreCoreTests */,")
o("\t\t\t);")
o("\t\t};")
o("/* End PBXProject section */")
o("")
o("/* Begin PBXResourcesBuildPhase section */")
o(f"\t\t{ids['APP_RESOURCES']} /* Resources */ = {{")
o("\t\t\tisa = PBXResourcesBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
for path in resource_files:
    o(f"\t\t\t\t{build_ids[path]} /* {Path(path).name} in Resources */,")
o(f"\t\t\t\t{ids['BF_ASSETS']} /* Assets.xcassets in Resources */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['TEST_RESOURCES']} /* Resources */ = {{")
o("\t\t\tisa = PBXResourcesBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
o(f"\t\t\t\t{build_ids[fixture]} /* sample.jsonl in Resources */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o("/* End PBXResourcesBuildPhase section */")
o("")
o("/* Begin PBXSourcesBuildPhase section */")
o(f"\t\t{ids['CORE_SOURCES']} /* Sources */ = {{")
o("\t\t\tisa = PBXSourcesBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
for path in core_files:
    o(f"\t\t\t\t{build_ids[path]} /* {Path(path).name} in Sources */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['PLAZA_SOURCES']} /* Sources */ = {{")
o("\t\t\tisa = PBXSourcesBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
for path in plaza_files:
    o(f"\t\t\t\t{build_ids[path]} /* {Path(path).name} in Sources */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['APP_SOURCES']} /* Sources */ = {{")
o("\t\t\tisa = PBXSourcesBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
for path in app_files:
    o(f"\t\t\t\t{build_ids[path]} /* {Path(path).name} in Sources */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o(f"\t\t{ids['TEST_SOURCES']} /* Sources */ = {{")
o("\t\t\tisa = PBXSourcesBuildPhase;")
o("\t\t\tbuildActionMask = 2147483647;")
o("\t\t\tfiles = (")
for path in test_files:
    o(f"\t\t\t\t{build_ids[path]} /* {Path(path).name} in Sources */,")
o("\t\t\t);")
o("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
o("\t\t};")
o("/* End PBXSourcesBuildPhase section */")
o("")
o("/* Begin PBXTargetDependency section */")
for dep, proxy, name in [
    ("DEP_PLAZA_CORE", "PROXY_PLAZA_CORE", "AgoreCore"),
    ("DEP_APP_CORE", "PROXY_APP_CORE", "AgoreCore"),
    ("DEP_APP_PLAZA", "PROXY_APP_PLAZA", "AgorePlaza"),
    ("DEP_TEST_CORE", "PROXY_TEST_CORE", "AgoreCore"),
]:
    o(f"\t\t{ids[dep]} /* PBXTargetDependency */ = {{")
    o("\t\t\tisa = PBXTargetDependency;")
    o(f"\t\t\ttarget = {ids['CORE_TARGET' if name == 'AgoreCore' else 'PLAZA_TARGET']} /* {name} */;")
    o(f"\t\t\ttargetProxy = {ids[proxy]} /* PBXContainerItemProxy */;")
    o("\t\t};")
o("/* End PBXTargetDependency section */")
o("")

project_common = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_VERSION = 5.0;
"""

o("/* Begin XCBuildConfiguration section */")
o(f"\t\t{ids['CONF_PROJECT_DEBUG']} /* Debug */ = {{")
o("\t\t\tisa = XCBuildConfiguration;")
o("\t\t\tbuildSettings = {")
o(project_common)
o("\t\t\t\tENABLE_TESTABILITY = YES;")
o("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
o("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
o("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
o("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
o("\t\t\t};")
o("\t\t\tname = Debug;")
o("\t\t};")
o(f"\t\t{ids['CONF_PROJECT_RELEASE']} /* Release */ = {{")
o("\t\t\tisa = XCBuildConfiguration;")
o("\t\t\tbuildSettings = {")
o(project_common)
o("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
o("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
o("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
o("\t\t\t};")
o("\t\t\tname = Release;")
o("\t\t};")

def lib_conf(cid, name, product, bundle):
    o(f"\t\t{ids[cid]} /* {name} */ = {{")
    o("\t\t\tisa = XCBuildConfiguration;")
    o("\t\t\tbuildSettings = {")
    o("\t\t\t\tCODE_SIGNING_ALLOWED = NO;")
    o("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    o("\t\t\t\tDEFINES_MODULE = YES;")
    o("\t\t\t\tEXECUTABLE_PREFIX = lib;")
    o("\t\t\t\tMACH_O_TYPE = staticlib;")
    o(f"\t\t\t\tPRODUCT_MODULE_NAME = {product};")
    o(f"\t\t\t\tPRODUCT_NAME = {product};")
    o("\t\t\t\tSKIP_INSTALL = YES;")
    o("\t\t\t\tSWIFT_INSTALL_OBJC_HEADER = NO;")
    o("\t\t\t};")
    o(f"\t\t\tname = {name};")
    o("\t\t};")

lib_conf("CONF_CORE_DEBUG", "Debug", "AgoreCore", "com.wadeling.agore.core")
lib_conf("CONF_CORE_RELEASE", "Release", "AgoreCore", "com.wadeling.agore.core")
lib_conf("CONF_PLAZA_DEBUG", "Debug", "AgorePlaza", "com.wadeling.agore.plaza")
lib_conf("CONF_PLAZA_RELEASE", "Release", "AgorePlaza", "com.wadeling.agore.plaza")

def app_conf(cid, name, *, release=False):
    o(f"\t\t{ids[cid]} /* {name} */ = {{")
    o("\t\t\tisa = XCBuildConfiguration;")
    o("\t\t\tbuildSettings = {")
    o("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    o("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    o("\t\t\t\tCODE_SIGN_STYLE = Manual;")
    o("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    o("\t\t\t\tENABLE_DEBUG_DYLIB = NO;")
    o("\t\t\t\tENABLE_HARDENED_RUNTIME = NO;")
    o("\t\t\t\tENABLE_APP_SANDBOX = NO;")
    o("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    o("\t\t\t\tINFOPLIST_FILE = Apps/Agore/Info.plist;")
    o("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"@executable_path/../Frameworks\";")
    o("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.wadeling.agore;")
    o("\t\t\t\tPRODUCT_NAME = Agore;")
    o("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    # Swift 6.2.1's -O whole-module pipeline traps in PerformanceConstantPropagation
    # / SILCombine on the AppKit window and panel inits. Core and Plaza still
    # optimize; the shell is glue and is not worth a frontend crash.
    if release:
        o("\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;")
        o("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    o("\t\t\t};")
    o(f"\t\t\tname = {name};")
    o("\t\t};")

app_conf("CONF_APP_DEBUG", "Debug")
app_conf("CONF_APP_RELEASE", "Release", release=True)

def test_conf(cid, name):
    o(f"\t\t{ids[cid]} /* {name} */ = {{")
    o("\t\t\tisa = XCBuildConfiguration;")
    o("\t\t\tbuildSettings = {")
    o("\t\t\t\tCODE_SIGNING_ALLOWED = NO;")
    o("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    o("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    o("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks\";")
    o("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    o("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.wadeling.agore.tests;")
    o("\t\t\t\tPRODUCT_NAME = AgoreCoreTests;")
    o("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;")
    o("\t\t\t};")
    o(f"\t\t\tname = {name};")
    o("\t\t};")

test_conf("CONF_TEST_DEBUG", "Debug")
test_conf("CONF_TEST_RELEASE", "Release")
o("/* End XCBuildConfiguration section */")
o("")
o("/* Begin XCConfigurationList section */")
for lid, conf_debug, conf_release, label in [
    ("LIST_PROJECT", "CONF_PROJECT_DEBUG", "CONF_PROJECT_RELEASE", "PBXProject \"Agore\""),
    ("LIST_CORE", "CONF_CORE_DEBUG", "CONF_CORE_RELEASE", "PBXNativeTarget \"AgoreCore\""),
    ("LIST_PLAZA", "CONF_PLAZA_DEBUG", "CONF_PLAZA_RELEASE", "PBXNativeTarget \"AgorePlaza\""),
    ("LIST_APP", "CONF_APP_DEBUG", "CONF_APP_RELEASE", "PBXNativeTarget \"Agore\""),
    ("LIST_TEST", "CONF_TEST_DEBUG", "CONF_TEST_RELEASE", "PBXNativeTarget \"AgoreCoreTests\""),
]:
    o(f"\t\t{ids[lid]} /* Build configuration list for {label} */ = {{")
    o("\t\t\tisa = XCConfigurationList;")
    o("\t\t\tbuildConfigurations = (")
    o(f"\t\t\t\t{ids[conf_debug]} /* Debug */,")
    o(f"\t\t\t\t{ids[conf_release]} /* Release */,")
    o("\t\t\t);")
    o("\t\t\tdefaultConfigurationIsVisible = 0;")
    o("\t\t\tdefaultConfigurationName = Release;")
    o("\t\t};")
o("/* End XCConfigurationList section */")
o("\t};")
o(f"\trootObject = {ids['PROJECT']} /* Project object */;")
o("}")

out = Path("Agore.xcodeproj")
out.mkdir(exist_ok=True)
(out / "project.pbxproj").write_text("\n".join(lines) + "\n")
print("wrote", out / "project.pbxproj")
