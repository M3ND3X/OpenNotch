// CalendarProvider - EventKit fetch, passes events to Rust.

import EventKit
import Foundation

enum CalendarProvider {
    static func fetchAndDispatch(appModel: AppModel) {
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, _ in
            Task { @MainActor in
                guard granted else {
                    appModel.dispatch(.permissionStatusChanged(calendar: false, camera: appModel.snapshot.permissions.camera, automation: appModel.snapshot.permissions.automation))
                    return
                }
                appModel.dispatch(.permissionStatusChanged(calendar: true, camera: appModel.snapshot.permissions.camera, automation: appModel.snapshot.permissions.automation))
                let start = Date()
                let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
                let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
                let events = store.events(matching: predicate)
                let json = events.prefix(10).map { event in
                    [
                        "title": event.title ?? "",
                        "start": event.startDate?.timeIntervalSince1970 ?? 0,
                        "end": event.endDate?.timeIntervalSince1970 ?? 0,
                    ] as [String: Any]
                }
                if let data = try? JSONSerialization.data(withJSONObject: json),
                   let str = String(data: data, encoding: .utf8) {
                    appModel.dispatch(.calendarEventsReceived(eventsJson: str))
                } else {
                    appModel.dispatch(.calendarEventsReceived(eventsJson: "[]"))
                }
            }
        }
    }
}
