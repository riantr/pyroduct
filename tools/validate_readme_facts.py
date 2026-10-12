#!/usr/bin/env python3
"""
Validate model facts in README files against extracted source code facts.

Parses README.mbt.md (English) and README.zh.mbt.md (Chinese) for numerical
claims about states, transitions, phases, triggers, and slots, then compares
them against the ground truth extracted from source code.

Exit 0 if all facts match, exit 1 if any drift is detected.

Usage:
    python tools/validate_readme_facts.py
    python tools/validate_readme_facts.py --verbose
"""

import json
import re
import subprocess
import sys
from pathlib import Path
from typing import List, Tuple


def extract_facts() -> dict:
    """Run extract_model_facts.py and parse its JSON output."""
    script_dir = Path(__file__).parent
    extractor = script_dir / 'extract_model_facts.py'
    
    if not extractor.exists():
        print(f"Error: {extractor} not found", file=sys.stderr)
        sys.exit(1)
    
    result = subprocess.run(
        [sys.executable, str(extractor)],
        capture_output=True,
        text=True,
        encoding='utf-8'
    )
    
    if result.returncode != 0:
        print(f"Error running extractor: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    
    return json.loads(result.stdout)


def find_numbers_in_line(line: str) -> List[int]:
    """Extract all integers from a line."""
    return [int(x) for x in re.findall(r'\b(\d+)\b', line)]


def check_readme(readme_path: Path, facts: dict, verbose: bool = False) -> List[str]:
    """
    Check a README file for model fact drift.
    
    Returns a list of error messages (empty if all facts match).
    """
    errors = []
    content = readme_path.read_text(encoding='utf-8')
    lines = content.split('\n')
    
    # Expected facts
    subject = facts['subject']
    group = facts['group']
    society = facts['society']
    combinations = facts['combinations']
    
    # Check each line for numerical claims
    for line_num, line in enumerate(lines, start=1):
        # Skip code blocks
        if line.strip().startswith('```'):
            continue
        
        # Pattern 1: "34 positions · 53 transitions · 11 phases" (English)
        # or "34 位置 · 53 迁移 · 11 阶段" (Chinese)
        if re.search(r'(positions?|位置).*?(transitions?|迁移).*?(phases?|阶段)', line, re.IGNORECASE):
            numbers = find_numbers_in_line(line)
            if len(numbers) >= 3:
                expected = [subject['states'], subject['transitions'], subject['phases']]
                actual = numbers[:3]
                if actual != expected:
                    errors.append(
                        f"{readme_path}:{line_num}: subject states/transitions/phases: "
                        f"expected {expected}, got {actual}"
                    )
                elif verbose:
                    print(f"[OK] {readme_path}:{line_num}: subject {actual}")
        
        # Pattern 2: "34·53·11" (compact form) - only check when context is clear
        # Look for patterns like "`src` (34·53·11)" or "`src`（34·53·11）"
        compact_match = re.search(r'`(src|group|society)`[^\d]*(\d+)·(\d+)·(\d+)', line)
        if compact_match:
            machine = compact_match.group(1)
            actual = [int(compact_match.group(2)), int(compact_match.group(3)), int(compact_match.group(4))]
            
            if machine == 'src':
                expected = [subject['states'], subject['transitions'], subject['phases']]
                if actual != expected:
                    errors.append(
                        f"{readme_path}:{line_num}: subject compact form: "
                        f"expected {expected}, got {actual}"
                    )
                elif verbose:
                    print(f"[OK] {readme_path}:{line_num}: subject compact {actual}")
            elif machine == 'group':
                expected = [group['states'], group['transitions'], group['phases']]
                if actual != expected:
                    errors.append(
                        f"{readme_path}:{line_num}: group compact form: "
                        f"expected {expected}, got {actual}"
                    )
                elif verbose:
                    print(f"[OK] {readme_path}:{line_num}: group compact {actual}")
            elif machine == 'society':
                expected = [society['states'], society['transitions'], society['phases']]
                if actual != expected:
                    errors.append(
                        f"{readme_path}:{line_num}: society compact form: "
                        f"expected {expected}, got {actual}"
                    )
                elif verbose:
                    print(f"[OK] {readme_path}:{line_num}: society compact {actual}")
        
        # Pattern 3: Section headings like "Phases — subject (11)"
        phase_heading = re.search(r'(phases?|阶段).*?\((\d+)\)', line, re.IGNORECASE)
        if phase_heading:
            actual = int(phase_heading.group(2))
            if 'subject' in line.lower() or '主体' in line:
                expected = subject['phases']
            elif 'group' in line.lower() or '群体' in line:
                expected = group['phases']
            elif 'society' in line.lower() or '社会' in line:
                expected = society['phases']
            else:
                continue
            
            if actual != expected:
                errors.append(
                    f"{readme_path}:{line_num}: phases heading: "
                    f"expected {expected}, got {actual}"
                )
            elif verbose:
                print(f"✓ {readme_path}:{line_num}: phases heading {actual}")
        
        # Pattern 4: "Positions — subject (34)" or "States (20)"
        state_heading = re.search(r'(positions?|states?|位置|状态).*?\((\d+)\)', line, re.IGNORECASE)
        if state_heading and 'phase' not in line.lower() and '阶段' not in line:
            actual = int(state_heading.group(2))
            if 'subject' in line.lower() or '主体' in line:
                expected = subject['states']
            elif 'group' in line.lower() or '群体' in line:
                expected = group['states']
            elif 'society' in line.lower() or '社会' in line:
                expected = society['states']
            else:
                continue
            
            if actual != expected:
                errors.append(
                    f"{readme_path}:{line_num}: states heading: "
                    f"expected {expected}, got {actual}"
                )
            elif verbose:
                print(f"✓ {readme_path}:{line_num}: states heading {actual}")
        
        # Pattern 5: "Drive slots (8) and the 49 triggers"
        slots_triggers = re.search(r'slots?.*?\((\d+)\).*?(\d+).*?triggers?', line, re.IGNORECASE)
        if slots_triggers or re.search(r'槽.*?\((\d+)\).*?(\d+).*?触发', line):
            match = slots_triggers or re.search(r'槽.*?\((\d+)\).*?(\d+).*?触发', line)
            actual_slots = int(match.group(1))
            actual_triggers = int(match.group(2))
            expected_slots = subject['slots']
            expected_triggers = subject['triggers']
            
            if actual_slots != expected_slots or actual_triggers != expected_triggers:
                errors.append(
                    f"{readme_path}:{line_num}: slots/triggers: "
                    f"expected ({expected_slots}, {expected_triggers}), "
                    f"got ({actual_slots}, {actual_triggers})"
                )
            elif verbose:
                print(f"✓ {readme_path}:{line_num}: slots {actual_slots}, triggers {actual_triggers}")
        
        # Pattern 6: "272 position × slot combinations, 228 honestly answer No-way"
        # or "272 个位置 × 槽组合中，228 个如实回答 无路"
        combinations_match = re.search(r'(\d+).*?(position|位置).*?(\d+).*?(no-way|无路)', line, re.IGNORECASE)
        if combinations_match:
            actual_total = int(combinations_match.group(1))
            actual_no_way = int(combinations_match.group(3))
            expected_total = combinations['total']
            expected_no_way = combinations['no_way']
            
            if actual_total != expected_total or actual_no_way != expected_no_way:
                errors.append(
                    f"{readme_path}:{line_num}: combinations: "
                    f"expected ({expected_total}, {expected_no_way}), "
                    f"got ({actual_total}, {actual_no_way})"
                )
            elif verbose:
                print(f"✓ {readme_path}:{line_num}: combinations {actual_total}/{actual_no_way}")
        
        # Pattern 7: "One group: 20 · 44 · 9" (standalone, not in compact form)
        group_standalone = re.search(r'(group|群体).*?(\d+).*?(\d+).*?(\d+)', line, re.IGNORECASE)
        if group_standalone and '·' in line and 'src' not in line.lower():
            actual = [int(group_standalone.group(2)), int(group_standalone.group(3)), int(group_standalone.group(4))]
            expected = [group['states'], group['transitions'], group['phases']]
            if actual != expected:
                errors.append(
                    f"{readme_path}:{line_num}: group standalone: "
                    f"expected {expected}, got {actual}"
                )
            elif verbose:
                print(f"✓ {readme_path}:{line_num}: group standalone {actual}")
        
        # Pattern 8: "One society: 13 · 28 · 8" (standalone)
        society_standalone = re.search(r'(society|社会).*?(\d+).*?(\d+).*?(\d+)', line, re.IGNORECASE)
        if society_standalone and '·' in line and 'src' not in line.lower():
            actual = [int(society_standalone.group(2)), int(society_standalone.group(3)), int(society_standalone.group(4))]
            expected = [society['states'], society['transitions'], society['phases']]
            if actual != expected:
                errors.append(
                    f"{readme_path}:{line_num}: society standalone: "
                    f"expected {expected}, got {actual}"
                )
            elif verbose:
                print(f"✓ {readme_path}:{line_num}: society standalone {actual}")
    
    return errors


def main():
    """Validate README files against extracted model facts."""
    verbose = '--verbose' in sys.argv or '-v' in sys.argv
    
    # Determine project root
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    
    readme_en = project_root / 'README.mbt.md'
    readme_zh = project_root / 'README.zh.mbt.md'
    
    # Validate paths exist
    for path in [readme_en, readme_zh]:
        if not path.exists():
            print(f"Error: {path} does not exist", file=sys.stderr)
            sys.exit(1)
    
    # Extract ground truth
    facts = extract_facts()
    
    if verbose:
        print(f"Extracted facts: {json.dumps(facts, indent=2)}\n")
    
    # Check both READMEs
    all_errors = []
    
    for readme in [readme_en, readme_zh]:
        errors = check_readme(readme, facts, verbose)
        all_errors.extend(errors)
    
    # Report results
    if all_errors:
        print(f"Found {len(all_errors)} drift(s):", file=sys.stderr)
        for error in all_errors:
            print(f"  {error}", file=sys.stderr)
        sys.exit(1)
    else:
        print(f"[OK] All model facts in README files match source code")
        sys.exit(0)


if __name__ == '__main__':
    main()
