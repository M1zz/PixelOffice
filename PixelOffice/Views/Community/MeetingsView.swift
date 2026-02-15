import SwiftUI

/// 회의 뷰 - 캘린더와 리스트 뷰 제공
struct MeetingsView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var viewMode: MeetingViewMode = .calendar
    @State private var selectedDate: Date = Date()
    @State private var selectedMonth: Date = Date()
    
    var conversations: [CommunityConversation] {
        companyStore.allConversations
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 뷰 모드 전환
            HStack {
                Picker("보기", selection: $viewMode) {
                    ForEach(MeetingViewMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
                
                // 회의 수 표시
                Text("\(conversations.count)개 회의")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 12)
            
            // 컨텐츠
            switch viewMode {
            case .calendar:
                calendarView
            case .list:
                listView
            }
        }
    }
    
    // MARK: - Calendar View
    
    @ViewBuilder
    private var calendarView: some View {
        VStack(spacing: 16) {
            // 월 네비게이션
            HStack {
                Button {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(monthYearString(selectedMonth))
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    withAnimation {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button {
                    withAnimation {
                        selectedMonth = Date()
                        selectedDate = Date()
                    }
                } label: {
                    Text("오늘")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            
            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(day == "일" ? .red : day == "토" ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            
            // 캘린더 그리드
            let days = generateDaysInMonth(for: selectedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        isCurrentMonth: isSameMonth(date, selectedMonth),
                        isSelected: isSameDay(date, selectedDate),
                        isToday: isSameDay(date, Date()),
                        meetings: meetingsOn(date)
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // 선택된 날짜의 회의 목록
            VStack(alignment: .leading, spacing: 12) {
                Text(dateString(selectedDate))
                    .font(.headline)
                
                let dayMeetings = meetingsOn(selectedDate)
                if dayMeetings.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title)
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("이 날 회의가 없습니다")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(dayMeetings, id: \.id) { meeting in
                        ConversationCard(conversation: meeting, isActive: meeting.status == .inProgress)
                    }
                }
            }
        }
    }
    
    // MARK: - List View
    
    @ViewBuilder
    private var listView: some View {
        if conversations.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("아직 회의 기록이 없습니다")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("AI 직원들이 회의를 요청하면 여기에 표시됩니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // 진행 중인 회의
                let activeConversations = conversations.filter { $0.status == .inProgress }
                if !activeConversations.isEmpty {
                    Text("🔴 진행 중")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    ForEach(activeConversations, id: \.id) { conversation in
                        ConversationCard(conversation: conversation, isActive: true)
                    }
                }
                
                // 완료된 회의 (날짜별 그룹핑)
                let completedConversations = conversations.filter { $0.status == .completed }
                if !completedConversations.isEmpty {
                    Text("✅ 완료됨")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    let grouped = Dictionary(grouping: completedConversations) { conversation in
                        Calendar.current.startOfDay(for: conversation.started)
                    }
                    
                    ForEach(grouped.keys.sorted().reversed(), id: \.self) { date in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dateString(date))
                                .font(.subheadline.bold())
                                .foregroundColor(.secondary)
                            
                            ForEach(grouped[date] ?? [], id: \.id) { conversation in
                                ConversationCard(conversation: conversation, isActive: false)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func meetingsOn(_ date: Date) -> [CommunityConversation] {
        conversations.filter { isSameDay($0.started, date) }
    }
    
    private func generateDaysInMonth(for date: Date) -> [Date] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate < monthLastWeek.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    private func isSameMonth(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.month, from: date1) == calendar.component(.month, from: date2) &&
               calendar.component(.year, from: date1) == calendar.component(.year, from: date2)
    }
    
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }
}

// MARK: - View Mode

enum MeetingViewMode: String, CaseIterable {
    case calendar = "캘린더"
    case list = "목록"
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let meetings: [CommunityConversation]
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // 날짜 숫자
            Text("\(dayNumber)")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor)
            
            // 회의 인디케이터
            if !meetings.isEmpty {
                HStack(spacing: 2) {
                    ForEach(meetings.prefix(3), id: \.id) { meeting in
                        Circle()
                            .fill(meeting.status == .inProgress ? Color.red : Color.blue)
                            .frame(width: 4, height: 4)
                    }
                    if meetings.count > 3 {
                        Text("+")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Spacer()
                    .frame(height: 4)
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.3)
        }
        if isSelected {
            return .white
        }
        if isWeekend {
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekday == 1 ? .red : .blue
        }
        return .primary
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor
        }
        if !isCurrentMonth {
            return Color.clear
        }
        if !meetings.isEmpty {
            return Color.accentColor.opacity(0.1)
        }
        return Color.clear
    }
}

#Preview {
    MeetingsView()
        .environmentObject(CompanyStore())
        .frame(width: 600, height: 700)
        .padding()
}
