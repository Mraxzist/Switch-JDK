# Switch-JDK.ps1

**English** | [Русский](README.ru.md)

A handy PowerShell script for instantly switching between JDK versions on Windows.
It auto-discovers installs (Adoptium/AdoptOpenJDK/Microsoft/Zulu/Oracle), fixes `PATH`, sets `JAVA_HOME`/`JDK_HOME`, broadcasts an environment change to the system, and prints the correct version flag (`-version` for JDK 8, `--version` for 9+).

> **Run the script:**
>
> ```powershell
> .\Switch-JDK.ps1 -Version 17
> .\Switch-JDK.ps1 -Version 24 -Vendor Oracle
> ```

---

## ✨ Features

* 🔎 **JDK auto-detection** via standard locations and the Registry (for Oracle).
* 🏷️ **Vendors:** default is “Any”; for Oracle use `-Vendor Oracle`.
* 📣 **Environment broadcast** — new processes pick up the change immediately.
* 🧑‍💻 **No admin required:** writes to `User` scope; with admin rights — to `Machine`.

---

## 🚀 Quick Start

```powershell
# Switch to JDK 17
.\Switch-JDK.ps1 -Version 17

# Switch to Oracle JDK 24 (looked up via JavaSoft Registry keys)
.\Switch-JDK.ps1 -Version 24 -Vendor Oracle

# Explicitly choose scope (default Auto: Machine if admin; otherwise User)
.\Switch-JDK.ps1 -Version 11 -Scope User
.\Switch-JDK.ps1 -Version 21 -Scope Machine
```

Verification:

```powershell
java -version   # For JDK 8
java --version  # For JDK 9+
```

---

## ⚙️ Parameters

| Parameter  | Type / Allowed values | Default | Description                                                   |
| ---------- | --------------------- | ------- | ------------------------------------------------------------- |
| `-Version` | `8, 11, 17, 21, 24`   | —       | Target major JDK version.                                     |
| `-Scope`   | `Auto, Machine, User` | `Auto`  | Where to write environment variables.                         |
| `-Vendor`  | `Any, Oracle`         | `Any`   | Preferred vendor. For Oracle 24, uses JavaSoft Registry keys. |

---

## 🛠️ How to add new versions (e.g., 25, 26)

1. **Allow the number in the parameter** (`param(...)` at the top of the file):

   ```powershell
   [ValidateSet(8,11,17,21,24,25,26)]
   [int]$Version,
   ```

> Optionally add new vendor roots to the `roots` array (Liberica/Corretto/RedHat, etc.) if you use other distributions:

> Example

> ```powershell
> 'C:\Program Files\BellSoft',        # Liberica
> 'C:\Program Files\Amazon Corretto', # Corretto
> 'C:\Program Files\RedHat'           # Red Hat builds
> ```

---

## ❗ Important notes

* **JDK 8** doesn’t support `--version` — use `java -version`. The script selects the correct flag automatically.
* **Running applications** (IDEs, terminals) may not see updated variables — restart them after switching.
* **Machine scope** requires administrator rights; otherwise use `-Scope User` or the default `Auto`.

---

## 🧹 What exactly is changed

* Environment variables: `JAVA_HOME`, `JDK_HOME`.
* `PATH`: removes old segments like `...\jdk*\bin`/`...\jre*\bin`, prepends `"<JDK_HOME>\bin"`.
* The current PowerShell session is updated immediately; a system `WM_SETTINGCHANGE` broadcast is also sent.
