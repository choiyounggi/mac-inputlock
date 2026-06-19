// inputlock — 화면은 켜둔 채 키보드/마우스 입력을 전역 차단하는 개인 잠금 데몬.
//
// 토글 단축키: ⌃⌥⌘L (Control+Option+Command+L) 로 잠금/해제.
// 잠금 중에는 키보드·마우스(이동·클릭·스크롤·트랙패드)가 전부 막히고,
// 오직 토글 단축키만 통과해서 잠금을 풀 수 있다.
//
// 안전장치(탈출구):
//   1. 이 프로세스가 죽으면 event tap이 자동 해제되어 입력이 즉시 복구된다.
//      → SSH로 들어와 `killall inputlock` 하면 무조건 빠져나올 수 있다.
//   2. Ctrl+C / SIGTERM 종료 시에도 정상 복구.
//   3. OS가 tap을 timeout으로 끄면 자동 재활성화.
//   4. 잠금 중 디스플레이가 꺼지지 않도록 sleep 방지(화면 유지).
//
// 한계: macOS 보안상 100% 차단은 아니다. 전원 버튼 강제종료, secure input(암호 입력 필드)
//       상황의 일부 시스템 단축키, 일부 멀티터치 시스템 제스처는 OS가 우선 처리할 수 있다.
//       "실수/장난/고양이/청소용 잠금" 수준엔 충분하지만 작정한 침입 차단용 보안 잠금은 아니다.

import Foundation
import CoreGraphics
import IOKit.pwr_mgt
import ApplicationServices

let agentLabel = "com.onggi.inputlock"

func stderrLine(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}

@discardableResult
func runLaunchctl(_ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
}

func agentPlistPath() -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return home + "/Library/LaunchAgents/\(agentLabel).plist"
}

func selfExecutablePath() -> String {
    // .app 번들 안에서 실행되면 번들 내부 실행 바이너리 경로를 쓴다.
    return Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
}

func installAgent() {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let exec = selfExecutablePath()
    let logPath = home + "/Library/Logs/inputlock.log"
    let plistPath = agentPlistPath()
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>\(agentLabel)</string>
        <key>ProgramArguments</key>
        <array>
            <string>\(exec)</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>ThrottleInterval</key>
        <integer>10</integer>
        <key>StandardOutPath</key>
        <string>\(logPath)</string>
        <key>StandardErrorPath</key>
        <string>\(logPath)</string>
    </dict>
    </plist>
    """
    let fm = FileManager.default
    try? fm.createDirectory(atPath: home + "/Library/LaunchAgents", withIntermediateDirectories: true)
    do {
        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
    } catch {
        stderrLine("[inputlock] ❌ LaunchAgent plist 작성 실패: \(error)")
        exit(1)
    }
    let uid = getuid()
    runLaunchctl(["bootout", "gui/\(uid)/\(agentLabel)"])   // 기존 게 있으면 내림 (없으면 무시)
    let rc = runLaunchctl(["bootstrap", "gui/\(uid)", plistPath])
    if rc == 0 {
        stderrLine("""
        [inputlock] ✅ 자동시작 등록 완료 — 로그인하면 항상 상주합니다.
                    plist: \(plistPath)
                    토글: ⌃⌥⌘L   로그: \(logPath)
        손쉬운 사용(Accessibility) 권한이 아직 없으면 시스템 설정에서 켠 뒤
        `\(exec) --install-agent` 를 다시 실행하세요.
        """)
    } else {
        stderrLine("[inputlock] ⚠️ bootstrap 실패 (코드 \(rc)). plist는 작성됨: \(plistPath)")
    }
}

func uninstallAgent() {
    let uid = getuid()
    runLaunchctl(["bootout", "gui/\(uid)/\(agentLabel)"])
    let plistPath = agentPlistPath()
    try? FileManager.default.removeItem(atPath: plistPath)
    stderrLine("[inputlock] 🧹 자동시작 해제 완료 (plist 제거: \(plistPath))")
}

func printHelp() {
    stderrLine("""
    inputlock — 화면은 켜둔 채 키보드/마우스 입력을 전역 차단하는 개인 잠금.

    사용법:
      inputlock                  데몬 실행 (포그라운드). ⌃⌥⌘L 로 잠금/해제 토글.
      inputlock --install-agent  로그인 시 자동 상주하도록 LaunchAgent 등록.
      inputlock --uninstall-agent 자동 상주 해제.
      inputlock --help           이 도움말.

    탈출구: 잠긴 채 안 풀리면 다른 기기에서 SSH로 `killall inputlock`.
    """)
}

// MARK: - 서브커맨드 분기
if CommandLine.arguments.count > 1 {
    switch CommandLine.arguments[1] {
    case "--install-agent":   installAgent();   exit(0)
    case "--uninstall-agent": uninstallAgent(); exit(0)
    case "--help", "-h":      printHelp();      exit(0)
    default:
        stderrLine("[inputlock] 알 수 없는 옵션: \(CommandLine.arguments[1])  (--help 참고)")
        exit(2)
    }
}

// kVK_ANSI_L = 0x25 (37)
let toggleKeyCode: Int64 = 0x25

var locked = false
var eventTap: CFMachPort?

// MARK: - 디스플레이 sleep 방지 (잠금 중 화면 유지)
var assertionID: IOPMAssertionID = 0
var assertionActive = false

func setDisplayAssertion(_ on: Bool) {
    if on && !assertionActive {
        let r = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "inputlock active" as CFString,
            &assertionID)
        assertionActive = (r == kIOReturnSuccess)
    } else if !on && assertionActive {
        IOPMAssertionRelease(assertionID)
        assertionActive = false
    }
}

func log(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}

// MARK: - 토글 조합 감지 (⌃⌥⌘ + L)
func isToggleCombo(_ event: CGEvent) -> Bool {
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let f = event.flags
    return keycode == toggleKeyCode
        && f.contains(.maskControl)
        && f.contains(.maskAlternate)
        && f.contains(.maskCommand)
}

// MARK: - 이벤트 콜백
let eventCallback: CGEventTapCallBack = { _, type, event, _ in
    // OS가 tap을 비활성화했으면 즉시 재활성화
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
        return nil
    }

    // 토글 단축키는 잠금/해제 어느 상태에서든 가로채서 토글 (시스템엔 전달 안 함)
    if type == .keyDown && isToggleCombo(event) {
        locked.toggle()
        setDisplayAssertion(locked)
        log("[inputlock] \(locked ? "🔒 LOCKED — 입력 차단" : "🔓 UNLOCKED — 입력 복구")")
        return nil
    }

    // 잠금 중이면 나머지 모든 입력을 삼킨다
    if locked {
        return nil
    }

    // 평상시엔 그대로 통과
    return Unmanaged.passUnretained(event)
}

// MARK: - 권한 확인 (손쉬운 사용 / Accessibility)
let promptOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(promptOpts) {
    log("""
    [inputlock] ⚠️  손쉬운 사용(Accessibility) 권한이 아직 없습니다.
                시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 에서
                이 프로그램(또는 실행한 터미널)을 켠 뒤 다시 실행하세요.
    """)
    // 권한 다이얼로그가 떴을 수 있으니 잠시 후 tap 생성 시도로 넘어간다.
}

// MARK: - Event Tap 구성
let types: [CGEventType] = [
    .keyDown, .keyUp, .flagsChanged,
    .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
    .mouseMoved, .leftMouseDragged, .rightMouseDragged,
    .scrollWheel, .otherMouseDown, .otherMouseUp, .otherMouseDragged
]
var mask: CGEventMask = 0
for t in types { mask |= (CGEventMask(1) << CGEventMask(t.rawValue)) }

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,            // defaultTap = 이벤트 삭제(차단) 가능
    eventsOfInterest: mask,
    callback: eventCallback,
    userInfo: nil
) else {
    log("""
    [inputlock] ❌ event tap 생성 실패 — 손쉬운 사용(Accessibility) 권한이 필요합니다.
                시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 에서 허용 후 다시 실행하세요.
    """)
    exit(1)
}
eventTap = tap

let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

// MARK: - 종료 시 복구
func cleanup() {
    setDisplayAssertion(false)
    if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
}
signal(SIGINT)  { _ in cleanup(); exit(0) }
signal(SIGTERM) { _ in cleanup(); exit(0) }

log("""
[inputlock] ✅ 실행 중.
            ⌃⌥⌘L (Control+Option+Command+L) 로 잠금/해제 토글.
            탈출구: Ctrl+C, 또는 다른 곳에서 `killall inputlock`.
""")

CFRunLoopRun()
