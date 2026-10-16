#!/usr/bin/env python3
import plistlib, sys
path, version = sys.argv[1:]
document = {
    'CFBundleTypeName': '纯文本与源代码', 'CFBundleTypeRole': 'Editor',
    'LSHandlerRank': 'Alternate', 'NSDocumentClass': 'TextDocument',
    'LSItemContentTypes': ['public.plain-text', 'public.text', 'public.source-code', 'public.html',
                           'net.daringfireball.markdown', 'public.python-script', 'com.sun.java-source',
                           'public.json', 'public.xml', 'public.shell-script'],
    'CFBundleTypeExtensions': ['txt', 'text', 'md', 'markdown', 'html', 'htm', 'py', 'java', 'js', 'ts',
                               'json', 'css', 'xml', 'svg', 'yaml', 'yml', 'toml', 'ini', 'cfg', 'log',
                               'sh', 'swift', 'c', 'h', 'cpp', 'rb', 'go', 'rs'],
}
info = {
    'CFBundleName': 'BudNote', 'CFBundleDisplayName': 'BudNote', 'CFBundleExecutable': 'BudNote',
    'CFBundleIdentifier': 'com.budwk.app.budnote', 'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': version, 'CFBundleVersion': version,
    'CFBundleIconFile': 'BudNote', 'LSMinimumSystemVersion': '12.0',
    'LSApplicationCategoryType': 'public.app-category.productivity',
    'ITSAppUsesNonExemptEncryption': False,
    'NSPrincipalClass': 'NSApplication', 'NSHighResolutionCapable': True,
    'UIDesignRequiresCompatibility': True,
    'NSHumanReadableCopyright': '© 2026 BudNote', 'CFBundleDevelopmentRegion': 'zh_CN',
    'CFBundleLocalizations': ['zh_CN', 'zh-Hans', 'en'],
    'CFBundleDocumentTypes': [document],
    'UTImportedTypeDeclarations': [{ 'UTTypeIdentifier': 'net.daringfireball.markdown',
        'UTTypeDescription': 'Markdown', 'UTTypeConformsTo': ['public.plain-text'],
        'UTTypeTagSpecification': {'public.filename-extension': ['md', 'markdown'], 'public.mime-type': 'text/markdown'}}]
}
with open(path, 'wb') as f: plistlib.dump(info, f)
