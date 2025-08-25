# Switch-JDK.ps1

[English](README.md) | **Русский**

Полезный PowerShell-скрипт для моментального переключения между версиями JDK на Windows.
Автопоиск установок (Adoptium/AdoptOpenJDK/Microsoft/Zulu/Oracle), чинит `PATH`, выставляет `JAVA_HOME`/`JDK_HOME`, рассылает системный broadcast, и печатает корректную версию (`-version` для JDK8, `--version` для 9+).

> **Запуск скрипта:**
>
> ```powershell
> .\Switch-JDK.ps1 -Version 17
> .\Switch-JDK.ps1 -Version 24 -Vendor Oracle
> ```

---

## ✨ Возможности

* 🔎 **Автодетект JDK** по стандартным путям и через реестр (для Oracle).
* 🏷️ **Вендоры:** по умолчанию «Any», для Oracle — `-Vendor Oracle`.
* 📣 **Broadcast обновления окружения** — новые процессы сразу видят изменения.
* 🧑‍💻 **Без админ-прав:** можно писать в `User`-область; с админом — в `Machine`.

---

## 🚀 Быстрый старт

```powershell
# Переключиться на JDK 17
.\Switch-JDK.ps1 -Version 17

# Переключиться на Oracle JDK 24 (ищется через реестр JavaSoft)
.\Switch-JDK.ps1 -Version 24 -Vendor Oracle

# Явно выбрать область (по умолчанию Auto: Machine, если админ; иначе User)
.\Switch-JDK.ps1 -Version 11 -Scope User
.\Switch-JDK.ps1 -Version 21 -Scope Machine
```

Проверка:

```powershell
java -version   # Для JDK 8
java --version  # Для JDK 9+
```

---

## ⚙️ Параметры

| Параметр   | Тип / Допустимые значения | По умолчанию | Описание                                                             |
| ---------- | ------------------------- | ------------ | -------------------------------------------------------------------- |
| `-Version` | `8, 11, 17, 21, 24`       | —            | Целевая мажорная версия JDK.                                         |
| `-Scope`   | `Auto, Machine, User`     | `Auto`       | Куда писать переменные окружения.                                    |
| `-Vendor`  | `Any, Oracle`             | `Any`        | Предпочтительный вендор. Для Oracle 24 — использует реестр JavaSoft. |

---

## 🛠️ Как добавить новые версии (например, 25, 26)

1. **Разреши номер в параметре** (`param(...)` вверху файла):

   ```powershell
   [ValidateSet(8,11,17,21,24,25,26)]
   [int]$Version,
   ```

> Добавь новые вендорные корни в массив `roots` (Liberica/Corretto/RedHat и т.п.), если используешь другие дистрибутивы:

> Пример

> ```powershell
> 'C:\Program Files\BellSoft',        # Liberica
> 'C:\Program Files\Amazon Corretto', # Corretto
> 'C:\Program Files\RedHat'           # Red Hat builds
> ```

---

## ❗ Важные нюансы

* **JDK 8** не поддерживает `--version` — используй `java -version`. Скрипт сам выбирает правильный флаг.
* **Запущенные приложения** (IDE, терминалы) могут не увидеть обновления переменных — перезапусти их после переключения.
* **Machine-scope** требует права администратора; иначе используй `-Scope User` или по умолчанию `Auto`.

---

## 🧹 Что именно изменяется

* Переменные окружения: `JAVA_HOME`, `JDK_HOME`.
* `PATH`: удаляются старые сегменты вида `...\jdk*\bin`/`...\jre*\bin`, добавляется `"<JDK_HOME>\bin"` в начало.
* Текущая сессия PowerShell обновляется мгновенно; плюс отправляется системный broadcast `WM_SETTINGCHANGE`.

---