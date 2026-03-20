#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import json
import logging

logging.basicConfig(level=logging.INFO, format="%(message)s")

def get_issue_key(issue):
    return f"{issue.get('instance_id', '')}_{issue.get('group', '')}_{issue.get('message', '')}"

def load_issues(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return {get_issue_key(i): i for i in data.get("issues", [])}
    except Exception as e:
        logging.error(f"无法读取文件 {filepath}: {e}")
        return {}

def main():
    if len(sys.argv) != 3:
        print("用法: python compare_inspection.py <last_report.json> <current_report.json>")
        sys.exit(1)
        
    last_file = sys.argv[1]
    curr_file = sys.argv[2]
    
    last_issues = load_issues(last_file)
    curr_issues = load_issues(curr_file)
    
    new_issues = []
    resolved_issues = []
    persistent_issues = []
    
    for key, issue in curr_issues.items():
        if key in last_issues:
            persistent_issues.append(issue)
        else:
            new_issues.append(issue)
            
    for key, issue in last_issues.items():
        if key not in curr_issues:
            resolved_issues.append(issue)
            
    print(f"📊 与上次巡检对比：")
    print(f"  🆕 新增问题：{len(new_issues)} 项")
    print(f"  ✅ 已修复：{len(resolved_issues)} 项")
    print(f"  🔄 持续存在：{len(persistent_issues)} 项\n")
    
    if new_issues:
        print("  【新增】：")
        for i in new_issues:
            print(f"    ❌ {i.get('instance_id')} ({i.get('instance_desc')}) — [{i.get('group')}] {i.get('message')}")
            
    if resolved_issues:
        print("  【修复】：")
        for i in resolved_issues:
            print(f"    ✅ {i.get('instance_id')} ({i.get('instance_desc')}) — [{i.get('group')}] {i.get('message')}（已恢复正常）")

if __name__ == "__main__":
    main()
