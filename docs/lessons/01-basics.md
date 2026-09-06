# 1. 터미널·Linux·파일의 기초

[학습 목차](../README.md) · 다음: [서버와 네트워크](02-network.md)

**목표:** 명령을 입력하는 위치를 구분하고, 파일을 찾고 읽을 수 있다. 아직 서버 설정 명령은 실행하지 않는다.

## 1.1 Mac과 Ubuntu는 다른 환경이다

Mac에서는 macOS가 실행된다. 이 과제에서는 OrbStack을 통해 Ubuntu라는 Linux 환경을 사용한다. 같은 화면 안에 터미널이 있어도 명령이 실행되는 운영체제와 사용자는 다를 수 있다.

| 이름 | 뜻 | 이번 과제에서 하는 일 |
| --- | --- | --- |
| 운영체제(OS) | 프로그램과 하드웨어를 관리하는 기본 소프트웨어 | macOS, Ubuntu |
| Linux | 운영체제의 핵심인 커널을 중심으로 한 계열 | 서버 실습 환경 |
| Ubuntu | Linux 커널과 도구를 묶어 제공하는 배포판 | 계정·방화벽·앱을 설정 |
| OrbStack | Mac에서 Linux 환경 등을 사용할 수 있게 하는 앱 | `24.04ubuntu`에 접근 |
| 터미널 | 글자로 명령을 입력하고 결과를 보는 창 | 명령 입력 |
| 셸(shell) | 입력한 명령을 해석하고 실행하는 프로그램 | 이번 스크립트는 Bash 사용 |

첫 번째 습관은 아래 세 명령이다.

```bash
uname -s
whoami
pwd
```

각각 운영체제 이름, 현재 사용자 이름, 현재 작업 폴더를 출력한다. `Linux`가 나오면 VM, `Darwin`이면 Mac이다. `whoami`가 `root`이면 최고 관리자 상태이므로 일반 학습 실습에는 기본 계정으로 돌아오는 편이 좋다.

## 1.2 명령은 어떻게 읽는가?

```bash
ls -l /home
```

- `ls`: 파일 목록을 출력하는 명령
- `-l`: 자세히 출력하라는 옵션
- `/home`: 살펴볼 대상 경로

`명령 옵션 대상`으로 읽으면 된다. 모든 명령이 똑같은 옵션을 쓰지는 않는다. 도움말은 `ls --help` 또는 `man ls`로 볼 수 있다. `man` 화면은 `q`로 닫는다.

화면에 `hankkim@24:~$`처럼 보이는 것은 **프롬프트**다. 사용자가 명령을 입력할 차례라는 표시이며 복사해서 입력하지 않는다. 결과 예시와 실제 입력 명령도 구분한다. 문서에서 `text` 블록은 주로 읽을 출력 예시다.

## 1.3 경로 읽기

파일과 폴더는 나무처럼 연결된다. Linux에서 가장 위는 `/`다. 이를 루트 디렉토리라고 부른다. 최고 관리자 사용자 `root`와 이름은 비슷하지만 서로 다른 개념이다.

```text
/
├── home/
│   ├── hankkim/
│   └── agent-admin/
│       └── agent-app/
└── var/
    └── log/
        └── agent-app/
            └── monitor.log
```

| 표기 | 의미 |
| --- | --- |
| `/home/agent-admin` | `/`부터 적은 절대 경로 |
| `bin/monitor.sh` | 현재 위치 기준 상대 경로 |
| `.` | 현재 디렉토리 |
| `..` | 바로 위 디렉토리 |
| `~` | 현재 사용자의 홈 디렉토리 |

`agent-admin`의 `~`는 `/home/agent-admin`이고, `hankkim`의 `~`는 보통 `/home/hankkim`이다. 따라서 서로 다른 사용자에게 `~/agent-app`이 같은 경로라고 생각하면 안 된다.

이번 과제에는 **소스 경로**와 **설치 경로**도 따로 있다.

```text
저장소: /Users/hankkim/Desktop/codyssey/B4-1/bin/monitor.sh
                 setup.sh가 복사 ↓
VM 설치: /home/agent-admin/agent-app/bin/monitor.sh
```

공유된 저장소를 VM에서 읽는 것과, VM 전용 설치 파일을 실행하는 것은 다른 작업이다. 편집 후 설치본에 반영하지 않으면 예전 코드가 실행된다.

## 1.4 꼭 필요한 파일 명령

| 명령 | 하는 일 | 예 |
| --- | --- | --- |
| `pwd` | 현재 위치 확인 | `pwd` |
| `ls` | 목록 확인 | `ls -la` |
| `cd` | 폴더 이동 | `cd /home` |
| `mkdir` | 폴더 생성 | `mkdir practice` |
| `cat` | 파일 전체 출력 | `cat note.txt` |
| `less` | 긴 파일을 페이지로 보기 | `less note.txt` — q로 종료 |
| `head` | 앞부분 보기 | `head -n 5 note.txt` |
| `tail` | 뒷부분 보기 | `tail -n 5 note.txt` |
| `cp` | 복사 | `cp note.txt copy.txt` |
| `mv` | 이동·이름 변경 | `mv copy.txt renamed.txt` |
| `rm` | 파일 삭제 | `rm renamed.txt` |

명령줄의 `rm`은 일반적으로 휴지통으로 이동시키지 않는다. 아래 연습에서는 직접 만든 파일의 이름을 지정해서 지운다.

## 1.5 작은 실습: 임시 폴더에서 파일 다루기

**장소: Ubuntu 일반 계정. 영향: 새 임시 폴더와 연습 파일만 생성한다.** 한 터미널에서 순서대로 실행한다.

```bash
practice_dir=$(mktemp -d)
cd "$practice_dir"
pwd
printf 'hello Linux\n' > note.txt
cat note.txt
cp note.txt copy.txt
ls -l
printf 'second line\n' >> note.txt
tail -n 1 note.txt
```

예상 결과:

- `pwd`는 `/tmp/tmp.…`처럼 새 임시 경로다.
- 처음 `cat` 결과는 `hello Linux`다.
- `ls`에는 `note.txt`와 `copy.txt`가 있다.
- 마지막 줄은 `second line`이다.

`>`는 파일을 새 내용으로 쓰고, `>>`는 기존 내용 뒤에 덧붙인다. 로그는 과거 기록을 남겨야 하므로 `>>`를 사용한다. `$practice_dir`는 이 터미널에서 만든 변수다. 새 터미널에는 이 변수가 없다.

연습이 끝나면 직접 만든 두 파일과 빈 임시 폴더만 제거한다.

```bash
rm note.txt copy.txt
cd ~
rmdir "$practice_dir"
```

## 1.6 편집과 키보드

텍스트 파일 편집에는 `nano`를 사용할 수 있다. 설치되어 있다면 `nano 파일경로`로 연다. 저장은 Ctrl+O → Enter, 종료는 Ctrl+X다. 관리자 설정 파일은 `sudoedit /etc/ssh/sshd_config`처럼 권한을 빌려 편집한다. 시스템 설정 파일의 소유자를 자기 계정으로 바꾸지는 않는다.

| 키 | 용도 |
| --- | --- |
| Tab | 파일명·명령 자동 완성 |
| 위쪽 화살표 | 이전 명령 다시 불러오기 |
| Ctrl+C | 현재 전경 프로그램 중단 요청 |
| Ctrl+D 또는 `exit` | 현재 셸 종료. VM 셸이면 Mac 셸로 돌아갈 수 있음 |
| q | less/man 화면 닫기 |

macOS의 복사·붙여넣기는 Command+C/V다. 터미널에서 Ctrl+C는 복사가 아닌 프로그램 중단이다.

## 확인 질문

1. `pwd`가 알려 주는 것은 사용자 이름인가, 현재 경로인가?
2. `bin/monitor.sh`가 어떤 때는 없다고 나오는 이유는 무엇인가?
3. 기존 로그를 남기려면 `>`와 `>>` 중 무엇을 써야 하는가?

<details>
<summary>답 확인</summary>

1. 현재 작업 경로다. 사용자 이름은 `whoami`로 본다.
2. 상대 경로이므로 현재 폴더에 따라 다른 파일을 가리킨다.
3. `>>`다. `>`는 기존 내용을 덮어쓴다.

</details>
