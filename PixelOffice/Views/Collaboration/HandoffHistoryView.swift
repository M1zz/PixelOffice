//
//  HandoffHistoryView.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  작업 인계(핸드오프) 히스토리 뷰
//

import SwiftUI

struct HandoffHistoryView: View {
    @State private var handoffs: [TaskHandoff] = []
    @State private var filterStatus: HandoffStatus?
    @State private var searchText = ""
    
    var filteredHandoffs: [TaskHandoff] {
        var result = handoffs
        
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.taskTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.fromEmployeeName.localizedCaseInsensitiveContains(searchText) ||
                $0.toEmployeeName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("작업 인계 기록")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 필터
                Picker("상태", selection: $filterStatus) {
                    Text("전체").tag(nil as HandoffStatus?)
                    ForEach([HandoffStatus.pending, .accepted, .completed, .rejected], id: \.self) { status in
                        Label(status.rawValue, systemImage: status.icon).tag(status as HandoffStatus?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            .padding()
            
            // 검색
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("검색...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            Divider()
                .padding(.top, 8)
            
            // 목록
            if filteredHandoffs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("인계 기록이 없습니다")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredHandoffs) { handoff in
                    HandoffRow(handoff: handoff)
                }
            }
            
            // 통계
            HStack {
                HandoffStatBadge(title: "전체", count: handoffs.count, color: .secondary)
                HandoffStatBadge(title: "대기중", count: handoffs.filter { $0.status == .pending }.count, color: .orange)
                HandoffStatBadge(title: "완료", count: handoffs.filter { $0.status == .completed }.count, color: .green)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            Task {
                handoffs = await HandoffService.shared.allHandoffs
            }
        }
    }
}

struct HandoffRow: View {
    let handoff: TaskHandoff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 상단: 태스크 + 상태
            HStack {
                Text(handoff.taskTitle)
                    .font(.headline)
                
                Spacer()
                
                Label(handoff.status.rawValue, systemImage: handoff.status.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            // 중간: From → To
            HStack(spacing: 4) {
                EmployeeBadge(name: handoff.fromEmployeeName, department: handoff.fromDepartment)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                EmployeeBadge(name: handoff.toEmployeeName, department: handoff.toDepartment)
            }
            
            // 하단: 날짜 + 사유
            HStack {
                Text(handoff.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(handoff.reason.rawValue, systemImage: handoff.reason.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 맥락 (있으면)
            if !handoff.context.isEmpty {
                Text(handoff.context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    var statusColor: Color {
        switch handoff.status {
        case .pending: return .orange
        case .accepted, .inProgress: return .blue
        case .completed: return .green
        case .rejected: return .red
        }
    }
}

struct EmployeeBadge: View {
    let name: String
    let department: DepartmentType
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            Text("(\(department.rawValue))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}

struct HandoffStatBadge: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HandoffHistoryView()
}
