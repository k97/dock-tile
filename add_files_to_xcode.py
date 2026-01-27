#!/usr/bin/env python3
"""
Add new Swift files to DockTile.xcodeproj
Automatically updates project.pbxproj with proper file references and build phases
"""

import re
import uuid

# Files to add (relative to DockTile folder)
NEW_FILES = [
    "Models/ConfigurationModels.swift",
    "Managers/ConfigurationManager.swift",
    "Extensions/ColorExtensions.swift",
    "Views/DockTileConfigurationView.swift",
    "Views/DockTileSidebarView.swift",
    "Views/DockTileDetailView.swift",
    "Views/CustomiseTileView.swift",
    "Components/DockTileIconPreview.swift",
    "Components/ItemRowView.swift",
    "Components/ColourPickerGrid.swift",
    "Components/SymbolPickerButton.swift",
]

def generate_xcode_id():
    """Generate a simple 6-character hex ID for Xcode"""
    return uuid.uuid4().hex[:6].upper()

def add_files_to_project():
    project_path = "DockTile.xcodeproj/project.pbxproj"

    print(f"📂 Reading {project_path}...")
    with open(project_path, 'r') as f:
        content = f.read()

    # Generate IDs for all files
    file_refs = {}
    build_files = {}

    for filepath in NEW_FILES:
        filename = filepath.split('/')[-1]
        file_id = f"AA{generate_xcode_id()}"
        build_id = f"AA{generate_xcode_id()}"

        file_refs[filepath] = {
            'id': file_id,
            'build_id': build_id,
            'filename': filename,
            'path': filepath
        }

    # 1. Add PBXBuildFile entries
    print("📝 Adding PBXBuildFile entries...")
    build_file_section = "/* Begin PBXBuildFile section */"
    build_file_entries = []

    for filepath, info in file_refs.items():
        entry = f"\t\t{info['build_id']} /* {info['filename']} in Sources */ = {{isa = PBXBuildFile; fileRef = {info['id']}; }};"
        build_file_entries.append(entry)

    # Find the end of PBXBuildFile section
    match = re.search(r'(/\* Begin PBXBuildFile section \*/\n)(.*?)(\n/\* End PBXBuildFile section \*/)', content, re.DOTALL)
    if match:
        existing_entries = match.group(2)
        new_entries = existing_entries.rstrip() + '\n' + '\n'.join(build_file_entries)
        content = content[:match.start(2)] + new_entries + content[match.end(2):]

    # 2. Add PBXFileReference entries
    print("📝 Adding PBXFileReference entries...")
    file_ref_entries = []

    for filepath, info in file_refs.items():
        entry = f"\t\t{info['id']} /* {info['filename']} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {info['filename']}; sourceTree = \"<group>\"; }};"
        file_ref_entries.append(entry)

    match = re.search(r'(/\* Begin PBXFileReference section \*/\n)(.*?)(\n/\* End PBXFileReference section \*/)', content, re.DOTALL)
    if match:
        existing_refs = match.group(2)
        new_refs = existing_refs.rstrip() + '\n' + '\n'.join(file_ref_entries)
        content = content[:match.start(2)] + new_refs + content[match.end(2):]

    # 3. Create groups and add file references to groups
    print("📝 Adding files to groups...")

    # Group files by folder
    groups = {
        'Models': [],
        'Managers': [],
        'Extensions': [],
        'Views': [],
        'Components': []
    }

    for filepath, info in file_refs.items():
        folder = filepath.split('/')[0]
        if folder in groups:
            groups[folder].append(info['id'])

    # Add groups to PBXGroup section
    for group_name, file_ids in groups.items():
        if not file_ids:
            continue

        # Check if group already exists
        group_pattern = rf'AA\w+ /\* {group_name} \*/ = {{[\s\S]*?children = \(([\s\S]*?)\);'
        match = re.search(group_pattern, content)

        if match:
            # Group exists, add files to it
            children_content = match.group(1)
            for file_id in file_ids:
                if file_id not in children_content:
                    filename = [info['filename'] for info in file_refs.values() if info['id'] == file_id][0]
                    new_child = f"\n\t\t\t\t{file_id} /* {filename} */,"
                    # Insert before closing parenthesis
                    insert_pos = match.end(1)
                    content = content[:insert_pos] + new_child + content[insert_pos:]
        else:
            # Create new group
            group_id = f"AA{generate_xcode_id()}"
            children_lines = [f"\n\t\t\t\t{fid} /* {[i['filename'] for i in file_refs.values() if i['id'] == fid][0]} */," for fid in file_ids]

            group_entry = f"""
\t\t{group_id} /* {group_name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({(''.join(children_lines))}
\t\t\t);
\t\t\tpath = {group_name};
\t\t\tsourceTree = "<group>";
\t\t}};"""

            # Add group to PBXGroup section
            group_section_end = content.find("/* End PBXGroup section */")
            content = content[:group_section_end] + group_entry + "\n" + content[group_section_end:]

            # Add group reference to DockTile group
            docktile_pattern = r'(AA\w+ /\* DockTile \*/ = \{[\s\S]*?children = \()([\s\S]*?)(\);)'
            match = re.search(docktile_pattern, content)
            if match:
                children = match.group(2)
                if group_id not in children:
                    new_ref = f"\n\t\t\t\t{group_id} /* {group_name} */,"
                    content = content[:match.end(2)] + new_ref + content[match.end(2):]

    # 4. Add files to PBXSourcesBuildPhase
    print("📝 Adding files to build phase...")
    sources_pattern = r'(AA\w+ /\* Sources \*/ = \{[\s\S]*?files = \()([\s\S]*?)(\);)'
    match = re.search(sources_pattern, content)

    if match:
        sources_content = match.group(2)
        for filepath, info in file_refs.items():
            if info['build_id'] not in sources_content:
                new_source = f"\n\t\t\t\t{info['build_id']} /* {info['filename']} in Sources */,"
                content = content[:match.end(2)] + new_source + content[match.end(2):]

    # Write updated content
    print(f"💾 Writing updated {project_path}...")
    with open(project_path, 'w') as f:
        f.write(content)

    print("✅ Successfully added all files to Xcode project!")
    print(f"\n📋 Added {len(NEW_FILES)} files:")
    for filepath in NEW_FILES:
        print(f"   • {filepath}")

if __name__ == "__main__":
    try:
        add_files_to_project()
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
