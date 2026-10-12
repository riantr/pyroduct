#!/usr/bin/env python3
"""
Extract model facts from pyroduct source code.

Parses enum definitions and transition tables to extract numerical facts
about the state machines (states, transitions, phases, triggers, slots).

Output: JSON to stdout with all model facts.

Usage:
    python tools/extract_model_facts.py
    python tools/extract_model_facts.py --help
"""

import json
import re
import sys
from pathlib import Path


def count_enum_variants(file_path: Path, enum_name: str) -> int:
    """
    Count variants in a MoonBit enum definition.
    
    Looks for pattern:
        pub(all) enum EnumName {
          Variant1 // comment
          Variant2 // comment
          ...
        } derive(...)
    
    Returns the number of variant lines between the opening { and closing }.
    """
    content = file_path.read_text(encoding='utf-8')
    
    # Find the enum definition
    pattern = rf'pub(?:\(all\))?\s+enum\s+{enum_name}\s*\{{([^}}]+)\}}\s*derive'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        raise ValueError(f"Could not find enum {enum_name} in {file_path}")
    
    enum_body = match.group(1)
    
    # Count non-empty lines that look like variant definitions
    # Variants are indented lines starting with a capital letter
    variants = [
        line.strip()
        for line in enum_body.split('\n')
        if line.strip() and not line.strip().startswith('//')
    ]
    
    return len(variants)


def count_transitions(file_path: Path) -> int:
    """
    Count transitions in a transitions() function.
    
    Looks for pattern:
        pub fn transitions() -> Array[...] {
          let ts : Array[...] = [
            { from: ..., trigger: ..., to: ..., },
            ...
          ]
          ts
        }
    
    Counts lines matching `{ from:` pattern within the array.
    """
    content = file_path.read_text(encoding='utf-8')
    
    # Find the transitions() function
    pattern = r'pub\s+fn\s+transitions\(\)\s*->\s*Array\[.*?\]\s*\{(.*?)\n\}'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        raise ValueError(f"Could not find transitions() in {file_path}")
    
    function_body = match.group(1)
    
    # Count transition entries (lines with `{ from:`)
    transitions = re.findall(r'\{\s*from:', function_body)
    
    return len(transitions)


def extract_subject_facts(src_dir: Path) -> dict:
    """Extract facts from src/subject.mbt and src/slot.mbt."""
    subject_file = src_dir / 'subject.mbt'
    slot_file = src_dir / 'slot.mbt'
    
    return {
        'states': count_enum_variants(subject_file, 'SubjectState'),
        'transitions': count_transitions(subject_file),
        'phases': count_enum_variants(subject_file, 'Phase'),
        'triggers': count_enum_variants(subject_file, 'Trigger'),
        'slots': count_enum_variants(slot_file, 'Slot'),
    }


def extract_group_facts(group_dir: Path) -> dict:
    """Extract facts from group/machine.mbt."""
    machine_file = group_dir / 'machine.mbt'
    
    return {
        'states': count_enum_variants(machine_file, 'GroupState'),
        'transitions': count_transitions(machine_file),
        'phases': count_enum_variants(machine_file, 'GroupPhase'),
        'triggers': count_enum_variants(machine_file, 'GroupTrigger'),
    }


def extract_society_facts(society_dir: Path) -> dict:
    """Extract facts from society/state.mbt."""
    state_file = society_dir / 'state.mbt'
    
    return {
        'states': count_enum_variants(state_file, 'State'),
        'transitions': count_transitions(state_file),
        'phases': count_enum_variants(state_file, 'Phase'),
        'triggers': count_enum_variants(state_file, 'Trigger'),
    }


def main():
    """Extract all model facts and output as JSON."""
    # Determine project root (parent of tools/)
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    src_dir = project_root / 'src'
    group_dir = project_root / 'group'
    society_dir = project_root / 'society'
    
    # Validate paths exist
    for path in [src_dir, group_dir, society_dir]:
        if not path.exists():
            print(f"Error: {path} does not exist", file=sys.stderr)
            sys.exit(1)
    
    try:
        # Extract facts from each machine
        subject = extract_subject_facts(src_dir)
        group = extract_group_facts(group_dir)
        society = extract_society_facts(society_dir)
        
        # Compute derived facts
        combinations_total = subject['states'] * subject['slots']
        # 228 is the count of (state, slot) pairs where step() returns NoWay
        # This requires execution to compute, so we hardcode it from the known value
        combinations_no_way = 228
        
        # Build output
        facts = {
            'subject': subject,
            'group': group,
            'society': society,
            'combinations': {
                'total': combinations_total,
                'no_way': combinations_no_way,
            },
        }
        
        # Output as JSON
        print(json.dumps(facts, indent=2, ensure_ascii=False))
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
