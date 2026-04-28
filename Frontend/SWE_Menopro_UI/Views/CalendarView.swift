//
//  CalendarView.swift
//  SWE_Menopro_UI
//
//  Monthly calendar showing days with hot flashes highlighted in pink.
//  Tap any day to manually log/unlog a hot flash for that date.
//

import SwiftUI

struct CalendarView: View {
    @State private var displayedMonth: Date = Date()
    @State private var hotFlashDates: Set<String> = []
    @State private var isLoading = false
    @State private var feedbackMessage = ""
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            Color.menoCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    header
                        .padding(.top, 8)

                    monthNavigator

                    weekdayHeader

                    monthGrid

                    legendRow

                    if let selected = selectedDate {
                        selectedDateCard(date: selected)
                    }

                    if !feedbackMessage.isEmpty {
                        Text(feedbackMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.menoMagenta)
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadEvents)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("calendar")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.menoMagenta)
                Text("Your hot flash log")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.menoTextPrimary)
            }
            Spacer()
            if isLoading {
                ProgressView().tint(.menoMagenta)
            }
        }
    }

    // MARK: - Month navigator

    private var monthNavigator: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.menoMagenta)
                    .frame(width: 36, height: 36)
                    .background(Color.menoCard)
                    .clipShape(Circle())
            }

            Spacer()

            Text(monthYearString(displayedMonth))
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.menoTextPrimary)

            Spacer()

            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.menoMagenta)
                    .frame(width: 36, height: 36)
                    .background(Color.menoCard)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols // ["S","M","T","W","T","F","S"]
        return HStack {
            ForEach(symbols, id: \.self) { day in
                Text(day)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.menoTextTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let days = daysForMonth(displayedMonth)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                dayCell(day)
            }
        }
        .menoCard(radius: MenoRadius.large, padding: 12)
    }

    private func dayCell(_ day: Date?) -> some View {
        Group {
            if let day = day {
                let dateString = isoDate(day)
                let hasHotFlash = hotFlashDates.contains(dateString)
                let isSelected = selectedDate.map { isoDate($0) == dateString } ?? false
                let isToday = calendar.isDateInToday(day)
                let isFuture = day > Date()

                Button(action: { selectDate(day) }) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 14, weight: hasHotFlash ? .semibold : .regular))
                        .foregroundColor(textColor(hasHotFlash: hasHotFlash, isFuture: isFuture))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            ZStack {
                                if hasHotFlash {
                                    Circle().fill(Color.menoMagentaSoft)
                                        .frame(width: 36, height: 36)
                                }
                                if isSelected {
                                    Circle().stroke(Color.menoMagenta, lineWidth: 2)
                                        .frame(width: 36, height: 36)
                                }
                                if isToday && !hasHotFlash && !isSelected {
                                    Circle().stroke(Color.menoTextTertiary, lineWidth: 1)
                                        .frame(width: 36, height: 36)
                                }
                            }
                        )
                }
                .disabled(isFuture)
            } else {
                Color.clear.frame(height: 36)
            }
        }
    }

    private func textColor(hasHotFlash: Bool, isFuture: Bool) -> Color {
        if isFuture { return .menoTextTertiary }
        if hasHotFlash { return .menoMagentaDark }
        return .menoTextPrimary
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(Color.menoMagentaSoft).frame(width: 10, height: 10)
                Text("hot flash logged")
                    .font(.system(size: 11))
                    .foregroundColor(.menoTextSecondary)
            }
            HStack(spacing: 6) {
                Circle().stroke(Color.menoTextTertiary, lineWidth: 1).frame(width: 10, height: 10)
                Text("today")
                    .font(.system(size: 11))
                    .foregroundColor(.menoTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Selected date detail

    private func selectedDateCard(date: Date) -> some View {
        let dateString = isoDate(date)
        let hasHotFlash = hotFlashDates.contains(dateString)

        return VStack(alignment: .leading, spacing: 12) {
            Text(longDateString(date))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.menoTextPrimary)

            Text(hasHotFlash
                 ? "A hot flash was logged on this day."
                 : "No hot flash logged.")
                .font(.system(size: 13))
                .foregroundColor(.menoTextSecondary)

            Button(action: { toggleHotFlash(for: date) }) {
                Text(hasHotFlash ? "Remove this log" : "Log a hot flash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(hasHotFlash ? Color.menoTextSecondary : Color.menoMagentaDark)
                    .cornerRadius(MenoRadius.small)
            }
        }
        .menoCard(radius: MenoRadius.medium, padding: 16)
    }

    // MARK: - Actions

    private func selectDate(_ date: Date) {
        feedbackMessage = ""
        selectedDate = date
    }

    private func changeMonth(by offset: Int) {
        if let new = calendar.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = new
            selectedDate = nil
        }
    }

    private func toggleHotFlash(for date: Date) {
        let dateString = isoDate(date)
        let hasHotFlash = hotFlashDates.contains(dateString)
        feedbackMessage = ""

        if hasHotFlash {
            APIService.shared.unlogHotFlash(date: dateString) { success, message in
                DispatchQueue.main.async {
                    if success {
                        hotFlashDates.remove(dateString)
                        feedbackMessage = "Removed."
                    } else {
                        feedbackMessage = message
                    }
                }
            }
        } else {
            APIService.shared.logHotFlash(date: dateString) { success, message in
                DispatchQueue.main.async {
                    if success {
                        hotFlashDates.insert(dateString)
                        feedbackMessage = "Logged."
                    } else {
                        feedbackMessage = message
                    }
                }
            }
        }
    }

    // MARK: - Networking

    private func loadEvents() {
        isLoading = true
        APIService.shared.getHotFlashDates { success, dates, _ in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    hotFlashDates = Set(dates)
                }
            }
        }
    }

    // MARK: - Date helpers

    private func monthYearString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func longDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Returns an array of optional dates representing the month grid.
    /// Leading nils pad to the first weekday of the month.
    private func daysForMonth(_ date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let dayCount = calendar.range(of: .day, in: .month, for: date)?.count
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) // 1 = Sunday
        let leadingPadding = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingPadding)
        for i in 0..<dayCount {
            if let d = calendar.date(byAdding: .day, value: i, to: monthInterval.start) {
                days.append(d)
            }
        }
        return days
    }
}

#Preview {
    CalendarView()
}
