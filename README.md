# LidGuard

LidGuard — нативное macOS-приложение для безопасного переключения режима сна при закрытии крышки через `pmset` с удобным интерфейсом AppKit.

## Что делает приложение

- Отключает сон при закрытии крышки: `pmset -a disablesleep 1`
- Возвращает стандартный режим сна: `pmset -a disablesleep 0`
- Показывает текущее значение `SleepDisabled`
- Запрашивает права администратора только в момент применения изменений
- Не содержит сетевых вызовов, фоновых сервисов и телеметрии

## Системные требования

- macOS 13+
- Swift 6.1+ (для локальной сборки)
- Права администратора (для применения изменений `pmset`)

## Локальный запуск

```bash
swift build --product LidGuardGUI --configuration release --disable-sandbox
./.build/release/LidGuardGUI
```

## Сборка DMG локально

```bash
./scripts/build_dmg.sh
```

Результат: `dist/LidGuard.dmg`.

## Публикация DMG на GitHub Releases

Workflow запускается по тегу `v*` и прикрепляет к релизу файл `LidGuard.dmg`.

```bash
git tag v0.1.1
git push origin v0.1.1
```

Дальше скачивание: GitHub -> `Releases` -> asset `LidGuard.dmg`.

## Безопасность

- Команды выполняются только через фиксированный путь `/usr/bin/pmset`
- Пользовательский ввод не подставляется в shell-команды
- Привилегии администратора используются только для двух целевых операций включения/выключения режима
- Состояние читается отдельной командой `pmset -g`
- Скрипт сборки `scripts/build_dmg.sh` использует `set -euo pipefail`, проверяет обязательные утилиты и очищает временные директории
- GitHub Actions закреплены на конкретные commit SHA для снижения supply-chain риска

## Ограничения

- На корпоративных/MDM-устройствах изменение параметров питания может блокироваться политиками
- GitHub всегда добавляет в релиз ссылки `Source code (zip/tar.gz)` для тега; отключить их нельзя

## Проверка состояния вручную

```bash
pmset -g | awk '/SleepDisabled/ { print $2 }'
```

Ожидаемые значения:
- `1` -> сон при закрытии крышки отключен
- `0` -> стандартный режим сна включен

## Структура репозитория

```text
AppSource/LidGuardApp.swift
Package.swift
scripts/generate_icon.swift
scripts/build_dmg.sh
.github/workflows/build-dmg.yml
```

## Лицензия

MIT, подробнее в [LICENSE](LICENSE).
