import Foundation
import SwiftUI

func debuglog(_ object: Any?, level: DebugLog.DebugLevel) {
    switch level {
    case .log:
        DebugLog.i.w(object, level: level)
    default:
        #if DEBUG
        DebugLog.i.w(object, level: level)
        #endif
        break
    }
}
func debuglogAtView(_ object: Any?, level: DebugLog.DebugLevel) -> some View {
    debuglog(object, level: level)
    return EmptyView()
}
func stackTrace(l: DebugLog.DebugLevel = .err) {
    var m = "Stack Trace"
    Thread.callStackSymbols.enumerated().forEach {
        guard $0.offset > 0 else { return }
        m += "\n\($0.element)"
    }
    DebugLog.i.w(m, level: l)

}

class DebugLog {
    private init() {
        startTime = CFAbsoluteTimeGetCurrent()
        lastTime = startTime
    }
    public static let i: DebugLog = DebugLog()
    private let startTime: CFAbsoluteTime
    private var lastTime: CFAbsoluteTime

    enum DebugLevel: String {
        case log, dbg, err
        var debugHeader: String {
            let spaceStr: String
            switch self {
            case .log: spaceStr = "  "
            case .dbg: spaceStr = "--"
            case .err: spaceStr = "!!"
            }
            return "{[\(spaceStr)\(self.rawValue.uppercased())\(spaceStr)]}"
        }
    }

    let maxNSLogBytes = 1024
    /**
     Debug Print
     */
    public func w(_ object: Any?, level: DebugLevel) {
        #if DEBUG
        let currentTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
        let elapsedTime: CFAbsoluteTime = currentTime - startTime
        let diffTime: CFAbsoluteTime = currentTime - lastTime
        defer { lastTime = CFAbsoluteTimeGetCurrent() }
        let header =
            level.debugHeader
                + "[elapsed: \(String(format:"%.4f", elapsedTime))]"
                + "[diff: \(String(format:"%.4f", diffTime))] "
        guard let object = object else {
            NSLog(header + "argument is nil")
            return
        }
        let buff: String = header + "\(object)"
        guard let buffAsData = buff.data(using: .utf8) else {
            NSLog(buff)
            return
        }
        if buffAsData.count < maxNSLogBytes {
            NSLog(buff)
            return
        }
        // 1024バイト以上は NSLog() だと端折られるので print() で代用する
        // (debug consoleでは表示されるが、ios consoleなどで表示されないので注意)
        print(Date().description + buff)
        #endif
    }
}
