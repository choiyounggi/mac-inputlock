# mac-inputlock

화면은 켜둔 채 **키보드·마우스 입력만 전역 차단**하는 macOS 개인 잠금 데몬.
잠금화면(로그인 화면)이 아니라, 입력만 먹통이 되고 화면은 그대로 보이는 "나만의 잠금".

자리비움·청소·실수 방지·고양이 방지용. 토글 단축키 하나로 잠그고 푼다.

## 토글 단축키

**⌃⌥⌘L** (Control + Option + Command + L) — 누를 때마다 잠금 ↔ 해제.

잠금 중에는 키보드·마우스(이동/클릭/스크롤/트랙패드)가 전부 막히고,
오직 이 단축키만 통과해서 잠금을 풀 수 있다.

## 설치

### 1) Homebrew (준비되면)

```bash
brew install --cask choiyounggi/tap/inputlock
```

### 2) 릴리즈에서 직접

[Releases](https://github.com/choiyounggi/mac-inputlock/releases)에서 `InputLock-<version>.zip`을
받아 압축을 풀고 `InputLock.app`을 `/Applications`로 옮긴다.

### 3) 소스에서 빌드

```bash
git clone https://github.com/choiyounggi/mac-inputlock.git
cd mac-inputlock
./build.sh 1.0.0          # InputLock.app + InputLock-1.0.0.zip 생성
```

## 권한 (필수)

입력을 가로채려면 **손쉬운 사용(Accessibility)** 권한이 필요하다.
**시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용**에서 `InputLock.app`을 추가하고 토글 ON.

> macOS 보안상 이 권한은 사용자가 직접 줘야 하며 자동화할 수 없다.

## 자동시작 (로그인 시 상주)

권한을 준 뒤 아래 한 줄이면 LaunchAgent로 등록되어 로그인 시 항상 상주한다:

```bash
/Applications/InputLock.app/Contents/MacOS/inputlock --install-agent
```

해제:

```bash
/Applications/InputLock.app/Contents/MacOS/inputlock --uninstall-agent
```

## 탈출구 (입력이 안 풀릴 때)

- 잠금 중이라도 **⌃⌥⌘L** 은 항상 통과한다.
- 그래도 안 되면 다른 기기에서 SSH로 `killall inputlock`.
  프로세스가 죽으면 event tap이 자동 해제되어 입력이 **즉시** 복구된다.
  (자동시작이 켜져 있으면 ~10초 뒤 **잠금 해제 상태로** 되살아난다.)

## 한계 (보안 잠금이 아님)

100% 차단은 아니다. 전원 버튼 강제종료, 암호 입력 필드(secure input) 상황의 일부 시스템 단축키,
일부 멀티터치 시스템 제스처는 OS가 우선 처리할 수 있다.
실수/장난/자리비움용으론 충분하지만, 작정한 침입을 막는 보안 잠금은 아니다.

## 동작 원리

`CGEventTap`(Quartz 전역 이벤트 탭)을 세션 레벨에 걸어, 잠금 상태에서 키보드·마우스 이벤트를
삼킨다(suppress). 토글 단축키만은 잠금/해제 어느 상태에서든 가로채 토글 트리거로 쓴다.

## 라이선스

MIT — [LICENSE](LICENSE)
