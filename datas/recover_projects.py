#!/usr/bin/env python3
"""
_projects 폴더에서 프로젝트 정보를 유추하여 company.json을 복구하는 스크립트
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path

# 부서 매핑
DEPT_MAPPING = {
    "기획": "기획",
    "디자인": "디자인",
    "개발": "개발",
    "QA": "QA",
    "마케팅": "마케팅"
}

def parse_employee_file(file_path):
    """직원 마크다운 파일에서 정보 추출"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 이름 추출
    name_match = re.search(r'^# (.+)$', content, re.MULTILINE)
    name = name_match.group(1) if name_match else Path(file_path).stem

    # AI 유형 추출
    ai_type_match = re.search(r'\*\*AI 유형\*\* \| (.+)', content)
    ai_type = ai_type_match.group(1).strip() if ai_type_match else "Claude"

    # 부서 추출
    dept_match = re.search(r'\*\*부서\*\* \| (.+)', content)
    dept = dept_match.group(1).strip() if dept_match else "기획팀"
    dept = dept.replace("팀", "")  # "기획팀" -> "기획"

    # 입사일 추출
    join_date_match = re.search(r'\*\*입사일\*\* \| (.+)', content)
    join_date_str = join_date_match.group(1).strip() if join_date_match else None

    # 대화 수 추출
    conv_count_match = re.search(r'\*\*총 대화 수\*\* \| (\d+)회', content)
    conv_count = int(conv_count_match.group(1)) if conv_count_match else 0

    # 외모 정보 추출
    appearance_match = re.search(r'### 외모\n\n(.+)', content)
    appearance = appearance_match.group(1).strip() if appearance_match else ""

    # 외모 정보에서 특징 파싱 (간단한 버전)
    appearance_data = {
        "skinTone": 0,
        "hairStyle": 0,
        "hairColor": 0,
        "shirtColor": 0,
        "accessory": 0
    }

    if "안경" in appearance:
        appearance_data["accessory"] = 1

    # 대화 기록 추출 (간단 버전 - 빈 배열)
    conversation_history = []

    return {
        "name": name,
        "aiType": ai_type,
        "department": dept,
        "joinDate": join_date_str,
        "conversationCount": conv_count,
        "appearance": appearance_data,
        "conversationHistory": conversation_history
    }

def scan_projects_folder(projects_path):
    """_projects 폴더 스캔"""
    projects = {}

    for project_dir in Path(projects_path).iterdir():
        if not project_dir.is_dir() or project_dir.name.startswith('.'):
            continue

        project_name = project_dir.name
        project_info = {
            "name": project_name.replace("-", " "),  # "클립-키보드" -> "클립 키보드"
            "departments": {},
            "employees": []
        }

        # 부서별 직원 스캔
        for dept_dir in project_dir.iterdir():
            if not dept_dir.is_dir() or dept_dir.name.startswith('_'):
                continue

            dept_name = dept_dir.name
            if dept_name not in DEPT_MAPPING:
                continue

            people_dir = dept_dir / "people"
            if not people_dir.exists():
                continue

            # 직원 파일 읽기
            for emp_file in people_dir.glob("*.md"):
                emp_info = parse_employee_file(emp_file)
                emp_info["department"] = dept_name
                emp_info["projectName"] = project_info["name"]
                project_info["employees"].append(emp_info)

        if project_info["employees"]:
            projects[project_name] = project_info

    return projects

def update_company_json(company_json_path, projects_info):
    """company.json 업데이트"""
    # 기존 company.json 로드
    with open(company_json_path, 'r', encoding='utf-8') as f:
        company_data = json.load(f)

    # 기존 프로젝트들 (ID로 매핑)
    existing_projects = {p["name"]: p for p in company_data.get("projects", [])}

    # 프로젝트 정보 업데이트
    for project_name, project_info in projects_info.items():
        display_name = project_info["name"]

        if display_name in existing_projects:
            # 기존 프로젝트 업데이트
            project = existing_projects[display_name]
            print(f"✅ 기존 프로젝트 발견: {display_name}")
        else:
            # 새 프로젝트 생성
            import uuid
            project = {
                "id": str(uuid.uuid4()).upper(),
                "name": display_name,
                "description": "",
                "status": "기획 중",
                "createdAt": datetime.now().isoformat() + "Z",
                "updatedAt": datetime.now().isoformat() + "Z",
                "departments": [],
                "tasks": []
            }
            company_data["projects"].append(project)
            print(f"🆕 새 프로젝트 생성: {display_name}")

        # 부서별 직원 그룹화
        dept_employees = {}
        for emp in project_info["employees"]:
            dept = emp["department"]
            if dept not in dept_employees:
                dept_employees[dept] = []
            dept_employees[dept].append(emp)

        # 부서 생성/업데이트
        existing_depts = {d["type"]: d for d in project.get("departments", [])}

        for dept_name, employees in dept_employees.items():
            if dept_name in existing_depts:
                dept = existing_depts[dept_name]
            else:
                import uuid
                dept = {
                    "id": str(uuid.uuid4()).upper(),
                    "type": dept_name,
                    "name": f"{dept_name}팀",
                    "employees": [],
                    "maxCapacity": 4,
                    "position": {"row": 0, "column": 0}
                }
                project["departments"].append(dept)

            # 직원 추가
            existing_emp_names = {e["name"] for e in dept.get("employees", [])}

            for emp_info in employees:
                if emp_info["name"] not in existing_emp_names:
                    import uuid
                    employee = {
                        "id": str(uuid.uuid4()).upper(),
                        "employeeNumber": f"EMP-{len(dept['employees']):04d}",
                        "name": emp_info["name"],
                        "aiType": emp_info["aiType"],
                        "status": "휴식 중",
                        "currentTaskId": None,
                        "conversationHistory": emp_info["conversationHistory"],
                        "createdAt": datetime.now().isoformat() + "Z",
                        "totalTasksCompleted": 0,
                        "characterAppearance": emp_info["appearance"]
                    }
                    dept["employees"].append(employee)
                    print(f"  👤 {emp_info['name']} ({dept_name}) 추가")

    # 저장
    with open(company_json_path, 'w', encoding='utf-8') as f:
        json.dump(company_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ company.json 업데이트 완료")
    return company_data

def main():
    base_dir = Path(__file__).parent
    projects_path = base_dir / "_projects"
    company_json_path = base_dir / "company.json"

    print("=" * 60)
    print("🔄 프로젝트 자동 복구 시작")
    print("=" * 60)
    print()

    # 1. _projects 폴더 스캔
    print("📂 _projects 폴더 스캔 중...")
    projects_info = scan_projects_folder(projects_path)

    print(f"\n발견된 프로젝트: {len(projects_info)}개")
    for name, info in projects_info.items():
        print(f"  - {info['name']}: {len(info['employees'])}명")
    print()

    # 2. company.json 업데이트
    print("📝 company.json 업데이트 중...")
    update_company_json(company_json_path, projects_info)

    print()
    print("=" * 60)
    print("✅ 복구 완료!")
    print("=" * 60)

if __name__ == "__main__":
    main()
