#!/usr/bin/env python3
"""Dependency-free deterministic Xcode project generator; generated project is committed."""
import pathlib, hashlib
root=pathlib.Path(__file__).resolve().parent.parent
out=root/'Aparte.xcodeproj';out.mkdir(exist_ok=True)
def uid(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects={}
def add(name,body):objects[uid(name)]=body;return uid(name)
def arr(items):return '('+','.join(items)+',)' if items else '()'
files=[];sources=[];resources=[]
for p in sorted((root/'Sources/Aparte').glob('*.swift')):
 rel=str(p.relative_to(root));fid=add(rel,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = SOURCE_ROOT;');files.append(fid)
 sources.append(add('build:'+rel,f'isa = PBXBuildFile; fileRef = {fid};'))
for rel in ['Resources/Models.json','Resources/Compatibility.json','Resources/Aparte.icns']:
 if not (root/rel).exists():continue
 file_type = 'image.icns' if rel.endswith('.icns') else 'text.json'
 fid=add(rel,f'isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{rel}"; sourceTree = SOURCE_ROOT;');files.append(fid)
 resources.append(add('build:'+rel,f'isa = PBXBuildFile; fileRef = {fid};'))
product=add('app','isa = PBXFileReference; explicitFileType = wrapper.application; path = "Aparte Dew.app"; sourceTree = BUILT_PRODUCTS_DIR;')
group=add('group',f'isa = PBXGroup; children = {arr(files+[product])}; sourceTree = "<group>";')
package=add('package','isa = XCLocalSwiftPackageReference; relativePath = .;')
products=[];links=[]
for name in ['AparteCore','AparteSpeech']:
 p=add(name,f'isa = XCSwiftPackageProductDependency; productName = {name};');products.append(p)
 links.append(add('link:'+name,f'isa = PBXBuildFile; productRef = {p};'))
phases=[add('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(sources)}; runOnlyForDeploymentPostprocessing = 0;'),add('frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {arr(links)}; runOnlyForDeploymentPostprocessing = 0;'),add('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resources)}; runOnlyForDeploymentPostprocessing = 0;')]
configs={}
for kind in ['project','target']:
 ids=[]
 for config in ['Debug','Release']:
  settings='MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; ARCHS = arm64; SWIFT_VERSION = 5.0; CLANG_ENABLE_MODULES = YES; '
  settings+='SWIFT_OPTIMIZATION_LEVEL = '+ ('"-Onone"' if config=='Debug' else '"-O"')+'; '
  if kind=='target':settings+='PRODUCT_NAME = "$(APARTE_PRODUCT_NAME)"; APARTE_PRODUCT_NAME = "Aparte Dew"; APARTE_DISPLAY_NAME = "Aparte Dew"; EXECUTABLE_NAME = Aparte; PRODUCT_MODULE_NAME = Aparte; PRODUCT_BUNDLE_IDENTIFIER = "$(APARTE_BUNDLE_IDENTIFIER)"; APARTE_BUNDLE_IDENTIFIER = dev.aparte.Aparte.dew; INFOPLIST_FILE = Resources/Info.plist; CODE_SIGNING_ALLOWED = NO; CODE_SIGN_STYLE = Manual; ENABLE_HARDENED_RUNTIME = NO; ENABLE_APP_SANDBOX = NO; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks"; '
  ids.append(add(kind+config,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};'))
 configs[kind]=add(kind+'configs',f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=add('target',f'isa = PBXNativeTarget; buildConfigurationList = {configs["target"]}; buildPhases = {arr(phases)}; buildRules = (); dependencies = (); name = Aparte; productName = Aparte; productReference = {product}; productType = "com.apple.product-type.application"; packageProductDependencies = {arr(products)};')
project=add('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; }}; buildConfigurationList = {configs["project"]}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base,); mainGroup = {group}; projectDirPath = ""; projectRoot = ""; targets = ({target},); packageReferences = ({package},);')
(out/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(k+' = { '+v+' };\n' for k,v in objects.items())+'}; rootObject = '+project+'; }\n')
schemes=out/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Aparte Dew.app" BlueprintName="Aparte" ReferencedContainer="container:Aparte.xcodeproj"/>'
(schemes/'Aparte.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
