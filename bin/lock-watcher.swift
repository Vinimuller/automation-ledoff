#!/usr/bin/swift
import Foundation

DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.screenIsLocked"),
    object: nil,
    queue: nil
) { _ in
    Process.launchedProcess(launchPath: "/usr/local/bin/ledoff", arguments: [])
}

DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("com.apple.screenIsUnlocked"),
    object: nil,
    queue: nil
) { _ in
    Process.launchedProcess(launchPath: "/usr/local/bin/ledon", arguments: [])
}

RunLoop.main.run()
