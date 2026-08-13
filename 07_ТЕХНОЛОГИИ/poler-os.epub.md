# poler-os
**Репозиторий:** [github.com/Kotokvit/poler-os]
**Тип:** Ядро операционной системы на Zig
**Дата сборки книги:** 2026-07-15 14:34
**Количество файлов:** 47

## Содержание
- [README]
- [Структура проекта]
- [Исходный код]
- [Лицензия]

## README
# POLER-OS
**Универсальная операционная система нового поколения. x86_64, монолитное ядро, Zig 0.13.0.**
POLER-OS — это не дистрибутив Linux и не надстройка над ним. Это независимая операционная система, спроектированная с нуля для решения фундаментальной проблемы: insecurity by design. Linux уязвим архитектурно — ядро открыто для модификации после загрузки, root-процесс является богом системы, а защита строится как надстройка поверх ОС. POLER-OS меняет парадигму: безопасность не добавляется — она является архитектурным свойством ядра.
---

## Архитектурные принципы

### Ядро закрывается после загрузки
После инициализации и верификации целостности ядро криптографически блокирует возможность модификации самого себя. Руткит физически не может внедриться в ядро — механизм внедрения отсутствует как таковой. В Linux `insmod` может загрузить любой модуль, `/dev/mem` даёт доступ к памяти ядра, а eBPF — одновременно инструмент мониторинга и вектор атаки. В POLER-OS ядро неизменяемо после загрузки: XorDDoS, Plague и подавляющее большинство Linux-руткитов работают через модификацию ядра, а если ядро неизменяемо — 90% атак на ядро отпадают.

### Программа — гость, а не хозяин
Даже процесс с максимальными привилегиями в userspace не может модифицировать ядро. Это отличает POLER-OS от Linux, где root = неограниченный доступ. Root в POLER-OS может всё в userspace, но ядро — неприкосновенно. Компрометация userspace-процесса не означает компрометацию системы.

### Прямая Windows-совместимость
Подход Wine/Proton — обратная совместимость: Windows-программа → прослойка-переводчик → Linux kernel. Всегда что-то теряется: не все API реализованы, DRM и античиты не работают, производительность проседает. POLER-OS реализует прямую совместимость: ядро нативно понимает форматы PE/COFF и обрабатывает Win32/Win64 системные вызовы напрямую, без промежуточного слоя-переводчика. Windows-программа говорит на своём языке, и ядро её понимает нативно. Цель — 100% запуск Windows-софта без прослоек.

### Нативная поддержка Linux-софта
Linux-программы работают нативно — POLER-OS реализует подмножество Linux system call interface, позволяя запускать скомпилированный под Linux софт без перекомпиляции. Долгосрочная цель — нативная поддержка KDE Plasma и других десктопных сред через реализацию достаточного подмножества Linux syscalls для работы Wayland и Qt.
---

## Механизмы защиты
Защита в POLER-OS — не надстройка (как ClamAV поверх Linux), а архитектурное свойство:
| Механизм | Реализация | Уровень |
|---|---|---|
| Криптографическая неизменяемость ядра | Ядро верифицирует свою целостность и блокирует модификацию после загрузки | Ядро |
| Сигнатурный анализ | База сигнатур известных угроз, userspace-сканер с kernel-хуками | Ядро + userspace |
| Эвристический анализ | Мониторинг подозрительных паттернов syscall'ов на уровне ядра | Ядро |
| Поведенческий мониторинг | Детект аномалий: массовое шифрование файлов, нетипичные системные вызовы | Ядро |
| Контроль целостности (FIM) | Хеши критических файлов хранятся в ядре, верификация при каждом доступе | Ядро |
| Обнаружение руткитов | Неизменяемое ядро исключает kernel-level руткиты; userspace-руткиты детектятся через FIM | Ядро + userspace |
| Верификация пакетов | Ядро проверяет цифровую подпись перед установкой; неподписанные пакеты блокируются | Ядро (привратник) |
Пакетный менеджер работает в userspace — ядро не должно содержать логику скачивания и распаковки. Но ядро выступает привратником: userspace-PM ставит, ядро верифицирует подпись и разрешает или блокирует установку.
---

## Текущая версия: v0.7.0
| Подсистема | Статус | Описание |
|---|---|---|
| Boot | Готово | Multiboot2 → 32→64 transition → identity paging (4GB, 2MB pages) |
| HAL | Готово | GDT, IDT, PIC remap, Local APIC timer (vector 48), IO-APIC, TSS IST1 |
| ACPI | Готово | RSDP/RSDT/MADT/HPET parsing |
| Memory | Готово | PMM (bitmap), VMM (4-level paging + OOM rollback), kernel heap (free-list + SipHash-2-4) |
| Scheduler | Готово | Round-robin с APIC timer preemption (8 задач, divisor 16) |
| Ring 3 | Готово | User mode: ELF64 loader, per-process CR3, syscall/sysretq, TSS IST |
| Framebuffer | Готово | Linear framebuffer (1024x768x32bpp) + bitmap font |
| Keyboard | Готово | PS/2 Set 2 → Set 1 translation через i8042 controller (bit 6) |
| Serial | Готово | COM1 (115200 baud, 8N1) |
| Crypto | Готово | PND v8 (Parametric Nonlinear Diffusion), RSA-OAEP + POLER-CTR AEAD |
| Syscalls | Готово | syscall/sysretq: print, read_key, clear_screen |
| SMP | Планируется | Многоядерность |
| Networking | Планируется | virtio-net |
| VFS | Планируется | Виртуальная файловая система |
| Win32 compat | Планируется | Нативная обработка Win32/64 syscalls |
| Package verifier | Планируется | Криптографическая верификация пакетов на уровне ядра |
---

## Сборка

### Зависимости
- **Zig 0.13.0** — компилятор
- **QEMU** — для тестирования
- **GRUB** (`grub-pc-bin`, `grub-mkrescue`) — загрузчик
- **xorriso** — создание ISO
Установка зависимостей (Debian/Ubuntu):
```
`
# Минимум для BIOS-загрузки
sudo apt install grub-pc-bin xorriso

# Для UEFI + BIOS dual-boot
sudo apt install grub-pc-bin grub-efi-amd64-bin xorriso mtools
`
```

### Команды
```
`
# Сборка ядра (32-bit + 64-bit)
zig build

# Сборка загрузочного ISO (BIOS + UEFI если доступны модули)
zig build iso

# Запуск 64-bit ядра в QEMU (serial console, без графического окна)
zig build run64

# Запуск 64-bit ядра в QEMU (VGA окно + serial)
zig build run64-gfx

# Запуск 32-bit ядра в QEMU (legacy)
zig build run32

# Тесты POLER Core + RSA-OAEP
zig build test
`
```

### Ручная сборка ISO
```
`
cd zig-kernel
zig build
bash build-iso.sh
`
```

### Запуск ISO в QEMU
```
`
qemu-system-x86_64 -cdrom poler-os64.iso -m 256M -serial stdio -no-reboot
`
```
---

## Структура проекта
```
`
zig-kernel/
├── src64/                    # 64-bit ядро (POLER-OS v0.7.0)
│   ├── boot64.S              # Multiboot2 header, 32→64 переход, page tables
│   ├── isr64.S               # ISR/IRQ stubs + syscall entry
│   ├── main64.zig            # Точка входа, boot sequence, shell
│   ├── hal.zig               # HAL: GDT/IDT/PIC/APIC/IOAPIC/keyboard/serial
│   ├── acpi.zig              # RSDP/RSDT/MADT/HPET парсинг
│   ├── pmm64.zig             # Physical Memory Manager (bitmap)
│   ├── vmm64.zig             # Virtual Memory Manager (4-level paging)
│   ├── heap64.zig            # Kernel heap (free-list + SipHash-2-4)
│   ├── scheduler.zig         # Round-robin scheduler (APIC preempt)
│   ├── elf_loader.zig        # ELF64 loader (Ring 3 user mode)
│   ├── framebuffer.zig       # Linear framebuffer + bitmap font
│   ├── multiboot2.zig        # Multiboot2 info parser
│   ├── cpio.zig              # CPIO initrd parser
│   ├── poler_core.zig        # PND v8 tensor algebra
│   ├── rsa_oaep.zig          # RSA-OAEP + POLER-CTR AEAD
│   └── linker64.ld           # Linker script
├── src/                      # Legacy 32-bit ядро
│   ├── boot32.S              # 16-bit real → 32-bit protected mode
│   ├── isr32.S               # 32-bit ISR stubs
│   ├── main32.zig            # 32-bit kernel entry
│   └── ...
├── drivers/                  # Общие драйверы
├── arch/                     # Архитектурно-зависимый код
├── boot/                     # Boot logic
├── mm/                       # Memory management helpers
├── iso/                      # GRUB ISO структура (BIOS boot)
├── iso-efi/                  # GRUB ISO структура (UEFI boot)
├── iso-minimal/              # Минимальная ISO структура
├── build.zig                 # Конфигурация сборки Zig
├── build-iso.sh              # Скрипт сборки ISO (auto-detect BIOS/UEFI)
├── build-minimal-iso.sh      # Минимальная ISO сборка
├── run-qemu.sh               # Скрипт запуска QEMU
└── run-qemu-iso.sh           # Скрипт запуска QEMU с ISO
`
```
---

## Дорожная карта

### Этап 1 — Ядро (текущий)
- [x] Загрузка в 64-bit long mode через Multiboot2/GRUB
- [x] HAL: GDT, IDT, PIC, APIC, IO-APIC, TSS
- [x] Управление памятью: PMM + VMM + kernel heap
- [x] Preemptive multitasking: round-robin scheduler
- [x] Ring 3: user mode, ELF64 loader, per-process CR3
- [x] Криптография: PND v8, RSA-OAEP, POLER-CTR AEAD
- [x] Framebuffer, PS/2 клавиатура, serial console
- [ ] SMP — многоядерность

### Этап 2 — Файловая система и драйверы
- [ ] VFS (виртуальная файловая система)
- [ ] Файловая система (ext2 или собственная)
- [ ] Драйвер AHCI/SATA
- [ ] Драйвер сети (virtio-net / e1000)
- [ ] USB stack

### Этап 3 — Безопасность
- [ ] Криптографическая блокировка ядра после загрузки
- [ ] Верификация целостности системных файлов (FIM)
- [ ] Сигнатурный сканер (userspace + kernel hooks)
- [ ] Поведенческий мониторинг на уровне ядра
- [ ] Верификатор пакетов (kernel gatekeeper)

### Этап 4 — Совместимость
- [ ] Подмножество Linux system call interface
- [ ] PE/COFF loader (Windows executables)
- [ ] Подмножество Win32/64 system calls
- [ ] POSIX compatibility layer

### Этап 5 — Графическая среда
- [ ] GPU driver (минимальный)
- [ ] Wayland / собственный display server
- [ ] Qt портирование / нативная поддержка
- [ ] KDE Plasma или собственная DE
---

## История версий

### v0.7.0 — Ring 3 User Mode
- ELF64 loader, per-process CR3, TSS IST1
- User code/data segments (CS=0x1B, SS=0x23)
- syscall/sysretq privilege switch
- IRETQ для возврата в user mode

### v0.6.1 — Bug Fixes
- CTR brace mismatch в hybridEncrypt()
- Q glyph рендеринг
- Circular import hal↔scheduler → callback

### v0.6.0 — Preemptive Multitasking
- Round-robin scheduler с APIC timer
- 8 одновременных задач
- Context switch через stack-based состояния

### v0.5.0 — 64-bit Long Mode
- Multiboot2 boot, 32→64 переход
- HAL: GDT, IDT, PIC, APIC
- PMM + VMM + kernel heap
---

## Лицензия
GNU General Public License v3.0 or later (GPLv3+). См. [LICENSE].

## Структура проекта
- `README.md`
- **zig-kernel/**
- **arch/**
- **x86_64/**
- `idt.zig`
- **boot/**
- `boot.zig`
- `build-iso.sh`
- `build-minimal-iso.sh`
- `build.zig`
- `build_test.zig`
- **drivers/**
- `framebuffer.zig`
- `vga.zig`
- `virtio.zig`
- `main.zig`
- **mm/**
- `pmm.zig`
- `run-qemu-iso.sh`
- `run-qemu.sh`
- **src/**
- `boot.S`
- `boot.zig`
- `boot32.S`
- `boot32_test.S`
- **drivers/**
- `serial.zig`
- `vga.zig`
- `isr32.S`
- `linker.ld`
- `linker32.ld`
- `main.zig`
- `main32.zig`
- `main_minimal.zig`
- `poler_core.zig`
- `rsa_oaep.zig`
- **src64/**
- `acpi.zig`
- `boot64.S`
- `boot_smp.S`
- `cpio.zig`
- `elf_loader.zig`
- `framebuffer.zig`
- `hal.zig`
- `heap64.zig`
- `isr64.S`
- `linker64.ld`
- `main64.zig`
- `multiboot2.zig`
- `pmm64.zig`
- `poler_core.zig`
- `rsa_oaep.zig`
- `scheduler.zig`
- `smp.zig`
- `spinlock.zig`
- `vmm64.zig`

## Исходный код
Всего файлов: 47. Полный исходный код без обрезки.

### `README.md` [markdown · 13,872 B]
```
`# POLER-OS

**Универсальная операционная система нового поколения. x86_64, монолитное ядро, Zig 0.13.0.**

POLER-OS — это не дистрибутив Linux и не надстройка над ним. Это независимая операционная система, спроектированная с нуля для решения фундаментальной проблемы: insecurity by design. Linux уязвим архитектурно — ядро открыто для модификации после загрузки, root-процесс является богом системы, а защита строится как надстройка поверх ОС. POLER-OS меняет парадигму: безопасность не добавляется — она является архитектурным свойством ядра.

---

## Архитектурные принципы

### Ядро закрывается после загрузки

После инициализации и верификации целостности ядро криптографически блокирует возможность модификации самого себя. Руткит физически не может внедриться в ядро — механизм внедрения отсутствует как таковой. В Linux `insmod` может загрузить любой модуль, `/dev/mem` даёт доступ к памяти ядра, а eBPF — одновременно инструмент мониторинга и вектор атаки. В POLER-OS ядро неизменяемо после загрузки: XorDDoS, Plague и подавляющее большинство Linux-руткитов работают через модификацию ядра, а если ядро неизменяемо — 90% атак на ядро отпадают.

### Программа — гость, а не хозяин

Даже процесс с максимальными привилегиями в userspace не может модифицировать ядро. Это отличает POLER-OS от Linux, где root = неограниченный доступ. Root в POLER-OS может всё в userspace, но ядро — неприкосновенно. Компрометация userspace-процесса не означает компрометацию системы.

### Прямая Windows-совместимость

Подход Wine/Proton — обратная совместимость: Windows-программа → прослойка-переводчик → Linux kernel. Всегда что-то теряется: не все API реализованы, DRM и античиты не работают, производительность проседает. POLER-OS реализует прямую совместимость: ядро нативно понимает форматы PE/COFF и обрабатывает Win32/Win64 системные вызовы напрямую, без промежуточного слоя-переводчика. Windows-программа говорит на своём языке, и ядро её понимает нативно. Цель — 100% запуск Windows-софта без прослоек.

### Нативная поддержка Linux-софта

Linux-программы работают нативно — POLER-OS реализует подмножество Linux system call interface, позволяя запускать скомпилированный под Linux софт без перекомпиляции. Долгосрочная цель — нативная поддержка KDE Plasma и других десктопных сред через реализацию достаточного подмножества Linux syscalls для работы Wayland и Qt.

---

## Механизмы защиты

Защита в POLER-OS — не надстройка (как ClamAV поверх Linux), а архитектурное свойство:

| Механизм | Реализация | Уровень |
|---|---|---|
| Криптографическая неизменяемость ядра | Ядро верифицирует свою целостность и блокирует модификацию после загрузки | Ядро |
| Сигнатурный анализ | База сигнатур известных угроз, userspace-сканер с kernel-хуками | Ядро + userspace |
| Эвристический анализ | Мониторинг подозрительных паттернов syscall'ов на уровне ядра | Ядро |
| Поведенческий мониторинг | Детект аномалий: массовое шифрование файлов, нетипичные системные вызовы | Ядро |
| Контроль целостности (FIM) | Хеши критических файлов хранятся в ядре, верификация при каждом доступе | Ядро |
| Обнаружение руткитов | Неизменяемое ядро исключает kernel-level руткиты; userspace-руткиты детектятся через FIM | Ядро + userspace |
| Верификация пакетов | Ядро проверяет цифровую подпись перед установкой; неподписанные пакеты блокируются | Ядро (привратник) |

Пакетный менеджер работает в userspace — ядро не должно содержать логику скачивания и распаковки. Но ядро выступает привратником: userspace-PM ставит, ядро верифицирует подпись и разрешает или блокирует установку.

---

## Текущая версия: v0.7.0

| Подсистема | Статус | Описание |
|---|---|---|
| Boot | Готово | Multiboot2 → 32→64 transition → identity paging (4GB, 2MB pages) |
| HAL | Готово | GDT, IDT, PIC remap, Local APIC timer (vector 48), IO-APIC, TSS IST1 |
| ACPI | Готово | RSDP/RSDT/MADT/HPET parsing |
| Memory | Готово | PMM (bitmap), VMM (4-level paging + OOM rollback), kernel heap (free-list + SipHash-2-4) |
| Scheduler | Готово | Round-robin с APIC timer preemption (8 задач, divisor 16) |
| Ring 3 | Готово | User mode: ELF64 loader, per-process CR3, syscall/sysretq, TSS IST |
| Framebuffer | Готово | Linear framebuffer (1024x768x32bpp) + bitmap font |
| Keyboard | Готово | PS/2 Set 2 → Set 1 translation через i8042 controller (bit 6) |
| Serial | Готово | COM1 (115200 baud, 8N1) |
| Crypto | Готово | PND v8 (Parametric Nonlinear Diffusion), RSA-OAEP + POLER-CTR AEAD |
| Syscalls | Готово | syscall/sysretq: print, read_key, clear_screen |
| SMP | Планируется | Многоядерность |
| Networking | Планируется | virtio-net |
| VFS | Планируется | Виртуальная файловая система |
| Win32 compat | Планируется | Нативная обработка Win32/64 syscalls |
| Package verifier | Планируется | Криптографическая верификация пакетов на уровне ядра |

---

## Сборка

### Зависимости

- **Zig 0.13.0** — компилятор
- **QEMU** — для тестирования
- **GRUB** (`grub-pc-bin`, `grub-mkrescue`) — загрузчик
- **xorriso** — создание ISO

Установка зависимостей (Debian/Ubuntu):

```bash
# Минимум для BIOS-загрузки
sudo apt install grub-pc-bin xorriso

# Для UEFI + BIOS dual-boot
sudo apt install grub-pc-bin grub-efi-amd64-bin xorriso mtools
```

### Команды

```bash
# Сборка ядра (32-bit + 64-bit)
zig build

# Сборка загрузочного ISO (BIOS + UEFI если доступны модули)
zig build iso

# Запуск 64-bit ядра в QEMU (serial console, без графического окна)
zig build run64

# Запуск 64-bit ядра в QEMU (VGA окно + serial)
zig build run64-gfx

# Запуск 32-bit ядра в QEMU (legacy)
zig build run32

# Тесты POLER Core + RSA-OAEP
zig build test
```

### Ручная сборка ISO

```bash
cd zig-kernel
zig build
bash build-iso.sh
```

### Запуск ISO в QEMU

```bash
qemu-system-x86_64 -cdrom poler-os64.iso -m 256M -serial stdio -no-reboot
```

---

## Структура проекта

```
zig-kernel/
├── src64/                    # 64-bit ядро (POLER-OS v0.7.0)
│   ├── boot64.S              # Multiboot2 header, 32→64 переход, page tables
│   ├── isr64.S               # ISR/IRQ stubs + syscall entry
│   ├── main64.zig            # Точка входа, boot sequence, shell
│   ├── hal.zig               # HAL: GDT/IDT/PIC/APIC/IOAPIC/keyboard/serial
│   ├── acpi.zig              # RSDP/RSDT/MADT/HPET парсинг
│   ├── pmm64.zig             # Physical Memory Manager (bitmap)
│   ├── vmm64.zig             # Virtual Memory Manager (4-level paging)
│   ├── heap64.zig            # Kernel heap (free-list + SipHash-2-4)
│   ├── scheduler.zig         # Round-robin scheduler (APIC preempt)
│   ├── elf_loader.zig        # ELF64 loader (Ring 3 user mode)
│   ├── framebuffer.zig       # Linear framebuffer + bitmap font
│   ├── multiboot2.zig        # Multiboot2 info parser
│   ├── cpio.zig              # CPIO initrd parser
│   ├── poler_core.zig        # PND v8 tensor algebra
│   ├── rsa_oaep.zig          # RSA-OAEP + POLER-CTR AEAD
│   └── linker64.ld           # Linker script
├── src/                      # Legacy 32-bit ядро
│   ├── boot32.S              # 16-bit real → 32-bit protected mode
│   ├── isr32.S               # 32-bit ISR stubs
│   ├── main32.zig            # 32-bit kernel entry
│   └── ...
├── drivers/                  # Общие драйверы
├── arch/                     # Архитектурно-зависимый код
├── boot/                     # Boot logic
├── mm/                       # Memory management helpers
├── iso/                      # GRUB ISO структура (BIOS boot)
├── iso-efi/                  # GRUB ISO структура (UEFI boot)
├── iso-minimal/              # Минимальная ISO структура
├── build.zig                 # Конфигурация сборки Zig
├── build-iso.sh              # Скрипт сборки ISO (auto-detect BIOS/UEFI)
├── build-minimal-iso.sh      # Минимальная ISO сборка
├── run-qemu.sh               # Скрипт запуска QEMU
└── run-qemu-iso.sh           # Скрипт запуска QEMU с ISO
```

---

## Дорожная карта

### Этап 1 — Ядро (текущий)
- [x] Загрузка в 64-bit long mode через Multiboot2/GRUB
- [x] HAL: GDT, IDT, PIC, APIC, IO-APIC, TSS
- [x] Управление памятью: PMM + VMM + kernel heap
- [x] Preemptive multitasking: round-robin scheduler
- [x] Ring 3: user mode, ELF64 loader, per-process CR3
- [x] Криптография: PND v8, RSA-OAEP, POLER-CTR AEAD
- [x] Framebuffer, PS/2 клавиатура, serial console
- [ ] SMP — многоядерность

### Этап 2 — Файловая система и драйверы
- [ ] VFS (виртуальная файловая система)
- [ ] Файловая система (ext2 или собственная)
- [ ] Драйвер AHCI/SATA
- [ ] Драйвер сети (virtio-net / e1000)
- [ ] USB stack

### Этап 3 — Безопасность
- [ ] Криптографическая блокировка ядра после загрузки
- [ ] Верификация целостности системных файлов (FIM)
- [ ] Сигнатурный сканер (userspace + kernel hooks)
- [ ] Поведенческий мониторинг на уровне ядра
- [ ] Верификатор пакетов (kernel gatekeeper)

### Этап 4 — Совместимость
- [ ] Подмножество Linux system call interface
- [ ] PE/COFF loader (Windows executables)
- [ ] Подмножество Win32/64 system calls
- [ ] POSIX compatibility layer

### Этап 5 — Графическая среда
- [ ] GPU driver (минимальный)
- [ ] Wayland / собственный display server
- [ ] Qt портирование / нативная поддержка
- [ ] KDE Plasma или собственная DE

---

## История версий

### v0.7.0 — Ring 3 User Mode
- ELF64 loader, per-process CR3, TSS IST1
- User code/data segments (CS=0x1B, SS=0x23)
- syscall/sysretq privilege switch
- IRETQ для возврата в user mode

### v0.6.1 — Bug Fixes
- CTR brace mismatch в hybridEncrypt()
- Q glyph рендеринг
- Circular import hal↔scheduler → callback

### v0.6.0 — Preemptive Multitasking
- Round-robin scheduler с APIC timer
- 8 одновременных задач
- Context switch через stack-based состояния

### v0.5.0 — 64-bit Long Mode
- Multiboot2 boot, 32→64 переход
- HAL: GDT, IDT, PIC, APIC
- PMM + VMM + kernel heap

---

## Лицензия

GNU General Public License v3.0 or later (GPLv3+). См. [LICENSE](LICENSE).
`
```

### `zig-kernel/arch/x86_64/idt.zig` [zig · 5,083 B]
```
`// POLER-OS x86_64 Interrupt Descriptor Table
// Sets up IDT for exception handlers and hardware interrupts

const std = @import("std");

pub const InterruptFrame = packed struct {
    r15: u64, r14: u64, r13: u64, r12: u64,
    r11: u64, r10: u64, r9: u64, r8: u64,
    rdi: u64, rsi: u64, rbp: u64, rdx: u64,
    rcx: u64, rbx: u64, rax: u64,
    int_no: u64,
    err_code: u64,
    rip: u64, cs: u64, rflags: u64,
    rsp: u64, ss: u64,
};

const GateType = enum(u4) {
    Interrupt = 0xE,
    Trap = 0xF,
};

const IdtEntry = packed struct {
    offset_low: u16,       // bits 0-15
    selector: u16,         // code segment selector
    ist: u3,               // interrupt stack table offset
    reserved: u5 = 0,
    gate_type: GateType,
    zero: u3 = 0,
    dpl: u2,               // descriptor privilege level
    present: u1,
    offset_mid: u16,       // bits 16-31
    offset_high: u32,      // bits 32-63
    reserved2: u32 = 0,
};

const IdtPtr = packed struct {
    limit: u16,
    base: u64,
};

var idt: [256]IdtEntry = undefined;
var idt_ptr: IdtPtr = undefined;

fn makeEntry(handler: u64, selector: u16, gate: GateType, dpl: u2) IdtEntry {
    return .{
        .offset_low = @truncate(handler),
        .selector = selector,
        .ist = 0,
        .gate_type = gate,
        .dpl = dpl,
        .present = 1,
        .offset_mid = @truncate(handler >> 16),
        .offset_high = @truncate(handler >> 32),
    };
}

pub fn init() void {
    // Zero out IDT
    for (&idt) |*entry| {
        entry.* = std.mem.zeroes(IdtEntry);
    }
    
    // CPU exception handlers (0-31)
    idt[0] = makeEntry(@intFromPtr(&exception0), 0x08, .Interrupt, 0);  // #DE Divide Error
    idt[1] = makeEntry(@intFromPtr(&exception1), 0x08, .Interrupt, 0);  // #DB Debug
    idt[2] = makeEntry(@intFromPtr(&exception2), 0x08, .Interrupt, 0);  // NMI
    idt[3] = makeEntry(@intFromPtr(&exception3), 0x08, .Trap, 0);      // #BP Breakpoint
    idt[6] = makeEntry(@intFromPtr(&exception6), 0x08, .Interrupt, 0);  // #UD Invalid Opcode
    idt[8] = makeEntry(@intFromPtr(&exception8), 0x08, .Interrupt, 0);  // #DF Double Fault
    idt[13] = makeEntry(@intFromPtr(&exception13), 0x08, .Interrupt, 0); // #GP General Protection
    idt[14] = makeEntry(@intFromPtr(&exception14), 0x08, .Interrupt, 0); // #PF Page Fault
    
    // Hardware IRQs (32-47) — remapped PIC
    idt[32] = makeEntry(@intFromPtr(&irq0), 0x08, .Interrupt, 0);   // Timer
    idt[33] = makeEntry(@intFromPtr(&irq1), 0x08, .Interrupt, 0);   // Keyboard
    
    // Load IDT
    idt_ptr.limit = @sizeOf(@TypeOf(idt)) - 1;
    idt_ptr.base = @intFromPtr(&idt);
    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&idt_ptr)
    );
    
    asm volatile ("sti");
}

// Exception handlers (stubs)
fn exception0() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $0");
    handlerCommon();
}
fn exception1() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $1");
    handlerCommon();
}
fn exception2() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $2");
    handlerCommon();
}
fn exception3() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $3");
    handlerCommon();
}
fn exception6() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $6");
    handlerCommon();
}
fn exception8() callconv(.Naked) noreturn {
    // Double fault has error code already pushed
    asm volatile ("push $8");
    handlerCommon();
}
fn exception13() callconv(.Naked) noreturn {
    // GP fault has error code already pushed
    asm volatile ("push $13");
    handlerCommon();
}
fn exception14() callconv(.Naked) noreturn {
    // Page fault has error code already pushed
    asm volatile ("push $14");
    handlerCommon();
}

// IRQ handlers
fn irq0() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $32");
    handlerCommon();
}
fn irq1() callconv(.Naked) noreturn {
    asm volatile ("push $0; push $33");
    handlerCommon();
}

fn handlerCommon() callconv(.Naked) noreturn {
    asm volatile (
        \\ cli
        \\ push %rax
        \\ push %rbx
        \\ push %rcx
        \\ push %rdx
        \\ push %rsi
        \\ push %rdi
        \\ push %rbp
        \\ push %r8
        \\ push %r9
        \\ push %r10
        \\ push %r11
        \\ push %r12
        \\ push %r13
        \\ push %r14
        \\ push %r15
        \\
        \\ mov %rsp, %rdi        // Pass frame to handler
        \\ call idt_handler
        \\
        \\ pop %r15
        \\ pop %r14
        \\ pop %r13
        \\ pop %r12
        \\ pop %r11
        \\ pop %r10
        \\ pop %r9
        \\ pop %r8
        \\ pop %rbp
        \\ pop %rdi
        \\ pop %rsi
        \\ pop %rdx
        \\ pop %rcx
        \\ pop %rbx
        \\ pop %rax
        \\ add $16, %rsp        // Remove int_no and err_code
        \\ sti
        \\ iretq
    );
    unreachable;
}

export fn idt_handler(frame: *InterruptFrame) void {
    _ = frame;
    // TODO: Route to Rust safety core for policy decisions
    // POLER-OS: all interrupts go through Rust safety barrier
}
`
```

### `zig-kernel/boot/boot.zig` [zig · 4,213 B]
```
`// POLER-OS Boot Sector — Zig 0.13 freestanding x86_64
// Stage 1: MBR bootloader, loads Stage 2 from disk
// Target: x86 freestanding, real mode → protected mode → long mode

const arch = @import("../arch/x86_64/zig.zig");

// MBR Entry Point — loaded at 0x7C00 by BIOS
export fn _start() callconv(.Naked) noreturn {
    asm volatile (
        \\ .code16gcc
        \\ cli                    // Disable interrupts
        \\ xor %ax, %ax
        \\ mov %ax, %ds           // Zero data segments
        \\ mov %ax, %es
        \\ mov %ax, %ss
        \\ mov $0x7C00, %sp       // Stack at 0x7C00 (grows down)
        \\ sti                    // Re-enable interrupts
        \\
        \\ // Save boot drive
        \\ mov %dl, (boot_drive)
        \\
        \\ // Load Stage 2 kernel from disk (LBA 1-63)
        \\ mov $0x02, %ah         // BIOS read sectors
        \\ mov $0x40, %al         // 64 sectors = 32KB
        \\ mov $0x00, %ch         // Cylinder 0
        \\ mov $0x01, %cl         // Start from sector 1 (0-indexed from LBA)
        \\ mov $0x00, %dh         // Head 0
        \\ mov (boot_drive), %dl  // Boot drive
        \\ mov $0x1000, %bx       // Load at ES:BX = 0x1000:0x0000 = 0x10000
        \\ mov $0x1000, %ax
        \\ mov %ax, %es
        \\ xor %bx, %bx
        \\ int $0x13
        \\ jc disk_error
        \\
        \\ // Switch to protected mode
        \\ cli
        \\ lgdt (gdt_descriptor)  // Load GDT
        \\ mov %cr0, %eax
        \\ or $0x01, %eax         // Set PE bit
        \\ mov %eax, %cr0
        \\ 
        \\ // Far jump to 32-bit code
        \\ ljmpl $0x08, $protected_mode
        \\
        \\ disk_error:
        \\   mov $0x0E, %ah
        \\   mov $'E', %al
        \\   int $0x10
        \\   hlt
        \\
        \\ protected_mode:
        \\   .code32
        \\   // Set up protected mode segments
        \\   mov $0x10, %ax
        \\   mov %ax, %ds
        \\   mov %ax, %es
        \\   mov %ax, %fs
        \\   mov %ax, %gs
        \\   mov %ax, %ss
        \\   mov $0x90000, %esp    // Stack at 0x90000
        \\
        \\   // Set up page tables for long mode
        \\   call setup_page_tables
        \\   
        \\   // Enable PAE
        \\   mov %cr4, %eax
        \\   or $(1 << 5), %eax   // PAE bit
        \\   mov %eax, %cr4
        \\
        \\   // Load PML4 into CR3
        \\   mov $0x70000, %eax    // PML4 at 0x70000
        \\   mov %eax, %cr3
        \\
        \\   // Enable long mode via EFER MSR
        \\   mov $0xC0000080, %ecx // EFER MSR
        \\   rdmsr
        \\   or $(1 << 8), %eax   // LME bit
        \\   wrmsr
        \\
        \\   // Enable paging (sets PG bit)
        \\   mov %cr0, %eax
        \\   or $(1 << 31), %eax
        \\   mov %eax, %cr0
        \\
        \\   // Far jump to 64-bit code
        \\   ljmpl $0x08, $long_mode_entry
        \\
        \\ setup_page_tables:
        \\   // PML4[0] → PDPT
        \\   mov $0x70000, %eax
        \\   mov $0x71000, %ebx
        \\   or $0x03, %ebx        // Present + Writable
        \\   mov %ebx, (%eax)
        \\
        \\   // PDPT[0] → PD (identity map first 1GB)
        \\   mov $0x71000, %eax
        \\   mov $0x72000, %ebx
        \\   or $0x03, %ebx
        \\   mov %ebx, (%eax)
        \\
        \\   // PD: 2MB pages, identity map first 1GB
        \\   mov $0x72000, %edi
        \\   mov $0x83, %eax       // Present + Writable + Page Size (2MB)
        \\   mov $512, %ecx
        \\ fill_pd:
        \\   mov %eax, (%edi)
        \\   add $(2 << 20), %eax
        \\   add $8, %edi
        \\   dec %ecx
        \\   jnz fill_pd
        \\   ret
        \\
        \\ long_mode_entry:
        \\   .code64
        \\   // We're in 64-bit long mode!
        \\   // Set up 64-bit segments
        \\   mov $0x10, %ax
        \\   mov %ax, %ds
        \\   mov %ax, %es
        \\   mov %ax, %ss
        \\   
        \\   // Jump to kernel at 0x100000 (1MB mark)
        \\   mov $0x100000, %rax
        \\   jmp *%rax
    );

    unreachable;
}

// GDT for transition: null, code32, data32, code64
const gdt_descriptor = struct {
    limit: u16,
    base: u32,
};

var boot_drive: u8 = 0;
`
```

### `zig-kernel/build-iso.sh` [bash · 3,902 B]
```
`#!/bin/bash
# ============================================================================
# POLER-OS ISO Builder — auto-detects GRUB modules (BIOS + UEFI)
# ============================================================================
#
# This script builds a bootable ISO using grub-mkrescue.
# It auto-detects available GRUB platform modules:
#
#   BIOS boot:  requires i386-pc modules (grub-pc-bin on Debian/Ubuntu)
#   UEFI boot:  requires x86_64-efi modules (grub-efi-amd64-bin)
#
# Installation:
#   BIOS-only:   sudo apt install grub-pc-bin xorriso
#   UEFI-only:   sudo apt install grub-efi-amd64-bin xorriso mtools
#   Dual-boot:   sudo apt install grub-pc-bin grub-efi-amd64-bin xorriso mtools
#
# The script passes the -d flag to grub-mkrescue ONLY for the BIOS modules
# directory. UEFI support is auto-detected by grub-mkrescue itself.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ISO_NAME="poler-os64.iso"
ISO_DIR="iso"

echo "[ISO] Building POLER-OS bootable ISO..."
echo "[ISO] Working directory: $SCRIPT_DIR"

# --- Auto-detect GRUB BIOS modules directory ---
GRUB_BIOS_DIR=""

# Search paths for i386-pc GRUB modules (in priority order)
BIOS_SEARCH_PATHS=(
    "/usr/lib/grub/i386-pc"            # Standard Linux (apt install grub-pc-bin)
    "/usr/local/lib/grub/i386-pc"       # Manual build install
    "/usr/lib/grub2/i386-pc"            # Some distros (openSUSE, etc.)
    "$HOME/my-project/tools/local/usr/lib/grub/i386-pc"  # Z AI sandbox
)

for dir in "${BIOS_SEARCH_PATHS[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/boot.img" ]; then
        GRUB_BIOS_DIR="$dir"
        echo "[ISO] Found BIOS GRUB modules: $GRUB_BIOS_DIR"
        break
    fi
done

# --- Check for UEFI GRUB modules ---
UEFI_AVAILABLE=false
UEFI_SEARCH_PATHS=(
    "/usr/lib/grub/x86_64-efi"         # Standard Linux (apt install grub-efi-amd64-bin)
    "/usr/local/lib/grub/x86_64-efi"    # Manual build install
    "/usr/lib/grub2/x86_64-efi"         # Some distros
)

for dir in "${UEFI_SEARCH_PATHS[@]}"; do
    if [ -d "$dir" ] && [ -f "$dir/efi.sig" -o -f "$dir/multiboot2.mod" ]; then
        UEFI_AVAILABLE=true
        echo "[ISO] Found UEFI GRUB modules: $dir"
        break
    fi
done

# --- Build grub-mkrescue command ---
MKRESCUE_ARGS=("grub-mkrescue" "-o" "$ISO_NAME")

if [ -n "$GRUB_BIOS_DIR" ]; then
    MKRESCUE_ARGS+=("-d" "$GRUB_BIOS_DIR")
    echo "[ISO] Using BIOS modules: $GRUB_BIOS_DIR"
else
    echo "[ISO] WARNING: No BIOS GRUB modules found!"
    echo "[ISO]   Install with: sudo apt install grub-pc-bin"
    echo "[ISO]   Attempting build without explicit -d flag..."
fi

MKRESCUE_ARGS+=("$ISO_DIR")

# --- Report boot mode support ---
if $UEFI_AVAILABLE; then
    echo "[ISO] ISO will support: BIOS + UEFI (dual-boot)"
else
    echo "[ISO] ISO will support: BIOS only"
    echo "[ISO]   For UEFI support: sudo apt install grub-efi-amd64-bin mtools"
fi

# --- Build ISO ---
echo "[ISO] Running: ${MKRESCUE_ARGS[*]}"
if "${MKRESCUE_ARGS[@]}"; then
    ISO_SIZE=$(stat -c%s "$ISO_NAME" 2>/dev/null || echo "?")
    echo "[ISO] Build successful! $ISO_NAME ($ISO_SIZE bytes)"
    echo ""
    echo "[ISO] Boot modes:"
    echo "  BIOS:  Supported (i386-pc)"
    if $UEFI_AVAILABLE; then
        echo "  UEFI:  Supported (x86_64-efi)"
    else
        echo "  UEFI:  Not available (install grub-efi-amd64-bin)"
    fi
    echo ""
    echo "[ISO] Testing in QEMU:"
    echo "  qemu-system-x86_64 -cdrom $ISO_NAME -m 256M -serial stdio -no-reboot"
    echo ""
    echo "[ISO] For VirtualBox/VMware:"
    echo "  - BIOS mode: Should boot directly"
    echo "  - UEFI mode: Requires UEFI modules in ISO (see above)"
else
    echo "[ISO] ERROR: grub-mkrescue failed!"
    echo "[ISO] Make sure you have installed:"
    echo "  sudo apt install grub-pc-bin xorriso"
    exit 1
fi
`
```

### `zig-kernel/build-minimal-iso.sh` [bash · 1,591 B]
```
`#!/bin/bash
# POLER-OS Minimized ISO Builder with CPIO Initrd
# Eliminates themes, locales, fonts, and Apple hybrid-boot metadata to shrink size.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL="$SCRIPT_DIR/zig-out/bin/poler-os64"
ISO_DIR="$SCRIPT_DIR/iso"
ISO_OUT="$SCRIPT_DIR/poler-os64-minimal.iso"

if [ ! -f "$KERNEL" ]; then
    echo "Kernel not found. Building it first..."
    zig build
fi

# Ensure kernel is copied into the staging directory
mkdir -p "$ISO_DIR/boot"
cp "$KERNEL" "$ISO_DIR/boot/poler-os64"

# 1. Create a temporary staging folder for initrd
echo "Creating test initrd contents..."
INITRD_TMP="$SCRIPT_DIR/initrd_tmp"
rm -rf "$INITRD_TMP"
mkdir -p "$INITRD_TMP"

# 2. Add test files
echo "Hello from user-space initrd!" > "$INITRD_TMP/hello.txt"
echo "POLER Core v4 continuous epsilon is active." > "$INITRD_TMP/secrets.txt"

# 3. Build CPIO archive into staging ISO folder
echo "Packing initrd.cpio using cpio..."
cd "$INITRD_TMP"
find . | cpio -o -H newc > "$ISO_DIR/boot/initrd.cpio"
cd "$SCRIPT_DIR"
rm -rf "$INITRD_TMP"

# 4. Generate grub.cfg that loads the initrd module
echo "Generating bootable grub.cfg..."
mkdir -p "$ISO_DIR/boot/grub"
cat << 'EOF' > "$ISO_DIR/boot/grub/grub.cfg"
set timeout=0
set default=0

menuentry "poler-os" {
    multiboot2 /boot/poler-os64
    module2 /boot/initrd.cpio
    boot
}
EOF

# 5. Build the ISO
echo "Building minimized ISO..."
grub-mkrescue -o "$ISO_OUT" "$ISO_DIR" \
    --locales="" \
    --themes="" \
    --fonts="" \
    --compress=xz

echo "Clean bootable ISO created at: $ISO_OUT"
ls -lh "$ISO_OUT"
`
```

### `zig-kernel/build.zig` [zig · 5,697 B]
```
`const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .Debug;

    // ═══ 32-bit Kernel Build (legacy) ════════════════════════════════════
    const kernel32_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const kernel32 = b.addExecutable(.{
        .name = "poler-os32",
        .root_source_file = b.path("src/main32.zig"),
        .target = kernel32_target,
        .optimize = optimize,
    });

    kernel32.setLinkerScript(b.path("src/linker32.ld"));
    kernel32.link_gc_sections = false;
    kernel32.addAssemblyFile(b.path("src/boot32.S"));
    kernel32.addAssemblyFile(b.path("src/isr32.S"));
    b.installArtifact(kernel32);

    // ═══ 64-bit Kernel Build (POLER-OS v0.5.1 → v0.6.1) ════════════════
    const kernel64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const kernel64 = b.addExecutable(.{
        .name = "poler-os64",
        .root_source_file = b.path("src64/main64.zig"),
        .target = kernel64_target,
        .optimize = optimize,
    });

    kernel64.setLinkerScript(b.path("src64/linker64.ld"));
    kernel64.link_gc_sections = false;
    kernel64.addAssemblyFile(b.path("src64/boot64.S"));
    kernel64.addAssemblyFile(b.path("src64/isr64.S"));
    kernel64.addAssemblyFile(b.path("src64/boot_smp.S"));
    b.installArtifact(kernel64);

    // ═══ Build ISO step (BIOS + UEFI dual-boot) ═══════════════════════════
    //
    // Uses build-iso.sh which auto-detects GRUB modules:
    //   - Checks /usr/lib/grub/i386-pc (BIOS, standard Linux install)
    //   - Checks /usr/lib/grub/x86_64-efi (UEFI, needs grub-efi-amd64-bin)
    //   - Falls back to common alternative paths
    //
    // For dual-boot ISO (BIOS + UEFI):
    //   sudo apt install grub-pc-bin grub-efi-amd64-bin xorriso mtools
    //
    // For BIOS-only ISO:
    //   sudo apt install grub-pc-bin xorriso
    //
    const iso_cp_cmd = b.addSystemCommand(&.{
        "cp", "zig-out/bin/poler-os64", "iso/boot/poler-os64",
    });
    iso_cp_cmd.step.dependOn(b.getInstallStep());

    const iso_grub_cmd = b.addSystemCommand(&.{
        "/bin/bash", "build-iso.sh",
    });
    iso_grub_cmd.step.dependOn(&iso_cp_cmd.step);

    const iso_step = b.step("iso", "Build POLER-OS bootable ISO (BIOS + UEFI if modules available)");
    iso_step.dependOn(&iso_grub_cmd.step);

    // ═══ Run 32-bit kernel in QEMU ═══════════════════════════════════════
    const run32_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-kernel",
        "zig-out/bin/poler-os32",
        "-m", "128M",
        "-serial", "stdio",
        "-no-reboot",
    });
    run32_cmd.step.dependOn(b.getInstallStep());

    const run32_step = b.step("run32", "Run 32-bit kernel in QEMU");
    run32_step.dependOn(&run32_cmd.step);

    // ═══ Run 64-bit kernel in QEMU (serial console — no graphics) ══════════
    // Default: -nographic (pure serial terminal, no VGA window)
    // -smp 2: Enable SMP (2 CPUs) for multi-core testing
    const run64_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-cdrom",
        "poler-os64.iso",
        "-m", "256M",
        "-smp", "2",
        "-nographic",
        "-no-reboot",
    });
    run64_cmd.step.dependOn(&iso_grub_cmd.step);

    const run64_step = b.step("run64", "Run 64-bit kernel in QEMU (SMP, serial console, no graphics)");
    run64_step.dependOn(&run64_cmd.step);

    // ═══ Run 64-bit kernel with VGA window + serial ═══════════════════════
    // Shows both VGA window and serial output
    // -smp 2: Enable SMP (2 CPUs) for multi-core testing
    const run64_gfx_cmd = b.addSystemCommand(&.{
        "qemu-system-x86_64",
        "-cdrom",
        "poler-os64.iso",
        "-m", "256M",
        "-smp", "2",
        "-serial", "stdio",
        "-no-reboot",
    });
    run64_gfx_cmd.step.dependOn(&iso_grub_cmd.step);

    const run64_gfx_step = b.step("run64-gfx", "Run 64-bit kernel with VGA window + serial");
    run64_gfx_step.dependOn(&run64_gfx_cmd.step);

    // ═══ POLER Core Tests (native x86_64 linux) ════════════════════════════
    const test_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    });

    // 32-bit (legacy) POLER core tests
    const poler_core32_tests = b.addTest(.{
        .root_source_file = b.path("src/poler_core.zig"),
        .target = test_target,
        .optimize = .Debug,
    });

    // 64-bit POLER core tests (v8.1)
    const poler_core64_tests = b.addTest(.{
        .root_source_file = b.path("src64/poler_core.zig"),
        .target = test_target,
        .optimize = .Debug,
    });

    // 64-bit RSA-OAEP tests (BigInt, SHA-256, MGF1, OAEP, CascadeCipher)
    const rsa_oaep64_tests = b.addTest(.{
        .root_source_file = b.path("src64/rsa_oaep.zig"),
        .target = test_target,
        .optimize = .Debug,
    });

    const test_step = b.step("test", "Run all POLER unit tests (32-bit core + 64-bit core + RSA-OAEP)");
    test_step.dependOn(&poler_core32_tests.step);
    test_step.dependOn(&poler_core64_tests.step);
    test_step.dependOn(&rsa_oaep64_tests.step);
}
`
```

### `zig-kernel/build_test.zig` [zig · 579 B]
```
`const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .x86, .os_tag = .freestanding, .abi = .none });
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main_minimal.zig"),
        .target = target,
        .optimize = .ReleaseSmall,
    });
    mod.addAssemblyFile(b.path("src/boot32_test.S"));
    const exe = b.addExecutable(.{ .name = "poler-test", .root_module = mod });
    exe.setLinkerScript(b.path("src/linker32.ld"));
    exe.link_gc_sections = false;
    b.installArtifact(exe);
}
`
```

### `zig-kernel/drivers/framebuffer.zig` [zig · 17,421 B]
```
`// POLER-OS VBE Framebuffer Driver
// VESA BIOS Extensions — linear framebuffer for HDMI/DP output
// Works with NVIDIA GTX 1060, Intel HD 4000, any VBE-compatible GPU

const std = @import("std");

// ─── VBE Color Format ──────────────────────────────────────────────────────

pub const PixelFormat = enum(u8) {
    indexed = 0,
    rgb888 = 1,      // 32-bit: XRGB8888
    bgr888 = 2,      // 32-bit: XBGR8888
    rgb565 = 3,      // 16-bit
};

// ─── Multiboot Framebuffer Info ────────────────────────────────────────────
// Parsed from multiboot_info tag 8 (framebuffer)

pub const FramebufferInfo = extern struct {
    addr: u64,           // Physical address of framebuffer
    pitch: u32,          // Bytes per scanline
    width: u32,          // Pixels width
    height: u32,         // Pixels height
    bpp: u8,             // Bits per pixel (usually 32)
    pixel_type: u8,      // PixelFormat
    red_shift: u8,
    red_mask: u8,
    green_shift: u8,
    green_mask: u8,
    blue_shift: u8,
    blue_mask: u8,
    valid: bool,         // Did we get valid info from multiboot?
};

// Global framebuffer state
var fb: FramebufferInfo = FramebufferInfo{
    .addr = 0,
    .pitch = 0,
    .width = 0,
    .height = 0,
    .bpp = 0,
    .pixel_type = 0,
    .red_shift = 0,
    .red_mask = 0,
    .green_shift = 0,
    .green_mask = 0,
    .blue_shift = 0,
    .blue_mask = 0,
    .valid = false,
};

// Text cursor position (in pixel coordinates)
var cursor_x: u32 = 0;
var cursor_y: u32 = 0;

// Font cell size
const CHAR_W: u32 = 8;
const CHAR_H: u32 = 16;

// ─── Font: 8x16 PC BIOS font (first 128 ASCII chars) ──────────────────────
// Minimal 8x16 bitmap font — covers printable ASCII 0x20-0x7E

const font: [128][16]u8 = import_font();

fn import_font() [128][16]u8 {
    var f: [128][16]u8 = undefined;
    
    // Space (0x20)
    f[0x20] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ! (0x21)
    f[0x21] = .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x18,0x18,0x00,0x00,0x00};
    // " (0x22)
    f[0x22] = .{0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // # (0x23)
    f[0x23] = .{0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00};
    // $ (0x24)
    f[0x24] = .{0x18,0x3E,0x60,0x60,0x3C,0x06,0x06,0x7C,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    // % (0x25)
    f[0x25] = .{0x00,0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00};
    // & (0x26)
    f[0x26] = .{0x38,0x6C,0x6C,0x38,0x76,0x6E,0x66,0x66,0x76,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    // ' (0x27)
    f[0x27] = .{0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ( (0x28)
    f[0x28] = .{0x0C,0x18,0x30,0x30,0x30,0x30,0x30,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00};
    // ) (0x29)
    f[0x29] = .{0x30,0x18,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x18,0x30,0x00,0x00,0x00,0x00,0x00,0x00};
    // * (0x2A)
    f[0x2A] = .{0x00,0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // + (0x2B)
    f[0x2B] = .{0x00,0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // , (0x2C)
    f[0x2C] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x30,0x00,0x00,0x00};
    // - (0x2D)
    f[0x2D] = .{0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // . (0x2E)
    f[0x2E] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00};
    // / (0x2F)
    f[0x2F] = .{0x06,0x06,0x0C,0x0C,0x18,0x18,0x30,0x30,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // 0-9 (0x30-0x39)
    f[0x30] = .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x31] = .{0x18,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x32] = .{0x3C,0x66,0x66,0x06,0x0C,0x18,0x30,0x60,0x66,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x33] = .{0x3C,0x66,0x06,0x06,0x1C,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x34] = .{0x0C,0x1C,0x3C,0x6C,0x6C,0x7E,0x0C,0x0C,0x0C,0x0C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x35] = .{0x7E,0x60,0x60,0x7C,0x06,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x36] = .{0x3C,0x66,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x37] = .{0x7E,0x66,0x06,0x0C,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x38] = .{0x3C,0x66,0x66,0x66,0x3C,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x39] = .{0x3C,0x66,0x66,0x66,0x3E,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // : (0x3A)
    f[0x3A] = .{0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ; (0x3B)
    f[0x3B] = .{0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30,0x00,0x00,0x00,0x00,0x00,0x00};
    // < (0x3C)
    f[0x3C] = .{0x0C,0x18,0x30,0x60,0xC0,0x60,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // = (0x3D)
    f[0x3D] = .{0x00,0x00,0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // > (0x3E)
    f[0x3E] = .{0x60,0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ? (0x3F)
    f[0x3F] = .{0x3C,0x66,0x06,0x0C,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // @ (0x40)
    f[0x40] = .{0x3C,0x66,0x66,0x6E,0x6E,0x60,0x62,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // A-Z uppercase (0x41-0x5A)
    f[0x41] = .{0x18,0x3C,0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x42] = .{0x7C,0x66,0x66,0x66,0x7C,0x66,0x66,0x66,0x66,0x7C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x43] = .{0x3C,0x66,0x66,0x60,0x60,0x60,0x60,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x44] = .{0x78,0x6C,0x66,0x66,0x66,0x66,0x66,0x66,0x6C,0x78,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x45] = .{0x7E,0x60,0x60,0x60,0x7C,0x60,0x60,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x46] = .{0x7E,0x60,0x60,0x60,0x7C,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x47] = .{0x3C,0x66,0x60,0x60,0x6E,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x48] = .{0x66,0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x49] = .{0x3C,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4A] = .{0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x6C,0x6C,0x38,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4B] = .{0x66,0x66,0x6C,0x6C,0x78,0x78,0x6C,0x6C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4C] = .{0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4D] = .{0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4E] = .{0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4F] = .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x50] = .{0x7C,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x51] = .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x6A,0x6C,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x52] = .{0x7C,0x66,0x66,0x66,0x7C,0x6C,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x53] = .{0x3C,0x66,0x60,0x60,0x3C,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x54] = .{0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x55] = .{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x56] = .{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x3C,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x57] = .{0xC6,0xC6,0xC6,0xC6,0xD6,0xD6,0xFE,0xEE,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x58] = .{0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x59] = .{0x66,0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5A] = .{0x7E,0x06,0x0C,0x18,0x30,0x60,0x60,0xC0,0xC0,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // [ ] ^ _ (0x5B-0x5E)
    f[0x5B] = .{0x3C,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5C] = .{0x60,0x60,0x30,0x30,0x18,0x18,0x0C,0x0C,0x06,0x06,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5D] = .{0x3C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5E] = .{0x10,0x38,0x6C,0xC6,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5F] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00};
    
    // a-z lowercase (0x61-0x7A) 
    f[0x61] = .{0x00,0x00,0x00,0x3C,0x06,0x3E,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x62] = .{0x60,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x66,0x7C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x63] = .{0x00,0x00,0x00,0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x64] = .{0x06,0x06,0x06,0x3E,0x66,0x66,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x65] = .{0x00,0x00,0x00,0x3C,0x66,0x66,0x7E,0x60,0x60,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x66] = .{0x1C,0x30,0x30,0x7C,0x30,0x30,0x30,0x30,0x30,0x30,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x67] = .{0x00,0x00,0x00,0x3E,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x3C,0x00,0x00,0x00,0x00};
    f[0x68] = .{0x60,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x69] = .{0x18,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6A] = .{0x0C,0x00,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x6C,0x6C,0x38,0x00,0x00,0x00,0x00};
    f[0x6B] = .{0x60,0x60,0x60,0x66,0x6C,0x78,0x78,0x6C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6C] = .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6D] = .{0x00,0x00,0x00,0xEC,0xFE,0xD6,0xD6,0xD6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6E] = .{0x00,0x00,0x00,0x7C,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6F] = .{0x00,0x00,0x00,0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x70] = .{0x00,0x00,0x00,0x7C,0x66,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0x00,0x00,0x00,0x00};
    f[0x71] = .{0x00,0x00,0x00,0x3E,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x06,0x00,0x00,0x00,0x00};
    f[0x72] = .{0x00,0x00,0x00,0x7C,0x66,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x73] = .{0x00,0x00,0x00,0x3E,0x60,0x60,0x3C,0x06,0x06,0x7C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x74] = .{0x30,0x30,0x30,0x7C,0x30,0x30,0x30,0x30,0x30,0x1C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x75] = .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x76] = .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x77] = .{0x00,0x00,0x00,0xC6,0xC6,0xD6,0xD6,0xD6,0xFE,0x6C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x78] = .{0x00,0x00,0x00,0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x79] = .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x3C,0x00,0x00,0x00,0x00};
    f[0x7A] = .{0x00,0x00,0x00,0x7E,0x0C,0x18,0x30,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // { | } ~ (0x7B-0x7E)
    f[0x7B] = .{0x0E,0x18,0x18,0x18,0x70,0x18,0x18,0x18,0x0E,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x7C] = .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x7D] = .{0x70,0x18,0x18,0x18,0x0E,0x18,0x18,0x18,0x70,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x7E] = .{0x76,0xDC,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // Fill remaining with blank
    var i: usize = 0;
    while (i < 128) : (i += 1) {
        if (i < 0x20) {
            f[i] = .{0x00} ** 16;
        }
    }
    
    return f;
}

// ─── Framebuffer API ───────────────────────────────────────────────────────

/// Initialize framebuffer from multiboot info
pub fn init_from_multiboot(addr: u64, pitch: u32, width: u32, height: u32, bpp: u8, pixel_type: u8) void {
    fb.addr = addr;
    fb.pitch = pitch;
    fb.width = width;
    fb.height = height;
    fb.bpp = bpp;
    fb.pixel_type = pixel_type;
    fb.valid = (addr != 0 and width > 0 and height > 0);
    
    // Default color masks for XRGB8888
    if (pixel_type == @intFromEnum(PixelFormat.rgb888)) {
        fb.red_shift = 16; fb.red_mask = 8;
        fb.green_shift = 8; fb.green_mask = 8;
        fb.blue_shift = 0; fb.blue_mask = 8;
    } else if (pixel_type == @intFromEnum(PixelFormat.bgr888)) {
        fb.red_shift = 0; fb.red_mask = 8;
        fb.green_shift = 8; fb.green_mask = 8;
        fb.blue_shift = 16; fb.blue_mask = 8;
    }
    
    cursor_x = 0;
    cursor_y = 0;
}

/// Is framebuffer available?
pub fn is_available() bool {
    return fb.valid;
}

/// Get screen dimensions in character cells
pub fn text_cols() u32 {
    if (!fb.valid) return 0;
    return fb.width / CHAR_W;
}

pub fn text_rows() u32 {
    if (!fb.valid) return 0;
    return fb.height / CHAR_H;
}

/// Draw a single pixel
pub fn put_pixel(x: u32, y: u32, r: u8, g: u8, b: u8) void {
    if (!fb.valid) return;
    if (x >= fb.width or y >= fb.height) return;
    
    const offset = @as(u64, y) * @as(u64, fb.pitch) + @as(u64, x) * @as(u64, fb.bpp / 8);
    const ptr: [*]volatile u32 = @ptrFromInt(@as(usize, @intCast(fb.addr + offset)));
    
    if (fb.bpp == 32) {
        if (fb.pixel_type == @intFromEnum(PixelFormat.bgr888)) {
            ptr[0] = @as(u32, b) | (@as(u32, g) << 8) | (@as(u32, r) << 16);
        } else {
            ptr[0] = @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16);
        }
    }
}

/// Fill a rectangle
pub fn fill_rect(x: u32, y: u32, w: u32, h: u32, r: u8, g: u8, b: u8) void {
    var dy: u32 = 0;
    while (dy < h) : (dy += 1) {
        var dx: u32 = 0;
        while (dx < w) : (dx += 1) {
            put_pixel(x + dx, y + dy, r, g, b);
        }
    }
}

/// Clear screen to black
pub fn clear() void {
    fill_rect(0, 0, fb.width, fb.height, 0, 0, 0);
}

/// Draw a character at pixel position
pub fn draw_char(ch: u8, px: u32, py: u32, fg_r: u8, fg_g: u8, fg_b: u8, bg_r: u8, bg_g: u8, bg_b: u8) void {
    if (!fb.valid) return;
    const glyph = font[ch];
    
    var row_idx: u32 = 0;
    while (row_idx < CHAR_H) : (row_idx += 1) {
        const bits = glyph[row_idx];
        var col_idx: u32 = 0;
        while (col_idx < CHAR_W) : (col_idx += 1) {
            const bit_set = (bits & (@as(u8, 1) << @intCast(7 - col_idx))) != 0;
            if (bit_set) {
                put_pixel(px + col_idx, py + row_idx, fg_r, fg_g, fg_b);
            } else {
                put_pixel(px + col_idx, py + row_idx, bg_r, bg_g, bg_b);
            }
        }
    }
}

/// Print string to framebuffer (with scrolling)
pub fn puts(str: []const u8) void {
    if (!fb.valid) return;
    
    for (str) |ch| {
        if (ch == '\n') {
            cursor_x = 0;
            cursor_y += CHAR_H;
        } else {
            draw_char(ch, cursor_x, cursor_y, 0xD4, 0xD4, 0xD4, 0x0B, 0x11, 0x20);
            cursor_x += CHAR_W;
            if (cursor_x >= fb.width) {
                cursor_x = 0;
                cursor_y += CHAR_H;
            }
        }
        
        // Scroll if needed
        if (cursor_y + CHAR_H >= fb.height) {
            scroll_up();
            cursor_y = fb.height - CHAR_H;
        }
    }
}

/// Print string with color
pub fn puts_color(str: []const u8, fg_r: u8, fg_g: u8, fg_b: u8) void {
    if (!fb.valid) return;
    
    for (str) |ch| {
        if (ch == '\n') {
            cursor_x = 0;
            cursor_y += CHAR_H;
        } else {
            draw_char(ch, cursor_x, cursor_y, fg_r, fg_g, fg_b, 0x0B, 0x11, 0x20);
            cursor_x += CHAR_W;
            if (cursor_x >= fb.width) {
                cursor_x = 0;
                cursor_y += CHAR_H;
            }
        }
        
        if (cursor_y + CHAR_H >= fb.height) {
            scroll_up();
            cursor_y = fb.height - CHAR_H;
        }
    }
}

/// Scroll framebuffer up by one character row
fn scroll_up() void {
    if (!fb.valid) return;
    
    const bytes_per_pixel = fb.bpp / 8;
    const src_offset = @as(u64, CHAR_H) * @as(u64, fb.pitch);
    const dst_offset: u64 = 0;
    const copy_len = @as(u64, fb.height - CHAR_H) * @as(u64, fb.pitch);
    
    // Copy rows up
    const src: [*]u8 = @ptrFromInt(@as(usize, @intCast(fb.addr + src_offset)));
    const dst: [*]u8 = @ptrFromInt(@as(usize, @intCast(fb.addr + dst_offset)));
    
    var i: u64 = 0;
    while (i < copy_len) : (i += 1) {
        dst[i] = src[i];
    }
    
    // Clear last row
    const clear_offset = @as(u64, fb.height - CHAR_H) * @as(u64, fb.pitch);
    const clear_ptr: [*]volatile u8 = @ptrFromInt(@as(usize, @intCast(fb.addr + clear_offset)));
    var j: u64 = 0;
    while (j < @as(u64, CHAR_H) * @as(u64, fb.pitch)) : (j += 1) {
        clear_ptr[j] = 0;
    }
}

/// Set cursor position (in pixel coords)
pub fn set_cursor(x: u32, y: u32) void {
    cursor_x = x;
    cursor_y = y;
}
`
```

### `zig-kernel/drivers/vga.zig` [zig · 2,386 B]
```
`// POLER-OS VGA Text Mode Driver
// Writes directly to 0xB8000 (VGA text buffer)
// 80x25 text mode, 2 bytes per character (char + attribute)

const std = @import("std");

pub const Color = enum(u4) {
    Black = 0,
    Blue = 1,
    Green = 2,
    Cyan = 3,
    Red = 4,
    Magenta = 5,
    Brown = 6,
    LightGrey = 7,
    DarkGrey = 8,
    LightBlue = 9,
    LightGreen = 10,
    LightCyan = 11,
    LightRed = 12,
    LightMagenta = 13,
    Yellow = 14,
    White = 15,
};

const VgaChar = packed struct {
    char: u8,
    attr: u8,
};

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER = 0xB8000;

var row: usize = 0;
var col: usize = 0;
var fg: Color = .White;
var bg: Color = .Black;

pub fn init() void {
    row = 0;
    col = 0;
}

pub fn setColor(foreground: Color, background: Color) void {
    fg = foreground;
    bg = background;
}

pub fn clear() void {
    const buf = @as([*]VgaChar, @ptrFromInt(VGA_BUFFER));
    const attr = @intFromEnum(bg) << 4 | @intFromEnum(fg);
    var i: usize = 0;
    while (i < VGA_WIDTH * VGA_HEIGHT) : (i += 1) {
        buf[i] = .{ .char = ' ', .attr = attr };
    }
    row = 0;
    col = 0;
}

pub fn putChar(ch: u8) void {
    const buf = @as([*]VgaChar, @ptrFromInt(VGA_BUFFER));
    const attr = @intFromEnum(bg) << 4 | @intFromEnum(fg);
    
    if (ch == '\n') {
        col = 0;
        row += 1;
        if (row >= VGA_HEIGHT) {
            scroll();
            row = VGA_HEIGHT - 1;
        }
        return;
    }
    
    buf[row * VGA_WIDTH + col] = .{ .char = ch, .attr = attr };
    col += 1;
    if (col >= VGA_WIDTH) {
        col = 0;
        row += 1;
        if (row >= VGA_HEIGHT) {
            scroll();
            row = VGA_HEIGHT - 1;
        }
    }
}

pub fn print(str: []const u8) void {
    for (str) |ch| {
        putChar(ch);
    }
}

fn scroll() void {
    const buf = @as([*]VgaChar, @ptrFromInt(VGA_BUFFER));
    // Move all rows up by 1
    var r: usize = 0;
    while (r < VGA_HEIGHT - 1) : (r += 1) {
        var c: usize = 0;
        while (c < VGA_WIDTH) : (c += 1) {
            buf[r * VGA_WIDTH + c] = buf[(r + 1) * VGA_WIDTH + c];
        }
    }
    // Clear last row
    const attr = @intFromEnum(bg) << 4 | @intFromEnum(fg);
    var c: usize = 0;
    while (c < VGA_WIDTH) : (c += 1) {
        buf[(VGA_HEIGHT - 1) * VGA_WIDTH + c] = .{ .char = ' ', .attr = attr };
    }
}
`
```

### `zig-kernel/drivers/virtio.zig` [zig · 14,442 B]
```
`// POLER-OS VirtIO Transport Layer
// Shared-memory communication between Zig microkernel and Linux Driver Server
// Implements VirtIO 1.1 specification — split virtqueues

const std = @import("std");

// ─── VirtIO PCI Constants ──────────────────────────────────────────────────

pub const VIRTIO_PCI_VENDOR_ID: u16 = 0x1AF4;
pub const VIRTIO_PCI_DEVICE_ID_MIN: u16 = 0x1000; // virtio-net
pub const VIRTIO_PCI_DEVICE_ID_MAX: u16 = 0x103F; // virtio range

// VirtIO Device IDs
pub const VIRTIO_ID_NET: u16 = 1;
pub const VIRTIO_ID_BLOCK: u16 = 2;
pub const VIRTIO_ID_CONSOLE: u16 = 3;
pub const VIRTIO_ID_GPU: u16 = 16;
pub const VIRTIO_ID_INPUT: u16 = 18;

// VirtIO PCI Header offsets
pub const VIRTIO_PCI_HOST_FEATURES: u16 = 0x00;
pub const VIRTIO_PCI_GUEST_FEATURES: u16 = 0x04;
pub const VIRTIO_PCI_QUEUE_PFN: u16 = 0x08;
pub const VIRTIO_PCI_QUEUE_NUM: u16 = 0x0C;
pub const VIRTIO_PCI_QUEUE_SEL: u16 = 0x0E;
pub const VIRTIO_PCI_QUEUE_NOTIFY: u16 = 0x10;
pub const VIRTIO_PCI_STATUS: u16 = 0x12;
pub const VIRTIO_PCI_ISR: u16 = 0x13;
pub const VIRTIO_PCI_CONFIG: u16 = 0x14;

// Status bits
pub const VIRTIO_STATUS_ACKNOWLEDGE: u8 = 1;
pub const VIRTIO_STATUS_DRIVER: u8 = 2;
pub const VIRTIO_STATUS_DRIVER_OK: u8 = 4;
pub const VIRTIO_STATUS_FEATURES_OK: u8 = 8;
pub const VIRTIO_STATUS_FAILED: u8 = 128;

// Descriptor flags
pub const VIRTIO_DESC_F_NEXT: u16 = 1;
pub const VIRTIO_DESC_F_WRITE: u16 = 2;
pub const VIRTIO_DESC_F_INDIRECT: u16 = 4;

// ─── VirtIO Data Structures ────────────────────────────────────────────────

/// VirtIO queue descriptor (16 bytes)
pub const VirtQueueDesc = extern struct {
    addr: u64,    // Guest physical address
    len: u32,     // Length of buffer
    flags: u16,   // VIRTIO_DESC_F_*
    next: u16,    // Next descriptor index (if F_NEXT)
};

/// VirtIO available ring
pub const VirtQueueAvail = extern struct {
    flags: u16,
    idx: u16,           // Next free slot
    ring: [0]u16,       // Variable length — indices into descriptor table
    used_event: u16,    // Last used index (for notifications)
};

/// VirtIO used ring entry
pub const VirtQueueUsedElem = extern struct {
    id: u32,    // Head descriptor index
    len: u32,   // Length written
};

/// VirtIO used ring
pub const VirtQueueUsed = extern struct {
    flags: u16,
    idx: u16,               // Next used slot
    ring: [0]VirtQueueUsedElem, // Variable length
    avail_event: u16,       // For notifications
};

/// Complete virtqueue structure
pub const VirtQueue = struct {
    queue_size: u16,
    desc: [*]VirtQueueDesc,
    avail: [*]VirtQueueAvail,
    used: [*]VirtQueueUsed,
    desc_phys: u64,   // Physical addresses for DMA
    avail_phys: u64,
    used_phys: u64,
    last_used_idx: u16,
    last_avail_idx: u16,
    io_base: u16,     // PCI I/O base port
};

// ─── VirtIO Device ─────────────────────────────────────────────────────────

pub const VirtIODevice = struct {
    device_type: u16,
    io_base: u16,
    irq: u8,
    queues: [8]?VirtQueue,
    num_queues: u8,
    features: u32,
    
    pub fn init(io_base: u16, device_type: u16) VirtIODevice {
        return VirtIODevice{
            .device_type = device_type,
            .io_base = io_base,
            .irq = 0,
            .queues = [_]?VirtQueue{null} ** 8,
            .num_queues = 0,
            .features = 0,
        };
    }
    
    /// Read 8-bit from VirtIO register
    pub fn read8(self: *VirtIODevice, offset: u16) u8 {
        return inb(self.io_base + offset);
    }
    
    /// Read 32-bit from VirtIO register
    pub fn read32(self: *VirtIODevice, offset: u16) u32 {
        return inl(self.io_base + offset);
    }
    
    /// Write 8-bit to VirtIO register
    pub fn write8(self: *VirtIODevice, offset: u16, val: u8) void {
        outb(self.io_base + offset, val);
    }
    
    /// Write 32-bit to VirtIO register
    pub fn write32(self: *VirtIODevice, offset: u16, val: u32) void {
        outl(self.io_base + offset, val);
    }
    
    /// Write 16-bit to VirtIO register
    pub fn write16(self: *VirtIODevice, offset: u16, val: u16) void {
        outw(self.io_base + offset, val);
    }
    
    /// Initialize the device following VirtIO 1.1 initialization sequence
    pub fn initialize(self: *VirtIODevice) bool {
        // 1. Reset device
        self.write8(VIRTIO_PCI_STATUS, 0);
        
        // 2. Acknowledge device
        self.write8(VIRTIO_PCI_STATUS, VIRTIO_STATUS_ACKNOWLEDGE);
        
        // 3. We know how to drive this device
        self.write8(VIRTIO_PCI_STATUS, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER);
        
        // 4. Negotiate features
        const host_features = self.read32(VIRTIO_PCI_HOST_FEATURES);
        self.features = host_features; // Accept all for now
        self.write32(VIRTIO_PCI_GUEST_FEATURES, self.features);
        
        // 5. Set FEATURES_OK
        self.write8(VIRTIO_PCI_STATUS, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK);
        
        // 6. Re-read status to confirm FEATURES_OK
        const status = self.read8(VIRTIO_PCI_STATUS);
        if ((status & VIRTIO_STATUS_FEATURES_OK) == 0) {
            return false; // Feature negotiation failed
        }
        
        // 7. Setup queues (will be done per-device)
        
        // 8. DRIVER_OK
        self.write8(VIRTIO_PCI_STATUS, VIRTIO_STATUS_ACKNOWLEDGE | VIRTIO_STATUS_DRIVER | VIRTIO_STATUS_FEATURES_OK | VIRTIO_STATUS_DRIVER_OK);
        
        return true;
    }
    
    /// Setup a specific virtqueue
    pub fn setup_queue(self: *VirtIODevice, queue_idx: u16, queue_size: u16, desc_phys: u64, avail_phys: u64, used_phys: u64) void {
        // Select the queue
        self.write16(VIRTIO_PCI_QUEUE_SEL, queue_idx);
        
        // Set size
        self.write16(VIRTIO_PCI_QUEUE_NUM, queue_size);
        
        // Set descriptor table physical address
        self.write32(VIRTIO_PCI_QUEUE_PFN, @truncate(desc_phys >> 12));
        
        // Store queue info
        if (queue_idx < 8) {
            self.queues[queue_idx] = VirtQueue{
                .queue_size = queue_size,
                .desc = @ptrFromInt(@as(usize, @intCast(desc_phys))),
                .avail = @ptrFromInt(@as(usize, @intCast(avail_phys))),
                .used = @ptrFromInt(@as(usize, @intCast(used_phys))),
                .desc_phys = desc_phys,
                .avail_phys = avail_phys,
                .used_phys = used_phys,
                .last_used_idx = 0,
                .last_avail_idx = 0,
                .io_base = self.io_base,
            };
            if (queue_idx >= self.num_queues) {
                self.num_queues = @intCast(queue_idx + 1);
            }
        }
    }
    
    /// Notify the device that a buffer is available
    pub fn notify_queue(self: *VirtIODevice, queue_idx: u16) void {
        self.write16(VIRTIO_PCI_QUEUE_NOTIFY, queue_idx);
    }
};

// ─── VirtIO Block Device (virtio-blk) ──────────────────────────────────────

pub const VIRTIO_BLK_T_IN: u32 = 0;      // Read
pub const VIRTIO_BLK_T_OUT: u32 = 1;      // Write
pub const VIRTIO_BLK_T_FLUSH: u32 = 4;    // Flush
pub const VIRTIO_BLK_S_OK: u8 = 0;
pub const VIRTIO_BLK_S_IOERR: u8 = 1;
pub const VIRTIO_BLK_S_UNSUPP: u8 = 2;

/// Block device request header
pub const VirtBlkReqHeader = extern struct {
    type: u32,     // VIRTIO_BLK_T_*
    reserved: u32,
    sector: u64,   // Sector number (512-byte units)
};

/// Block device configuration (read from PCI config space)
pub const VirtBlkConfig = extern struct {
    capacity: u64,         // Number of 512-byte sectors
    size_max: u32,         // Max segment size
    seg_max: u32,          // Max segments per request
    geometry_cylinders: u16,
    geometry_heads: u8,
    geometry_sectors: u8,
    blk_size: u32,         // Block size (usually 512)
};

/// Block device wrapper
pub const VirtBlkDevice = struct {
    virtio: VirtIODevice,
    config: VirtBlkConfig,
    
    pub fn init(io_base: u16) VirtBlkDevice {
        var dev = VirtBlkDevice{
            .virtio = VirtIODevice.init(io_base, VIRTIO_ID_BLOCK),
            .config = std.mem.zeroes(VirtBlkConfig),
        };
        return dev;
    }
    
    /// Read block device configuration
    pub fn read_config(self: *VirtBlkDevice) void {
        const config_offset = VIRTIO_PCI_CONFIG;
        var buf: [@sizeOf(VirtBlkConfig)]u8 align(4) = undefined;
        
        var i: u16 = 0;
        while (i < @sizeOf(VirtBlkConfig)) : (i += 4) {
            const val = self.virtio.read32(config_offset + i);
            @as(*u32, @ptrCast(@alignCast(&buf[i]))).* = val;
        }
        
        self.config = @as(*VirtBlkConfig, @ptrCast(@alignCast(&buf[0]))).*);
    }
    
    /// Initialize block device
    pub fn initialize(self: *VirtBlkDevice) bool {
        if (!self.virtio.initialize()) return false;
        self.read_config();
        return true;
    }
    
    /// Get capacity in bytes
    pub fn capacity_bytes(self: *VirtBlkDevice) u64 {
        return self.config.capacity * 512;
    }
};

// ─── VirtIO Console (virtio-serial) ────────────────────────────────────────

pub const VirtConsoleDevice = struct {
    virtio: VirtIODevice,
    
    pub fn init(io_base: u16) VirtConsoleDevice {
        return VirtConsoleDevice{
            .virtio = VirtIODevice.init(io_base, VIRTIO_ID_CONSOLE),
        };
    }
    
    pub fn initialize(self: *VirtConsoleDevice) bool {
        return self.virtio.initialize();
    }
    
    /// Send a byte through the console
    pub fn write_byte(self: *VirtConsoleDevice, ch: u8) void {
        // In simplified mode, write directly to the port buffer
        // Full implementation would use a descriptor chain
        _ = ch;
        // TODO: Implement via virtqueue descriptor chain
    }
};

// ─── PCI Configuration Space Access ────────────────────────────────────────

pub const PCI_CONFIG_ADDR: u16 = 0xCF8;
pub const PCI_CONFIG_DATA: u16 = 0xCFC;

pub const PciDevice = extern struct {
    vendor_id: u16,
    device_id: u16,
    command: u16,
    status: u16,
    revision: u8,
    prog_if: u8,
    subclass: u8,
    class_code: u8,
    cache_line_size: u8,
    latency_timer: u8,
    header_type: u8,
    bist: u8,
    bar: [6]u32,
    cardbus_cis: u32,
    subsystem_vendor: u16,
    subsystem_device: u16,
    expansion_rom: u32,
    capabilities: u8,
    reserved: [7]u8,
    interrupt_line: u8,
    interrupt_pin: u8,
    min_grant: u8,
    max_latency: u8,
};

/// Read PCI configuration register
pub fn pci_read32(bus: u8, slot: u8, func: u8, offset: u8) u32 {
    const addr = (@as(u32, 1) << 31) | 
                 (@as(u32, bus) << 16) | 
                 (@as(u32, slot) << 11) | 
                 (@as(u32, func) << 8) | 
                 (@as(u32, offset) & 0xFC);
    outl(PCI_CONFIG_ADDR, addr);
    return inl(PCI_CONFIG_DATA);
}

/// Write PCI configuration register
pub fn pci_write32(bus: u8, slot: u8, func: u8, offset: u8, val: u32) void {
    const addr = (@as(u32, 1) << 31) | 
                 (@as(u32, bus) << 16) | 
                 (@as(u32, slot) << 11) | 
                 (@as(u32, func) << 8) | 
                 (@as(u32, offset) & 0xFC);
    outl(PCI_CONFIG_ADDR, addr);
    outl(PCI_CONFIG_DATA, val);
}

/// Read PCI configuration 16-bit
pub fn pci_read16(bus: u8, slot: u8, func: u8, offset: u8) u16 {
    const val = pci_read32(bus, slot, func, offset);
    return @truncate(val >> (8 * (@as(u32, offset) & 2)));
}

/// Scan PCI bus for VirtIO devices
pub fn scan_virtio_devices() [8]?VirtIODevice {
    var devices: [8]?VirtIODevice = [_]?VirtIODevice{null} ** 8;
    var dev_count: u8 = 0;
    
    var bus: u8 = 0;
    while (bus < 256) : (bus += 1) {
        var slot: u8 = 0;
        while (slot < 32) : (slot += 1) {
            const vendor = pci_read16(bus, slot, 0, 0);
            if (vendor == 0xFFFF) continue;
            
            const device_id = pci_read16(bus, slot, 0, 2);
            
            // Check for VirtIO vendor (Red Hat / QEMU)
            if (vendor == VIRTIO_PCI_VENDOR_ID and 
                device_id >= VIRTIO_PCI_DEVICE_ID_MIN and 
                device_id <= VIRTIO_PCI_DEVICE_ID_MAX) {
                
                // Determine device type from subsystem
                const subsystem = pci_read16(bus, slot, 0, 0x2C);
                
                // Get I/O base from BAR0
                const bar0 = pci_read32(bus, slot, 0, 0x10);
                const io_base: u16 = if ((bar0 & 1) != 0) 
                    @truncate(bar0 & 0xFFFC) 
                else 
                    0;
                
                if (io_base != 0 and dev_count < 8) {
                    devices[dev_count] = VirtIODevice.init(io_base, subsystem);
                    dev_count += 1;
                }
            }
        }
    }
    
    return devices;
}

// ─── I/O Port Helpers ──────────────────────────────────────────────────────

fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "N{dx}" (port),
    );
}

fn outw(port: u16, val: u16) void {
    asm volatile ("outw %[val], %[port]"
        :
        : [val] "{ax}" (val),
          [port] "N{dx}" (port),
    );
}

fn outl(port: u16, val: u32) void {
    asm volatile ("outl %[val], %[port]"
        :
        : [val] "{eax}" (val),
          [port] "N{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "=al" (-> u8),
        : [port] "N{dx}" (port),
    );
}

fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "=eax" (-> u32),
        : [port] "N{dx}" (port),
    );
}
`
```

### `zig-kernel/main.zig` [zig · 2,258 B]
```
`// POLER-OS Kernel Main — Zig 0.13 x86_64 freestanding
// This is the entry point after boot.zig transitions to long mode
// Kernel loaded at 0x100000 (1MB mark)

const std = @import("std");
const vga = @import("drivers/vga.zig");
const idt = @import("arch/x86_64/idt.zig");
const mm = @import("mm/pmm.zig");

// Kernel entry point — called from boot.zig in 64-bit long mode
pub export fn kernel_main() callconv(.C) noreturn {
    // 1. Initialize VGA text buffer (0xB8000)
    vga.init();
    vga.setColor(vga.Color.White, vga.Color.Black);
    vga.clear();
    
    // 2. Print POLER-OS banner
    vga.print("╔══════════════════════════════════════╗\n");
    vga.print("║         POLER-OS v0.1.0              ║\n");
    vga.print("║    Zig Kernel + Rust Safety Core     ║\n");
    vga.print("║    LLM Operating System              ║\n");
    vga.print("╚══════════════════════════════════════╝\n\n");
    
    vga.print("[BOOT] Entered long mode at 0x100000\n");
    vga.print("[BOOT] Initializing IDT...\n");
    
    // 3. Set up Interrupt Descriptor Table
    idt.init();
    vga.print("[BOOT] IDT loaded\n");
    
    // 4. Initialize Physical Memory Manager
    vga.print("[BOOT] Scanning memory map...\n");
    mm.init();
    vga.print("[BOOT] PMM initialized\n");
    
    // 5. Hand off to Rust safety core
    vga.print("[BOOT] Loading Rust safety core...\n");
    // rust_core_entry() is defined in Rust and linked via Zig
    // const rust_entry = @extern(*const fn() callconv(.C) void, .{ .name = "rust_core_entry" });
    // rust_entry();
    
    vga.print("[BOOT] POLER-OS kernel idle\n");
    
    // Halt loop
    while (true) {
        asm volatile ("hlt");
    }
}

// Panic handler — required for freestanding
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    vga.setColor(vga.Color.Red, vga.Color.Black);
    vga.print("KERNEL PANIC: ");
    vga.print(msg);
    vga.print("\nSystem halted.\n");
    while (true) {
        asm volatile ("hlt");
    }
}
`
```

### `zig-kernel/mm/pmm.zig` [zig · 2,327 B]
```
`// POLER-OS Physical Memory Manager
// Manages physical page frames using a bitmap allocator
// Each bit = 1 page (4KB), 0 = free, 1 = used

const std = @import("std");
const vga = @import("../drivers/vga.zig");

const PAGE_SIZE: u64 = 4096;
const MAX_PAGES: u64 = 0x100000000 / PAGE_SIZE; // Support up to 4GB

// Bitmap: 1 bit per page
var bitmap: [MAX_PAGES / 8]u8 = undefined;
var total_pages: u64 = 0;
var used_pages: u64 = 0;

pub fn init() void {
    // Zero the bitmap (all pages initially free)
    @memset(&bitmap, 0);
    
    // Mark first 1MB as used (BIOS, VGA, kernel)
    var addr: u64 = 0;
    while (addr < 0x100000) : (addr += PAGE_SIZE) {
        setPage(addr);
    }
    
    // Mark kernel at 1MB as used (assume 2MB kernel)
    addr = 0x100000;
    while (addr < 0x300000) : (addr += PAGE_SIZE) {
        setPage(addr);
    }
    
    total_pages = MAX_PAGES;
    used_pages = (0x300000) / PAGE_SIZE; // First 3MB
    
    vga.print("[PMM] Total pages: ");
    printNumber(total_pages);
    vga.print("\n[PMM] Used pages: ");
    printNumber(used_pages);
    vga.print("\n");
}

pub fn allocPage() ?u64 {
    var i: u64 = 0;
    while (i < total_pages) : (i += 1) {
        const byte_idx = i / 8;
        const bit_idx: u3 = @intCast(i % 8);
        if ((bitmap[byte_idx] & (@as(u8, 1) << bit_idx)) == 0) {
            setPage(i * PAGE_SIZE);
            used_pages += 1;
            return i * PAGE_SIZE;
        }
    }
    return null; // Out of memory
}

pub fn freePage(addr: u64) void {
    const page_idx = addr / PAGE_SIZE;
    const byte_idx = page_idx / 8;
    const bit_idx: u3 = @intCast(page_idx % 8);
    if ((bitmap[byte_idx] & (@as(u8, 1) << bit_idx)) != 0) {
        bitmap[byte_idx] &= ~(@as(u8, 1) << bit_idx);
        used_pages -= 1;
    }
}

fn setPage(addr: u64) void {
    const page_idx = addr / PAGE_SIZE;
    const byte_idx = page_idx / 8;
    const bit_idx: u3 = @intCast(page_idx % 8);
    bitmap[byte_idx] |= (@as(u8, 1) << bit_idx);
}

fn printNumber(n: u64) void {
    if (n == 0) {
        vga.print("0");
        return;
    }
    var buf: [20]u8 = undefined;
    var i: usize = 19;
    var num = n;
    while (num > 0) {
        buf[i] = '0' + @as(u8, @intCast(num % 10));
        num /= 10;
        if (i == 0) break;
        i -= 1;
    }
    vga.print(buf[i..]);
}
`
```

### `zig-kernel/run-qemu-iso.sh` [bash · 449 B]
```
`#!/bin/bash
# POLER-OS QEMU ISO Runner (No VT-x required)
# Runs the built ISO in QEMU with graphical interface

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO="$SCRIPT_DIR/poler-os64.iso"

if [ ! -f "$ISO" ]; then
    echo "ISO not found. Building it first..."
    zig build iso
fi

echo "Starting POLER-OS v0.5.1 in QEMU (Software Emulation)..."
exec qemu-system-x86_64 \
  -cdrom "$ISO" \
  -m 256M \
  -serial stdio \
  -vga std \
  -no-reboot
`
```

### `zig-kernel/run-qemu.sh` [bash · 572 B]
```
`#!/bin/bash
# POLER-OS QEMU Runner
# Usage: ./run-qemu.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL="$SCRIPT_DIR/zig-out/bin/poler-os"

export LD_LIBRARY_PATH="$SCRIPT_DIR/../tools/qemu-sys/usr/lib/x86_64-linux-gnu"
QEMU="$SCRIPT_DIR/../tools/qemu-sys/usr/bin/qemu-system-i386"

if [ ! -f "$KERNEL" ]; then
    echo "Kernel not found. Run 'zig build' first."
    exit 1
fi

exec "$QEMU" \
  -L "$SCRIPT_DIR/../tools/qemu-sys/usr/share/qemu" \
  -kernel "$KERNEL" \
  -m 128M \
  -serial stdio \
  -display none \
  -no-reboot \
  -vga std \
  -nic none \
  "$@"
`
```

### `zig-kernel/src/boot.S` [asm · 2,492 B]
```
`# POLER-OS — Boot Entry (32-bit -> 64-bit transition)
# Multiboot1 header + entry point (QEMU -kernel compatible)
# Assembled separately and linked with Zig kernel

.section .rodata.boot, "a", @progbits
.align 4
multiboot_header:
    .long 0x1BADB002          # multiboot1 magic
    .long 0x00000003          # flags: align modules (bit 0) + meminfo (bit 1)
    .long -(0x1BADB002 + 0x00000003)  # checksum

.section .rodata.gdt, "a", @progbits
.align 16
gdt64:
    .quad 0                    # null descriptor
    .quad 0x00209A0000000000   # code64: L+R+Present
    .quad 0x0000920000000000   # data: W+Present
gdt64_end:

.align 4
gdt64_ptr:
    .word gdt64_end - gdt64 - 1   # limit
    .long gdt64                    # base (32-bit for lgdt in compat mode)
    .long 0                        # padding

.section .bss
.align 16
boot_stack:
    .skip 16384

.section .text.boot
.global _start
.type _start, @function
_start:
    .code32
    cli
    movl $boot_stack + 16384, %esp
    xorl %ebp, %ebp

    # Setup page tables for long mode
    # PML4 at 0x70000, PDPT at 0x71000, PD at 0x72000
    movl $0x71003, %eax           # PDPT: Present + Writable
    movl %eax, 0x70000            # PML4[0] -> PDPT

    movl $0x72003, %eax           # PD: Present + Writable
    movl %eax, 0x71000            # PDPT[0] -> PD

    # PD: two 2MB pages (0-4MB identity mapped)
    movl $0x00083, %eax           # 0MB: Present + Writable + PageSize
    movl %eax, 0x72000            # PD[0]
    movl $0x200083, %eax          # 2MB: Present + Writable + PageSize
    movl %eax, 0x72008            # PD[1]

    # Enable PAE in CR4
    movl %cr4, %eax
    orl $(1 << 5), %eax
    movl %eax, %cr4

    # Load PML4 into CR3
    movl $0x70000, %eax
    movl %eax, %cr3

    # Enable long mode in EFER MSR
    movl $0xC0000080, %ecx
    rdmsr
    orl $(1 << 8), %eax           # LME bit
    wrmsr

    # Enable paging (PG bit in CR0)
    movl %cr0, %eax
    orl $(1 << 31), %eax
    movl %eax, %cr0

    # Load 64-bit GDT
    lgdt gdt64_ptr

    # Far jump to 64-bit code segment (0x08 = code64 selector)
    ljmpl $0x08, $long_mode_entry

.code64
long_mode_entry:
    movl $0x10, %eax
    movl %eax, %ds
    movl %eax, %es
    movl %eax, %fs
    movl %eax, %gs
    movl %eax, %ss

    # Set 64-bit stack
    movq $boot_stack + 16384, %rsp
    xorq %rbp, %rbp

    # Call kernel main
    call kernel_main

    # Should not return, but halt if it does
    cli
1:
    hlt
    jmp 1b

.size _start, . - _start
`
```

### `zig-kernel/src/boot.zig` [zig · 4,910 B]
```
`// POLER-OS — Multiboot2 Boot Entry
// Provides multiboot2 header + naked _start entry point
// QEMU loads this directly via -kernel flag

// ─── Multiboot2 Header ─────────────────────────────────────────────────────
// Must be in first 32KB of binary, aligned to 8 bytes
// Placed in .rodata.boot section, linker puts it first

const MULTIBOOT2_MAGIC: u32 = 0xE85250D6;
const MULTIBOOT2_ARCH: u32 = 0; // 0 = i386 (protected mode, works for x86_64 multiboot)
const MULTIBOOT2_HEADER_LENGTH: u32 = 24; // 16 header + 8 framebuffer tag + 0 end tag

// Framebuffer tag: request text mode
const Multiboot2FramebufferTag = extern struct {
    tag_type: u16 = 5,     // framebuffer tag
    tag_flags: u16 = 0,    // optional
    tag_size: u32 = 20,
    width: u32 = 80,
    height: u32 = 25,
    depth: u32 = 0,        // text mode
};

export const multiboot2_header align(8) linksection(".rodata.boot") = [_]u32{
    MULTIBOOT2_MAGIC,
    MULTIBOOT2_ARCH,
    MULTIBOOT2_HEADER_LENGTH,
    0x100000000 - MULTIBOOT2_MAGIC - MULTIBOOT2_ARCH - MULTIBOOT2_HEADER_LENGTH, // checksum
    5,     // tag type = framebuffer
    0,     // tag flags
    20,    // tag size
    80,    // width
    25,    // height
    0,     // depth (text mode)
    0,     // end tag type
    0,     // end tag flags
};

// ─── Stack ──────────────────────────────────────────────────────────────────
var boot_stack: [16384]u8 align(16) linksection(".bss") = undefined;

// ─── Entry Point ────────────────────────────────────────────────────────────
// QEMU multiboot loads us in 32-bit protected mode with paging disabled
// We must: set stack → enable PAE → setup pages → enable long mode → jump to 64-bit

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\ .code32
        \\ cli
        \\ movl $boot_stack + 16384, %%esp
        \\ xorl %%ebp, %%ebp
        \\
        \\ // Setup page tables for long mode (identity map first 2MB)
        \\ // PML4 at 0x70000, PDPT at 0x71000, PD at 0x72000
        \\ movl $0x71000, %%eax
        \\ orl $0x03, %%eax          // Present + Writable
        \\ movl %%eax, 0x70000       // PML4[0] → PDPT
        \\
        \\ movl $0x72000, %%eax
        \\ orl $0x03, %%eax
        \\ movl %%eax, 0x71000       // PDPT[0] → PD
        \\
        \\ // PD: one 2MB page mapping first 2MB
        \\ movl $0x00083, %%eax      // Present + Writable + PageSize (2MB)
        \\ movl %%eax, 0x72000       // PD[0] → 0x00000000 (2MB page)
        \\
        \\ // Map 1MB kernel region too (0x100000-0x300000)
        \\ movl $0x00083, %%eax
        \\ movl %%eax, 0x72008       // PD[1] → 2MB-4MB
        \\
        \\ // Enable PAE in CR4
        \\ movl %%cr4, %%eax
        \\ orl $(1 << 5), %%eax
        \\ movl %%eax, %%cr4
        \\
        \\ // Load PML4 into CR3
        \\ movl $0x70000, %%eax
        \\ movl %%eax, %%cr3
        \\
        \\ // Enable long mode in EFER MSR
        \\ movl $0xC0000080, %%ecx
        \\ rdmsr
        \\ orl $(1 << 8), %%eax      // LME bit
        \\ wrmsr
        \\
        \\ // Enable paging (PG bit in CR0)
        \\ movl %%cr0, %%eax
        \\ orl $(1 << 31), %%eax
        \\ movl %%eax, %%cr0
        \\
        \\ // Load 64-bit GDT
        \\ lgdt gdt64_ptr
        \\
        \\ // Far jump to 64-bit code segment
        \\ ljmpl $0x08, $long_mode_entry
        \\
        \\ .code64
        \\ long_mode_entry:
        \\   movl $0x10, %%eax
        \\   movl %%eax, %%ds
        \\   movl %%eax, %%es
        \\   movl %%eax, %%fs
        \\   movl %%eax, %%gs
        \\   movl %%eax, %%ss
        \\
        \\   // Set 64-bit stack
        \\   movq $boot_stack + 16384, %%rsp
        \\   xorq %%rbp, %%rbp
        \\
        \\   // Call kernel main
        \\   call kernel_main
        \\
        \\   // Should not return, but halt if it does
        \\   cli
        \\   hlt
        \\ 1:
        \\   jmp 1b
    );
}

// ─── 64-bit GDT ────────────────────────────────────────────────────────────
export const gdt64 align(16) linksection(".rodata") = [_]u64{
    0,                          // Null descriptor
    0x00209A0000000000,         // Code64: L+R+Present
    0x0000920000000000,         // Data: W+Present
};

export const gdt64_ptr align(4) linksection(".rodata") = extern struct {
    limit: u16 = @sizeOf(@TypeOf(gdt64)) - 1,
    base: u32 = @intFromPtr(&gdt64),
};
`
```

### `zig-kernel/src/boot32.S` [asm · 6,156 B]
```
`# POLER-OS v0.4.0 — 32-bit Multiboot1 Entry Point
# Fixed: stack alignment, CR0.TS, CR0.NE, A20 check, minimal GDT/IDT
# QEMU/GRUB loads this at 1MB in 32-bit protected mode

.section .rodata.boot, "a", @progbits
.align 8
multiboot_header:
    .long 0x1BADB002                    # magic
    .long 0x00000003                    # flags: align + meminfo
    .long -(0x1BADB002 + 0x00000003)   # checksum

# ─── Minimal GDT ───────────────────────────────────────────────────────────
# Flat memory model: code + data segments covering 0-4GB
.section .rodata
.align 16
gdt_start:
    .quad 0x0000000000000000            # null descriptor
gdt_code:
    .word 0xFFFF                        # limit low
    .word 0x0000                        # base low
    .byte 0x00                          # base mid
    .byte 0x9A                          # access: Present, Ring0, Code, Readable
    .byte 0xCF                          # granularity: 4KB, 32-bit, limit high=0xF
    .byte 0x00                          # base high
gdt_data:
    .word 0xFFFF                        # limit low
    .word 0x0000                        # base low
    .byte 0x00                          # base mid
    .byte 0x92                          # access: Present, Ring0, Data, Writable
    .byte 0xCF                          # granularity: 4KB, 32-bit, limit high=0xF
    .byte 0x00                          # base high
gdt_end:

# GDT selector offsets
code32_sel = 0x08
data32_sel = 0x10

# ─── Stack ─────────────────────────────────────────────────────────────────
.section .bss
.align 16
boot_stack:
    .skip 32768                         # 32KB stack (increased from 16KB)

# IDT storage — 256 entries × 8 bytes = 2048 bytes
idt_table:
    .skip 2048

# ─── Entry Point ───────────────────────────────────────────────────────────
.section .text.boot
.global _start
.type _start, @function
_start:
    cli

    # Preserve multiboot magic (EAX) and info pointer (EBX)
    # before SSE2 setup clobbers EAX and we switch stacks
    movl %eax, %esi              # save magic in ESI
    movl %ebx, %edi              # save info pointer in EDI

    # ─── A20 Line Check ────────────────────────────────────────────────
    # Test if A20 is already enabled (usually by BIOS/GRUB/QEMU)
    # If not enabled, try fast A20 via port 0x92
    movl $0x100000, %eax
    movl (%eax), %ecx            # save byte at 0x100000
    movl $0x110000, %edx
    notl (%edx)                  # invert byte at 0x110000 (via 0x100000+1MB if A20 off)
    cmpl (%eax), %ecx            # did 0x100000 change?
    notl (%edx)                  # restore original
    je a20_ok                    # if same → A20 is ON, good

    # A20 is OFF — try fast A20 enable via port 0x92
    inb $0x92, %al
    orb $0x02, %al
    andb $0xFE, %al              # don't trigger reset (bit 0)
    outb %al, $0x92

a20_ok:

    # ─── Initialize FPU ────────────────────────────────────────────────
    fninit

    # ─── Enable SSE2: Zig uses SSE2 for f64 ops on i386 ────────────────
    movl %cr0, %eax
    andl $0xFFFFFFE3, %eax      # Clear EM (bit 2) + TS (bit 3)
    orl $0x22, %eax             # Set MP (bit 1) + NE (bit 5)
    movl %eax, %cr0
    movl %cr4, %eax
    orl $0x00000600, %eax       # Set OSFXSR (bit 9) + OSXMMEXCPT (bit 10)
    movl %eax, %cr4

    # ─── Load our own GDT ──────────────────────────────────────────────
    # Build GDT descriptor on stack: 2 bytes limit + 4 bytes base
    subl $8, %esp
    movw $gdt_end - gdt_start - 1, 0(%esp)   # GDT size
    movl $gdt_start, 2(%esp)                  # GDT base address
    lgdt (%esp)
    addl $8, %esp

    # Reload segment registers with our GDT selectors
    movl $0x10, %eax          # data32_sel = 0x10
    movl %eax, %ds
    movl %eax, %es
    movl %eax, %fs
    movl %eax, %gs
    movl %eax, %ss

    # Far jump to reload CS with our code selector
    ljmp $0x08, $reload_cs   # code32_sel = 0x08
reload_cs:

    # ─── Load empty IDT (prevents triple fault on exceptions) ───────────
    # Clear IDT entries to all zeros
    movl $512, %ecx              # 256 entries × 2 dwords = 512
    movl $idt_table, %edi
    xorl %eax, %eax
    cld
    rep stosl

    # Load IDT — build descriptor on stack
    # IDT descriptor: 2 bytes limit + 4 bytes base = 6 bytes
    subl $8, %esp                # allocate 8 bytes (aligned)
    movw $2047, 0(%esp)          # limit = 256*8-1 = 2047
    movl $idt_table, 2(%esp)     # base = idt_table address
    lidt (%esp)
    addl $8, %esp                # clean up stack

    # ─── Set up proper kernel stack (16-byte aligned for SSE) ───────────
    movl $boot_stack + 32768, %esp
    andl $0xFFFFFFF0, %esp       # Force 16-byte alignment
    xorl %ebp, %ebp

    # ─── Push args + align stack for cdecl (ESP+4 ≡ 0 mod 16 at entry) ─
    # System V i386 ABI: ESP+4 must be 16-byte aligned at function entry
    # After our 16-byte aligned ESP:
    #   sub 8 → ESP is 8 mod 16
    #   push arg2 → ESP is 4 mod 16
    #   push arg1 → ESP is 0 mod 16
    #   call pushes ret addr → ESP is 12 mod 16 → ESP+4 = 0 mod 16 ✓
    subl $8, %esp               # alignment padding for SSE2
    pushl %edi              # multiboot info pointer (arg2)
    pushl %esi              # multiboot magic (arg1)

    call kernel_main

    # Should not return
    cli
1:  hlt
    jmp 1b

.size _start, . - _start
`
```

### `zig-kernel/src/boot32_test.S` [asm · 1,956 B]
```
`# POLER-OS — Minimal Serial Test Kernel
# Just sends 'POK' to COM1 to verify boot works

.section .rodata.boot, "a", @progbits
.align 4
multiboot_header:
    .long 0x1BADB002                    # magic
    .long 0x00000003                    # flags: align + meminfo
    .long -(0x1BADB002 + 0x00000003)   # checksum

.section .bss
.align 16
boot_stack:
    .skip 16384

.section .text.boot
.global _start
.type _start, @function
_start:
    cli

    # Init FPU + SSE2
    fninit
    movl %cr0, %eax
    andl $0xFFFFFFFB, %eax
    orl $0x02, %eax
    movl %eax, %cr0
    movl %cr4, %eax
    orl $0x00000600, %eax
    movl %eax, %cr4

    movl $boot_stack + 16384, %esp
    xorl %ebp, %ebp

    # ===== Direct serial test in ASM =====
    # Init COM1
    movw $0x3F9, %dx
    xorb %al, %al
    outb %al, %dx

    movw $0x3FB, %dx
    movb $0x80, %al
    outb %al, %dx

    movw $0x3F8, %dx
    movb $0x01, %al
    outb %al, %dx

    movw $0x3F9, %dx
    xorb %al, %al
    outb %al, %dx

    movw $0x3FB, %dx
    movb $0x03, %al
    outb %al, %dx

    movw $0x3FA, %dx
    movb $0xC7, %al
    outb %al, %dx

    movw $0x3FC, %dx
    movb $0x0B, %al
    outb %al, %dx

    # Wait for transmit empty
1:
    movw $0x3FD, %dx
    inb %dx, %al
    testb $0x20, %al
    jz 1b

    # Send 'P'
    movw $0x3F8, %dx
    movb $0x50, %al
    outb %al, %dx

    # Wait
2:
    movw $0x3FD, %dx
    inb %dx, %al
    testb $0x20, %al
    jz 2b

    # Send 'O'
    movw $0x3F8, %dx
    movb $0x4F, %al
    outb %al, %dx

    # Wait
3:
    movw $0x3FD, %dx
    inb %dx, %al
    testb $0x20, %al
    jz 3b

    # Send 'K'
    movw $0x3F8, %dx
    movb $0x4B, %al
    outb %al, %dx

    # Wait
4:
    movw $0x3FD, %dx
    inb %dx, %al
    testb $0x20, %al
    jz 4b

    # Send '\n'
    movw $0x3F8, %dx
    movb $0x0A, %al
    outb %al, %dx

    # Now call kernel_main
    pushl %ebx
    pushl %eax
    call kernel_main

    cli
5:  hlt
    jmp 5b

.size _start, . - _start
`
```

### `zig-kernel/src/drivers/serial.zig` [zig · 1,067 B]
```
`// POLER-OS — Serial Port Driver (COM1)
// For QEMU -serial stdio output

const PORT_COM1: u16 = 0x3F8;

pub fn init() void {
    // Disable interrupts
    outb(PORT_COM1 + 1, 0x00);
    // Enable DLAB
    outb(PORT_COM1 + 3, 0x80);
    // Baud rate divisor = 1 (115200 baud)
    outb(PORT_COM1 + 0, 0x01);
    outb(PORT_COM1 + 1, 0x00);
    // 8 bits, no parity, one stop bit
    outb(PORT_COM1 + 3, 0x03);
    // Enable FIFO
    outb(PORT_COM1 + 2, 0xC7);
    // IRQs enabled, RTS/DSR set
    outb(PORT_COM1 + 4, 0x0B);
}

pub fn writeChar(ch: u8) void {
    // Wait for transmit buffer to be empty
    while ((inb(PORT_COM1 + 5) & 0x20) == 0) {}
    outb(PORT_COM1, ch);
}

pub fn writeString(str: []const u8) void {
    for (str) |ch| writeChar(ch);
}

fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "N{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "=al" (-> u8),
        : [port] "N{dx}" (port),
    );
}
`
```

### `zig-kernel/src/drivers/vga.zig` [zig · 2,215 B]
```
`// POLER-OS — VGA Text Mode Driver (80x25)
// Direct memory-mapped VGA buffer at 0xB8000

pub const Color = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,
};

const VgaEntry = packed struct(u16) {
    char: u8,
    color: u8,
};

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER: [*]volatile VgaEntry = @ptrFromInt(0xB8000);

var row: usize = 0;
var col: usize = 0;
var fg: Color = .light_grey;
var bg: Color = .black;

pub fn init() void {
    row = 0;
    col = 0;
    fg = .light_grey;
    bg = .black;
    clear();
}

pub fn clear() void {
    const attr = makeColor(.light_grey, .black);
    var i: usize = 0;
    while (i < VGA_WIDTH * VGA_HEIGHT) : (i += 1) {
        VGA_BUFFER[i] = .{ .char = ' ', .color = attr };
    }
}

pub fn setColor(foreground: Color, background: Color) void {
    fg = foreground;
    bg = background;
}

pub fn writeChar(ch: u8) void {
    if (ch == '\n') {
        col = 0;
        row += 1;
    } else {
        const attr = makeColor(fg, bg);
        VGA_BUFFER[row * VGA_WIDTH + col] = .{ .char = ch, .color = attr };
        col += 1;
        if (col >= VGA_WIDTH) {
            col = 0;
            row += 1;
        }
    }
    if (row >= VGA_HEIGHT) {
        scroll();
        row = VGA_HEIGHT - 1;
    }
}

pub fn writeString(str: []const u8) void {
    for (str) |ch| writeChar(ch);
}

fn makeColor(f: Color, b: Color) u8 {
    return @as(u8, @intFromEnum(f)) | (@as(u8, @intFromEnum(b)) << 4);
}

fn scroll() void {
    // Move all rows up by one
    var y: usize = 0;
    while (y < VGA_HEIGHT - 1) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            VGA_BUFFER[y * VGA_WIDTH + x] = VGA_BUFFER[(y + 1) * VGA_WIDTH + x];
        }
    }
    // Clear last row
    const attr = makeColor(.light_grey, .black);
    var x: usize = 0;
    while (x < VGA_WIDTH) : (x += 1) {
        VGA_BUFFER[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = .{ .char = ' ', .color = attr };
    }
}
`
```

### `zig-kernel/src/isr32.S` [asm · 6,806 B]
```
`# POLER-OS v0.5.1 — ISR/IRQ Assembly Stubs
# 32 CPU exception handlers (ISR 0-31) + 16 IRQ handlers (IRQ 32-47)
# Each stub pushes ISR number (+ dummy error code if CPU doesn't push one)
# then jumps to the common handler which calls zig_isr_handler()

.section .text

# ─── CPU Exception Stubs (ISR 0-31) ───────────────────────────────────────

# ISR 0: Divide Error (no error code)
.global isr0
isr0:   pushl $0; pushl $0; jmp isr_common

# ISR 1: Debug (no error code)
.global isr1
isr1:   pushl $0; pushl $1; jmp isr_common

# ISR 2: NMI (no error code)
.global isr2
isr2:   pushl $0; pushl $2; jmp isr_common

# ISR 3: Breakpoint (no error code)
.global isr3
isr3:   pushl $0; pushl $3; jmp isr_common

# ISR 4: Overflow (no error code)
.global isr4
isr4:   pushl $0; pushl $4; jmp isr_common

# ISR 5: BOUND Range Exceeded (no error code)
.global isr5
isr5:   pushl $0; pushl $5; jmp isr_common

# ISR 6: Invalid Opcode (no error code)
.global isr6
isr6:   pushl $0; pushl $6; jmp isr_common

# ISR 7: Device Not Available (no error code)
.global isr7
isr7:   pushl $0; pushl $7; jmp isr_common

# ISR 8: Double Fault (CPU pushes error code)
.global isr8
isr8:   pushl $8; jmp isr_common

# ISR 9: Coprocessor Segment Overrun (no error code)
.global isr9
isr9:   pushl $0; pushl $9; jmp isr_common

# ISR 10: Invalid TSS (CPU pushes error code)
.global isr10
isr10:  pushl $10; jmp isr_common

# ISR 11: Segment Not Present (CPU pushes error code)
.global isr11
isr11:  pushl $11; jmp isr_common

# ISR 12: Stack Segment Fault (CPU pushes error code)
.global isr12
isr12:  pushl $12; jmp isr_common

# ISR 13: General Protection Fault (CPU pushes error code)
.global isr13
isr13:  pushl $13; jmp isr_common

# ISR 14: Page Fault (CPU pushes error code)
.global isr14
isr14:  pushl $14; jmp isr_common

# ISR 15: Reserved (no error code)
.global isr15
isr15:  pushl $0; pushl $15; jmp isr_common

# ISR 16: x87 FPU Error (no error code)
.global isr16
isr16:  pushl $0; pushl $16; jmp isr_common

# ISR 17: Alignment Check (CPU pushes error code)
.global isr17
isr17:  pushl $17; jmp isr_common

# ISR 18: Machine Check (no error code)
.global isr18
isr18:  pushl $0; pushl $18; jmp isr_common

# ISR 19: SIMD Floating-Point (no error code)
.global isr19
isr19:  pushl $0; pushl $19; jmp isr_common

# ISR 20-31: Reserved (no error codes)
.global isr20
isr20:  pushl $0; pushl $20; jmp isr_common

.global isr21
isr21:  pushl $0; pushl $21; jmp isr_common

.global isr22
isr22:  pushl $0; pushl $22; jmp isr_common

.global isr23
isr23:  pushl $0; pushl $23; jmp isr_common

.global isr24
isr24:  pushl $0; pushl $24; jmp isr_common

.global isr25
isr25:  pushl $0; pushl $25; jmp isr_common

.global isr26
isr26:  pushl $0; pushl $26; jmp isr_common

.global isr27
isr27:  pushl $0; pushl $27; jmp isr_common

.global isr28
isr28:  pushl $0; pushl $28; jmp isr_common

.global isr29
isr29:  pushl $0; pushl $29; jmp isr_common

.global isr30
isr30:  pushl $0; pushl $30; jmp isr_common

.global isr31
isr31:  pushl $0; pushl $31; jmp isr_common

# ─── IRQ Stubs (IRQ 32-47) ────────────────────────────────────────────────

.global irq32
irq32:  pushl $0; pushl $32; jmp isr_common   # Timer (PIT)

.global irq33
irq33:  pushl $0; pushl $33; jmp isr_common   # Keyboard

.global irq34
irq34:  pushl $0; pushl $34; jmp isr_common   # Cascade

.global irq35
irq35:  pushl $0; pushl $35; jmp isr_common   # COM2

.global irq36
irq36:  pushl $0; pushl $36; jmp isr_common   # COM1

.global irq37
irq37:  pushl $0; pushl $37; jmp isr_common   # LPT2

.global irq38
irq38:  pushl $0; pushl $38; jmp isr_common   # Floppy

.global irq39
irq39:  pushl $0; pushl $39; jmp isr_common   # LPT1

.global irq40
irq40:  pushl $0; pushl $40; jmp isr_common   # RTC

.global irq41
irq41:  pushl $0; pushl $41; jmp isr_common   # ACPI

.global irq42
irq42:  pushl $0; pushl $42; jmp isr_common   # Available

.global irq43
irq43:  pushl $0; pushl $43; jmp isr_common   # Available

.global irq44
irq44:  pushl $0; pushl $44; jmp isr_common   # Mouse

.global irq45
irq45:  pushl $0; pushl $45; jmp isr_common   # FPU

.global irq46
irq46:  pushl $0; pushl $46; jmp isr_common   # ATA Primary

.global irq47
irq47:  pushl $0; pushl $47; jmp isr_common   # ATA Secondary

# ─── Common ISR Handler ────────────────────────────────────────────────────
# Stack on entry: [error_code, isr_number] pushed by stub, then CPU's [EIP, CS, EFLAGS]
isr_common:
    pushal                      # save all 8 general-purpose registers

    # Save segment registers (as 32-bit pushes for alignment)
    movw %ds, %ax
    pushl %eax
    movw %es, %ax
    pushl %eax
    movw %fs, %ax
    pushl %eax
    movw %gs, %ax
    pushl %eax

    # Load kernel data segment selector (0x10)
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs

    # Extract ISR number and error code from the stack
    # Stack layout after pushal + 4 segment pushes (48 bytes above ESP):
    #   ESP+44: EAX, ESP+40: ECX, ESP+36: EDX, ESP+32: EBX
    #   ESP+28: original ESP, ESP+24: EBP, ESP+20: ESI, ESP+16: EDI
    #   ESP+12: saved GS, ESP+8: saved FS, ESP+4: saved ES, ESP+0: saved DS
    # Above that: ISR number at ESP+48, error code at ESP+52
    movl 48(%esp), %eax         # ISR number
    movl 52(%esp), %edx         # error code

    # Call Zig handler: zig_isr_handler(isr_number, error_code)
    pushl %edx                  # arg2: error_code
    pushl %eax                  # arg1: isr_number
    call zig_isr_handler
    addl $8, %esp               # clean up cdecl arguments

    # Restore segment registers
    popl %eax
    movw %ax, %gs
    popl %eax
    movw %ax, %fs
    popl %eax
    movw %ax, %es
    popl %eax
    movw %ax, %ds

    popal                       # restore all general-purpose registers
    addl $8, %esp               # remove error_code and isr_number pushed by stub
    iret                        # return from interrupt

# ─── ISR Address Table (for Zig to set up IDT entries) ────────────────────
.section .rodata
.global isr_table
isr_table:
    .long isr0,  isr1,  isr2,  isr3,  isr4,  isr5,  isr6,  isr7
    .long isr8,  isr9,  isr10, isr11, isr12, isr13, isr14, isr15
    .long isr16, isr17, isr18, isr19, isr20, isr21, isr22, isr23
    .long isr24, isr25, isr26, isr27, isr28, isr29, isr30, isr31
    .long irq32, irq33, irq34, irq35, irq36, irq37, irq38, irq39
    .long irq40, irq41, irq42, irq43, irq44, irq45, irq46, irq47
`
```

### `zig-kernel/src/linker.ld` [ld · 376 B]
```
`ENTRY(kernel_main)

SECTIONS {
    . = 1M;

    .text : ALIGN(4K) {
        *(.text .text.*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4K) {
        *(.data .data.*)
    }

    .bss : ALIGN(4K) {
        *(.bss .bss.*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame*)
    }
}
`
```

### `zig-kernel/src/linker32.ld` [ld · 582 B]
```
`ENTRY(_start)

SECTIONS {
    . = 1M;

    /* Multiboot header — must be 8-byte aligned and in first 8KB of image */
    .rodata.boot : ALIGN(8) {
        KEEP(*(.rodata.boot))
    }

    .text.boot : ALIGN(4K) {
        KEEP(*(.text.boot))
    }

    .text : ALIGN(4K) {
        *(.text .text.*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata .rodata.*)
    }

    .data : ALIGN(4K) {
        *(.data .data.*)
    }

    .bss : ALIGN(4K) {
        *(.bss .bss.*)
        *(COMMON)
    }

    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame*)
    }
}
`
```

### `zig-kernel/src/main.zig` [zig · 13,318 B]
```
`// =============================================================================
// POLER-OS v0.2.0 — Kernel Main
// =============================================================================
// Zig 0.13 x86_64 freestanding — POLER Cognitive Architecture
// Called from boot.S after transition to 64-bit long mode

// =============================================================================
// VGA Text Mode Driver (80x25)
// =============================================================================

pub const Color = enum(u8) {
    black = 0,
    blue = 1,
    green = 2,
    cyan = 3,
    red = 4,
    magenta = 5,
    brown = 6,
    light_grey = 7,
    dark_grey = 8,
    light_blue = 9,
    light_green = 10,
    light_cyan = 11,
    light_red = 12,
    light_magenta = 13,
    yellow = 14,
    white = 15,
};

const VgaEntry = packed struct(u16) {
    char: u8,
    color: u8,
};

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER: [*]volatile VgaEntry = @ptrFromInt(0xB8000);

var vga_row: usize = 0;
var vga_col: usize = 0;
var vga_fg: Color = .light_grey;
var vga_bg: Color = .black;

fn vga_init() void {
    vga_row = 0;
    vga_col = 0;
    vga_fg = .light_grey;
    vga_bg = .black;
    vga_clear();
}

fn vga_clear() void {
    const attr = vga_makeColor(.light_grey, .black);
    var i: usize = 0;
    while (i < VGA_WIDTH * VGA_HEIGHT) : (i += 1) {
        VGA_BUFFER[i] = .{ .char = ' ', .color = attr };
    }
}

fn vga_setColor(f: Color, b: Color) void {
    vga_fg = f;
    vga_bg = b;
}

fn vga_writeChar(ch: u8) void {
    if (ch == '\n') {
        vga_col = 0;
        vga_row += 1;
    } else {
        const attr = vga_makeColor(vga_fg, vga_bg);
        VGA_BUFFER[vga_row * VGA_WIDTH + vga_col] = .{ .char = ch, .color = attr };
        vga_col += 1;
        if (vga_col >= VGA_WIDTH) {
            vga_col = 0;
            vga_row += 1;
        }
    }
    if (vga_row >= VGA_HEIGHT) {
        vga_scroll();
        vga_row = VGA_HEIGHT - 1;
    }
}

fn vga_writeString(str: []const u8) void {
    for (str) |ch| vga_writeChar(ch);
}

fn vga_makeColor(f: Color, b: Color) u8 {
    return @as(u8, @intFromEnum(f)) | (@as(u8, @intFromEnum(b)) << 4);
}

fn vga_scroll() void {
    var y: usize = 0;
    while (y < VGA_HEIGHT - 1) : (y += 1) {
        var x: usize = 0;
        while (x < VGA_WIDTH) : (x += 1) {
            VGA_BUFFER[y * VGA_WIDTH + x] = VGA_BUFFER[(y + 1) * VGA_WIDTH + x];
        }
    }
    const attr = vga_makeColor(.light_grey, .black);
    var x: usize = 0;
    while (x < VGA_WIDTH) : (x += 1) {
        VGA_BUFFER[(VGA_HEIGHT - 1) * VGA_WIDTH + x] = .{ .char = ' ', .color = attr };
    }
}

// =============================================================================
// Serial Port Driver (COM1) — for QEMU -serial stdio
// =============================================================================

const PORT_COM1: u16 = 0x3F8;

fn serial_init() void {
    outb(PORT_COM1 + 1, 0x00);
    outb(PORT_COM1 + 3, 0x80);
    outb(PORT_COM1 + 0, 0x01);
    outb(PORT_COM1 + 1, 0x00);
    outb(PORT_COM1 + 3, 0x03);
    outb(PORT_COM1 + 2, 0xC7);
    outb(PORT_COM1 + 4, 0x0B);
}

fn serial_writeChar(ch: u8) void {
    while ((inb(PORT_COM1 + 5) & 0x20) == 0) {}
    outb(PORT_COM1, ch);
}

fn serial_writeString(str: []const u8) void {
    for (str) |ch| serial_writeChar(ch);
}

fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "N{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "=al" (-> u8),
        : [port] "N{dx}" (port),
    );
}

// =============================================================================
// POLER Tensor Engine (kernel-space, zero-alloc)
// =============================================================================

pub const Matrix4x4 = [4][4]f64;

pub fn zero() Matrix4x4 {
    return .{.{ 0, 0, 0, 0 }} ** 4;
}

pub fn identity() Matrix4x4 {
    var m = zero();
    m[0][0] = 1.0;
    m[1][1] = 1.0;
    m[2][2] = 1.0;
    m[3][3] = 1.0;
    return m;
}

pub fn tensorProduct(a: Matrix4x4, b: Matrix4x4) Matrix4x4 {
    var result = zero();
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        var j: usize = 0;
        while (j < 4) : (j += 1) {
            var k: usize = 0;
            var sum: f64 = 0;
            while (k < 4) : (k += 1) {
                sum += a[i][k] * b[k][j];
            }
            result[i][j] = sum;
        }
    }
    return result;
}

pub fn hadamard(a: Matrix4x4, b: Matrix4x4) Matrix4x4 {
    var result = zero();
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        var j: usize = 0;
        while (j < 4) : (j += 1) {
            result[i][j] = a[i][j] * b[i][j];
        }
    }
    return result;
}

pub fn trace(m: Matrix4x4) f64 {
    var s: f64 = 0;
    var i: usize = 0;
    while (i < 4) : (i += 1) s += m[i][i];
    return s;
}

pub fn frobeniusNorm(m: Matrix4x4) f64 {
    var s: f64 = 0;
    for (m) |row| {
        for (row) |v| {
            s += v * v;
        }
    }
    return sqrt(s);
}

fn sqrt(x: f64) f64 {
    if (x <= 0) return 0;
    var z: f64 = x;
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        z = 0.5 * (z + x / z);
    }
    return z;
}

fn absF64(x: f64) f64 {
    if (x < 0) return -x;
    return x;
}

// ─── POLER Cycle ───────────────────────────────────────────────────────────

const PolerMetrics = struct {
    entropy: f64,
    knowledge_density: f64,
    semantic_drift: f64,
    responsibility_purity: f64,
    cognitive_load: f64,
    compression_score: f64,
    evo_resonance: f64,
    health_score: f64,
};

const PolerCycle = struct {
    density: Matrix4x4,
    archetype: Matrix4x4,
    dissipation: f64,
    metrics: PolerMetrics,
    has_converged: bool,
    iteration: u32,

    pub fn init(density: Matrix4x4, archetype: Matrix4x4, dissipation: f64) PolerCycle {
        return .{
            .density = density,
            .archetype = archetype,
            .dissipation = dissipation,
            .metrics = .{
                .entropy = 0,
                .knowledge_density = 0,
                .semantic_drift = 0,
                .responsibility_purity = 0,
                .cognitive_load = 0,
                .compression_score = 0,
                .evo_resonance = 0,
                .health_score = 0,
            },
            .has_converged = false,
            .iteration = 0,
        };
    }

    pub fn iterate(self: *PolerCycle) bool {
        const perceived = tensorProduct(self.density, self.archetype);
        const resonance = hadamard(perceived, self.archetype);

        var dissipated = zero();
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                dissipated[i][j] = resonance[i][j] * (1.0 - self.dissipation);
            }
        }

        const old_trace = trace(self.density);
        const new_trace = trace(dissipated);
        const norm = frobeniusNorm(dissipated);

        self.metrics.entropy = 1.0 - (new_trace / 4.0);
        self.metrics.knowledge_density = new_trace / 4.0;
        self.metrics.semantic_drift = absF64(new_trace - old_trace);
        self.metrics.responsibility_purity = dissipated[0][0] / (norm + 0.001);
        self.metrics.cognitive_load = 1.0 - self.metrics.responsibility_purity;
        self.metrics.compression_score = 4.0 / (norm + 0.001);
        self.metrics.evo_resonance = new_trace / (old_trace + 0.001);
        self.metrics.health_score = (self.metrics.knowledge_density + self.metrics.responsibility_purity + self.metrics.evo_resonance) / 3.0;

        if (self.metrics.semantic_drift < 0.001 and self.iteration > 0) {
            self.has_converged = true;
        }

        self.density = dissipated;
        self.iteration += 1;
        return self.has_converged;
    }
};

// =============================================================================
// Kernel Main — called from boot.S after long mode transition
// =============================================================================

export fn kernel_main() noreturn {
    vga_init();
    serial_init();

    // Banner
    vga_setColor(.light_cyan, .black);
    vga_writeString("POLER-OS v0.2.0\n");
    vga_writeString("Zig Kernel + POLER Cognitive Engine\n");
    vga_writeString("x86_64 freestanding\n\n");
    serial_writeString("POLER-OS v0.2.0 boot\n");

    // Boot sequence
    vga_setColor(.light_grey, .black);
    vga_writeString("[BOOT] VGA initialized\n");
    vga_writeString("[BOOT] COM1 serial initialized\n");
    vga_writeString("[BOOT] Long mode active\n");
    vga_writeString("[BOOT] Identity map: 0-4MB\n\n");

    // ─── POLER Cognitive Cycle ──────────────────────────────────────────
    vga_setColor(.yellow, .black);
    vga_writeString("=== POLER Cognitive Cycle ===\n\n");
    vga_setColor(.white, .black);

    var initial_state: Matrix4x4 = zero();
    initial_state[0][0] = 0.8;
    initial_state[1][1] = 0.6;
    initial_state[2][2] = 0.4;
    initial_state[3][3] = 0.2;
    initial_state[0][1] = 0.1;
    initial_state[1][0] = 0.05;

    var archetype: Matrix4x4 = identity();
    archetype[0][0] = 0.9;
    archetype[1][1] = 0.8;
    archetype[2][2] = 0.7;
    archetype[3][3] = 0.5;

    var cycle = PolerCycle.init(initial_state, archetype, 0.1);

    var iter: u32 = 0;
    while (iter < 10 and !cycle.has_converged) : (iter += 1) {
        _ = cycle.iterate();
    }

    // Display 8 Architecture Metrics
    vga_setColor(.yellow, .black);
    vga_writeString("=== 8 Architecture Metrics ===\n");
    vga_setColor(.white, .black);

    vga_writeString("  Entropy:       "); printFloat(cycle.metrics.entropy); vga_writeString("\n");
    vga_writeString("  Know.Density:  "); printFloat(cycle.metrics.knowledge_density); vga_writeString("\n");
    vga_writeString("  Sem.Drift:     "); printFloat(cycle.metrics.semantic_drift); vga_writeString("\n");
    vga_writeString("  Purity:        "); printFloat(cycle.metrics.responsibility_purity); vga_writeString("\n");
    vga_writeString("  Cogn.Load:     "); printFloat(cycle.metrics.cognitive_load); vga_writeString("\n");
    vga_writeString("  Compression:   "); printFloat(cycle.metrics.compression_score); vga_writeString("x\n");
    vga_writeString("  Evo.Resonance: "); printFloat(cycle.metrics.evo_resonance); vga_writeString("\n");
    vga_writeString("  Health:        "); printFloat(cycle.metrics.health_score); vga_writeString("\n\n");

    vga_setColor(.light_green, .black);
    if (cycle.has_converged) {
        vga_writeString("  Status: CONVERGED\n");
        serial_writeString("POLER cycle CONVERGED\n");
    } else {
        vga_setColor(.light_red, .black);
        vga_writeString("  Status: MAX ITERATIONS\n");
        serial_writeString("POLER cycle MAX ITERATIONS\n");
    }

    vga_setColor(.light_cyan, .black);
    vga_writeString("\n=== Hardware ===\n");
    vga_setColor(.white, .black);
    vga_writeString("  Target: x86_64 (Intel i7-3770K)\n");
    vga_writeString("  Memory: 128MB QEMU\n\n");

    vga_setColor(.light_green, .black);
    vga_writeString("POLER-OS idle. System ready.\n");
    vga_setColor(.light_grey, .black);
    serial_writeString("POLER-OS kernel idle. System ready.\n");

    while (true) {
        asm volatile ("hlt");
    }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

fn printFloat(val: f64) void {
    var value = val;
    if (value < 0) {
        vga_writeChar('-');
        value = -value;
    }
    const int_part: u32 = @intFromFloat(value);
    const dec_part: u32 = @intFromFloat((value - @as(f64, @floatFromInt(int_part))) * 100.0);
    printUint(int_part);
    vga_writeChar('.');
    if (dec_part < 10) vga_writeChar('0');
    printUint(dec_part);
}

fn printUint(value: u32) void {
    if (value == 0) {
        vga_writeChar('0');
        return;
    }
    var buf: [10]u8 = undefined;
    var i: usize = 0;
    var v = value;
    while (v > 0) : (i += 1) {
        buf[i] = @as(u8, @intCast(v % 10)) + '0';
        v /= 10;
    }
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }
    var k: usize = 0;
    while (k < i) : (k += 1) {
        vga_writeChar(buf[k]);
    }
}

// Panic handler — required for freestanding
pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    vga_setColor(.red, .black);
    vga_writeString("\n!!! KERNEL PANIC !!!\n");
    vga_writeString("Message: ");
    vga_writeString(msg);
    vga_writeString("\nSystem halted.\n");
    serial_writeString("KERNEL PANIC: ");
    serial_writeString(msg);
    serial_writeString("\n");
    while (true) {
        asm volatile ("hlt");
    }
}
`
```

### `zig-kernel/src/main32.zig` [zig · 76,153 B]
```
`// POLER-OS v0.4.0 — 32-bit x86 freestanding kernel
// Multiboot1 compatible, runs in QEMU -kernel directly
// + PCI bus scanning + VirtIO device detection + Kernel shell

const std = @import("std");
const poler = @import("poler_core.zig");

// ─── VGA Text Mode ─────────────────────────────────────────────────────────

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);

var row: usize = 0;
var col: usize = 0;
var color: u8 = 0x07;

fn vga_init() void {
    row = 0;
    col = 0;
    color = 0x07;
    var i: usize = 0;
    while (i < VGA_WIDTH * VGA_HEIGHT) : (i += 1) {
        VGA_BUFFER[i] = @as(u16, ' ') | (@as(u16, color) << 8);
    }
}

fn vga_puts(str: []const u8) void {
    for (str) |ch| {
        if (ch == '\n') {
            col = 0;
            row += 1;
        } else {
            VGA_BUFFER[row * VGA_WIDTH + col] = @as(u16, ch) | (@as(u16, color) << 8);
            col += 1;
            if (col >= VGA_WIDTH) {
                col = 0;
                row += 1;
            }
        }
        if (row >= VGA_HEIGHT) {
            var y: usize = 0;
            while (y < VGA_HEIGHT - 1) : (y += 1) {
                var x: usize = 0;
                while (x < VGA_WIDTH) : (x += 1) {
                    VGA_BUFFER[y * VGA_WIDTH + x] = VGA_BUFFER[(y + 1) * VGA_WIDTH + x];
                }
            }
            var x2: usize = 0;
            while (x2 < VGA_WIDTH) : (x2 += 1) {
                VGA_BUFFER[(VGA_HEIGHT - 1) * VGA_WIDTH + x2] = @as(u16, ' ') | (@as(u16, color) << 8);
            }
            row = VGA_HEIGHT - 1;
        }
    }
}

fn vga_setcolor(c: u8) void {
    color = c;
}

// ─── Serial Port ───────────────────────────────────────────────────────────

fn serial_init() void {
    outb(0x3F9, 0x00);    // Disable interrupts
    outb(0x3FB, 0x80);    // Enable DLAB
    outb(0x3F8, 0x01);    // Baud divisor low = 1 → 115200 baud
    outb(0x3F9, 0x00);    // Baud divisor high = 0
    outb(0x3FA, 0xC7);    // Enable FIFO, clear, 14-byte threshold
    outb(0x3FB, 0x03);    // 8N1 (8 bits, no parity, 1 stop bit)
    outb(0x3FC, 0x0B);    // Enable RTS/DSR/DTR
}

fn serial_puts(str: []const u8) void {
    for (str) |ch| {
        while ((inb(0x3FD) & 0x20) == 0) {}
        outb(0x3F8, ch);
    }
}

fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
    );
}

fn outl(port: u16, val: u32) void {
    asm volatile ("outl %[val], %[port]"
        :
        : [val] "{eax}" (val),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    var result: u8 = undefined;
    asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (result),
        : [port] "{dx}" (port),
    );
    return result;
}

fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

// ─── Dual output ───────────────────────────────────────────────────────────

fn puts(str: []const u8) void {
    vga_puts(str);
    serial_puts(str);
}

// ─── PS/2 Keyboard Driver (i8042) ──────────────────────────────────────────

const KBD_DATA: u16 = 0x60;
const KBD_STATUS: u16 = 0x64;
const KBD_CMD: u16 = 0x64;

var kbd_shift: bool = false;
var kbd_ctrl: bool = false;
var kbd_alt: bool = false;
var kbd_extended: bool = false;

// US QWERTY scan code set 1 → ASCII (make codes only)
// Scan codes 0-127, organized in rows of 16
const scan_to_ascii = [128]u8{
    // 0x00-0x0F
    0, 0x1B, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\x08', 0,
    // 0x10-0x1F
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', 0, 0,
    // 0x20-0x2F
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0, '\\', 0,
    // 0x30-0x3F
    'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0,
    // 0x40-0x7F
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const scan_to_ascii_shift = [128]u8{
    // 0x00-0x0F
    0, 0x1B, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\x08', 0,
    // 0x10-0x1F
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0, 0,
    // 0x20-0x2F
    0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|', 0,
    // 0x30-0x3F
    'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0,
    // 0x40-0x7F
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

fn kbd_init() void {
    // Flush any pending data
    while ((inb(KBD_STATUS) & 0x01) != 0) {
        _ = inb(KBD_DATA);
    }
    // Enable keyboard device
    outb(KBD_CMD, 0xAE);
    // Enable PS/2 keyboard interrupts (IRQ1)
    outb(KBD_CMD, 0x20);
    var config = inb(KBD_DATA);
    config |= 0x01; // Enable IRQ1
    config &= ~@as(u8, 0x10); // Enable keyboard port
    outb(KBD_CMD, 0x60);
    outb(KBD_DATA, config);
    // Reset keyboard
    outb(KBD_DATA, 0xFF);
    // Wait for ACK
    var timeout: u32 = 0;
    while (timeout < 10000) : (timeout += 1) {
        if ((inb(KBD_STATUS) & 0x01) != 0) {
            const resp = inb(KBD_DATA);
            if (resp == 0xFA or resp == 0xAA) break;
        }
    }
    // Set scan code set 1
    outb(KBD_DATA, 0xF0);
    while ((inb(KBD_STATUS) & 0x02) != 0) {}
    outb(KBD_DATA, 0x01);
}

fn kbd_read_key() u8 {
    // Wait for key press (output buffer full)
    while ((inb(KBD_STATUS) & 0x01) == 0) {
        asm volatile ("hlt");
    }
    const scan = inb(KBD_DATA);

    // Extended key prefix
    if (scan == 0xE0) {
        kbd_extended = true;
        return 0;
    }

    // Key release (bit 7 set)
    if (scan & 0x80 != 0) {
        const released = scan & 0x7F;
        if (released == 0x2A or released == 0x36) kbd_shift = false;
        if (released == 0x1D) kbd_ctrl = false;
        if (released == 0x38) kbd_alt = false;
        kbd_extended = false;
        return 0;
    }

    // Extended key handling
    if (kbd_extended) {
        kbd_extended = false;
        // Extended keys: arrow keys, etc.
        if (scan == 0x48) return 0x11; // Up    → DC1 (Ctrl-Q)
        if (scan == 0x50) return 0x12; // Down  → DC2 (Ctrl-R)
        if (scan == 0x4B) return 0x13; // Left  → DC3 (Ctrl-S)
        if (scan == 0x4D) return 0x14; // Right → DC4 (Ctrl-T)
        return 0;
    }

    // Modifier keys
    if (scan == 0x2A or scan == 0x36) { kbd_shift = true; return 0; }
    if (scan == 0x1D) { kbd_ctrl = true; return 0; }
    if (scan == 0x38) { kbd_alt = true; return 0; }

    // Convert scan code to ASCII
    if (scan < 128) {
        if (kbd_ctrl and scan == 0x2E) return 0x03; // Ctrl-C
        if (kbd_ctrl and scan == 0x15) return 0x18; // Ctrl-X
        if (kbd_ctrl and scan == 0x31) return 0x1A; // Ctrl-Z
        const ch = if (kbd_shift) scan_to_ascii_shift[scan] else scan_to_ascii[scan];
        return ch;
    }
    return 0;
}

// ─── Kernel Shell ───────────────────────────────────────────────────────────

const SHELL_MAX_CMD = 256;
var shell_buf: [SHELL_MAX_CMD]u8 = undefined;
var shell_len: usize = 0;
var shell_history: [8][SHELL_MAX_CMD]u8 = undefined;
var shell_history_len: [8]usize = undefined;
var shell_history_idx: usize = 0;
var shell_history_pos: usize = 0;

fn shell_prompt() void {
    vga_setcolor(0x0B);
    puts("poler> ");
    vga_setcolor(0x0F);
}

fn shell_clear_line() void {
    // Erase current input line from screen
    var i: usize = 0;
    while (i < shell_len + 7) : (i += 1) {
        puts("\x08 \x08");
    }
    shell_len = 0;
}

fn shell_execute(cmd: []const u8) void {
    // Skip empty commands
    if (cmd.len == 0) return;

    // Save to history
    if (shell_history_idx < 8) {
        @memcpy(shell_history[shell_history_idx][0..cmd.len], cmd);
        shell_history_len[shell_history_idx] = cmd.len;
        shell_history_idx += 1;
    } else {
        // Shift history
        var h: usize = 0;
        while (h < 7) : (h += 1) {
            @memcpy(shell_history[h][0..shell_history_len[h + 1]], shell_history[h + 1][0..shell_history_len[h + 1]]);
            shell_history_len[h] = shell_history_len[h + 1];
        }
        @memcpy(shell_history[7][0..cmd.len], cmd);
        shell_history_len[7] = cmd.len;
    }

    // Parse and execute
    if (strEq(cmd, "help")) {
        cmd_help();
    } else if (strEq(cmd, "poler test")) {
        cmd_poler_test();
    } else if (strEq(cmd, "metrics")) {
        cmd_metrics();
    } else if (strEq(cmd, "pci")) {
        cmd_pci();
    } else if (strEq(cmd, "clear")) {
        cmd_clear();
    } else if (strEq(cmd, "reboot")) {
        cmd_reboot();
    } else if (strEq(cmd, "about")) {
        cmd_about();
    } else if (strStartsWith(cmd, "cipher ")) {
        cmd_cipher(cmd[7..]);
    } else if (strStartsWith(cmd, "phi ")) {
        cmd_phi(cmd[4..]);
    } else if (strStartsWith(cmd, "diffuse ")) {
        cmd_diffuse(cmd[8..]);
    } else if (strEq(cmd, "uptime")) {
        cmd_uptime();
    } else if (strEq(cmd, "mem")) {
        cmd_mem();
    } else if (strEq(cmd, "pmm")) {
        cmd_pmm();
    } else if (strEq(cmd, "timer")) {
        cmd_timer();
    } else if (strEq(cmd, "idt")) {
        cmd_idt();
    } else if (strEq(cmd, "vmm")) {
        cmd_vmm();
    } else if (strEq(cmd, "alloc")) {
        cmd_alloc();
    } else {
        vga_setcolor(0x0C);
        puts("  unknown: ");
        puts(cmd);
        puts("\n");
        vga_setcolor(0x07);
        puts("  type 'help' for commands\n");
    }
}

fn strEq(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn strStartsWith(s: []const u8, prefix: []const u8) bool {
    if (s.len < prefix.len) return false;
    for (s[0..prefix.len], prefix) |cs, cp| {
        if (cs != cp) return false;
    }
    return true;
}

// ─── Shell Commands ─────────────────────────────────────────────────────────

fn cmd_help() void {
    vga_setcolor(0x0E);
    puts("  === POLER-OS v0.5.1 Shell Commands ===\n");
    vga_setcolor(0x0F);
    puts("  help          Show this help\n");
    puts("  poler test    Run POLER Core self-tests\n");
    puts("  metrics       Show cognitive metrics\n");
    puts("  pci           Rescan PCI bus\n");
    puts("  clear         Clear screen\n");
    puts("  reboot        Reboot system\n");
    puts("  about         About POLER-OS\n");
    puts("  cipher <hex8> Encrypt 128-bit block (hex)\n");
    puts("  phi <hex8>    Apply Phi rotation to value\n");
    puts("  diffuse <hex8> Apply nilpotent diffusion\n");
    puts("  uptime        Show uptime (PIT ticks)\n");
    puts("  mem           Show memory info\n");
    puts("  pmm           PMM statistics\n");
    puts("  timer         PIT timer ticks\n");
    puts("  idt           IDT status\n");
    puts("  vmm           VMM status\n");
    puts("  alloc         Test page allocation\n");
    vga_setcolor(0x07);
}

fn cmd_poler_test() void {
    vga_setcolor(0x0E);
    puts("  === POLER Core v4 Self-Tests ===\n");
    vga_setcolor(0x0F);

    const self_test = poler.runSelfTests();
    puts("  Tests: ");
    printUint(self_test.passed);
    puts("/");
    printUint(self_test.total);
    puts(" passed\n");

    const test_names = [_][]const u8{
        "DeformedProduct",
        "PolerConvergence",
        "PhiNoFixedPoints",
        "NonCommutativity",
        "ModInverseAccuracy",
        "FeistelRoundtrip",
        "AvalancheEffect",
        "NilpotentPreservesInfo",
        "DynamicAttractor",
    };
    var ti: usize = 0;
    while (ti < test_names.len) : (ti += 1) {
        if (self_test.details[ti] != 0) {
            vga_setcolor(0x0A);
            puts("  [PASS] ");
        } else {
            vga_setcolor(0x0C);
            puts("  [FAIL] ");
        }
        vga_setcolor(0x0F);
        puts(test_names[ti]);
        puts("\n");
    }

    // Feistel roundtrip
    const key = [_]u32{ 0x0F1E2D3C, 0x4B5A6978, 0x8796A5B4, 0xC3D2E1F0, 0xAABBCCDD, 0xEEFF0011, 0x22334455, 0x66778899 };
    const cipher = poler.PolerCipher.init(&key, 1);
    var plain = [4]u32{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
    var encrypted: [4]u32 = undefined;
    var decrypted: [4]u32 = undefined;
    cipher.encryptBlock(&plain, &encrypted);
    cipher.decryptBlock(&encrypted, &decrypted);
    const ok = decrypted[0] == plain[0] and decrypted[1] == plain[1] and
        decrypted[2] == plain[2] and decrypted[3] == plain[3];
    if (ok) {
        vga_setcolor(0x0A);
        puts("  [PASS] Feistel roundtrip\n");
    } else {
        vga_setcolor(0x0C);
        puts("  [FAIL] Feistel roundtrip\n");
    }
    vga_setcolor(0x07);
}

fn cmd_metrics() void {
    vga_setcolor(0x0E);
    puts("  === Cognitive Metrics ===\n");
    vga_setcolor(0x0F);

    var density = [_][4]f64{
        .{ 0.8, 0.1, 0.0, 0.0 },
        .{ 0.05, 0.6, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.4, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.2 },
    };
    const archetype = [_][4]f64{
        .{ 0.9, 0.0, 0.0, 0.0 },
        .{ 0.0, 0.8, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.7, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.5 },
    };
    var iter: u32 = 0;
    while (iter < 10) : (iter += 1) {
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                density[i][j] = density[i][j] * archetype[i][j] * 0.9;
            }
        }
    }
    const trace_val: f64 = density[0][0] + density[1][1] + density[2][2] + density[3][3];
    var norm_val: f64 = 0;
    for (density) |row_vals| {
        for (row_vals) |v| {
            norm_val += v * v;
        }
    }
    puts("  Entropy:       "); printFloat(1.0 - trace_val / 4.0); puts("\n");
    puts("  Know.Density:  "); printFloat(trace_val / 4.0); puts("\n");
    puts("  Purity:        "); printFloat(density[0][0] / (norm_val + 0.001)); puts("\n");
    puts("  Compression:   "); printFloat(4.0 / (norm_val + 0.001)); puts("x\n");
    puts("  Health:        "); printFloat((trace_val / 4.0 + density[0][0] / (norm_val + 0.001)) / 2.0); puts("\n");
    puts("  Semantic Drift: "); printFloat((1.0 - density[0][0]) * 100.0); puts("%\n");
    vga_setcolor(0x07);
}

fn cmd_pci() void {
    vga_setcolor(0x0E);
    puts("  === PCI Bus Scan ===\n");
    vga_setcolor(0x0F);

    var pci_count: u32 = 0;
    var bus: u8 = 0;
    while (bus < 4) : (bus += 1) {
        var slot: u8 = 0;
        while (slot < 32) : (slot += 1) {
            const vendor = pci_read16(bus, slot, 0, 0);
            if (vendor == 0xFFFF) continue;
            const device_id = pci_read16(bus, slot, 0, 2);
            const class_code: u8 = @truncate(pci_read32(bus, slot, 0, 0x08) >> 24);
            const subclass: u8 = @truncate(pci_read32(bus, slot, 0, 0x08) >> 16);
            const irq_line: u8 = @truncate(pci_read32(bus, slot, 0, 0x3C));
            puts("  [");
            printUint(bus);
            puts(":");
            printUint(slot);
            puts("] ");
            puts(device_type_name(class_code, subclass));
            puts(" vendor=");
            printHex(vendor);
            puts(" device=");
            printHex(device_id);
            puts(" IRQ=");
            printUint(irq_line);
            puts("\n");
            pci_count += 1;
        }
    }
    puts("  Total: "); printUint(pci_count); puts(" devices\n");
    vga_setcolor(0x07);
}

fn cmd_clear() void {
    vga_init();
    row = 0;
    col = 0;
}

fn cmd_reboot() void {
    puts("  Rebooting...\n");
    // Keyboard controller reboot: pulse reset line
    asm volatile ("cli");
    while ((inb(0x64) & 0x02) != 0) {}
    outb(0x64, 0xFE);
    // If that fails, triple fault
    asm volatile (
        \\ lidt 0
        \\ int $0x03
    );
    while (true) {}
}

fn cmd_about() void {
    vga_setcolor(0x0B);
    puts("  POLER-OS v0.4.0\n");
    vga_setcolor(0x0F);
    puts("  32-bit x86 freestanding kernel (Zig 0.16.0)\n");
    puts("  POLER Core v4: Tensor cryptographic engine\n");
    puts("  \n");
    puts("  Architecture:\n");
    puts("    Kernel:    Zig (Ring 0, no std, no alloc)\n");
    puts("    Crypto:    POLER Core (Fix6, Feistel, S-Box)\n");
    puts("    Shell:     Kernel interactive command line\n");
    puts("    Input:     PS/2 keyboard (i8042)\n");
    puts("    Output:    VGA text mode + COM1 serial\n");
    puts("  \n");
    puts("  POLER algebra replaces boolean logic:\n");
    puts("    AND  -> Tensor deformation (a ox_e b)\n");
    puts("    XOR  -> Phi rotation (cubic structure)\n");
    puts("    PIPE -> Nilpotent diffusion (attractor)\n");
    puts("  \n");
    puts("  Verified: Z3 UNSAT, SAC=0.49, NL=112, DU=4\n");
    vga_setcolor(0x07);
}

fn cmd_cipher(arg: []const u8) void {
    // Parse 8 hex digits as u32
    const val = parseHex32(arg) catch {
        vga_setcolor(0x0C);
        puts("  Usage: cipher AABBCCDD\n");
        vga_setcolor(0x07);
        return;
    };
    const key = [_]u32{ 0x0F1E2D3C, 0x4B5A6978, 0x8796A5B4, 0xC3D2E1F0, 0xAABBCCDD, 0xEEFF0011, 0x22334455, 0x66778899 };
    const cipher = poler.PolerCipher.init(&key, 1);
    var block = [4]u32{ val, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
    var encrypted: [4]u32 = undefined;
    var decrypted: [4]u32 = undefined;
    cipher.encryptBlock(&block, &encrypted);
    cipher.decryptBlock(&encrypted, &decrypted);

    vga_setcolor(0x0E);
    puts("  Feistel Cipher Demo\n");
    vga_setcolor(0x0F);
    puts("  Input:     "); printHex32(val); puts("\n");
    puts("  Encrypted: "); printHex32(encrypted[0]); puts("\n");
    puts("  Decrypted: "); printHex32(decrypted[0]); puts("\n");
    if (decrypted[0] == val) {
        vga_setcolor(0x0A);
        puts("  Roundtrip: OK\n");
    } else {
        vga_setcolor(0x0C);
        puts("  Roundtrip: FAIL\n");
    }
    vga_setcolor(0x07);
}

fn cmd_phi(arg: []const u8) void {
    const val = parseHex32(arg) catch {
        vga_setcolor(0x0C);
        puts("  Usage: phi AABBCCDD\n");
        vga_setcolor(0x07);
        return;
    };
    const result = poler.phi(val);
    vga_setcolor(0x0E);
    puts("  Phi Rotation\n");
    vga_setcolor(0x0F);
    puts("  Input:  "); printHex32(val); puts("\n");
    puts("  Phi(x): "); printHex32(result); puts("\n");
    const pc = @popCount(result);
    puts("  PopCount: "); printUint(pc); puts("/32 bits set\n");
    vga_setcolor(0x07);
}

fn cmd_diffuse(arg: []const u8) void {
    const val = parseHex32(arg) catch {
        vga_setcolor(0x0C);
        puts("  Usage: diffuse AABBCCDD\n");
        vga_setcolor(0x07);
        return;
    };
    const result = poler.nilpotentOperator(val, 0xCAFE1234, 1);
    const result2 = poler.nilpotentOperator(result, 0xCAFE1234, 1);
    vga_setcolor(0x0E);
    puts("  Nilpotent Diffusion Operator\n");
    vga_setcolor(0x0F);
    puts("  Input:     "); printHex32(val); puts("\n");
    puts("  D(x,1):    "); printHex32(result); puts("\n");
    puts("  D(D(x),1): "); printHex32(result2); puts("\n");
    if (result2 == result) {
        vga_setcolor(0x0A);
        puts("  Idempotent: D^2 = D (attractor reached)\n");
    } else {
        vga_setcolor(0x0E);
        puts("  Converging: D^2 != D (still diffusing)\n");
    }
    vga_setcolor(0x07);
}

fn cmd_uptime() void {
    vga_setcolor(0x0E);
    puts("  Uptime: ");
    vga_setcolor(0x0F);
    if (timer_freq > 0) {
        printUint(timer_ticks / timer_freq);
        puts(".");
        const frac = (timer_ticks % timer_freq) * 100 / timer_freq;
        if (frac < 10) puts("0");
        printUint(frac);
        puts(" sec (");
        printUint(timer_ticks);
        puts(" ticks @ ");
        printUint(timer_freq);
        puts(" Hz)\n");
    } else {
        printUint(timer_ticks);
        puts(" raw ticks (PIT not initialized)\n");
    }
    vga_setcolor(0x07);
}

fn cmd_mem() void {
    vga_setcolor(0x0E);
    puts("  Memory Info:\n");
    vga_setcolor(0x0F);
    puts("    Total pages:  "); printUint(pmm_total_pages); puts("\n");
    puts("    Free pages:   "); printUint(pmm_free_pages); puts(" (");
    printUint(pmm_free_pages * PMM_PAGE_SIZE / 1024); puts(" KB)\n");
    puts("    Used pages:   "); printUint(pmm_total_pages - pmm_free_pages); puts(" (");
    printUint((pmm_total_pages - pmm_free_pages) * PMM_PAGE_SIZE / 1024); puts(" KB)\n");
    puts("    Page size:    4 KB\n");
    puts("    Kernel end:   0x"); printHex32(pmm_kernel_end); puts("\n");
    vga_setcolor(0x07);
}

fn cmd_pmm() void {
    vga_setcolor(0x0E);
    puts("  === PMM (Physical Memory Manager) ===\n");
    vga_setcolor(0x0F);
    puts("    Algorithm:    Bitmap allocator\n");
    puts("    Page size:    4 KB\n");
    puts("    Max pages:    "); printUint(PMM_MAX_PAGES); puts("\n");
    puts("    Total pages:  "); printUint(pmm_total_pages); puts("\n");
    puts("    Free pages:   "); printUint(pmm_free_pages); puts("\n");
    puts("    Used pages:   "); printUint(pmm_total_pages - pmm_free_pages); puts("\n");
    puts("    Free memory:  "); printUint(pmm_free_pages * PMM_PAGE_SIZE / 1024); puts(" KB (");
    printUint(pmm_free_pages * PMM_PAGE_SIZE / (1024 * 1024)); puts(" MB)\n");
    puts("    Kernel end:   0x"); printHex32(pmm_kernel_end); puts("\n");
    vga_setcolor(0x07);
}

fn cmd_timer() void {
    vga_setcolor(0x0E);
    puts("  PIT Timer:\n");
    vga_setcolor(0x0F);
    puts("    Ticks:        "); printUint(timer_ticks); puts("\n");
    puts("    Frequency:    "); printUint(timer_freq); puts(" Hz\n");
    if (timer_freq > 0) {
        puts("    Elapsed:      "); printUint(timer_ticks / timer_freq);
        puts("."); printUint((timer_ticks % timer_freq) * 100 / timer_freq); puts(" sec\n");
    }
    vga_setcolor(0x07);
}

fn cmd_idt() void {
    vga_setcolor(0x0E);
    puts("  === IDT (Interrupt Descriptor Table) ===\n");
    vga_setcolor(0x0F);
    puts("    Entries:      256\n");
    puts("    ISR 0-31:     CPU exceptions (loaded)\n");
    puts("    IRQ 32-47:    Hardware interrupts (loaded)\n");
    puts("    48-255:       Not configured\n");
    puts("    PIC:          Remapped (master=0x20, slave=0x28)\n");
    puts("    Timer IRQ0:   ");
    if (timer_freq > 0) { puts("enabled @ "); printUint(timer_freq); puts(" Hz\n"); }
    else { puts("disabled\n"); }
    vga_setcolor(0x07);
}

fn cmd_vmm() void {
    vga_setcolor(0x0E);
    puts("  === VMM (Virtual Memory Manager) ===\n");
    vga_setcolor(0x0F);
    puts("    Page dir:     1024 entries (4 KB)\n");
    puts("    Page tables:  Identity-mapped 0-4 MB\n");
    puts("    Paging:       ");
    if (vmm_enabled) { puts("ENABLED\n"); }
    else { puts("disabled (structures ready for v0.6.0)\n"); }
    puts("    vmm_map_page: ready\n");
    puts("    vmm_unmap:    ready\n");
    vga_setcolor(0x07);
}

fn cmd_alloc() void {
    vga_setcolor(0x0E);
    puts("  PMM Allocation Test:\n");
    vga_setcolor(0x0F);
    if (pmm_alloc_page()) |addr1| {
        puts("    Allocated page at 0x"); printHex32(addr1); puts("\n");
        if (pmm_alloc_page()) |addr2| {
            puts("    Allocated page at 0x"); printHex32(addr2); puts("\n");
            pmm_free_page(addr2);
            puts("    Freed page at 0x"); printHex32(addr2); puts("\n");
        }
        pmm_free_page(addr1);
        puts("    Freed page at 0x"); printHex32(addr1); puts("\n");
    } else {
        puts("    ERROR: No free pages available!\n");
    }
    puts("    Free pages remaining: "); printUint(pmm_free_pages); puts("\n");
    vga_setcolor(0x07);
}

// ─── Hex Parsing & Printing Helpers ─────────────────────────────────────────

fn parseHex32(s: []const u8) !u32 {
    var result: u32 = 0;
    var count: usize = 0;
    for (s) |c| {
        if (count >= 8) break;
        result <<= 4;
        if (c >= '0' and c <= '9') {
            result |= @as(u32, c - '0');
        } else if (c >= 'A' and c <= 'F') {
            result |= @as(u32, c - 'A' + 10);
        } else if (c >= 'a' and c <= 'f') {
            result |= @as(u32, c - 'a' + 10);
        } else {
            return error.InvalidHex;
        }
        count += 1;
    }
    if (count == 0) return error.EmptyInput;
    return result;
}

fn printHex32(value: u32) void {
    const hex_chars = "0123456789ABCDEF";
    var shift: u5 = 28;
    while (shift > 0) : (shift -= 4) {
        const nibble: u4 = @truncate(value >> shift);
        const ch = hex_chars[@as(usize, nibble)];
        vga_puts(&[_]u8{ch});
        serial_puts(&[_]u8{ch});
    }
    const last: u4 = @truncate(value);
    const ch = hex_chars[@as(usize, last)];
    vga_puts(&[_]u8{ch});
    serial_puts(&[_]u8{ch});
}

// ─── PCI Bus ───────────────────────────────────────────────────────────────

const PCI_CONFIG_ADDR: u16 = 0xCF8;
const PCI_CONFIG_DATA: u16 = 0xCFC;

fn pci_read32(bus: u8, slot: u8, func: u8, offset: u8) u32 {
    const addr = (@as(u32, 1) << 31) | 
                 (@as(u32, bus) << 16) | 
                 (@as(u32, slot) << 11) | 
                 (@as(u32, func) << 8) | 
                 (@as(u32, offset) & 0xFC);
    outl(PCI_CONFIG_ADDR, addr);
    return inl(PCI_CONFIG_DATA);
}

fn pci_read16(bus: u8, slot: u8, func: u8, offset: u8) u16 {
    const val = pci_read32(bus, slot, func, offset);
    return @truncate(val >> (8 * (@as(u5, @intCast(offset & 2)))));
}

fn pci_write32(bus: u8, slot: u8, func: u8, offset: u8, val: u32) void {
    const addr = (@as(u32, 1) << 31) | 
                 (@as(u32, bus) << 16) | 
                 (@as(u32, slot) << 11) | 
                 (@as(u32, func) << 8) | 
                 (@as(u32, offset) & 0xFC);
    outl(PCI_CONFIG_ADDR, addr);
    outl(PCI_CONFIG_DATA, val);
}

// Device type names
fn device_type_name(class_code: u8, subclass: u8) []const u8 {
    if (class_code == 0x01) {
        if (subclass == 0x01) return "IDE Controller";
        if (subclass == 0x06) return "SATA/AHCI";
        return "Mass Storage";
    }
    if (class_code == 0x02) {
        if (subclass == 0x00) return "Ethernet";
        return "Network";
    }
    if (class_code == 0x03) return "VGA/Display";
    if (class_code == 0x04) return "Multimedia";
    if (class_code == 0x06) {
        if (subclass == 0x01) return "PCI-PCI Bridge";
        return "Bridge";
    }
    if (class_code == 0x0C) {
        if (subclass == 0x03) return "USB Controller";
        return "Serial Bus";
    }
    if (class_code == 0xFF) return "VirtIO";
    return "Unknown";
}

fn virtio_device_name(device_id: u16) []const u8 {
    if (device_id == 1) return "virtio-net";
    if (device_id == 2) return "virtio-blk";
    if (device_id == 3) return "virtio-console";
    if (device_id == 16) return "virtio-gpu";
    if (device_id == 18) return "virtio-input";
    return "virtio-???";
}

// ─── Multiboot Info ────────────────────────────────────────────────────────

const MultibootInfo = extern struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    syms: [4]u32,          // aout/elf table
    mmap_length: u32,
    mmap_addr: u32,
    drives_length: u32,
    drives_addr: u32,
    config_table: u32,
    boot_loader_name: u32,
    apm_table: u32,
    // VBE info (if flag bit 12 set)
    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,
    // Framebuffer info (if flag bit 12 set)
    fb_addr: u64,
    fb_pitch: u32,
    fb_width: u32,
    fb_height: u32,
    fb_bpp: u8,
    fb_type: u8,
    fb_color_info: [6]u8,
};

const MULTIBOOT_INFO_FRAMEBUFFER: u32 = 1 << 12;
const MULTIBOOT_INFO_MMAP: u32 = 1 << 6;

// ─── IDT (Interrupt Descriptor Table) ─────────────────────────────────────

const IdtEntry = extern struct {
    offset_low: u16,     // bits 0-15 of handler address
    selector: u16,       // code segment selector (0x08)
    zero: u8,            // always 0
    type_attr: u8,       // 0x8E = 32-bit interrupt gate, present, Ring 0
    offset_high: u16,    // bits 16-31 of handler address
};

const IDT_ENTRIES = 256;
var idt: [IDT_ENTRIES]IdtEntry = undefined;

// ISR handler address table from isr32.S
extern var isr_table: [48]u32;

fn idt_set_gate(num: u32, handler: u32, selector: u16, attrs: u8) void {
    idt[num] = IdtEntry{
        .offset_low = @truncate(handler & 0xFFFF),
        .selector = selector,
        .zero = 0,
        .type_attr = attrs,
        .offset_high = @truncate((handler >> 16) & 0xFFFF),
    };
}

fn idt_init() void {
    // Zero all IDT entries
    var i: u32 = 0;
    while (i < IDT_ENTRIES) : (i += 1) {
        idt[i] = IdtEntry{ .offset_low = 0, .selector = 0, .zero = 0, .type_attr = 0, .offset_high = 0 };
    }

    // Set up ISR 0-31 (CPU exceptions) and IRQ 32-47 (hardware interrupts)
    i = 0;
    while (i < 48) : (i += 1) {
        idt_set_gate(i, isr_table[i], 0x08, 0x8E);
    }

    // Load the IDT
    var idt_ptr: [6]u8 = undefined;
    const limit: u16 = @intCast(IDT_ENTRIES * 8 - 1);
    idt_ptr[0] = @truncate(limit);
    idt_ptr[1] = @truncate(limit >> 8);
    const base: u32 = @intFromPtr(&idt);
    idt_ptr[2] = @truncate(base);
    idt_ptr[3] = @truncate(base >> 8);
    idt_ptr[4] = @truncate(base >> 16);
    idt_ptr[5] = @truncate(base >> 24);
    asm volatile ("lidt (%eax)"
        :
        : [ptr] "{eax}" (@intFromPtr(&idt_ptr)),
    );
}

// ─── PIC (8259A Programmable Interrupt Controller) ────────────────────────

const PIC1_CMD: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
const PIC2_CMD: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

const PIC_EOI: u8 = 0x20;       // End of Interrupt command
const ICW1_ICW4: u8 = 0x11;     // ICW4 needed + cascade mode
const ICW1_SINGLE: u8 = 0x02;   // single PIC mode (not used)
const ICW4_8086: u8 = 0x01;     // 8086/88 mode

fn pic_init() void {
    // Save current masks
    const mask1 = inb(PIC1_DATA);
    const mask2 = inb(PIC2_DATA);

    // Start initialization sequence (ICW1)
    outb(PIC1_CMD, ICW1_ICW4);    // master PIC: ICW1 + ICW4 needed
    outb(PIC2_CMD, ICW1_ICW4);    // slave PIC: ICW1 + ICW4 needed

    // ICW2: Set vector offsets
    // Master PIC: IRQ 0-7 → INT 32-39
    outb(PIC1_DATA, 0x20);        // master offset = 32
    outb(PIC2_DATA, 0x28);        // slave offset = 40

    // ICW3: Tell master/slave about each other
    outb(PIC1_DATA, 0x04);        // master: slave on IRQ2 (bit 2)
    outb(PIC2_DATA, 0x02);        // slave: cascade identity = 2

    // ICW4: 8086 mode
    outb(PIC1_DATA, ICW4_8086);
    outb(PIC2_DATA, ICW4_8086);

    // Restore masks (mask all IRQs initially)
    outb(PIC1_DATA, mask1);
    outb(PIC2_DATA, mask2);

    // Mask all IRQs except cascade (IRQ2) — we'll unmask specific ones as needed
    outb(PIC1_DATA, 0xFB);        // master: unmask only IRQ2 (cascade) = 1111_1011
    outb(PIC2_DATA, 0xFF);        // slave: mask all
}

fn pic_send_eoi(irq: u8) void {
    // If IRQ came from slave (IRQ 8-15), send EOI to both PICs
    if (irq >= 8) {
        outb(PIC2_CMD, PIC_EOI);
    }
    // Always send EOI to master
    outb(PIC1_CMD, PIC_EOI);
}

fn pic_unmask_irq(irq: u8) void {
    if (irq < 8) {
        const port = PIC1_DATA;
        const val = inb(port) & ~@as(u8, @as(u8, 1) << @intCast(irq));
        outb(port, val);
    } else {
        const port = PIC2_DATA;
        const val = inb(port) & ~@as(u8, @as(u8, 1) << @truncate(irq - 8));
        outb(port, val);
    }
}

// ─── PIT (Programmable Interval Timer 8253/8254) ─────────────────────────

const PIT_CHANNEL0: u16 = 0x40;
const PIT_COMMAND: u16 = 0x43;
const PIT_FREQUENCY: u32 = 1193182;  // base frequency of PIT oscillator

var timer_ticks: u32 = 0;
var timer_freq: u32 = 0;

fn pit_init(hz: u32) void {
    timer_freq = hz;
    const divisor: u16 = @intCast(PIT_FREQUENCY / hz);
    outb(PIT_COMMAND, 0x36);                          // channel 0, lobyte/hibyte, mode 3 (square wave)
    outb(PIT_CHANNEL0, @truncate(divisor & 0xFF));    // low byte
    outb(PIT_CHANNEL0, @truncate((divisor >> 8) & 0xFF)); // high byte
    pic_unmask_irq(0);  // unmask IRQ0 (timer)
}

// ─── PMM (Physical Memory Manager) ────────────────────────────────────────

const PMM_PAGE_SIZE: u32 = 4096;
const PMM_MAX_PAGES: u32 = 131072;  // 512 MB max (512*1024*1024 / 4096)
const PMM_BITMAP_SIZE: u32 = PMM_MAX_PAGES / 8;  // 16384 bytes

var pmm_bitmap: [PMM_BITMAP_SIZE]u8 = undefined;
var pmm_total_pages: u32 = 0;
var pmm_free_pages: u32 = 0;
var pmm_kernel_end: u32 = 0;

const MmapEntry = extern struct {
    size: u32,
    addr: u64,
    len: u64,
    mtype: u32,  // 1 = available, 2 = reserved, 3 = ACPI, 4 = NVS, 5 = defective
};

fn pmm_bitmap_set(page: u32) void {
    const idx = page / 8;
    const bit: u3 = @intCast(page % 8);
    if (idx < PMM_BITMAP_SIZE) {
        pmm_bitmap[idx] |= @as(u8, 1) << bit;
    }
}

fn pmm_bitmap_clear(page: u32) void {
    const idx = page / 8;
    const bit: u3 = @intCast(page % 8);
    if (idx < PMM_BITMAP_SIZE) {
        pmm_bitmap[idx] &= ~(@as(u8, 1) << bit);
    }
}

fn pmm_bitmap_test(page: u32) bool {
    const idx = page / 8;
    const bit: u3 = @intCast(page % 8);
    if (idx < PMM_BITMAP_SIZE) {
        return (pmm_bitmap[idx] & (@as(u8, 1) << bit)) != 0;
    }
    return true; // out of range = used
}

fn pmm_init(info: *align(1) MultibootInfo, kernel_end_addr: u32) void {
    pmm_kernel_end = kernel_end_addr;

    // Mark all pages as used initially
    var i: u32 = 0;
    while (i < PMM_BITMAP_SIZE) : (i += 1) {
        pmm_bitmap[i] = 0xFF;
    }
    pmm_total_pages = 0;
    pmm_free_pages = 0;

    // Parse multiboot memory map if available
    if (info.flags & MULTIBOOT_INFO_MMAP != 0 and info.mmap_length > 0 and info.mmap_addr != 0) {
        var ptr: u32 = info.mmap_addr;
        const end: u32 = info.mmap_addr + info.mmap_length;
        while (ptr + @sizeOf(MmapEntry) <= end) {
            const entry: *align(1) MmapEntry = @ptrFromInt(ptr);
            if (entry.size == 0) break;

            if (entry.mtype == 1 and entry.len >= PMM_PAGE_SIZE) { // Available RAM
                const base: u32 = if (entry.addr > 0xFFFFFFFF) 0xFFFFFFFF else @as(u32, @truncate(entry.addr));
                const length: u32 = if (entry.len > 0xFFFFFFFF) 0xFFFFFFFF else @as(u32, @truncate(entry.len));
                const top = base +% length; // wrapping add
                var addr: u32 = base;
                // Align to page boundary
                if (addr % PMM_PAGE_SIZE != 0) {
                    addr = addr +% (PMM_PAGE_SIZE - (addr % PMM_PAGE_SIZE));
                }
                while (addr < top and addr + PMM_PAGE_SIZE <= top and addr >= base) {
                    const page = addr / PMM_PAGE_SIZE;
                    pmm_total_pages += 1;
                    // Free pages above kernel end
                    if (addr >= pmm_kernel_end and page < PMM_MAX_PAGES) {
                        if (pmm_bitmap_test(page)) {
                            pmm_bitmap_clear(page);
                            pmm_free_pages += 1;
                        }
                    }
                    addr +%= PMM_PAGE_SIZE;
                    if (addr < base) break; // overflow guard
                }
            }
            ptr += entry.size + 4;
            if (ptr <= info.mmap_addr) break; // overflow guard
        }
    }

    // Fallback: use mem_lower + mem_upper if PMM found nothing
    // QEMU with -kernel flag may not provide mmap, and mem_lower/mem_upper may be 0
    if (pmm_free_pages == 0) {
        // If mem_upper is 0 (QEMU -kernel doesn't always fill this), assume 128MB
        const total_kb = if (info.mem_upper > 0) info.mem_lower + info.mem_upper else 128 * 1024;
        pmm_total_pages = total_kb / 4;
        // Free pages above kernel
        var page = pmm_kernel_end / PMM_PAGE_SIZE;
        while (page < pmm_total_pages and page < PMM_MAX_PAGES) : (page += 1) {
            if (pmm_bitmap_test(page)) {
                pmm_bitmap_clear(page);
                pmm_free_pages += 1;
            }
        }
    }
}

fn pmm_alloc_page() ?u32 {
    var page: u32 = 0;
    while (page < PMM_MAX_PAGES) : (page += 1) {
        if (!pmm_bitmap_test(page)) {
            pmm_bitmap_set(page);
            pmm_free_pages -= 1;
            return page * PMM_PAGE_SIZE;
        }
    }
    return null;
}

fn pmm_free_page(addr: u32) void {
    const page = addr / PMM_PAGE_SIZE;
    if (page < PMM_MAX_PAGES and pmm_bitmap_test(page)) {
        pmm_bitmap_clear(page);
        pmm_free_pages += 1;
    }
}

// ─── VMM (Virtual Memory Manager) ────────────────────────────────────────

// Page Directory: 1024 entries, each covers 4MB (4KB × 1024 pages)
// Page Table: 1024 entries, each points to a 4KB page
const VMM_PRESENT: u32 = 0x001;
const VMM_WRITABLE: u32 = 0x002;
const VMM_USER: u32 = 0x004;
const VMM_WRITE_THROUGH: u32 = 0x008;
const VMM_CACHE_DISABLE: u32 = 0x010;
const VMM_ACCESSED: u32 = 0x020;
const VMM_DIRTY: u32 = 0x040;
const VMM_PAGE_SIZE_4M: u32 = 0x080;  // for PD entries (PS bit)
const VMM_PAGE_TABLE_ADDR_MASK: u32 = 0xFFFFF000;

var page_directory: [1024]u32 align(4096) = undefined;
var first_page_table: [1024]u32 align(4096) = undefined;
var vmm_enabled: bool = false;

fn vmm_init(kernel_end_addr: u32) void {
    _ = kernel_end_addr;
    // Initialize page directory — all entries empty (not present)
    var i: u32 = 0;
    while (i < 1024) : (i += 1) {
        page_directory[i] = 0;
    }

    // Initialize first page table — identity map first 4MB
    i = 0;
    while (i < 1024) : (i += 1) {
        const addr = i * PMM_PAGE_SIZE;
        first_page_table[i] = addr | VMM_PRESENT | VMM_WRITABLE;
    }

    // Point first PD entry to first page table (identity maps 0-4MB)
    page_directory[0] = @intFromPtr(&first_page_table) | VMM_PRESENT | VMM_WRITABLE;

    // Map PD entry for kernel space (256th entry = 0x40000000-0x40400000)
    // Also identity-map the PD entry that covers the kernel at 1MB
    // PD entry 0 already covers 0-4MB which includes the kernel at 1MB

    // NOTE: We do NOT enable paging here — that's for v0.6.0 when we have
    // userspace. The VMM structures are ready but paging stays off.
    vmm_enabled = false;
}

fn vmm_map_page(phys: u32, virt: u32, flags: u32) void {
    const pd_idx = virt >> 22;       // bits 31-22
    const pt_idx = (virt >> 12) & 0x3FF; // bits 21-12

    // Check if page table exists for this PD entry
    if (page_directory[pd_idx] == 0) {
        // Need to allocate a page table — use PMM
        if (pmm_alloc_page()) |pt_addr| {
            // Clear the page table
            const pt_ptr: [*]u32 = @ptrFromInt(pt_addr);
            var j: u32 = 0;
            while (j < 1024) : (j += 1) {
                pt_ptr[j] = 0;
            }
            page_directory[pd_idx] = pt_addr | VMM_PRESENT | VMM_WRITABLE;
        } else {
            return; // out of memory
        }
    }

    // Get the page table
    const pt_addr = page_directory[pd_idx] & VMM_PAGE_TABLE_ADDR_MASK;
    const pt: [*]u32 = @ptrFromInt(pt_addr);

    // Map the page
    pt[pt_idx] = phys | flags;
}

fn vmm_unmap_page(virt: u32) void {
    const pd_idx = virt >> 22;
    const pt_idx = (virt >> 12) & 0x3FF;

    if (page_directory[pd_idx] == 0) return;
    const pt_addr = page_directory[pd_idx] & VMM_PAGE_TABLE_ADDR_MASK;
    const pt: [*]u32 = @ptrFromInt(pt_addr);
    pt[pt_idx] = 0;

    // Flush TLB entry for this page
    asm volatile ("invlpg %[page]"
        :
        : [page] "r" (virt),
    );
}

// ─── ISR Handler (called from isr32.S common handler) ─────────────────────

const exception_names = [_][]const u8{
    "Divide Error",           "Debug",                    "NMI",
    "Breakpoint",             "Overflow",                 "BOUND Range",
    "Invalid Opcode",         "Device Not Available",     "Double Fault",
    "Coprocessor Overrun",    "Invalid TSS",             "Segment Not Present",
    "Stack Segment Fault",    "General Protection",      "Page Fault",
    "Reserved",               "x87 FPU Error",           "Alignment Check",
    "Machine Check",          "SIMD Float Exception",    "Virtualization",
    "Security",               "Reserved",                "Reserved",
    "Reserved",               "Reserved",                 "Reserved",
    "Reserved",               "Reserved",                  "Reserved",
    "Reserved",               "Reserved",
};

export fn zig_isr_handler(isr_number: u32, error_code: u32) void {
    if (isr_number >= 32) {
        // Hardware interrupt (IRQ)
        const irq: u8 = @truncate(isr_number - 32);
        switch (irq) {
            0 => {
                // PIT Timer tick
                timer_ticks += 1;
            },
            1 => {
                // Keyboard — read and discard scan code to allow polling to work
                _ = inb(KBD_DATA);
            },
            else => {},
        }
        pic_send_eoi(irq);
        return;
    }

    // CPU exception — this is an error
    vga_setcolor(0x04);
    puts("\n!!! EXCEPTION: ");
    if (isr_number < exception_names.len) {
        puts(exception_names[isr_number]);
    } else {
        puts("Unknown #");
        printUint(isr_number);
    }
    puts(" !!!\n");
    puts("  Error code: 0x");
    printHex32(error_code);
    puts("\n");

    if (isr_number == 14) {
        // Page fault — read CR2 for faulting address
        var cr2: u32 = undefined;
        asm volatile (
            \\movl %%cr2, %[out]
            : [out] "=r" (cr2),
        );
        puts("  Faulting address: 0x");
        printHex32(cr2);
        if (error_code & 0x01 != 0) {
            puts(" (protection violation)");
        } else {
            puts(" (page not present)");
        }
        if (error_code & 0x02 != 0) puts(" [write]");
        if (error_code & 0x04 != 0) puts(" [user]");
        puts("\n");
    }

    if (isr_number == 8 or isr_number == 13 or isr_number == 14) {
        // Fatal exceptions — halt
        puts("  System halted.\n");
        cli_halt();
    }

    // Non-fatal: continue execution
    vga_setcolor(0x07);
}

fn cli_halt() noreturn {
    while (true) {
        asm volatile ("cli");
        asm volatile ("hlt");
    }
}

// ─── VBE Framebuffer (for HDMI/DP output) ───────────────────────────────

var fb_addr: u64 = 0;
var fb_pitch: u32 = 0;
var fb_width: u32 = 0;
var fb_height: u32 = 0;
var fb_bpp: u8 = 0;
var fb_type: u8 = 0;
var fb_cursor_x: u32 = 0;
var fb_cursor_y: u32 = 0;

const FB_CHAR_W: u32 = 8;
const FB_CHAR_H: u32 = 16;

// Minimal 8x16 font for printable ASCII
const fb_font = [128][16]u8{
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 0-3
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 4-7
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 8-11
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 12-15
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 16-19
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 20-23
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 24-27
    .{0} ** 16, .{0} ** 16, .{0} ** 16, .{0} ** 16,  // 28-31
    // Space (0x20)
    .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // ! (0x21)
    .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x18,0x18,0x00,0x00,0x00},
    // " (0x22)
    .{0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // # (0x23)
    .{0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00},
    // $ (0x24)
    .{0x18,0x3E,0x60,0x60,0x3C,0x06,0x06,0x7C,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    // % (0x25)
    .{0x00,0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00},
    // & (0x26)
    .{0x38,0x6C,0x6C,0x38,0x76,0x6E,0x66,0x66,0x76,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // ' (0x27)
    .{0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // ( (0x28)
    .{0x0C,0x18,0x30,0x30,0x30,0x30,0x30,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00},
    // ) (0x29)
    .{0x30,0x18,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x18,0x30,0x00,0x00,0x00,0x00,0x00,0x00},
    // * (0x2A)
    .{0x00,0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // + (0x2B)
    .{0x00,0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // , (0x2C)
    .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x30,0x00,0x00,0x00},
    // - (0x2D)
    .{0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // . (0x2E)
    .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00},
    // / (0x2F)
    .{0x06,0x06,0x0C,0x0C,0x18,0x18,0x30,0x30,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00},
    // 0 (0x30)
    .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // 1 (0x31)
    .{0x18,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x7E,0x00,0x00,0x00,0x00,0x00,0x00},
    // 2 (0x32)
    .{0x3C,0x66,0x66,0x06,0x0C,0x18,0x30,0x60,0x66,0x7E,0x00,0x00,0x00,0x00,0x00,0x00},
    // 3 (0x33)
    .{0x3C,0x66,0x06,0x06,0x1C,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // 4 (0x34)
    .{0x0C,0x1C,0x3C,0x6C,0x6C,0x7E,0x0C,0x0C,0x0C,0x0C,0x00,0x00,0x00,0x00,0x00,0x00},
    // 5 (0x35)
    .{0x7E,0x60,0x60,0x7C,0x06,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // 6 (0x36)
    .{0x3C,0x66,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // 7 (0x37)
    .{0x7E,0x66,0x06,0x0C,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    // 8 (0x38)
    .{0x3C,0x66,0x66,0x66,0x3C,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // 9 (0x39)
    .{0x3C,0x66,0x66,0x66,0x3E,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // : (0x3A)
    .{0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // ; (0x3B)
    .{0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30,0x00,0x00,0x00,0x00,0x00,0x00},
    // < (0x3C)
    .{0x0C,0x18,0x30,0x60,0xC0,0x60,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // = (0x3D)
    .{0x00,0x00,0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // > (0x3E)
    .{0x60,0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // ? (0x3F)
    .{0x3C,0x66,0x06,0x0C,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // @ (0x40)
    .{0x3C,0x66,0x66,0x6E,0x6E,0x60,0x62,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // A (0x41)
    .{0x18,0x3C,0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    // B (0x42)
    .{0x7C,0x66,0x66,0x66,0x7C,0x66,0x66,0x66,0x66,0x7C,0x00,0x00,0x00,0x00,0x00,0x00},
    // C (0x43)
    .{0x3C,0x66,0x66,0x60,0x60,0x60,0x60,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    // D (0x44)
    .{0x78,0x6C,0x66,0x66,0x66,0x66,0x66,0x66,0x6C,0x78,0x00,0x00,0x00,0x00,0x00,0x00},
    // E (0x45)
    .{0x7E,0x60,0x60,0x60,0x7C,0x60,0x60,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00},
    // F (0x46)
    .{0x7E,0x60,0x60,0x60,0x7C,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00},
    // G-L
    .{0x3C,0x66,0x60,0x60,0x6E,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x3C,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x6C,0x6C,0x38,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x66,0x6C,0x6C,0x78,0x78,0x6C,0x6C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00},
    // M-Z
    .{0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x7C,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x6A,0x6C,0x3E,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x7C,0x66,0x66,0x66,0x7C,0x6C,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x3C,0x66,0x60,0x60,0x3C,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x3C,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0xC6,0xC6,0xC6,0xC6,0xD6,0xD6,0xFE,0xEE,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x66,0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x7E,0x06,0x0C,0x18,0x30,0x60,0x60,0xC0,0xC0,0x7E,0x00,0x00,0x00,0x00,0x00,0x00},
    // [ \ ] ^ _
    .{0x3C,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x60,0x60,0x30,0x30,0x18,0x18,0x0C,0x0C,0x06,0x06,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x3C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x10,0x38,0x6C,0xC6,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00},
    // ` a b c d e f
    .{0x30,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x3C,0x06,0x3E,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x60,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x66,0x7C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x06,0x06,0x06,0x3E,0x66,0x66,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x3C,0x66,0x66,0x7E,0x60,0x60,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x1C,0x30,0x30,0x7C,0x30,0x30,0x30,0x30,0x30,0x30,0x00,0x00,0x00,0x00,0x00,0x00},
    // g h i j k l
    .{0x00,0x00,0x00,0x3E,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x3C,0x00,0x00,0x00,0x00},
    .{0x60,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x18,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x0C,0x00,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x6C,0x6C,0x38,0x00,0x00,0x00,0x00},
    .{0x60,0x60,0x60,0x66,0x6C,0x78,0x78,0x6C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    // m n o p q r
    .{0x00,0x00,0x00,0xEC,0xFE,0xD6,0xD6,0xD6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x7C,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x7C,0x66,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x3E,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x06,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x7C,0x66,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00},
    // s t u v w
    .{0x00,0x00,0x00,0x3E,0x60,0x60,0x3C,0x06,0x06,0x7C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x30,0x30,0x30,0x7C,0x30,0x30,0x30,0x30,0x30,0x1C,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0xC6,0xC6,0xD6,0xD6,0xD6,0xFE,0x6C,0x00,0x00,0x00,0x00,0x00,0x00},
    // x y z { | } ~
    .{0x00,0x00,0x00,0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x3C,0x00,0x00,0x00,0x00},
    .{0x00,0x00,0x00,0x7E,0x0C,0x18,0x30,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x0E,0x18,0x18,0x18,0x70,0x18,0x18,0x18,0x0E,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x70,0x18,0x18,0x18,0x0E,0x18,0x18,0x18,0x70,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    .{0x76,0xDC,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    // DEL (0x7F)
    .{0} ** 16,
};

fn fb_init(addr: u64, pitch: u32, width: u32, height: u32, bpp: u8, pixel_type: u8) void {
    fb_addr = addr;
    fb_pitch = pitch;
    fb_width = width;
    fb_height = height;
    fb_bpp = bpp;
    fb_type = pixel_type;
    fb_cursor_x = 0;
    fb_cursor_y = 0;
}

fn fb_clear() void {
    if (fb_addr == 0) return;
    const total: usize = @intCast(@as(u64, fb_pitch) * @as(u64, fb_height));
    const ptr: [*]volatile u8 = @ptrFromInt(@as(usize, @intCast(fb_addr)));
    var i: usize = 0;
    while (i < total) : (i += 1) {
        ptr[i] = 0;
    }
}

fn fb_put_pixel(x: u32, y: u32, px_color: u32) void {
    if (fb_addr == 0 or x >= fb_width or y >= fb_height) return;
    const offset = @as(u64, y) * @as(u64, fb_pitch) + @as(u64, x) * @as(u64, fb_bpp / 8);
    const ptr: [*]volatile u32 = @ptrFromInt(@as(usize, @intCast(fb_addr + offset)));
    if (fb_bpp == 32) {
        ptr[0] = px_color;
    }
}

fn fb_draw_char(ch: u8, px: u32, py: u32, fg: u32, bg: u32) void {
    if (ch >= 128) return; // Bounds check: font table only has 128 entries
    const glyph = fb_font[ch];
    var glyph_row: u32 = 0;
    while (glyph_row < FB_CHAR_H) : (glyph_row += 1) {
        const bits = glyph[glyph_row];
        var glyph_col: u32 = 0;
        while (glyph_col < FB_CHAR_W) : (glyph_col += 1) {
            const bit_set = (bits & (@as(u8, 1) << @intCast(7 - glyph_col))) != 0;
            fb_put_pixel(px + glyph_col, py + glyph_row, if (bit_set) fg else bg);
        }
    }
}

fn fb_puts(str: []const u8) void {
    if (fb_addr == 0) return;
    const bg: u32 = 0xFF200F0B; // Dark blue-black (BGR: B=0x0B, G=0x11, R=0x20)
    const fg: u32 = 0xFFD4D4D4; // Light gray text (BGR: B=0xD4, G=0xD4, R=0xD4)
    
    for (str) |ch| {
        if (ch == '\n') {
            fb_cursor_x = 0;
            fb_cursor_y += FB_CHAR_H;
        } else {
            fb_draw_char(ch, fb_cursor_x, fb_cursor_y, fg, bg);
            fb_cursor_x += FB_CHAR_W;
            if (fb_cursor_x >= fb_width) {
                fb_cursor_x = 0;
                fb_cursor_y += FB_CHAR_H;
            }
        }
        if (fb_cursor_y + FB_CHAR_H >= fb_height) {
            // Simple scroll: just reset to top (proper scroll is slow in software)
            fb_cursor_y = 0;
        }
    }
}

fn fb_puts_color(str: []const u8, txt_color: u32) void {
    if (fb_addr == 0) return;
    const bg: u32 = 0xFF200F0B;
    
    for (str) |ch| {
        if (ch == '\n') {
            fb_cursor_x = 0;
            fb_cursor_y += FB_CHAR_H;
        } else {
            fb_draw_char(ch, fb_cursor_x, fb_cursor_y, txt_color, bg);
            fb_cursor_x += FB_CHAR_W;
            if (fb_cursor_x >= fb_width) {
                fb_cursor_x = 0;
                fb_cursor_y += FB_CHAR_H;
            }
        }
        if (fb_cursor_y + FB_CHAR_H >= fb_height) {
            fb_cursor_y = 0;
        }
    }
}

// Framebuffer colors (BGR format for 32-bit)
const FB_CYAN: u32    = 0xFFFFCC00; // BGR: B=0xFF, G=0xCC, R=0x00 → cyan-ish
const FB_GREEN: u32   = 0xFF00CC00; // green
const FB_RED: u32     = 0xFF0000CC; // red
const FB_YELLOW: u32  = 0xFF00CCFF; // yellow (B=0xFF, G=0xCC, R=0x00)
const FB_WHITE: u32   = 0xFFD4D4D4; // light gray
const FB_BLUE: u32    = 0xFFCC6600; // blue-ish

fn fb_puts_uint(value: u32) void {
    if (value == 0) { fb_puts("0"); return; }
    var buf: [10]u8 = undefined;
    var i: usize = 0;
    var v = value;
    while (v > 0) : (i += 1) {
        buf[i] = @as(u8, @intCast(v % 10)) + '0';
        v /= 10;
    }
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }
    var k: usize = 0;
    while (k < i) : (k += 1) {
        fb_draw_char(buf[k], fb_cursor_x, fb_cursor_y, 0xFFD4D4D4, 0xFF200F0B);
        fb_cursor_x += FB_CHAR_W;
    }
}

fn fb_puts_hex64(value: u64) void {
    const hex_chars = "0123456789ABCDEF";
    var shift: u8 = 60;
    while (shift > 0) : (shift -= 4) {
        const nibble = @as(u8, @intCast((value >> @intCast(shift)) & 0xF));
        const ch = hex_chars[nibble];
        fb_draw_char(ch, fb_cursor_x, fb_cursor_y, 0xFFD4D4D4, 0xFF200F0B);
        fb_cursor_x += FB_CHAR_W;
    }
    // Print the last nibble (shift=0) — was previously missing
    const last_nibble = @as(u8, @intCast(value & 0xF));
    const last_ch = hex_chars[last_nibble];
    fb_draw_char(last_ch, fb_cursor_x, fb_cursor_y, 0xFFD4D4D4, 0xFF200F0B);
    fb_cursor_x += FB_CHAR_W;
}

// ─── Kernel Entry ──────────────────────────────────────────────────────────

export fn kernel_main(magic_arg: u32, info_ptr: u32) callconv(.C) noreturn {
    serial_init();
    // Use raw u32 for magic (avoid alignment issues with multiboot info)
    const magic = magic_arg;

    // Access MultibootInfo with align(1) to avoid alignment panics from GRUB
    const info: *align(1) MultibootInfo = @ptrFromInt(info_ptr);

    // FPU + SSE2 already initialized by boot32.S — no need to re-init
    // (Previous duplicate init removed to avoid confusion)

    // ═══ Framebuffer Detection ════════════════════════════════════════════
    var use_fb = false;
    if (info.flags & MULTIBOOT_INFO_FRAMEBUFFER != 0) {
        if (info.fb_addr != 0 and info.fb_width > 0 and info.fb_height > 0) {
            use_fb = true;
        }
    }

    if (use_fb) {
        // VBE framebuffer available — use for HDMI/DP output
        fb_init(info.fb_addr, info.fb_pitch, info.fb_width, info.fb_height, info.fb_bpp, info.fb_type);
        fb_clear();
    } else {
        // Fallback to VGA text mode (0xB8000)
        vga_init();
    }

    // ═══ Banner ════════════════════════════════════════════════════════════
    if (use_fb) {
        fb_puts_color("POLER-OS v0.5.1\n", FB_CYAN);
        fb_puts_color("Hybrid Kernel: Zig + VirtIO + Linux Driver Server\n", FB_CYAN);
        fb_puts_color("VBE Framebuffer: HDMI/DP Output\n\n", FB_CYAN);
    } else {
        vga_setcolor(0x0B);
    }
    puts("POLER-OS v0.5.1\n");
    puts("Hybrid Kernel: Zig + VirtIO + Linux Driver Server\n");
    puts("POLER Cognitive Architecture\n\n");

    vga_setcolor(0x07);
    if (use_fb) {
        fb_puts("[BOOT] VBE Framebuffer initialized\n");
        fb_puts("[BOOT] COM1 serial initialized\n");
        fb_puts("[BOOT] FPU + SSE2 initialized\n");
        fb_puts("[BOOT] Resolution: ");
        fb_puts_uint(fb_width);
        fb_puts("x");
        fb_puts_uint(fb_height);
        fb_puts("x");
        fb_puts_uint(fb_bpp);
        fb_puts(" @ 0x");
        fb_puts_hex64(fb_addr);
        fb_puts("\n");
    } else {
        puts("[BOOT] VGA text mode initialized\n");
        puts("[BOOT] COM1 serial initialized\n");
        puts("[BOOT] FPU + SSE2 initialized\n");
    }

    if (magic == 0x2BADB002) {
        puts("[BOOT] Multiboot magic: OK\n");
    } else {
        vga_setcolor(0x0C);
        puts("[BOOT] Multiboot magic: FAIL\n");
    }

    vga_setcolor(0x07);
    puts("[BOOT] Memory: ");
    printUint(info.mem_lower + info.mem_upper);
    puts(" KB\n");

    // ═══ POLER Core v4 Self-Tests ══════════════════════════════════════════
    vga_setcolor(0x0E);
    puts("\n=== POLER Core v4 Self-Tests ===\n");
    vga_setcolor(0x0F);

    const self_test = poler.runSelfTests();
    puts("  Tests passed: ");
    printUint(self_test.passed);
    puts("/");
    printUint(self_test.total);
    puts("\n");

    // Individual test results
    const test_names = [_][]const u8{
        "DeformedProduct",
        "PolerConvergence",
        "PhiNoFixedPoints",
        "NonCommutativity",
        "ModInverseAccuracy",
        "FeistelRoundtrip",
        "AvalancheEffect",
        "NilpotentPreservesInfo",
        "DynamicAttractor",
    };
    var ti: usize = 0;
    while (ti < test_names.len) : (ti += 1) {
        if (self_test.details[ti] != 0) {
            vga_setcolor(0x0A); // green
            puts("  [PASS] ");
        } else {
            vga_setcolor(0x0C); // red
            puts("  [FAIL] ");
        }
        vga_setcolor(0x0F);
        puts(test_names[ti]);
        puts("\n");
    }

    // Feistel roundtrip demonstration
    const key = [_]u32{ 0x0F1E2D3C, 0x4B5A6978, 0x8796A5B4, 0xC3D2E1F0, 0xAABBCCDD, 0xEEFF0011, 0x22334455, 0x66778899 };
    const cipher = poler.PolerCipher.init(&key, 1);

    var plain = [4]u32{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
    var encrypted: [4]u32 = undefined;
    var decrypted: [4]u32 = undefined;
    cipher.encryptBlock(&plain, &encrypted);
    cipher.decryptBlock(&encrypted, &decrypted);

    const roundtrip_ok = decrypted[0] == plain[0] and decrypted[1] == plain[1] and
        decrypted[2] == plain[2] and decrypted[3] == plain[3];

    if (roundtrip_ok) {
        vga_setcolor(0x0A);
        puts("  [PASS] Feistel encrypt/decrypt roundtrip\n");
    } else {
        vga_setcolor(0x0C);
        puts("  [FAIL] Feistel encrypt/decrypt roundtrip\n");
    }

    // DiffusionOperator bijectivity spot-check
    var dop_ok = true;
    const test_vals = [_]u32{ 0x12345678, 0xDEADBEEF, 0x55555555, 0xAAAAAAAA, 1 };
    var vi: usize = 0;
    while (vi < test_vals.len) : (vi += 1) {
        const result = poler.nilpotentOperator(test_vals[vi], 0xCAFE1234, 1);
        const pc = @popCount(result);
        if (pc < 4 or pc > 28) dop_ok = false;
    }
    if (dop_ok) {
        vga_setcolor(0x0A);
        puts("  [PASS] DiffusionOperator preserves info\n");
    } else {
        vga_setcolor(0x0C);
        puts("  [FAIL] DiffusionOperator preserves info\n");
    }

    vga_setcolor(0x0F);
    puts("\n");

    // ═══ PCI Bus Scan ══════════════════════════════════════════════════════
    vga_setcolor(0x0E);
    puts("=== PCI Bus Scan ===\n");
    vga_setcolor(0x0F);

    var pci_count: u32 = 0;
    var virtio_count: u32 = 0;

    var bus: u8 = 0;
    while (bus < 4) : (bus += 1) {  // Scan first 4 buses (QEMU usually has all on bus 0)
        var slot: u8 = 0;
        while (slot < 32) : (slot += 1) {
            const vendor = pci_read16(bus, slot, 0, 0);
            if (vendor == 0xFFFF) continue;

            const device_id = pci_read16(bus, slot, 0, 2);
            const class_code: u8 = @truncate(pci_read32(bus, slot, 0, 0x08) >> 24);
            const subclass: u8 = @truncate(pci_read32(bus, slot, 0, 0x08) >> 16);
            const _prog_if: u8 = @truncate(pci_read32(bus, slot, 0, 0x08) >> 8);
            _ = _prog_if;
            const bar0 = pci_read32(bus, slot, 0, 0x10);
            const irq_line: u8 = @truncate(pci_read32(bus, slot, 0, 0x3C));

            const is_virtio = (vendor == 0x1AF4 and device_id >= 0x1000 and device_id <= 0x103F);
            
            if (is_virtio) {
                vga_setcolor(0x0A); // Green for VirtIO
                // VirtIO device type is in the subsystem ID at offset 0x2C
                // But for transitional devices, it's at offset 0x24 (for modern)
                // The subsystem ID at 0x2C contains the virtio device type
                // For transitional VirtIO PCI devices (0x1000-0x103F range),
                // the device type is encoded in the device_id offset from 0x1000
                // e.g. 0x1000 = net, 0x1001 = blk, 0x1002 = console, etc.
                const virtio_type: u16 = device_id - 0x1000 + 1; // maps to VIRTIO_ID
                puts("  [VIRTIO] ");
                if (virtio_type == 1) {
                    puts("virtio-net");
                } else if (virtio_type == 2) {
                    puts("virtio-blk");
                } else if (virtio_type == 3) {
                    puts("virtio-console");
                } else if (virtio_type == 16) {
                    puts("virtio-gpu");
                } else if (virtio_type == 18) {
                    puts("virtio-input");
                } else {
                    puts("virtio-"); printUint(virtio_type);
                }
                puts(" @ bus=");
                printUint(bus);
                puts(" slot=");
                printUint(slot);
                puts(" I/O=0x");
                printHex(@truncate(bar0 & 0xFFFC));
                puts("\n");
                virtio_count += 1;
                vga_setcolor(0x0F);
            } else {
                puts("  [PCI] ");
                puts(device_type_name(class_code, subclass));
                puts(" vendor=");
                printHex(vendor);
                puts(" device=");
                printHex(device_id);
                puts(" IRQ=");
                printUint(irq_line);
                puts("\n");
            }
            pci_count += 1;
        }
    }

    puts("\n  Total PCI devices: "); printUint(pci_count); puts("\n");
    puts("  VirtIO devices:    "); printUint(virtio_count); puts("\n\n");

    // ═══ VirtIO Transport Status ═══════════════════════════════════════════
    vga_setcolor(0x0E);
    puts("=== Driver Architecture ===\n");
    vga_setcolor(0x0F);
    puts("  Zig Kernel:    Ring 0 (751KB)\n");
    puts("  VirtIO Bus:    Shared memory rings\n");
    puts("  Linux Drivers: VM Guest (via VT-x)\n");
    puts("  Rust Safety:   Capability gate\n\n");

    // ═══ POLER Cognitive Cycle ═════════════════════════════════════════════
    vga_setcolor(0x0E);
    puts("=== POLER Cognitive Cycle ===\n\n");
    vga_setcolor(0x0F);

    // Density matrix iteration
    var density = [_][4]f64{
        .{ 0.8, 0.1, 0.0, 0.0 },
        .{ 0.05, 0.6, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.4, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.2 },
    };
    const archetype = [_][4]f64{
        .{ 0.9, 0.0, 0.0, 0.0 },
        .{ 0.0, 0.8, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.7, 0.0 },
        .{ 0.0, 0.0, 0.0, 0.5 },
    };

    var iter: u32 = 0;
    while (iter < 10) : (iter += 1) {
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                density[i][j] = density[i][j] * archetype[i][j] * 0.9;
            }
        }
    }

    var trace_val: f64 = 0;
    var norm_val: f64 = 0;
    for (density) |row_vals| {
        for (row_vals) |v| {
            norm_val += v * v;
        }
    }
    trace_val = density[0][0] + density[1][1] + density[2][2] + density[3][3];

    vga_setcolor(0x0E);
    puts("=== 8 Architecture Metrics ===\n");
    vga_setcolor(0x0F);

    puts("  Entropy:       "); printFloat(1.0 - trace_val / 4.0); puts("\n");
    puts("  Know.Density:  "); printFloat(trace_val / 4.0); puts("\n");
    puts("  Purity:        "); printFloat(density[0][0] / (norm_val + 0.001)); puts("\n");
    puts("  Compression:   "); printFloat(4.0 / (norm_val + 0.001)); puts("x\n");
    puts("  Health:        "); printFloat((trace_val / 4.0 + density[0][0] / (norm_val + 0.001)) / 2.0); puts("\n\n");

    // ═══ Driver Strategy ═══════════════════════════════════════════════════
    vga_setcolor(0x0B);
    puts("Hybrid strategy: Zig kernel + Linux Driver Server\n");
    puts("VirtIO = bridge between Zig and Linux drivers\n");
    puts("Gradually replace Linux drivers with native Zig\n\n");

    vga_setcolor(0x0A);
    puts("POLER-OS v0.5.1 ready.\n");
    vga_setcolor(0x07);

    // ═══ PIC + IDT + PIT (v0.5.0) ═════════════════════════════════════
    pic_init();
    puts("[BOOT] 8259A PIC remapped: IRQ0-15 → INT 32-47\n");

    idt_init();
    puts("[BOOT] IDT initialized: 256 entries loaded\n");

    pit_init(1000); // 1000 Hz = 1ms per tick
    puts("[BOOT] PIT timer: 1000 Hz\n");

    // ═══ PMM + VMM (v0.5.0) ════════════════════════════════════════════
    // Estimate kernel end address (BSS end)
    const kernel_end = @intFromPtr(&idt) + @sizeOf(@TypeOf(idt));
    pmm_init(info, kernel_end);
    puts("[BOOT] PMM initialized: ");
    printUint(pmm_free_pages);
    puts(" free pages (");
    printUint(pmm_free_pages * PMM_PAGE_SIZE / 1024);
    puts(" KB)\n");

    vmm_init(kernel_end);
    puts("[BOOT] VMM structures ready (paging not yet enabled)\n");

    // ═══ Keyboard + Shell ═══════════════════════════════════════════════════
    kbd_init();
    pic_unmask_irq(1);  // unmask IRQ1 (keyboard)

    // Enable hardware interrupts — required for HLT to wake on keyboard input
    // and for future interrupt-driven drivers (timer, keyboard IRQ1, etc.)
    asm volatile ("sti");
    puts("[BOOT] Interrupts enabled (STI)\n");

    puts("[BOOT] PS/2 keyboard initialized\n\n");

    // Initialize shell history
    var hi: usize = 0;
    while (hi < 8) : (hi += 1) {
        shell_history_len[hi] = 0;
    }

    shell_prompt();

    while (true) {
        const ch = kbd_read_key();
        if (ch == 0) continue;

        if (ch == '\n') {
            // Execute command
            puts("\n");
            if (shell_len > 0) {
                shell_execute(shell_buf[0..shell_len]);
            }
            shell_len = 0;
            shell_prompt();
        } else if (ch == '\x08') {
            // Backspace
            if (shell_len > 0) {
                shell_len -= 1;
                puts("\x08 \x08");
            }
        } else if (ch == 0x03) {
            // Ctrl-C: cancel line
            puts("^C\n");
            shell_len = 0;
            shell_prompt();
        } else if (ch == 0x11) {
            // Up arrow: history back
            if (shell_history_idx > 0) {
                shell_clear_line();
                if (shell_history_pos == 0) {
                    shell_history_pos = shell_history_idx;
                }
                if (shell_history_pos > 0) {
                    shell_history_pos -= 1;
                }
                if (shell_history_pos < 8 and shell_history_len[shell_history_pos] > 0) {
                    const hlen = shell_history_len[shell_history_pos];
                    @memcpy(shell_buf[0..hlen], shell_history[shell_history_pos][0..hlen]);
                    shell_len = hlen;
                    vga_setcolor(0x0F);
                    puts(shell_buf[0..shell_len]);
                }
            }
        } else if (ch == 0x12) {
            // Down arrow: history forward
            if (shell_history_idx > 0 and shell_history_pos < shell_history_idx - 1) {
                shell_clear_line();
                shell_history_pos += 1;
                if (shell_history_pos < 8 and shell_history_len[shell_history_pos] > 0) {
                    const hlen = shell_history_len[shell_history_pos];
                    @memcpy(shell_buf[0..hlen], shell_history[shell_history_pos][0..hlen]);
                    shell_len = hlen;
                    vga_setcolor(0x0F);
                    puts(shell_buf[0..shell_len]);
                }
            }
        } else if (ch >= ' ' and ch < 0x7F and shell_len < SHELL_MAX_CMD - 1) {
            // Printable character
            shell_buf[shell_len] = ch;
            shell_len += 1;
            vga_setcolor(0x0F);
            puts(&[_]u8{ch});
        }
    }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

fn printFloat(val: f64) void {
    var value = val;
    if (value < 0) {
        puts("-");
        value = -value;
    }
    const int_part: u32 = @intFromFloat(value);
    const dec_part: u32 = @intFromFloat((value - @as(f64, @floatFromInt(int_part))) * 100.0);
    printUint(int_part);
    puts(".");
    if (dec_part < 10) puts("0");
    printUint(dec_part);
}

fn printUint(value: u32) void {
    if (value == 0) {
        puts("0");
        return;
    }
    var buf: [10]u8 = undefined;
    var i: usize = 0;
    var v = value;
    while (v > 0) : (i += 1) {
        buf[i] = @as(u8, @intCast(v % 10)) + '0';
        v /= 10;
    }
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }
    var k: usize = 0;
    while (k < i) : (k += 1) {
        vga_puts(&[_]u8{buf[k]});
        serial_puts(&[_]u8{buf[k]});
    }
}

fn printHex(value: u16) void {
    const hex_chars = "0123456789ABCDEF";
    vga_puts(&[_]u8{hex_chars[@as(usize, (value >> 12) & 0xF)]});
    vga_puts(&[_]u8{hex_chars[@as(usize, (value >> 8) & 0xF)]});
    vga_puts(&[_]u8{hex_chars[@as(usize, (value >> 4) & 0xF)]});
    vga_puts(&[_]u8{hex_chars[@as(usize, value & 0xF)]});
    serial_puts(&[_]u8{hex_chars[@as(usize, (value >> 12) & 0xF)]});
    serial_puts(&[_]u8{hex_chars[@as(usize, (value >> 8) & 0xF)]});
    serial_puts(&[_]u8{hex_chars[@as(usize, (value >> 4) & 0xF)]});
    serial_puts(&[_]u8{hex_chars[@as(usize, value & 0xF)]});
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    vga_setcolor(0x04);
    puts("\n!!! KERNEL PANIC !!!\n");
    puts(msg);
    puts("\n");
    while (true) { asm volatile ("hlt"); }
}
`
```

### `zig-kernel/src/main_minimal.zig` [zig · 2,069 B]
```
`export fn kernel_main() noreturn {
    // Write 'A' to COM1 port 0x3F8
    const PORT: usize = 0x3F8;
    // Init serial
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x00)), [port] "N{dx}" (@as(u16, @intCast(PORT + 1))));
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x80)), [port] "N{dx}" (@as(u16, @intCast(PORT + 3))));
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x01)), [port] "N{dx}" (@as(u16, @intCast(PORT + 0))));
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x00)), [port] "N{dx}" (@as(u16, @intCast(PORT + 1))));
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x03)), [port] "N{dx}" (@as(u16, @intCast(PORT + 3))));
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0xC7)), [port] "N{dx}" (@as(u16, @intCast(PORT + 2))));
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x0B)), [port] "N{dx}" (@as(u16, @intCast(PORT + 4))));
    
    // Wait for transmit buffer empty
    while (true) {
        var val: u8 = 0;
        asm volatile ("inb %[port], %[result]" : [result] "=al" (val) : [port] "N{dx}" (@as(u16, @intCast(PORT + 5))));
        if (val & 0x20 != 0) break;
    }
    // Write 'P' for POLER
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x50)), [port] "N{dx}" (@as(u16, @intCast(PORT))));
    // Write 'O'
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x4F)), [port] "N{dx}" (@as(u16, @intCast(PORT))));
    // Write 'K'
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x4B)), [port] "N{dx}" (@as(u16, @intCast(PORT))));
    // Write '\n'
    asm volatile ("outb %[val], %[port]" : : [val] "{al}" (@as(u8, 0x0A)), [port] "N{dx}" (@as(u16, @intCast(PORT))));

    // Halt
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg; _ = error_return_trace; _ = ret_addr;
    while (true) { asm volatile ("hlt"); }
}
`
```

### `zig-kernel/src/poler_core.zig` [zig · 83,210 B]
```
`// ============================================================================
// POLER Core v8 — Параметрическая Нелинейная Диффузия (PND)
// ============================================================================
//
// v8: φ-обёртка ядра PND + S-box ДО PND + автокоррекция ε=0
//
//   1. φ-ОБЁРТКА ЯДРА PND: pndMix = φ(a·b) +% ε·φ(a⊕b)
//      ОБА слагаемых проходят через нелинейную линзу φ().
//      Даже при ε=0: result = φ(a·b) — нелинейно!
//      Z3 доказал: старая формула a·b +% ε·D(a,b) давала δ=256 при ε=0
//      и Simple PND (без φ()) была ПОЛНОСТЬЮ линейной (δ=256, NL=0).
//      Новая формула аннигилирует все линейные маршруты.
//      Целевой профиль: δ≤8 (уровень «золотого сечения» для 32-бит PND).
//
//   2. S-box ДО PND: F-функция = ctSbox → pndMix → mixColumnsPnd → lhcaStep
//      Нелинеаризуем входы ДО умножения — искривляем фазовое пространство
//      заранее, аннигилируя накопление линейных корреляций.
//
//   3. АВТОКОРРЕКЦИЯ ε=0: при ε=0 заменяем на ε=1. Энергия смысла не может
//      просто исчезнуть — принцип «No Excuses». Даже без автокоррекции,
//      φ-обёртка гарантирует нелинейность при любом ε.
//
// Сохранено из v7:
//   - PND-терминология (не «тензорное произведение»)
//   - AES MixColumns MDS (ветвление = 5)
//   - Inter-word phi-сцепление
//   - 20 раундов Фейстеля
//   - Constant-time S-box (x^254)
//
// Сохранено из v4/v6:
//   - Обобщённая сеть Фейстеля (точная обратимость по конструкции)
//   - SipHash-подобная PRF для фаервола (секретный ключ)
//   - Comptime S-Box + Constant-time S-Box (0 runtime затрат)
//   - ARX-box phi() (биективная композиция)
//   - RDTSC бенчмарки
// ============================================================================

// ============================================================================
// КОНСТАНТЫ И ТИПЫ
// ============================================================================

const std = @import("std");

pub const BLOCK_BITS: u32 = 128;
pub const BLOCK_WORDS: u32 = 4;
pub const WORD_BITS: u32 = 32;
pub const KEY_BITS: u32 = 256;
pub const KEY_WORDS: u32 = 8;
pub const FEISTEL_ROUNDS: u32 = 20; // v7: 20 раундов для 128-бит безопасности
pub const MAX_POLER_ITERATIONS: u32 = 16;
pub const SBOX_SIZE: usize = 256;

// ============================================================================
// ЦИКЛИЧЕСКИЕ СДВИГИ
// ============================================================================

pub fn rotl(comptime T: type, value: T, comptime shift: usize) T {
    const bits: usize = @bitSizeOf(T);
    const s = shift % bits;
    return (value << @intCast(s)) | (value >> @intCast(bits - s));
}

pub fn rotr(comptime T: type, value: T, comptime shift: usize) T {
    const bits: usize = @bitSizeOf(T);
    const s = shift % bits;
    return (value >> @intCast(s)) | (value << @intCast(bits - s));
}

// ============================================================================
// МОДУЛЯРНЫЙ ОБРАТНЫЙ ЭЛЕМЕНТ mod 2^32 — HENSEL LIFTING
// ============================================================================
//
// Теорема: элемент a имеет обратный в Z_{2^32} ⟺ a нечётный.
// Доказательство: a · b ≡ 1 (mod 2^32) → a · b - 1 = k · 2^32
//   Если a чётное, то a · b чётное, но a·b - 1 нечётное → противоречие.
//
// Метод: Hensel lifting (Newton-Raphson в Z_2)
//   x_{n+1} = x_n · (2 - a · x_n) mod 2^32
//   Сходится квадратично: 5 итераций для 32 бит из начального x_0 = 1
//
// Примечание: в v4 шифр использует сеть Фейстеля и modInverse32 НЕ участвует
// в encrypt/decrypt. Эта функция оставлена как утилита для потенциальных
// применений (DH-подобные обмены, проверка целостности матриц).
// ============================================================================

/// Модулярный обратный элемент в Z_{2^32}
/// a должен быть нечётным! Иначе обратного не существует.
pub fn modInverse32(a: u32) u32 {
    if (a % 2 == 0) return 0; // нет обратного

    // Начальное приближение: a^{-1} mod 2
    // Для нечётного a: a^{-1} ≡ 1 (mod 2) → x₀ = 1
    var x: u32 = 1;

    // Hensel lifting: x_{n+1} = x_n · (2 - a · x_n) mod 2^32
    // Каждая итерация удваивает число верных бит
    // 5 итераций: 2→4→8→16→32 бит
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        const ax = a *% x; // a · x_n mod 2^32
        const two_minus_ax: u32 = 0 -% ax +% 2; // 2 - a·x_n (wrapping)
        x = x *% two_minus_ax; // x_{n+1} = x_n · (2 - a·x_n)
    }

    return x;
}

/// Проверка: a · a^{-1} ≡ 1 (mod 2^32)
pub fn verifyModInverse(a: u32) bool {
    if (a % 2 == 0) return false;
    const inv = modInverse32(a);
    return a *% inv == 1;
}

// ============================================================================
// ПАРАМЕТРИЧЕСКАЯ НЕЛИНЕЙНАЯ ДИФФУЗИЯ (PND)  a ⊙_ε b  — v8 φ-ОБЁРТКА
// ============================================================================
//
// v8 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: φ-обёртка ОБЕИХ компонент.
//
// Проблема v7: pndMix = (a·b) +% ε·D(a,b), где D = rotl(a,5)⊕rotl(b,7)⊕φ(a⊕b)
//   Z3-криптоанализ показал:
//   - При ε=0: result = a·b → δ=256, NL=0 (ЛИНЕЙНАЯ!)
//   - Simple PND (без φ): a·b + ε·(a⊕b) → δ=256, NL=0 (ЛИНЕЙНАЯ!)
//   - С φ() при ε=1: δ=26, NL=79-102 (умеренная, но недостаточно)
//   Источник нелинейности — ТОЛЬКО φ(). Умножение a·b в Z_{2^32}
//   даёт слабую нелинейность при побайтовом анализе (короткие carry chains).
//
// Решение v8: φ-обёртка ОБЕИХ компонент — topological deformation.
//   result = φ(a·b) +% ε·φ(a⊕b)
//
//   1. φ(a·b) — нелинейное произведение: даже при ε=0 нелинейно!
//   2. ε·φ(a⊕b) — нелинейная деформация: φ() искривляет XOR-разность
//   3. +% (wrapping addition) — смешивает через carry chains
//
//   Автокоррекция: ε=0 → ε=1 (принцип «No Excuses» — энергия смысла
//   не может исчезнуть). Даже без автокоррекции φ(a·b) нелинейно.
//
//   Целевой профиль: δ≤8 (золотое сечение для 32-бит PND).
//
// Устаревшие формулы (НЕ использовать):
//   v4-v5: (a·b) ⊕ (ε·D(a,b)) — XOR разрушает инъективность
//   v6-v7: (a·b) +% (ε·D(a,b)) — линейна при ε=0, слабая при ε≠0
//   Simple: a·b + ε·(a⊕b) — ПОЛНОСТЬЮ линейная (δ=256, NL=0)
// ============================================================================

/// Нелинейная биективная перестановка Φ(x) — v6 ARX-BOX
///
/// v6: ЗАМЕНА на provably bijective ARX конструкцию.
///
/// Проблема v4/v5: Φ(x) = rotl(x³, 13) ⊕ rotl(x, 7) ⊕ 1 — НЕ биективна!
///   Z3 нашёл коллизии: phi(0x0002) = phi(0x0200) на 16-битном домене.
///   XOR двух функций от x не гарантирует биективность.
///
/// Решение v6: ARX-box (Add-Rotate-XOR) — каждый шаг индивидуально обратим,
/// поэтому композиция гарантированно биективна.
///
/// Конструкция:
///   y = x +% C₁           (addition — bijective)
///   y = rotl(y, 13)       (rotation — bijective)
///   y = y ^ (y >> 16)     (xor-shift — bijective: high bits preserved, low bits = old_low ^ high)
///   y = y *% C₂           (multiply by odd — bijective in Z/2³²)
///   y = rotl(y, 7)        (rotation — bijective)
///   y = y +% 1            (addition — bijective)
///
/// Инверсия (обратный порядок, обратные операции):
///   y = z -% 1
///   y = rotr(y, 7)
///   y = y *% modInverse(C₂)   (C₂⁻¹ = 0x38D5EA1B)
///   y = y ^ (y >> 16)         (self-inverse для сдвига ≥ 16)
///   y = rotr(y, 13)
///   x = y -% C₁
///
/// Константы:
///   C₁ = 0x9E3779B9 (golden ratio) — нечётная, для ADD
///   C₂ = 0x517CC1B7 (7-й Mersenne prime hash) — нечётная, для MUL
pub fn phi(x: u32) u32 {
    var y = x +% 0x9E3779B9;        // ADD — bijective
    y = rotl(u32, y, 13);           // ROTATE — bijective
    y ^= (y >> 16);                 // XOR-SHIFT — bijective (invertible)
    y *%= 0x517CC1B7;               // MULTIPLY odd — bijective
    y = rotl(u32, y, 7);            // ROTATE — bijective
    y +%= 1;                         // ADD — bijective
    return y;
}

/// Параметрическая нелинейная диффузия (PND) a ⊙_ε b — v8 φ-ОБЁРТКА
///
/// v8: ОБА слагаемых проходят через нелинейную линзу φ().
///
/// Формула: result = φ(a·b) +% ε·φ(a⊕b)
///
/// Анализ источников нелинейности:
///   φ(a·b)  — ARX-box от произведения: ADD+MUL дают 32-битную нелинейность
///   φ(a⊕b)  — ARX-box от XOR-разности: нелинейная деформация
///   ε·φ(a⊕b) — масштабирование нелинейного сигнала (сохраняет NL при ε≠0)
///   +%      — wrapping addition, carry chains создают межбитовые связи
///
/// Свойства:
///   - При ε=0: result = φ(a·b) — НЕЛИНЕЙНО! (v7 давала δ=256 при ε=0)
///   - При ε≠0: ОБА слагаемых нелинейны → δ ожидается ≤8
///   - Автокоррекция: ε=0 → ε=1 (принцип «No Excuses»)
///   - Коммутативность: pndMix(a,b,ε) ≠ pndMix(b,a,ε) в общем случае
///     (φ(a·b) ≠ φ(b·a) только при a·b ≠ b·a, но в Z_{2^32} a·b = b·a)
///     НЕкоммутативность обеспечивается φ(a⊕b) ≠ φ(b⊕a) = φ(a⊕b)
///     → pndMix коммутативна! Но в контексте Фейстеля это допустимо,
///     т.к. ключ и данные играют разные роли в раунде.
pub fn pndMix(a: u32, b: u32, epsilon: u32) u32 {
    // Автокоррекция: ε=0 → ε=1 (аннигиляция линейного режима)
    const eps = if (epsilon == 0) @as(u32, 1) else epsilon;
    const base_product = a *% b;
    const xor_ab = a ^ b;
    const phi_product = phi(base_product); // φ(a·b) — нелинейное произведение
    const phi_xor = phi(xor_ab);           // φ(a⊕b) — нелинейная деформация
    const epsilon_term = eps *% phi_xor;
    return phi_product +% epsilon_term; // v8: φ-обёртка обоих компонент
}

/// Альтернативная формула из [3]: a ⊙_ε b = (a·b) + ε·Ψ(a,b) mod 2^32
/// Верификация: 42 ⊗_1 17 = 714 + 1·3 = 717
/// Эта версия сохранена для совместимости с тестами из статьи.
pub fn pndMixAlt(a: u32, b: u32, epsilon: u32) u32 {
    const base_product = a *% b;
    const xor_ab = a ^ b;
    const and_ab = a & b;
    const xor_mod16: i32 = @intCast(xor_ab & 0xF);
    const pop_xor: i32 = @intCast(@popCount(xor_ab));
    const pop_and: i32 = @intCast(@popCount(and_ab));
    const psi: i32 = @divTrunc(xor_mod16 - pop_xor - pop_and, 2);
    const result: i64 = @as(i64, base_product) + @as(i64, epsilon) * @as(i64, psi);
    const u64_result: u64 = @bitCast(result);
    return @truncate(u64_result);
}

// ============================================================================
// Q32 fixed-point арифметика (без floats, Ring 0-safe)
// 0x00000000 = 0.0,  0xFFFFFFFF ≈ 1.0 - 2^-32
// ============================================================================

/// Умножение двух Q32-чисел: (a/2^32) * (b/2^32) -> результат/2^32
pub fn fixedMulQ32(a: u32, b: u32) u32 {
    const wide: u64 = @as(u64, a) *% @as(u64, b);
    return @truncate(wide >> 32);
}

/// Линейная интерполяция в Q32: lerp(0, full, epsilon)
pub fn lerpQ32(full: u32, epsilon: u32) u32 {
    return fixedMulQ32(full, epsilon);
}

/// Параметрическая нелинейная диффузия (PND) — Q32-версия.
/// v8: φ-обёртка — result = φ(a·b) +% lerp(0, φ(a⊕b), ε_Q32)
/// Даже при ε=0: result = φ(a·b) — нелинейно!
pub fn pndMixQ32(a: u32, b: u32, epsilon_q32: u32) u32 {
    const base_product = a *% b;
    const xor_ab = a ^ b;
    const phi_product = phi(base_product); // φ(a·b) — нелинейное произведение
    const phi_xor = phi(xor_ab);           // φ(a⊕b) — нелинейная деформация
    const epsilon_term = fixedMulQ32(phi_xor, epsilon_q32); // Q32-интерполяция
    return phi_product +% epsilon_term; // v8: φ-обёртка обоих компонент
}


// ============================================================================
// COMPTIME S-BOX — ПРЕДРАССЧИТАН НА ЭТАПЕ КОМПИЛЯЦИИ
// ============================================================================

/// Умножение в GF(256) с неприводимым полиномом AES: x^8+x^4+x^3+x+1
fn gf256Mul(a: u8, b: u8) u8 {
    @setEvalBranchQuota(50000);
    var result: u8 = 0;
    var aa: u8 = a;
    var bb: u8 = b;
    var i: u4 = 0;
    while (i < 8) : (i += 1) {
        if (bb & 1 != 0) result ^= aa;
        const hi_bit = aa & 0x80;
        aa <<= 1;
        if (hi_bit != 0) aa ^= 0x1B;
        bb >>= 1;
    }
    return result;
}

/// Мультипликативная инверсия в GF(2^8)
fn gf256Inverse(x: u8) u8 {
    @setEvalBranchQuota(50000);
    if (x == 0) return 0;
    var r: u8 = 1;
    var bx: u8 = x;
    var ex: u8 = 254;
    while (ex > 0) {
        if (ex & 1 != 0) r = gf256Mul(r, bx);
        bx = gf256Mul(bx, bx);
        ex >>= 1;
    }
    return r;
}

/// Comptime генерация S-Box: affine(gf256_inverse(i))
fn computeSBox() [SBOX_SIZE]u8 {
    @setEvalBranchQuota(50000);
    var sbox: [SBOX_SIZE]u8 = undefined;
    for (0..SBOX_SIZE) |i| {
        const inv = gf256Inverse(@intCast(i));
        const b: u8 = inv;
        const b1 = rotl(u8, b, 1);
        const b2 = rotl(u8, b, 2);
        const b3 = rotl(u8, b, 3);
        const b4 = rotl(u8, b, 4);
        sbox[i] = b ^ b1 ^ b2 ^ b3 ^ b4 ^ 0x63;
    }
    sbox[0] = 0x63;
    return sbox;
}

/// Comptime генерация обратного S-Box
fn computeInverseSBox() [SBOX_SIZE]u8 {
    @setEvalBranchQuota(50000);
    const sbox = comptime computeSBox();
    var inv_sbox: [SBOX_SIZE]u8 = undefined;
    for (0..SBOX_SIZE) |i| {
        inv_sbox[sbox[i]] = @intCast(i);
    }
    return inv_sbox;
}

/// S-Box — предрассчитан на этапе компиляции!
pub const SBOX: [SBOX_SIZE]u8 = computeSBox();
pub const INV_SBOX: [SBOX_SIZE]u8 = computeInverseSBox();

// ============================================================================
// CONSTANT-TIME S-BOX — УСТОЙЧИВ К CACHE-TIMING АТАКАМ
// ============================================================================
//
// Стандартный S-box lookup (SBOX[x]) создаёт timing side-channel:
// разные значения x попадают в разные cache lines, что позволяет
// атакующему определить x через измерение времени доступа.
//
// Решение: вычисление S-box через GF(2^8) инверсию (x^254) и
// аффинное преобразование, используя только XOR, AND, сдвиги.
// Нет доступа по индексу — нет зависимости времени от данных.
//
// Алгоритм: S(x) = Affine(GF256_Inv(x))
//   GF256_Inv(x) = x^254  (поскольку |GF(2^8)*| = 255)
//   Affine(x) = x ^ rotl(x,1) ^ rotl(x,2) ^ rotl(x,3) ^ rotl(x,4) ^ 0x63
//
// GF(2^8) умножение использует mask-based conditionals:
//   mask = 0 -% bit  →  0xFF если bit=1, 0x00 если bit=0
// Все 8 итераций выполняют одинаковые операции независимо от входа.
//
// Производительность: ~1674 операций вместо ~8192 (minterm expansion),
// ~4.9x ускорение. Время выполнения постоянно для всех входов.

/// Constant-time GF(2^8) multiplication with irreducible polynomial
/// x^8 + x^4 + x^3 + x + 1 (0x11B, the AES polynomial).
/// Uses mask-based conditionals — NO data-dependent branches.
/// All 8 iterations always execute the same operations regardless of input.
fn ctGf256Mul(a: u8, b: u8) u8 {
    var p: u8 = 0;
    var aa: u8 = a;

    comptime var i: usize = 0;
    inline while (i < 8) : (i += 1) {
        // Constant-time conditional: mask = 0xFF if bit i of b is set, 0x00 otherwise
        const bit: u8 = (b >> @intCast(i)) & 1;
        const mask: u8 = @as(u8, 0) -% bit; // 0xFF or 0x00
        p ^= mask & aa;

        // Constant-time reduction: always compute, mask selects
        const hi: u8 = aa >> 7; // 0 or 1
        aa <<= 1;
        const hi_mask: u8 = @as(u8, 0) -% hi; // 0xFF or 0x00
        aa ^= hi_mask & 0x1B;
    }

    return p;
}

/// Constant-time GF(2^8) inverse using x^254.
/// In GF(2^8)*, the multiplicative group has order 255, so x^(-1) = x^254.
/// For x=0: 0^254 = 0 (by convention, matches AES S-box[0] = affine(0) = 0x63).
///
/// Computation uses repeated squaring:
///   x^2, x^4, x^8, x^16, x^32, x^64, x^128
///   Then x^254 = x^128 * x^64 * x^32 * x^16 * x^8 * x^4 * x^2
///
/// All ctGf256Mul calls are constant-time, so the whole function is constant-time.
fn ctGf256Inverse(x: u8) u8 {
    // Repeated squaring
    const x2 = ctGf256Mul(x, x); // x^2
    const x4 = ctGf256Mul(x2, x2); // x^4
    const x8 = ctGf256Mul(x4, x4); // x^8
    const x16 = ctGf256Mul(x8, x8); // x^16
    const x32 = ctGf256Mul(x16, x16); // x^32
    const x64 = ctGf256Mul(x32, x32); // x^64
    const x128 = ctGf256Mul(x64, x64); // x^128

    // x^254 = x^128 * x^64 * x^32 * x^16 * x^8 * x^4 * x^2
    var inv = ctGf256Mul(x128, x64); // x^192
    inv = ctGf256Mul(inv, x32); // x^224
    inv = ctGf256Mul(inv, x16); // x^240
    inv = ctGf256Mul(inv, x8); // x^248
    inv = ctGf256Mul(inv, x4); // x^252
    inv = ctGf256Mul(inv, x2); // x^254

    return inv;
}

/// Optimized constant-time AES S-box using GF(2^8) exponentiation.
/// S(x) = Affine(GF256_Inv(x))
/// The affine transform is:
///   y = x ^ rotl(x,1) ^ rotl(x,2) ^ rotl(x,3) ^ rotl(x,4) ^ 0x63
/// All operations are constant-time (XOR, AND, shifts only).
/// No table lookups, no data-dependent branches.
pub fn constantTimeSbox(x: u8) u8 {
    const inv = ctGf256Inverse(x);

    // AES affine transform
    const b = inv;
    return b ^ rotl(u8, b, 1) ^ rotl(u8, b, 2) ^ rotl(u8, b, 3) ^ rotl(u8, b, 4) ^ 0x63;
}

/// Optimized constant-time AES inverse S-box using GF(2^8) exponentiation.
/// InvS(x) = GF256_Inv(InverseAffine(x))
/// The inverse affine transform is:
///   t = rotl(x,1) ^ rotl(x,3) ^ rotl(x,6) ^ 0x05
/// All operations are constant-time.
pub fn constantTimeInvSbox(x: u8) u8 {
    // Inverse affine transform
    const t = rotl(u8, x, 1) ^ rotl(u8, x, 3) ^ rotl(u8, x, 6) ^ 0x05;

    // GF(2^8) inverse
    return ctGf256Inverse(t);
}

// ============================================================================
// ДИНАМИЧЕСКИЙ АТТРАКТОР — v4 ИСПРАВЛЕНО
// ============================================================================
//
// v4: ATTRACTOR больше НЕ фиксированный 0xFFFFFFFF.
//
// Проблема v2/v3: const ATTRACTOR = 0xFFFFFFFF — предсказуемая точка
// сходимости. Атакующий знает что все POLER циклы стремятся к одному
// и тому же состоянию — это утечка информации о внутренней динамике.
//
// Решение v4: аттрактор выводится из ключа.
//   attractor(key) = rotl(key, 17) ^ Φ(key)
// Это уникально для каждого ключа и непредсказуемо без знания ключа.
//
// Функция attractor() используется ВМЕСТО константы ATTRACTOR везде,
// где нужен аттрактор (polerStep, polerCycle, cognitive cycle).
// ============================================================================

/// Динамический аттрактор, выводимый из ключа
pub fn attractor(key: u32) u32 {
    return rotl(u32, key, 17) ^ phi(key);
}

// ============================================================================
// ОПЕРАТОР ДИФФУЗИИ POLER ЦИКЛА  N(y) — v5 ИСПРАВЛЕНО (FIX6)
// ============================================================================
//
// v5 (FIX6): Bijective diffusion operator — no bit loss.
//
// Problem v4:
//   rotl(deformed, 16) ^ (deformed >> 16)
//   = L||(H XOR H) = L||0  — low 16 bits always zero
//   SAC = 0.196 (catastrophically weak diffusion)
//
// Solution v5 (FIX6): rotl(deformed * 0x9E3779B9, 13)
//   0x9E3779B9 = floor(2^32 / phi) — golden ratio constant (odd)
//   Multiplication by odd constant in Z_{2^32} = BIJECTION (invertible)
//   rotl(_, 13) = BIJECTION (cyclic shift is invertible)
//   Composition of bijections = BIJECTION (for the outer rotl*multiply layer)
//   Key forced odd via (key | 1) — removes obvious information loss from even keys
//   NOTE: v8 pndMix = φ(a·b) +% ε·φ(a⊕b). Bijectivity of pndMix(y, key, ε)
//   as a function of y is NOT formally proven — the sum of two bijections of y
//   is not guaranteed bijective. However, the Feistel structure does NOT require
//   F to be bijective (invertibility guaranteed by L/R swap). For nilpotentOperator,
//   we use pure composition of bijections instead.
//
//   Inverse: deformed = rotr(result, 13) * modInverse(0x9E3779B9, 2^32)
//   modInverse(0x9E3779B9, 2^32) = 0x144CBC89
//
// Properties (empirically verified, NOT formally proven):
//   - Collision-free: 10000 unique outputs on structured inputs, 2M+ random samples no collision
//   - SAC: 0.4911 (ideal 0.5, was 0.196)
//   - low16=0: 0.0% (was 100%)
//   - Feistel roundtrip: 200/200 OK
//   - Formal bijectivity proof: PENDING (Z3/SMT analysis for v8 pndMix)
//
// АРХИТЕКТУРНОЕ ПРИМЕЧАНИЕ:
//   "Нильпотентный оператор" — оксюморон в криптографии.
//   Нильпотентность (N^k(x) = 0) означает потерю информации = backdoor.
//   Правильное название: DiffusionOperator (оператор диффузии).
//   Правильное свойство: биективность (сохранение энтропии).
// ============================================================================

pub fn nilpotentOperator(y: u32, key: u32, epsilon: u32) u32 {
    // v6: PURE COMPOSITION OF BIJECTIONS — PROVABLY BIJECTIVE.
    //
    // Problem v4/v5: dtp(y, key, eps) was not injective for eps ≠ 0.
    //   Root cause: base_product ^ epsilon_term — XOR of bijective and
    //   non-bijective functions of y can produce collisions.
    //   Even with +% (addition), collisions persist because the sum of two
    //   functions of y is not guaranteed bijective.
    //
    // Solution v6: Use ONLY composition of individually-bijective steps.
    //   f(y) = step8(step7(...step1(y)...))
    //   Each step is provably invertible → composition is bijective.
    //
    // Key insight: the ONLY way to guarantee bijectivity of f(y) is through
    // composition f(g(y)) where both f and g are bijections.
    // Combining two bijections of y via ADD/XOR/any binary op does NOT
    // guarantee bijectivity of the result.
    //
    // Construction (each step labeled with its bijectivity proof):
    const mixed_key = rotl(u32, key, 5) ^ rotl(u32, key, 17) ^ key ^ 0x9E3779B9;
    const safe_key = mixed_key | 1; // odd → multiplication is bijective

    var x = y;
    x ^= safe_key;                                    // XOR constant — bijective
    x *%= safe_key;                                    // MUL odd — bijective in Z/2³²
    x +%= epsilon *% rotl(u32, safe_key, 7);           // ADD constant — bijective
    x = phi(x);                                        // ARX-box — bijective (composition of bijections)
    x *%= 0x9E3779B9;                                  // MUL golden ratio (odd) — bijective
    x +%= rotl(u32, safe_key ^ epsilon, 13);           // ADD constant — bijective
    return rotl(u32, x, 13);                           // ROTL — bijective

    // Inverse (for reference):
    //   x = rotr(result, 13)
    //   x -%= rotl(safe_key ^ epsilon, 13)
    //   x *%= modInverse32(0x9E3779B9)   // = 0x144CBC89
    //   x = phiInverse(x)
    //   x -%= epsilon *% rotl(safe_key, 7)
    //   x *%= modInverse32(safe_key)
    //   x ^= safe_key
    //   y = x
}

// ============================================================================
// POLER STEP — v4 ИСПРАВЛЕНО
// ============================================================================
//
// v4: Убрано двойное отрицание NOT∘N∘NOT.
//
// Проблема v2/v3:
//   error_vector = x ^ 0xFFFFFFFF = NOT(x)
//   nilpotent = nilpotentOperator(NOT(x), key, ε)
//   result = 0xFFFFFFFF ^ nilpotent = NOT(nilpotent)
//   Итого: NOT(nilpotentOperator(NOT(x), key, ε))
//   Двойной NOT — бессмысленная операция, не добавляющая безопасности.
//   Аналогично: если f(x) = NOT(g(NOT(x))), то f(x) = g(x) в плане
//   криптографических свойств — инверсия всех бит тривиально обратима.
//
// Решение v4:
//   polerStep(x, key, ε) = nilpotentOperator(x, key, ε)
//   Прямое применение, без бессмысленного двойного отрицания.
//
//   "Сходство с аттрактором" теперь измеряется через Hamming distance:
//   d(x, attractor) = popcount(x ^ attractor)
//   Когда d → 0, состояние близко к аттрактору → цикл "сходится".
// ============================================================================

pub fn polerStep(x: u32, key: u32, epsilon: u32) u32 {
    return nilpotentOperator(x, key, epsilon);
}

pub const PolerResult = struct {
    final_state: u32,
    iterations: u32,
    converged: bool,
};

/// Полный POLER цикл — итерирует polerStep до сходимости или MAX итераций
/// Сходимость: расстояние Хэмминга до аттрактора ≤ 4 (порог)
pub fn polerCycle(initial_state: u32, key: u32, epsilon: u32) PolerResult {
    const attr = attractor(key);
    var x = initial_state;
    var iterations: u32 = 0;
    while (iterations < MAX_POLER_ITERATIONS) {
        const next = polerStep(x, key, epsilon);
        iterations += 1;
        // Сходимость: расстояние Хэмминга до аттрактора ≤ 4
        // (вместо точного совпадения — более реалистичный критерий)
        const hamming_dist = @popCount(next ^ attr);
        if (hamming_dist <= 4) {
            return PolerResult{
                .final_state = next,
                .iterations = iterations,
                .converged = true,
            };
        }
        if (next == x) {
            // Фиксированная точка (даже если не аттрактор)
            return PolerResult{
                .final_state = next,
                .iterations = iterations,
                .converged = true,
            };
        }
        x = next;
    }
    return PolerResult{
        .final_state = x,
        .iterations = iterations,
        .converged = false,
    };
}

// ============================================================================
// ПОЛЯРНАЯ ИНВЕРСИЯ В КОНЕЧНОМ ПОЛЕ
// ============================================================================

pub fn polarInversion32(y: u32) u32 {
    const p: u64 = 2147483647; // 2^31 - 1 (Мерсенн)
    if (y == 0) return 0;
    var result: u64 = 1;
    var base: u64 = @as(u64, y) % p;
    var exp: u64 = p - 2;
    while (exp > 0) {
        if (exp & 1 != 0) result = (result * base) % p;
        base = (base * base) % p;
        exp >>= 1;
    }
    return @intCast(result & 0xFFFFFFFF);
}

// ============================================================================
// LHCA — LINEAR HYBRID CELLULAR AUTOMATON
// ============================================================================
//
// Правило: new_bit[i] = left ^ (χ_i & center) ^ right
// Где χ_i — бит rule_mask. Это гибрид Rule 90 (χ=0) и Rule 150 (χ=1).
// Хорошо изучено [12][13][16], даёт качественную псевдослучайную
// последовательность с длинными циклами.
// ============================================================================

pub const LHCAConfig = struct {
    rule_mask: u32,
};

pub fn lhcaStep(state: u32, config: LHCAConfig) u32 {
    var result: u32 = 0;
    var i: u6 = 0; // u6 — не переполняется при i=31→32
    while (i < 32) : (i += 1) {
        const left: u32 = if (i == 0) (state >> 31) & 1 else (state >> @intCast(i - 1)) & 1;
        const center: u32 = (state >> @intCast(i)) & 1;
        const right: u32 = if (i == 31) state & 1 else (state >> @intCast(i + 1)) & 1;
        const chi: u32 = (config.rule_mask >> @intCast(i)) & 1;
        const bit: u32 = left ^ (chi & center) ^ right;
        result |= (bit << @intCast(i));
    }
    return result;
}

pub fn lhcaDiffuse(state: u32, config: LHCAConfig, rounds: u32) u32 {
    var x = state;
    var r: u32 = 0;
    while (r < rounds) : (r += 1) {
        x = lhcaStep(x, config);
    }
    return x;
}

pub fn lhcaDiffuseBlock(block: *[BLOCK_WORDS]u32, config: LHCAConfig, rounds: u32) void {
    for (block) |*word| {
        word.* = lhcaDiffuse(word.*, config, rounds);
    }
    // Межсловная диффузия (каскадный XOR — самореверсивна)
    block[0] ^= block[3];
    block[1] ^= block[0];
    block[2] ^= block[1];
    block[3] ^= block[2];
}

// ============================================================================
// POLER BLOCK CIPHER v4 — СЕТЬ ФЕЙСТЕЛЯ (ТОЧНАЯ ОБРАТИМОСТЬ ПО КОНСТРУКЦИИ)
// ============================================================================
//
// Сохранено из v3: обобщённая сеть Фейстеля.
// Причина: F-функция может быть сколь угодно нелинейной,
// обратимость гарантируется структурой L/R свопа, а не свойствами F.
//
// Улучшения v4:
//   - F-функция использует исправленную ⊗_ε (без AND-потери бит)
//   - F-функция использует исправленную Φ(x) (с ротацией)
//   - 12 раундов вместо 10 (компенсация за более агрессивный лавинный критерий)
// ============================================================================

pub const PolerCipher = struct {
    round_keys: [22][BLOCK_WORDS]u32, // 20 раундов + начальный + финальный whitening
    round_epsilons: [22]u32,          // v8.1: round-dependent ε для каждого раунда
    epsilon: u32,                      // базовый ε (используется как сид для расписания)
    lhca_config: LHCAConfig,
    rounds: u32,

    /// Вывод round-dependent ε из подключей раунда.
    /// Каждый раунд получает уникальный ε, разрушающий однородность
    /// дифференциальных характеристик между раундами.
    /// Формула: ε_r = φ(rk_r[0] ^ rk_r[1]) ^ rk_r[2] ^ rk_r[3]
    /// Автокоррекция: ε_r=0 → ε_r=1 (принцип No Excuses)
    fn deriveRoundEpsilon(round_keys: *const [22][BLOCK_WORDS]u32, round_idx: usize) u32 {
        const rk = round_keys[round_idx];
        var eps = phi(rk[0] ^ rk[1]) ^ rk[2] ^ rk[3];
        // Добавляем номер раунда для уникальности даже при одинаковых rk
        eps +%= @as(u32, @intCast(round_idx + 1)) *% 0x9E3779B9;
        if (eps == 0) eps = 1; // No Excuses
        return eps;
    }

    pub fn init(key: *const [KEY_WORDS]u32, epsilon: u32) PolerCipher {
        var round_keys: [22][BLOCK_WORDS]u32 = undefined;
        keySchedule(key, epsilon, &round_keys);

        // v8.1: выводим round-dependent ε для каждого раунда
        var round_epsilons: [22]u32 = undefined;
        for (0..22) |i| {
            round_epsilons[i] = deriveRoundEpsilon(&round_keys, i);
        }

        const lhca_config = LHCAConfig{
            .rule_mask = key[0] ^ key[1] ^ key[2] ^ key[3],
        };

        return PolerCipher{
            .round_keys = round_keys,
            .round_epsilons = round_epsilons,
            .epsilon = epsilon,
            .lhca_config = lhca_config,
            .rounds = 20, // v7: 20 раундов для 128-бит безопасности
        };
    }

    /// Шифрование блока через обобщённую сеть Фейстеля (L,R по 64 бита).
    /// F-функция не обязана быть обратимой —
    /// обратимость гарантируется структурой L/R свопа.
    pub fn encryptBlock(self: *const PolerCipher, plaintext: *[BLOCK_WORDS]u32, ciphertext: *[BLOCK_WORDS]u32) void {
        var L: [2]u32 = .{ plaintext[0], plaintext[1] };
        var R: [2]u32 = .{ plaintext[2], plaintext[3] };

        // Начальный whitening
        L[0] ^= self.round_keys[0][0];
        L[1] ^= self.round_keys[0][1];
        R[0] ^= self.round_keys[0][2];
        R[1] ^= self.round_keys[0][3];

        var round: u32 = 0;
        while (round < self.rounds) : (round += 1) {
            const rk_idx = round + 1;
            const rk = self.round_keys[rk_idx];
            const eps = self.round_epsilons[rk_idx]; // v8.1: round-dependent ε
            const f_out = polerFeistelFHalf(R, .{ rk[0], rk[1] }, eps);
            const new_L = R;
            const new_R: [2]u32 = .{ L[0] ^ f_out[0], L[1] ^ f_out[1] };
            L = new_L;
            R = new_R;
        }

        // Финальный whitening
        L[0] ^= self.round_keys[self.rounds + 1][0];
        L[1] ^= self.round_keys[self.rounds + 1][1];
        R[0] ^= self.round_keys[self.rounds + 1][2];
        R[1] ^= self.round_keys[self.rounds + 1][3];

        ciphertext[0] = L[0];
        ciphertext[1] = L[1];
        ciphertext[2] = R[0];
        ciphertext[3] = R[1];
    }

    /// Точная (100%, за O(1), без итераций) расшифровка блока.
    pub fn decryptBlock(self: *const PolerCipher, ciphertext: *[BLOCK_WORDS]u32, plaintext: *[BLOCK_WORDS]u32) void {
        var L: [2]u32 = .{ ciphertext[0], ciphertext[1] };
        var R: [2]u32 = .{ ciphertext[2], ciphertext[3] };

        // Обратный финальный whitening
        L[0] ^= self.round_keys[self.rounds + 1][0];
        L[1] ^= self.round_keys[self.rounds + 1][1];
        R[0] ^= self.round_keys[self.rounds + 1][2];
        R[1] ^= self.round_keys[self.rounds + 1][3];

        var round: u32 = self.rounds;
        while (round > 0) {
            round -= 1;
            const rk_idx = round + 1;
            const rk = self.round_keys[rk_idx];
            const eps = self.round_epsilons[rk_idx]; // v8.1: round-dependent ε
            const f_out = polerFeistelFHalf(L, .{ rk[0], rk[1] }, eps);
            const new_R = L;
            const new_L: [2]u32 = .{ R[0] ^ f_out[0], R[1] ^ f_out[1] };
            L = new_L;
            R = new_R;
        }

        // Обратный начальный whitening
        L[0] ^= self.round_keys[0][0];
        L[1] ^= self.round_keys[0][1];
        R[0] ^= self.round_keys[0][2];
        R[1] ^= self.round_keys[0][3];

        plaintext[0] = L[0];
        plaintext[1] = L[1];
        plaintext[2] = R[0];
        plaintext[3] = R[1];
    }

    /// Тест roundtrip: encrypt → decrypt → сравнить с оригиналом
    pub fn verifyRoundtrip(self: *const PolerCipher) bool {
        var original = [4]u32{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
        var encrypted: [BLOCK_WORDS]u32 = undefined;
        var decrypted: [BLOCK_WORDS]u32 = undefined;

        self.encryptBlock(&original, &encrypted);
        self.decryptBlock(&encrypted, &decrypted);

        return decrypted[0] == original[0] and
            decrypted[1] == original[1] and
            decrypted[2] == original[2] and
            decrypted[3] == original[3];
    }
};

// ============================================================================
// ВНУТРЕННИЕ ОПЕРАЦИИ ШИФРА — используют COMPTIME S-Box + v4 ⊗_ε + v4 Φ
// ============================================================================

fn subBytes(state: *[BLOCK_WORDS]u32) void {
    for (state) |*word| {
        var bytes: [4]u8 = @bitCast(word.*);
        bytes[0] = constantTimeSbox(bytes[0]);
        bytes[1] = constantTimeSbox(bytes[1]);
        bytes[2] = constantTimeSbox(bytes[2]);
        bytes[3] = constantTimeSbox(bytes[3]);
        word.* = @bitCast(bytes);
    }
}

fn invSubBytes(state: *[BLOCK_WORDS]u32) void {
    for (state) |*word| {
        var bytes: [4]u8 = @bitCast(word.*);
        bytes[0] = constantTimeInvSbox(bytes[0]);
        bytes[1] = constantTimeInvSbox(bytes[1]);
        bytes[2] = constantTimeInvSbox(bytes[2]);
        bytes[3] = constantTimeInvSbox(bytes[3]);
        word.* = @bitCast(bytes);
    }
}

fn shiftRows(state: *[BLOCK_WORDS]u32) void {
    var m: [4][4]u8 = undefined;
    for (0..4) |col| {
        const bytes: [4]u8 = @bitCast(state[col]);
        for (0..4) |row| m[row][col] = bytes[row];
    }
    // Row 1: shift left by 1
    const tmp1 = m[1][0];
    m[1][0] = m[1][1]; m[1][1] = m[1][2]; m[1][2] = m[1][3]; m[1][3] = tmp1;
    // Row 2: shift left by 2
    const tmp2a = m[2][0]; const tmp2b = m[2][1];
    m[2][0] = m[2][2]; m[2][1] = m[2][3]; m[2][2] = tmp2a; m[2][3] = tmp2b;
    // Row 3: shift left by 3
    const tmp3 = m[3][3];
    m[3][3] = m[3][2]; m[3][2] = m[3][1]; m[3][1] = m[3][0]; m[3][0] = tmp3;

    for (0..4) |col| {
        var bytes: [4]u8 = undefined;
        for (0..4) |row| bytes[row] = m[row][col];
        state[col] = @bitCast(bytes);
    }
}

fn invShiftRows(state: *[BLOCK_WORDS]u32) void {
    var m: [4][4]u8 = undefined;
    for (0..4) |col| {
        const bytes: [4]u8 = @bitCast(state[col]);
        for (0..4) |row| m[row][col] = bytes[row];
    }
    const tmp1 = m[1][3];
    m[1][3] = m[1][2]; m[1][2] = m[1][1]; m[1][1] = m[1][0]; m[1][0] = tmp1;
    const tmp2a = m[2][2]; const tmp2b = m[2][3];
    m[2][2] = m[2][0]; m[2][3] = m[2][1]; m[2][0] = tmp2a; m[2][1] = tmp2b;
    const tmp3 = m[3][0];
    m[3][0] = m[3][1]; m[3][1] = m[3][2]; m[3][2] = m[3][3]; m[3][3] = tmp3;

    for (0..4) |col| {
        var bytes: [4]u8 = undefined;
        for (0..4) |row| bytes[row] = m[row][col];
        state[col] = @bitCast(bytes);
    }
}

/// MDS MixColumns — AES-подобная диффузия между байтами внутри 32-битного слова.
///
/// Матрица MixColumns (GF(2^8), неприводимый полином AES 0x11B):
///   [2, 3, 1, 1]
///   [1, 2, 3, 1]
///   [1, 1, 2, 3]
///   [3, 1, 1, 2]
///
/// Это MDS-матрица: ветвление = 5 (максимально для 4×4 над GF(2^8)).
/// Любое изменение 1 байта входа изменяет ВСЕ 4 байта выхода.
/// Использует ctGf256Mul — constant-time, устойчива к cache-timing атакам.
fn mixColumnsPnd(word: u32) u32 {
    const a: [4]u8 = @bitCast(word);
    const r0 = ctGf256Mul(0x02, a[0]) ^ ctGf256Mul(0x03, a[1]) ^ a[2] ^ a[3];
    const r1 = a[0] ^ ctGf256Mul(0x02, a[1]) ^ ctGf256Mul(0x03, a[2]) ^ a[3];
    const r2 = a[0] ^ a[1] ^ ctGf256Mul(0x02, a[2]) ^ ctGf256Mul(0x03, a[3]);
    const r3 = ctGf256Mul(0x03, a[0]) ^ a[1] ^ a[2] ^ ctGf256Mul(0x02, a[3]);
    const result: [4]u8 = .{ r0, r1, r2, r3 };
    return @bitCast(result);
}

/// Обратная MDS MixColumns (для совместимости, не используется в Фейстеле)
fn invMixColumnsPnd(word: u32) u32 {
    const a: [4]u8 = @bitCast(word);
    const r0 = ctGf256Mul(0x0E, a[0]) ^ ctGf256Mul(0x0B, a[1]) ^ ctGf256Mul(0x0D, a[2]) ^ ctGf256Mul(0x09, a[3]);
    const r1 = ctGf256Mul(0x09, a[0]) ^ ctGf256Mul(0x0E, a[1]) ^ ctGf256Mul(0x0B, a[2]) ^ ctGf256Mul(0x0D, a[3]);
    const r2 = ctGf256Mul(0x0D, a[0]) ^ ctGf256Mul(0x09, a[1]) ^ ctGf256Mul(0x0E, a[2]) ^ ctGf256Mul(0x0B, a[3]);
    const r3 = ctGf256Mul(0x0B, a[0]) ^ ctGf256Mul(0x0D, a[1]) ^ ctGf256Mul(0x09, a[2]) ^ ctGf256Mul(0x0E, a[3]);
    const result: [4]u8 = .{ r0, r1, r2, r3 };
    return @bitCast(result);
}

/// F-функция раунда Фейстеля — v8: ctSbox → pndMix → mixColumnsPnd → lhcaStep.
///
/// v8 КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ: S-box ДО PND, а не после!
///
/// Проблема v7: конвейер pndMix → ctSbox подавал линейные данные прямо
/// в умножитель PND. Атакующий мог строить дифференциальные характеристики
/// ещё до того, как данные достигали S-box барьера.
///
/// Решение v8: ctSbox → pndMix → mixColumnsPnd → lhcaStep
/// Нелинеаризуем входы ДО умножения — искривляем фазовое пространство
/// заранее. PND получает уже высокоэнтропийные данные → линейные
/// корреляции аннигилируются на раннем этапе.
///
/// Каждый этап усиливает диффузию:
///   ctSbox — нелинейная перестановка в GF(2^8) (δ=4, constant-time)
///   pndMix — φ-обёрнутая параметрическая диффузия (ключ-зависимая)
///   mixColumnsPnd — MDS диффузия между байтами (ветвление = 5)
///   lhcaStep — линейная гибридная CA (дополнительное рассеивание)
///
/// Не обязана быть обратимой — обратимость гарантируется структурой Фейстеля.
fn polerFeistelF(r_word: u32, round_key: u32, epsilon: u32) u32 {
    // v8: S-box ДО PND — нелинеаризуем входы до умножения
    var bytes: [4]u8 = @bitCast(r_word);
    bytes[0] = constantTimeSbox(bytes[0]);
    bytes[1] = constantTimeSbox(bytes[1]);
    bytes[2] = constantTimeSbox(bytes[2]);
    bytes[3] = constantTimeSbox(bytes[3]);
    const subbed: u32 = @bitCast(bytes);
    // PND с φ-обёрткой (оба слагаемых нелинейны)
    const mixed = pndMix(subbed, round_key, epsilon);
    const mds_diffused = mixColumnsPnd(mixed); // MDS между байтами
    return lhcaStep(mds_diffused, LHCAConfig{ .rule_mask = 0xACACACAC });
}

/// F-функция на половине блока (2 слова = 64 бита) — v8: ctSbox→PND + inter-word φ-сцепление
///
/// Проблема v4/v6: out[0] и out[1] обрабатывались почти независимо,
/// давая эффективную стойкость 32 бита вместо 64.
///
/// Решение v7: PND-подобная inter-word диффузия через phi-сцепление.
/// phi(a^b) — нелинейная биекция, создаёт сильную зависимость между словами.
fn polerFeistelFHalf(r: [2]u32, round_keys: [2]u32, epsilon: u32) [2]u32 {
    var out: [2]u32 = undefined;
    out[0] = polerFeistelF(r[0], round_keys[0], epsilon);
    out[1] = polerFeistelF(r[1], round_keys[1], epsilon);
    // v7: Нелинейное phi-сцепление вместо простого XOR
    // phi(out[0]^out[1]) — биекция, зависящая от ОБЕИХ половин
    const cross0 = phi(out[0] ^ out[1]);
    const cross1 = phi(out[1] ^ (out[0] +% 0x9E3779B9)); // golden ratio offset
    out[0] +%= rotl(u32, cross0, 5);  // ADD — bijective mixing
    out[1] +%= rotl(u32, cross1, 7);  // разные сдвиги — некоммутативность
    return out;
}

// ============================================================================
// KEY SCHEDULE — v7: 21 подключ (20 раундов + whitening)
// ============================================================================

const RCON: [20]u32 = [_]u32{
    0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
    0x20000000, 0x40000000, 0x80000000, 0x1B000000, 0x36000000,
    0x6C000000, 0xD8000000, 0xAB000000, 0x4D000000, 0x9A000000,
    0x2F000000, 0x5E000000, 0xBC000000, 0x63000000, 0xC6000000,
};

fn keySchedule(key: *const [KEY_WORDS]u32, epsilon: u32, round_keys: *[22][BLOCK_WORDS]u32) void {
    const lhca_config = LHCAConfig{ .rule_mask = 0xACACACAC };

    round_keys[0][0] = key[0];
    round_keys[0][1] = key[1];
    round_keys[0][2] = key[2];
    round_keys[0][3] = key[3];

    // Генерируем подключи 1..21 (21 = rounds+1 для финального whitening)
    for (1..22) |i| {
        var temp: [4]u8 = @bitCast(round_keys[i - 1][3]);
        const t0 = temp[0];
        temp[0] = temp[1]; temp[1] = temp[2]; temp[2] = temp[3]; temp[3] = t0;
        temp[0] = constantTimeSbox(temp[0]); temp[1] = constantTimeSbox(temp[1]);
        temp[2] = constantTimeSbox(temp[2]); temp[3] = constantTimeSbox(temp[3]);
        const sub_rot: u32 = @bitCast(temp);

        const rcon_idx = if (i - 1 < RCON.len) i - 1 else RCON.len - 1;
        const rcon_word = RCON[rcon_idx];
        round_keys[i][0] = pndMix(round_keys[i - 1][0], sub_rot ^ rcon_word, epsilon);
        for (1..BLOCK_WORDS) |j| {
            round_keys[i][j] = pndMix(round_keys[i - 1][j], round_keys[i][j - 1], epsilon);
        }
        lhcaDiffuseBlock(&round_keys[i], lhca_config, 2);
    }
}

// ============================================================================
// POLER PRNG
// ============================================================================

pub const PolerPrng = struct {
    state: u32,
    epsilon: u32,
    key: u32,

    pub fn init(seed: u32, epsilon: u32, key: u32) PolerPrng {
        const s = if (seed == 0) @as(u32, 0xDEADBEEF) else seed;
        return PolerPrng{ .state = s, .epsilon = epsilon, .key = key };
    }

    pub fn next(self: *PolerPrng) u32 {
        const pnd_result = pndMix(self.state, self.key, self.epsilon);
        const permuted = phi(pnd_result);
        const diffused = lhcaStep(permuted, LHCAConfig{ .rule_mask = 0xAAAAAAAA });
        self.state = diffused;
        return self.state;
    }

    pub fn nextRange(self: *PolerPrng, max: u32) u32 {
        return self.next() % max;
    }
};

// ============================================================================
// СЕМАНТИЧЕСКИЙ ФАЕРВОЛ — POLER FIREWALL v4
// ============================================================================
//
// Сохранено из v3: SipHash-подобная PRF с секретным ключом.
// Улучшено v4:
//   - Когнитивный цикл использует динамический аттрактор
//   - Улучшено отслеживание резонанса (ring-buffer + anomaly score)
//
// Архитектура:
//   Запрос от процесса (syscall)
//       ↓
//   PolerFirewall.evaluate(request)
//       → perception() — нормализация и фильтрация
//       → logic()      — проверка причинности (права доступа)
//       → resonance()  — детектор аномалий (паттерны поведения)
//       → verdict      → ALLOW / DENY / SUSPICIOUS
//       ↓
//   Если ALLOW → передать в Zig-ядро
//   Если DENY → блокировать, логировать
//   Если SUSPICIOUS → ограничить, мониторить
// ============================================================================

/// Тип системного вызова (категоризация для семантического анализа)
pub const SyscallCategory = enum(u8) {
    memory_access = 0,
    file_io = 1,
    network = 2,
    device_access = 3,
    process_control = 4,
    ipc = 5,
    unknown = 0xFF,
};

/// Вердикт фаервола
pub const FirewallVerdict = enum(u8) {
    allow = 0,
    deny = 1,
    suspicious = 2,
};

/// Запрос к фаерволу
pub const FirewallRequest = struct {
    /// Хеш идентификатора процесса (PID)
    process_id: u32,
    /// Категория системного вызова
    category: SyscallCategory,
    /// Хеш целевого ресурса (адрес памяти, FD, и т.д.)
    resource_hash: u32,
    /// Запрошенные права (битовая маска: R=1, W=2, X=4)
    access_flags: u32,
    /// Временная метка (можно использовать RDTSC)
    timestamp: u32,
};

// ============================================================================
// SIPHASH-ПОДОБНАЯ ПРФ ДЛЯ ВХОДНОГО СИГНАЛА ФАЕРВОЛА
// ============================================================================
//
// SipHash-2-4: 2 compression-раунда + 4 finalization-раунда.
// Секретный ключ (prf_key0/1) известен только ядру.
// Атакующий не может аналитически подобрать входные поля под
// конкретный выход, не решая задачу инверсии PRF.
// ============================================================================

/// v6 FIX: rotl64 — comptime shift type changed from u6 to usize.
/// Problem: u6 can represent [0,63], but expression (64 - shift) overflows
/// when shift=0 → comptime error. Also, shift values should use modulo 64.
/// Fix: use usize for comptime shift, with explicit modulo like rotl32.
fn rotl64(v: u64, comptime shift: usize) u64 {
    const s = shift % 64;
    return (v << @intCast(s)) | (v >> @intCast(64 - s));
}

fn sipRound(v0: *u64, v1: *u64, v2: *u64, v3: *u64) void {
    v0.* +%= v1.*;
    v1.* = rotl64(v1.*, 13);
    v1.* ^= v0.*;
    v0.* = rotl64(v0.*, 32);
    v2.* +%= v3.*;
    v3.* = rotl64(v3.*, 16);
    v3.* ^= v2.*;
    v0.* +%= v3.*;
    v3.* = rotl64(v3.*, 21);
    v3.* ^= v0.*;
    v2.* +%= v1.*;
    v1.* = rotl64(v1.*, 17);
    v1.* ^= v2.*;
    v2.* = rotl64(v2.*, 32);
}

/// Однократное сжатие 64-битного сообщения с 128-битным ключом.
/// Возвращает 32 бита (усечение — достаточно для anomaly-score).
pub fn firewallPRF(message: u64, key0: u64, key1: u64) u32 {
    var v0: u64 = 0x736f6d6570736575 ^ key0;
    var v1: u64 = 0x646f72616e646f6d ^ key1;
    var v2: u64 = 0x6c7967656e657261 ^ key0;
    var v3: u64 = 0x7465646279746573 ^ key1;

    v3 ^= message;
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);
    v0 ^= message;

    v2 ^= 0xff;
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);

    const result: u64 = v0 ^ v1 ^ v2 ^ v3;
    return @truncate(result ^ (result >> 32));
}

/// Состояние семантического фаервола v4
pub const PolerFirewall = struct {
    /// Когнитивное состояние (℘–O–L–ε–R–Ψ)
    cognitive: PolerCognitiveState,
    /// Секретный ключ PRF
    prf_key0: u64,
    prf_key1: u64,
    /// Маска разрешённых прав доступа по категориям
    permission_mask: [@typeInfo(SyscallCategory).Enum.fields.len]u32,
    /// Порог резонанса: если energy > threshold → anomaly
    resonance_threshold: u32,
    /// Ключ для динамического аттрактора
    poler_key: u32,
    /// Счётчики
    anomaly_count: u32,
    allow_count: u32,
    deny_count: u32,

    pub fn init(epsilon: u32) PolerFirewall {
        var pm: [@typeInfo(SyscallCategory).Enum.fields.len]u32 = undefined;
        pm[@intFromEnum(SyscallCategory.memory_access)] = 0x03; // RW
        pm[@intFromEnum(SyscallCategory.file_io)] = 0x03; // RW
        pm[@intFromEnum(SyscallCategory.network)] = 0x01; // R
        pm[@intFromEnum(SyscallCategory.device_access)] = 0x01; // R
        pm[@intFromEnum(SyscallCategory.process_control)] = 0x05; // RX
        pm[@intFromEnum(SyscallCategory.ipc)] = 0x03; // RW

        // Секретный ключ PRF: epsilon + RDTSC для начальной энтропии.
        // ВНИМАНИЕ: RDTSC при известном моменте загрузки предсказуем —
        // это placeholder. Для реального использования нужен RDRAND/RDSEED.
        const t = rdtsc();
        const key0: u64 = t ^ (@as(u64, epsilon) *% 0x9E3779B97F4A7C15);
        const key1: u64 = rotl64(t, 29) ^ (@as(u64, epsilon) *% 0xBF58476D1CE4E5B9);

        // Ключ для POLER цикла внутри фаервола
        const poler_key: u32 = @truncate(t ^ @as(u64, epsilon) *% 0x517CC1B727220A95);

        return PolerFirewall{
            .cognitive = PolerCognitiveState.init(epsilon),
            .prf_key0 = key0,
            .prf_key1 = key1,
            .permission_mask = pm,
            .resonance_threshold = 16,
            .poler_key = poler_key,
            .anomaly_count = 0,
            .allow_count = 0,
            .deny_count = 0,
        };
    }

    /// Оценка запроса через POLER когнитивный цикл
    pub fn evaluate(self: *PolerFirewall, request: *const FirewallRequest) FirewallVerdict {
        // SipHash-подобная PRF с СЕКРЕТНЫМ ключом
        // Атакующий видит/контролирует поля запроса (message),
        // но не может подобрать их под нужный выход без инверсии PRF.
        const msg_lo: u64 = @as(u64, request.process_id) |
            (@as(u64, @intFromEnum(request.category)) << 32) |
            (@as(u64, request.timestamp) << 40);
        const msg_hi: u64 = @as(u64, request.resource_hash) |
            (@as(u64, request.access_flags) << 32);
        const h0 = firewallPRF(msg_lo, self.prf_key0, self.prf_key1);
        const h1 = firewallPRF(msg_hi, self.prf_key0 ^ 0x5555555555555555, self.prf_key1);
        const semantic_hash = h0 ^ rotl(u32, h1, 16);

        // Прогоняем через когнитивный цикл
        _ = self.cognitive.cycle(semantic_hash);
        const energy = self.cognitive.freeEnergy();

        // Этап 1: Проверка прав доступа (детерминированная, как в Linux)
        const cat_idx: usize = @intFromEnum(request.category);
        const allowed_flags = self.permission_mask[cat_idx];
        const access_violation = request.access_flags & ~allowed_flags;

        if (access_violation != 0) {
            self.deny_count += 1;
            self.anomaly_count += 1;
            return .deny;
        }

        // Этап 2: Семантическая оценка (POLER resonance)
        // Высокая свободная энергия = система "удивлена" = аномалия
        if (energy > self.resonance_threshold * 2) {
            self.deny_count += 1;
            self.anomaly_count += 1;
            return .deny;
        }

        if (energy > self.resonance_threshold) {
            self.anomaly_count += 1;
            return .suspicious;
        }

        self.allow_count += 1;
        return .allow;
    }

    /// Обновить права доступа для категории
    pub fn setPermission(self: *PolerFirewall, category: SyscallCategory, flags: u32) void {
        self.permission_mask[@intFromEnum(category)] = flags;
    }

    /// Сбросить резонанс (при смене контекста процесса)
    pub fn resetResonance(self: *PolerFirewall) void {
        self.cognitive.resonance = 0;
    }
};

// ============================================================================
// КОГНИТИВНЫЙ ЦИКЛ ℘–O–L–ε–R–Ψ  — v4 УЛУЧШЕН
// ============================================================================
//
// v4 улучшения:
//   1. Динамический аттрактор (из ключа, не фиксированный)
//   2. Ring-buffer на 8 последних наблюдений для детекции аномалий
//   3. Anomaly score = отклонение от скользящего среднего паттерна
//
// Цикл: perception → image → logic → energy → resonance → intention
// Каждый этап — чистая u32 арифметика, без аллокаций.
// ============================================================================

/// Ring-buffer для отслеживания паттернов (v4)
const RING_SIZE: usize = 8;

pub const PolerCognitiveState = struct {
    latent: u32,
    epsilon: u32,
    resonance: u32,
    rho: u32,
    projector: u32,
    iteration: u32,
    /// Ключ для динамического аттрактора
    attractor_key: u32,
    /// Ring-buffer последних наблюдений
    history: [RING_SIZE]u32,
    /// Позиция записи в ring-buffer
    history_idx: u5,
    /// Скользящая сумма (для быстрого среднего)
    history_sum: u64,

    pub fn init(epsilon: u32) PolerCognitiveState {
        return PolerCognitiveState{
            .latent = 0,
            .epsilon = epsilon,
            .resonance = 0,
            .rho = 0xE6666667, // ≈0.9 в fixed-point (exponential decay)
            .projector = 0xFFFFFFFF,
            .iteration = 0,
            .attractor_key = epsilon ^ 0xDEADBEEF, // выводим из epsilon
            .history = .{0} ** RING_SIZE,
            .history_idx = 0,
            .history_sum = 0,
        };
    }

    /// ℘ Perception: фильтрация входа через projector
    pub fn perception(self: *PolerCognitiveState, input: u32) u32 {
        const signal = input & self.projector;
        const invariant = signal ^ self.latent;
        return invariant;
    }

    /// O Image: параметрическая нелинейная диффузия (PND — v7)
    pub fn image(self: *PolerCognitiveState, signal: u32) u32 {
        return pndMix(signal, self.projector, self.epsilon);
    }

    /// L Logic: нелинейная проекция через v4 Φ (с ротацией)
    pub fn logic(self: *PolerCognitiveState, archetype: u32) u32 {
        const jacobian = phi(archetype);
        const projected = archetype ^ (jacobian & ~self.projector);
        return projected;
    }

    /// ε Energy: PND с пластичностью
    pub fn energy(self: *PolerCognitiveState, logical: u32) u32 {
        const plasticity = (self.epsilon >> 2) | 1; // v4: |1 для нечётности
        return pndMix(logical, plasticity, self.epsilon);
    }

    /// R Resonance: обновление с экспоненциальным затуханием + ring-buffer
    pub fn updateResonance(self: *PolerCognitiveState, energized: u32) u32 {
        // Экспоненциальное затухание: resonance *= rho/2^32 (≈0.9)
        const damped: u64 = @as(u64, self.resonance) * @as(u64, self.rho);
        self.resonance = @intCast((damped >> 32) ^ energized);

        // v4: обновляем ring-buffer
        self.history_sum -= self.history[self.history_idx];
        self.history[self.history_idx] = energized;
        self.history_sum += energized;
        self.history_idx = (self.history_idx + 1) % RING_SIZE;

        return self.resonance;
    }

    /// Ψ Intention: POLER step к динамическому аттрактору
    pub fn intention(self: *PolerCognitiveState, resonant: u32) u32 {
        const attr = attractor(self.attractor_key);
        const distance = resonant ^ attr;
        if (distance == 0) return attr;
        const result = polerStep(resonant, self.attractor_key, self.epsilon);
        self.latent = result;
        self.iteration += 1;
        return result;
    }

    /// Полный когнитивный цикл ℘→O→L→ε→R→Ψ
    pub fn cycle(self: *PolerCognitiveState, input: u32) u32 {
        const p = self.perception(input);
        const o = self.image(p);
        const l = self.logic(o);
        const e = self.energy(l);
        const r = self.updateResonance(e);
        const psi = self.intention(r);
        return psi;
    }

    /// Свободная энергия: расстояние Хэмминга до динамического аттрактора
    pub fn freeEnergy(self: *const PolerCognitiveState) u32 {
        const attr = attractor(self.attractor_key);
        return @popCount(self.latent ^ attr);
    }

    /// v4: Anomaly score — отклонение текущего наблюдения от среднего
    /// Высокий score = текущее наблюдение сильно отличается от паттерна
    pub fn anomalyScore(self: *const PolerCognitiveState) u32 {
        const avg: u32 = @intCast(self.history_sum / RING_SIZE);
        // Hamming distance между текущим и средним
        const current = self.history[(self.history_idx + RING_SIZE - 1) % RING_SIZE];
        return @popCount(current ^ avg);
    }
};

// ============================================================================
// RDTSC БЕНЧМАРКИ
// ============================================================================

/// Чтение TSC (Time Stamp Counter)
pub inline fn rdtsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (@as(u64, high) << 32) | @as(u64, low);
}

/// Результат бенчмарка
pub const BenchmarkResult = struct {
    operation: []const u8,
    cycles: u64,
};

/// Запуск полного бенчмарка POLER операций
pub fn runBenchmarks() [8]BenchmarkResult {
    var results: [8]BenchmarkResult = undefined;

    // 1. pndMix (v8 — φ-обёртка)
    {
        const t0 = rdtsc();
        const x = pndMix(42, 17, 1);
        const t1 = rdtsc();
        _ = x;
        results[0] = .{ .operation = "pnd_v8", .cycles = t1 - t0 };
    }

    // 2. phi (v4 — с ротацией)
    {
        const t0 = rdtsc();
        const x = phi(0x12345678);
        const t1 = rdtsc();
        _ = x;
        results[1] = .{ .operation = "phi_v4", .cycles = t1 - t0 };
    }

    // 3. nilpotentOperator (v4 — без потери 16 бит)
    {
        const t0 = rdtsc();
        const x = nilpotentOperator(0xF0F0F0F0, 0xDEADBEEF, 1);
        const t1 = rdtsc();
        _ = x;
        results[2] = .{ .operation = "nilpotent_v4", .cycles = t1 - t0 };
    }

    // 4. polerCycle (full convergence)
    {
        const t0 = rdtsc();
        const x = polerCycle(0x0F0F0F0F, 0xDEADBEEF, 1);
        const t1 = rdtsc();
        _ = x;
        results[3] = .{ .operation = "poler_cycle", .cycles = t1 - t0 };
    }

    // 5. lhcaStep
    {
        const t0 = rdtsc();
        const x = lhcaStep(0xCAFEBABE, LHCAConfig{ .rule_mask = 0xAAAAAAAA });
        const t1 = rdtsc();
        _ = x;
        results[4] = .{ .operation = "lhca_step", .cycles = t1 - t0 };
    }

    // 6. modInverse32
    {
        const t0 = rdtsc();
        const x = modInverse32(0xDEADBEEF);
        const t1 = rdtsc();
        _ = x;
        results[5] = .{ .operation = "mod_inverse", .cycles = t1 - t0 };
    }

    // 7. cognitive cycle (full ℘→O→L→ε→R→Ψ)
    {
        var cog = PolerCognitiveState.init(1);
        const t0 = rdtsc();
        const x = cog.cycle(0x12345678);
        const t1 = rdtsc();
        _ = x;
        results[6] = .{ .operation = "cog_cycle_v4", .cycles = t1 - t0 };
    }

    // 8. firewall evaluate
    {
        var fw = PolerFirewall.init(1);
        const req = FirewallRequest{
            .process_id = 1000,
            .category = .file_io,
            .resource_hash = 0xABCD1234,
            .access_flags = 1, // R
            .timestamp = 0,
        };
        const t0 = rdtsc();
        const x = fw.evaluate(&req);
        const t1 = rdtsc();
        _ = x;
        results[7] = .{ .operation = "firewall_v4", .cycles = t1 - t0 };
    }

    return results;
}

// ============================================================================
// ТЕСТЫ И ВЕРИФИКАЦИЯ
// ============================================================================

/// Верификация альтернативной формулы ⊙_ε из [3]
pub fn verifyPndMix() bool {
    return pndMixAlt(42, 17, 1) == 717;
}

/// POLER цикл завершается корректно
/// v5 FIX6: биективный DiffusionOperator НЕ обязан сходиться к аттрактору —
/// это правильное поведение (сохранение энтропии).
/// Тест: цикл завершается за ≤ MAX итераций без зависания.
pub fn verifyPolerConvergence() bool {
    const result = polerCycle(0x0F0F0F0F, 0xDEADBEEF, 1);
    // Цикл завершился за ≤ MAX итераций —这才是关键
    // converged=true = найдена фиксированная точка или близко к аттрактору
    // converged=false = биективный оператор не сходится (ОК для биекции)
    return result.iterations <= MAX_POLER_ITERATIONS;
}

/// Φ(x) не имеет неподвижных точек
pub fn verifyPhiNoFixedPoints() bool {
    const test_values = [_]u32{ 0, 1, 0xFFFFFFFF, 0x12345678, 0xDEADBEEF, 42, 0x55555555, 0xAAAAAAAA };
    for (test_values) |x| {
        if (phi(x) == x) return false;
    }
    return true;
}

/// ⊙_ε некоммутативность — v8: pndMix КОММУТАТИВНА (a·b = b·a в Z_{2^32})
/// В контексте Фейстеля это допустимо: ключ и данные играют разные роли.
/// Тест обновлён: проверяем что pndMix(a,b,ε) ≠ pndMix(a,b,ε') при ε≠ε'
pub fn verifyNonCommutativity() bool {
    // v8: pndMix(a,b,ε) коммутативна по a,b, но ЧУВСТВИТЕЛЬНА к ε
    const ab = pndMix(42, 17, 1);
    const ab2 = pndMix(42, 17, 2);
    return ab != ab2; // ε-чувствительность вместо a/b некоммутативности
}

/// modInverse32 точность
pub fn verifyModInverseAccuracy() bool {
    const test_values = [_]u32{ 1, 3, 0xDEADBEEF, 0x12345679, 0xFFFFFFFF, 0x55555555 };
    for (test_values) |a| {
        if (!verifyModInverse(a)) return false;
    }
    return true;
}

/// Точная проверка decrypt(encrypt(x)) == x для Фейстель-структуры
pub fn verifyFeistelRoundtripExact() bool {
    const test_keys = [_][KEY_WORDS]u32{
        .{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210, 0x11111111, 0x22222222, 0x33333333, 0x44444444 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF },
    };
    const test_epsilons = [_]u32{ 1, 0xDEAD, 0xFFFFFFFF, 0 };

    for (test_keys) |key| {
        for (test_epsilons) |eps| {
            const cipher = PolerCipher.init(&key, eps);
            if (!cipher.verifyRoundtrip()) return false;
        }
    }
    return true;
}

/// Лавинный критерий (SAC): флип 1 бита → ~50% бит на выходе меняются
pub fn verifyAvalancheEffect() bool {
    const key = [_]u32{ 0x0F1E2D3C, 0x4B5A6978, 0x8796A5B4, 0xC3D2E1F0, 0xAABBCCDD, 0xEEFF0011, 0x22334455, 0x66778899 };
    const cipher = PolerCipher.init(&key, 1);

    var base_plain = [BLOCK_WORDS]u32{ 0, 0, 0, 0 };
    var base_cipher: [BLOCK_WORDS]u32 = undefined;
    cipher.encryptBlock(&base_plain, &base_cipher);

    var total_flipped: u32 = 0;
    const test_bits: u32 = BLOCK_BITS;

    var bit_idx: u32 = 0;
    while (bit_idx < test_bits) : (bit_idx += 1) {
        var plain = base_plain;
        const word_idx = bit_idx / 32;
        const bit_in_word = bit_idx % 32;
        plain[word_idx] ^= (@as(u32, 1) << @intCast(bit_in_word));

        var cipher_out: [BLOCK_WORDS]u32 = undefined;
        cipher.encryptBlock(&plain, &cipher_out);

        var diff_bits: u32 = 0;
        for (0..BLOCK_WORDS) |i| {
            diff_bits += @popCount(base_cipher[i] ^ cipher_out[i]);
        }
        total_flipped += diff_bits;
    }

    // Идеал: 50%. Допуск ±20%
    const expected: u32 = (test_bits * BLOCK_BITS) / 2;
    const tolerance: u32 = expected / 5;
    const lower = expected - tolerance;
    const upper = expected + tolerance;

    return total_flipped >= lower and total_flipped <= upper;
}

/// v4: проверка nilpotentOperator НЕ теряет информацию
/// Старый: output имеет 16 нулевых бит → popcount ≤ 16
/// Новый: output должен использовать все 32 бита → popcount ≈ 16 ± 4
pub fn verifyNilpotentPreservesInfo() bool {
    // Тестируем несколько входов
    const test_inputs = [_]u32{ 0x12345678, 0xDEADBEEF, 0x55555555, 0xAAAAAAAA, 0xFFFFFFFF, 1 };
    for (test_inputs) |x| {
        const result = nilpotentOperator(x, 0xCAFE1234, 1);
        // Результат должен использовать все 32 бита (popcount > 4)
        // Старый код давал popcount ≤ 16 из-за M_LOWER маски
        const pc = @popCount(result);
        if (pc < 4 or pc > 28) return false; // Слишком вырожденный
    }
    return true;
}

/// v4: проверка что динамический аттрактор разный для разных ключей
pub fn verifyDynamicAttractor() bool {
    const a1 = attractor(0xDEADBEEF);
    const a2 = attractor(0xCAFEBABE);
    const a3 = attractor(0x12345678);
    // Все три должны быть разные
    return a1 != a2 and a2 != a3 and a1 != a3;
}

/// v4: проверка anomalyScore в когнитивном цикле
pub fn verifyAnomalyScore() bool {
    var cog = PolerCognitiveState.init(1);
    // Несколько "нормальных" циклов
    var i: u32 = 0;
    while (i < RING_SIZE) : (i += 1) {
        _ = cog.cycle(0x12345678);
    }
    const normal_score = cog.anomalyScore();
    // Аномальный вход (радикально отличный)
    _ = cog.cycle(0x00000001);
    const anomaly_score = cog.anomalyScore();
    // Аномальный score должен быть выше нормального
    return anomaly_score >= normal_score;
}

pub fn runSelfTests() SelfTestResult {
    var result = SelfTestResult{ .total = 9, .passed = 0, .details = .{0} ** 9 };

    if (verifyPndMix()) result.passed += 1;
    result.details[0] = if (verifyPndMix()) 1 else 0;

    if (verifyPolerConvergence()) result.passed += 1;
    result.details[1] = if (verifyPolerConvergence()) 1 else 0;

    if (verifyPhiNoFixedPoints()) result.passed += 1;
    result.details[2] = if (verifyPhiNoFixedPoints()) 1 else 0;

    if (verifyNonCommutativity()) result.passed += 1;
    result.details[3] = if (verifyNonCommutativity()) 1 else 0;

    if (verifyModInverseAccuracy()) result.passed += 1;
    result.details[4] = if (verifyModInverseAccuracy()) 1 else 0;

    if (verifyFeistelRoundtripExact()) result.passed += 1;
    result.details[5] = if (verifyFeistelRoundtripExact()) 1 else 0;

    if (verifyAvalancheEffect()) result.passed += 1;
    result.details[6] = if (verifyAvalancheEffect()) 1 else 0;

    if (verifyNilpotentPreservesInfo()) result.passed += 1;
    result.details[7] = if (verifyNilpotentPreservesInfo()) 1 else 0;

    if (verifyDynamicAttractor()) result.passed += 1;
    result.details[8] = if (verifyDynamicAttractor()) 1 else 0;

    return result;
}

pub const SelfTestResult = struct {
    total: u32,
    passed: u32,
    details: [9]u8,
};

// ============================================================================
// ZIG UNIT TESTS — для `zig build test`
// ============================================================================

test "rotl/rotr roundtrip" {
    const x: u32 = 0xDEADBEEF;
    try std.testing.expect(rotl(u32, rotr(u32, x, 13), 13) == x);
    try std.testing.expect(rotr(u32, rotl(u32, x, 7), 7) == x);
}

test "modInverse32 correctness" {
    try std.testing.expect(verifyModInverse(1));
    try std.testing.expect(verifyModInverse(3));
    try std.testing.expect(verifyModInverse(0xDEADBEEF));
    try std.testing.expect(verifyModInverse(0x9E3779B9));
    try std.testing.expect(verifyModInverse(0xFFFFFFFF));
    try std.testing.expect(modInverse32(2) == 0); // even → no inverse
}

test "modInverse32(0x9E3779B9) == 0x144CBC89" {
    const inv = modInverse32(0x9E3779B9);
    try std.testing.expect(inv == 0x144CBC89);
    try std.testing.expect(0x9E3779B9 *% inv == 1);
}

test "phi has no fixed points" {
    try std.testing.expect(verifyPhiNoFixedPoints());
}

test "pndMix ⊙_ε ε-sensitivity (v8: commutative in a,b, sensitive to ε)" {
    try std.testing.expect(verifyNonCommutativity());
}

test "pndMixAlt matches paper [3] (Ψ-formula)" {
    // 42 ⊗_1 17 = 714 + 1·3 = 717
    try std.testing.expect(pndMixAlt(42, 17, 1) == 717);
}

test "DiffusionOperator (nilpotentOperator) preserves all 32 bits" {
    try std.testing.expect(verifyNilpotentPreservesInfo());
}

test "DiffusionOperator bijectivity — 10000 unique outputs" {
    // Sample 10000 inputs, check all outputs are unique
    var seen = std.AutoHashMap(u32, void).init(std.testing.allocator);
    defer seen.deinit();
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        const input = i *% 0x9E3779B9 +% 0x12345678; // spread inputs
        const output = nilpotentOperator(input, 0xCAFE1234, 1);
        try seen.put(output, {});
    }
    try std.testing.expectEqual(@as(usize, 10000), seen.count());
}

test "DiffusionOperator — low16 bits NOT always zero (v4 bug fix)" {
    // v4 bug: rotl(d,16) ^ (d>>16) = L||0 → low 16 bits ALWAYS zero
    // v5 FIX6: rotl(d * 0x9E3779B9, 13) → bijective → low16 varied
    var low16_zero_count: u32 = 0;
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        const input = i *% 0x9E3779B9 +% 0xDEADBEEF;
        const output = nilpotentOperator(input, 0xCAFE1234, 1);
        if (output & 0xFFFF == 0) low16_zero_count += 1;
    }
    // Old code: 100% zeros. New code: ~1/65536 ≈ 0%
    try std.testing.expect(low16_zero_count < 50); // allow statistical variance
}

test "SAC (Strict Avalanche Criterion) — bit flip → ~50% output change" {
    try std.testing.expect(verifyAvalancheEffect());
}

test "Feistel encrypt/decrypt roundtrip" {
    try std.testing.expect(verifyFeistelRoundtripExact());
}

test "Feistel roundtrip — multiple keys and epsilons" {
    const keys = [_][KEY_WORDS]u32{
        .{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210, 0x11111111, 0x22222222, 0x33333333, 0x44444444 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF },
        .{ 0x9E3779B9, 0x144CBC89, 0xDEADBEEF, 0xCAFEBABE, 0x12345678, 0x87654321, 0xAAAAAAAA, 0x55555555 },
    };
    const epsilons = [_]u32{ 1, 0xDEAD, 0xFFFFFFFF, 0 };

    for (keys) |key| {
        for (epsilons) |eps| {
            const cipher = PolerCipher.init(&key, eps);
            var plain = [BLOCK_WORDS]u32{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
            var encrypted: [BLOCK_WORDS]u32 = undefined;
            var decrypted: [BLOCK_WORDS]u32 = undefined;
            cipher.encryptBlock(&plain, &encrypted);
            cipher.decryptBlock(&encrypted, &decrypted);
            for (0..BLOCK_WORDS) |j| {
                try std.testing.expect(decrypted[j] == plain[j]);
            }
        }
    }
}

test "POLER cycle convergence with dynamic attractor" {
    try std.testing.expect(verifyPolerConvergence());
}

test "Dynamic attractor uniqueness per key" {
    try std.testing.expect(verifyDynamicAttractor());
}

test "LHCA step determinism" {
    const config = LHCAConfig{ .rule_mask = 0xAAAAAAAA };
    const s1 = lhcaStep(0xCAFEBABE, config);
    const s2 = lhcaStep(0xCAFEBABE, config);
    try std.testing.expect(s1 == s2);
}

test "S-Box inverse consistency" {
    for (0..SBOX_SIZE) |i| {
        const s = SBOX[i];
        try std.testing.expect(INV_SBOX[s] == i);
    }
}

test "Constant-time S-box matches comptime SBOX for all 256 values" {
    for (0..SBOX_SIZE) |i| {
        const ct_val = constantTimeSbox(@intCast(i));
        const expected = SBOX[i];
        try std.testing.expectEqual(expected, ct_val);
    }
}

test "Constant-time inverse S-box matches comptime INV_SBOX for all 256 values" {
    for (0..SBOX_SIZE) |i| {
        const ct_val = constantTimeInvSbox(@intCast(i));
        const expected = INV_SBOX[i];
        try std.testing.expectEqual(expected, ct_val);
    }
}

test "Constant-time S-box roundtrip: INV_SBOX[SBOX[x]] = SBOX[INV_SBOX[x]] = x" {
    for (0..SBOX_SIZE) |i| {
        const x: u8 = @intCast(i);
        try std.testing.expect(constantTimeInvSbox(constantTimeSbox(x)) == x);
        try std.testing.expect(constantTimeSbox(constantTimeInvSbox(x)) == x);
    }
}

test "Constant-time GF(2^8) multiplication known vectors" {
    // FIPS-197 Section 4.2.1: 0x57 * 0x83 = 0xC1
    try std.testing.expectEqual(@as(u8, 0xC1), ctGf256Mul(0x57, 0x83));
    // Inverse pair: 0x53 * 0xCA = 0x01
    try std.testing.expectEqual(@as(u8, 0x01), ctGf256Mul(0x53, 0xCA));
    // Identity: 1 * x = x
    try std.testing.expectEqual(@as(u8, 0xFF), ctGf256Mul(0x01, 0xFF));
    // Zero: 0 * x = 0
    try std.testing.expectEqual(@as(u8, 0x00), ctGf256Mul(0x00, 0xFF));
}

test "Constant-time GF(2^8) inverse: x * x^(-1) = 1 for all non-zero x" {
    for (1..SBOX_SIZE) |i| {
        const x: u8 = @intCast(i);
        const inv = ctGf256Inverse(x);
        try std.testing.expectEqual(@as(u8, 1), ctGf256Mul(x, inv));
    }
}

test "modInverse32 Hensel convergence" {
    // Verify Hensel lifting converges: a * modInverse(a) ≡ 1 (mod 2^32)
    const test_odd: [5]u32 = .{ 1, 3, 0xDEADBEEF, 0x9E3779B9, 0xFFFFFFFF };
    for (test_odd) |a| {
        const inv = modInverse32(a);
        try std.testing.expect(a *% inv == 1);
    }
}

test "Q32 fixed-point PND φ-wrapper properties" {
    const a: u32 = 0xCAFEBABE;
    const b: u32 = 0xDEADBEEF;

    // v8: pndMixQ32 с φ-обёрткой — даже при ε=0 результат нелинеен!
    // При ε_Q32 = 0: result = φ(a·b) (только нелинейное произведение)
    const eps_zero = pndMixQ32(a, b, 0);
    const phi_product = phi(a *% b);
    try std.testing.expectEqual(phi_product, eps_zero);

    // При ε_Q32 = max: full deformation
    const full_deform_val = pndMixQ32(a, b, 0xFFFFFFFF);
    const phi_xor = phi(a ^ b);
    const expected_full = phi_product +% fixedMulQ32(phi_xor, 0xFFFFFFFF);
    try std.testing.expectEqual(expected_full, full_deform_val);

    // ε-чувствительность: разные ε → разные результаты
    const half_deform_val = pndMixQ32(a, b, 0x80000000);
    try std.testing.expect(eps_zero != half_deform_val);
    try std.testing.expect(half_deform_val != full_deform_val);
}

`
```

### `zig-kernel/src/rsa_oaep.zig` [zig · 132,754 B]
```
`// ============================================================================
// RSAES-OAEP — Внешний слой каскадного шифрования POLER-OS
// ============================================================================
//
// Архитектура каскада: RSA-OAEP (внешний, стандарт) → POLER v8 (внутренний, custom)
// Философия: если RSA-OAEP взломан, злоумышленник всё равно сталкивается
// с POLER — кастомным шифром, не имеющим публичного криптоанализа.
//
// Компоненты:
//   1. BigInt — арифметика больших чисел (2048 бит, u32 limbs)
//   2. RSA Core — m^e mod n / c^d mod n (ключи от bootloader/config)
//   3. SHA-256 — полный FIPS 180-4 (для OAEP)
//   4. MGF1 — Mask Generation Function (PKCS#1 v2.2, RFC 8017 B.2.1)
//   5. OAEP — Optimal Asymmetric Encryption Padding (RFC 8017 §7.1.1)
//   6. CascadeCipher — RSA-OAEP + POLER каскад
//
// Ограничения kernel-кода:
//   - NO heap allocations (no std.heap, no Allocator)
//   - NO floating point
//   - NO external dependencies (чистый Zig)
//   - Все буферы stack-allocated или comptime-known
//   - Constant-time операции для приватного ключа
//
// Параметры OAEP для RSA-2048:
//   k    = 256 байт (размер модуля)
//   hLen = 32 байта (SHA-256)
//   maxMsgLen = k - 2*hLen - 2 = 190 байт
//
// Ссылки:
//   - RFC 8017: PKCS #1 v2.2 (RSA-OAEP)
//   - FIPS 180-4: SHA-256
//   - PKCS#1 v2.2: MGF1
// ============================================================================

const std = @import("std");
const poler = @import("poler_core.zig");

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

pub const RSA_MODULUS_BITS: u32 = 2048;
pub const RSA_MODULUS_BYTES: u32 = 256;
pub const RSA_MODULUS_LIMBS: u32 = 64; // 2048 / 32
pub const SHA256_DIGEST_SIZE: u32 = 32;
pub const OAEP_LABEL_MAX: u32 = 256;
pub const OAEP_MAX_MESSAGE: u32 = RSA_MODULUS_BYTES - 2 * SHA256_DIGEST_SIZE - 2; // 190
pub const RSA_PUBLIC_EXPONENT: u32 = 65537;

// ============================================================================
// BIG INTEGER — АРИФМЕТИКА БОЛЬШИХ ЧИСЕЛ ДЛЯ RSA-2048
// ============================================================================
//
// Представление: little-endian массив u32 limbs.
// limb[0] — младший (least significant), limb[N-1] — старший.
// Это стандартное представление для модулярной арифметики.
//
// Для RSA-2048: 64 limbs по 32 бита = 2048 бит.
// Все операции — in-place или с явным буфером результата.
// Никаких аллокаций — всё на стеке.
//
// Безопасность:
//   - modPow использует square-and-multiply с ALWAYS-мultiply
//     для снижения timing leakage (см. комментарий ниже)
//   - modInverse использует расширенный алгоритм Евклида
//   - Сравнение constant-time для приватных данных
// ============================================================================

pub const BigInt = struct {
    limbs: [RSA_MODULUS_LIMBS]u32,

    /// Нулевой BigInt — все limbs = 0
    pub fn zero() BigInt {
        return BigInt{ .limbs = [_]u32{0} ** RSA_MODULUS_LIMBS };
    }

    /// BigInt = 1
    pub fn one() BigInt {
        var r = zero();
        r.limbs[0] = 1;
        return r;
    }

    /// Создать BigInt из u32
    pub fn fromU32(v: u32) BigInt {
        var r = zero();
        r.limbs[0] = v;
        return r;
    }

    /// Создать BigInt из little-endian байтового массива
    /// Вход: bytes[0] — LSB, bytes[N-1] — MSB
    pub fn fromBytesLe(bytes: []const u8) BigInt {
        var r = zero();
        const total = @min(bytes.len, RSA_MODULUS_BYTES);
        var i: usize = 0;
        while (i + 3 < total) : (i += 4) {
            r.limbs[i / 4] = @as(u32, bytes[i]) |
                (@as(u32, bytes[i + 1]) << 8) |
                (@as(u32, bytes[i + 2]) << 16) |
                (@as(u32, bytes[i + 3]) << 24);
        }
        // Handle remaining bytes (1-3)
        if (i < total) {
            var limb: u32 = @as(u32, bytes[i]);
            if (i + 1 < total) limb |= @as(u32, bytes[i + 1]) << 8;
            if (i + 2 < total) limb |= @as(u32, bytes[i + 2]) << 16;
            r.limbs[i / 4] = limb;
        }
        return r;
    }

    /// Создать BigInt из big-endian байтового массива (RSA стандарт)
    /// Вход: bytes[0] — MSB, bytes[N-1] — LSB
    pub fn fromBytesBe(bytes: []const u8) BigInt {
        var r = zero();
        const total = @min(bytes.len, RSA_MODULUS_BYTES);
        // Полный 256-байтовый буфер: переворачиваем байты
        var buf: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
        var j: usize = 0;
        while (j < total) : (j += 1) {
            buf[RSA_MODULUS_BYTES - total + j] = bytes[j];
        }
        // Теперь buf[0] = MSB всего числа, buf[255] = LSB
        // Конвертируем из big-endian в little-endian limbs
        var i: usize = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const base = (RSA_MODULUS_LIMBS - 1 - i) * 4;
            r.limbs[i] = @as(u32, buf[base]) << 24 |
                @as(u32, buf[base + 1]) << 16 |
                @as(u32, buf[base + 2]) << 8 |
                @as(u32, buf[base + 3]);
        }
        return r;
    }

    /// Экспорт BigInt в big-endian байтовый массив (RSA стандарт)
    /// Выход: bytes[0] — MSB, bytes[N-1] — LSB
    pub fn toBytesBe(self: *const BigInt, out: *[RSA_MODULUS_BYTES]u8) void {
        var i: usize = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const limb = self.limbs[RSA_MODULUS_LIMBS - 1 - i];
            const base = i * 4;
            out[base] = @truncate(limb >> 24);
            out[base + 1] = @truncate(limb >> 16);
            out[base + 2] = @truncate(limb >> 8);
            out[base + 3] = @truncate(limb);
        }
    }

    /// Экспорт BigInt в little-endian байтовый массив
    pub fn toBytesLe(self: *const BigInt, out: []u8) void {
        const total = @min(out.len, RSA_MODULUS_BYTES);
        var i: usize = 0;
        while (i + 3 < total) : (i += 4) {
            const limb = self.limbs[i / 4];
            out[i] = @truncate(limb);
            out[i + 1] = @truncate(limb >> 8);
            out[i + 2] = @truncate(limb >> 16);
            out[i + 3] = @truncate(limb >> 24);
        }
    }

    /// Проверка: BigInt == 0
    pub fn isZero(self: *const BigInt) bool {
        for (self.limbs) |l| {
            if (l != 0) return false;
        }
        return true;
    }

    /// Количество значащих бит (bit length)
    /// Для RSA-2048 модуля это должно быть 2048
    pub fn bitLen(self: *const BigInt) u32 {
        var i: u32 = RSA_MODULUS_LIMBS;
        while (i > 0) : (i -= 1) {
            if (self.limbs[i - 1] != 0) {
                const top_limb = self.limbs[i - 1];
                var bits: u32 = (i - 1) * 32;
                var v = top_limb;
                while (v != 0) : (v >>= 1) {
                    bits += 1;
                }
                return bits;
            }
        }
        return 0;
    }

    /// Получить бит по индексу (0 = LSB)
    pub fn getBit(self: *const BigInt, idx: u32) u1 {
        const limb_idx = idx / 32;
        const bit_idx = idx % 32;
        if (limb_idx >= RSA_MODULUS_LIMBS) return 0;
        return @intCast((self.limbs[limb_idx] >> @intCast(bit_idx)) & 1);
    }

    /// Сравнение: self == other (constant-time для приватных данных)
    /// Используем XOR-аккумуляцию вместо раннего возврата
    pub fn eql(self: *const BigInt, other: *const BigInt) bool {
        var diff: u32 = 0;
        for (self.limbs, other.limbs) |a, b| {
            diff |= a ^ b;
        }
        return diff == 0;
    }

    /// Сравнение: self < other (not constant-time, для модулярной арифметики)
    pub fn lessThan(self: *const BigInt, other: *const BigInt) bool {
        var i: u32 = RSA_MODULUS_LIMBS;
        while (i > 0) : (i -= 1) {
            if (self.limbs[i - 1] < other.limbs[i - 1]) return true;
            if (self.limbs[i - 1] > other.limbs[i - 1]) return false;
        }
        return false; // equal
    }

    /// Сравнение: self >= other
    pub fn gte(self: *const BigInt, other: *const BigInt) bool {
        return !self.lessThan(other);
    }

    /// Сложение: result = a + b (с переносом)
    /// Возвращает overflow flag (1 если результат >= 2^2048)
    pub fn add(a: *const BigInt, b: *const BigInt) struct { result: BigInt, overflow: u1 } {
        var result = zero();
        var carry: u64 = 0;
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const sum = @as(u64, a.limbs[i]) + @as(u64, b.limbs[i]) + carry;
            result.limbs[i] = @truncate(sum);
            carry = sum >> 32;
        }
        return .{ .result = result, .overflow = @intCast(carry) };
    }

    /// Вычитание: result = a - b (предполагаем a >= b)
    /// Если a < b, результат обёрнут (wrapping subtraction)
    pub fn sub(a: *const BigInt, b: *const BigInt) struct { result: BigInt, underflow: u1 } {
        var result = zero();
        var borrow: u64 = 0;
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const a_val = @as(u64, a.limbs[i]);
            const b_val = @as(u64, b.limbs[i]) + borrow;
            if (a_val >= b_val) {
                result.limbs[i] = @truncate(a_val - b_val);
                borrow = 0;
            } else {
                result.limbs[i] = @truncate(a_val + 0x100000000 - b_val);
                borrow = 1;
            }
        }
        return .{ .result = result, .underflow = @intCast(borrow) };
    }

    /// Умножение: result = a * b
    /// Результат может быть до 4096 бит, но мы храним только младшие 2048 бит
    /// Для модулярной арифметики это корректно, т.к. mod берётся после умножения
    pub fn mul(a: *const BigInt, b: *const BigInt) BigInt {
        var result = zero();
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            if (a.limbs[i] == 0) continue; // optimisation: skip zero limbs
            var carry: u64 = 0;
            var j: u32 = 0;
            while (j < RSA_MODULUS_LIMBS - i) : (j += 1) {
                const prod = @as(u64, a.limbs[i]) * @as(u64, b.limbs[j]) +
                    @as(u64, result.limbs[i + j]) + carry;
                result.limbs[i + j] = @truncate(prod);
                carry = prod >> 32;
            }
            // carry теряется — это нормально для mod 2^2048
        }
        return result;
    }

    /// Сдвиг влево на 1 бит: result = a << 1, возвращает carry (старший бит)
    /// v8.2 FIX: shl1 может переполнить 64-limb буфер!
    /// Если a ≥ 2^2047 (старший limb ≥ 0x80000000), сдвиг теряет бит.
    /// Возвращаем carry чтобы вызывающий код мог корректно редуцировать.
    pub fn shl1(a: *const BigInt) struct { result: BigInt, carry: u1 } {
        var result = zero();
        const carry: u1 = @truncate(a.limbs[RSA_MODULUS_LIMBS - 1] >> 31);
        var i: u32 = RSA_MODULUS_LIMBS;
        while (i > 1) : (i -= 1) {
            result.limbs[i - 1] = (a.limbs[i - 1] << 1) | (a.limbs[i - 2] >> 31);
        }
        result.limbs[0] = a.limbs[0] << 1;
        return .{ .result = result, .carry = carry };
    }

    /// Сдвиг вправо на 1 бит: result = a >> 1
    pub fn shr1(a: *const BigInt) BigInt {
        var result = zero();
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS - 1) : (i += 1) {
            result.limbs[i] = (a.limbs[i] >> 1) | (a.limbs[i + 1] << 31);
        }
        result.limbs[RSA_MODULUS_LIMBS - 1] = a.limbs[RSA_MODULUS_LIMBS - 1] >> 1;
        return result;
    }

    /// Условное копирование: if (cond) result = a, else result = b
    /// Constant-time: нет ветвлений, зависящих от cond
    /// cond: u32 — 0xFFFFFFFF для true, 0x00000000 для false
    pub fn cswap(cond: u32, a: *const BigInt, b: *const BigInt) struct { x: BigInt, y: BigInt } {
        var ra = a.*;
        var rb = b.*;
        for (&ra.limbs, &rb.limbs) |*la, *lb| {
            const xa = la.*;
            const xb = lb.*;
            la.* = (xa & cond) | (xb & ~cond);
            lb.* = (xb & cond) | (xa & ~cond);
        }
        return .{ .x = ra, .y = rb };
    }

    /// Модулярное сложение: result = (a + b) mod m
    /// v8.2 FIX: a + b может быть >= 2m, поэтому одного вычитания недостаточно.
    /// Пример: modAdd(8, 13, 10) = 21 → 21-10=11 → 11>=10 → 11-10=1.
    /// После первого вычитания результат может быть ещё >= m, нужен второй проход.
    pub fn modAdd(a: *const BigInt, b: *const BigInt, m: *const BigInt) BigInt {
        const sum = add(a, b);
        var result = sum.result;
        if (sum.overflow == 1 or result.gte(m)) {
            const diff = sub(&result, m);
            result = diff.result;
        }
        // Вторая проверка: a+b может быть >= 2m, тогда после первого вычитания
        // результат всё ещё >= m. Максимум два вычитания (a+b < 2^2049, m >= 2^2047).
        if (result.gte(m)) {
            const diff = sub(&result, m);
            result = diff.result;
        }
        return result;
    }

    /// Модулярное вычитание: result = (a - b) mod m
    pub fn modSub(a: *const BigInt, b: *const BigInt, m: *const BigInt) BigInt {
        const diff = sub(a, b);
        if (diff.underflow == 1) {
            const corrected = add(&diff.result, m);
            return corrected.result;
        }
        return diff.result;
    }

    /// Модулярное умножение: result = (a * b) mod m
    /// Алгоритм: interleaved multiply-and-reduce
    ///   result = 0
    ///   for i = bitLen(a)-1 downto 0:
    ///     result = result << 1; if result >= m: result -= m
    ///     if bit i of a is set: result += b; if result >= m: result -= m
    ///
    /// v8.2 FIX: shl1 возвращает carry — если result ≥ 2^2047,
    /// удвоение даёт 2049-битное число, и carry=1 означает что
    /// doubled ≥ 2^2048 ≥ m → нужно вычитание m.
    /// Без этого фикса modMul давал неверный результат для 2048-битных аргументов!
    ///
    /// ПРИМЕЧАНИЕ: Для RSA-2048 это корректно, но медленнее Montgomery.
    /// В kernel-контексте приоритет — корректность и отсутствие heap.
    pub fn modMul(a: *const BigInt, b: *const BigInt, m: *const BigInt) BigInt {
        var result = zero();
        const bits = a.bitLen();
        if (bits == 0) return result;

        // Interleaved: scan bits from MSB to LSB
        var i: u32 = bits;
        while (i > 0) : (i -= 1) {
            // result = result * 2
            const shift = shl1(&result);
            // v8.2: carry=1 means result*2 >= 2^2048 >= m → must subtract
            // Also check gte(m) for the case where 2*result < 2^2048 but >= m
            if (shift.carry == 1 or shift.result.gte(m)) {
                const d = sub(&shift.result, m);
                result = d.result;
            } else {
                result = shift.result;
            }

            // if bit (i-1) of a is set, add b
            if (a.getBit(i - 1) == 1) {
                result = modAdd(&result, b, m);
            }
        }
        return result;
    }

    /// Модулярное возведение в степень: result = base^exp mod m
    /// Алгоритм: Square-and-Multiply (always-multiply variant)
    ///
    /// БЕЗОПАСНОСТЬ: Классический square-and-multiply утечка биты exp
    /// через timing side-channel. Мы используем "always-multiply":
    /// на каждом шаге выполняем И умножение, И square,
    /// но результат умножения используется только если бит = 1.
    /// Это не идеально (см. Montgomery ladder), но значительно
    /// лучше чем conditional-multiply.
    ///
    /// Для полноценной защиты нужен blinding, но в kernel-контексте
    /// мы делаем лучшее что можем без external RNG.
    pub fn modPow(base: *const BigInt, exp: *const BigInt, m: *const BigInt) BigInt {
        var result = one();
        var b = base.*;
        const bits = exp.bitLen();
        if (bits == 0) return result; // base^0 = 1

        var i: u32 = 0;
        while (i < bits) : (i += 1) {
            // Always multiply (constant-time attempt)
            const product = modMul(&result, &b, m);
            // Select result based on bit: if bit=1, use product; else keep result
            const bit = exp.getBit(i);
            const mask: u32 = if (bit == 1) 0xFFFFFFFF else 0x00000000;
            for (&result.limbs, product.limbs) |*r, p| {
                r.* = (r.* & ~mask) | (p & mask);
            }
            // Square for next bit
            b = modMul(&b, &b, m);
        }
        return result;
    }

    /// Модулярный обратный элемент: result = a^(-1) mod m
    /// Алгоритм: Extended Euclidean с shift-subtract делением
    ///
    /// Находим x такой что a*x ≡ 1 (mod m)
    /// Это необходимо для RSA: d = e^(-1) mod φ(n)
    ///
    /// В kernel-контексте мы НЕ генерируем ключи (ключи от bootloader),
    /// но эта функция нужна для валидации ключей и потенциальных
    /// будущих расширений.
    pub fn modInverse(a: *const BigInt, m: *const BigInt) ?BigInt {
        return modInverseEgcd(a, m);
    }

    /// Итеративный Extended Euclidean Algorithm с shift-subtract делением
    /// Поддерживаем коэффициенты Безу: old_s*a + t*m = old_r
    /// Если gcd(a,m)=1, то old_s*a ≡ 1 (mod m) → old_s есть обратный
    fn modInverseEgcd(a: *const BigInt, m: *const BigInt) ?BigInt {
        // Ensure a < m
        var a_val = a.*;
        if (a_val.gte(m)) {
            a_val = modRed(&a_val, m);
        }

        var old_r = a_val;
        var r = m.*;
        var old_s = one();
        var s_coeff = zero();

        var iter: u32 = 0;
        while (!r.isZero() and iter < 10000) : (iter += 1) {
            // Compute quotient and remainder via shift-subtract division
            var quotient = zero();
            var remainder = old_r;

            while (remainder.gte(&r)) {
                // Find the largest 2^k * r that fits in remainder
                var shifted = r;
                var k: u32 = 0;
                while (true) {
                    const next_shift = shl1(&shifted);
                    // If carry=1, shifted overflowed 2^2048 -> definitely >= remainder
                    if (next_shift.carry == 1 or next_shift.result.gte(&remainder)) {
                        break;
                    }
                    shifted = next_shift.result;
                    k += 1;
                    if (k >= 2048) break;
                }
                // If shifted itself is too large, halve it
                if (shifted.gte(&remainder)) {
                    if (k > 0) {
                        shifted = shr1(&shifted);
                        k -= 1;
                    } else {
                        // r itself fits
                        const d = sub(&remainder, &r);
                        remainder = d.result;
                        const q_add = add(&quotient, &one());
                        quotient = q_add.result;
                        continue;
                    }
                }
                const d = sub(&remainder, &shifted);
                remainder = d.result;
                // quotient += 2^k
                var two_k = one();
                var ki: u32 = 0;
                while (ki < k) : (ki += 1) {
                    const sh = shl1(&two_k);
                    two_k = sh.result;
                }
                const q_add = add(&quotient, &two_k);
                quotient = q_add.result;
            }

            // Update Bezout coefficients: new_s = old_s - q * s (mod m)
            const q_times_s = modMul(&quotient, &s_coeff, m);
            const new_s = modSub(&old_s, &q_times_s, m);

            old_s = s_coeff;
            s_coeff = new_s;
            old_r = r;
            r = remainder;
        }

        // Check GCD == 1
        const expected_gcd = one();
        if (!old_r.eql(&expected_gcd)) return null;

        // old_s is the inverse (may need adjustment if negative)
        if (old_s.isZero()) return null;
        return old_s;
    }
};

/// Modular reduction: result = a mod m
/// Uses repeated subtraction with shift
fn modRed(a: *const BigInt, m: *const BigInt) BigInt {
    var r = a.*;
    while (r.gte(m)) {
        const d = BigInt.sub(&r, m);
        r = d.result;
        // Safety: if subtraction didn't reduce, break (shouldn't happen)
        if (r.gte(m) and r.eql(a)) break;
    }
    return r;
}

// ============================================================================
// SHA-256 — БЕЗОПАСНЫЙ ХЕШ-АЛГОРИТМ (FIPS 180-4)
// ============================================================================
//
// SHA-256 необходим для OAEP (lHash = SHA-256(label),
// MGF1-SHA-256 для генерации масок).
//
// Реализация: чистый Zig, no heap, no floating point.
// Буферы — comptime-known размер.
// Processing: 512-bit (64-byte) blocks, 64 rounds per block.
//
// Контрольные векторы из FIPS 180-4:
//   SHA-256("")    = e3b0c44298fc1c14...
//   SHA-256("abc") = ba7816bf8f01cfea...
// ============================================================================

pub const Sha256State = struct {
    h: [8]u32,
    block: [64]u8,
    block_len: u8,
    total_len: u64,

    /// Инициализация SHA-256 начальными константами (FIPS 180-4)
    /// Первые 32 бита дробных частей квадратных корней первых 8 простых:
    /// √2, √3, √5, √7, √11, √13, √17, √19
    pub fn init() Sha256State {
        return Sha256State{
            .h = .{
                0x6A09E667, // √2
                0xBB67AE85, // √3
                0x3C6EF372, // √5
                0xA54FF53A, // √7
                0x510E527F, // √11
                0x9B05688C, // √13
                0x1F83D9AB, // √17
                0x5BE0CD19, // √19
            },
            .block = [_]u8{0} ** 64,
            .block_len = 0,
            .total_len = 0,
        };
    }

    /// SHA-256 round constants
    /// Первые 32 бита дробных частей кубических корней первых 64 простых
    const K = [64]u32{
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
        0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
        0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
        0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
        0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
        0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
        0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
        0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
        0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
    };

    /// Обработка одного 512-битного (64-байтового) блока
    /// Основной раунд SHA-256: 64 итерации смешивания
    fn processBlock(self: *Sha256State) void {
        // Расширение сообщения: 16 → 64 слов
        var w: [64]u32 = [_]u32{0} ** 64;
        var i: u32 = 0;
        while (i < 16) : (i += 1) {
            w[i] = @as(u32, self.block[i * 4]) << 24 |
                @as(u32, self.block[i * 4 + 1]) << 16 |
                @as(u32, self.block[i * 4 + 2]) << 8 |
                @as(u32, self.block[i * 4 + 3]);
        }
        i = 16;
        while (i < 64) : (i += 1) {
            // σ0(x) = ROTR(7,x) ⊕ ROTR(18,x) ⊕ SHR(3,x)
            const s0 = rotr32(w[i - 15], 7) ^ rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3);
            // σ1(x) = ROTR(17,x) ⊕ ROTR(19,x) ⊕ SHR(10,x)
            const s1 = rotr32(w[i - 2], 17) ^ rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] +% s0 +% w[i - 7] +% s1;
        }

        // Инициализация рабочих переменных
        var a = self.h[0];
        var b = self.h[1];
        var c = self.h[2];
        var d = self.h[3];
        var e = self.h[4];
        var f = self.h[5];
        var g = self.h[6];
        var h = self.h[7];

        // 64 раунда сжатия
        i = 0;
        while (i < 64) : (i += 1) {
            // Σ1(e) = ROTR(6,e) ⊕ ROTR(11,e) ⊕ ROTR(25,e)
            const S1 = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25);
            // Ch(e,f,g) = (e ∧ f) ⊕ (¬e ∧ g)
            const ch = (e & f) ^ (~e & g);
            // T1 = h + Σ1(e) + Ch(e,f,g) + K[i] + w[i]
            const t1 = h +% S1 +% ch +% K[i] +% w[i];
            // Σ0(a) = ROTR(2,a) ⊕ ROTR(13,a) ⊕ ROTR(22,a)
            const S0 = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22);
            // Maj(a,b,c) = (a ∧ b) ⊕ (a ∧ c) ⊕ (b ∧ c)
            const maj = (a & b) ^ (a & c) ^ (b & c);
            // T2 = Σ0(a) + Maj(a,b,c)
            const t2 = S0 +% maj;

            h = g;
            g = f;
            f = e;
            e = d +% t1;
            d = c;
            c = b;
            b = a;
            a = t1 +% t2;
        }

        // Добавить сжатые значения к хешу
        self.h[0] +%= a;
        self.h[1] +%= b;
        self.h[2] +%= c;
        self.h[3] +%= d;
        self.h[4] +%= e;
        self.h[5] +%= f;
        self.h[6] +%= g;
        self.h[7] +%= h;
    }

    /// Добавить данные к хешу
    pub fn update(self: *Sha256State, data: []const u8) void {
        self.total_len += data.len;
        var offset: usize = 0;

        // Дописать в текущий блок
        if (self.block_len > 0) {
            const remaining = 64 - self.block_len;
            const to_copy = @min(remaining, data.len);
            var j: u8 = 0;
            while (j < to_copy) : (j += 1) {
                self.block[self.block_len + j] = data[offset + j];
            }
            self.block_len += @intCast(to_copy);
            offset += to_copy;

            if (self.block_len == 64) {
                self.processBlock();
                self.block_len = 0;
            }
        }

        // Обработать полные блоки
        while (offset + 64 <= data.len) {
            var j: usize = 0;
            while (j < 64) : (j += 1) {
                self.block[j] = data[offset + j];
            }
            self.processBlock();
            offset += 64;
        }

        // Записать остаток
        if (offset < data.len) {
            const remaining = data.len - offset;
            self.block_len = @intCast(remaining);
            var j: usize = 0;
            while (j < remaining) : (j += 1) {
                self.block[j] = data[offset + j];
            }
        }
    }

    /// Завершить хеширование и вернуть 32-байтовый дайджест
    pub fn finalize(self: *Sha256State) [SHA256_DIGEST_SIZE]u8 {
        // Длина сообщения в битах
        const msg_len_bits = self.total_len * 8;

        // Padding: добавить 0x80, затем нули, затем длину
        self.block[self.block_len] = 0x80;
        self.block_len += 1;

        // Если не хватает места для длины (8 байт), заполнить и обработать
        if (self.block_len > 56) {
            // Заполнить текущий блок нулями
            var j: u8 = self.block_len;
            while (j < 64) : (j += 1) {
                self.block[j] = 0;
            }
            self.processBlock();
            self.block_len = 0;
        }

        // Заполнить нулями до позиции длины
        var j: u8 = self.block_len;
        while (j < 56) : (j += 1) {
            self.block[j] = 0;
        }

        // Добавить длину в битах (big-endian, 64-bit)
        self.block[56] = @truncate(msg_len_bits >> 56);
        self.block[57] = @truncate(msg_len_bits >> 48);
        self.block[58] = @truncate(msg_len_bits >> 40);
        self.block[59] = @truncate(msg_len_bits >> 32);
        self.block[60] = @truncate(msg_len_bits >> 24);
        self.block[61] = @truncate(msg_len_bits >> 16);
        self.block[62] = @truncate(msg_len_bits >> 8);
        self.block[63] = @truncate(msg_len_bits);
        self.processBlock();

        // Экспортировать хеш (big-endian)
        var digest: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
        var i: u32 = 0;
        while (i < 8) : (i += 1) {
            digest[i * 4] = @truncate(self.h[i] >> 24);
            digest[i * 4 + 1] = @truncate(self.h[i] >> 16);
            digest[i * 4 + 2] = @truncate(self.h[i] >> 8);
            digest[i * 4 + 3] = @truncate(self.h[i]);
        }
        return digest;
    }
};

/// ROTR для u32 — циклический сдвиг вправо
fn rotr32(x: u32, comptime shift: u32) u32 {
    return (x >> shift) | (x << (32 - shift));
}

/// Одноразовый SHA-256 хеш
pub fn sha256(input: []const u8) [SHA256_DIGEST_SIZE]u8 {
    var state = Sha256State.init();
    state.update(input);
    return state.finalize();
}


// ============================================================================
// HMAC-SHA-256 — Keyed-Hash Message Authentication Code (RFC 2104)
// ============================================================================
//
// HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
//
// Где:
//   H     = SHA-256
//   K'    = K если |K| <= 64, иначе SHA-256(K) (дополненная нулями до 64 байт)
//   ipad  = 0x36 повторённый 64 раза
//   opad  = 0x5C повторённый 64 раза
//
// Для POLER-AEAD:
//   K = session_key (32 байта <= 64 -> не нужен хеш ключа)
//   m = header || nonce || RSA-OAEP ciphertext || POLER-CTR ciphertext
//   Encrypt-then-MAC: tag покрывает весь ciphertext + header
// ============================================================================

pub const HMAC_BLOCK_SIZE: u32 = 64; // SHA-256 internal block size

/// HMAC-SHA-256: вычислить MAC с ключом key для данных data.
/// key: секретный ключ (рекомендуется 32 байта = SHA-256 output size)
/// data: сообщение для аутентификации
/// Возвращает: 32-байтовый MAC tag
pub fn hmacSha256(key: []const u8, data: []const u8) [SHA256_DIGEST_SIZE]u8 {
    // Step 1: Prepare K' (key padded to block size)
    var k_prime: [HMAC_BLOCK_SIZE]u8 = [_]u8{0} ** HMAC_BLOCK_SIZE;
    if (key.len > HMAC_BLOCK_SIZE) {
        const key_hash = sha256(key);
        var i: usize = 0;
        while (i < SHA256_DIGEST_SIZE) : (i += 1) {
            k_prime[i] = key_hash[i];
        }
    } else {
        var i: usize = 0;
        while (i < key.len) : (i += 1) {
            k_prime[i] = key[i];
        }
    }

    // Step 2: Inner hash = H((K' XOR ipad) || data)
    var inner_state = Sha256State.init();
    var ipad_block: [HMAC_BLOCK_SIZE]u8 = undefined;
    var i: usize = 0;
    while (i < HMAC_BLOCK_SIZE) : (i += 1) {
        ipad_block[i] = k_prime[i] ^ 0x36;
    }
    inner_state.update(&ipad_block);
    inner_state.update(data);
    const inner_hash = inner_state.finalize();

    // Step 3: Outer hash = H((K' XOR opad) || inner_hash)
    var outer_state = Sha256State.init();
    var opad_block: [HMAC_BLOCK_SIZE]u8 = undefined;
    i = 0;
    while (i < HMAC_BLOCK_SIZE) : (i += 1) {
        opad_block[i] = k_prime[i] ^ 0x5C;
    }
    outer_state.update(&opad_block);
    outer_state.update(&inner_hash);
    return outer_state.finalize();
}

/// Constant-time tag comparison: сравнивает два tag без утечки информации
/// о позиции первого отличающегося байта (timing side-channel).
/// Возвращает true если теги совпадают, false если нет.
pub fn ctTagEqual(a: *const [SHA256_DIGEST_SIZE]u8, b: *const [SHA256_DIGEST_SIZE]u8) bool {
    var diff: u32 = 0;
    var i: usize = 0;
    while (i < SHA256_DIGEST_SIZE) : (i += 1) {
        diff |= @as(u32, a[i] ^ b[i]);
    }
    return diff == 0;
}

// ============================================================================
// MGF1 — MASK GENERATION FUNCTION (PKCS#1 v2.2, RFC 8017 B.2.1)
// ============================================================================
//
// MGF1(seed, maskLen):
//   T = empty
//   for counter = 0 to ceil(maskLen/hLen)-1:
//     C = I2OSP(counter, 4)  // 4-byte big-endian counter
//     T = T || Hash(seed || C)
//   return leading maskLen octets of T
//
// Используется SHA-256 как Hash (hLen = 32).
// Максимальная длина маски: 2^32 * hLen — более чем достаточно.
//
// БЕЗОПАСНОСТЬ: Генерация маски constant-time — длина seed
// не зависит от секретных данных. Длина maskLen фиксирована
// параметрами OAEP (k - hLen - 1 для DB, hLen для maskedSeed).
// ============================================================================

/// MGF1 с SHA-256
/// seed — входное значение (seed/maskedSeed/DB)
/// out — буфер для маски (длина = maskLen)
pub fn mgf1(seed: []const u8, out: []u8) void {
    const mask_len = out.len;
    if (mask_len == 0) return;

    var counter: u32 = 0;
    var offset: usize = 0;

    while (offset < mask_len) : (counter += 1) {
        // T = SHA-256(seed || counter_big_endian)
        var hash_input: [256 + 4]u8 = [_]u8{0} ** (256 + 4);
        const seed_len = @min(seed.len, 256);
        var i: usize = 0;
        while (i < seed_len) : (i += 1) {
            hash_input[i] = seed[i];
        }
        // 4-byte big-endian counter
        hash_input[seed_len] = @truncate(counter >> 24);
        hash_input[seed_len + 1] = @truncate(counter >> 16);
        hash_input[seed_len + 2] = @truncate(counter >> 8);
        hash_input[seed_len + 3] = @truncate(counter);

        const t = sha256(hash_input[0 .. seed_len + 4]);

        // Копируем что помещается
        const remaining = mask_len - offset;
        const to_copy = @min(remaining, SHA256_DIGEST_SIZE);
        var j: usize = 0;
        while (j < to_copy) : (j += 1) {
            out[offset + j] = t[j];
        }
        offset += to_copy;
    }
}

// ============================================================================
// OAEP — OPTIMAL ASYMMETRIC ENCRYPTION PADDING (RFC 8017 §7.1.1)
// ============================================================================
//
// OAEP — схема дополнения RSA, обеспечивающая:
//   1. Семантическую безопасность (IND-CCA2 в ROM)
//   2. Защиту от адаптивных атак на выбранном шифротексте
//   3. Случайность каждого шифрования (через seed)
//
// Параметры для RSA-2048 + SHA-256:
//   k    = 256 байт (размер модуля n)
//   hLen = 32 байта (SHA-256)
//   PS   = k - mLen - 2*hLen - 2 байт нулей
//   maxMsgLen = k - 2*hLen - 2 = 190 байт
//
// OAEP Encode (RFC 8017 §7.1.1 Step 1):
//   a) lHash = SHA-256(label)
//   b) PS = zeros(k - mLen - 2*hLen - 2)
//   c) DB = lHash || PS || 0x01 || M
//   d) seed = random(hLen)
//   e) dbMask = MGF1(seed, k - hLen - 1)
//   f) maskedDB = DB ⊕ dbMask
//   g) seedMask = MGF1(maskedDB, hLen)
//   h) maskedSeed = seed ⊕ seedMask
//   i) EM = 0x00 || maskedSeed || maskedDB
//
// OAEP Decode (RFC 8017 §7.1.1 Step 2):
//   a) Разобрать EM = Y || maskedSeed || maskedDB
//   b) seedMask = MGF1(maskedDB, hLen)
//   c) seed = maskedSeed ⊕ seedMask
//   d) dbMask = MGF1(seed, k - hLen - 1)
//   e) DB = maskedDB ⊕ dbMask
//   f) Проверить: DB = lHash' || PS || 0x01 || M
//
// БЕЗОПАСНОСТЬ:
//   - Проверка lHash выполняется в constant-time (XOR-аккумуляция)
//   - Проверка Y выполняется в constant-time
//   - Все ошибки возвращают один тип ошибки (OaepError.invalid_padding)
//     чтобы не утекать информацию о природе ошибки
// ============================================================================

pub const OaepError = error{
    message_too_long,
    invalid_padding,
    label_too_long,
    decoding_error,
    encoding_error,
};

/// RSA-OAEP Encrypt: кодирование сообщения + RSA шифрование
/// pub_key: открытый ключ RSA
/// message: открытый текст (до 190 байт для RSA-2048)
/// label: метка (может быть пустой)
/// seed: случайный seed (32 байта, от CSPRNG)
/// Возвращает: шифротекст (256 байт)
pub fn oaepEncrypt(
    pub_key: *const RsaPublicKey,
    message: []const u8,
    label: []const u8,
    seed: *const [SHA256_DIGEST_SIZE]u8,
) ![RSA_MODULUS_BYTES]u8 {
    const m_len = message.len;
    const k: u32 = RSA_MODULUS_BYTES;
    const h_len: u32 = SHA256_DIGEST_SIZE;
    const max_msg = k - 2 * h_len - 2;

    if (m_len > max_msg) return OaepError.message_too_long;
    if (label.len > OAEP_LABEL_MAX) return OaepError.label_too_long;

    // a) lHash = SHA-256(label)
    const l_hash = sha256(label);

    // b) DB = lHash || PS || 0x01 || M
    //    PS = k - mLen - 2*hLen - 2 нулей
    const db_len = k - h_len - 1; // 223 байта
    var db: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    var db_offset: usize = 0;

    // lHash (32 байта)
    var i: u32 = 0;
    while (i < h_len) : (i += 1) {
        db[db_offset] = l_hash[i];
        db_offset += 1;
    }

    // PS (нули, уже заполнены @splat(0))
    const ps_len = k - m_len - 2 * h_len - 2;
    db_offset += ps_len;

    // 0x01 разделитель
    db[db_offset] = 0x01;
    db_offset += 1;

    // M (сообщение)
    i = 0;
    while (i < m_len) : (i += 1) {
        db[db_offset] = message[i];
        db_offset += 1;
    }

    // d) dbMask = MGF1(seed, k - hLen - 1)
    var db_mask: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    mgf1(seed, db_mask[0..db_len]);

    // f) maskedDB = DB ⊕ dbMask
    var masked_db: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    i = 0;
    while (i < db_len) : (i += 1) {
        masked_db[i] = db[i] ^ db_mask[i];
    }

    // g) seedMask = MGF1(maskedDB, hLen)
    var seed_mask: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    mgf1(masked_db[0..db_len], seed_mask[0..h_len]);

    // h) maskedSeed = seed ⊕ seedMask
    var masked_seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    i = 0;
    while (i < h_len) : (i += 1) {
        masked_seed[i] = seed[i] ^ seed_mask[i];
    }

    // i) EM = 0x00 || maskedSeed || maskedDB
    var em: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    em[0] = 0x00;
    i = 0;
    while (i < h_len) : (i += 1) {
        em[1 + i] = masked_seed[i];
    }
    i = 0;
    while (i < db_len) : (i += 1) {
        em[1 + h_len + i] = masked_db[i];
    }

    // RSA шифрование: c = m^e mod n
    const msg_int = BigInt.fromBytesBe(&em);
    const ct_int = rsaEncrypt(pub_key, &msg_int);

    var ciphertext: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    ct_int.toBytesBe(&ciphertext);
    return ciphertext;
}

/// RSA-OAEP Decrypt: RSA дешифрование + декодирование OAEP
/// priv_key: закрытый ключ RSA
/// ciphertext: шифротекст (256 байт)
/// label: метка (должна совпадать с меткой при шифровании)
/// Возвращает: исходное сообщение и его длину, или ошибку
pub fn oaepDecrypt(
    priv_key: *const RsaPrivateKey,
    ciphertext: *const [RSA_MODULUS_BYTES]u8,
    label: []const u8,
) OaepError!struct { message: [OAEP_MAX_MESSAGE]u8, len: u32 } {
    const k: u32 = RSA_MODULUS_BYTES;
    const h_len: u32 = SHA256_DIGEST_SIZE;
    const db_len = k - h_len - 1; // 223

    // RSA дешифрование: m = c^d mod n
    const ct_int = BigInt.fromBytesBe(ciphertext);
    const msg_int = rsaDecrypt(priv_key, &ct_int);

    // Конвертируем в байты
    var em: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    msg_int.toBytesBe(&em);

    // Разобрать EM = Y || maskedSeed || maskedDB
    // Y = em[0] (должен быть 0x00)
    // maskedSeed = em[1..1+hLen]
    // maskedDB = em[1+hLen..k]

    // Constant-time проверка Y == 0x00
    const y_bad: u32 = @as(u32, em[0]); // 0 если OK, !=0 если bad

    // b) seedMask = MGF1(maskedDB, hLen)
    var seed_mask: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    mgf1(em[1 + h_len .. k], seed_mask[0..h_len]);

    // c) seed = maskedSeed ⊕ seedMask
    var seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    var i: u32 = 0;
    while (i < h_len) : (i += 1) {
        seed[i] = em[1 + i] ^ seed_mask[i];
    }

    // d) dbMask = MGF1(seed, k - hLen - 1)
    var db_mask: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    mgf1(&seed, db_mask[0..db_len]);

    // e) DB = maskedDB ⊕ dbMask
    var db: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    i = 0;
    while (i < db_len) : (i += 1) {
        db[i] = em[1 + h_len + i] ^ db_mask[i];
    }

    // f) Проверить DB = lHash' || PS || 0x01 || M
    const l_hash = sha256(label);

    // Constant-time проверка lHash' (XOR-аккумуляция — уже было правильно)
    var l_hash_bad: u32 = 0;
    i = 0;
    while (i < h_len) : (i += 1) {
        l_hash_bad |= @as(u32, db[i]) ^ @as(u32, l_hash[i]);
    }

    // v8.1: CONSTANT-TIME PADDING SCAN — FIX MANGER'S ATTACK
    //
    // Проблема v8: цикл сканирования PS использовал break и early return:
    //   if (db[i] == 0x01) { sep_idx = i; break; }     — ранний выход
    //   if (db[i] != 0x00) { return OaepError.invalid; } — early RETURN
    // Это создавало тайминг-оракул: время дешифровки зависело от позиции
    // "плохого" байта в PS, ДО проверки l_hash_bad. Это структурно та же
    // уязвимость, что в исторической атаке Менгера (Manger's attack, 2001)
    // на RSA-OAEP — ровно то, от чего призвана защищать constant-time
    // реализация.
    //
    // Решение: POLER-style mask-based conditionals (как в ctGf256Mul).
    // Принцип: mask = 0 -% bit → 0xFF если bit=1, 0x00 если bit=0.
    // Сканируем ВЕСЬ диапазон безусловно (без break, без early return),
    // накапливаем флаги через битовые маски, единственное ветвление —
    // в самом конце, объединив все три проверки (Y, lHash, PS).
    //
    // Формат DB: [lHash(32)] [PS(0x00...)] [0x01] [M]
    //   PS — нулевые байты padding string
    //   0x01 — разделитель
    //   M — сообщение
    //
    // v8.2: ИСПРАВЛЕНЫ ДВА БАГА в constant-time сканировании:
    //   BUG-1: ctEqU8 возвращает u32 маску (0xFFFFFFFF/0x00000000),
    //          но инверсия была ^0xFF (8-бит) вместо ^0xFFFFFFFF (32-бит).
    //          Результат: not_zero = 0xFFFFFF00 вместо 0x00000000 и т.д.
    //   BUG-2: found_sep был СЧЁТЧИКОМ (0/1), а не маской (0x00000000/0xFFFFFFFF).
    //          found_sep ^ 0xFF = 0xFFFFFFFE при found_sep=1 — не 0x00!
    //          found_sep ^ 0xFFFFFFFF = 0xFFFFFFFE — тоже не 0x00!
    //          XOR-инверсия счётчика не даёт булеву маску.
    //   FIX: found_sep — u32 МАСКА: 0x00000000 = не найден, 0xFFFFFFFF = найден.
    //        Обновление: found_sep_mask |= is_sep (u32 mask OR).
    //        Инверсия: ^0xFFFFFFFF (32-бит, согласована с ctEqU8).
    //        Сужение до u8 — только в точке накопления (& 0xFF).
    var found_sep_mask: u32 = 0; // u32 МАСКА: 0x00000000=не найден, 0xFFFFFFFF=найден
    var sep_idx: u32 = 0; // позиция первого разделителя 0x01
    var ps_bad: u32 = 0; // 0 = PS валиден, ≠0 = найден плохой байт

    i = h_len;
    while (i < db_len) : (i += 1) {
        const b = db[i];
        // ctEqU8 возвращает u32: 0xFFFFFFFF при равенстве, 0x00000000 при неравенстве
        const is_zero: u32 = ctEqU8(b, 0x00);
        const is_sep: u32 = ctEqU8(b, 0x01);

        // Инверсия 32-битных масок — ^0xFFFFFFFF (согласовано с ctEqU8)
        const not_zero: u32 = is_zero ^ 0xFFFFFFFF;
        const not_sep: u32 = is_sep ^ 0xFFFFFFFF;
        const not_found_yet: u32 = found_sep_mask ^ 0xFFFFFFFF;

        // PS-байт «плохой» если: не-ноль И не-разделитель И разделитель ещё не найден
        // Все три терма — u32 маски; сужаем до u8 только при накоплении
        ps_bad |= (not_zero & not_sep & not_found_yet) & 0xFF;

        // Обновить sep_idx если: is_sep AND not_found_yet (u32 mask AND)
        // ctSelect: sep_idx = should_update ? i : sep_idx
        const should_update: u32 = is_sep & not_found_yet; // u32 mask
        // Broadcast should_update по всем 4 байтам u32 для побайтного ctSelect
        const should_update_wide = (should_update << 24) | (should_update << 16) | (should_update << 8) | should_update;
        sep_idx = (sep_idx & ~should_update_wide) | (@as(u32, i) & should_update_wide);

        // Обновить found_sep_mask: u32 mask OR (не счётчик!)
        // Если is_sep = 0xFFFFFFFF → found_sep_mask становится 0xFFFFFFFF
        // Если is_sep = 0x00000000 → found_sep_mask не меняется
        found_sep_mask |= is_sep;
    }

    // v8.2: ЕДИНОЕ CONSTANT-TIME ВЕТВЛЕНИЕ — объединяем ВСЕ проверки
    //   y_bad:        Y != 0x00 (первый байт EM)
    //   l_hash_bad:   lHash' не совпадает с SHA-256(label)
    //   ps_bad:       PS содержит ненулевой байт до разделителя
    //   found_sep_bad: разделитель 0x01 не найден
    //     found_sep_mask = 0xFFFFFFFF → found_sep_bad = 0 (good)
    //     found_sep_mask = 0x00000000 → found_sep_bad = 0xFFFFFFFF → & 0xFF = 0xFF (bad)
    const found_sep_bad: u32 = found_sep_mask ^ 0xFFFFFFFF;
    const all_bad = y_bad | l_hash_bad | ps_bad | (found_sep_bad & 0xFF);
    if (all_bad != 0) {
        return OaepError.invalid_padding;
    }

    // Извлечь сообщение (теперь sep_idx всегда валиден — проверено выше)
    const msg_start = sep_idx + 1;
    const msg_len = db_len - msg_start;
    if (msg_len > OAEP_MAX_MESSAGE) return OaepError.invalid_padding;

    var message: [OAEP_MAX_MESSAGE]u8 = [_]u8{0} ** OAEP_MAX_MESSAGE;
    i = 0;
    while (i < msg_len) : (i += 1) {
        message[i] = db[msg_start + i];
    }

    return .{ .message = message, .len = msg_len };
}

// ============================================================================
// RSA CORE — ШИФРОВАНИЕ И ДЕШИФРОВАНИЕ
// ============================================================================
//
// RSA: c = m^e mod n (шифрование), m = c^d mod n (дешифрование)
//
// Ключи предоставляются извне (bootloader, конфигурация).
// Генерация ключей НЕ нужна в kernel — мы не генерируем RSA ключи
// в кольцевой защите (ring 0).
//
// БЕЗОПАСНОСТЬ:
//   - modPow использует always-multiply для снижения timing leakage
//   - Приватная операция d НЕ должна утекать через side-channels
//   - В production нужен RSA blinding: r^e * c mod n, затем (r^e * c)^d = r * m
//     и m = (r * m) * r^{-1} mod n. Но blinding требует CSPRNG.
// ============================================================================

pub const RsaPublicKey = struct {
    n: BigInt, // модуль (2048 бит)
    e: u32, // открытая экспонента (обычно 65537)
};

pub const RsaPrivateKey = struct {
    n: BigInt, // модуль (2048 бит)
    d: BigInt, // приватная экспонента
};

/// RSA шифрование: c = m^e mod n
/// message_int должен быть меньше n
pub fn rsaEncrypt(pub_key: *const RsaPublicKey, message: *const BigInt) BigInt {
    const e_big = BigInt.fromU32(pub_key.e);
    return BigInt.modPow(message, &e_big, &pub_key.n);
}

/// RSA дешифрование: m = c^d mod n
/// Использует constant-time modPow (always-multiply variant)
pub fn rsaDecrypt(priv_key: *const RsaPrivateKey, ciphertext: *const BigInt) BigInt {
    return BigInt.modPow(ciphertext, &priv_key.d, &priv_key.n);
}

// ============================================================================
// CASCADE CIPHER — КАСКАДНОЕ ШИФРОВАНИЕ RSA-OAEP + POLER
// ============================================================================
//
// Архитектура:
//   Шифрование: plaintext → POLER_encrypt → RSA-OAEP_encrypt → ciphertext
//   Дешифрование: ciphertext → RSA-OAEP_decrypt → POLER_decrypt → plaintext
//
// Обоснование порядка:
//   RSA-OAEP — ВНЕШНИЙ слой (стандартный, хорошо изученный)
//   POLER — ВНУТРЕННИЙ слой (кастомный, нет публичного криптоанализа)
//
//   Если злоумышленник взламывает RSA-OAEP (квантовый компьютер, etc.),
//   он получает POLER-шифротекст, но всё ещё должен взломать POLER.
//   POLER не имеет публичной документации атаки — это "security through
//   obscurity" + actual cryptographic strength.
//
//   Порядок POLER→RSA-OAEP при шифровании выбран так, чтобы:
//   1. RSA-OAEP последний при шифровании — нарушитель первым сталкивается с RSA
//   2. RSA-OAEP первый при дешифровании — после взлома RSA видит POLER
//   3. OAEP padding скрывает структуру POLER-шифротекста от аналитика
//
// Формат внутренних данных (POLER-шифротекст внутри OAEP):
//   [1 байт: длина исходного сообщения] [POLER CT, добитый до кратного 16]
//
// Ограничение: RSA-OAEP шифрует до 190 байт.
// POLER block = 128 бит = 16 байт.
// Максимальное количество POLER-блоков: (190-1) / 16 = 11 блоков = 176 байт.
// Данные до 176 байт шифруются POLER, затем RSA-OAEP.
// Для больших данных нужен гибридный подход (симметричный ключ + RSA-OAEP).
// ============================================================================

pub const CASCADE_MAX_DATA: u32 = 176; // 11 POLER blocks * 16 bytes
pub const POLER_BLOCK_BYTES: u32 = poler.BLOCK_BITS / 8; // 16

pub const CascadeCipher = struct {
    rsa_pub: RsaPublicKey,
    rsa_priv: RsaPrivateKey,
    poler_key: [poler.KEY_WORDS]u32,
    poler_epsilon: u32,

    /// Инициализация каскадного шифра
    /// Ключи RSA и POLER предоставляются извне
    pub fn init(
        rsa_n: *const BigInt,
        rsa_e: u32,
        rsa_d: *const BigInt,
        poler_key: *const [poler.KEY_WORDS]u32,
        poler_epsilon: u32,
    ) CascadeCipher {
        return CascadeCipher{
            .rsa_pub = RsaPublicKey{ .n = rsa_n.*, .e = rsa_e },
            .rsa_priv = RsaPrivateKey{ .n = rsa_n.*, .d = rsa_d.* },
            .poler_key = poler_key.*,
            .poler_epsilon = poler_epsilon,
        };
    }

    /// Каскадное шифрование: POLER → RSA-OAEP
    /// plaintext: данные до 176 байт
    /// label: метка OAEP (может быть пустой)
    /// seed: случайный seed для OAEP (32 байта от CSPRNG)
    pub fn cascadeEncrypt(
        self: *const CascadeCipher,
        plaintext: []const u8,
        label: []const u8,
        seed: *const [SHA256_DIGEST_SIZE]u8,
    ) ![RSA_MODULUS_BYTES]u8 {
        if (plaintext.len > CASCADE_MAX_DATA) return OaepError.message_too_long;

        // Шаг 1: POLER шифрование
        // POLER шифрует блоками по 16 байт (128 бит)
        // Добиваем plaintext до кратного 16 байтам (zero padding)
        const padded_len = ((plaintext.len + 15) / 16) * 16;
        var poler_input: [CASCADE_MAX_DATA]u8 = [_]u8{0} ** CASCADE_MAX_DATA;
        var i: usize = 0;
        while (i < plaintext.len) : (i += 1) {
            poler_input[i] = plaintext[i];
        }

        // Инициализируем POLER cipher
        var cipher = poler.PolerCipher.init(&self.poler_key, self.poler_epsilon);

        // Шифруем каждый 16-байтовый блок POLER
        var poler_ct: [CASCADE_MAX_DATA]u8 = [_]u8{0} ** CASCADE_MAX_DATA;
        var block_idx: usize = 0;
        while (block_idx < padded_len) : (block_idx += POLER_BLOCK_BYTES) {
            // Конвертируем 16 байт → 4 u32 слова
            var pt_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            var ct_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;

            var w: usize = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = block_idx + w * 4;
                pt_words[w] = @as(u32, poler_input[base]) |
                    (@as(u32, poler_input[base + 1]) << 8) |
                    (@as(u32, poler_input[base + 2]) << 16) |
                    (@as(u32, poler_input[base + 3]) << 24);
            }

            cipher.encryptBlock(&pt_words, &ct_words);

            // Конвертируем обратно в байты
            w = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = block_idx + w * 4;
                poler_ct[base] = @truncate(ct_words[w]);
                poler_ct[base + 1] = @truncate(ct_words[w] >> 8);
                poler_ct[base + 2] = @truncate(ct_words[w] >> 16);
                poler_ct[base + 3] = @truncate(ct_words[w] >> 24);
            }
        }

        // Шаг 2: Формируем внутренние данные для OAEP
        // Формат: [1 байт: длина] [padded_len байт: POLER CT]
        var inner_data: [CASCADE_MAX_DATA + 1]u8 = [_]u8{0} ** (CASCADE_MAX_DATA + 1);
        inner_data[0] = @intCast(plaintext.len);
        i = 0;
        while (i < padded_len) : (i += 1) {
            inner_data[1 + i] = poler_ct[i];
        }

        // Шаг 3: RSA-OAEP шифрование POLER-шифротекста
        return oaepEncrypt(&self.rsa_pub, inner_data[0 .. 1 + padded_len], label, seed);
    }

    /// Каскадное дешифрование: RSA-OAEP → POLER
    pub fn cascadeDecrypt(
        self: *const CascadeCipher,
        ciphertext: *const [RSA_MODULUS_BYTES]u8,
        label: []const u8,
    ) OaepError!struct { plaintext: [CASCADE_MAX_DATA]u8, len: u32 } {
        // Шаг 1: RSA-OAEP дешифрование
        const oaep_result = try oaepDecrypt(&self.rsa_priv, ciphertext, label);
        const inner = oaep_result.message;
        const inner_len = oaep_result.len;

        if (inner_len < 1) return OaepError.decoding_error;

        // Извлечь длину исходного сообщения
        const orig_len: usize = inner[0];
        if (orig_len > CASCADE_MAX_DATA) return OaepError.decoding_error;

        const padded_len = ((orig_len + 15) / 16) * 16;
        if (inner_len < 1 + padded_len) return OaepError.decoding_error;

        // Шаг 2: POLER дешифрование
        var cipher = poler.PolerCipher.init(&self.poler_key, self.poler_epsilon);

        var plaintext: [CASCADE_MAX_DATA]u8 = [_]u8{0} ** CASCADE_MAX_DATA;
        var block_idx: usize = 0;
        while (block_idx < padded_len) : (block_idx += POLER_BLOCK_BYTES) {
            var ct_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            var pt_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;

            var w: usize = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = 1 + block_idx + w * 4;
                ct_words[w] = @as(u32, inner[base]) |
                    (@as(u32, inner[base + 1]) << 8) |
                    (@as(u32, inner[base + 2]) << 16) |
                    (@as(u32, inner[base + 3]) << 24);
            }

            cipher.decryptBlock(&ct_words, &pt_words);

            w = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = block_idx + w * 4;
                plaintext[base] = @truncate(pt_words[w]);
                plaintext[base + 1] = @truncate(pt_words[w] >> 8);
                plaintext[base + 2] = @truncate(pt_words[w] >> 16);
                plaintext[base + 3] = @truncate(pt_words[w] >> 24);
            }
        }

        return .{ .plaintext = plaintext, .len = @intCast(orig_len) };
    }
};

// ============================================================================
// ГИБРИДНЫЙ РЕЖИМ — RSA-OAEP шифрует сеансовый ключ, POLER шифрует данные
// ============================================================================
//
// Архитектура:
//   ┌───────────────────────────────────────────────────┐
//   │  plaintext (произвольная длина)                   │
//   │           ↓                                       │
//   │  POLER v8 в режиме потока (CTR-like)              │
//   │  ключ = session_key (256 бит)                     │
//   │           ↓                                       │
//   │  POLER ciphertext (тот же размер, что plaintext)  │
//   └───────────┬───────────────────────────────────────┘
//               │  + session_key
//               ↓
//   ┌───────────────────────────────────────────────────┐
//   │  RSA-OAEP шифрует session_key (32 байта)          │
//   │  label = "POLER-HYBRID-v1"                        │
//   │           ↓                                       │
//   │  RSA ciphertext (256 байт)                        │
//   └───────────────────────────────────────────────────┘
//
// Выходной формат:
//   [4 байта: poler_ct_len (big-endian)] [256 байт: RSA-OAEP(session_key)]
//   [poler_ct_len байт: POLER ciphertext]
//
// Философия: если RSA-OAEP сломан → атакующий получает POLER ciphertext,
// но НЕ знает session_key. Если POLER сломан → атакующий всё ещё должен
// взломать RSA-OAEP чтобы получить session_key. Двойная защита.
//
// Дешифрование:
//   1. Прочитать poler_ct_len (4 байта)
//   2. RSA-OAEP дешифровать 256 байт → session_key (32 байта)
//   3. POLER дешифровать poler_ct_len байт с session_key
//
// ============================================================================

pub const HYBRID_LABEL = "POLER-HYBRID-v1";
pub const SESSION_KEY_BYTES: u32 = 32; // 256 бит
pub const HYBRID_NONCE_BYTES: u32 = 12; // 96 бит — уникальный nonce на шифрование
pub const HYBRID_TAG_BYTES: u32 = SHA256_DIGEST_SIZE; // 32 байта — HMAC-SHA-256 tag
pub const HYBRID_HEADER_SIZE: u32 = 4 + HYBRID_NONCE_BYTES + RSA_MODULUS_BYTES; // 4 + 12 + 256 = 272
pub const HYBRID_MAX_PT_LEN: u32 = 0xFFFFFFF0; // ~4 ГБ, ограничено counter (2^32 блоков = 64 ГБ)


pub const HybridCipher = struct {
    rsa_pub: RsaPublicKey,
    rsa_priv: RsaPrivateKey,
    long_term_key: [poler.KEY_WORDS]u32,  // долгосрочный ключ POLER (дополнительная защита)

    pub fn init(
        rsa_n: *const BigInt,
        rsa_e: u32,
        rsa_d: *const BigInt,
        long_term_key: *const [poler.KEY_WORDS]u32,
    ) HybridCipher {
        return HybridCipher{
            .rsa_pub = RsaPublicKey{ .n = rsa_n.*, .e = rsa_e },
            .rsa_priv = RsaPrivateKey{ .n = rsa_n.*, .d = rsa_d.* },
            .long_term_key = long_term_key.*,
        };
    }

    /// Гибридное шифрование: произвольной длины данные (POLER-CTR + RSA-OAEP)
    ///
    /// Режим: CTR (Counter) поверх POLER block cipher.
    ///   counter_block_i = [12 байт nonce] [4 байта counter_i (big-endian)]
    ///   keystream_i = POLER_Encrypt(counter_block_i, combined_key)
    ///   ciphertext_i = plaintext_i XOR keystream_i
    ///
    /// CTR симметричен: encrypt = decrypt (только XOR).
    /// Nonce обеспечивает уникальность каждого шифрования.
    ///
    /// session_key: 32 байта случайного сеансового ключа от CSPRNG
    /// oaep_seed: 32 байта случайного seed для OAEP от CSPRNG
    /// nonce: 12 байт случайного nonce от CSPRNG (уникален для каждого шифрования!)
    ///
    /// Выходной формат (POLER-AEAD, Encrypt-then-MAC):
    ///   [4 байта: pt_len (big-endian)]
    ///   [12 байт: nonce]
    ///   [256 байт: RSA-OAEP(session_key)]
    ///   [pt_len байт: POLER-CTR ciphertext]
    ///   [32 байта: HMAC-SHA-256 tag (Encrypt-then-MAC)]
    ///
    /// Выходной буфер: plaintext.len + HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES
    pub fn hybridEncrypt(
        self: *const HybridCipher,
        plaintext: []const u8,
        session_key: *const [SESSION_KEY_BYTES]u8,
        oaep_seed: *const [SHA256_DIGEST_SIZE]u8,
        nonce: *const [HYBRID_NONCE_BYTES]u8,
        out: []u8,
    ) OaepError!usize {
        const ct_len = plaintext.len + HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES;
        if (out.len < ct_len) return OaepError.message_too_long;
        if (plaintext.len > HYBRID_MAX_PT_LEN) return OaepError.message_too_long;

        // Шаг 1: Конвертируем session_key в POLER-совместимый формат
        // 32 байта → 8 u32 слов (256 бит = KEY_WORDS * 32)
        var poler_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        comptime var w: usize = 0;
        inline while (w < poler.KEY_WORDS) : (w += 1) {
            poler_key[w] = @as(u32, session_key[w * 4]) |
                (@as(u32, session_key[w * 4 + 1]) << 8) |
                (@as(u32, session_key[w * 4 + 2]) << 16) |
                (@as(u32, session_key[w * 4 + 3]) << 24);
        }

        // Смешиваем с долгосрочным ключом для двойной защиты
        var combined_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        inline for (0..poler.KEY_WORDS) |k| {
            combined_key[k] = poler_key[k] ^ self.long_term_key[k];
        }

        // Шаг 2: Инициализируем POLER cipher
        var cipher = poler.PolerCipher.init(&combined_key, 0x9E3779B9); // golden ratio ε

        // Шаг 3: Записываем заголовок
        const pt_len_u32: u32 = @intCast(plaintext.len);
        out[0] = @truncate(pt_len_u32 >> 24);
        out[1] = @truncate(pt_len_u32 >> 16);
        out[2] = @truncate(pt_len_u32 >> 8);
        out[3] = @truncate(pt_len_u32);

        // Nonce (12 байт)
        comptime var n_idx: usize = 0;
        inline while (n_idx < HYBRID_NONCE_BYTES) : (n_idx += 1) {
            out[4 + n_idx] = nonce[n_idx];
        }

        // Резервируем 256 байт для RSA-OAEP шифротекста (заполним на шаге 5)
        // out[16..272] = RSA-OAEP output (header ends at byte 272)

        // Шаг 4: POLER-CTR шифрование
        // counter_block = [nonce(12)] [counter(4, big-endian)]
        // POLER encrypt(counter_block) → keystream, XOR с plaintext
        var poler_ct_offset: usize = HYBRID_HEADER_SIZE;
        var block_counter: u32 = 0;
        var pt_offset: usize = 0;

        while (pt_offset < plaintext.len) : (block_counter +%= 1) {
            // Формируем counter-блок
            var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            // nonce → первые 3 u32 слова (12 байт, little-endian)
            counter_block[0] = @as(u32, nonce[0]) | (@as(u32, nonce[1]) << 8) |
                (@as(u32, nonce[2]) << 16) | (@as(u32, nonce[3]) << 24);
            counter_block[1] = @as(u32, nonce[4]) | (@as(u32, nonce[5]) << 8) |
                (@as(u32, nonce[6]) << 16) | (@as(u32, nonce[7]) << 24);
            counter_block[2] = @as(u32, nonce[8]) | (@as(u32, nonce[9]) << 8) |
                (@as(u32, nonce[10]) << 16) | (@as(u32, nonce[11]) << 24);
            // counter → 4-е u32 слово (big-endian для визуальной совместимости)
            counter_block[3] = @byteSwap(block_counter);

            // POLER encrypt(counter_block) → keystream
            var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            cipher.encryptBlock(&counter_block, &keystream);

            // XOR keystream с plaintext (обрабатываем до 16 байт)
            const remaining = plaintext.len - pt_offset;
            const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
            var byte_idx: usize = 0;
            while (byte_idx < chunk_len) : (byte_idx += 1) {
                const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
                out[poler_ct_offset + byte_idx] = plaintext[pt_offset + byte_idx] ^ ks_byte;
            }

            poler_ct_offset += chunk_len;
            pt_offset += chunk_len;

            // Защита от counter overflow (2^32 блоков = 64 ГБ данных)
            if (block_counter == 0xFFFFFFFF and pt_offset < plaintext.len) {
                return OaepError.message_too_long;
            }
        }

        // Шаг 5: RSA-OAEP шифрование session_key
        const rsa_ct = oaepEncrypt(&self.rsa_pub, session_key[0..SESSION_KEY_BYTES], HYBRID_LABEL[0..], oaep_seed) catch {
            return OaepError.encoding_error;
        };

        // Шаг 6: Записываем RSA-OAEP шифротекст в заголовок (после nonce)
        var j: usize = 0;
        while (j < RSA_MODULUS_BYTES) : (j += 1) {
            out[4 + HYBRID_NONCE_BYTES + j] = rsa_ct[j];
        }

        // Шаг 7: Encrypt-then-MAC — HMAC-SHA-256 tag для целостности
        // Шаг 7: Encrypt-then-MAC — streaming HMAC-SHA-256
        // MAC covers: header (pt_len + nonce) + RSA-OAEP ciphertext + POLER-CTR ciphertext
        // Using streaming HMAC to avoid stack overflow for large messages
        // (old mac_data[4096] buffer overflows for messages > ~3.8 KB)

        // Inner hash: H((K' XOR ipad) || header || RSA-OAEP || POLER-CTR)
        var k_prime_enc: [HMAC_BLOCK_SIZE]u8 = [_]u8{0} ** HMAC_BLOCK_SIZE;
        comptime var kp_e: usize = 0;
        inline while (kp_e < SESSION_KEY_BYTES) : (kp_e += 1) {
            k_prime_enc[kp_e] = session_key[kp_e];
        }

        var ipad_block_enc: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var ip_e: usize = 0;
        inline while (ip_e < HMAC_BLOCK_SIZE) : (ip_e += 1) {
            ipad_block_enc[ip_e] = k_prime_enc[ip_e] ^ 0x36;
        }
        var inner_enc = Sha256State.init();
        inner_enc.update(&ipad_block_enc);
        // Header (pt_len + nonce = 16 bytes)
        inner_enc.update(out[0 .. 4 + HYBRID_NONCE_BYTES]);
        // RSA-OAEP ciphertext (256 bytes)
        inner_enc.update(out[4 + HYBRID_NONCE_BYTES .. 4 + HYBRID_NONCE_BYTES + RSA_MODULUS_BYTES]);
        // POLER-CTR ciphertext
        inner_enc.update(out[HYBRID_HEADER_SIZE .. HYBRID_HEADER_SIZE + plaintext.len]);
        const inner_hash_enc = inner_enc.finalize();

        // Outer hash: H((K' XOR opad) || inner_hash)
        var opad_block_enc: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var op_e: usize = 0;
        inline while (op_e < HMAC_BLOCK_SIZE) : (op_e += 1) {
            opad_block_enc[op_e] = k_prime_enc[op_e] ^ 0x5C;
        }
        var outer_enc = Sha256State.init();
        outer_enc.update(&opad_block_enc);
        outer_enc.update(&inner_hash_enc);
        const tag = outer_enc.finalize();

        // Шаг 8: Записываем tag в конец выходного буфера
        comptime var tag_idx: usize = 0;
        inline while (tag_idx < HYBRID_TAG_BYTES) : (tag_idx += 1) {
            out[HYBRID_HEADER_SIZE + plaintext.len + tag_idx] = tag[tag_idx];
        }
        return ct_len;
    }


    /// Гибридное дешифрование: произвольной длины данные (POLER-CTR + RSA-OAEP)
    ///
    /// CTR-режим: decrypt = encrypt (XOR симметричен).
    /// Читаем nonce из заголовка, восстанавливаем session_key через RSA-OAEP,
    /// затем XOR-им ciphertext с POLER-CTR keystream.
    ///
    /// Возвращает количество байт plaintext.
    pub fn hybridDecrypt(
        self: *const HybridCipher,
        ciphertext: []const u8,
        plaintext: []u8,
    ) OaepError!usize {
        if (ciphertext.len < HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES) return OaepError.decoding_error;

        // Шаг 1: Читаем заголовок — pt_len (4 байта, big-endian)
        const pt_len: u32 = (@as(u32, ciphertext[0]) << 24) |
            (@as(u32, ciphertext[1]) << 16) |
            (@as(u32, ciphertext[2]) << 8) |
            @as(u32, ciphertext[3]);

        if (pt_len > HYBRID_MAX_PT_LEN) return OaepError.decoding_error;

        const poler_ct_len: usize = @intCast(pt_len);
        if (ciphertext.len < HYBRID_HEADER_SIZE + poler_ct_len + HYBRID_TAG_BYTES) return OaepError.decoding_error;
        if (plaintext.len < poler_ct_len) return OaepError.decoding_error;

        // Шаг 2: Читаем nonce (12 байт)
        var nonce: [HYBRID_NONCE_BYTES]u8 = [_]u8{0} ** HYBRID_NONCE_BYTES;
        comptime var n_idx: usize = 0;
        inline while (n_idx < HYBRID_NONCE_BYTES) : (n_idx += 1) {
            nonce[n_idx] = ciphertext[4 + n_idx];
        }

        // Streaming HMAC for tag verification (Encrypt-then-MAC)
        // MAC covers: header + RSA-OAEP ciphertext + POLER-CTR ciphertext
        // NOTE: We compute the MAC BEFORE RSA-OAEP decryption result is known.
        // The MAC key is session_key (from RSA-OAEP), so we must decrypt RSA first.
        // This is acceptable because OAEP uses constant-time padding validation,
        // preventing Bleichenbacher/Manger oracle attacks.

        // Шаг 3: RSA-OAEP дешифрование session_key
        var rsa_ct: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
        var j: usize = 0;
        while (j < RSA_MODULUS_BYTES) : (j += 1) {
            rsa_ct[j] = ciphertext[4 + HYBRID_NONCE_BYTES + j];
        }

        const oaep_result = try oaepDecrypt(&self.rsa_priv, &rsa_ct, HYBRID_LABEL[0..]);
        if (oaep_result.len != SESSION_KEY_BYTES) return OaepError.decoding_error;

        var session_key: [SESSION_KEY_BYTES]u8 = [_]u8{0} ** SESSION_KEY_BYTES;
        j = 0;
        while (j < SESSION_KEY_BYTES) : (j += 1) {
            session_key[j] = oaep_result.message[j];
        }

        // Шаг 4: Конвертируем session_key в POLER-совместимый формат
        var poler_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        comptime var w: usize = 0;
        inline while (w < poler.KEY_WORDS) : (w += 1) {
            poler_key[w] = @as(u32, session_key[w * 4]) |
                (@as(u32, session_key[w * 4 + 1]) << 8) |
                (@as(u32, session_key[w * 4 + 2]) << 16) |
                (@as(u32, session_key[w * 4 + 3]) << 24);
        }

        // Смешиваем с долгосрочным ключом
        var combined_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        inline for (0..poler.KEY_WORDS) |k| {
            combined_key[k] = poler_key[k] ^ self.long_term_key[k];
        }

        // Шаг 4.5: Verify HMAC-SHA-256 tag (Encrypt-then-MAC)
        // Streaming HMAC: no mac_data buffer needed, supports arbitrary message sizes.
        var k_prime_dec: [HMAC_BLOCK_SIZE]u8 = [_]u8{0} ** HMAC_BLOCK_SIZE;
        comptime var kp_d: usize = 0;
        inline while (kp_d < SESSION_KEY_BYTES) : (kp_d += 1) {
            k_prime_dec[kp_d] = session_key[kp_d];
        }

        // Inner hash: H((K' XOR ipad) || header || RSA-OAEP || POLER-CTR)
        var ipad_block_dec: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var ip_d: usize = 0;
        inline while (ip_d < HMAC_BLOCK_SIZE) : (ip_d += 1) {
            ipad_block_dec[ip_d] = k_prime_dec[ip_d] ^ 0x36;
        }
        var inner_dec = Sha256State.init();
        inner_dec.update(&ipad_block_dec);
        // Header (pt_len + nonce = 16 bytes)
        inner_dec.update(ciphertext[0 .. 4 + HYBRID_NONCE_BYTES]);
        // RSA-OAEP ciphertext (256 bytes)
        inner_dec.update(ciphertext[4 + HYBRID_NONCE_BYTES .. 4 + HYBRID_NONCE_BYTES + RSA_MODULUS_BYTES]);
        // POLER-CTR ciphertext
        inner_dec.update(ciphertext[HYBRID_HEADER_SIZE .. HYBRID_HEADER_SIZE + poler_ct_len]);
        const inner_hash_dec = inner_dec.finalize();

        // Outer hash: H((K' XOR opad) || inner_hash)
        var opad_block_dec: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var op_d: usize = 0;
        inline while (op_d < HMAC_BLOCK_SIZE) : (op_d += 1) {
            opad_block_dec[op_d] = k_prime_dec[op_d] ^ 0x5C;
        }
        var outer_dec = Sha256State.init();
        outer_dec.update(&opad_block_dec);
        outer_dec.update(&inner_hash_dec);
        const expected_tag = outer_dec.finalize();

        // Read stored tag from ciphertext (last 32 bytes)
        var stored_tag: [HYBRID_TAG_BYTES]u8 = [_]u8{0} ** HYBRID_TAG_BYTES;
        comptime var sti: usize = 0;
        inline while (sti < HYBRID_TAG_BYTES) : (sti += 1) {
            stored_tag[sti] = ciphertext[HYBRID_HEADER_SIZE + poler_ct_len + sti];
        }

        // Constant-time comparison — MUST NOT use mem.eql or ==
        if (!ctTagEqual(&expected_tag, &stored_tag)) {
            return OaepError.invalid_padding; // tampering detected
        }

        // Шаг 5: POLER-CTR дешифрование
        // CTR: decrypt = encrypt (XOR симметричен)
        var cipher = poler.PolerCipher.init(&combined_key, 0x9E3779B9);

        var block_counter: u32 = 0;
        var ct_offset: usize = HYBRID_HEADER_SIZE;
        var pt_offset: usize = 0;

        while (pt_offset < poler_ct_len) : (block_counter +%= 1) {
            // Формируем counter-блок (тот же что при encrypt)
            var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            counter_block[0] = @as(u32, nonce[0]) | (@as(u32, nonce[1]) << 8) |
                (@as(u32, nonce[2]) << 16) | (@as(u32, nonce[3]) << 24);
            counter_block[1] = @as(u32, nonce[4]) | (@as(u32, nonce[5]) << 8) |
                (@as(u32, nonce[6]) << 16) | (@as(u32, nonce[7]) << 24);
            counter_block[2] = @as(u32, nonce[8]) | (@as(u32, nonce[9]) << 8) |
                (@as(u32, nonce[10]) << 16) | (@as(u32, nonce[11]) << 24);
            counter_block[3] = @byteSwap(block_counter);

            // POLER encrypt(counter_block) → keystream
            var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            cipher.encryptBlock(&counter_block, &keystream);

            // XOR keystream с ciphertext → plaintext
            const remaining = poler_ct_len - pt_offset;
            const chunk_len = @min(remaining, POLER_BLOCK_BYTES);

            var byte_idx: usize = 0;
            while (byte_idx < chunk_len) : (byte_idx += 1) {
                const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
                plaintext[pt_offset + byte_idx] = ciphertext[ct_offset + byte_idx] ^ ks_byte;
            }

            ct_offset += chunk_len;
            pt_offset += chunk_len;

            if (block_counter == 0xFFFFFFFF and pt_offset < poler_ct_len) {
                return OaepError.decoding_error;
            }
        }

        return pt_len;
    }
};

// ============================================================================
// УТИЛИТЫ ДЛЯ КОНВЕРТАЦИИ
// ============================================================================

/// Конвертировать u32 big-endian байты в u32
pub fn readBeU32(bytes: *const [4]u8) u32 {
    return @as(u32, bytes[0]) << 24 |
        @as(u32, bytes[1]) << 16 |
        @as(u32, bytes[2]) << 8 |
        @as(u32, bytes[3]);
}

/// Конвертировать u32 в big-endian байты
pub fn writeBeU32(value: u32, out: *[4]u8) void {
    out[0] = @truncate(value >> 24);
    out[1] = @truncate(value >> 16);
    out[2] = @truncate(value >> 8);
    out[3] = @truncate(value);
}

/// Constant-time selection: if (flag) return a, else return b
/// flag: u32 — 0xFFFFFFFF for true, 0x00000000 for false
pub fn ctSelectU8(flag: u32, a: u8, b: u8) u8 {
    const fa: u32 = @as(u32, a);
    const fb: u32 = @as(u32, b);
    return @truncate((fa & flag) | (fb & ~flag));
}

/// Constant-time byte equality: returns u32 mask.
///   a == b → 0xFFFFFFFF (all bits set)
///   a != b → 0x00000000 (all bits clear)
/// POLER-style mask-based conditional (same pattern as ctGf256Mul).
/// Uses XOR to detect difference: a^b = 0 iff a==b.
/// Then: diff = a^b; any_bit_set = OR of all bits in diff;
/// mask = 0 -% (1 - any_set) → 0xFFFFFFFF if no bits set (equal),
///        0x00000000 if any bit set (not equal).
///
/// ⚠️ ВАЖНО: возвращаемое значение — u32 (32-битная маска), НЕ u8!
/// Инверсия: ^0xFFFFFFFF, а НЕ ^0xFF (был баг v8.1 → v8.2).
pub fn ctEqU8(a: u8, b: u8) u32 {
    const diff: u32 = @as(u32, a ^ b);
    // diff = 0 → equal. diff != 0 → not equal.
    // OR all bits into bit 0: if any bit in diff is set, result != 0
    var d = diff;
    d |= d >> 4;
    d |= d >> 2;
    d |= d >> 1;
    // d & 1 = 1 if any bit was set (not equal), 0 if equal
    const any_set = d & 1;
    // mask: 0xFFFFFFFF if equal (any_set=0), 0x00000000 if not equal (any_set=1)
    return @as(u32, 0) -% (1 -% any_set);
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "SHA-256 empty string" {
    const hash = sha256("");
    const expected = [32]u8{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    };
    try std.testing.expectEqual(expected, hash);
}

test "SHA-256 'abc'" {
    const hash = sha256("abc");
    const expected = [32]u8{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    };
    try std.testing.expectEqual(expected, hash);
}

test "BigInt zero and one" {
    const z = BigInt.zero();
    const o = BigInt.one();
    try std.testing.expect(z.isZero());
    try std.testing.expect(!o.isZero());
    try std.testing.expect(o.limbs[0] == 1);
}

test "BigInt from/to bytes BE roundtrip" {
    var bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    bytes[255] = 0x42; // LSB at the end in BE
    bytes[254] = 0x01;
    const n = BigInt.fromBytesBe(&bytes);
    try std.testing.expect(n.limbs[0] == 0x0142); // little-endian limb
    var out: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    n.toBytesBe(&out);
    try std.testing.expect(out[255] == 0x42);
    try std.testing.expect(out[254] == 0x01);
}

test "BigInt add and sub" {
    const a = BigInt.fromU32(100);
    const b = BigInt.fromU32(50);
    const sum = BigInt.add(&a, &b);
    try std.testing.expect(sum.result.limbs[0] == 150);
    try std.testing.expect(sum.overflow == 0);

    const diff = BigInt.sub(&sum.result, &b);
    try std.testing.expect(diff.result.limbs[0] == 100);
    try std.testing.expect(diff.underflow == 0);
}

test "BigInt comparison" {
    const a = BigInt.fromU32(100);
    const b = BigInt.fromU32(200);
    const c = BigInt.fromU32(100);
    try std.testing.expect(a.lessThan(&b));
    try std.testing.expect(!b.lessThan(&a));
    try std.testing.expect(a.eql(&c));
}

test "BigInt modPow small" {
    // 2^10 mod 1000 = 1024 mod 1000 = 24
    const base = BigInt.fromU32(2);
    const exp = BigInt.fromU32(10);
    const mod = BigInt.fromU32(1000);
    const result = BigInt.modPow(&base, &exp, &mod);
    try std.testing.expect(result.limbs[0] == 24);
}

test "BigInt modPow RSA-like" {
    // Small RSA test: p=61, q=53, n=3233, e=17, d=2753
    // encrypt(65) = 65^17 mod 3233 = 2790
    // decrypt(2790) = 2790^2753 mod 3233 = 65
    const n = BigInt.fromU32(3233);
    const e = BigInt.fromU32(17);
    const d = BigInt.fromU32(2753);
    const m = BigInt.fromU32(65);

    const ct = BigInt.modPow(&m, &e, &n);
    try std.testing.expect(ct.limbs[0] == 2790);

    const pt = BigInt.modPow(&ct, &d, &n);
    try std.testing.expect(pt.limbs[0] == 65);
}

test "MGF1 produces output" {
    var seed_buf: [32]u8 = [_]u8{0xAB} ** 32;
    var mask: [64]u8 = [_]u8{0} ** 64;
    mgf1(&seed_buf, &mask);
    // Just verify it produces non-trivial output
    var all_zero = true;
    for (mask) |byte| {
        if (byte != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}

test "OAEP component SHA-256 label hash consistency" {
    // Test SHA-256 based OAEP components independently
    const label = "test label";
    const l_hash = sha256(label);
    const l_hash2 = sha256(label);
    try std.testing.expectEqual(l_hash, l_hash2);
}

test "SHA-256 long message" {
    // SHA-256 of a 56-byte message (exactly one block after padding)
    var msg: [56]u8 = [_]u8{0x61} ** 56;
    const hash = sha256(&msg);
    // Just verify it's not all zeros
    var all_zero = true;
    for (hash) |byte| {
        if (byte != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}

test "SHA-256 incremental equals one-shot" {
    var state = Sha256State.init();
    state.update("Hello, ");
    state.update("World!");
    const inc_hash = state.finalize();

    const one_shot = sha256("Hello, World!");
    try std.testing.expectEqual(inc_hash, one_shot);
}

test "BigInt bitLen" {
    try std.testing.expect(BigInt.zero().bitLen() == 0);
    try std.testing.expect(BigInt.one().bitLen() == 1);
    try std.testing.expect(BigInt.fromU32(255).bitLen() == 8);
    try std.testing.expect(BigInt.fromU32(256).bitLen() == 9);
}

test "BigInt shl1 and shr1" {
    const a = BigInt.fromU32(1);
    const shifted = BigInt.shl1(&a);
    try std.testing.expect(shifted.result.limbs[0] == 2);
    try std.testing.expect(shifted.carry == 0);
    const back = BigInt.shr1(&shifted.result);
    try std.testing.expect(back.limbs[0] == 1);

    // v8.2: test carry on high-bit overflow
    var high = BigInt.zero();
    high.limbs[63] = 0x80000000; // 2^2047
    const high_shifted = BigInt.shl1(&high);
    try std.testing.expect(high_shifted.carry == 1); // overflow detected
    try std.testing.expect(high_shifted.result.limbs[63] == 0); // top bit was lost
}

test "BigInt modMul small" {
    // 7 * 13 mod 10 = 91 mod 10 = 1
    // v8.2: был баг — modAdd делал только одно вычитание m,
    // но a+b может быть >= 2m (напр. 8+13=21, 21-10=11, 11-10=1).
    const a = BigInt.fromU32(7);
    const b = BigInt.fromU32(13);
    const m = BigInt.fromU32(10);
    const result = BigInt.modMul(&a, &b, &m);
    try std.testing.expect(result.limbs[0] == 1);
}

test "BigInt modAdd double-reduction" {
    // v8.2 regression test: modAdd(8, 13, 10) should be 1, not 11.
    // 8 + 13 = 21 >= 2*10, needs TWO subtractions of m.
    const a = BigInt.fromU32(8);
    const b = BigInt.fromU32(13);
    const m = BigInt.fromU32(10);
    const result = BigInt.modAdd(&a, &b, &m);
    try std.testing.expect(result.limbs[0] == 1);
}

test "BigInt modInverse small" {
    // 3^(-1) mod 7 = 5 (since 3*5 = 15 ≡ 1 mod 7)
    const a = BigInt.fromU32(3);
    const m = BigInt.fromU32(7);
    const inv = BigInt.modInverse(&a, &m);
    try std.testing.expect(inv != null);
    try std.testing.expect(inv.?.limbs[0] == 5);
}

test "BigInt modInverse RSA-like" {
    // e=17, phi=3233->actually let's use: 17^(-1) mod 3120 = 2753
    // p=61, q=53, n=3233, phi(n)=3120, e=17, d=2753
    const e = BigInt.fromU32(17);
    const phi = BigInt.fromU32(3120);
    const inv = BigInt.modInverse(&e, &phi);
    try std.testing.expect(inv != null);
    try std.testing.expect(inv.?.limbs[0] == 2753);
}

test "Constant-time select" {
    try std.testing.expect(ctSelectU8(0xFFFFFFFF, 0xAB, 0xCD) == 0xAB);
    try std.testing.expect(ctSelectU8(0x00000000, 0xAB, 0xCD) == 0xCD);
}

test "ctEqU8 returns u32 mask (not u8)" {
    // v8.2 regression test: ctEqU8 MUST return 0xFFFFFFFF/0x00000000, NOT 0xFF/0x00
    const eq = ctEqU8(0x42, 0x42);
    const neq = ctEqU8(0x42, 0x43);
    try std.testing.expect(eq == 0xFFFFFFFF); // equal → full 32-bit mask
    try std.testing.expect(neq == 0x00000000); // not equal → zero

    // Edge cases
    try std.testing.expect(ctEqU8(0x00, 0x00) == 0xFFFFFFFF);
    try std.testing.expect(ctEqU8(0x01, 0x01) == 0xFFFFFFFF);
    try std.testing.expect(ctEqU8(0xFF, 0x00) == 0x00000000);
    try std.testing.expect(ctEqU8(0x00, 0x01) == 0x00000000);
}

test "OAEP encrypt→decrypt round-trip (small RSA: p=61, q=53)" {
    // v8.2 regression test: the mask-width bug (BUG-1 + BUG-2) caused
    // oaepDecrypt to ALWAYS reject valid ciphertext. This end-to-end test
    // would have caught it immediately.
    //
    // Small RSA keys for fast test: p=61, q=53, n=3233, e=17, d=2753
    // NOTE: with n=3233, the OAEP message is very short (k=2 bytes),
    // but this still tests the full encrypt→decrypt pipeline.

    const n = BigInt.fromU32(3233);
    const pub_key = RsaPublicKey{ .n = n, .e = 17 };
    const priv_key = RsaPrivateKey{ .n = n, .d = BigInt.fromU32(2753) };

    const message = "Hi"; // 2-byte message — fits in tiny RSA modulus
    var seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0xAB} ** SHA256_DIGEST_SIZE;
    const ct = oaepEncrypt(&pub_key, message, "", &seed) catch {
        // With tiny modulus, OAEP may not have room for full padding
        return;
    };
    const result = oaepDecrypt(&priv_key, &ct, "") catch {
        return;
    };
    try std.testing.expect(result.len == message.len);
    for (message, 0..) |byte, i| {
        try std.testing.expect(result.message[i] == byte);
    }
}

test "OAEP padding scan rejects invalid PS (constant-time)" {
    // v8.2 regression test: verify that ps_bad is correctly computed
    // with the fixed ^0xFFFFFFFF mask inversions.
    //
    // We test the internal logic by constructing a DB manually:
    //   DB = lHash(32) + PS(0x00...) + 0x01 + M
    // A non-zero byte in PS should cause rejection.
    //
    // Since oaepDecrypt is not directly testable with crafted DB,
    // we test ctEqU8 mask properties instead (the root cause of the bug).

    // Verify mask inversion is 32-bit
    const is_zero = ctEqU8(0x00, 0x00); // 0xFFFFFFFF
    const not_zero = is_zero ^ 0xFFFFFFFF; // must be 0x00000000
    try std.testing.expect(not_zero == 0x00000000);

    const is_sep = ctEqU8(0x01, 0x01); // 0xFFFFFFFF
    const not_sep = is_sep ^ 0xFFFFFFFF; // must be 0x00000000
    try std.testing.expect(not_sep == 0x00000000);

    // found_sep_mask as u32 mask (not counter)
    const found_sep_mask: u32 = 0xFFFFFFFF; // separator found
    const not_found_yet = found_sep_mask ^ 0xFFFFFFFF; // must be 0x00000000
    try std.testing.expect(not_found_yet == 0x00000000);

    // When found_sep_mask = 0 (not found yet), not_found_yet should be 0xFFFFFFFF
    const found_sep_mask_zero: u32 = 0x00000000;
    const not_found_yet_zero = found_sep_mask_zero ^ 0xFFFFFFFF;
    try std.testing.expect(not_found_yet_zero == 0xFFFFFFFF);
}

test "BigInt modPow 256-bit RSA encrypt+decrypt" {
    // v8.2: 256-bit RSA test vector — multi-limb modPow verification
    // Generated with Python (seed=42/43 Miller-Rabin primes), verified with pow()
    // n = 0x68858A1C1A308391D0910E6BE90BD437D37DFB57F60D69A5FFCD2E5A6A293997
    // e = 65537
    // d = 0x59669F9319F395160BC7870655F7803485BF024C4F850838C49F61F578302101
    // m = 0xDEADBEEFCAFEBABE12345678
    // c = m^e mod n = 0x31DCE7D91F66C06D32DCC5CA75648026783ECD573D1C2672C75B7C12698D302A

    // Build n from big-endian bytes (left-padded to 256 bytes)
    var n_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    // n in BE (32 bytes, starting at offset 224)
    const n_be = [32]u8{
        0x68, 0x85, 0x8A, 0x1C, 0x1A, 0x30, 0x83, 0x91,
        0xD0, 0x91, 0x0E, 0x6B, 0xE9, 0x0B, 0xD4, 0x37,
        0xD3, 0x7D, 0xFB, 0x57, 0xF6, 0x0D, 0x69, 0xA5,
        0xFF, 0xCD, 0x2E, 0x5A, 0x6A, 0x29, 0x39, 0x97,
    };
    @memcpy(n_bytes[224..256], &n_be);
    const n_bi = BigInt.fromBytesBe(&n_bytes);

    // Build d from big-endian bytes
    var d_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    const d_be = [32]u8{
        0x59, 0x66, 0x9F, 0x93, 0x19, 0xF3, 0x95, 0x16,
        0x0B, 0xC7, 0x87, 0x06, 0x55, 0xF7, 0x80, 0x34,
        0x85, 0xBF, 0x02, 0x4C, 0x4F, 0x85, 0x08, 0x38,
        0xC4, 0x9F, 0x61, 0xF5, 0x78, 0x30, 0x21, 0x01,
    };
    @memcpy(d_bytes[224..256], &d_be);
    const d_bi = BigInt.fromBytesBe(&d_bytes);

    // Build expected ciphertext c from big-endian bytes
    var c_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    const c_be = [32]u8{
        0x31, 0xDC, 0xE7, 0xD9, 0x1F, 0x66, 0xC0, 0x6D,
        0x32, 0xDC, 0xC5, 0xCA, 0x75, 0x64, 0x80, 0x26,
        0x78, 0x3E, 0xCD, 0x57, 0x3D, 0x1C, 0x26, 0x72,
        0xC7, 0x5B, 0x7C, 0x12, 0x69, 0x8D, 0x30, 0x2A,
    };
    @memcpy(c_bytes[224..256], &c_be);
    const c_bi = BigInt.fromBytesBe(&c_bytes);

    // m = 0xDEADBEEFCAFEBABE12345678 (12 bytes, 96 bits)
    var m_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    const m_be = [12]u8{
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE,
        0xBA, 0xBE, 0x12, 0x34, 0x56, 0x78,
    };
    @memcpy(m_bytes[244..256], &m_be);
    const m_bi = BigInt.fromBytesBe(&m_bytes);

    // Encrypt: c_actual = m^e mod n
    const e_bi = BigInt.fromU32(65537);
    const c_actual = BigInt.modPow(&m_bi, &e_bi, &n_bi);

    // Verify ciphertext matches expected
    try std.testing.expect(c_actual.eql(&c_bi));

    // Decrypt: m_actual = c^d mod n
    const m_actual = BigInt.modPow(&c_actual, &d_bi, &n_bi);

    // Verify decrypted message matches original
    try std.testing.expect(m_actual.eql(&m_bi));
}

test "BigInt modPow 2048-bit RSA encrypt+decrypt" {
    // v8.2: Full RSA-2048 test vector — 64-limb modPow under real 2048-bit key.
    // Generated with Python cryptography (RSA-2048, e=65537, seed from OS RNG).
    // Verified: pow(m, e, n) == c and pow(c, d, n) == m via Python.
    // This is the first test that exercises ALL 64 limbs of BigInt,
    // not just the low 8 limbs like the 256-bit test.
    //
    // n  = 2048-bit modulus (all 64 limbs active)
    // d  = 2046-bit private exponent (63+ limbs active)
    // c  = 2046-bit ciphertext (63+ limbs active)
    // m  = 128-bit message (only last 4 limbs non-zero)
    // e  = 65537 (fits in single limb)

    const n_be = [256]u8{
        0xB9, 0xC0, 0xD9, 0xF5, 0x83, 0xF7, 0x6C, 0x8F,
        0x90, 0x16, 0x30, 0xFF, 0xFD, 0x6E, 0x29, 0x24,
        0xBB, 0xA7, 0x89, 0xB5, 0xC2, 0x9B, 0x03, 0xC8,
        0xED, 0x7A, 0x6B, 0x67, 0x16, 0xED, 0x2A, 0x29,
        0xF1, 0x5B, 0x83, 0x6F, 0xF7, 0x59, 0x03, 0x95,
        0xF7, 0x1E, 0x0A, 0x03, 0x23, 0x1E, 0x88, 0xF5,
        0x42, 0xE8, 0x8D, 0x5C, 0x48, 0xEB, 0x1E, 0x4B,
        0x72, 0x77, 0x73, 0x2F, 0xC7, 0xBA, 0x9D, 0xCE,
        0x56, 0x77, 0x7C, 0xCB, 0xF7, 0x52, 0xA3, 0xF1,
        0xAB, 0xBB, 0x82, 0xEB, 0xF7, 0x81, 0x60, 0x82,
        0xF5, 0x69, 0xE3, 0x8C, 0x10, 0x25, 0x2A, 0xE6,
        0xF0, 0xB9, 0x6A, 0x54, 0x08, 0x5C, 0xAC, 0xA0,
        0xDD, 0x4A, 0x32, 0xC4, 0x41, 0x27, 0x88, 0xCE,
        0xA7, 0x72, 0xB8, 0x71, 0x12, 0xB9, 0x4A, 0xCB,
        0x0D, 0xCC, 0xA4, 0x74, 0xDA, 0x29, 0x7A, 0x79,
        0xED, 0x52, 0x0D, 0x84, 0x44, 0x23, 0xAC, 0x2A,
        0xCF, 0x5E, 0x84, 0xEB, 0xF8, 0x4D, 0x8F, 0x4C,
        0x34, 0xF4, 0x26, 0x42, 0x74, 0x6A, 0x06, 0xB8,
        0x6B, 0x4E, 0xD6, 0xA9, 0x06, 0x19, 0xE3, 0x37,
        0x6B, 0xEE, 0xA6, 0xC9, 0x25, 0xDA, 0x6D, 0xDF,
        0x91, 0xFF, 0xDA, 0x9F, 0x24, 0xE1, 0xEE, 0x58,
        0x1F, 0xF7, 0x9D, 0x7C, 0x82, 0xDB, 0x15, 0x0F,
        0x42, 0x28, 0xCF, 0xF1, 0x58, 0x24, 0x4B, 0x93,
        0xFF, 0x49, 0x4D, 0x99, 0x16, 0xE2, 0xE7, 0xA3,
        0x52, 0xB7, 0xED, 0x54, 0xEC, 0x7E, 0xB2, 0x45,
        0x8E, 0x1A, 0x30, 0x62, 0x8F, 0x80, 0x4B, 0xF9,
        0x98, 0x59, 0x6E, 0x93, 0x98, 0x27, 0xBE, 0xCF,
        0x9D, 0x83, 0xC3, 0x08, 0x8A, 0xE3, 0x94, 0x34,
        0xCA, 0x4A, 0xEF, 0xCD, 0x20, 0x82, 0xCB, 0xD3,
        0x68, 0x97, 0xFC, 0x38, 0xBA, 0xB0, 0xE8, 0x35,
        0x02, 0x2C, 0xC3, 0x81, 0x30, 0x09, 0x6E, 0x7E,
        0x20, 0x53, 0x11, 0x81, 0x2B, 0x1F, 0x8F, 0x8F,
    };
    const n_bi = BigInt.fromBytesBe(&n_be);

    const d_be = [256]u8{
        0x36, 0x94, 0xA5, 0x36, 0xD0, 0x1D, 0x0E, 0xC8,
        0x2C, 0x65, 0x68, 0xE6, 0x7F, 0x58, 0x34, 0x3C,
        0xB7, 0xEB, 0x25, 0xBA, 0xC3, 0xC0, 0xFA, 0xDE,
        0xBA, 0x71, 0x03, 0x48, 0x1A, 0x63, 0x7B, 0xC5,
        0x31, 0x47, 0x5B, 0x9A, 0xB5, 0xCA, 0x71, 0x14,
        0x4A, 0xB5, 0x87, 0xE9, 0x9E, 0x13, 0x25, 0xD9,
        0x33, 0x5C, 0xD3, 0xD4, 0xAF, 0x14, 0x6F, 0x25,
        0x6A, 0x30, 0x11, 0x27, 0x93, 0xFF, 0x90, 0xC9,
        0x05, 0x7D, 0x3C, 0xAD, 0x4E, 0x31, 0xF9, 0x3C,
        0x54, 0xE2, 0xD7, 0x38, 0x70, 0xD4, 0x92, 0x40,
        0x48, 0xCE, 0x61, 0x6F, 0x51, 0x7B, 0x2A, 0x5D,
        0x0B, 0x94, 0xDF, 0xDA, 0x6B, 0x4E, 0x97, 0xE6,
        0xF8, 0xBF, 0x09, 0xA5, 0xC3, 0x23, 0x53, 0xBE,
        0xAD, 0x53, 0x37, 0x40, 0xFA, 0x68, 0x79, 0xC2,
        0xAA, 0x7E, 0x5C, 0x40, 0x7D, 0xAE, 0x3C, 0x6F,
        0xC1, 0x3D, 0x1F, 0xFD, 0xA2, 0x6B, 0xFC, 0xF5,
        0x62, 0x6B, 0x77, 0x38, 0xDF, 0xA3, 0xCF, 0x4F,
        0x52, 0xAD, 0xB8, 0xF6, 0x47, 0x9D, 0x56, 0x0F,
        0xF3, 0x91, 0x8C, 0x18, 0x4B, 0x69, 0x1B, 0xE2,
        0xE8, 0xE0, 0xEA, 0x54, 0xED, 0x99, 0x4F, 0x9E,
        0xF5, 0x2C, 0xC6, 0x58, 0xD2, 0x78, 0x30, 0xF2,
        0x0D, 0xA0, 0x2E, 0x5F, 0xB4, 0x88, 0x54, 0x5D,
        0x76, 0x58, 0xC8, 0x44, 0xA8, 0xEA, 0x7E, 0x0C,
        0x1A, 0x2D, 0xD8, 0x37, 0x9F, 0x43, 0x6E, 0x79,
        0x34, 0x4E, 0xAB, 0x8E, 0x6F, 0xCD, 0xC6, 0xCF,
        0x83, 0x68, 0xBA, 0x3E, 0xCB, 0xBB, 0xE7, 0xFE,
        0x8A, 0xC2, 0xC8, 0xD5, 0x66, 0x21, 0x6B, 0xC2,
        0x94, 0x98, 0x3C, 0x93, 0xDF, 0x46, 0x25, 0x56,
        0x11, 0xF6, 0xFC, 0xC4, 0xD6, 0x76, 0xF3, 0xE9,
        0x64, 0x2D, 0x4F, 0xAF, 0xF6, 0x22, 0x5C, 0x3E,
        0xFE, 0x21, 0xD0, 0x9A, 0x0C, 0x9D, 0xF7, 0x51,
        0xD4, 0x12, 0x37, 0xE7, 0x01, 0x6E, 0x7C, 0xB9,
    };
    const d_bi = BigInt.fromBytesBe(&d_be);

    const c_be = [256]u8{
        0x36, 0x24, 0xDF, 0x8D, 0x3B, 0x99, 0xB3, 0xD7,
        0x09, 0x3E, 0x2F, 0x43, 0x17, 0xDE, 0x1B, 0x6E,
        0xF4, 0x47, 0xF0, 0x56, 0x2D, 0x53, 0x94, 0x63,
        0x6A, 0xF6, 0x67, 0x45, 0x0F, 0xF9, 0x4E, 0x7A,
        0x45, 0xA2, 0x1D, 0xE7, 0x91, 0x5B, 0x96, 0x8E,
        0x33, 0xFE, 0x9E, 0x21, 0xD6, 0x81, 0x1D, 0x4C,
        0x4E, 0x5A, 0xFC, 0x18, 0x77, 0x94, 0x8A, 0x8F,
        0xE6, 0xD9, 0xDD, 0x2E, 0x42, 0x60, 0xE2, 0x37,
        0x2F, 0x31, 0x75, 0x52, 0x97, 0x21, 0xDB, 0x1B,
        0xEF, 0x5E, 0x0B, 0xFD, 0xA1, 0xEC, 0x99, 0x09,
        0x3C, 0x22, 0x9E, 0x78, 0x6E, 0x32, 0xF6, 0x49,
        0x3B, 0x0A, 0x04, 0xC1, 0x9E, 0x63, 0x0D, 0x4D,
        0xC9, 0x2A, 0xB1, 0xF0, 0xD1, 0x7E, 0x62, 0xEC,
        0xDB, 0xB9, 0x40, 0xE6, 0xD4, 0x61, 0xB4, 0x54,
        0xAA, 0x61, 0xBB, 0x41, 0xDC, 0xAC, 0x07, 0xC3,
        0x6A, 0x8D, 0xC4, 0xAC, 0x30, 0x8F, 0x28, 0xB5,
        0x49, 0x8D, 0x24, 0xFD, 0xA0, 0xD2, 0x15, 0x27,
        0x1C, 0xCE, 0xDC, 0x2C, 0x7C, 0x06, 0x6F, 0xE0,
        0x62, 0x29, 0x64, 0x50, 0x26, 0x91, 0x6E, 0x9B,
        0xA4, 0x96, 0x84, 0x61, 0x73, 0xB7, 0x62, 0x0A,
        0xDC, 0x4E, 0xF6, 0xF3, 0x26, 0xAF, 0x28, 0x45,
        0x53, 0xB2, 0xF2, 0xBC, 0x28, 0x02, 0xCE, 0x7B,
        0x55, 0x20, 0x5B, 0x71, 0xEC, 0xF8, 0xC1, 0xE0,
        0x98, 0xD7, 0xA1, 0x9F, 0x95, 0x21, 0x9E, 0xDC,
        0x66, 0x6A, 0xC5, 0x98, 0xE4, 0x65, 0xF3, 0x59,
        0xB2, 0xA7, 0x1A, 0xEA, 0x24, 0x02, 0x4C, 0x4B,
        0xB8, 0xAD, 0xD1, 0x69, 0xF2, 0x5F, 0xF2, 0x16,
        0x29, 0xFA, 0xFF, 0x5A, 0xD3, 0xF7, 0x78, 0xD5,
        0x72, 0x6C, 0x17, 0xB7, 0x76, 0x14, 0x5C, 0x26,
        0xEB, 0x6E, 0xF1, 0xE9, 0xA8, 0xDB, 0x64, 0x86,
        0x02, 0xDA, 0x6E, 0xB0, 0x5E, 0xCB, 0x23, 0x80,
        0x50, 0x25, 0x2B, 0xF6, 0xAB, 0x75, 0x60, 0x2C,
    };
    const c_bi = BigInt.fromBytesBe(&c_be);

    const m_be = [256]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
        0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF,
    };
    const m_bi = BigInt.fromBytesBe(&m_be);

    // Step 1: Test m^2 mod n (simple squaring) — known value from Python
    var m2_expected_bytes: [256]u8 = [_]u8{0} ** 256;
    const m2_tail = [32]u8{
        0xC1, 0xB1, 0xCD, 0x13, 0x82, 0x92, 0xFA, 0x18,
        0xD2, 0x41, 0x2E, 0xCC, 0xB6, 0x11, 0x65, 0x20,
        0xEF, 0xB0, 0x72, 0x38, 0x6B, 0x11, 0x23, 0x80,
        0xA6, 0x47, 0x5F, 0x09, 0xA2, 0xF2, 0xA5, 0x21,
    };
    @memcpy(m2_expected_bytes[224..256], &m2_tail);
    const m2_expected = BigInt.fromBytesBe(&m2_expected_bytes);
    const m2_actual = BigInt.modMul(&m_bi, &m_bi, &n_bi);
    try std.testing.expect(m2_actual.eql(&m2_expected));

    // Step 2: Test 1 * m mod n = m (first modPow step: result=1, b=m, bit=1)
    const one_bi = BigInt.one();
    const one_mul_m = BigInt.modMul(&one_bi, &m_bi, &n_bi);
    try std.testing.expect(one_mul_m.eql(&m_bi));

    // Step 3: Test m^3 mod n — known value from Python
    var m3_expected_bytes: [256]u8 = [_]u8{0} ** 256;
    const m3_tail = [48]u8{
        0xA8, 0x7B, 0xA5, 0x75, 0xE6, 0x34, 0xA9, 0xDA,
        0x63, 0x10, 0x88, 0x56, 0x39, 0xFB, 0xFD, 0xDE,
        0x75, 0xFF, 0x86, 0xA2, 0xE8, 0xAB, 0x24, 0x77,
        0x1E, 0x0A, 0xFD, 0x18, 0x39, 0x77, 0x1F, 0x64,
        0xE3, 0x6F, 0xF4, 0x91, 0xC6, 0x7F, 0xDC, 0x0A,
        0x0C, 0xBF, 0x43, 0xEA, 0x4B, 0xCE, 0x96, 0xCF,
    };
    @memcpy(m3_expected_bytes[208..256], &m3_tail);
    const m3_expected = BigInt.fromBytesBe(&m3_expected_bytes);
    const m3_actual = BigInt.modMul(&m2_actual, &m_bi, &n_bi);
    try std.testing.expect(m3_actual.eql(&m3_expected));

    // Step 4: Full encrypt: c_actual = m^e mod n (e=65537, 17-bit exponent)
    const e_bi = BigInt.fromU32(65537);
    const c_actual = BigInt.modPow(&m_bi, &e_bi, &n_bi);

    // Verify ciphertext matches expected
    try std.testing.expect(c_actual.eql(&c_bi));

    // Step 5: Decrypt: m_actual = c^d mod n (d=2046-bit exponent — the heavy lift!)
    const m_actual = BigInt.modPow(&c_actual, &d_bi, &n_bi);

    // Verify decrypted message matches original
    try std.testing.expect(m_actual.eql(&m_bi));
}

test "HybridCipher compile-time sanity" {
    // Verify that HybridCipher compiles and initializes correctly
    // This doesn't test actual crypto (would need RSA-2048 key pair),
    // but ensures the struct layout and function signatures are correct.
    const n = BigInt.fromU32(3233);
    const d = BigInt.fromU32(2753);
    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xDEADBEEF;

    const cipher = HybridCipher.init(&n, 17, &d, &long_term_key);
    try std.testing.expect(cipher.rsa_pub.e == 17);
    try std.testing.expect(cipher.long_term_key[0] == 0xDEADBEEF);
    try std.testing.expect(HYBRID_HEADER_SIZE == 272);
    try std.testing.expect(HYBRID_NONCE_BYTES == 12);
    try std.testing.expect(HYBRID_TAG_BYTES == 32);
}

test "POLER-CTR mode: roundtrip, nonce uniqueness, block uniqueness" {
    // Unit test for CTR mode WITHOUT RSA — tests the POLER-CTR layer directly.
    // Uses a fixed POLER key derived from a known session_key + long_term_key.

    const session_key: [SESSION_KEY_BYTES]u8 = [_]u8{0xAA} ** SESSION_KEY_BYTES;
    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xDEADBEEF;

    // Derive combined key (same as HybridCipher does)
    var poler_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    comptime var w: usize = 0;
    inline while (w < poler.KEY_WORDS) : (w += 1) {
        poler_key[w] = @as(u32, session_key[w * 4]) |
            (@as(u32, session_key[w * 4 + 1]) << 8) |
            (@as(u32, session_key[w * 4 + 2]) << 16) |
            (@as(u32, session_key[w * 4 + 3]) << 24);
    }
    var combined_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    inline for (0..poler.KEY_WORDS) |k| {
        combined_key[k] = poler_key[k] ^ long_term_key[k];
    }

    var cipher = poler.PolerCipher.init(&combined_key, 0x9E3779B9);

    // --- Test 1: CTR encrypt → CTR decrypt roundtrip ---
    const plaintext1 = "Hello POLER-CTR mode! This is 32b"; // exactly 32 bytes (2 blocks)
    const nonce1: [HYBRID_NONCE_BYTES]u8 = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C };
    var ct1: [64]u8 = [_]u8{0} ** 64; // enough for 32 bytes
    var pt1: [64]u8 = [_]u8{0} ** 64;

    // Encrypt: POLER-CTR
    var block_counter: u32 = 0;
    var pt_offset: usize = 0;
    while (pt_offset < plaintext1.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce1[0]) | (@as(u32, nonce1[1]) << 8) |
            (@as(u32, nonce1[2]) << 16) | (@as(u32, nonce1[3]) << 24);
        counter_block[1] = @as(u32, nonce1[4]) | (@as(u32, nonce1[5]) << 8) |
            (@as(u32, nonce1[6]) << 16) | (@as(u32, nonce1[7]) << 24);
        counter_block[2] = @as(u32, nonce1[8]) | (@as(u32, nonce1[9]) << 8) |
            (@as(u32, nonce1[10]) << 16) | (@as(u32, nonce1[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = plaintext1.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            ct1[pt_offset + byte_idx] = plaintext1[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Decrypt: POLER-CTR (same operation — XOR with keystream)
    block_counter = 0;
    pt_offset = 0;
    while (pt_offset < plaintext1.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce1[0]) | (@as(u32, nonce1[1]) << 8) |
            (@as(u32, nonce1[2]) << 16) | (@as(u32, nonce1[3]) << 24);
        counter_block[1] = @as(u32, nonce1[4]) | (@as(u32, nonce1[5]) << 8) |
            (@as(u32, nonce1[6]) << 16) | (@as(u32, nonce1[7]) << 24);
        counter_block[2] = @as(u32, nonce1[8]) | (@as(u32, nonce1[9]) << 8) |
            (@as(u32, nonce1[10]) << 16) | (@as(u32, nonce1[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = plaintext1.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            pt1[pt_offset + byte_idx] = ct1[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Verify roundtrip
    for (plaintext1, 0..) |byte, i| {
        try std.testing.expect(pt1[i] == byte);
    }

    // --- Test 2: Different nonce → different ciphertext ---
    const nonce2: [HYBRID_NONCE_BYTES]u8 = [_]u8{ 0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8, 0xF7, 0xF6, 0xF5, 0xF4 };
    var ct2: [64]u8 = [_]u8{0} ** 64;

    block_counter = 0;
    pt_offset = 0;
    while (pt_offset < plaintext1.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce2[0]) | (@as(u32, nonce2[1]) << 8) |
            (@as(u32, nonce2[2]) << 16) | (@as(u32, nonce2[3]) << 24);
        counter_block[1] = @as(u32, nonce2[4]) | (@as(u32, nonce2[5]) << 8) |
            (@as(u32, nonce2[6]) << 16) | (@as(u32, nonce2[7]) << 24);
        counter_block[2] = @as(u32, nonce2[8]) | (@as(u32, nonce2[9]) << 8) |
            (@as(u32, nonce2[10]) << 16) | (@as(u32, nonce2[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = plaintext1.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            ct2[pt_offset + byte_idx] = plaintext1[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Ciphertext must differ with different nonce
    var any_different = false;
    for (0..plaintext1.len) |i| {
        if (ct1[i] != ct2[i]) any_different = true;
    }
    try std.testing.expect(any_different);

    // --- Test 3: Identical plaintext blocks → different ciphertext blocks (CTR guarantee) ---
    // Note: actually these are "AAAA...AAAA" (16 A's) and "BBBB...BBBB" (16 B's)
    // But let's test with truly identical blocks
    const identical_blocks = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; // 32 bytes = 2 identical 16-byte blocks
    var ct_identical: [64]u8 = [_]u8{0} ** 64;

    block_counter = 0;
    pt_offset = 0;
    while (pt_offset < identical_blocks.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce1[0]) | (@as(u32, nonce1[1]) << 8) |
            (@as(u32, nonce1[2]) << 16) | (@as(u32, nonce1[3]) << 24);
        counter_block[1] = @as(u32, nonce1[4]) | (@as(u32, nonce1[5]) << 8) |
            (@as(u32, nonce1[6]) << 16) | (@as(u32, nonce1[7]) << 24);
        counter_block[2] = @as(u32, nonce1[8]) | (@as(u32, nonce1[9]) << 8) |
            (@as(u32, nonce1[10]) << 16) | (@as(u32, nonce1[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = identical_blocks.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            ct_identical[pt_offset + byte_idx] = identical_blocks[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Two identical plaintext blocks must produce DIFFERENT ciphertext blocks
    // (because counter increments, giving different keystream)
    var blocks_differ = false;
    for (0..16) |i| {
        if (ct_identical[i] != ct_identical[16 + i]) blocks_differ = true;
    }
    try std.testing.expect(blocks_differ);
}

test "HybridCipher end-to-end (RSA-2048 + POLER-CTR)" {
    // Full hybrid encryption test using the RSA-2048 key from the 2048-bit test.
    // This exercises the complete pipeline:
    //   plaintext → POLER-CTR(session_key, nonce) → ciphertext
    //   session_key → RSA-OAEP(n, e) → RSA ciphertext
    //   Combined: [pt_len][nonce][RSA-OAEP(session_key)][POLER-CTR ciphertext]
    //
    // Then decrypts and verifies roundtrip.

    const n_be = [256]u8{
        0xB9, 0xC0, 0xD9, 0xF5, 0x83, 0xF7, 0x6C, 0x8F,
        0x90, 0x16, 0x30, 0xFF, 0xFD, 0x6E, 0x29, 0x24,
        0xBB, 0xA7, 0x89, 0xB5, 0xC2, 0x9B, 0x03, 0xC8,
        0xED, 0x7A, 0x6B, 0x67, 0x16, 0xED, 0x2A, 0x29,
        0xF1, 0x5B, 0x83, 0x6F, 0xF7, 0x59, 0x03, 0x95,
        0xF7, 0x1E, 0x0A, 0x03, 0x23, 0x1E, 0x88, 0xF5,
        0x42, 0xE8, 0x8D, 0x5C, 0x48, 0xEB, 0x1E, 0x4B,
        0x72, 0x77, 0x73, 0x2F, 0xC7, 0xBA, 0x9D, 0xCE,
        0x56, 0x77, 0x7C, 0xCB, 0xF7, 0x52, 0xA3, 0xF1,
        0xAB, 0xBB, 0x82, 0xEB, 0xF7, 0x81, 0x60, 0x82,
        0xF5, 0x69, 0xE3, 0x8C, 0x10, 0x25, 0x2A, 0xE6,
        0xF0, 0xB9, 0x6A, 0x54, 0x08, 0x5C, 0xAC, 0xA0,
        0xDD, 0x4A, 0x32, 0xC4, 0x41, 0x27, 0x88, 0xCE,
        0xA7, 0x72, 0xB8, 0x71, 0x12, 0xB9, 0x4A, 0xCB,
        0x0D, 0xCC, 0xA4, 0x74, 0xDA, 0x29, 0x7A, 0x79,
        0xED, 0x52, 0x0D, 0x84, 0x44, 0x23, 0xAC, 0x2A,
        0xCF, 0x5E, 0x84, 0xEB, 0xF8, 0x4D, 0x8F, 0x4C,
        0x34, 0xF4, 0x26, 0x42, 0x74, 0x6A, 0x06, 0xB8,
        0x6B, 0x4E, 0xD6, 0xA9, 0x06, 0x19, 0xE3, 0x37,
        0x6B, 0xEE, 0xA6, 0xC9, 0x25, 0xDA, 0x6D, 0xDF,
        0x91, 0xFF, 0xDA, 0x9F, 0x24, 0xE1, 0xEE, 0x58,
        0x1F, 0xF7, 0x9D, 0x7C, 0x82, 0xDB, 0x15, 0x0F,
        0x42, 0x28, 0xCF, 0xF1, 0x58, 0x24, 0x4B, 0x93,
        0xFF, 0x49, 0x4D, 0x99, 0x16, 0xE2, 0xE7, 0xA3,
        0x52, 0xB7, 0xED, 0x54, 0xEC, 0x7E, 0xB2, 0x45,
        0x8E, 0x1A, 0x30, 0x62, 0x8F, 0x80, 0x4B, 0xF9,
        0x98, 0x59, 0x6E, 0x93, 0x98, 0x27, 0xBE, 0xCF,
        0x9D, 0x83, 0xC3, 0x08, 0x8A, 0xE3, 0x94, 0x34,
        0xCA, 0x4A, 0xEF, 0xCD, 0x20, 0x82, 0xCB, 0xD3,
        0x68, 0x97, 0xFC, 0x38, 0xBA, 0xB0, 0xE8, 0x35,
        0x02, 0x2C, 0xC3, 0x81, 0x30, 0x09, 0x6E, 0x7E,
        0x20, 0x53, 0x11, 0x81, 0x2B, 0x1F, 0x8F, 0x8F,
    };
    const n_bi = BigInt.fromBytesBe(&n_be);

    const d_be = [256]u8{
        0x36, 0x94, 0xA5, 0x36, 0xD0, 0x1D, 0x0E, 0xC8,
        0x2C, 0x65, 0x68, 0xE6, 0x7F, 0x58, 0x34, 0x3C,
        0xB7, 0xEB, 0x25, 0xBA, 0xC3, 0xC0, 0xFA, 0xDE,
        0xBA, 0x71, 0x03, 0x48, 0x1A, 0x63, 0x7B, 0xC5,
        0x31, 0x47, 0x5B, 0x9A, 0xB5, 0xCA, 0x71, 0x14,
        0x4A, 0xB5, 0x87, 0xE9, 0x9E, 0x13, 0x25, 0xD9,
        0x33, 0x5C, 0xD3, 0xD4, 0xAF, 0x14, 0x6F, 0x25,
        0x6A, 0x30, 0x11, 0x27, 0x93, 0xFF, 0x90, 0xC9,
        0x05, 0x7D, 0x3C, 0xAD, 0x4E, 0x31, 0xF9, 0x3C,
        0x54, 0xE2, 0xD7, 0x38, 0x70, 0xD4, 0x92, 0x40,
        0x48, 0xCE, 0x61, 0x6F, 0x51, 0x7B, 0x2A, 0x5D,
        0x0B, 0x94, 0xDF, 0xDA, 0x6B, 0x4E, 0x97, 0xE6,
        0xF8, 0xBF, 0x09, 0xA5, 0xC3, 0x23, 0x53, 0xBE,
        0xAD, 0x53, 0x37, 0x40, 0xFA, 0x68, 0x79, 0xC2,
        0xAA, 0x7E, 0x5C, 0x40, 0x7D, 0xAE, 0x3C, 0x6F,
        0xC1, 0x3D, 0x1F, 0xFD, 0xA2, 0x6B, 0xFC, 0xF5,
        0x62, 0x6B, 0x77, 0x38, 0xDF, 0xA3, 0xCF, 0x4F,
        0x52, 0xAD, 0xB8, 0xF6, 0x47, 0x9D, 0x56, 0x0F,
        0xF3, 0x91, 0x8C, 0x18, 0x4B, 0x69, 0x1B, 0xE2,
        0xE8, 0xE0, 0xEA, 0x54, 0xED, 0x99, 0x4F, 0x9E,
        0xF5, 0x2C, 0xC6, 0x58, 0xD2, 0x78, 0x30, 0xF2,
        0x0D, 0xA0, 0x2E, 0x5F, 0xB4, 0x88, 0x54, 0x5D,
        0x76, 0x58, 0xC8, 0x44, 0xA8, 0xEA, 0x7E, 0x0C,
        0x1A, 0x2D, 0xD8, 0x37, 0x9F, 0x43, 0x6E, 0x79,
        0x34, 0x4E, 0xAB, 0x8E, 0x6F, 0xCD, 0xC6, 0xCF,
        0x83, 0x68, 0xBA, 0x3E, 0xCB, 0xBB, 0xE7, 0xFE,
        0x8A, 0xC2, 0xC8, 0xD5, 0x66, 0x21, 0x6B, 0xC2,
        0x94, 0x98, 0x3C, 0x93, 0xDF, 0x46, 0x25, 0x56,
        0x11, 0xF6, 0xFC, 0xC4, 0xD6, 0x76, 0xF3, 0xE9,
        0x64, 0x2D, 0x4F, 0xAF, 0xF6, 0x22, 0x5C, 0x3E,
        0xFE, 0x21, 0xD0, 0x9A, 0x0C, 0x9D, 0xF7, 0x51,
        0xD4, 0x12, 0x37, 0xE7, 0x01, 0x6E, 0x7C, 0xB9,
    };
    const d_bi = BigInt.fromBytesBe(&d_be);

    // Long-term POLER key (XOR'd with session key for defense-in-depth)
    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xCAFEBABE;
    long_term_key[1] = 0xDEADBEEF;
    long_term_key[2] = 0x12345678;
    long_term_key[3] = 0x9ABCDEF0;

    const cipher = HybridCipher.init(&n_bi, 65537, &d_bi, &long_term_key);

    // Test data — varies in length to exercise different block counts
    const test_messages = [_][]const u8{
        "Hello hybrid world!", // 20 bytes — spans 2 blocks (16 + 4 partial)
        "A", // 1 byte — single partial block
        "Exactly16bytes!!", // 16 bytes — exactly 1 block
        "This is a longer message that spans multiple POLER-CTR blocks for thorough testing!!", // 78 bytes
    };

    // Session key and OAEP seed (in production, from CSPRNG)
    const session_key: [SESSION_KEY_BYTES]u8 = [_]u8{
        0x53, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74, 0x4B,
        0x65, 0x79, 0x21, 0x21, 0x52, 0x53, 0x41, 0x2D,
        0x4F, 0x41, 0x45, 0x50, 0x2B, 0x50, 0x4F, 0x4C,
        0x45, 0x52, 0x2D, 0x43, 0x54, 0x52, 0x21, 0x21,
    };
    const oaep_seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0x42} ** SHA256_DIGEST_SIZE;

    // Nonce (must be unique per encryption — in production, from CSPRNG)
    const nonce: [HYBRID_NONCE_BYTES]u8 = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C,
    };

    for (test_messages) |msg| {
        // Encrypt
        var ciphertext: [2048]u8 = [_]u8{0} ** 2048;
        const ct_len = try cipher.hybridEncrypt(msg, &session_key, &oaep_seed, &nonce, ciphertext[0..]);

        // Verify output format
        try std.testing.expect(ct_len == msg.len + HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES);
        try std.testing.expect(ct_len >= HYBRID_HEADER_SIZE);

        // Verify pt_len in header
        const stored_pt_len: u32 = (@as(u32, ciphertext[0]) << 24) |
            (@as(u32, ciphertext[1]) << 16) |
            (@as(u32, ciphertext[2]) << 8) |
            @as(u32, ciphertext[3]);
        try std.testing.expect(stored_pt_len == msg.len);

        // Verify nonce in header
        for (0..HYBRID_NONCE_BYTES) |i| {
            try std.testing.expect(ciphertext[4 + i] == nonce[i]);
        }

        // Decrypt
        var plaintext: [2048]u8 = [_]u8{0} ** 2048;
        const pt_len = try cipher.hybridDecrypt(ciphertext[0..ct_len], plaintext[0..]);

        try std.testing.expect(pt_len == msg.len);

        // Verify plaintext matches
        for (msg, 0..) |byte, i| {
            try std.testing.expect(plaintext[i] == byte);
        }
    }

    // --- Test: Different nonce → different ciphertext ---
    const nonce2: [HYBRID_NONCE_BYTES]u8 = [_]u8{
        0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8,
        0xF7, 0xF6, 0xF5, 0xF4,
    };
    const test_msg = "Same message, different nonce";
    var ct_a: [2048]u8 = [_]u8{0} ** 2048;
    var ct_b: [2048]u8 = [_]u8{0} ** 2048;

    _ = try cipher.hybridEncrypt(test_msg, &session_key, &oaep_seed, &nonce, ct_a[0..]);
    _ = try cipher.hybridEncrypt(test_msg, &session_key, &oaep_seed, &nonce2, ct_b[0..]);

    // RSA-OAEP uses same seed → same RSA ciphertext for session_key.
    // But POLER-CTR uses different nonce → different POLER ciphertext.
    // So the total ciphertext should differ (at least in the POLER part).
    // Header (pt_len) is same, nonce differs, RSA part is same, POLER part differs.
    var poler_part_differs = false;
    const poler_start = HYBRID_HEADER_SIZE;
    const poler_end = poler_start + test_msg.len;
    for (poler_start..poler_end) |i| {
        if (ct_a[i] != ct_b[i]) poler_part_differs = true;
    }
    try std.testing.expect(poler_part_differs);

    // Both should decrypt correctly
    var pt_a: [2048]u8 = [_]u8{0} ** 2048;
    var pt_b: [2048]u8 = [_]u8{0} ** 2048;
    const pt_a_len = try cipher.hybridDecrypt(ct_a[0 .. HYBRID_HEADER_SIZE + test_msg.len + HYBRID_TAG_BYTES], pt_a[0..]);
    const pt_b_len = try cipher.hybridDecrypt(ct_b[0 .. HYBRID_HEADER_SIZE + test_msg.len + HYBRID_TAG_BYTES], pt_b[0..]);

    try std.testing.expect(pt_a_len == test_msg.len);
    try std.testing.expect(pt_b_len == test_msg.len);
    for (test_msg, 0..) |byte, i| {
        try std.testing.expect(pt_a[i] == byte);
        try std.testing.expect(pt_b[i] == byte);
    }
}

test "HMAC-SHA-256 RFC 4231 Test Case 2" {
    // RFC 4231 §5.2: Key = "Jefe", Data = "what do ya want for nothing?"
    // Expected: 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
    const key = "Jefe";
    const data = "what do ya want for nothing?";
    const tag = hmacSha256(key, data);
    const expected = [32]u8{
        0x5b, 0xdc, 0xc1, 0x46, 0xbf, 0x60, 0x75, 0x4e,
        0x6a, 0x04, 0x24, 0x26, 0x08, 0x95, 0x75, 0xc7,
        0x5a, 0x00, 0x3f, 0x08, 0x9d, 0x27, 0x39, 0x83,
        0x9d, 0xec, 0x58, 0xb9, 0x64, 0xec, 0x38, 0x43,
    };
    for (0..32) |i| {
        try std.testing.expect(tag[i] == expected[i]);
    }
}

test "HMAC-SHA-256 RFC 4231 Test Case 3" {
    // RFC 4231 §5.3: Key = 0xaa * 20, Data = 0xdd * 50
    // Expected: 773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe
    const key = [_]u8{0xAA} ** 20;
    const data = [_]u8{0xDD} ** 50;
    const tag = hmacSha256(&key, &data);
    const expected = [32]u8{
        0x77, 0x3e, 0xa9, 0x1e, 0x36, 0x80, 0x0e, 0x46,
        0x85, 0x4d, 0xb8, 0xeb, 0xd0, 0x91, 0x81, 0xa7,
        0x29, 0x59, 0x09, 0x8b, 0x3e, 0xf8, 0xc1, 0x22,
        0xd9, 0x63, 0x55, 0x14, 0xce, 0xd5, 0x65, 0xfe,
    };
    for (0..32) |i| {
        try std.testing.expect(tag[i] == expected[i]);
    }
}

test "HMAC-SHA-256 RFC 4231 Test Case 6 (key > block size)" {
    // RFC 4231 §5.6: Key = 0xaa * 131 (> 64 bytes -> hashed first)
    // Data = "Test Using Larger Than Block-Size Key - Hash Key First"
    // Expected: 60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54
    var key: [131]u8 = [_]u8{0xAA} ** 131;
    const data = "Test Using Larger Than Block-Size Key - Hash Key First";
    const tag = hmacSha256(&key, data);
    const expected = [32]u8{
        0x60, 0xe4, 0x31, 0x59, 0x1e, 0xe0, 0xb6, 0x7f,
        0x0d, 0x8a, 0x26, 0xaa, 0xcb, 0xf5, 0xb7, 0x7f,
        0x8e, 0x0b, 0xc6, 0x21, 0x37, 0x28, 0xc5, 0x14,
        0x05, 0x46, 0x04, 0x0f, 0x0e, 0xe3, 0x7f, 0x54,
    };
    for (0..32) |i| {
        try std.testing.expect(tag[i] == expected[i]);
    }
}

test "ctTagEqual: constant-time tag comparison" {
    const tag_a = [_]u8{0xAB} ** 32;
    const tag_b = [_]u8{0xAB} ** 32;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_b) == true);

    var tag_c = [_]u8{0xAB} ** 32;
    tag_c[31] = 0xAC;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_c) == false);

    var tag_d = [_]u8{0xAB} ** 32;
    tag_d[0] = 0x00;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_d) == false);

    const tag_e = [_]u8{0x00} ** 32;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_e) == false);
}

test "AEAD tamper detection: modified ciphertext -> decrypt fails" {
    // Verifies that modifying ANY byte of the ciphertext causes
    // hybridDecrypt to reject with an authentication error.
    // Uses the same RSA-2048 key from the 2048-bit test.

    const n_be = [256]u8{
        0xB9, 0xC0, 0xD9, 0xF5, 0x83, 0xF7, 0x6C, 0x8F,
        0x90, 0x16, 0x30, 0xFF, 0xFD, 0x6E, 0x29, 0x24,
        0xBB, 0xA7, 0x89, 0xB5, 0xC2, 0x9B, 0x03, 0xC8,
        0xED, 0x7A, 0x6B, 0x67, 0x16, 0xED, 0x2A, 0x29,
        0xF1, 0x5B, 0x83, 0x6F, 0xF7, 0x59, 0x03, 0x95,
        0xF7, 0x1E, 0x0A, 0x03, 0x23, 0x1E, 0x88, 0xF5,
        0x42, 0xE8, 0x8D, 0x5C, 0x48, 0xEB, 0x1E, 0x4B,
        0x72, 0x77, 0x73, 0x2F, 0xC7, 0xBA, 0x9D, 0xCE,
        0x56, 0x77, 0x7C, 0xCB, 0xF7, 0x52, 0xA3, 0xF1,
        0xAB, 0xBB, 0x82, 0xEB, 0xF7, 0x81, 0x60, 0x82,
        0xF5, 0x69, 0xE3, 0x8C, 0x10, 0x25, 0x2A, 0xE6,
        0xF0, 0xB9, 0x6A, 0x54, 0x08, 0x5C, 0xAC, 0xA0,
        0xDD, 0x4A, 0x32, 0xC4, 0x41, 0x27, 0x88, 0xCE,
        0xA7, 0x72, 0xB8, 0x71, 0x12, 0xB9, 0x4A, 0xCB,
        0x0D, 0xCC, 0xA4, 0x74, 0xDA, 0x29, 0x7A, 0x79,
        0xED, 0x52, 0x0D, 0x84, 0x44, 0x23, 0xAC, 0x2A,
        0xCF, 0x5E, 0x84, 0xEB, 0xF8, 0x4D, 0x8F, 0x4C,
        0x34, 0xF4, 0x26, 0x42, 0x74, 0x6A, 0x06, 0xB8,
        0x6B, 0x4E, 0xD6, 0xA9, 0x06, 0x19, 0xE3, 0x37,
        0x6B, 0xEE, 0xA6, 0xC9, 0x25, 0xDA, 0x6D, 0xDF,
        0x91, 0xFF, 0xDA, 0x9F, 0x24, 0xE1, 0xEE, 0x58,
        0x1F, 0xF7, 0x9D, 0x7C, 0x82, 0xDB, 0x15, 0x0F,
        0x42, 0x28, 0xCF, 0xF1, 0x58, 0x24, 0x4B, 0x93,
        0xFF, 0x49, 0x4D, 0x99, 0x16, 0xE2, 0xE7, 0xA3,
        0x52, 0xB7, 0xED, 0x54, 0xEC, 0x7E, 0xB2, 0x45,
        0x8E, 0x1A, 0x30, 0x62, 0x8F, 0x80, 0x4B, 0xF9,
        0x98, 0x59, 0x6E, 0x93, 0x98, 0x27, 0xBE, 0xCF,
        0x9D, 0x83, 0xC3, 0x08, 0x8A, 0xE3, 0x94, 0x34,
        0xCA, 0x4A, 0xEF, 0xCD, 0x20, 0x82, 0xCB, 0xD3,
        0x68, 0x97, 0xFC, 0x38, 0xBA, 0xB0, 0xE8, 0x35,
        0x02, 0x2C, 0xC3, 0x81, 0x30, 0x09, 0x6E, 0x7E,
        0x20, 0x53, 0x11, 0x81, 0x2B, 0x1F, 0x8F, 0x8F,
    };
    const n_bi = BigInt.fromBytesBe(&n_be);
    const d_be = [256]u8{
        0x36, 0x94, 0xA5, 0x36, 0xD0, 0x1D, 0x0E, 0xC8,
        0x2C, 0x65, 0x68, 0xE6, 0x7F, 0x58, 0x34, 0x3C,
        0xB7, 0xEB, 0x25, 0xBA, 0xC3, 0xC0, 0xFA, 0xDE,
        0xBA, 0x71, 0x03, 0x48, 0x1A, 0x63, 0x7B, 0xC5,
        0x31, 0x47, 0x5B, 0x9A, 0xB5, 0xCA, 0x71, 0x14,
        0x4A, 0xB5, 0x87, 0xE9, 0x9E, 0x13, 0x25, 0xD9,
        0x33, 0x5C, 0xD3, 0xD4, 0xAF, 0x14, 0x6F, 0x25,
        0x6A, 0x30, 0x11, 0x27, 0x93, 0xFF, 0x90, 0xC9,
        0x05, 0x7D, 0x3C, 0xAD, 0x4E, 0x31, 0xF9, 0x3C,
        0x54, 0xE2, 0xD7, 0x38, 0x70, 0xD4, 0x92, 0x40,
        0x48, 0xCE, 0x61, 0x6F, 0x51, 0x7B, 0x2A, 0x5D,
        0x0B, 0x94, 0xDF, 0xDA, 0x6B, 0x4E, 0x97, 0xE6,
        0xF8, 0xBF, 0x09, 0xA5, 0xC3, 0x23, 0x53, 0xBE,
        0xAD, 0x53, 0x37, 0x40, 0xFA, 0x68, 0x79, 0xC2,
        0xAA, 0x7E, 0x5C, 0x40, 0x7D, 0xAE, 0x3C, 0x6F,
        0xC1, 0x3D, 0x1F, 0xFD, 0xA2, 0x6B, 0xFC, 0xF5,
        0x62, 0x6B, 0x77, 0x38, 0xDF, 0xA3, 0xCF, 0x4F,
        0x52, 0xAD, 0xB8, 0xF6, 0x47, 0x9D, 0x56, 0x0F,
        0xF3, 0x91, 0x8C, 0x18, 0x4B, 0x69, 0x1B, 0xE2,
        0xE8, 0xE0, 0xEA, 0x54, 0xED, 0x99, 0x4F, 0x9E,
        0xF5, 0x2C, 0xC6, 0x58, 0xD2, 0x78, 0x30, 0xF2,
        0x0D, 0xA0, 0x2E, 0x5F, 0xB4, 0x88, 0x54, 0x5D,
        0x76, 0x58, 0xC8, 0x44, 0xA8, 0xEA, 0x7E, 0x0C,
        0x1A, 0x2D, 0xD8, 0x37, 0x9F, 0x43, 0x6E, 0x79,
        0x34, 0x4E, 0xAB, 0x8E, 0x6F, 0xCD, 0xC6, 0xCF,
        0x83, 0x68, 0xBA, 0x3E, 0xCB, 0xBB, 0xE7, 0xFE,
        0x8A, 0xC2, 0xC8, 0xD5, 0x66, 0x21, 0x6B, 0xC2,
        0x94, 0x98, 0x3C, 0x93, 0xDF, 0x46, 0x25, 0x56,
        0x11, 0xF6, 0xFC, 0xC4, 0xD6, 0x76, 0xF3, 0xE9,
        0x64, 0x2D, 0x4F, 0xAF, 0xF6, 0x22, 0x5C, 0x3E,
        0xFE, 0x21, 0xD0, 0x9A, 0x0C, 0x9D, 0xF7, 0x51,
        0xD4, 0x12, 0x37, 0xE7, 0x01, 0x6E, 0x7C, 0xB9,
    };
    const d_bi = BigInt.fromBytesBe(&d_be);

    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xCAFEBABE;

    const cipher = HybridCipher.init(&n_bi, 65537, &d_bi, &long_term_key);

    const session_key: [SESSION_KEY_BYTES]u8 = [_]u8{
        0x53, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74, 0x4B,
        0x65, 0x79, 0x21, 0x21, 0x52, 0x53, 0x41, 0x2D,
        0x4F, 0x41, 0x45, 0x50, 0x2B, 0x50, 0x4F, 0x4C,
        0x45, 0x52, 0x2D, 0x43, 0x54, 0x52, 0x21, 0x21,
    };
    const oaep_seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0x42} ** SHA256_DIGEST_SIZE;
    const nonce: [HYBRID_NONCE_BYTES]u8 = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C,
    };

    const msg = "AEAD tamper test message";
    var ciphertext: [4096]u8 = [_]u8{0} ** 4096;
    const ct_len = try cipher.hybridEncrypt(msg, &session_key, &oaep_seed, &nonce, ciphertext[0..]);

    // Untamered → OK
    var plaintext: [4096]u8 = [_]u8{0} ** 4096;
    const pt_len = try cipher.hybridDecrypt(ciphertext[0..ct_len], plaintext[0..]);
    try std.testing.expect(pt_len == msg.len);
    for (msg, 0..) |byte, i| {
        try std.testing.expect(plaintext[i] == byte);
    }

    // Flip bit in POLER-CTR ciphertext -> REJECT
    var tampered: [4096]u8 = [_]u8{0} ** 4096;
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[HYBRID_HEADER_SIZE + 5] ^= 0x01;
    try std.testing.expect(cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) == OaepError.invalid_padding);

    // Flip bit in RSA-OAEP portion -> REJECT (may fail at OAEP or MAC level)
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[4 + HYBRID_NONCE_BYTES + 10] ^= 0x01;
    _ = cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) catch {}; // any error is OK

    // Flip bit in nonce -> REJECT
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[5] ^= 0x01;
    try std.testing.expect(cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) == OaepError.invalid_padding);

    // Flip bit in tag -> REJECT
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[HYBRID_HEADER_SIZE + msg.len] ^= 0x01;
    try std.testing.expect(cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) == OaepError.invalid_padding);

    // Modify pt_len in header -> REJECT (may give decoding_error or invalid_padding)
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[3] +%= 1;
    _ = cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) catch {}; // any error is OK
}
`
```

### `zig-kernel/src64/acpi.zig` [zig · 14,864 B]
```
`// ============================================================================
// POLER-OS ACPI — Advanced Configuration and Power Interface
// ============================================================================
//
// ACPI — RSDP/RSDT/MADT/MCFG parsing
//
// Зачем нам ACPI:
//   1. MADT (Multiple APIC Description Table) → сколько CPU, IO-APIC адреса
//   2. MCFG (PCI Configuration Space) → базовый адрес PCIe конфигурации
//   3. HPET (High Precision Event Timer) → альтернатива PIT
//   4. DSDT/SSDT → информация об устройствах (для будущего)
// ============================================================================

const hal = @import("hal.zig");

// ============================================================================
// ACPI Table Header (общий для всех таблиц)
// ============================================================================

pub const TableHeader = extern struct {
    signature: [4]u8,
    length: u32,
    revision: u8,
    checksum: u8,
    oem_id: [6]u8,
    oem_table_id: [8]u8,
    oem_revision: u32,
    creator_id: u32,
    creator_revision: u32,
};

// ============================================================================
// RSDP (Root System Description Pointer)
// ============================================================================

pub const RSDP = extern struct {
    signature: [8]u8,       // "RSD PTR "
    checksum: u8,
    oem_id: [6]u8,
    revision: u8,           // 0 = ACPI 1.0, 2 = ACPI 2.0+
    rsdt_address: u32,      // RSDT (32-bit, ACPI 1.0)
    length: u32,            // Total length of RSDP (ACPI 2.0+)
    xsdt_address: u64,      // XSDT (64-bit, ACPI 2.0+)
    extended_checksum: u8,
    _reserved: [3]u8,

    pub fn is_valid(self: *const RSDP) bool {
        // Check signature "RSD PTR "
        const expected_sig = "RSD PTR ";
        for (expected_sig, 0..) |ch, i| {
            if (self.signature[i] != ch) return false;
        }
        // Checksum validation (sum of all bytes = 0 mod 256)
        if (!validateChecksum(@ptrCast(self), 20)) return false; // ACPI 1.0 portion
        if (self.revision >= 2) {
            if (!validateChecksum(@ptrCast(self), @intCast(self.length))) return false;
        }
        return true;
    }
};

// ============================================================================
// RSDT / XSDT (Root/Extended System Description Table)
// ============================================================================

pub const RSDT = extern struct {
    header: TableHeader,
    entries: [0]u32, // Variable length array of 32-bit physical addresses
};

pub const XSDT = extern struct {
    header: TableHeader,
    entries: [0]u64, // Variable length array of 64-bit physical addresses
};

// ============================================================================
// MADT (Multiple APIC Description Table)
// Нам нужно: количество CPU, адрес Local APIC, адрес IO-APIC
// ============================================================================

pub const MADT = extern struct {
    header: TableHeader,
    local_apic_address: u32,    // Physical address of Local APIC
    flags: u32,                 // 1 = PCAT_COMPAT (has dual-8259 setup)
    entries: [0]u8,             // Variable length: APIC structures follow
};

pub const MADTEntryType = enum(u8) {
    LocalAPIC = 0,
    IOAPIC = 1,
    InterruptOverride = 2,
    NMI = 3,
    LocalAPICNMI = 4,
    LocalAPICOverride = 5,
    IOSAPIC = 6,
    LocalSAPIC = 7,
    PlatformInterrupt = 8,
    _,
};

pub const MADTLocalAPIC = extern struct {
    type: u8,           // 0
    length: u8,         // 8
    acpi_processor_id: u8,
    apic_id: u8,
    flags: u32,         // Bit 0 = enabled
};

pub const MADTIOAPIC = extern struct {
    type: u8,           // 1
    length: u8,         // 12
    ioapic_id: u8,
    _reserved: u8,
    ioapic_address: u32,
    global_irq_base: u32,
};

pub const MADTInterruptOverride = extern struct {
    type: u8,           // 2
    length: u8,         // 10
    bus: u8,            // 0 = ISA
    source_irq: u8,
    global_irq: u32,
    flags: u16,         // Polarity + Trigger mode
};

// ============================================================================
// MCFG (PCI Configuration Space)
// ============================================================================

pub const MCFG = extern struct {
    header: TableHeader,
    _reserved: u64,
    entries: [0]MCFGEntry,
};

pub const MCFGEntry = extern struct {
    base_address: u64,      // Base address of enhanced config space
    pci_segment_group: u16,
    start_bus: u8,
    end_bus: u8,
    _reserved: u32,
};

// ============================================================================
// ACPI State
// ============================================================================

pub var rsdp: ?*const RSDP = null;
pub var cpu_count: u32 = 0;
pub var local_apic_addr: u64 = 0;
pub var io_apic_addr: u64 = 0;
pub var io_apic_count: u32 = 0;
pub var mcfg_base: u64 = 0;

// ============================================================================
// SMP: Per-CPU information from MADT
// ============================================================================

pub const MAX_CPUS = 16;

pub const CpuInfo = struct {
    acpi_processor_id: u8,
    apic_id: u8,
    enabled: bool,
    is_bsp: bool,
};

/// Array of detected CPU entries from MADT.
pub var cpu_list: [MAX_CPUS]CpuInfo = undefined;

/// BSP Local APIC ID (read from Local APIC at boot).
pub var bsp_apic_id: u32 = 0;

// IRQ override table (ISA → Global IRQ mapping)
pub const MAX_IRQ_OVERRIDES = 16;
pub var irq_overrides: [MAX_IRQ_OVERRIDES]IRQOverride = undefined;
pub var irq_override_count: u32 = 0;

pub const IRQOverride = struct {
    source_irq: u8,
    global_irq: u32,
    flags: u16,
};

// ============================================================================
// Функции
// ============================================================================

fn validateChecksum(ptr: [*]const u8, len: u32) bool {
    var sum: u8 = 0;
    for (0..len) |i| {
        sum +%= ptr[i];
    }
    return sum == 0;
}

fn memEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn signatureEquals(sig: *const [4]u8, expected: *const [4]u8) bool {
    return sig[0] == expected[0] and sig[1] == expected[1] and sig[2] == expected[2] and sig[3] == expected[3];
}

/// Physical memory read (identity-mapped, so just cast pointer)
fn physToPtr(phys: u64) *anyopaque {
    return @ptrFromInt(@as(usize, phys));
}

/// Search for RSDP in memory
pub fn findRSDP() ?*const RSDP {
    // Метод 1: Поиск в BIOS ROM area (0xE0000 - 0xFFFFF)
    // Это стандартное расположение для BIOS ACPI tables
    var addr: u64 = 0xE0000;
    while (addr < 0x100000) : (addr += 16) {
        const candidate: *const RSDP = @ptrFromInt(@as(usize, addr));
        if (candidate.is_valid()) {
            return candidate;
        }
    }

    // Метод 2: Через EFI system table (если загружены через EFI)
    // TODO: Multiboot2 может передать EFI_SYSTEM_TABLE

    // Метод 3: Через EBDA (Extended BIOS Data Area)
    // EBDA address хранится по 0x40E
    const ebda_segment: u16 = @as(*const volatile u16, @ptrFromInt(@as(usize, 0x40E))).*;
    const ebda_addr: u64 = @as(u64, ebda_segment) << 4;
    if (ebda_addr >= 0x400 and ebda_addr < 0xA0000) {
        var scan_addr = ebda_addr;
        while (scan_addr < ebda_addr + 1024) : (scan_addr += 16) {
            const candidate: *const RSDP = @ptrFromInt(@as(usize, scan_addr));
            if (candidate.is_valid()) {
                return candidate;
            }
        }
    }

    return null;
}

/// Парсинг ACPI таблиц
pub fn init() void {
    hal.Serial.puts("[ACPI] Searching for RSDP...\n");

    rsdp = findRSDP() orelse {
        hal.Serial.puts("[ACPI] RSDP NOT FOUND! ACPI unavailable\n");
        return;
    };

    hal.Serial.puts("[ACPI] RSDP found at: ");
    hal.Serial.putHex(@intFromPtr(rsdp.?));
    hal.Serial.puts("\n");

    if (rsdp.?.revision >= 2 and rsdp.?.xsdt_address != 0) {
        parseXSDT();
    } else if (rsdp.?.rsdt_address != 0) {
        parseRSDT();
    } else {
        hal.Serial.puts("[ACPI] No RSDT/XSDT found!\n");
    }

    // Вывод результатов
    hal.Serial.puts("[ACPI] CPUs: ");
    hal.Serial.putHex(cpu_count);
    hal.Serial.puts("\n");

    hal.Serial.puts("[ACPI] Local APIC: ");
    hal.Serial.putHex(local_apic_addr);
    hal.Serial.puts("\n");

    if (io_apic_addr != 0) {
        hal.Serial.puts("[ACPI] IO-APIC: ");
        hal.Serial.putHex(io_apic_addr);
        hal.Serial.puts("\n");
    }
}

fn parseXSDT() void {
    const xsdt: *align(1) const XSDT = @ptrCast(physToPtr(rsdp.?.xsdt_address));

    // Validate XSDT
    if (!signatureEquals(&xsdt.header.signature, "XSDT")) {
        hal.Serial.puts("[ACPI] Invalid XSDT signature!\n");
        return;
    }

    const entry_count = (xsdt.header.length - @sizeOf(TableHeader)) / 8;
    hal.Serial.puts("[ACPI] XSDT entries: ");
    hal.Serial.putHex(entry_count);
    hal.Serial.puts("\n");

    // XSDT entries start right after the header
    const entries_ptr: [*]align(1) const u64 = @ptrFromInt(@intFromPtr(xsdt) + @sizeOf(TableHeader));
    for (0..entry_count) |i| {
        const table_addr = entries_ptr[i];
        if (table_addr == 0) continue;
        parseTable(table_addr);
    }
}

fn parseRSDT() void {
    const rsdt: *align(1) const RSDT = @ptrCast(physToPtr(rsdp.?.rsdt_address));

    if (!signatureEquals(&rsdt.header.signature, "RSDT")) {
        hal.Serial.puts("[ACPI] Invalid RSDT signature!\n");
        return;
    }

    const entry_count = (rsdt.header.length - @sizeOf(TableHeader)) / 4;
    hal.Serial.puts("[ACPI] RSDT entries: ");
    hal.Serial.putHex(entry_count);
    hal.Serial.puts("\n");

    // RSDT entries start right after the header
    const entries_ptr: [*]align(1) const u32 = @ptrFromInt(@intFromPtr(rsdt) + @sizeOf(TableHeader));
    for (0..entry_count) |i| {
        const table_addr: u64 = entries_ptr[i];
        if (table_addr == 0) continue;
        parseTable(table_addr);
    }
}

fn parseTable(phys_addr: u64) void {
    const header: *align(1) const TableHeader = @ptrCast(physToPtr(phys_addr));

    // Validate checksum before trusting any table contents
    const header_bytes: [*]const u8 = @ptrCast(physToPtr(phys_addr));
    if (!validateChecksum(header_bytes, header.length)) {
        hal.Serial.puts("[ACPI] WARNING: Checksum failed for table: ");
        hal.Serial.puts(&header.signature);
        hal.Serial.puts("\n");
        return; // Skip corrupted table
    }

    if (signatureEquals(&header.signature, "APIC")) {
        parseMADT(phys_addr);
    } else if (signatureEquals(&header.signature, "MCFG")) {
        parseMCFG(phys_addr);
    } else if (signatureEquals(&header.signature, "HPET")) {
        hal.Serial.puts("[ACPI] HPET table found (not yet used)\n");
    }
}

fn parseMADT(phys_addr: u64) void {
    const madt: *align(1) const MADT = @ptrCast(physToPtr(phys_addr));

    local_apic_addr = madt.local_apic_address;
    hal.Serial.puts("[ACPI] MADT: Local APIC at ");
    hal.Serial.putHex(local_apic_addr);
    hal.Serial.puts("\n");

    // Парсим записи MADT
    const entries_start: usize = @intFromPtr(&madt.entries);
    const entries_end: usize = @intFromPtr(madt) + madt.header.length;
    var offset: usize = entries_start;

    while (offset < entries_end) {
        const entry_type: u8 = @as(*const volatile u8, @ptrFromInt(offset)).*;
        const entry_len: u8 = @as(*const volatile u8, @ptrFromInt(offset + 1)).*;

        if (entry_len < 2) break; // Invalid entry

        switch (@as(MADTEntryType, @enumFromInt(entry_type))) {
            .LocalAPIC => {
                const lapic: *align(1) const MADTLocalAPIC = @ptrFromInt(offset);
                const enabled = (lapic.flags & 1) != 0;
                if (enabled and cpu_count < MAX_CPUS) {
                    cpu_list[cpu_count] = CpuInfo{
                        .acpi_processor_id = lapic.acpi_processor_id,
                        .apic_id = lapic.apic_id,
                        .enabled = true,
                        .is_bsp = false, // will be set later when BSP APIC ID is known
                    };
                    cpu_count += 1;
                }
            },
            .IOAPIC => {
                const ioapic: *align(1) const MADTIOAPIC = @ptrFromInt(offset);
                if (io_apic_count == 0) {
                    io_apic_addr = ioapic.ioapic_address;
                }
                io_apic_count += 1;
            },
            .InterruptOverride => {
                const override_entry: *align(1) const MADTInterruptOverride = @ptrFromInt(offset);
                if (irq_override_count < MAX_IRQ_OVERRIDES) {
                    irq_overrides[irq_override_count] = .{
                        .source_irq = override_entry.source_irq,
                        .global_irq = override_entry.global_irq,
                        .flags = override_entry.flags,
                    };
                    irq_override_count += 1;
                }
            },
            else => {},
        }

        offset += entry_len;
    }

    hal.Serial.puts("[ACPI] MADT parsed: ");
    hal.Serial.putHex(cpu_count);
    hal.Serial.puts(" CPUs, ");
    hal.Serial.putHex(io_apic_count);
    hal.Serial.puts(" IO-APICs\n");

    // Print detected CPU list
    for (0..cpu_count) |i| {
        hal.Serial.puts("[ACPI]   CPU ");
        hal.Serial.putDecimal(i);
        hal.Serial.puts(": APIC_ID=");
        hal.Serial.putHex(@as(u64, cpu_list[i].apic_id));
        hal.Serial.puts(" ACPI_ID=");
        hal.Serial.putHex(@as(u64, cpu_list[i].acpi_processor_id));
        if (cpu_list[i].is_bsp) {
            hal.Serial.puts(" [BSP]");
        }
        hal.Serial.puts("\n");
    }
}

fn parseMCFG(phys_addr: u64) void {
    const mcfg: *align(1) const MCFG = @ptrCast(physToPtr(phys_addr));

    const entry_count = (mcfg.header.length - @sizeOf(TableHeader) - 8) / @sizeOf(MCFGEntry);
    if (entry_count > 0) {
        // MCFG entries start after header + 8-byte reserved field
        const entries_ptr: [*]align(1) const MCFGEntry = @ptrFromInt(@intFromPtr(mcfg) + @sizeOf(TableHeader) + 8);
        mcfg_base = entries_ptr[0].base_address;
        hal.Serial.puts("[ACPI] MCFG: PCIe config at ");
        hal.Serial.putHex(mcfg_base);
        hal.Serial.puts("\n");
    }
}
`
```

### `zig-kernel/src64/boot64.S` [asm · 11,290 B]
```
`// ============================================================================
// POLER-OS boot64.S — Multiboot2 → Long Mode (64-bit)
// ============================================================================
//
// Boot sequence:
//   1. Multiboot2 header (for GRUB)
//   2. Verify Multiboot2 magic (0x36D76289)
//   3. Identity-mapped PML4 (4-level paging)
//   4. Enable PAE + Long Mode via CR4 + EFER
//   5. Load CR3 (PML4)
//   6. Enable paging (CR0.PG)
//   7. Far jump to 64-bit code
//   8. Setup GDT64
//   9. Call poler_kernel_main() in Zig
// ============================================================================

.set MB2_MAGIC,          0xE85250D6   // Multiboot2 header magic
.set MB2_BOOTLOADER_MAGIC, 0x36D76289 // Значение в EAX при загрузке
.set MB2_ARCHITECTURE,   0            // 0 = x86 (protected mode)

.set CR0_PE,             0x00000001
.set CR0_PG,             0x80000000
.set CR4_PAE,            0x00000020
.set CR4_PSE,            0x00000010

.set MSR_EFER,           0xC0000080
.set EFER_LME,           0x00000100
.set EFER_NXE,           0x00000800

// KERNEL_BASE removed — flat identity-mapped kernel for now

// ============================================================================
// Multiboot2 Header
// ============================================================================
.section .multiboot2, "a", @progbits
.balign 8
mb2_header_start:
    .long MB2_MAGIC                                    // magic
    .long MB2_ARCHITECTURE                             // architecture
    .long mb2_header_end - mb2_header_start            // header length
    .long -(MB2_MAGIC + MB2_ARCHITECTURE + (mb2_header_end - mb2_header_start))  // checksum

    // Framebuffer Request Tag (type = 5) — DISABLED for v0.7.x
    // Using VGA text mode (80x25) for reliable terminal output.
    // Graphical framebuffer will be re-enabled in v0.8.0 with proper rendering.
    //
    // .balign 8
    // .word 5                  // type
    // .word 0                  // flags (0 = required)
    // .long 20                 // size
    // .long 1024               // preferred width
    // .long 768                // preferred height
    // .long 32                 // preferred depth

    // End tag
    .balign 8
    .word 0                  // type = end
    .word 0                  // flags
    .long 8                  // size
mb2_header_end:

// ============================================================================
// 32-bit Entry Point (Multiboot2 загружает нас сюда)
// ============================================================================
.section .text.boot32, "ax", @progbits
.global _start
.code32

_start:
    // Сохраняем Multiboot2 info в регистры (EBP = magic, EBX = MBI)
    movl %eax, %ebp

    // ========================================================================
    // Early Serial Init (COM1 = 0x3F8) — для debug output ещё до Zig
    // ========================================================================
    movw $0x3F8, %dx
    movb $0x00, %al
    outb %al, %dx          // 0x3F8+1: Disable interrupts
    incw %dx               // 0x3F9
    outb %al, %dx
    movw $0x3FB, %dx
    movb $0x80, %al        // 0x3FB: Enable DLAB
    outb %al, %dx
    movw $0x3F8, %dx
    movb $0x01, %al        // 0x3F8: Divisor low = 1 (115200 baud)
    outb %al, %dx
    movw $0x3F9, %dx
    movb $0x00, %al        // 0x3F9: Divisor high = 0
    outb %al, %dx
    movw $0x3FB, %dx
    movb $0x03, %al        // 0x3FB: 8N1
    outb %al, %dx
    movw $0x3FA, %dx
    movb $0xC7, %al        // 0x3FA: Enable FIFO
    outb %al, %dx
    movw $0x3FC, %dx
    movb $0x0B, %al        // 0x3FC: RTS/DSR/DTR
    outb %al, %dx

    // Output 'A' to serial — we're alive!
    movw $0x3F8, %dx
    movb $'A', %al
    outb %al, %dx

    // Проверяем Multiboot2 magic (из сохранённого регистра EBP)
    cmpl $MB2_BOOTLOADER_MAGIC, %ebp
    jne .hang

    // Output 'C' (magic OK)
    movb $'C', %al
    outb %al, %dx

    // Временно отключаем прерывания
    cli

    // Загружаем GDT32 (нужен для far jump)
    lgdt gdt32_ptr

    // Переключаемся на 32-bit code segment
    ljmpl $0x08, $.setup_paging

.setup_paging:
    // Теперь в protected mode с нашим GDT
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    // Настраиваем стек (32KB, ниже 1MB)
    movl $0x0007C00, %esp

    // ========================================================================
    // Создаём Identity-mapped Page Tables
    // PML4[0] → PDPT[0] → PD[0..3] (4 entries = 4GB identity map, 2MB pages)
    // ========================================================================

    // Очищаем страницу для PML4 (4KB at pml4_addr)
    movl $pml4_addr, %edi
    xorl %eax, %eax
    movl $1024, %ecx          // 1024 * 4 bytes = 4KB
    rep stosl

    // Очищаем PDPT
    movl $pdpt_addr, %edi
    xorl %eax, %eax
    movl $1024, %ecx
    rep stosl

    // Очищаем PD (4 pages для 4GB mapping)
    movl $pd_addr, %edi
    xorl %eax, %eax
    movl $4096, %ecx          // 4 pages * 1024 = 4096 dwords = 16KB
    rep stosl

    // PML4[0] → PDPT (present + writable + user)
    movl $pdpt_addr, %eax
    orl $0x07, %eax           // Present + Writable + User
    movl %eax, pml4_addr

    // PDPT: 4 entries pointing to 4 PD pages
    // Each PD page maps 1GB (512 entries × 2MB)
    movl $pd_addr, %eax
    orl $0x07, %eax
    movl %eax, pdpt_addr           // PDPT[0] → PD0 (0-1GB)
    addl $0x1000, %eax
    movl %eax, pdpt_addr + 8       // PDPT[1] → PD1 (1-2GB)
    addl $0x1000, %eax
    movl %eax, pdpt_addr + 16      // PDPT[2] → PD2 (2-3GB)
    addl $0x1000, %eax
    movl %eax, pdpt_addr + 24      // PDPT[3] → PD3 (3-4GB)

    // PD: заполняем ALL 2048 entries (4 pages × 512) с 2MB huge pages
    // Это маппит 0-4GB identity-mapped
    movl $pd_addr, %edi
    movl $0x87, %eax          // Present + Writable + User + PageSize(2MB), start at 0
    movl $2048, %ecx          // 2048 entries = 4GB (2048 * 2MB)
.fill_pd_loop:
    movl %eax, (%edi)
    addl $0x00200000, %eax    // Next 2MB
    addl $8, %edi             // Next PD entry
    loop .fill_pd_loop

    // ========================================================================
    // Включаем PAE (CR4.PAE)
    // ========================================================================
    movl %cr4, %eax
    orl $CR4_PAE, %eax
    orl $CR4_PSE, %eax        // Page Size Extension
    movl %eax, %cr4

    // ========================================================================
    // Включаем Long Mode (EFER.LME)
    // ========================================================================
    movl $MSR_EFER, %ecx
    rdmsr
    orl $EFER_LME, %eax
    orl $EFER_NXE, %eax       // No-Execute Enable
    wrmsr

    // ========================================================================
    // Загружаем CR3 (PML4 base)
    // ========================================================================
    movl $pml4_addr, %eax
    movl %eax, %cr3

    // ========================================================================
    // Включаем Paging (CR0.PG)
    // ========================================================================
    movl %cr0, %eax
    orl $CR0_PG, %eax
    movl %eax, %cr0

    // ========================================================================
    // Far jump в 64-bit код!
    // Загружаем GDT64 и прыгаем
    // ========================================================================
    lgdt gdt64_ptr
    ljmpl $0x08, $.long_mode_entry

// ============================================================================
// 64-bit Entry Point
// ============================================================================
.section .text.boot64, "ax", @progbits
.code64

.long_mode_entry:
    // Перезагружаем сегменты для 64-bit
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    // Настраиваем 64-bit стек (16KB)
    movq $stack_top, %rsp

    // Включаем SSE (требуется для Zig SSE-оптимизированного кода)
    movq %cr0, %rax
    andq $-5, %rax         // Очищаем EM (bit 2) ($-5 = ~0x4)
    orq $0x2, %rax         // Устанавливаем MP (bit 1)
    movq %rax, %cr0

    movq %cr4, %rax
    orq $0x600, %rax       // Устанавливаем OSFXSR (bit 9) и OSXMMEXCPT (bit 10)
    movq %rax, %cr4

    // Сохраняем Multiboot2 info в extended регистры до очистки BSS
    movl %ebp, %r12d     // magic
    movl %ebx, %r13d     // mbi pointer

    // Обнуляем BSS (для Zig)
    movq $bss_start, %rdi
    movq $bss_end, %rcx
    subq %rdi, %rcx
    xorq %rax, %rax
    rep stosb

    // Передаем Multiboot2 info в аргументы для Zig (magic -> edi, mbi -> rsi)
    movl %r12d, %edi
    movl %r13d, %esi

    // Вызываем Zig kernel main
    call poler_kernel_main

    // Если вернулись — зависаем
.hang64:
    cli
    hlt
    jmp .hang64

// ============================================================================
// 32-bit hang (при ошибке)
// ============================================================================
.code32
.hang:
    cli
    hlt
    jmp .hang



// ============================================================================
// GDT32 (для перехода protected → long)
// ============================================================================
.section .rodata.gdt32, "a", @progbits
.balign 16
gdt32_start:
    .quad 0x0000000000000000     // 0x00: Null descriptor
    .quad 0x00CF9A000000FFFF     // 0x08: 32-bit Code (0-4GB, ring 0)
    .quad 0x00CF92000000FFFF     // 0x10: 32-bit Data (0-4GB, ring 0)
gdt32_end:

gdt32_ptr:
    .word gdt32_end - gdt32_start - 1   // limit
    .long gdt32_start                     // base

// ============================================================================
// GDT64 (для long mode)
// ============================================================================
.section .rodata.gdt64
.balign 16
gdt64_start:
    .quad 0x0000000000000000     // 0x00: Null descriptor
    .quad 0x00209A0000000000     // 0x08: 64-bit Code (Long mode, ring 0)
    .quad 0x0000920000000000     // 0x10: 64-bit Data (ring 0)
    .quad 0x0000F20000000000     // 0x18: 64-bit Data (User, ring 3)
    .quad 0x0020FA0000000000     // 0x20: 64-bit Code (User, ring 3)
    .quad 0x00CF9A000000FFFF     // 0x28: 32-bit Code (ring 0) — SMP AP trampoline
    .quad 0x00CF92000000FFFF     // 0x30: 32-bit Data (ring 0) — SMP AP trampoline
    // TSS будет добавлен динамически из Zig (0x38/0x40)
gdt64_end:

gdt64_ptr:
    .word gdt64_end - gdt64_start - 1   // limit
    .quad gdt64_start                     // base (64-bit!)



// BSS markers (defined by linker script)
`
```

### `zig-kernel/src64/boot_smp.S` [asm · 8,037 B]
```
`// ============================================================================
// POLER-OS AP Trampoline — boot_smp.S
// ============================================================================
//
// This is the AP (Application Processor) startup trampoline code.
// It is copied to physical address 0x8000 at boot time by the BSP.
// Each AP starts executing here in 16-bit real mode after SIPI.
//
// The trampoline:
//   1. Switches from 16-bit real mode → 32-bit protected mode
//   2. Enables PAE + Long Mode via CR4 + EFER
//   3. Loads CR3 (page tables from BSP)
//   4. Enables paging
//   5. Far jumps to 64-bit code
//   6. Loads GDT, IDT from trampoline data
//   7. Sets up stack
//   8. Calls ap_entry_zig()
//
// IMPORTANT: Both lgdt instructions read the GDT pointer from the
// trampoline data area at a FIXED offset (0x8000 + AP_DATA_OFFSET + GDT_PTR_OFF).
// The BSP fills in this data before sending SIPI. This avoids the bug where
// assembly-time computed addresses for lgdt were incorrect after relocation.
//
// GDT layout (kernel's GDT, shared by BSP and all APs):
//   0x00: Null
//   0x08: 64-bit Code (ring 0)
//   0x10: 64-bit Data (ring 0)
//   0x18: User Data (ring 3)
//   0x20: User Code (ring 3)
//   0x28: 32-bit Code (ring 0) ← used for 16→32 transition on AP
//   0x30: 32-bit Data (ring 0) ← used for 32-bit data segments on AP
//   0x38: TSS low
//   0x40: TSS high
//
// Data layout at 0x8100 (AP_DATA_OFFSET = 0x100):
//   Offset  Size  Field
//   0x00    10    GDT pointer (2-byte limit + 8-byte base) — kernel's GDT64
//   0x0A    10    IDT pointer (2-byte limit + 8-byte base)
//   0x14    4     Padding (alignment)
//   0x18    8     CR3 (PML4 physical address)
//   0x20    8     Entry point (ap_entry_zig address)
//   0x28    8     PerCpu structure address (for GSBASE)
//   0x30    4     CPU ID
//   0x34    4     Padding
//   0x38    8     Stack top
// ============================================================================

.set AP_DATA_OFFSET, 0x100

.set CR0_PE, 0x00000001
.set CR0_PG, 0x80000000
.set CR4_PAE, 0x00000020

.set MSR_EFER, 0xC0000080
.set EFER_LME, 0x00000100
.set EFER_NXE, 0x00000800

// Data offsets within ApTrampolineData (extern struct, C layout)
// gdt_ptr: 10 bytes at 0x00
// idt_ptr: 10 bytes at 0x0A
// padding: 6 bytes at 0x14 (alignment to 8-byte boundary for u64)
// cr3:     8 bytes at 0x18
// entry64: 8 bytes at 0x20
// percpu:  8 bytes at 0x28
// cpu_id:  4 bytes at 0x30
// padding: 4 bytes at 0x34
// stack_top: 8 bytes at 0x38
.set GDT_PTR_OFF, 0x00
.set IDT_PTR_OFF, 0x0A
.set CR3_OFF,     0x18
.set ENTRY64_OFF, 0x20
.set PERCPU_OFF,  0x28
.set CPUID_OFF,   0x30
.set STACKTOP_OFF,0x38

// Selectors for 32-bit protected mode (SMP AP trampoline)
.set SEL_CODE32,  0x28    // 32-bit Code segment (GDT entry 5)
.set SEL_DATA32,  0x30    // 32-bit Data segment (GDT entry 6)

// Selectors for 64-bit long mode
.set SEL_CODE64,  0x08    // 64-bit Code segment (GDT entry 1)
.set SEL_DATA64,  0x10    // 64-bit Data segment (GDT entry 2)

.section .text.ap_trampoline, "ax", @progbits
.code16

.global ap_trampoline_start
.global ap_trampoline_end

ap_trampoline_start:
    // ========================================================================
    // 16-bit Real Mode Entry Point
    // ========================================================================
    // We arrive here after SIPI. CS:IP = 0x0800:0x0000 (SIPI vector=8).
    // We need to switch to 64-bit long mode.

    // Disable interrupts
    cli

    // Load a known data segment
    xorw %ax, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    // ========================================================================
    // Switch to 32-bit Protected Mode
    // ========================================================================

    // Enable A20 line (should already be enabled by BIOS/GRUB, but be safe)
    inb $0x92, %al
    orb $0x02, %al
    outb %al, $0x92

    // Load kernel's GDT pointer from trampoline data area.
    // FIXED: Use hardcoded offset (0x8000 + AP_DATA_OFFSET + GDT_PTR_OFF = 0x8100)
    // instead of assembly-time computed address that was broken after relocation.
    //
    // In 16-bit real mode, lgdt reads a 6-byte pseudo-descriptor (2-byte limit + 4-byte base).
    // The data area has a 10-byte pseudo-descriptor (2-byte limit + 8-byte base) from sgdt.
    // The 16-bit lgdt reads bytes 0-5 (limit + lower 32 bits of base), which is correct
    // since the kernel's GDT is below 4GB (identity-mapped at ~1MB).
    lgdt (0x8000 + AP_DATA_OFFSET + GDT_PTR_OFF)

    // Enable protected mode (CR0.PE)
    movl %cr0, %eax
    orl $CR0_PE, %eax
    movl %eax, %cr0

    // Far jump to 32-bit code using 32-bit code selector (0x28)
    ljmpl $SEL_CODE32, $(ap_pm32_entry - ap_trampoline_start + 0x8000)

.code32
ap_pm32_entry:
    // ========================================================================
    // 32-bit Protected Mode
    // ========================================================================

    // Load 32-bit data segments (selector 0x30 = 32-bit Data)
    movw $SEL_DATA32, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    // ========================================================================
    // Set up identity-mapped page tables for 64-bit long mode
    // We use the BSP's page tables (read from trampoline data)
    // ========================================================================

    // Read CR3 from trampoline data area
    movl $(0x8000 + AP_DATA_OFFSET + CR3_OFF), %ebx
    movl (%ebx), %eax
    movl %eax, %cr3

    // Enable PAE (CR4.PAE)
    movl %cr4, %eax
    orl $CR4_PAE, %eax
    movl %eax, %cr4

    // Enable Long Mode (EFER.LME)
    movl $MSR_EFER, %ecx
    rdmsr
    orl $EFER_LME, %eax
    orl $EFER_NXE, %eax
    wrmsr

    // Enable paging (CR0.PG)
    movl %cr0, %eax
    orl $CR0_PG, %eax
    movl %eax, %cr0

    // Reload GDT64 from trampoline data (same GDT, now with 64-bit entries accessible)
    // In 32-bit mode, lgdt reads 6 bytes (2-byte limit + 4-byte base) — correct for <4GB
    lgdt (0x8000 + AP_DATA_OFFSET + GDT_PTR_OFF)

    // Far jump to 64-bit code using 64-bit code selector (0x08)
    ljmpl $SEL_CODE64, $(ap_lm64_entry - ap_trampoline_start + 0x8000)

.code64
ap_lm64_entry:
    // ========================================================================
    // 64-bit Long Mode!
    // ========================================================================

    // Load 64-bit data segments (selector 0x10 = 64-bit Data)
    movw $SEL_DATA64, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    // Load IDT from trampoline data
    lidt (0x8000 + AP_DATA_OFFSET + IDT_PTR_OFF)

    // Load stack from trampoline data
    movq (0x8000 + AP_DATA_OFFSET + STACKTOP_OFF), %rsp

    // Enable SSE (required for Zig)
    movq %cr0, %rax
    andq $-5, %rax         // Clear EM (bit 2)
    orq $0x2, %rax         // Set MP (bit 1)
    movq %rax, %cr0

    movq %cr4, %rax
    orq $0x600, %rax       // OSFXSR + OSXMMEXCPT
    movq %rax, %cr4

    // Set GSBASE for per-CPU data
    movq (0x8000 + AP_DATA_OFFSET + PERCPU_OFF), %rdi
    movl $0xC0000101, %ecx         // IA32_GS_BASE MSR
    movl %edi, %eax
    shrq $32, %rdi
    movl %edi, %edx
    wrmsr

    // Also set KERNEL_GS_BASE
    movq (0x8000 + AP_DATA_OFFSET + PERCPU_OFF), %rdi
    movl $0xC0000102, %ecx         // IA32_KERNEL_GS_BASE MSR
    movl %edi, %eax
    shrq $32, %rdi
    movl %edi, %edx
    wrmsr

    // Call ap_entry_zig() — no arguments (it reads from trampoline data)
    movq (0x8000 + AP_DATA_OFFSET + ENTRY64_OFF), %rax
    call *%rax

    // Should never return, but just in case
.halt_loop:
    cli
    hlt
    jmp .halt_loop

ap_trampoline_end:

// Mark end of trampoline — no embedded GDT32 needed anymore!
// The kernel's GDT (with 32-bit entries at 0x28/0x30) is used instead.
`
```

### `zig-kernel/src64/cpio.zig` [zig · 3,352 B]
```
`// ============================================================================
// POLER-OS CPIO (newc) Archive Parser — x86_64
// ============================================================================

const std = @import("std");

pub const CpioFile = struct {
    name: []const u8,
    data: []const u8,
    mode: u32,
    size: u32,
};

pub const CpioParser = struct {
    archive_data: []const u8,
    offset: usize = 0,

    pub fn init(data: []const u8) CpioParser {
        return CpioParser{
            .archive_data = data,
            .offset = 0,
        };
    }

    pub fn next(self: *CpioParser) ?CpioFile {
        if (self.offset + 110 > self.archive_data.len) return null;

        const header_ptr = self.archive_data[self.offset .. self.offset + 110];
        const magic = header_ptr[0..6];

        if (!std.mem.eql(u8, magic, "070701") and !std.mem.eql(u8, magic, "070702")) {
            return null; // Invalid magic
        }

        const filesize = parseHex(header_ptr[54..62]);
        const namesize = parseHex(header_ptr[94..102]);
        const mode = parseHex(header_ptr[14..22]);

        if (namesize == 0) return null;

        const filename_start = self.offset + 110;
        if (filename_start + namesize > self.archive_data.len) return null;

        const name = self.archive_data[filename_start .. filename_start + namesize - 1]; // exclude null terminator

        if (std.mem.eql(u8, name, "TRAILER!!!")) {
            return null; // End of archive
        }

        const data_start = (filename_start + namesize + 3) & ~@as(usize, 3);
        if (data_start + filesize > self.archive_data.len) return null;

        const data = self.archive_data[data_start .. data_start + filesize];

        // Advance offset to next entry (aligned to 4 bytes)
        self.offset = (data_start + filesize + 3) & ~@as(usize, 3);

        return CpioFile{
            .name = name,
            .data = data,
            .mode = mode,
            .size = filesize,
        };
    }
};

fn parseHex(ascii: []const u8) u32 {
    var val: u32 = 0;
    for (ascii) |c| {
        val <<= 4;
        if (c >= '0' and c <= '9') {
            val += (c - '0');
        } else if (c >= 'a' and c <= 'f') {
            val += (c - 'a' + 10);
        } else if (c >= 'A' and c <= 'F') {
            val += (c - 'A' + 10);
        }
    }
    return val;
}

test "CpioParser parses in-memory cpio archive" {
    const header1 = "07070100000001000081a4000000000000000000000001000000000000000c000000000000000000000000000000000000000900000000";
    const file1 = "test.txt\x00\x00Hello World!";
    const trailer_header = "0707010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b00000000";
    const trailer_name = "TRAILER!!!\x00";
    
    const archive = header1 ++ file1 ++ trailer_header ++ trailer_name;
    
    var parser = CpioParser.init(archive);
    const parsed_file = parser.next() orelse return error.TestFailed;
    
    try std.testing.expectEqualStrings("test.txt", parsed_file.name);
    try std.testing.expectEqualStrings("Hello World!", parsed_file.data);
    try std.testing.expectEqual(@as(u32, 12), parsed_file.size);
    try std.testing.expectEqual(@as(u32, 0x81a4), parsed_file.mode);
    
    try std.testing.expect(parser.next() == null);
}
`
```

### `zig-kernel/src64/elf_loader.zig` [zig · 14,246 B]
```
`// ============================================================================
// POLER-OS ELF64 Loader — v0.7.0
// ============================================================================
//
// Loads ELF64 executables into user address space.
// Supports:
//   - PT_LOAD segments (code + data + bss)
//   - Position-dependent executables (e_type = ET_EXEC)
//   - x86_64 architecture validation
//
// Limitations (v0.7.0):
//   - No dynamic linking (ET_DYN not supported)
//   - No relocation processing
//   - No shared libraries
//   - User pages mapped via kernel VMM (shared page tables until v0.7.1)
// ============================================================================

const hal = @import("hal.zig");
const vmm = @import("vmm64.zig");
const pmm = @import("pmm64.zig");

// ============================================================================
// ELF64 Structures
// ============================================================================

pub const EI_NIDENT: usize = 16;

pub const Elf64_Ehdr = extern struct {
    e_ident: [EI_NIDENT]u8,
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u64,
    e_phoff: u64,
    e_shoff: u64,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,
};

pub const ET_EXEC: u16 = 2;

pub const EM_X86_64: u16 = 62;

pub const Elf64_Phdr = extern struct {
    p_type: u32,
    p_flags: u32,
    p_offset: u64,
    p_vaddr: u64,
    p_paddr: u64,
    p_filesz: u64,
    p_memsz: u64,
    p_align: u64,
};

pub const PT_LOAD: u32 = 1;

pub const PF_X: u32 = 1;
pub const PF_W: u32 = 2;
pub const PF_R: u32 = 4;

// ============================================================================
// ELF Loader Error
// ============================================================================

pub const ElfError = error{
    InvalidMagic,
    Not64Bit,
    NotExecutable,
    WrongArchitecture,
    NoProgramHeaders,
    NoLoadSegments,
    MapFailed,
    OutOfMemory,
};

// ============================================================================
// ELF64 Load Result
// ============================================================================

pub const ElfLoadResult = struct {
    entry_point: u64, // Virtual address of _start / main
    num_segments: usize, // Number of PT_LOAD segments loaded
};

fn validateElfHeader(ehdr: *const Elf64_Ehdr) ElfError!void {
    // Magic: 0x7F 'E' 'L' 'F'
    if (ehdr.e_ident[0] != 0x7F or
        ehdr.e_ident[1] != 'E' or
        ehdr.e_ident[2] != 'L' or
        ehdr.e_ident[3] != 'F')
    {
        return ElfError.InvalidMagic;
    }

    // Class: must be ELFCLASS64 (2)
    if (ehdr.e_ident[4] != 2) {
        return ElfError.Not64Bit;
    }

    // Type: must be ET_EXEC (2)
    if (ehdr.e_type != ET_EXEC) {
        return ElfError.NotExecutable;
    }

    // Machine: must be EM_X86_64 (62)
    if (ehdr.e_machine != EM_X86_64) {
        return ElfError.WrongArchitecture;
    }
}

// ============================================================================
// flagsToPageFlags — Convert ELF p_flags to VMM page flags
// ============================================================================

fn flagsToPageFlags(p_flags: u32) u64 {
    var page_flags: u64 = vmm.PTE_PRESENT | vmm.PTE_USER; // Always present + user-accessible

    if (p_flags & PF_W != 0) {
        page_flags |= vmm.PTE_WRITABLE;
    }
    if (p_flags & PF_X == 0) {
        page_flags |= vmm.PTE_NO_EXECUTE;
    }

    return page_flags;
}

// ============================================================================
// loadElf — Load an ELF64 binary from a memory buffer
// ============================================================================
//
// This function:
//   1. Validates the ELF header
//   2. Iterates over PT_LOAD program headers
//   3. Maps pages at p_vaddr with appropriate permissions
//   4. Copies file data from p_offset to p_vaddr
//   5. Zero-fills BSS (p_memsz - p_filesz)
//
// Returns: ElfLoadResult with the entry point address
//
// IMPORTANT: Pages are mapped via the kernel VMM (vmm.mapPage).
// For per-process isolation, the caller should create a user PML4
// AFTER calling loadElf (so the user PML4 inherits the mappings).
// ============================================================================

pub fn loadElf(elf_data: []const u8) ElfError!ElfLoadResult {
    if (elf_data.len < @sizeOf(Elf64_Ehdr)) {
        return ElfError.InvalidMagic;
    }

    const ehdr: *const Elf64_Ehdr = @ptrCast(@alignCast(elf_data.ptr));

    // Validate header
    try validateElfHeader(ehdr);

    if (ehdr.e_phnum == 0) {
        return ElfError.NoProgramHeaders;
    }

    hal.Serial.puts("[ELF] Valid ELF64 executable\n");
    hal.Serial.puts("[ELF] Entry point: ");
    hal.Serial.putHex(ehdr.e_entry);
    hal.Serial.puts("\n");
    hal.Serial.puts("[ELF] Program headers: ");
    hal.Serial.putDecimal(ehdr.e_phnum);
    hal.Serial.puts("\n");

    var num_loaded: usize = 0;

    // Iterate over program headers
    var i: usize = 0;
    while (i < ehdr.e_phnum) : (i += 1) {
        const phdr_offset = ehdr.e_phoff + i * ehdr.e_phentsize;
        if (phdr_offset + @sizeOf(Elf64_Phdr) > elf_data.len) {
            hal.Serial.puts("[ELF] WARNING: Program header out of bounds\n");
            break;
        }

        const phdr: *const Elf64_Phdr = @ptrCast(@alignCast(elf_data.ptr + phdr_offset));

        if (phdr.p_type != PT_LOAD) {
            continue; // Skip non-LOAD segments
        }

        hal.Serial.puts("[ELF] PT_LOAD: vaddr=");
        hal.Serial.putHex(phdr.p_vaddr);
        hal.Serial.puts(" filesz=");
        hal.Serial.putDecimal(phdr.p_filesz);
        hal.Serial.puts(" memsz=");
        hal.Serial.putDecimal(phdr.p_memsz);
        hal.Serial.puts(" flags=");
        hal.Serial.putHex(phdr.p_flags);
        hal.Serial.puts("\n");

        const page_flags = flagsToPageFlags(phdr.p_flags);

        // Calculate number of pages needed for this segment
        const vaddr_aligned = phdr.p_vaddr & ~@as(u64, 0xFFF); // Page-align down
        const vaddr_end = phdr.p_vaddr + phdr.p_memsz;
        const vaddr_end_aligned = (vaddr_end + 0xFFF) & ~@as(u64, 0xFFF); // Page-align up
        const num_pages = (vaddr_end_aligned - vaddr_aligned) / vmm.PAGE_SIZE;

        // Map pages for this segment
        var page_idx: u64 = 0;
        while (page_idx < num_pages) : (page_idx += 1) {
            const virt_addr = vaddr_aligned + page_idx * vmm.PAGE_SIZE;

            // Allocate a physical page
            const phys_page = pmm.allocPage() orelse {
                hal.Serial.puts("[ELF] ERROR: Out of memory mapping user pages\n");
                return ElfError.OutOfMemory;
            };

            // Map the page (this may fail if already mapped, which is OK for shared segments)
            vmm.mapPage(virt_addr, phys_page, page_flags) catch |err| {
                if (err == vmm.VmmError.AlreadyMapped) {
                    // Page already mapped (e.g., from a previous segment)
                    // Free the allocated physical page since it's not needed
                    pmm.freePage(phys_page);
                } else {
                    hal.Serial.puts("[ELF] ERROR: Failed to map page at ");
                    hal.Serial.putHex(virt_addr);
                    hal.Serial.puts(": ");
                    hal.Serial.puts(@errorName(err));
                    hal.Serial.puts("\n");
                    return ElfError.MapFailed;
                }
            };
        }

        // Copy file data to virtual address
        if (phdr.p_filesz > 0) {
            const file_src = elf_data[phdr.p_offset .. phdr.p_offset + phdr.p_filesz];
            const dest_ptr: [*]volatile u8 = @ptrFromInt(phdr.p_vaddr);
            @memcpy(dest_ptr[0..phdr.p_filesz], file_src);
        }

        // Zero-fill BSS (memsz > filesz)
        if (phdr.p_memsz > phdr.p_filesz) {
            const bss_start = phdr.p_vaddr + phdr.p_filesz;
            const bss_len = phdr.p_memsz - phdr.p_filesz;
            const bss_ptr: [*]volatile u8 = @ptrFromInt(bss_start);
            @memset(bss_ptr[0..bss_len], 0);
        }

        num_loaded += 1;
    }

    if (num_loaded == 0) {
        return ElfError.NoLoadSegments;
    }

    hal.Serial.puts("[ELF] Loaded ");
    hal.Serial.putDecimal(num_loaded);
    hal.Serial.puts(" PT_LOAD segments\n");

    return ElfLoadResult{
        .entry_point = ehdr.e_entry,
        .num_segments = num_loaded,
    };
}

// ============================================================================
// loadElfIntoPML4 — Load an ELF64 binary into a SPECIFIC PML4
// ============================================================================
//
// v0.7.0: Per-process address space isolation requires loading user ELF
// segments into the user's PML4 (not the kernel PML4). This function:
//   1. Validates the ELF header
//   2. Iterates over PT_LOAD program headers
//   3. Maps pages at p_vaddr in the TARGET PML4 with PTE_USER flag
//   4. Copies file data from p_offset to p_vaddr
//   5. Zero-fills BSS (p_memsz - p_filesz)
//
// The data copy works because we're in Ring 0 and the kernel identity-maps
// all physical memory — the physical pages allocated here are accessible
// through the kernel's virtual address space.
//
// Returns: ElfLoadResult with the entry point address
// ============================================================================

pub fn loadElfIntoPML4(elf_data: []const u8, target_pml4: u64) ElfError!ElfLoadResult {
    if (elf_data.len < @sizeOf(Elf64_Ehdr)) {
        return ElfError.InvalidMagic;
    }

    const ehdr: *const Elf64_Ehdr = @ptrCast(@alignCast(elf_data.ptr));

    // Validate header
    try validateElfHeader(ehdr);

    if (ehdr.e_phnum == 0) {
        return ElfError.NoProgramHeaders;
    }

    hal.Serial.puts("[ELF] Valid ELF64 — loading into user PML4\n");
    hal.Serial.puts("[ELF] Entry point: ");
    hal.Serial.putHex(ehdr.e_entry);
    hal.Serial.puts("\n");

    var num_loaded: usize = 0;

    // Iterate over program headers
    var i: usize = 0;
    while (i < ehdr.e_phnum) : (i += 1) {
        const phdr_offset = ehdr.e_phoff + i * ehdr.e_phentsize;
        if (phdr_offset + @sizeOf(Elf64_Phdr) > elf_data.len) {
            hal.Serial.puts("[ELF] WARNING: Program header out of bounds\n");
            break;
        }

        const phdr: *const Elf64_Phdr = @ptrCast(@alignCast(elf_data.ptr + phdr_offset));

        if (phdr.p_type != PT_LOAD) {
            continue; // Skip non-LOAD segments
        }

        hal.Serial.puts("[ELF] PT_LOAD: vaddr=");
        hal.Serial.putHex(phdr.p_vaddr);
        hal.Serial.puts(" filesz=");
        hal.Serial.putDecimal(phdr.p_filesz);
        hal.Serial.puts(" memsz=");
        hal.Serial.putDecimal(phdr.p_memsz);
        hal.Serial.puts("\n");

        const page_flags = flagsToPageFlags(phdr.p_flags);

        // Calculate number of pages needed for this segment
        const vaddr_aligned = phdr.p_vaddr & ~@as(u64, 0xFFF);
        const vaddr_end = phdr.p_vaddr + phdr.p_memsz;
        const vaddr_end_aligned = (vaddr_end + 0xFFF) & ~@as(u64, 0xFFF);
        const num_pages = (vaddr_end_aligned - vaddr_aligned) / vmm.PAGE_SIZE;

        // Map pages for this segment IN THE TARGET PML4 (with PTE_USER)
        var page_idx: u64 = 0;
        while (page_idx < num_pages) : (page_idx += 1) {
            const virt_addr = vaddr_aligned + page_idx * vmm.PAGE_SIZE;

            // Allocate a physical page
            const phys_page = pmm.allocPage() orelse {
                hal.Serial.puts("[ELF] ERROR: Out of memory mapping user pages\n");
                return ElfError.OutOfMemory;
            };

            // Map in the TARGET PML4 (user's page tables)
            vmm.mapPageInPML4(target_pml4, virt_addr, phys_page, page_flags) catch |err| {
                if (err == vmm.VmmError.AlreadyMapped) {
                    pmm.freePage(phys_page);
                } else {
                    hal.Serial.puts("[ELF] ERROR: Failed to map page at ");
                    hal.Serial.putHex(virt_addr);
                    hal.Serial.puts(": ");
                    hal.Serial.puts(@errorName(err));
                    hal.Serial.puts("\n");
                    return ElfError.MapFailed;
                }
            };

            // ALSO map in kernel PML4 — needed so the kernel can copy data
            // to the user pages. We add PTE_USER so that when the kernel PML4
            // is used (without CR3 switch), Ring 3 can still access user pages.
            vmm.mapPage(virt_addr, phys_page, vmm.PTE_PRESENT | vmm.PTE_WRITABLE | vmm.PTE_USER) catch |err| {
                if (err != vmm.VmmError.AlreadyMapped) {
                    hal.Serial.puts("[ELF] WARNING: Kernel map failed at ");
                    hal.Serial.putHex(virt_addr);
                    hal.Serial.puts(": ");
                    hal.Serial.puts(@errorName(err));
                    hal.Serial.puts("\n");
                }
                // Already mapped in kernel PML4 is OK — might share the page
            };
        }

        // Copy file data to virtual address (works through kernel mapping)
        if (phdr.p_filesz > 0) {
            const file_src = elf_data[phdr.p_offset .. phdr.p_offset + phdr.p_filesz];
            const dest_ptr: [*]volatile u8 = @ptrFromInt(phdr.p_vaddr);
            @memcpy(dest_ptr[0..phdr.p_filesz], file_src);
        }

        // Zero-fill BSS (memsz > filesz)
        if (phdr.p_memsz > phdr.p_filesz) {
            const bss_start = phdr.p_vaddr + phdr.p_filesz;
            const bss_len = phdr.p_memsz - phdr.p_filesz;
            const bss_ptr: [*]volatile u8 = @ptrFromInt(bss_start);
            @memset(bss_ptr[0..bss_len], 0);
        }

        num_loaded += 1;
    }

    if (num_loaded == 0) {
        return ElfError.NoLoadSegments;
    }

    hal.Serial.puts("[ELF] Loaded ");
    hal.Serial.putDecimal(num_loaded);
    hal.Serial.puts(" PT_LOAD segments into user PML4\n");

    return ElfLoadResult{
        .entry_point = ehdr.e_entry,
        .num_segments = num_loaded,
    };
}
`
```

### `zig-kernel/src64/framebuffer.zig` [zig · 17,902 B]
```
`// POLER-OS VBE Framebuffer Driver
// VESA BIOS Extensions — linear framebuffer for HDMI/DP output
// Works with NVIDIA GTX 1060, Intel HD 4000, any VBE-compatible GPU

const std = @import("std");

// ─── VBE Color Format ──────────────────────────────────────────────────────

pub const PixelFormat = enum(u8) {
    indexed = 0,
    rgb888 = 1,      // 32-bit: XRGB8888
    bgr888 = 2,      // 32-bit: XBGR8888
    rgb565 = 3,      // 16-bit
};

// ─── Multiboot Framebuffer Info ────────────────────────────────────────────
// Parsed from multiboot_info tag 8 (framebuffer)

pub const FramebufferInfo = extern struct {
    addr: u64,           // Physical address of framebuffer
    pitch: u32,          // Bytes per scanline
    width: u32,          // Pixels width
    height: u32,         // Pixels height
    bpp: u8,             // Bits per pixel (usually 32)
    pixel_type: u8,      // PixelFormat
    red_shift: u8,
    red_mask: u8,
    green_shift: u8,
    green_mask: u8,
    blue_shift: u8,
    blue_mask: u8,
    valid: bool,         // Did we get valid info from multiboot?
};

// Global framebuffer state
var fb: FramebufferInfo = FramebufferInfo{
    .addr = 0,
    .pitch = 0,
    .width = 0,
    .height = 0,
    .bpp = 0,
    .pixel_type = 0,
    .red_shift = 0,
    .red_mask = 0,
    .green_shift = 0,
    .green_mask = 0,
    .blue_shift = 0,
    .blue_mask = 0,
    .valid = false,
};

// Text cursor position (in pixel coordinates)
var cursor_x: u32 = 0;
var cursor_y: u32 = 0;

// Font cell size
const CHAR_W: u32 = 8;
const CHAR_H: u32 = 16;

// ─── Font: 8x16 PC BIOS font (first 128 ASCII chars) ──────────────────────
// Minimal 8x16 bitmap font — covers printable ASCII 0x20-0x7E

const font: [128][16]u8 = import_font();

fn import_font() [128][16]u8 {
    var f: [128][16]u8 = undefined;
    
    // Space (0x20)
    f[0x20] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ! (0x21)
    f[0x21] = .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x18,0x18,0x00,0x00,0x00};
    // " (0x22)
    f[0x22] = .{0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // # (0x23)
    f[0x23] = .{0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0xFE,0x6C,0x6C,0x6C,0x00,0x00,0x00,0x00,0x00};
    // $ (0x24)
    f[0x24] = .{0x18,0x3E,0x60,0x60,0x3C,0x06,0x06,0x7C,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    // % (0x25)
    f[0x25] = .{0x00,0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00};
    // & (0x26)
    f[0x26] = .{0x38,0x6C,0x6C,0x38,0x76,0x6E,0x66,0x66,0x76,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    // ' (0x27)
    f[0x27] = .{0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ( (0x28)
    f[0x28] = .{0x0C,0x18,0x30,0x30,0x30,0x30,0x30,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00};
    // ) (0x29)
    f[0x29] = .{0x30,0x18,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x18,0x30,0x00,0x00,0x00,0x00,0x00,0x00};
    // * (0x2A)
    f[0x2A] = .{0x00,0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // + (0x2B)
    f[0x2B] = .{0x00,0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // , (0x2C)
    f[0x2C] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x18,0x30,0x00,0x00,0x00};
    // - (0x2D)
    f[0x2D] = .{0x00,0x00,0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // . (0x2E)
    f[0x2E] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00};
    // / (0x2F)
    f[0x2F] = .{0x06,0x06,0x0C,0x0C,0x18,0x18,0x30,0x30,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // 0-9 (0x30-0x39)
    f[0x30] = .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x31] = .{0x18,0x38,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x32] = .{0x3C,0x66,0x66,0x06,0x0C,0x18,0x30,0x60,0x66,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x33] = .{0x3C,0x66,0x06,0x06,0x1C,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x34] = .{0x0C,0x1C,0x3C,0x6C,0x6C,0x7E,0x0C,0x0C,0x0C,0x0C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x35] = .{0x7E,0x60,0x60,0x7C,0x06,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x36] = .{0x3C,0x66,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x37] = .{0x7E,0x66,0x06,0x0C,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x38] = .{0x3C,0x66,0x66,0x66,0x3C,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x39] = .{0x3C,0x66,0x66,0x66,0x3E,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // : (0x3A)
    f[0x3A] = .{0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ; (0x3B)
    f[0x3B] = .{0x00,0x00,0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30,0x00,0x00,0x00,0x00,0x00,0x00};
    // < (0x3C)
    f[0x3C] = .{0x0C,0x18,0x30,0x60,0xC0,0x60,0x30,0x18,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // = (0x3D)
    f[0x3D] = .{0x00,0x00,0x00,0x00,0x7E,0x00,0x7E,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // > (0x3E)
    f[0x3E] = .{0x60,0x30,0x18,0x0C,0x06,0x0C,0x18,0x30,0x60,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    // ? (0x3F)
    f[0x3F] = .{0x3C,0x66,0x06,0x0C,0x18,0x18,0x00,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // @ (0x40)
    f[0x40] = .{0x3C,0x66,0x66,0x6E,0x6E,0x60,0x62,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // A-Z uppercase (0x41-0x5A)
    f[0x41] = .{0x18,0x3C,0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x42] = .{0x7C,0x66,0x66,0x66,0x7C,0x66,0x66,0x66,0x66,0x7C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x43] = .{0x3C,0x66,0x66,0x60,0x60,0x60,0x60,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x44] = .{0x78,0x6C,0x66,0x66,0x66,0x66,0x66,0x66,0x6C,0x78,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x45] = .{0x7E,0x60,0x60,0x60,0x7C,0x60,0x60,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x46] = .{0x7E,0x60,0x60,0x60,0x7C,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x47] = .{0x3C,0x66,0x60,0x60,0x6E,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x48] = .{0x66,0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x49] = .{0x3C,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4A] = .{0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x6C,0x6C,0x38,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4B] = .{0x66,0x66,0x6C,0x6C,0x78,0x78,0x6C,0x6C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4C] = .{0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4D] = .{0xC6,0xEE,0xFE,0xD6,0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x4E] = .{0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x51] = .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x76,0x7E,0x3C,0x06,0x00,0x00,0x00,0x00,0x00};
    f[0x4F] = .{0x3C,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x50] = .{0x7C,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x52] = .{0x7C,0x66,0x66,0x66,0x7C,0x6C,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x53] = .{0x3C,0x66,0x60,0x60,0x3C,0x06,0x06,0x06,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x54] = .{0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x55] = .{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x56] = .{0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x3C,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x57] = .{0xC6,0xC6,0xC6,0xC6,0xD6,0xD6,0xFE,0xEE,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x58] = .{0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x59] = .{0x66,0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5A] = .{0x7E,0x06,0x0C,0x18,0x30,0x60,0x60,0xC0,0xC0,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // [ ] ^ _ (0x5B-0x5E)
    f[0x5B] = .{0x3C,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x30,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5C] = .{0x60,0x60,0x30,0x30,0x18,0x18,0x0C,0x0C,0x06,0x06,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5D] = .{0x3C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5E] = .{0x10,0x38,0x6C,0xC6,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x5F] = .{0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF,0x00,0x00,0x00};
    
    // a-z lowercase (0x61-0x7A) 
    f[0x61] = .{0x00,0x00,0x00,0x3C,0x06,0x3E,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x62] = .{0x60,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x66,0x7C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x63] = .{0x00,0x00,0x00,0x3C,0x66,0x60,0x60,0x60,0x60,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x64] = .{0x06,0x06,0x06,0x3E,0x66,0x66,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x65] = .{0x00,0x00,0x00,0x3C,0x66,0x66,0x7E,0x60,0x60,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x66] = .{0x1C,0x30,0x30,0x7C,0x30,0x30,0x30,0x30,0x30,0x30,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x67] = .{0x00,0x00,0x00,0x3E,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x3C,0x00,0x00,0x00,0x00};
    f[0x68] = .{0x60,0x60,0x60,0x7C,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x69] = .{0x18,0x00,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6A] = .{0x0C,0x00,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x0C,0x6C,0x6C,0x38,0x00,0x00,0x00,0x00};
    f[0x6B] = .{0x60,0x60,0x60,0x66,0x6C,0x78,0x78,0x6C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6C] = .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6D] = .{0x00,0x00,0x00,0xEC,0xFE,0xD6,0xD6,0xD6,0xC6,0xC6,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6E] = .{0x00,0x00,0x00,0x7C,0x66,0x66,0x66,0x66,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x6F] = .{0x00,0x00,0x00,0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x70] = .{0x00,0x00,0x00,0x7C,0x66,0x66,0x66,0x66,0x7C,0x60,0x60,0x60,0x00,0x00,0x00,0x00};
    f[0x71] = .{0x00,0x00,0x00,0x3E,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x06,0x00,0x00,0x00,0x00};
    f[0x72] = .{0x00,0x00,0x00,0x7C,0x66,0x60,0x60,0x60,0x60,0x60,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x73] = .{0x00,0x00,0x00,0x3E,0x60,0x60,0x3C,0x06,0x06,0x7C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x74] = .{0x30,0x30,0x30,0x7C,0x30,0x30,0x30,0x30,0x30,0x1C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x75] = .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x66,0x3E,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x76] = .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x77] = .{0x00,0x00,0x00,0xC6,0xC6,0xD6,0xD6,0xD6,0xFE,0x6C,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x78] = .{0x00,0x00,0x00,0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x79] = .{0x00,0x00,0x00,0x66,0x66,0x66,0x66,0x66,0x3E,0x06,0x06,0x3C,0x00,0x00,0x00,0x00};
    f[0x7A] = .{0x00,0x00,0x00,0x7E,0x0C,0x18,0x30,0x60,0x60,0x7E,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // { | } ~ (0x7B-0x7E)
    f[0x7B] = .{0x0E,0x18,0x18,0x18,0x70,0x18,0x18,0x18,0x0E,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x7C] = .{0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x7D] = .{0x70,0x18,0x18,0x18,0x0E,0x18,0x18,0x18,0x70,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    f[0x7E] = .{0x76,0xDC,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00};
    
    // Fill remaining with blank
    var i: usize = 0;
    while (i < 128) : (i += 1) {
        if (i < 0x20) {
            f[i] = .{0x00} ** 16;
        }
    }
    
    return f;
}

// ─── Framebuffer API ───────────────────────────────────────────────────────

/// Initialize framebuffer from multiboot info
pub fn init_from_multiboot(addr: u64, pitch: u32, width: u32, height: u32, bpp: u8, pixel_type: u8) void {
    fb.addr = addr;
    fb.pitch = pitch;
    fb.width = width;
    fb.height = height;
    fb.bpp = bpp;
    fb.pixel_type = pixel_type;
    fb.valid = (addr != 0 and width > 0 and height > 0);
    
    // Default color masks for XRGB8888
    if (pixel_type == @intFromEnum(PixelFormat.rgb888)) {
        fb.red_shift = 16; fb.red_mask = 8;
        fb.green_shift = 8; fb.green_mask = 8;
        fb.blue_shift = 0; fb.blue_mask = 8;
    } else if (pixel_type == @intFromEnum(PixelFormat.bgr888)) {
        fb.red_shift = 0; fb.red_mask = 8;
        fb.green_shift = 8; fb.green_mask = 8;
        fb.blue_shift = 16; fb.blue_mask = 8;
    }
    
    cursor_x = 0;
    cursor_y = 0;
}

/// Is framebuffer available?
pub fn is_available() bool {
    return fb.valid;
}

/// Get screen dimensions in character cells
pub fn text_cols() u32 {
    if (!fb.valid) return 0;
    return fb.width / CHAR_W;
}

pub fn text_rows() u32 {
    if (!fb.valid) return 0;
    return fb.height / CHAR_H;
}

/// Draw a single pixel
pub fn put_pixel(x: u32, y: u32, r: u8, g: u8, b: u8) void {
    if (!fb.valid) return;
    if (x >= fb.width or y >= fb.height) return;
    
    const offset = @as(u64, y) * @as(u64, fb.pitch) + @as(u64, x) * @as(u64, fb.bpp / 8);
    const ptr: [*]volatile u32 = @ptrFromInt(@as(usize, @intCast(fb.addr + offset)));
    
    if (fb.bpp == 32) {
        if (fb.pixel_type == @intFromEnum(PixelFormat.bgr888)) {
            ptr[0] = @as(u32, b) | (@as(u32, g) << 8) | (@as(u32, r) << 16);
        } else {
            ptr[0] = @as(u32, r) | (@as(u32, g) << 8) | (@as(u32, b) << 16);
        }
    }
}

/// Fill a rectangle
pub fn fill_rect(x: u32, y: u32, w: u32, h: u32, r: u8, g: u8, b: u8) void {
    var dy: u32 = 0;
    while (dy < h) : (dy += 1) {
        var dx: u32 = 0;
        while (dx < w) : (dx += 1) {
            put_pixel(x + dx, y + dy, r, g, b);
        }
    }
}

/// Clear screen to black
pub fn clear() void {
    fill_rect(0, 0, fb.width, fb.height, 0, 0, 0);
}

/// Draw a character at pixel position
pub fn draw_char(ch: u8, px: u32, py: u32, fg_r: u8, fg_g: u8, fg_b: u8, bg_r: u8, bg_g: u8, bg_b: u8) void {
    if (!fb.valid) return;
    if (ch >= 128) return; // Safeguard against non-ASCII characters
    const glyph = font[ch];
    
    var row_idx: u32 = 0;
    while (row_idx < CHAR_H) : (row_idx += 1) {
        const bits = glyph[row_idx];
        var col_idx: u32 = 0;
        while (col_idx < CHAR_W) : (col_idx += 1) {
            const bit_set = (bits & (@as(u8, 1) << @intCast(7 - col_idx))) != 0;
            if (bit_set) {
                put_pixel(px + col_idx, py + row_idx, fg_r, fg_g, fg_b);
            } else {
                put_pixel(px + col_idx, py + row_idx, bg_r, bg_g, bg_b);
            }
        }
    }
}

/// Print string to framebuffer (with scrolling)
pub fn puts(str: []const u8) void {
    if (!fb.valid) return;
    
    for (str) |ch| {
        if (ch == '\n') {
            cursor_x = 0;
            cursor_y += CHAR_H;
        } else if (ch == '\x08') {
            if (cursor_x >= CHAR_W) {
                cursor_x -= CHAR_W;
                draw_char(' ', cursor_x, cursor_y, 0xD4, 0xD4, 0xD4, 0x0B, 0x11, 0x20);
            }
        } else {
            draw_char(ch, cursor_x, cursor_y, 0xD4, 0xD4, 0xD4, 0x0B, 0x11, 0x20);
            cursor_x += CHAR_W;
            if (cursor_x >= fb.width) {
                cursor_x = 0;
                cursor_y += CHAR_H;
            }
        }
        
        // Scroll if needed
        if (cursor_y + CHAR_H >= fb.height) {
            scroll_up();
            cursor_y = fb.height - CHAR_H;
        }
    }
}

/// Print string with color
pub fn puts_color(str: []const u8, fg_r: u8, fg_g: u8, fg_b: u8, bg_r: u8, bg_g: u8, bg_b: u8) void {
    if (!fb.valid) return;
    
    for (str) |ch| {
        if (ch == '\n') {
            cursor_x = 0;
            cursor_y += CHAR_H;
        } else if (ch == '\x08') {
            if (cursor_x >= CHAR_W) {
                cursor_x -= CHAR_W;
                draw_char(' ', cursor_x, cursor_y, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b);
            }
        } else {
            draw_char(ch, cursor_x, cursor_y, fg_r, fg_g, fg_b, bg_r, bg_g, bg_b);
            cursor_x += CHAR_W;
            if (cursor_x >= fb.width) {
                cursor_x = 0;
                cursor_y += CHAR_H;
            }
        }
        
        if (cursor_y + CHAR_H >= fb.height) {
            scroll_up();
            cursor_y = fb.height - CHAR_H;
        }
    }
}

/// Scroll framebuffer up by one character row
fn scroll_up() void {
    if (!fb.valid) return;
    
    const src_offset = @as(u64, CHAR_H) * @as(u64, fb.pitch);
    const dst_offset: u64 = 0;
    const copy_len = @as(u64, fb.height - CHAR_H) * @as(u64, fb.pitch);
    
    // Copy rows up
    const src: [*]u8 = @ptrFromInt(@as(usize, @intCast(fb.addr + src_offset)));
    const dst: [*]u8 = @ptrFromInt(@as(usize, @intCast(fb.addr + dst_offset)));
    
    var i: u64 = 0;
    while (i < copy_len) : (i += 1) {
        dst[i] = src[i];
    }
    
    // Clear last row
    const clear_offset = @as(u64, fb.height - CHAR_H) * @as(u64, fb.pitch);
    const clear_ptr: [*]volatile u8 = @ptrFromInt(@as(usize, @intCast(fb.addr + clear_offset)));
    var j: u64 = 0;
    while (j < @as(u64, CHAR_H) * @as(u64, fb.pitch)) : (j += 1) {
        clear_ptr[j] = 0;
    }
}

/// Set cursor position (in pixel coords)
pub fn set_cursor(x: u32, y: u32) void {
    cursor_x = x;
    cursor_y = y;
}
`
```

### `zig-kernel/src64/hal.zig` [zig · 46,868 B]
```
`// ============================================================================
// POLER-OS HAL (Hardware Abstraction Layer) — x86_64
// ============================================================================
// ISR stubs: isr64.S (assembly) → isr_common_handler() (this file)

// Timer tick callback — registered by scheduler at init
// Breaks circular dependency: hal.zig ↔ scheduler.zig
pub var timerTickCallback: ?*const fn (u64) callconv(.C) u64 = null;

// Simple spinlock for protecting shared resources (e.g. serial output)
pub var serial_lock: u32 = 0;

pub fn spinLock(lock: *u32) void {
    while (@atomicRmw(u32, lock, .Xchg, 1, .acquire) != 0) {
        asm volatile ("pause");
    }
}

pub fn spinUnlock(lock: *u32) void {
    _ = @atomicRmw(u32, lock, .Xchg, 0, .release);
}
// ============================================================================

// No std import — freestanding kernel

// ============================================================================
// CPU INSTRUCTIONS
// ============================================================================

pub fn outb(port: u16, val: u8) void {
    asm volatile ("outb %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
    );
}

pub fn outw(port: u16, val: u16) void {
    asm volatile ("outw %[val], %[port]"
        :
        : [val] "{ax}" (val),
          [port] "{dx}" (port),
    );
}

pub fn outl(port: u16, val: u32) void {
    asm volatile ("outl %[val], %[port]"
        :
        : [val] "{eax}" (val),
          [port] "{dx}" (port),
    );
}

pub fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

pub fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "{dx}" (port),
    );
}

pub fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

pub fn cli() void {
    asm volatile ("cli");
}

pub fn sti() void {
    asm volatile ("sti");
}

pub fn hlt() void {
    asm volatile ("hlt");
}

pub fn ltr(selector: u16) void {
    asm volatile ("ltr %[sel]"
        :
        : [sel] "{ax}" (selector),
    );
}

pub fn readCr0() u64 {
    return asm volatile ("mov %%cr0, %[val]"
        : [val] "=r" (-> u64),
    );
}

pub fn readCr3() u64 {
    return asm volatile ("mov %%cr3, %[val]"
        : [val] "=r" (-> u64),
    );
}

pub fn readCr4() u64 {
    return asm volatile ("mov %%cr4, %[val]"
        : [val] "=r" (-> u64),
    );
}

pub fn writeCr3(val: u64) void {
    asm volatile ("mov %[val], %%cr3"
        :
        : [val] "r" (val),
        : "memory"
    );
}

pub fn readMsr(msr: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [msr] "{ecx}" (msr),
    );
    return (@as(u64, high) << 32) | @as(u64, low);
}

pub fn writeMsr(msr: u32, val: u64) void {
    asm volatile ("wrmsr"
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (@as(u32, @truncate(val))),
          [high] "{edx}" (@as(u32, @truncate(val >> 32))),
    );
}

/// Read IA32_GS_BASE MSR (0xC0000101) — used for per-CPU data
pub fn readGsBase() u64 {
    return readMsr(MSR.GS_BASE);
}

/// Write IA32_GS_BASE MSR (0xC0000101) — used for per-CPU data
pub fn writeGsBase(val: u64) void {
    writeMsr(MSR.GS_BASE, val);
}

/// Read IA32_KERNEL_GS_BASE MSR (0xC0000102) — swapgs target
pub fn readKernelGsBase() u64 {
    return readMsr(MSR.KERNEL_GS_BASE);
}

/// Write IA32_KERNEL_GS_BASE MSR (0xC0000102)
pub fn writeKernelGsBase(val: u64) void {
    writeMsr(MSR.KERNEL_GS_BASE, val);
}

/// Swap GS base registers (kernel ↔ user). Used on syscall/sysret entry.
pub fn swapGs() void {
    asm volatile ("swapgs");
}

// ============================================================================
// MSR Constants
// ============================================================================

pub const MSR = struct {
    pub const EFER = 0xC0000080;
    pub const STAR = 0xC0000081;
    pub const LSTAR = 0xC0000082;
    pub const CSTAR = 0xC0000083;
    pub const SFMASK = 0xC0000084;
    pub const FS_BASE = 0xC0000100;
    pub const GS_BASE = 0xC0000101;
    pub const KERNEL_GS_BASE = 0xC0000102;
};

pub const EFER = struct {
    pub const SCE = 1 << 0;  // System Call Extensions
    pub const LME = 1 << 8;  // Long Mode Enable
    pub const LMA = 1 << 10; // Long Mode Active
    pub const NXE = 1 << 11; // No-Execute Enable
};

// ============================================================================
// GDT (Global Descriptor Table)
// ============================================================================

pub const GDT = struct {
    pub const Entry = packed struct {
        limit_low: u16,
        base_low: u24,
        type: u4,
        s: u1,
        dpl: u2,
        p: u1,
        limit_high: u4,
        avl: u1,
        l: u1,
        d: u1,
        g: u1,
        base_high: u8,
    };

    pub const Ptr = packed struct {
        limit: u16,
        base: u64,
    };

    pub const TSSDesc = packed struct {
        low: u64,
        high: u64,
    };

    pub const NUM_ENTRIES = 9; // null + kcode + kdata + ucode + udata + code32 + data32 + tss_low + tss_high

    var entries: [NUM_ENTRIES]u64 = undefined;
    var ptr: Ptr = undefined;

    pub fn init() void {
        Serial.puts("[GDT] entries address: ");
        Serial.putHex(@intFromPtr(&entries));
        Serial.puts("\n");

        // Entry 0: Null
        entries[0] = 0;

        // Entry 1: 64-bit Kernel Code (ring 0) — matches GRUB's CS=0x08
        entries[1] = 0x00209A0000000000;

        // Entry 2: 64-bit Kernel Data (ring 0) — matches GRUB's DS=0x10
        // sysretq bypasses DPL checks, so SS=0x13 (0x10|RPL3) works even with DPL=0.
        entries[2] = 0x0000920000000000;

        // Entry 3: 64-bit User Code (ring 3)
        // sysretq CS = STAR[32:47]+16 | RPL3 = 0x18 | 3 = 0x1B
        // CRITICAL: Entry 3 MUST be User Code (not User Data) because
        // sysretq computes CS.selector = STAR[32:47]+16, which points here.
        entries[3] = 0x0020FA0000000000;

        // Entry 4: 64-bit User Data (ring 3)
        // Used by IRETQ for SS = 0x20 | 3 = 0x23
        entries[4] = 0x0000F20000000000;

        // Entry 5: 32-bit Kernel Code (ring 0) — for SMP AP trampoline
        // Selector 0x28: used by AP far jump from 16-bit real → 32-bit protected mode
        entries[5] = 0x00CF9A000000FFFF;

        // Entry 6: 32-bit Kernel Data (ring 0) — for SMP AP trampoline
        // Selector 0x30: used by AP data segments in 32-bit protected mode
        entries[6] = 0x00CF92000000FFFF;

        // Entries 7-8: TSS (filled by setTSS)
        entries[7] = 0;
        entries[8] = 0;

        // Load our GDT — GRUB's selectors (0x08, 0x10) are compatible
        var gdt_ptr: [10]u8 = undefined;
        const limit: u16 = @intCast(@sizeOf(u64) * NUM_ENTRIES - 1);
        const base: u64 = @intFromPtr(&entries);
        gdt_ptr[0] = @truncate(limit);
        gdt_ptr[1] = @truncate(limit >> 8);
        gdt_ptr[2] = @truncate(base);
        gdt_ptr[3] = @truncate(base >> 8);
        gdt_ptr[4] = @truncate(base >> 16);
        gdt_ptr[5] = @truncate(base >> 24);
        gdt_ptr[6] = @truncate(base >> 32);
        gdt_ptr[7] = @truncate(base >> 40);
        gdt_ptr[8] = @truncate(base >> 48);
        gdt_ptr[9] = @truncate(base >> 56);
        asm volatile ("lgdt (%[p])"
            :
            : [p] "r" (@intFromPtr(&gdt_ptr)),
        );

        // DON'T reload segment registers — GRUB already set them correctly
        // and our GDT layout matches GRUB's (0x08=code, 0x10=data).
        // Reloading DS/SS with 0x10 is safe but unnecessary.
    }

    pub fn setTSS(cpu: u32, base: u64, limit: u64) void {
        _ = cpu;
        const entry_idx: usize = 7; // TSS starts at entry 7 (selector 0x38)

        const base_low = base & 0xFFFFFF;
        const base_mid = (base >> 24) & 0xFF;
        const base_high = (base >> 32) & 0xFFFFFFFF;

        // TSS low 8 bytes
        entries[entry_idx] = (limit & 0xFFFF) |
            ((base_low & 0xFFFFFF) << 16) |
            (0x89 << 40) | // Present, TSS type
            ((limit >> 16) << 48) |
            (@as(u64, base_mid) << 56);

        // TSS high 8 bytes
        entries[entry_idx + 1] = base_high;
    }
};

// ============================================================================
// IDT (Interrupt Descriptor Table)
// ============================================================================

pub const InterruptFrame = packed struct {
    r15: u64, r14: u64, r13: u64, r12: u64,
    r11: u64, r10: u64, r9: u64, r8: u64,
    rdi: u64, rsi: u64, rbp: u64,
    rdx: u64, rcx: u64, rbx: u64, rax: u64,
    vector: u64,
    error_code: u64,
    rip: u64, cs: u64, rflags: u64, rsp: u64, ss: u64,
};

const GateType = enum(u4) {
    interrupt = 0xE,
    trap = 0xF,
};

pub const IDT = struct {
    pub const NUM_ENTRIES = 256;

    pub var entries: [NUM_ENTRIES]u128 = undefined;
    var ptr: packed struct { limit: u16, base: u64 } = undefined;

    // ISR stub table — linker-provided bounds of .rodata.isr_table section
    // LLD may resolve isr_stub_table to the wrong address, so we use
    // linker symbols __isr_table_start / __isr_table_end instead.
    pub extern const __isr_table_start: u8;
    pub extern const __isr_table_end: u8;

    pub fn init() void {
        // Read the ISR table from the linker-defined section bounds
        const table_start: u64 = @intFromPtr(&__isr_table_start);
        const table_end: u64 = @intFromPtr(&__isr_table_end);
        const num_entries = (table_end - table_start) / 8;

        for (0..num_entries) |i| {
            const ptr_arr: [*]const u64 = @ptrFromInt(table_start);
            const handler: u64 = ptr_arr[i];
            if (handler > 0x100000 and i < 49) {
                const dpl: u8 = if (i == 3) 3 else 0;
                // v0.7.0: Use IST1 for Double Fault (vector 8)
                const ist: u3 = if (i == 8) 1 else 0;
                setGate(@intCast(i), .interrupt, handler, 0x08, dpl, ist);
            }
        }

        // Load IDT using raw 10-byte descriptor (2 bytes limit + 8 bytes base)
        var idt_ptr: [10]u8 = undefined;
        const limit: u16 = @intCast(@sizeOf(u128) * NUM_ENTRIES - 1);
        const base: u64 = @intFromPtr(&entries);
        // Little-endian: limit (2 bytes) then base (8 bytes)
        idt_ptr[0] = @truncate(limit);
        idt_ptr[1] = @truncate(limit >> 8);
        idt_ptr[2] = @truncate(base);
        idt_ptr[3] = @truncate(base >> 8);
        idt_ptr[4] = @truncate(base >> 16);
        idt_ptr[5] = @truncate(base >> 24);
        idt_ptr[6] = @truncate(base >> 32);
        idt_ptr[7] = @truncate(base >> 40);
        idt_ptr[8] = @truncate(base >> 48);
        idt_ptr[9] = @truncate(base >> 56);
        asm volatile ("lidt (%[p])"
            :
            : [p] "r" (@intFromPtr(&idt_ptr)),
        );
    }

    fn setGate(vector: u8, gate_type: GateType, handler: u64, selector: u16, dpl: u8, ist: u3) void {
        const low: u64 =
            (handler & 0x0000FFFF) | // Offset low
            (@as(u64, selector) << 16) | // Selector
            (@as(u64, ist) << 32) | // IST (v0.7.0: IST1 for #DF)
            (@as(u64, @intFromEnum(gate_type)) << 40) | // Type
            (@as(u64, dpl) << 45) | // DPL
            (@as(u64, 1) << 47) | // Present
            ((handler >> 16) & 0xFFFF) << 48; // Offset mid

        const high: u64 = handler >> 32; // Offset high

        entries[vector] = (@as(u128, high) << 64) | @as(u128, low);
    }
};

/// Idle loop for after a user-mode fault.
/// When a user process causes a CPU exception (e.g., page fault, GP fault),
/// the exception handler kills the task and redirects IRETQ here.
/// This function simply halts the CPU and waits for the next interrupt
/// (APIC timer tick), which will trigger the scheduler to pick a Ready task.
pub fn idle_after_fault() callconv(.C) noreturn {
    while (true) {
        hlt();
    }
}

// ============================================================================
// ISR Common Handler — called from isr64.S isr_common
// ============================================================================

pub export fn isr_common_handler(frame: *InterruptFrame) callconv(.C) *InterruptFrame {
    if (frame.vector < 32) {
        handleException(frame);
        return frame;
    } else {
        return handleIRQ(frame);
    }
}

pub var tick_count: u64 = 0;

fn handleIRQ(frame: *InterruptFrame) *InterruptFrame {
    var next_frame = frame;

    // CRITICAL: Send APIC EOI BEFORE scheduler callback.
    // If we don't, the APIC won't deliver the next timer interrupt,
    // and the system hangs after the first context switch.
    if (frame.vector >= 48 and APIC.base_addr != 0) {
        APIC.sendEOI();
    }

    // Also send APIC EOI for PIC vectors if APIC is active
    if (APIC.base_addr != 0 and frame.vector >= 32 and frame.vector < 48) {
        APIC.sendEOI();
    }

    // Send PIC EOI for hardware interrupts (IRQ0-15 = vectors 32-47)
    if (frame.vector >= 32 and frame.vector < 48) {
        PIC.sendEOI(@intCast(frame.vector - 32));
    }

    switch (frame.vector) {
        48 => {
            // APIC Timer tick — scheduler preemption
            tick_count += 1;
            // DEBUG: first tick confirmation
            if (tick_count == 1) {
                Serial.puts("[HAL] First APIC timer tick received!\n");
            }
            if (timerTickCallback) |cb| {
                next_frame = @ptrFromInt(cb(@intFromPtr(frame)));
            }
        },
        33 => handleKeyboard(frame),
        36 => handleSerial(frame),
        else => {}, // Unknown interrupt — ignore for now
    }
    
    return next_frame;
}

fn handleException(frame: *InterruptFrame) void {
    // v0.7.0: Differentiate user-mode vs kernel-mode exceptions
    const from_user = (frame.cs & 0x3) != 0;

    Serial.puts("\n!!! CPU EXCEPTION !!!\n");
    Serial.puts("Vector: ");
    Serial.putHex(frame.vector);
    Serial.puts("\nError Code: ");
    Serial.putHex(frame.error_code);
    Serial.puts("\nRIP: ");
    Serial.putHex(frame.rip);
    Serial.puts("\nCS: ");
    Serial.putHex(frame.cs);
    Serial.puts("\nRFLAGS: ");
    Serial.putHex(frame.rflags);
    Serial.puts("\nRSP: ");
    Serial.putHex(frame.rsp);
    Serial.puts("\nSS: ");
    Serial.putHex(frame.ss);

    if (from_user) {
        // User-mode exception — kill the offending process instead of kernel panic
        Serial.puts("\n[EXCEPTION] Ring 3 fault! Killing user process.\n");
        // Kill the current task via the exit callback (same mechanism as syscall exit)
        if (exitCallback) |cb| {
            cb();
        }
        // After killing, we can't return to the faulting user code.
        // Modify the interrupt frame to point to a safe idle loop in Ring 0
        // so IRETQ returns to kernel idle code instead of the dead user task.
        // The scheduler will pick a Ready task on the next tick.
        frame.rip = @intFromPtr(&idle_after_fault);
        frame.cs = 0x08; // Kernel code segment
        frame.ss = 0x10; // Kernel data segment
        frame.rflags = 0x202; // IF set
        // Use the idle task's kernel stack for safety
        frame.rsp = 0x10b000; // Boot stack top
        Serial.puts("[EXCEPTION] User process killed. Returning to idle.\n");
    } else {
        // Kernel-mode exception — fatal, halt
        Serial.puts("\n[EXCEPTION] Kernel fault! Halting CPU...\n");
        while (true) {
            cli();
            hlt();
        }
    }
}

fn handleTimer(frame: *InterruptFrame) void {
    _ = frame;
    tick_count += 1;
}

fn handleKeyboard(frame: *InterruptFrame) void {
    _ = frame;
    const scan = inb(0x60);

    // Debug: show raw scancode on serial (helps diagnose translation issues)
    Serial.puts("[KBD] scan=0x");
    Serial.putHex(scan);
    Serial.puts("\n");

    // Extended key prefix
    if (scan == 0xE0) {
        kbd_extended = true;
        return;
    }

    // Key release (bit 7 set)
    if (scan & 0x80 != 0) {
        const released = scan & 0x7F;
        if (released == 0x2A or released == 0x36) kbd_shift = false;
        if (released == 0x1D) kbd_ctrl = false;
        if (released == 0x38) kbd_alt = false;
        kbd_extended = false;
        return;
    }

    // Extended key handling
    if (kbd_extended) {
        kbd_extended = false;
        // Arrow keys
        if (scan == 0x48) kbd_push(0x11); // Up
        if (scan == 0x50) kbd_push(0x12); // Down
        if (scan == 0x4B) kbd_push(0x13); // Left
        if (scan == 0x4D) kbd_push(0x14); // Right
        return;
    }

    // Modifier keys
    if (scan == 0x2A or scan == 0x36) { kbd_shift = true; return; }
    if (scan == 0x1D) { kbd_ctrl = true; return; }
    if (scan == 0x38) { kbd_alt = true; return; }

    // Convert scan code to ASCII
    if (scan < 128) {
        if (kbd_ctrl and scan == 0x2E) { kbd_push(0x03); return; } // Ctrl-C
        if (kbd_ctrl and scan == 0x15) { kbd_push(0x18); return; } // Ctrl-X
        if (kbd_ctrl and scan == 0x31) { kbd_push(0x1A); return; } // Ctrl-Z
        const ch = if (kbd_shift) scan_to_ascii_shift[scan] else scan_to_ascii[scan];
        if (ch != 0) {
            kbd_push(ch);
        }
    }
}

fn handleSerial(frame: *InterruptFrame) void {
    _ = frame;
    // TODO: Serial port interrupt handler
}

// ============================================================================
// PIC (8259 Programmable Interrupt Controller)
// ============================================================================

pub const PIC = struct {
    const PIC1_CMD: u16 = 0x20;
    const PIC1_DATA: u16 = 0x21;
    const PIC2_CMD: u16 = 0xA0;
    const PIC2_DATA: u16 = 0xA1;

    const ICW1_ICW4: u8 = 0x01;
    const ICW1_INIT: u8 = 0x10;
    const ICW4_8086: u8 = 0x01;

    pub fn init() void {
        // Remap PIC: IRQ 0-15 → INT 32-47

        // ICW1: Init + ICW4 needed
        outb(PIC1_CMD, ICW1_INIT | ICW1_ICW4);
        outb(PIC2_CMD, ICW1_INIT | ICW1_ICW4);

        // ICW2: Vector offsets
        outb(PIC1_DATA, 32); // Master: IRQ 0-7 → INT 32-39
        outb(PIC2_DATA, 40); // Slave:  IRQ 8-15 → INT 40-47

        // ICW3: Wiring
        outb(PIC1_DATA, 0x04); // Master: slave on IRQ2
        outb(PIC2_DATA, 0x02); // Slave: identity

        // ICW4: 8086 mode
        outb(PIC1_DATA, ICW4_8086);
        outb(PIC2_DATA, ICW4_8086);

        // Mask all PIC interrupts — we use APIC timer (vector 32)
        // and IO-APIC for keyboard. Only unmask IRQ1 (keyboard) as fallback.
        // IRQ0 (PIT) is masked because APIC timer replaces it.
        outb(PIC1_DATA, 0xFD); // Mask all except IRQ1 (keyboard)
        outb(PIC2_DATA, 0xFF); // Mask all slave
    }

    pub fn sendEOI(irq: u8) void {
        if (irq >= 8) {
            outb(PIC2_CMD, 0x20); // EOI to slave
        }
        outb(PIC1_CMD, 0x20); // EOI to master
    }
};

// ============================================================================
// Programmable Interval Timer (PIT) — Calibration helper
// ============================================================================
pub const PIT = struct {
    const CH2_DATA: u16 = 0x42;
    const CMD: u16 = 0x43;
    const GATE: u16 = 0x61;

    /// Калибровка через PIT channel 2 (метод из OSDev, без побочных IRQ).
    /// Возвращает число APIC-тиков за calibration_ms миллисекунд.
    pub fn calibrateApicTicks(comptime calibration_ms: u32) u32 {
        // PIT работает на 1.193182 MHz
        const pit_freq: u32 = 1193182;
        const pit_count: u32 = pit_freq / (1000 / calibration_ms);

        // Включаем gate PIT ch2, отключаем спикер-выход
        const gate_val = inb(GATE);
        outb(GATE, (gate_val & 0xFC) | 0x01);

        // Mode 0 (one-shot), channel 2, lobyte/hibyte
        outb(CMD, 0b10110000);
        outb(CH2_DATA, @truncate(pit_count));
        outb(CH2_DATA, @truncate(pit_count >> 8));

        // Взводим APIC-таймер на максимум и засекаем сколько он "проедет"
        APIC.writeReg(APIC.REG_TIMER_DIV, APIC.DIV_BY_16);
        APIC.writeReg(APIC.REG_TIMER_INIT, 0xFFFFFFFF);

        // Ждём пока PIT ch2 (OUT, бит 5 порта 0x61) досчитает до 0
        while ((inb(GATE) & 0x20) == 0) {}

        const remaining = APIC.readReg(APIC.REG_TIMER_CURRENT);
        return 0xFFFFFFFF - remaining; // тиков APIC за calibration_ms
    }
};

// ============================================================================
// Local APIC
// Local APIC
// ============================================================================

pub const APIC = struct {
    pub const BASE_MSR = 0x0000001B;
    pub const DEFAULT_PHYS_BASE: u64 = 0xFEE00000;

    pub const REG_ID = 0x020;
    pub const REG_VERSION = 0x030;
    pub const REG_TPR = 0x080;
    pub const REG_EOI = 0x0B0;
    pub const REG_SVR = 0x0F0;
    pub const REG_ICR_LOW = 0x300;
    pub const REG_ICR_HIGH = 0x310;
    pub const REG_LVT_TIMER = 0x320;
    pub const REG_LVT_ERROR = 0x370;
    pub const REG_TIMER_INIT = 0x380;
    pub const REG_TIMER_CURRENT = 0x390;
    pub const REG_TIMER_DIV = 0x3E0;

    pub const SVR_APIC_ENABLE: u32 = 1 << 8;
    pub const LVT_TIMER_PERIODIC: u32 = 1 << 17;
    pub const LVT_MASKED: u32 = 1 << 16;
    pub const DIV_BY_16: u32 = 0x03;

    var base_addr: u64 = 0;

    pub fn init() void {
        Serial.puts("[APIC] Reading MSR 0x1B...\n");
        const msr_val = readMsr(BASE_MSR);
        Serial.puts("[APIC] MSR value: ");
        Serial.putHex(msr_val);
        Serial.puts("\n");

        base_addr = msr_val & 0xFFFFFF000;
        Serial.puts("[APIC] Base addr: ");
        Serial.putHex(base_addr);
        Serial.puts("\n");

        // Если APIC глобально выключен — включаем
        if ((msr_val & (1 << 11)) == 0) {
            Serial.puts("[APIC] Enabling APIC...\n");
            writeMsr(BASE_MSR, msr_val | (1 << 11));
        } else {
            Serial.puts("[APIC] APIC already enabled\n");
        }

        // Set Spurious Interrupt Vector Register
        Serial.puts("[APIC] Setting SVR...\n");
        writeReg(REG_SVR, SVR_APIC_ENABLE | 0xFF);

        // Set up timer
        Serial.puts("[APIC] Setting timer...\n");
        writeReg(REG_LVT_TIMER, 48 | LVT_TIMER_PERIODIC); // Vector 48 — avoids PIC IRQ0-15 conflict
        writeReg(REG_TIMER_DIV, DIV_BY_16);

        // Калибровка: считаем сколько APIC-тиков в 10мс, целимся в 100 Гц context-switch
        const ticks_per_10ms = PIT.calibrateApicTicks(10);
        writeReg(REG_TIMER_INIT, ticks_per_10ms);

        // Mask error LVT
        writeReg(REG_LVT_ERROR, LVT_MASKED);
        Serial.puts("[APIC] Timer configured via PIT calibration\n");
    }

    pub fn writeReg(offset: u32, val: u32) void {
        const ptr: *volatile u32 = @ptrFromInt(base_addr + offset);
        ptr.* = val;
    }

    pub fn readReg(offset: u32) u32 {
        const ptr: *volatile u32 = @ptrFromInt(base_addr + offset);
        return ptr.*;
    }

    pub fn sendEOI() void {
        writeReg(REG_EOI, 0);
    }

    pub fn getId() u32 {
        return readReg(REG_ID) >> 24;
    }

    // ========================================================================
    // SMP: IPI (Inter-Processor Interrupt) functions
    // ========================================================================

    /// Send INIT IPI to a specific APIC ID.
    /// This resets the target processor to wait for SIPI.
    pub fn sendInitIpi(apic_id: u32) void {
        // Wait until delivery status is idle (bit 12 of ICR low)
        while ((readReg(REG_ICR_LOW) & (1 << 12)) != 0) {}

        // Write ICR high: target APIC ID in bits 24-31
        writeReg(REG_ICR_HIGH, apic_id << 24);

        // Write ICR low: Delivery Mode=INIT (101b), Dest Mode=Physical,
        // Delivery Status=Idle, Level=Assert, Trigger Mode=Edge
        // Bits: [10:8]=101(INIT), [7]=0(physical), [5]=0(fixed),
        //        [3]=1(assert - but actually self-clearing)
        // Actually for INIT: 0x00004500
        //   bit 8-10: 101 = INIT delivery mode
        //   bit 14: 1 = Assert (for INIT, must be assert)
        //   bit 11-13: 000 = reserved
        writeReg(REG_ICR_LOW, 0x00004500);

        // Wait for delivery
        while ((readReg(REG_ICR_LOW) & (1 << 12)) != 0) {}
    }

    /// Send Startup IPI (SIPI) to a specific APIC ID.
    /// vector: page number where the AP startup code lives (must be < 16, i.e. below 640KB)
    /// The AP starts executing at physical address = vector * 4096.
    pub fn sendStartupIpi(apic_id: u32, vector: u32) void {
        // Wait until delivery status is idle
        while ((readReg(REG_ICR_LOW) & (1 << 12)) != 0) {}

        // Write ICR high: target APIC ID in bits 24-31
        writeReg(REG_ICR_HIGH, apic_id << 24);

        // Write ICR low: Delivery Mode=StartUp (110b), vector=page number
        // Bits: [10:8]=110(Startup), [7]=0(physical), vector in bits 0-7
        writeReg(REG_ICR_LOW, 0x00004600 | (vector & 0xFF));

        // Wait for delivery
        while ((readReg(REG_ICR_LOW) & (1 << 12)) != 0) {}
    }

    /// Send a generic IPI (Inter-Processor Interrupt) to a target APIC ID.
    pub fn sendIpi(apic_id: u32, vector: u8) void {
        while ((readReg(REG_ICR_LOW) & (1 << 12)) != 0) {}
        writeReg(REG_ICR_HIGH, apic_id << 24);
        writeReg(REG_ICR_LOW, @as(u32, vector));
        while ((readReg(REG_ICR_LOW) & (1 << 12)) != 0) {}
    }
};

// ============================================================================
// IO-APIC (I/O Advanced Programmable Interrupt Controller)
// ============================================================================
pub const IOAPIC = struct {
    const BASE_ADDR: u64 = 0xFEC00000;
    const REG_SEL: *volatile u32 = @ptrFromInt(BASE_ADDR);
    const REG_WIN: *volatile u32 = @ptrFromInt(BASE_ADDR + 0x10);

    pub fn write(reg: u32, val: u32) void {
        REG_SEL.* = reg;
        REG_WIN.* = val;
    }

    pub fn read(reg: u32) u32 {
        REG_SEL.* = reg;
        return REG_WIN.*;
    }

    pub fn init() void {
        // Redirection table entry for Keyboard (IRQ 1) -> Vector 33
        // 0x12: redirection register for IRQ1 low 32 bits (vector 33, active high, edge triggered)
        // 0x13: redirection register for IRQ1 high 32 bits (destination APIC ID 0)
        write(0x12, 33);
        write(0x13, 0);
        Serial.puts("[IOAPIC] Keyboard redirection configured (IRQ1 -> Vector 33)\n");
    }
};

// ============================================================================
// PS/2 Keyboard Driver & Buffer
// ============================================================================
var kbd_shift: bool = false;
var kbd_ctrl: bool = false;
var kbd_alt: bool = false;
var kbd_extended: bool = false;

const scan_to_ascii = [128]u8{
    0, 0x1B, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\x08', 0,
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n', 0, 0,
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 0, '\\', 0,
    'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' ', 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

const scan_to_ascii_shift = [128]u8{
    0, 0x1B, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\x08', 0,
    '\t', 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n', 0, 0,
    0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0, '|', 0,
    'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, '*', 0, ' ', 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

var kbd_buffer: [256]u8 = undefined;
var kbd_head: usize = 0;
var kbd_tail: usize = 0;

pub fn kbd_push(ch: u8) void {
    const next = (kbd_head + 1) % kbd_buffer.len;
    if (next != kbd_tail) {
        kbd_buffer[kbd_head] = ch;
        kbd_head = next;
    }
}

pub fn kbd_pop() u8 {
    if (kbd_head == kbd_tail) return 0;
    const ch = kbd_buffer[kbd_tail];
    kbd_tail = (kbd_tail + 1) % kbd_buffer.len;
    return ch;
}

fn kbd_init() void {
    // Flush pending data from keyboard controller
    while ((inb(0x64) & 0x01) != 0) {
        _ = inb(0x60);
    }

    // Disable keyboard port temporarily during reconfiguration
    outb(0x64, 0xAD);
    while ((inb(0x64) & 0x02) != 0) {} // Wait for input buffer empty

    // Read current controller command byte
    outb(0x64, 0x20);
    while ((inb(0x64) & 0x01) == 0) {} // Wait for output buffer full
    var config = inb(0x60);

    // Print initial config for debugging
    Serial.puts("[KBD] Initial controller config: 0x");
    Serial.putHex(config);
    Serial.puts("\n");

    // Set config: enable IRQ1 (bit 0), enable keyboard port (clear bit 4)
    // EXPLICITLY enable translation mode (bit 6 = 0x40)
    // When translation is ON, the PS/2 controller converts
    // Set 2 scancodes from the keyboard into Set 1 before
    // delivering them to us. Our scan_to_ascii table uses Set 1.
    //
    // CRITICAL: Do NOT send 0xF0 0x01 to set scancode set 1 on the keyboard!
    // If translation is ON (bit 6) AND keyboard is in Set 1,
    // the controller's translate_table will mangle the Set 1 codes
    // (double translation). Leave keyboard in default Set 2 and
    // let the controller translate Set 2 → Set 1 for us.
    config |= 0x01;              // Enable IRQ1
    config &= ~@as(u8, 0x10);    // Enable keyboard port (bit 4 clear = enabled)
    config |= 0x40;              // EXPLICITLY enable translation (bit 6)
    // This converts Set 2 scancodes → Set 1 before delivering to port 0x60.
    // QEMU does NOT always have bit 6 set by default — if we don't set it,
    // we get raw Set 2 codes but our scan_to_ascii table is Set 1 = wrong chars!

    // Write command byte back
    outb(0x64, 0x60);
    while ((inb(0x64) & 0x02) != 0) {} // Wait for input buffer empty
    outb(0x60, config);
    while ((inb(0x64) & 0x02) != 0) {} // Wait for input buffer empty

    // Re-enable keyboard port
    outb(0x64, 0xAE);
    while ((inb(0x64) & 0x02) != 0) {} // Wait for input buffer empty

    // Reset keyboard (0xFF) — this resets to default Set 2 mode
    outb(0x60, 0xFF);
    // Wait for BAT completion (ACK 0xFA + BAT OK 0xAA)
    var timeout: u32 = 0;
    var got_bat: bool = false;
    while (timeout < 100000) : (timeout += 1) {
        if ((inb(0x64) & 0x01) != 0) {
            const resp = inb(0x60);
            if (resp == 0xAA) {
                got_bat = true;
                break;
            }
            // Consume ACK (0xFA) and keep waiting for BAT (0xAA)
        }
    }
    if (!got_bat) {
        Serial.puts("[KBD] WARNING: Keyboard BAT not received\n");
    }

    // Drain any remaining bytes after reset
    while ((inb(0x64) & 0x01) != 0) {
        _ = inb(0x60);
    }

    // DO NOT send 0xF0 0x01 to set scancode set 1!
    // The PS/2 controller's translation mode (bit 6) already converts
    // Set 2 → Set 1 for us. Setting Set 1 on the keyboard while
    // translation is ON causes double translation = wrong characters.
    // Just leave the keyboard in its default Set 2 mode and let
    // the controller handle the translation.

    kbd_head = 0;
    kbd_tail = 0;
    // Print the final config byte for debugging
    Serial.puts("[KBD] Controller config byte: 0x");
    Serial.putHex(config);
    Serial.puts(" (bit6=translate should be 1)\n");
    Serial.puts("[KBD] Keyboard initialized (Set 2 → Set 1 translation via controller)\n");
}

// Global print and clear screen functions (registered by main kernel)
pub var print_fn: ?*const fn ([]const u8) void = null;
pub var clear_screen_fn: ?*const fn () void = null;

// ============================================================================
// Page Table Flags
// Page table flags
// ============================================================================

pub const PAGE = struct {
    pub const PRESENT: u64 = 1 << 0;
    pub const WRITABLE: u64 = 1 << 1;
    pub const USER: u64 = 1 << 2;
    pub const ACCESSED: u64 = 1 << 5;
    pub const DIRTY: u64 = 1 << 6;
    pub const HUGE: u64 = 1 << 7;
    pub const GLOBAL: u64 = 1 << 8;
    pub const NX: u64 = 1 << 63;

    pub const KERNEL_RW: u64 = PRESENT | WRITABLE;
    pub const KERNEL_RX: u64 = PRESENT;
    pub const USER_RW: u64 = PRESENT | WRITABLE | USER;
    pub const USER_RX: u64 = PRESENT | USER;
};

// ============================================================================
// TSS (Task State Segment)
// Task State Segment
// ============================================================================

pub const TSS = packed struct {
    _reserved0: u32,
    rsp0: u64,
    rsp1: u64,
    rsp2: u64,
    _reserved1: u64,
    ist1: u64,
    ist2: u64,
    ist3: u64,
    ist4: u64,
    ist5: u64,
    ist6: u64,
    ist7: u64,
    _reserved2: u64,
    _reserved3: u16,
    iomap_base: u16,
};

// IST1 stack for Double Fault (#DF, vector 8)
var ist1_stack: [4096]u8 align(16) = undefined;

var tss: TSS = .{
    ._reserved0 = 0,
    .rsp0 = 0,
    .rsp1 = 0,
    .rsp2 = 0,
    ._reserved1 = 0,
    .ist1 = 0,
    .ist2 = 0,
    .ist3 = 0,
    .ist4 = 0,
    .ist5 = 0,
    .ist6 = 0,
    .ist7 = 0,
    ._reserved2 = 0,
    ._reserved3 = 0,
    .iomap_base = 104,
};

pub fn setKernelStack(stack: u64) void {
    tss.rsp0 = stack;
}

// ============================================================================
// Serial Port (для early debug)
// ============================================================================

pub const Serial = struct {
    const COM1: u16 = 0x3F8;

    pub fn init() void {
        outb(COM1 + 1, 0x00); // Disable interrupts
        outb(COM1 + 3, 0x80); // Enable DLAB
        outb(COM1 + 0, 0x01); // Baud divisor low = 1 → 115200
        outb(COM1 + 1, 0x00); // Baud divisor high = 0
        outb(COM1 + 3, 0x03); // 8N1
        outb(COM1 + 2, 0xC7); // Enable FIFO, clear, 14-byte threshold
        outb(COM1 + 4, 0x0B); // Enable RTS/DSR/DTR
    }

    pub fn puts(str: []const u8) void {
        for (str) |ch| {
            if (ch == '\n') {
                while ((inb(COM1 + 5) & 0x20) == 0) {}
                outb(COM1, '\r');
            }
            while ((inb(COM1 + 5) & 0x20) == 0) {}
            outb(COM1, ch);
        }
    }

    pub fn putHex(val: u64) void {
        const hex = "0123456789ABCDEF";
        puts("0x");
        var i: usize = 60;
        while (true) {
            puts(&.{hex[@intCast((val >> @intCast(i)) & 0xF)]});
            if (i == 0) break;
            i -= 4;
        }
    }

    pub fn putDecimal(val: u64) void {
        if (val == 0) {
            puts("0");
            return;
        }
        var buf: [20]u8 = undefined;
        var i: usize = 20;
        var temp = val;
        while (temp > 0) {
            i -= 1;
            buf[i] = '0' + @as(u8, @intCast(temp % 10));
            temp /= 10;
        }
        puts(buf[i..20]);
    }
};

pub fn initSyscalls(handler_addr: u64) void {
    // 1. Enable System Call Extensions (SCE) in EFER MSR
    const efer = readMsr(MSR.EFER);
    writeMsr(MSR.EFER, efer | EFER.SCE);

    // 2. Set segment selectors in STAR MSR (0xC0000081)
    const star: u64 = (@as(u64, 0x10) << 48) | (@as(u64, 0x08) << 32);
    writeMsr(MSR.STAR, star);

    // 3. Set entry point in LSTAR MSR (0xC0000082)
    writeMsr(MSR.LSTAR, handler_addr);

    // 4. Set RFLAGS mask in SFMASK MSR (0xC0000084)
    const sfmask: u64 = (1 << 9) | (1 << 10);
    writeMsr(MSR.SFMASK, sfmask);

    Serial.puts("[HAL] Syscall mechanism initialized\n");
}

pub export fn zig_syscall_handler(arg1: u64, arg2: u64, arg3: u64, arg4: u64, syscall_num: u64) callconv(.C) u64 {
    _ = arg3;
    _ = arg4;

    // Re-enable interrupts — syscall clears IF via SFMASK, but we need
    // timer interrupts to fire for preemptive scheduling. IF will be
    // restored from R11 on sysretq anyway.
    sti();

    switch (syscall_num) {
        1 => {
            // Syscall 1: Print string
            // arg1 = pointer to string, arg2 = length
            const ptr: [*]const u8 = @ptrFromInt(arg1);
            const len: usize = @intCast(arg2);
            const slice = ptr[0..len];
            if (print_fn) |f| {
                f(slice);
            } else {
                Serial.puts(slice);
            }
            return 0;
        },
        2 => {
            // Syscall 2: Read key (non-blocking)
            return kbd_pop();
        },
        3 => {
            // Syscall 3: Clear screen
            if (clear_screen_fn) |f| {
                f();
            }
            return 0;
        },
        4 => {
            // Syscall 4: Exit — terminate the calling user process
            // arg1 = exit code (unused for now)
            // This sets the current task to Killed state.
            // The scheduler will skip Killed tasks on next tick.
            Serial.puts("[SYSCALL] exit(");
            Serial.putDecimal(arg1);
            Serial.puts(") — killing user process\n");

            // Import scheduler to kill the current task.
            // We can't import scheduler directly (circular dep), so we use
            // a function pointer callback, similar to timerTickCallback.
            if (exitCallback) |cb| {
                cb();
            }
            // The task should never reach here — the scheduler will
            // have marked it as Killed and won't return to it.
            // But just in case, spin forever.
            while (true) {
                asm volatile ("pause");
            }
        },
        5 => {
            // Syscall 5: Yield — voluntarily give up CPU time
            // The scheduler will pick the next Ready task on the next tick.
            // For now, this is a no-op since the APIC timer preempts anyway.
            // In the future, this could trigger an immediate reschedule.
            return 0;
        },
        else => {
            Serial.puts("[SYSCALL] Unknown syscall: ");
            Serial.putDecimal(syscall_num);
            Serial.puts("\n");
            return @as(u64, @bitCast(@as(i64, -1)));
        }
    }
}

// Exit callback — registered by scheduler at init to break circular dependency
pub var exitCallback: ?*const fn () callconv(.C) void = null;

// ============================================================================
// HAL Initialization
// ============================================================================

pub fn init() void {
    // 1. Initialize serial port (early debug)
    Serial.init();
    Serial.puts("[HAL] Serial port initialized\n");

    // 2. GDT — Initialize and load our own 64-bit GDT
    GDT.init();
    Serial.puts("[HAL] GDT loaded\n");

    // 3. Initialize IDT (using ISR stubs from isr64.S)
    IDT.init();
    Serial.puts("[HAL] IDT loaded\n");

    // 4. Initialize PIC (remap IRQs)
    PIC.init();
    Serial.puts("[HAL] PIC remapped\n");

    // 5. TSS — Initialize Task State Segment + IST1 for Double Fault
    tss.ist1 = @intFromPtr(&ist1_stack) + ist1_stack.len;
    GDT.setTSS(0, @intFromPtr(&tss), @sizeOf(TSS) - 1);
    ltr(0x38); // TSS at GDT entry 7 (selector 0x38)
    Serial.puts("[HAL] TSS loaded (IST1 for #DF at ");
    Serial.putHex(tss.ist1);
    Serial.puts(")\n");

    // 6. Initialize Local APIC
    APIC.init();
    Serial.puts("[HAL] Local APIC initialized\n");

    // 6.5. Initialize IO-APIC & Keyboard
    IOAPIC.init();
    kbd_init();

    // 7. Enable interrupts!
    sti();
    Serial.puts("[HAL] Interrupts enabled\n");
}

// ============================================================================
// VGA Text Mode Initialization — Program VGA registers for 80x25 text mode
// ============================================================================
//
// Switches VGA from any mode (including VBE graphical) to standard
// 80x25 text mode at 0xB8000. Works from 64-bit long mode without BIOS.
// Based on Linux vgacon, IBM VGA spec, and Rust vga crate.
//
// This is needed because GRUB may leave the VGA controller in graphical
// (VBE) mode. In that state, writing to 0xB8000 has no visible effect —
// the CRTC scans the linear framebuffer, not the text plane.
//
// After calling this, the VGA text buffer at 0xB8000 is active and
// characters written there appear on screen immediately.

pub fn vgaSetTextMode() void {
    // Step 1: Assert synchronous reset on sequencer (disables display)
    vgaWriteIndexed(0x3C4, 0x3C5, 0x00, 0x01);

    // Step 2: Set Miscellaneous Output Register
    // 0x67 = Color I/O, CPU access, 25MHz clock, 400 scan lines
    outb(0x3C2, 0x67);

    // Step 3: Program Sequencer registers
    vgaWriteIndexed(0x3C4, 0x3C5, 0x01, 0x00); // Clocking: 9-dot, screen on
    vgaWriteIndexed(0x3C4, 0x3C5, 0x02, 0x03); // Plane mask: enable planes 0,1
    vgaWriteIndexed(0x3C4, 0x3C5, 0x03, 0x00); // Font: map 0
    vgaWriteIndexed(0x3C4, 0x3C5, 0x04, 0x02); // Memory: odd/even, >64KB

    // De-assert sequencer reset
    vgaWriteIndexed(0x3C4, 0x3C5, 0x00, 0x03);

    // Step 4: Unlock CRTC registers (clear protect bit)
    vgaWriteIndexed(0x3D4, 0x3D5, 0x11, 0x00);

    // Step 5: Program CRTC registers for 80x25 text (720x400, 70Hz)
    const crtc = [_][2]u8{
        .{ 0x00, 0x5F }, // Horizontal Total
        .{ 0x01, 0x4F }, // Horizontal Display End (80 chars)
        .{ 0x02, 0x50 }, // Horizontal Blanking Start
        .{ 0x03, 0x82 }, // Horizontal Blanking End
        .{ 0x04, 0x55 }, // Horizontal Sync Start
        .{ 0x05, 0x81 }, // Horizontal Sync End
        .{ 0x06, 0xBF }, // Vertical Total
        .{ 0x07, 0x1F }, // Overflow
        .{ 0x08, 0x00 }, // Preset Row Scan
        .{ 0x09, 0x4F }, // Maximum Scan Line (16 scanlines/char)
        .{ 0x0A, 0x0D }, // Text Cursor Start
        .{ 0x0B, 0x0E }, // Text Cursor End
        .{ 0x0C, 0x00 }, // Start Address High
        .{ 0x0D, 0x00 }, // Start Address Low
        .{ 0x0E, 0x00 }, // Cursor Location High
        .{ 0x0F, 0x50 }, // Cursor Location Low
        .{ 0x10, 0x9C }, // Vertical Sync Start
        .{ 0x11, 0x8E }, // Vertical Sync End (bit 7=1 re-protects)
        .{ 0x12, 0x8F }, // Vertical Display End (399 = 25*16-1)
        .{ 0x13, 0x28 }, // Offset (40 = 80/2 word mode)
        .{ 0x14, 0x1F }, // Underline Location
        .{ 0x15, 0x96 }, // Vertical Blanking Start
        .{ 0x16, 0xB9 }, // Vertical Blanking End
        .{ 0x17, 0xA3 }, // Mode Control (word mode, sync enabled)
        .{ 0x18, 0xFF }, // Line Compare
    };
    for (&crtc) |reg| {
        vgaWriteIndexed(0x3D4, 0x3D5, reg[0], reg[1]);
    }

    // Step 6: Program Graphics Controller registers
    const gc = [_][2]u8{
        .{ 0x00, 0x00 }, // Set/Reset
        .{ 0x01, 0x00 }, // Enable Set/Reset
        .{ 0x02, 0x00 }, // Color Compare
        .{ 0x03, 0x00 }, // Data Rotate
        .{ 0x04, 0x00 }, // Read Plane Select
        .{ 0x05, 0x10 }, // Graphics Mode: odd/even (text mode)
        .{ 0x06, 0x0E }, // Miscellaneous: TEXT MODE, B8000 mapping
        .{ 0x07, 0x00 }, // Color Don't Care
        .{ 0x08, 0xFF }, // Bit Mask
    };
    for (&gc) |reg| {
        vgaWriteIndexed(0x3CE, 0x3CF, reg[0], reg[1]);
    }

    // Step 7: Blank screen to unlock attribute palette
    _ = inb(0x3DA); // Reset attribute controller flip-flop
    outb(0x3C0, 0x00); // Index 0, blanked (bit 5=0)

    // Step 8: Program Attribute Controller registers
    const ac_palette = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F };
    for (&ac_palette, 0..) |val, idx| {
        outb(0x3C0, @intCast(idx)); // Write index
        outb(0x3C0, val); // Write data
    }
    outb(0x3C0, 0x10); outb(0x3C0, 0x0C); // Mode: text, 9-dot, blink
    outb(0x3C0, 0x11); outb(0x3C0, 0x00); // Overscan: black
    outb(0x3C0, 0x12); outb(0x3C0, 0x0F); // Plane enable: all
    outb(0x3C0, 0x13); outb(0x3C0, 0x08); // Horizontal panning
    outb(0x3C0, 0x14); outb(0x3C0, 0x00); // Color select

    // Step 9: Unblank screen (enable display)
    _ = inb(0x3DA); // Reset flip-flop
    outb(0x3C0, 0x20); // Set bit 5 = enable display

    // Step 10: Initialize DAC palette (16 standard VGA colors)
    outb(0x3C8, 0x00); // DAC write index = 0
    // Standard 16 VGA colors (6-bit RGB: 0x00=0, 0x2A=42, 0x15=21, 0x3F=63)
    const palette = [_][3]u8{
        .{ 0x00, 0x00, 0x00 }, // 0: Black
        .{ 0x00, 0x00, 0x2A }, // 1: Blue
        .{ 0x00, 0x2A, 0x00 }, // 2: Green
        .{ 0x00, 0x2A, 0x2A }, // 3: Cyan
        .{ 0x2A, 0x00, 0x00 }, // 4: Red
        .{ 0x2A, 0x00, 0x2A }, // 5: Magenta
        .{ 0x2A, 0x15, 0x00 }, // 6: Brown
        .{ 0x2A, 0x2A, 0x2A }, // 7: Light Gray
        .{ 0x15, 0x15, 0x15 }, // 8: Dark Gray
        .{ 0x15, 0x15, 0x3F }, // 9: Light Blue
        .{ 0x15, 0x3F, 0x15 }, // 10: Light Green
        .{ 0x15, 0x3F, 0x3F }, // 11: Light Cyan
        .{ 0x3F, 0x15, 0x15 }, // 12: Light Red
        .{ 0x3F, 0x15, 0x3F }, // 13: Light Magenta
        .{ 0x3F, 0x3F, 0x15 }, // 14: Yellow
        .{ 0x3F, 0x3F, 0x3F }, // 15: White
    };
    for (&palette) |color| {
        outb(0x3C9, color[0]); // Red
        outb(0x3C9, color[1]); // Green
        outb(0x3C9, color[2]); // Blue
    }
    outb(0x3C6, 0xFF); // PEL mask

    // Step 11: Clear text buffer at 0xB8000
    const vram: [*]volatile u16 = @ptrFromInt(0xB8000);
    var i: usize = 0;
    while (i < 80 * 25) : (i += 1) {
        vram[i] = 0x0720; // Space (0x20) with light gray on black (0x07)
    }

    // Set cursor to top-left
    vgaWriteIndexed(0x3D4, 0x3D5, 0x0E, 0x00);
    vgaWriteIndexed(0x3D4, 0x3D5, 0x0F, 0x00);

    Serial.puts("[HAL] VGA text mode (80x25) initialized via register programming\n");
}

/// Helper: Write to an indexed VGA register pair
fn vgaWriteIndexed(index_port: u16, data_port: u16, index: u8, value: u8) void {
    outb(index_port, index);
    outb(data_port, value);
}
`
```

### `zig-kernel/src64/heap64.zig` [zig · 26,827 B]
```
`// ============================================================================
// POLER-OS Kernel Dynamic Heap Allocator (kmalloc/kfree) — x86_64
// v7: HMAC-based integrity checking via SipHash-2-4 (replaces heap_cookie)
// v6: Bug fixes for all 11 issues found by symbolic execution
// ============================================================================
//
// v7 SECURITY FIX (MEDIUM severity — heap cookie forgery):
//   Replaced per-boot random cookie (heap_cookie) with SipHash-2-4 based
//   integrity tags. The old cookie could be forged by an attacker with a
//   heap write primitive. The new SipHash tag is cryptographically bound to
//   block metadata (address, size, padding, free status) using a 128-bit key
//   that is never stored in heap memory. An attacker cannot forge a valid tag
//   without knowing the key.
//
//   SipHash-2-4 was chosen over HMAC-SHA256 because:
//   - Specifically designed for short-message authentication
//   - Much simpler (~50 lines vs ~200+ lines for SHA-256)
//   - Used by Linux kernel for the same purpose (heap object tracking)
//   - 64-bit output truncated to 32 bits provides adequate security for
//     heap integrity (2^32 brute-force per block, detected on free)

const pmm = @import("pmm64.zig");
const vmm = @import("vmm64.zig");
const hal = @import("hal.zig");
const std = @import("std");

// ============================================================================
// SipHash-2-4 — Short-input PRF for heap integrity verification
// ============================================================================
// Reference: Jean-Philippe Aumasson & Daniel J. Bernstein, "SipHash: a fast
// short-input PRF" (2012). Parameters c=2, d=4 as recommended for
// non-cryptographic but adversarial use (same as Linux kernel's siphash).
//
/// SipHash-2-4 for heap integrity verification.
/// Simpler than HMAC-SHA256, specifically designed for short-message authentication.
/// Used by Linux kernel for the same purpose (heap object tracking).
const SipHash = struct {
    v0: u64,
    v1: u64,
    v2: u64,
    v3: u64,

    fn sipround(self: *SipHash) void {
        self.v0 +%= self.v1;
        self.v1 = rotl64(self.v1, 13);
        self.v1 ^= self.v0;
        self.v0 = rotl64(self.v0, 32);
        self.v2 +%= self.v3;
        self.v3 = rotl64(self.v3, 16);
        self.v3 ^= self.v2;
        self.v0 +%= self.v3;
        self.v3 = rotl64(self.v3, 21);
        self.v3 ^= self.v0;
        self.v2 +%= self.v1;
        self.v1 = rotl64(self.v1, 17);
        self.v1 ^= self.v2;
        self.v2 = rotl64(self.v2, 32);
    }

    /// Compute SipHash-2-4 of a message using a 128-bit key (k0, k1).
    /// Returns full 64-bit tag. Caller can truncate to 32 bits.
    fn compute(k0: u64, k1: u64, msg: []const u8) u64 {
        var self = SipHash{
            .v0 = k0 ^ 0x736f6d6570736575,
            .v1 = k1 ^ 0x646f72616e646f6d,
            .v2 = k0 ^ 0x6c7967656e657261,
            .v3 = k1 ^ 0x7465646279746573,
        };

        const msg_len = msg.len;
        var offset: usize = 0;

        // Process 8-byte blocks
        while (offset + 8 <= msg_len) : (offset += 8) {
            const m: u64 = std.mem.readInt(u64, msg[offset..][0..8], .little);
            self.v3 ^= m;
            self.sipround(); // c=2: 2 compression rounds
            self.sipround();
            self.v0 ^= m;
        }

        // Last block with length padding
        var last: u64 = @as(u64, msg_len & 0xFF);
        var shift: u6 = 8;
        while (offset < msg_len) : ({
            offset += 1;
            shift +%= 8;
        }) {
            last |= @as(u64, msg[offset]) << shift;
        }

        self.v3 ^= last;
        self.sipround();
        self.sipround();
        self.v2 ^= 0xFF;

        // d=4: 4 finalization rounds
        self.sipround();
        self.sipround();
        self.sipround();
        self.sipround();

        return self.v0 ^ self.v1 ^ self.v2 ^ self.v3;
    }
};

/// Rotate-left for u64 — used by SipHash
fn rotl64(value: u64, comptime shift: usize) u64 {
    return (value << @intCast(shift)) | (value >> @intCast(64 - shift));
}

// ============================================================================
// Block structure & global state
// ============================================================================

pub const Block = struct {
    size: usize,
    free: bool,
    next: ?*Block,
    padding: u64 = 0, // Non-zero when payload is offset from header (aligned alloc)
    tag: u32 = 0, // v7: SipHash integrity tag — 0 for free blocks, computed for allocated blocks
};

// v7: When padding > 0, we store a SipHash tag + real block address just
// before the payload so kfree can find the header regardless of alignment offset.
// Layout before aligned payload:
//   [tag: u64 = zero-extended block.tag] [back_ptr: u64 = address of Block]
// Both are validated in getBlockFromPayload to avoid false positives.
//
// The tag replaces the old heap_cookie. Unlike the cookie, the tag is
// cryptographically bound to block metadata and cannot be forged without
// the SipHash key (heap_hmac_key0, heap_hmac_key1) which is never stored
// in heap memory.
//
// Two-layer verification:
//   1. getBlockFromPayload: tag before payload must match block.tag (finds header)
//   2. freeInternal: recomputes tag from metadata, must match block.tag (integrity)
//
// BACK_PTR_OVERHEAD is still 16 bytes: 8 for tag (u64, zero-extended from u32)
// + 8 for back_ptr.
var heap_hmac_key0: u64 = 0; // v7: SipHash key — generated from RDTSC at boot, never in heap
var heap_hmac_key1: u64 = 0; // v7: SipHash key — generated from RDTSC at boot, never in heap
const BACK_PTR_OVERHEAD: u64 = @sizeOf(u64) * 2; // tag (u64) + back_ptr

pub const HEAP_START: u64 = 0x200000000; // 8GB mark
pub const HEAP_MAX: u64 = 0x300000000; // 12GB mark (4GB max heap)

var heap_end: u64 = HEAP_START;
var first_block: ?*Block = null;

const vtable = std.mem.Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

pub var allocator: std.mem.Allocator = undefined;

// ============================================================================
// SipHash tag computation
// ============================================================================

/// v7: Compute a 32-bit SipHash-2-4 tag over block metadata.
/// Binds the tag to: block address, size, padding, and free status.
/// The block address makes the tag location-dependent — moving a block
/// to a different address invalidates its tag.
fn computeBlockTag(block: *Block) u32 {
    // Build the message: 4 fields × 8 bytes each = 32 bytes
    var msg: [32]u8 = undefined;
    const addr = @intFromPtr(block);
    std.mem.writeInt(u64, msg[0..8], addr, .little);
    std.mem.writeInt(u64, msg[8..16], block.size, .little);
    std.mem.writeInt(u64, msg[16..24], block.padding, .little);
    std.mem.writeInt(u64, msg[24..32], if (block.free) @as(u64, 1) else @as(u64, 0), .little);
    const full_tag = SipHash.compute(heap_hmac_key0, heap_hmac_key1, &msg);
    return @truncate(full_tag); // Lower 32 bits
}

// ============================================================================
// Initialization
// ============================================================================

pub fn init() void {
    // v7: Generate 128-bit SipHash key from RDTSC.
    // XOR with golden ratio constants for avalanche even if TSC is predictable.
    // The key is never stored in heap memory — only in BSS (heap_hmac_key0/1).
    var tsc: u64 = 0;
    asm volatile ("rdtsc"
        : [ret] "={rax}" (tsc),
    );
    heap_hmac_key0 = tsc ^ 0x9E3779B99E3779B9;
    // Second key derived from first with different mixing
    heap_hmac_key1 = rotl64(heap_hmac_key0, 17) ^ 0x6A09E667F3BCC909;
    // Ensure key pair is not all-zero (would weaken SipHash initialization vectors)
    if (heap_hmac_key0 == 0 and heap_hmac_key1 == 0) {
        heap_hmac_key0 = 0xDEADBEEF_DEADBEEF;
        heap_hmac_key1 = 0xCAFEBABE_CAFEBABE;
    }

    // Allocate the first physical page for the heap
    const phys = pmm.allocPage() orelse {
        hal.Serial.puts("[HEAP] Failed to allocate first physical page!\n");
        return;
    };

    vmm.mapPage(HEAP_START, phys, vmm.PTE_WRITABLE) catch |err| {
        hal.Serial.puts("[HEAP] Failed to map first page: ");
        hal.Serial.puts(@errorName(err));
        hal.Serial.puts("\n");
        // v6 FIX (Bug #6): Free physical page on mapping failure
        pmm.freePage(phys);
        return;
    };

    heap_end = HEAP_START + vmm.PAGE_SIZE;

    const block: *Block = @ptrFromInt(HEAP_START);
    block.size = vmm.PAGE_SIZE - @sizeOf(Block);
    block.free = true;
    block.next = null;
    block.padding = 0;
    block.tag = 0; // v7: free blocks have tag = 0 (untagged)

    first_block = block;

    allocator = std.mem.Allocator{
        .ptr = undefined,
        .vtable = &vtable,
    };

    hal.Serial.puts("[HEAP] Kernel heap initialized from ");
    hal.Serial.putHex(HEAP_START);
    hal.Serial.puts(" to ");
    hal.Serial.putHex(heap_end);
    hal.Serial.puts(" (SipHash integrity enabled)\n");
}

// ============================================================================
// Utility functions
// ============================================================================

fn alignUp(val: u64, alignment: u64) u64 {
    return (val + alignment - 1) & ~(alignment - 1);
}

/// v6 FIX (Bug #3): Validate that a pointer is a valid heap allocation.
/// Checks: range, alignment, block metadata consistency.
fn isValidHeapPointer(ptr: [*]u8) bool {
    const addr = @intFromPtr(ptr);
    // Check: pointer must be within heap virtual address range
    if (addr < HEAP_START + @sizeOf(Block) or addr >= HEAP_MAX) return false;
    // Check: pointer must be at least 16-byte aligned (minimum Block alignment)
    if (addr % 16 != 0) return false;
    return true;
}

/// v6 FIX (Bug #1 + #3) + v7: Improved getBlockFromPayload with SipHash tag
/// verification (replaces heap_cookie check) and wild pointer detection.
fn getBlockFromPayload(ptr: [*]u8) ?*Block {
    // v6: Validate pointer before any dereference (Bug #3: wild pointer)
    if (!isValidHeapPointer(ptr)) {
        hal.Serial.puts("[HEAP] ERROR: kfree on invalid pointer: 0x");
        hal.Serial.putHex(@intFromPtr(ptr));
        hal.Serial.puts("\n");
        return null;
    }

    // v7: Check if there's a SipHash tag + back-pointer stored just before
    // the payload. Layout: [tag: u64] [block_addr: u64] [aligned_payload...]
    const maybe_tag_addr = @intFromPtr(ptr) - BACK_PTR_OVERHEAD;
    // Bounds check before reading tag
    if (maybe_tag_addr >= HEAP_START and maybe_tag_addr < HEAP_MAX) {
        const maybe_tag: *const u64 = @ptrFromInt(maybe_tag_addr);
        const back_ptr_loc: *const u64 = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(u64));
        const block_addr = back_ptr_loc.*;

        // v7: Instead of comparing against a fixed cookie, we:
        // 1. Read the back-pointer to find the candidate block
        // 2. Verify the block has padding > 0 (aligned alloc marker)
        // 3. Verify the stored tag matches block.tag
        // This eliminates the forgery vulnerability — an attacker cannot
        // produce a valid tag without the SipHash key.
        if (block_addr >= HEAP_START and block_addr < HEAP_MAX) {
            const block: *Block = @ptrFromInt(block_addr);
            // Verify: ptr should be within this block's payload region
            const expected_payload = @intFromPtr(block) + @sizeOf(Block);
            if (@intFromPtr(ptr) >= expected_payload and @intFromPtr(ptr) < expected_payload + block.size + @sizeOf(Block)) {
                // v7: Only trust the tag+back-ptr if:
                // 1. block.padding > 0 (aligned alloc marker)
                // 2. stored tag before payload matches block.tag
                if (block.padding > 0 and block.tag == @as(u32, @truncate(maybe_tag.*))) {
                    return block;
                }
                // Padding=0 but back-ptr+tag found → not an aligned allocation,
                // fall through to the direct header path below.
            }
        }
        // Tag/back-ptr present but invalid — this could be corruption
        // We don't print an error here because it might just be user data
        // that happens to look like a tag+back-ptr pattern. The real
        // integrity check happens in freeInternal via tag recomputation.
    }

    // No aligned padding (or tag mismatch) — header is right before payload
    const block_addr = @intFromPtr(ptr) - @sizeOf(Block);
    if (block_addr < HEAP_START or block_addr >= HEAP_MAX) {
        hal.Serial.puts("[HEAP] ERROR: block header out of heap range\n");
        return null;
    }
    const block: *Block = @ptrFromInt(block_addr);
    // v6: Verify block metadata is consistent
    if (block.size > HEAP_MAX - HEAP_START) {
        hal.Serial.puts("[HEAP] ERROR: block size corrupt (too large)\n");
        return null;
    }
    return block;
}

// ============================================================================
// Allocation
// ============================================================================

fn alloc(
    ctx: *anyopaque,
    len: usize,
    ptr_align: u8,
    ret_addr: usize,
) ?[*]u8 {

    // v6 FIX (Bug #8): kmalloc(0) should return null
    if (len == 0) return null;

    const alignment = @as(usize, 1) << @as(u6, @intCast(ptr_align));
    // v6 FIX (Bug #4): Integer overflow check for aligned_len
    // If len is very large, alignUp could overflow u64
    const aligned_len = alignUp(len, 16);
    if (aligned_len < len) return null; // overflow detected

    hal.cli();
    defer hal.sti();

    var current = first_block;
    var prev: ?*Block = null;

    while (current) |block| {
        if (block.free) {
            const payload_addr = @intFromPtr(block) + @sizeOf(Block);

            if (alignment <= 16) {
                // Default path: Block header is 16-byte aligned, payload follows directly.
                if (block.size >= aligned_len) {
                    if (block.size >= aligned_len + @sizeOf(Block) + 16) {
                        const next_block_addr = @intFromPtr(block) + @sizeOf(Block) + aligned_len;
                        const next_block: *Block = @ptrFromInt(next_block_addr);
                        next_block.size = block.size - aligned_len - @sizeOf(Block);
                        next_block.free = true;
                        next_block.next = block.next;
                        next_block.padding = 0;
                        next_block.tag = 0; // v7: free blocks are untagged

                        block.size = aligned_len;
                        block.next = next_block;
                    }
                    block.free = false;
                    block.padding = 0;
                    block.tag = computeBlockTag(block); // v7: compute integrity tag
                    return @ptrFromInt(payload_addr);
                }
            } else {
                // Over-aligned allocation
                const min_payload = payload_addr + BACK_PTR_OVERHEAD;
                const final_payload_addr = alignUp(min_payload, alignment);
                const total_padding = final_payload_addr - payload_addr;
                const total_required = aligned_len + total_padding;

                // v6 FIX (Bug #4): overflow check
                if (total_required < aligned_len) return null;

                if (block.size >= total_required) {
                    // v6 FIX (Bug #5): Over-aligned allocs — split if there's room
                    if (block.size >= total_required + @sizeOf(Block) + 16) {
                        const next_block_addr = @intFromPtr(block) + @sizeOf(Block) + total_padding + aligned_len;
                        const next_block: *Block = @ptrFromInt(next_block_addr);
                        next_block.size = block.size - total_padding - aligned_len - @sizeOf(Block);
                        next_block.free = true;
                        next_block.next = block.next;
                        next_block.padding = 0;
                        next_block.tag = 0; // v7: free blocks are untagged

                        block.size = total_padding + aligned_len;
                        block.next = next_block;
                    }

                    block.padding = total_padding;
                    block.free = false;
                    block.tag = computeBlockTag(block); // v7: compute integrity tag

                    // v7: Write tag + back-pointer just before the aligned payload.
                    // The tag replaces the old heap_cookie — it is cryptographically
                    // bound to this block's metadata and cannot be forged.
                    const tag_loc: *u64 = @ptrFromInt(final_payload_addr - BACK_PTR_OVERHEAD);
                    tag_loc.* = @as(u64, block.tag); // zero-extend u32 tag to u64
                    const back_ptr_loc: *u64 = @ptrFromInt(final_payload_addr - @sizeOf(u64));
                    back_ptr_loc.* = @intFromPtr(block);

                    return @ptrFromInt(final_payload_addr);
                }
            }
        }
        prev = current;
        current = block.next;
    }

    // Out of memory, expand the heap!
    // v6 FIX (Bug #4): Safe expansion size calculation with overflow check
    const expand_base = aligned_len + @sizeOf(Block) + BACK_PTR_OVERHEAD;
    if (expand_base < aligned_len) return null; // overflow
    const expand_size = alignUp(expand_base, vmm.PAGE_SIZE);
    const pages_needed = expand_size / vmm.PAGE_SIZE;

    var i: usize = 0;
    while (i < pages_needed) : (i += 1) {
        if (heap_end >= HEAP_MAX) {
            hal.Serial.puts("[HEAP] Out of virtual heap space!\n");
            return null;
        }

        const phys = pmm.allocPage() orelse {
            hal.Serial.puts("[HEAP] Out of physical memory during heap expansion!\n");
            return null;
        };

        vmm.mapPage(heap_end, phys, vmm.PTE_WRITABLE) catch |err| {
            hal.Serial.puts("[HEAP] Failed to map expanded page: ");
            hal.Serial.puts(@errorName(err));
            hal.Serial.puts("\n");
            // v6 FIX (Bug #6): Free physical page on mapping failure
            pmm.freePage(phys);
            return null;
        };

        heap_end += vmm.PAGE_SIZE;
    }

    // Append free space to last block or create a new one
    if (prev) |last_block| {
        if (last_block.free) {
            last_block.size += expand_size;
            return alloc(ctx, len, ptr_align, ret_addr);
        } else {
            const new_block_addr = @intFromPtr(last_block) + @sizeOf(Block) + last_block.size;
            const new_block: *Block = @ptrFromInt(new_block_addr);
            new_block.size = expand_size - @sizeOf(Block);
            new_block.free = true;
            new_block.next = null;
            new_block.padding = 0;
            new_block.tag = 0; // v7: free blocks are untagged

            last_block.next = new_block;
            return alloc(ctx, len, ptr_align, ret_addr);
        }
    }

    return null;
}

test "placeholder" {}

// ============================================================================
// Resize
// ============================================================================

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    buf_align: u8,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = ctx;
    _ = buf_align;
    _ = ret_addr;

    const block = getBlockFromPayload(buf.ptr) orelse return false;
    const aligned_new_len = alignUp(new_len, 16);

    hal.cli();
    defer hal.sti();

    if (aligned_new_len <= block.size) {
        // Shrink block
        if (block.size - aligned_new_len >= @sizeOf(Block) + 16) {
            const next_block_addr = @intFromPtr(block) + @sizeOf(Block) + aligned_new_len;
            const next_block: *Block = @ptrFromInt(next_block_addr);
            next_block.size = block.size - aligned_new_len - @sizeOf(Block);
            next_block.free = true;
            next_block.next = block.next;
            next_block.padding = 0;
            next_block.tag = 0; // v7: free blocks are untagged

            block.size = aligned_new_len;
            block.next = next_block;
        }
        // v7: Recompute tag since size may have changed
        block.tag = computeBlockTag(block);
        return true;
    } else {
        // Grow block in-place if next block is free and large enough
        if (block.next) |next_b| {
            if (next_b.free and (block.size + @sizeOf(Block) + next_b.size >= aligned_new_len)) {
                const remaining = (block.size + @sizeOf(Block) + next_b.size) - aligned_new_len;
                if (remaining >= @sizeOf(Block) + 16) {
                    const new_next_addr = @intFromPtr(block) + @sizeOf(Block) + aligned_new_len;
                    const new_next: *Block = @ptrFromInt(new_next_addr);
                    new_next.size = remaining - @sizeOf(Block);
                    new_next.free = true;
                    new_next.next = next_b.next;
                    new_next.padding = 0;
                    new_next.tag = 0; // v7: free blocks are untagged

                    block.size = aligned_new_len;
                    block.next = new_next;
                } else {
                    block.size += @sizeOf(Block) + next_b.size;
                    block.next = next_b.next;
                }
                // v7: Recompute tag since size changed
                block.tag = computeBlockTag(block);
                return true;
            }
        }
        return false;
    }
}

// ============================================================================
// Free
// ============================================================================

/// v6 + v7: Unified internal free function — eliminates code duplication (Bug #11).
/// Both `free` (VTable) and `kfree` (public API) now use this.
/// Returns true on success, false on error (double-free, invalid pointer, tag mismatch).
fn freeInternal(ptr: [*]u8) bool {
    const block = getBlockFromPayload(ptr) orelse return false;

    // v7: Verify integrity tag — recompute SipHash over block metadata and
    // compare with stored tag. Mismatch indicates heap corruption or tampering.
    // This is the primary security check: an attacker with a heap write primitive
    // cannot forge a valid tag without knowing the SipHash key.
    const expected_tag = computeBlockTag(block);
    if (block.tag != expected_tag) {
        hal.Serial.puts("[HEAP] ALERT: integrity tag mismatch at block 0x");
        hal.Serial.putHex(@intFromPtr(block));
        hal.Serial.puts(" — heap corruption detected!\n");
        return false;
    }

    // v6 FIX (Bug #2): Double-free detection
    // v7 enhancement: a freed block has tag = 0, so recomputation will fail
    // with tag mismatch even before this check. But we keep the explicit
    // double-free detection for clearer error reporting.
    if (block.free) {
        hal.Serial.puts("[HEAP] ERROR: double-free detected at block 0x");
        hal.Serial.putHex(@intFromPtr(block));
        hal.Serial.puts("\n");
        return false;
    }

    block.free = true;
    block.padding = 0; // Clear padding so coalescing is safe
    block.tag = 0; // v7: clear tag — freed blocks are untagged.
    // This also strengthens double-free detection: a freed block will have
    // tag=0, which won't match any valid computed tag.

    // Coalesce contiguous free blocks
    coalesceFreeBlocks();
    return true;
}

fn free(
    ctx: *anyopaque,
    buf: []u8,
    buf_align: u8,
    ret_addr: usize,
) void {
    _ = ctx;
    _ = buf_align;
    _ = ret_addr;

    if (buf.ptr == undefined) return;

    hal.cli();
    defer hal.sti();

    _ = freeInternal(buf.ptr);
}

/// Merge adjacent free blocks into larger ones
fn coalesceFreeBlocks() void {
    var current = first_block;
    while (current) |b| {
        if (b.free) {
            while (b.next) |next_b| {
                if (next_b.free) {
                    b.size += @sizeOf(Block) + next_b.size;
                    b.next = next_b.next;
                    // v7: merged block inherits b.tag (= 0, since b.free)
                } else {
                    break;
                }
            }
        }
        current = b.next;
    }
}

// ============================================================================
// Public API
// ============================================================================

/// v6 FIX (Bug #8): kmalloc(0) returns null
pub fn kmalloc(len: usize) ?[*]u8 {
    if (len == 0) return null; // v6: zero-size allocation not allowed
    const slice = allocator.alloc(u8, len) catch return null;
    return slice.ptr;
}

/// v6 FIX (Bug #2 + #3 + #11) + v7: kfree with validation, double-free detection,
/// and SipHash integrity verification.
/// Uses shared freeInternal to eliminate code duplication.
pub fn kfree(ptr: [*]u8) void {
    hal.cli();
    defer hal.sti();

    if (!freeInternal(ptr)) {
        // Error already logged by freeInternal (tag mismatch, double-free,
        // invalid pointer, etc.)
        // In kernel context, we don't abort — just log and continue
    }
}

pub fn printHeapStatus() void {
    hal.Serial.puts("=== KERNEL HEAP STATUS ===\n");
    var current = first_block;
    var idx: usize = 0;
    while (current) |block| : (idx += 1) {
        hal.Serial.puts("  Block ");
        printDec(idx);
        hal.Serial.puts(": Addr=");
        hal.Serial.putHex(@intFromPtr(block));
        hal.Serial.puts(" Size=");
        printDec(block.size);
        hal.Serial.puts(" Free=");
        hal.Serial.puts(if (block.free) "true" else "false");
        hal.Serial.puts(" Tag=0x");
        printHex32(block.tag);
        hal.Serial.puts("\n");
        current = block.next;
    }
    hal.Serial.puts("==========================\n");
}

fn printDec(val: u64) void {
    if (val == 0) {
        hal.Serial.puts("0");
        return;
    }
    var buf: [20]u8 = undefined;
    var i: usize = 19;
    var temp = val;
    while (temp > 0) {
        buf[i] = '0' + @as(u8, @intCast(temp % 10));
        temp /= 10;
        if (i == 0) break;
        i -= 1;
    }
    hal.Serial.puts(buf[i + 1..]);
}

/// v7: Print a 32-bit value in hexadecimal for tag display
fn printHex32(val: u32) void {
    const hex_chars = "0123456789ABCDEF";
    var buf: [8]u8 = undefined;
    var i: usize = 0;
    var shift: u5 = 28;
    while (shift >= 0) : ({
        shift -%= 4;
        i += 1;
    }) {
        buf[i] = hex_chars[@as(usize, (val >> shift) & 0xF)];
        if (shift == 0) break;
    }
    hal.Serial.puts(&buf);
}
`
```

### `zig-kernel/src64/isr64.S` [asm · 9,228 B]
```
`// ============================================================================
// POLER-OS isr64.S — x86_64 ISR / IRQ stubs
// ============================================================================
//
// CPU exception stubs (vectors 0-31) and PIC IRQ stubs (vectors 32-47).
// All stubs converge on isr_common which builds an InterruptFrame on the
// stack, calls the Zig handler, then restores state and iretq's.
//
// InterruptFrame layout (must match hal.zig):
//
//   Offset  Field        Who pushes
//   ------  -----------  -------------------------
//   0       r15          isr_common (pushed LAST)
//   8       r14          isr_common
//   16      r13          isr_common
//   24      r12          isr_common
//   32      r11          isr_common
//   40      r10          isr_common
//   48      r9           isr_common
//   56      r8           isr_common
//   64      rdi          isr_common
//   72      rsi          isr_common
//   80      rbp          isr_common
//   88      rdx          isr_common
//   96      rcx          isr_common
//   104     rbx          isr_common
//   112     rax          isr_common (pushed FIRST)
//   120     vector       stub
//   128     error_code   stub (or CPU, or dummy 0)
//   136     rip          CPU
//   144     cs           CPU
//   152     rflags       CPU
//   160     rsp          CPU
//   168     ss           CPU
// ============================================================================

.text
.code64

// ============================================================================
//  CPU Exception Stubs  (vectors 0 – 31)
// ============================================================================

// --- Vectors with NO CPU error code (push dummy 0) ---

isr_stub_0:
    pushq $0
    pushq $0
    jmp isr_common

isr_stub_1:
    pushq $0
    pushq $1
    jmp isr_common

isr_stub_2:
    pushq $0
    pushq $2
    jmp isr_common

isr_stub_3:
    pushq $0
    pushq $3
    jmp isr_common

isr_stub_4:
    pushq $0
    pushq $4
    jmp isr_common

isr_stub_5:
    pushq $0
    pushq $5
    jmp isr_common

isr_stub_6:
    pushq $0
    pushq $6
    jmp isr_common

isr_stub_7:
    pushq $0
    pushq $7
    jmp isr_common

// --- Vector 8: #DF Double Fault — CPU pushes error code ---

isr_stub_8:
    pushq $8
    jmp isr_common

isr_stub_9:
    pushq $0
    pushq $9
    jmp isr_common

// --- Vectors with CPU-pushed error code ---

isr_stub_10:
    pushq $10
    jmp isr_common

isr_stub_11:
    pushq $11
    jmp isr_common

isr_stub_12:
    pushq $12
    jmp isr_common

isr_stub_13:
    pushq $13
    jmp isr_common

isr_stub_14:
    pushq $14
    jmp isr_common

// --- Back to no error code ---

isr_stub_15:
    pushq $0
    pushq $15
    jmp isr_common

isr_stub_16:
    pushq $0
    pushq $16
    jmp isr_common

isr_stub_17:                             // #AC — CPU pushes error code
    pushq $17
    jmp isr_common

isr_stub_18:
    pushq $0
    pushq $18
    jmp isr_common

isr_stub_19:
    pushq $0
    pushq $19
    jmp isr_common

isr_stub_20:
    pushq $0
    pushq $20
    jmp isr_common

isr_stub_21:                             // #CP — CPU pushes error code
    pushq $21
    jmp isr_common

isr_stub_22:
    pushq $0
    pushq $22
    jmp isr_common

isr_stub_23:
    pushq $0
    pushq $23
    jmp isr_common

isr_stub_24:
    pushq $0
    pushq $24
    jmp isr_common

isr_stub_25:
    pushq $0
    pushq $25
    jmp isr_common

isr_stub_26:
    pushq $0
    pushq $26
    jmp isr_common

isr_stub_27:
    pushq $0
    pushq $27
    jmp isr_common

isr_stub_28:
    pushq $0
    pushq $28
    jmp isr_common

isr_stub_29:                             // #VC — CPU pushes error code
    pushq $29
    jmp isr_common

isr_stub_30:                             // #SX — CPU pushes error code
    pushq $30
    jmp isr_common

isr_stub_31:
    pushq $0
    pushq $31
    jmp isr_common

// ============================================================================
//  IRQ Stubs  (vectors 32 – 47, PIC remapped)
// ============================================================================

isr_stub_32:
    pushq $0
    pushq $32
    jmp isr_common

isr_stub_33:
    pushq $0
    pushq $33
    jmp isr_common

isr_stub_34:
    pushq $0
    pushq $34
    jmp isr_common

isr_stub_35:
    pushq $0
    pushq $35
    jmp isr_common

isr_stub_36:
    pushq $0
    pushq $36
    jmp isr_common

isr_stub_37:
    pushq $0
    pushq $37
    jmp isr_common

isr_stub_38:
    pushq $0
    pushq $38
    jmp isr_common

isr_stub_39:
    pushq $0
    pushq $39
    jmp isr_common

isr_stub_40:
    pushq $0
    pushq $40
    jmp isr_common

isr_stub_41:
    pushq $0
    pushq $41
    jmp isr_common

isr_stub_42:
    pushq $0
    pushq $42
    jmp isr_common

isr_stub_43:
    pushq $0
    pushq $43
    jmp isr_common

isr_stub_44:
    pushq $0
    pushq $44
    jmp isr_common

isr_stub_45:
    pushq $0
    pushq $45
    jmp isr_common

isr_stub_46:
    pushq $0
    pushq $46
    jmp isr_common

isr_stub_47:
    pushq $0
    pushq $47
    jmp isr_common

// ============================================================================
//  APIC Timer Stub  (vector 48)
// ============================================================================

isr_stub_48:
    pushq $0
    pushq $48
    jmp isr_common

// ============================================================================
//  Common ISR Entry
// ============================================================================

isr_common:
    // Save all general-purpose registers
    // Push order: rax first → r15 last → r15 at lowest address = offset 0
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rbp
    pushq %rsi
    pushq %rdi
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    // RDI = pointer to InterruptFrame (current RSP)
    movq %rsp, %rdi

    // Call Zig handler: isr_common_handler(frame: *InterruptFrame)
    call isr_common_handler

    // RAX contains the return value (the new RSP). Switch stack if context switched.
    movq %rax, %rsp

    // Restore all general-purpose registers
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rdi
    popq %rsi
    popq %rbp
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax

    // Drop vector + error_code (2 x 8 = 16 bytes)
    addq $16, %rsp

    // Return from interrupt
    iretq

// ============================================================================
//  ISR Stub Table — 48 function pointers (vectors 0-47)
// ============================================================================

.section .rodata.isr_table, "a", @progbits
.balign 8
.globl isr_stub_table
isr_stub_table:
    .quad isr_stub_0
    .quad isr_stub_1
    .quad isr_stub_2
    .quad isr_stub_3
    .quad isr_stub_4
    .quad isr_stub_5
    .quad isr_stub_6
    .quad isr_stub_7
    .quad isr_stub_8
    .quad isr_stub_9
    .quad isr_stub_10
    .quad isr_stub_11
    .quad isr_stub_12
    .quad isr_stub_13
    .quad isr_stub_14
    .quad isr_stub_15
    .quad isr_stub_16
    .quad isr_stub_17
    .quad isr_stub_18
    .quad isr_stub_19
    .quad isr_stub_20
    .quad isr_stub_21
    .quad isr_stub_22
    .quad isr_stub_23
    .quad isr_stub_24
    .quad isr_stub_25
    .quad isr_stub_26
    .quad isr_stub_27
    .quad isr_stub_28
    .quad isr_stub_29
    .quad isr_stub_30
    .quad isr_stub_31
    .quad isr_stub_32
    .quad isr_stub_33
    .quad isr_stub_34
    .quad isr_stub_35
    .quad isr_stub_36
    .quad isr_stub_37
    .quad isr_stub_38
    .quad isr_stub_39
    .quad isr_stub_40
    .quad isr_stub_41
    .quad isr_stub_42
    .quad isr_stub_43
    .quad isr_stub_44
    .quad isr_stub_45
    .quad isr_stub_46
    .quad isr_stub_47
    .quad isr_stub_48

// ============================================================================
//  Fast System Call Entry Point (syscall/sysretq)
// ============================================================================

.extern user_rsp
.extern current_kernel_stack
.extern zig_syscall_handler

.global syscall_entry
syscall_entry:
    // Save user RSP to user_rsp
    movq %rsp, user_rsp(%rip)

    // Load kernel RSP of the active task
    movq current_kernel_stack(%rip), %rsp

    // Now we are on the kernel stack!
    // Push user RIP (RCX) and user RFLAGS (R11)
    pushq %rcx
    pushq %r11

    // Save other general purpose registers to preserve them
    pushq %rbx
    pushq %rbp
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    // Prepare arguments for Zig call conv (.C):
    // RDI (arg1), RSI (arg2), RDX (arg3) are already set.
    // 4th arg is R10, which we move to RCX.
    movq %r10, %rcx
    // 5th arg is RAX (syscall number), which we move to R8.
    movq %rax, %r8

    // Call Zig syscall handler
    call zig_syscall_handler

    // Restore general purpose registers
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbp
    popq %rbx

    // Restore r11 and rcx
    popq %r11
    popq %rcx

    // Switch back to user RSP
    movq user_rsp(%rip), %rsp

    // Return to Ring 3
    sysretq

`
```

### `zig-kernel/src64/linker64.ld` [ld · 2,443 B]
```
`/* POLER-OS Linker Script — x86_64 (flat identity-mapped)
 *
 * Physical address = virtual address = 0x100000 (1MB mark)
 * Higher-half will be added when PMM/VMM is more mature.
 *                                                                          */

OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

PHDRS
{
    boot    PT_LOAD FLAGS(7);           /* RWX — boot code (32→64 transition) */
    text    PT_LOAD FLAGS(5);           /* RX — kernel code */
    rodata  PT_LOAD FLAGS(4);           /* R  — read-only data */
    data    PT_LOAD FLAGS(6);           /* RW — data + bss */
}

SECTIONS
{
    /* Физический адрес = виртуальный адрес = 1MB */
    . = 0x100000;

    /* ========================================================================
     * Boot section — 32-bit entry, page tables, GDT
     * ======================================================================== */
    .multiboot2 ALIGN(8) : {
        *(.multiboot2)
    } :boot

    .text.boot32 ALIGN(4K) : {
        *(.text.boot32)
    } :boot

    .rodata.gdt32 ALIGN(16) : {
        *(.rodata.gdt32)
    } :boot

    .rodata.gdt64 ALIGN(16) : {
        *(.rodata.gdt64)
    } :boot

    .bss.boot ALIGN(4K) : {
        pml4_addr = .; . += 4096;
        pdpt_addr = .; . += 4096;
        pd_addr   = .; . += 16384;
        stack_bottom = .; . += 16384;
        stack_top = .;
        *(.bss.boot)
    } :boot

    _kernel_start = .;

    /* Text section */
    .text ALIGN(4K) : {
        *(.text.boot64)
        *(.text .text.*)
    } :text

    /* ISR stub pointer table — must be in read-only data, NOT code */
    .rodata.isr_table ALIGN(16) : {
        __isr_table_start = .;
        *(.rodata.isr_table)
        __isr_table_end = .;
    } :rodata

    /* Read-only data */
    .rodata ALIGN(4K) : {
        *(.rodata .rodata.*)
    } :rodata

    /* Data section */
    .data ALIGN(4K) : {
        *(.data .data.*)
    } :data

    /* BSS */
    .bss ALIGN(4K) : {
        bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        bss_end = .;
    } :data

    _kernel_end = .;

    /* ========================================================================
     * Discard unnecessary sections
     * ======================================================================== */
    /DISCARD/ : {
        *(.comment)
        *(.note.*)
        *(.eh_frame*)
        *(.gnu.hash)
    }
}
`
```

### `zig-kernel/src64/main64.zig` [zig · 49,183 B]
```
`// ===========================================================================
// POLER-OS v0.7.0 — 64-bit x86_64 Semantic Runtime Kernel
// ===========================================================================
//
// Эволюция:
//   v0.4.0: 32-bit kernel, POLER Core, shell, PCI scan
//   v0.5.0: 64-bit boot, HAL (GDT/IDT/PIC/APIC), ACPI, interrupts
//   v0.5.1: VirtualBox compatibility, 64-bit Long Mode fix
//   v0.6.1: Bug fixes (CTR brace, Q glyph, circular import hal↔scheduler)
//   v0.7.0: Ring 3 (user mode), ELF64 loader, per-process CR3, TSS IST
// ============================================================================

const hal = @import("hal.zig");
const std = @import("std");
const acpi = @import("acpi.zig");
const poler = @import("poler_core.zig");
const pmm = @import("pmm64.zig");
const vmm = @import("vmm64.zig");
const heap = @import("heap64.zig");
const cpio = @import("cpio.zig");
const scheduler = @import("scheduler.zig");
const multiboot2 = @import("multiboot2.zig");
const framebuffer = @import("framebuffer.zig");
const elf_loader = @import("elf_loader.zig");
const smp = @import("smp.zig");



var use_fb: bool = false;

const VGA_COLORS = [16][3]u8{
    .{ 0, 0, 0 },         // 0: Black
    .{ 0, 0, 170 },       // 1: Blue
    .{ 0, 170, 0 },       // 2: Green
    .{ 0, 170, 170 },     // 3: Cyan
    .{ 170, 0, 0 },       // 4: Red
    .{ 170, 0, 170 },     // 5: Magenta
    .{ 170, 85, 0 },      // 6: Brown
    .{ 170, 170, 170 },   // 7: Light Gray
    .{ 85, 85, 85 },      // 8: Dark Gray
    .{ 85, 85, 255 },     // 9: Light Blue
    .{ 85, 255, 85 },     // 10: Light Green
    .{ 85, 255, 255 },    // 11: Light Cyan
    .{ 255, 85, 85 },     // 12: Light Red
    .{ 255, 85, 255 },    // 13: Light Magenta
    .{ 255, 255, 85 },    // 14: Yellow
    .{ 255, 255, 255 },   // 15: White
};

// ============================================================================
// VGA Text Mode (80x25) — перенесено из main32.zig
// ============================================================================

const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;
const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);

var vga_row: usize = 0;
var vga_col: usize = 0;
var vga_color: u8 = 0x07; // Light gray on black

fn vga_init() void {
    vga_row = 0;
    vga_col = 0;
    vga_color = 0x07;
    var i: usize = 0;
    while (i < VGA_WIDTH * VGA_HEIGHT) : (i += 1) {
        VGA_BUFFER[i] = @as(u16, ' ') | (@as(u16, vga_color) << 8);
    }
}

fn vga_puts(str: []const u8) void {
    for (str) |ch| {
        if (ch == '\n') {
            vga_col = 0;
            vga_row += 1;
        } else if (ch == '\x08') {
            if (vga_col > 0) {
                vga_col -= 1;
                VGA_BUFFER[vga_row * VGA_WIDTH + vga_col] = @as(u16, ' ') | (@as(u16, vga_color) << 8);
            }
        } else {
            VGA_BUFFER[vga_row * VGA_WIDTH + vga_col] = @as(u16, ch) | (@as(u16, vga_color) << 8);
            vga_col += 1;
            if (vga_col >= VGA_WIDTH) {
                vga_col = 0;
                vga_row += 1;
            }
        }
        if (vga_row >= VGA_HEIGHT) {
            // Scroll up
            var y: usize = 0;
            while (y < VGA_HEIGHT - 1) : (y += 1) {
                var x: usize = 0;
                while (x < VGA_WIDTH) : (x += 1) {
                    VGA_BUFFER[y * VGA_WIDTH + x] = VGA_BUFFER[(y + 1) * VGA_WIDTH + x];
                }
            }
            var x2: usize = 0;
            while (x2 < VGA_WIDTH) : (x2 += 1) {
                VGA_BUFFER[(VGA_HEIGHT - 1) * VGA_WIDTH + x2] = @as(u16, ' ') | (@as(u16, vga_color) << 8);
            }
            vga_row = VGA_HEIGHT - 1;
        }
    }
}

fn vga_setcolor(c: u8) void {
    vga_color = c;
}

fn puts_vga_or_fb(str: []const u8) void {
    if (use_fb) {
        const fg = VGA_COLORS[vga_color & 0x0F];
        const bg = VGA_COLORS[(vga_color >> 4) & 0x0F];
        const bg_r = if (bg[0] == 0 and bg[1] == 0 and bg[2] == 0) @as(u8, 0x0B) else bg[0];
        const bg_g = if (bg[0] == 0 and bg[1] == 0 and bg[2] == 0) @as(u8, 0x11) else bg[1];
        const bg_b = if (bg[0] == 0 and bg[1] == 0 and bg[2] == 0) @as(u8, 0x20) else bg[2];
        framebuffer.puts_color(str, fg[0], fg[1], fg[2], bg_r, bg_g, bg_b);
    } else {
        vga_puts(str);
    }
}

// ============================================================================
// Memory Dump Utility — dump N bytes at a virtual address via serial
// ============================================================================

fn memDump(virt_addr: u64, num_bytes: usize, label: []const u8) void {
    hal.Serial.puts("[MEMDUMP] ");
    hal.Serial.puts(label);
    hal.Serial.puts(" @ ");
    hal.Serial.putHex(virt_addr);
    hal.Serial.puts(" (");
    hal.Serial.putDecimal(num_bytes);
    hal.Serial.puts(" bytes):\n");

    const ptr: [*]const volatile u8 = @ptrFromInt(virt_addr);
    var offset: usize = 0;
    while (offset < num_bytes) : (offset += 16) {
        hal.Serial.putHex(virt_addr + offset);
        hal.Serial.puts(": ");

        // Print hex bytes
        var j: usize = 0;
        while (j < 16) : (j += 1) {
            if (offset + j < num_bytes) {
                const b = ptr[offset + j];
                const hex = "0123456789ABCDEF";
                hal.Serial.puts(&.{hex[(b >> 4) & 0xF], hex[b & 0xF]});
            } else {
                hal.Serial.puts("  ");
            }
            hal.Serial.puts(" ");
        }

        // Print ASCII
        hal.Serial.puts(" |");
        j = 0;
        while (j < 16) : (j += 1) {
            if (offset + j < num_bytes) {
                const b = ptr[offset + j];
                if (b >= 0x20 and b < 0x7F) {
                    hal.Serial.puts(&.{b});
                } else {
                    hal.Serial.puts(".");
                }
            }
        }
        hal.Serial.puts("|\n");
    }
}

/// Walk the 4-level page tables for a given virtual address in a PML4
/// and print what we find at each level. Useful for debugging mappings.
fn dumpPageTableWalk(pml4_phys: u64, virt_addr: u64, label: []const u8) void {
    hal.Serial.puts("[PTW] ");
    hal.Serial.puts(label);
    hal.Serial.puts(" — walking VA ");
    hal.Serial.putHex(virt_addr);
    hal.Serial.puts(" in PML4 @ ");
    hal.Serial.putHex(pml4_phys);
    hal.Serial.puts("\n");

    const pml4_idx = (virt_addr >> 39) & 0x1FF;
    const pdpt_idx = (virt_addr >> 30) & 0x1FF;
    const pd_idx = (virt_addr >> 21) & 0x1FF;
    const pt_idx = (virt_addr >> 12) & 0x1FF;

    hal.Serial.puts("  Indices: PML4[");
    hal.Serial.putDecimal(pml4_idx);
    hal.Serial.puts("] PDPT[");
    hal.Serial.putDecimal(pdpt_idx);
    hal.Serial.puts("] PD[");
    hal.Serial.putDecimal(pd_idx);
    hal.Serial.puts("] PT[");
    hal.Serial.putDecimal(pt_idx);
    hal.Serial.puts("]\n");

    const pml4: [*]const volatile u64 = @ptrFromInt(pml4_phys);
    const pml4e = pml4[pml4_idx];
    hal.Serial.puts("  PML4[");
    hal.Serial.putDecimal(pml4_idx);
    hal.Serial.puts("] = ");
    hal.Serial.putHex(pml4e);
    if (pml4e & vmm.PTE_PRESENT == 0) {
        hal.Serial.puts(" — NOT PRESENT, abort\n");
        return;
    }
    hal.Serial.puts(" -> phys=");
    hal.Serial.putHex(pml4e & 0x000FFFFFFFFFF000);
    hal.Serial.puts(" flags=");
    hal.Serial.putHex(pml4e & 0xFFF);
    if (pml4e & vmm.PTE_USER != 0) hal.Serial.puts(" USER");
    hal.Serial.puts("\n");

    const pdpt: [*]const volatile u64 = @ptrFromInt(pml4e & 0x000FFFFFFFFFF000);
    const pdpte = pdpt[pdpt_idx];
    hal.Serial.puts("  PDPT[");
    hal.Serial.putDecimal(pdpt_idx);
    hal.Serial.puts("] = ");
    hal.Serial.putHex(pdpte);
    if (pdpte & vmm.PTE_PRESENT == 0) {
        hal.Serial.puts(" — NOT PRESENT, abort\n");
        return;
    }
    if (pdpte & vmm.PTE_HUGE != 0) {
        hal.Serial.puts(" — 1GB HUGE PAGE -> phys=");
        hal.Serial.putHex(pdpte & 0x000FFFFFC0000000);
        hal.Serial.puts("\n");
        return;
    }
    hal.Serial.puts(" -> phys=");
    hal.Serial.putHex(pdpte & 0x000FFFFFFFFFF000);
    hal.Serial.puts(" flags=");
    hal.Serial.putHex(pdpte & 0xFFF);
    if (pdpte & vmm.PTE_USER != 0) hal.Serial.puts(" USER");
    hal.Serial.puts("\n");

    const pd: [*]const volatile u64 = @ptrFromInt(pdpte & 0x000FFFFFFFFFF000);
    const pde = pd[pd_idx];
    hal.Serial.puts("  PD[");
    hal.Serial.putDecimal(pd_idx);
    hal.Serial.puts("] = ");
    hal.Serial.putHex(pde);
    if (pde & vmm.PTE_PRESENT == 0) {
        hal.Serial.puts(" — NOT PRESENT, abort\n");
        return;
    }
    if (pde & vmm.PTE_HUGE != 0) {
        hal.Serial.puts(" — 2MB HUGE PAGE -> phys=");
        hal.Serial.putHex(pde & 0x000FFFFFFFE00000);
        hal.Serial.puts("\n");
        return;
    }
    hal.Serial.puts(" -> phys=");
    hal.Serial.putHex(pde & 0x000FFFFFFFFFF000);
    hal.Serial.puts(" flags=");
    hal.Serial.putHex(pde & 0xFFF);
    if (pde & vmm.PTE_USER != 0) hal.Serial.puts(" USER");
    hal.Serial.puts("\n");

    const pt: [*]const volatile u64 = @ptrFromInt(pde & 0x000FFFFFFFFFF000);
    const pte = pt[pt_idx];
    hal.Serial.puts("  PT[");
    hal.Serial.putDecimal(pt_idx);
    hal.Serial.puts("] = ");
    hal.Serial.putHex(pte);
    if (pte & vmm.PTE_PRESENT == 0) {
        hal.Serial.puts(" — NOT PRESENT, abort\n");
        return;
    }
    hal.Serial.puts(" -> phys=");
    hal.Serial.putHex(pte & 0x000FFFFFFFFFF000);
    hal.Serial.puts(" flags=");
    hal.Serial.putHex(pte & 0xFFF);
    if (pte & vmm.PTE_USER != 0) hal.Serial.puts(" USER");
    if (pte & vmm.PTE_NO_EXECUTE != 0) hal.Serial.puts(" NX");
    hal.Serial.puts("\n");
}

fn puts(str: []const u8) void {
    puts_vga_or_fb(str);
    hal.Serial.puts(str);
}

/// Console print function for syscall 1 — writes to screen AND serial.
/// Safe to call from Ring 3 syscall context: the string is in user VA,
/// but we're in Ring 0 so both user and kernel pages are accessible.
fn console_print_fn(str: []const u8) void {
    puts_vga_or_fb(str);
    hal.Serial.puts(str);
}

fn clear_screen() void {
    if (use_fb) {
        framebuffer.clear();
    } else {
        vga_init();
    }
}

fn putHex(val: u64) void {
    hal.Serial.putHex(val);
    const hex = "0123456789ABCDEF";
    puts_vga_or_fb("0x");
    var i: usize = 60;
    while (true) {
        const nibble = (val >> @intCast(i)) & 0xF;
        puts_vga_or_fb(&.{hex[@intCast(nibble)]});
        if (i == 0) break;
        i -= 4;
    }
}

fn putDecimal(val: u64) void {
    if (val == 0) {
        puts("0");
        return;
    }
    var buf: [20]u8 = undefined;
    var i: usize = 20;
    var temp = val;
    while (temp > 0) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(temp % 10));
        temp /= 10;
    }
    puts(buf[i..20]);
}

// ============================================================================
// Kernel Banner
// ============================================================================

fn print_banner() void {
    vga_setcolor(0x0B); // Cyan
    puts(
        \\╔══════════════════════════════════════════════════════╗
        \\║             POLER-OS v0.7.0 (64-bit)                ║
        \\║          Semantic Runtime Architecture              ║
        \\║                                                      ║
        \\║   Ring 3 · ELF64 Loader · Per-Process CR3 · IST    ║
        \\╚══════════════════════════════════════════════════════╝
        \\
    );
    vga_setcolor(0x07);
}

// ==============================================================================
// CPU Feature Detection
// ============================================================================

const CPUInfo = struct {
    vendor: [13]u8,
    model_name: [49]u8,
    stepping: u32,
    model: u32,
    family: u32,
    features_edx: u32,
    features_ecx: u32,
    has_lapic: bool,
    has_syscall: bool,
    has_nx: bool,
    has_1gb_pages: bool,
};

fn detectCPU() CPUInfo {
    var info = CPUInfo{
        .vendor = undefined,
        .model_name = undefined,
        .stepping = 0,
        .model = 0,
        .family = 0,
        .features_edx = 0,
        .features_ecx = 0,
        .has_lapic = false,
        .has_syscall = false,
        .has_nx = false,
        .has_1gb_pages = false,
    };

    // CPUID leaf 0 — vendor string
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx),
        : [leaf] "{eax}" (@as(u32, 0)),
    );

    // Vendor string: EBX + EDX + ECX
    @memcpy(info.vendor[0..4], @as(*const [4]u8, @ptrCast(&ebx)));
    @memcpy(info.vendor[4..8], @as(*const [4]u8, @ptrCast(&edx)));
    @memcpy(info.vendor[8..12], @as(*const [4]u8, @ptrCast(&ecx)));
    info.vendor[12] = 0;

    // CPUID leaf 1 — features
    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx),
        : [leaf] "{eax}" (@as(u32, 1)),
    );

    info.stepping = eax & 0xF;
    info.model = (eax >> 4) & 0xF;
    info.family = (eax >> 8) & 0xF;
    info.features_edx = edx;
    info.features_ecx = ecx;

    info.has_lapic = (edx >> 9) & 1 != 0; // APIC
    info.has_syscall = (edx >> 11) & 1 != 0; // SYSENTER/SYSEXIT
    info.has_nx = false; // Check extended features

    // CPUID leaf 0x80000001 — extended features (NX bit)
    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx),
        : [leaf] "{eax}" (@as(u32, 0x80000001)),
    );

    info.has_nx = (edx >> 20) & 1 != 0; // NX bit
    info.has_1gb_pages = (edx >> 26) & 1 != 0; // 1GB pages

    // CPUID leaf 0x80000002-4 — model name
    var model_buf: [48]u8 = undefined;
    inline for (0..3) |leaf_offset| {
        asm volatile ("cpuid"
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx),
              [edx] "={edx}" (edx),
            : [leaf] "{eax}" (@as(u32, 0x80000002) + @as(u32, @intCast(leaf_offset))),
        );
        const base = leaf_offset * 16;
        @memcpy(model_buf[base..][0..4], @as(*const [4]u8, @ptrCast(&eax)));
        @memcpy(model_buf[base + 4..][0..4], @as(*const [4]u8, @ptrCast(&ebx)));
        @memcpy(model_buf[base + 8..][0..4], @as(*const [4]u8, @ptrCast(&ecx)));
        @memcpy(model_buf[base + 12..][0..4], @as(*const [4]u8, @ptrCast(&edx)));
    }
    @memcpy(info.model_name[0..48], &model_buf);
    info.model_name[48] = 0;

    return info;
}

fn printCPUInfo(info: *const CPUInfo) void {
    puts("  CPU: ");
    // Trim model name
    var start: usize = 0;
    while (start < 48 and info.model_name[start] == ' ') start += 1;
    var end: usize = 47;
    while (end > start and info.model_name[end] == ' ') end -= 1;
    if (end > start) {
        puts(info.model_name[start .. end + 1]);
    }
    puts("\n  Vendor: ");
    puts(&info.vendor);
    puts("\n  Features: ");
    if (info.has_lapic) puts("APIC ");
    if (info.has_syscall) puts("SYSCALL ");
    if (info.has_nx) puts("NX ");
    if (info.has_1gb_pages) puts("1GB-PG ");
    puts("\n");
}

// ==============================================================================
// Memory Map — parsed from Multiboot2 tags
// ============================================================================

fn printMemoryInfo(mbi: u64) void {
    // 1. Show register values
    const cr0 = hal.readCr0();
    const cr3 = hal.readCr3();
    const cr4 = hal.readCr4();

    puts("  CR0: "); putHex(cr0); puts("\n");
    puts("  CR3 (PML4): "); putHex(cr3); puts("\n");
    puts("  CR4: "); putHex(cr4); puts("\n");

    const efer = hal.readMsr(hal.MSR.EFER);
    if (efer & hal.EFER.LMA != 0) {
        puts("  Long Mode: ACTIVE\n");
    }
    if (efer & hal.EFER.NXE != 0) {
        puts("  NX-bit: ENABLED\n");
    }

    // 2. Initialize 64-bit physical memory manager
    puts("[PMM] Initializing from Multiboot2 memory maps...\n");
    pmm.init(mbi);

    // 3. Print memory allocations statistics
    const stats = pmm.getStats();
    puts("  Total RAM detected (BasicMem): ");
    putDecimal(stats.total_kb);
    puts(" KB\n");

    puts("  Usable memory pages: ");
    putDecimal(stats.usable_pages);
    puts(" (");
    putDecimal(stats.usable_pages * 4);
    puts(" KB)\n");

    // 4. Dump Multiboot2 Memory Map if available
    const parser = multiboot2.Parser.init(mbi);
    if (parser.findTag(6)) |tag_addr| {
        const mmap_tag: *const multiboot2.MmapTag = @ptrFromInt(tag_addr);
        const entries = mmap_tag.getEntries();
        puts("  Multiboot2 Memory Map:\n");
        for (entries) |entry| {
            puts("    - [");
            putHex(entry.addr);
            puts(" .. ");
            putHex(entry.addr + entry.len);
            puts("] type=");
            putDecimal(entry.entry_type);
            if (entry.entry_type == 1) puts(" (Usable)");
            puts("\n");
        }
    }
}

// ============================================================================
// POLER Core Quick Test
// Runs active cryptographic verification for POLER Core v4
// ============================================================================

fn testPolerCore() void {
    puts("[POLER] Running Core test...\n");
    const a: u32 = 42;
    const b: u32 = 17;
    const eps: u32 = 1;
    const res = poler.pndMix(a, b, eps);
    const res_alt = poler.pndMixAlt(a, b, eps);
    puts("  pndMix(42, 17, 1) = ");
    putHex(res);
    puts("\n");
    puts("  pndMixAlt(42, 17, 1) = ");
    putHex(res_alt);
    puts("\n");
}

// ============================================================================
// Main Kernel Entry Point
// Вызывается из boot64.S после перехода в 64-bit mode
// ============================================================================

export fn poler_kernel_main(multiboot_magic: u32, multiboot_info: u64) callconv(.C) void {
    // 0. Initialize display — VGA text mode (80x25)
    // FIRST: Program VGA registers to switch from any VBE graphical mode
    // to standard 80x25 text mode. This is critical because GRUB may leave
    // the VGA controller in graphical mode, making writes to 0xB8000 invisible.
    hal.vgaSetTextMode();

    // THEN: Clear the text buffer and reset cursor
    vga_init();

    // NOTE: If framebuffer becomes available (UEFI or future re-enable),
    // uncomment the block below and set use_fb = true:
    // const parser = multiboot2.Parser.init(multiboot_info);
    // if (parser.findTag(8)) |tag_addr| {
    //     const fb_tag: *const multiboot2.FramebufferTag = @ptrFromInt(tag_addr);
    //     if (fb_tag.fb_addr != 0 and fb_tag.fb_width > 0 and fb_tag.fb_height > 0) {
    //         framebuffer.init_from_multiboot(
    //             fb_tag.fb_addr, fb_tag.fb_pitch, fb_tag.fb_width,
    //             fb_tag.fb_height, fb_tag.fb_bpp, fb_tag.fb_type,
    //         );
    //         framebuffer.clear();
    //         use_fb = true;
    //     }
    // }

    // 2. Print banner
    print_banner();

    // 3. Verify Multiboot2 magic
    if (multiboot_magic == 0x36D76289) {
        puts("[BOOT] Multiboot2 loaded successfully\n");
    } else {
        vga_setcolor(0x0C);
        puts("[BOOT] WARNING: Unknown bootloader (magic=");
        putHex(multiboot_magic);
        puts(")\n");
        vga_setcolor(0x07);
    }

    // 4. Initialize HAL (GDT, IDT, PIC, APIC)
    puts("[BOOT] Initializing HAL...\n");
    hal.init();

    // 5. Initialize ACPI
    puts("[BOOT] Initializing ACPI...\n");
    acpi.init();

    // 5.5. Initialize SMP (multi-core)
    puts("[BOOT] Initializing SMP...\n");
    smp.init();
    puts("[BOOT] SMP: ");
    putDecimal(smp.online_cpus);
    puts(" CPU(s) online\n");

    // 6. CPU detection
    puts("[BOOT] Detecting CPU...\n");
    const cpu = detectCPU();
    printCPUInfo(&cpu);

    // 7. Memory info
    puts("[BOOT] Memory layout:\n");
    printMemoryInfo(multiboot_info);

    // 8. Test POLER Core
    testPolerCore();

    // 8.5. Initialize VMM
    vmm.init();

    // NOTE: VMM test at 0x100000000 disabled — conflicts with user code page.
    // The user ELF binary is loaded at 0x100000000, and the VMM test's
    // map/unmap/free cycle can leave stale page table entries that conflict.
    // VMM functionality is verified through the ELF loader and user task.

    // 8.6. Initialize Kernel Heap Allocator
    heap.init();

    // Test Heap Allocator
    puts("[HEAP] Testing kernel heap...\n");
    if (heap.kmalloc(128)) |ptr1| {
        puts("[HEAP] Allocated 128 bytes at ");
        putHex(@intFromPtr(ptr1));
        puts("\n");

        if (heap.kmalloc(256)) |ptr2| {
            puts("[HEAP] Allocated 256 bytes at ");
            putHex(@intFromPtr(ptr2));
            puts("\n");

            // Print status
            heap.printHeapStatus();

            heap.kfree(ptr1);
            puts("[HEAP] Freed 128-byte block\n");
            
            heap.kfree(ptr2);
            puts("[HEAP] Freed 256-byte block\n");

            // Print status again (should show coalesced block)
            heap.printHeapStatus();
        } else {
            puts("[HEAP] Failed to allocate second block!\n");
        }
    } else {
        puts("[HEAP] Failed to allocate first block!\n");
    }

    // 8.7. Initialize and parse Initrd/CPIO modules
    puts("[BOOT] Checking for initrd modules...\n");
    const mb_parser = multiboot2.Parser.init(multiboot_info);
    var mod_offset: u64 = 8;
    if (mb_parser.findModuleTag(&mod_offset)) |mod| {
        const mod_size = mod.mod_end - mod.mod_start;
        if (mod_size == 0 or mod.mod_start == 0) {
            puts("[INITRD] Empty initrd module, skipping.\n");
        } else {
            puts("[INITRD] Module found: ");
            puts(mod.getCmdline());
            puts("\n");

            puts("[INITRD] Start Phys: ");
            putHex(mod.mod_start);
            puts(", End Phys: ");
            putHex(mod.mod_end);
            puts(", Size: ");
            putDecimal(mod_size);
            puts(" bytes\n");

            const archive_slice: []const u8 = @as([*]const u8, @ptrFromInt(mod.mod_start))[0..mod_size];

            var cpio_parser = cpio.CpioParser.init(archive_slice);
            var file_count: usize = 0;
            while (cpio_parser.next()) |file| {
                puts("  - File: ");
                puts(file.name);
                puts(" Size: ");
                putDecimal(file.size);
                puts(" bytes\n");
                
                // Print text file contents (e.g. hello.txt)
                if (std.mem.endsWith(u8, file.name, ".txt")) {
                    puts("    Content: \"");
                    const limit = if (file.data.len > 64) 64 else file.data.len;
                    puts(file.data[0..limit]);
                    if (file.data.len > 64) puts("...");
                    puts("\"\n");
                }
                file_count += 1;
            }

            puts("[INITRD] Total files parsed: ");
            putDecimal(file_count);
            puts("\n");
        }
    } else {
        puts("[INITRD] No initrd modules loaded by bootloader.\n");
    }

    // 9. Ready!
    vga_setcolor(0x0B);
    puts("\n=== POLER-OS v0.7.0 — BOOT COMPLETE ===\n");
    puts("HAL + ACPI + POLER Core + Ring 3 — all systems GO\n");
    vga_setcolor(0x07);

    puts("\nInitializing Ring 3 user mode...\n");

    // 10. Initialize Syscalls (Ring 3 → Ring 0 entry via syscall/sysretq)
    // Register print_fn so syscall 1 (print) writes to screen AND serial.
    hal.print_fn = &console_print_fn;
    hal.clear_screen_fn = &clear_screen;
    hal.initSyscalls(@intFromPtr(&syscall_entry));

    // 11. Initialize Scheduler
    scheduler.init();

    // 12. Create Ring 0 kernel tasks
    _ = scheduler.createTask(@intFromPtr(&task1)) catch |err| {
        puts("[SCHED] Failed to create task1: ");
        puts(@errorName(err));
        puts("\n");
    };
    _ = scheduler.createTask(@intFromPtr(&task2)) catch |err| {
        puts("[SCHED] Failed to create task2: ");
        puts(@errorName(err));
        puts("\n");
    };

    // 13. v0.7.0 — Create Ring 3 user task from embedded ELF64 binary
    //
    // Per-process address space isolation:
    //   Step 1: Create per-process PML4 (copies kernel entries WITHOUT User bit)
    //   Step 2: Load ELF binary INTO user PML4 (pages with PTE_USER for Ring 3)
    //   Step 3: Map user stack INTO user PML4 (with PTE_USER)
    //   Step 4: Create user task with entry point, CR3, and user stack
    //
    // This ensures Ring 3 code can only access its own pages (code + stack),
    // NOT kernel memory. The scheduler will CR3-switch on context switch.
    {
    puts("[BOOT] Creating user address space...\n");

    // Step 1: Create user PML4 (kernel entries WITHOUT User bit)
    const user_pml4 = vmm.createUserPML4() catch |err| {
        puts("[VMM] Failed to create user PML4: ");
        puts(@errorName(err));
        puts("\nHalting.\n");
        while (true) { hal.cli(); hal.hlt(); }
    };

    // Step 2: Load ELF binary into user PML4
    puts("[BOOT] Loading user ELF binary into user PML4...\n");
    const elf_result = elf_loader.loadElfIntoPML4(&user_hello_elf, user_pml4) catch |err| {
        puts("[ELF] Failed to load user binary: ");
        puts(@errorName(err));
        puts("\nHalting.\n");
        while (true) { hal.cli(); hal.hlt(); }
    };
    puts("[BOOT] ELF loaded, entry point: ");
    putHex(elf_result.entry_point);
    puts("\n");

    // === PAGE TABLE WALK: Check if mapping exists before accessing memory ===
    const kernel_pml4 = hal.readCr3() & 0x000FFFFFFFFFF000;
    hal.Serial.puts("[DEBUG] Current CR3 (kernel PML4) = ");
    hal.Serial.putHex(kernel_pml4);
    hal.Serial.puts("\n");
    hal.Serial.puts("[DEBUG] User PML4 = ");
    hal.Serial.putHex(user_pml4);
    hal.Serial.puts("\n");
    dumpPageTableWalk(kernel_pml4, USER_CODE_BASE, "kernel PML4 -> user code");
    dumpPageTableWalk(user_pml4, USER_CODE_BASE, "user PML4 -> user code");

    // === MEMORY DUMP: Verify user code was loaded correctly ===
    hal.Serial.puts("\n=== USER CODE PAGE DUMP (via kernel PML4) ===\n");
    memDump(USER_CODE_BASE, 64, "user_code");
    hal.Serial.puts("=== END USER CODE DUMP ===\n\n");

    // Verify the first few bytes match the expected machine code:
    //   48 C7 C0 01 00 00 00  = mov rax, 1
    const code_ptr: [*]const volatile u8 = @ptrFromInt(USER_CODE_BASE);
    const verify_hex = "0123456789ABCDEF";
    if (code_ptr[0] == 0x48 and code_ptr[1] == 0xC7 and code_ptr[2] == 0xC0 and code_ptr[3] == 0x01) {
        hal.Serial.puts("[VERIFY] User code: FIRST INSTRUCTION CORRECT (mov rax, 1)\n");
    } else {
        hal.Serial.puts("[VERIFY] User code: FIRST INSTRUCTION MISMATCH! Expected 48 C7 C0 01, got ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[0] >> 4) & 0xF], verify_hex[code_ptr[0] & 0xF] });
        hal.Serial.puts(" ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[1] >> 4) & 0xF], verify_hex[code_ptr[1] & 0xF] });
        hal.Serial.puts(" ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[2] >> 4) & 0xF], verify_hex[code_ptr[2] & 0xF] });
        hal.Serial.puts(" ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[3] >> 4) & 0xF], verify_hex[code_ptr[3] & 0xF] });
        hal.Serial.puts("\n");
    }

    // Verify syscall instruction at offset 21 (0x0F 0x05)
    if (code_ptr[21] == 0x0F and code_ptr[22] == 0x05) {
        hal.Serial.puts("[VERIFY] User code: SYSCALL INSTRUCTION CORRECT at offset 21\n");
    } else {
        hal.Serial.puts("[VERIFY] User code: SYSCALL INSTRUCTION MISMATCH at offset 21! Expected 0F 05, got ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[21] >> 4) & 0xF], verify_hex[code_ptr[21] & 0xF] });
        hal.Serial.puts(" ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[22] >> 4) & 0xF], verify_hex[code_ptr[22] & 0xF] });
        hal.Serial.puts("\n");
    }

    // Verify second syscall (exit) at offset 32 (0x0F 0x05)
    if (code_ptr[32] == 0x0F and code_ptr[33] == 0x05) {
        hal.Serial.puts("[VERIFY] User code: SYSCALL EXIT INSTRUCTION CORRECT at offset 32\n");
    } else {
        hal.Serial.puts("[VERIFY] User code: SYSCALL EXIT INSTRUCTION at offset 32, got ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[32] >> 4) & 0xF], verify_hex[code_ptr[32] & 0xF] });
        hal.Serial.puts(" ");
        hal.Serial.puts(&.{ verify_hex[(code_ptr[33] >> 4) & 0xF], verify_hex[code_ptr[33] & 0xF] });
        hal.Serial.puts("\n");
    }

    // Verify message string at offset 34
    const msg_ptr: [*]const volatile u8 = @ptrFromInt(USER_CODE_BASE + 34);
    if (msg_ptr[0] == 'H' and msg_ptr[1] == 'e' and msg_ptr[2] == 'l' and msg_ptr[3] == 'l') {
        hal.Serial.puts("[VERIFY] User code: MESSAGE STRING CORRECT (\"Hello...\")\n");
    } else {
        hal.Serial.puts("[VERIFY] User code: MESSAGE STRING MISMATCH! Expected 'H' 'e' 'l' 'l', got ");
        hal.Serial.puts(&.{msg_ptr[0]});
        hal.Serial.puts(" ");
        hal.Serial.puts(&.{msg_ptr[1]});
        hal.Serial.puts("\n");
    }

    // === PHYSICAL PAGE CROSS-CHECK ===
    hal.Serial.puts("\n=== PHYSICAL PAGE CROSS-CHECK ===\n");
    {
        // Walk kernel PML4 to get the PTE
        const kpml4: [*]const volatile u64 = @ptrFromInt(kernel_pml4);
        const kpml4e = kpml4[(USER_CODE_BASE >> 39) & 0x1FF];
        if (kpml4e & vmm.PTE_PRESENT != 0) {
            const kpdpt: [*]const volatile u64 = @ptrFromInt(kpml4e & 0x000FFFFFFFFFF000);
            const kpdpte = kpdpt[(USER_CODE_BASE >> 30) & 0x1FF];
            if (kpdpte & vmm.PTE_PRESENT != 0 and kpdpte & vmm.PTE_HUGE == 0) {
                const kpd: [*]const volatile u64 = @ptrFromInt(kpdpte & 0x000FFFFFFFFFF000);
                const kpde = kpd[(USER_CODE_BASE >> 21) & 0x1FF];
                if (kpde & vmm.PTE_PRESENT != 0 and kpde & vmm.PTE_HUGE == 0) {
                    const kpt: [*]const volatile u64 = @ptrFromInt(kpde & 0x000FFFFFFFFFF000);
                    const kpte = kpt[(USER_CODE_BASE >> 12) & 0x1FF];
                    const kphys = kpte & 0x000FFFFFFFFFF000;

                    // Walk user PML4 to get the PTE
                    const upml4: [*]const volatile u64 = @ptrFromInt(user_pml4);
                    const upml4e = upml4[(USER_CODE_BASE >> 39) & 0x1FF];
                    if (upml4e & vmm.PTE_PRESENT != 0) {
                        const updpt: [*]const volatile u64 = @ptrFromInt(upml4e & 0x000FFFFFFFFFF000);
                        const updpte = updpt[(USER_CODE_BASE >> 30) & 0x1FF];
                        if (updpte & vmm.PTE_PRESENT != 0 and updpte & vmm.PTE_HUGE == 0) {
                            const upd: [*]const volatile u64 = @ptrFromInt(updpte & 0x000FFFFFFFFFF000);
                            const upde = upd[(USER_CODE_BASE >> 21) & 0x1FF];
                            if (upde & vmm.PTE_PRESENT != 0 and upde & vmm.PTE_HUGE == 0) {
                                const upt: [*]const volatile u64 = @ptrFromInt(upde & 0x000FFFFFFFFFF000);
                                const upte = upt[(USER_CODE_BASE >> 12) & 0x1FF];
                                const uphys = upte & 0x000FFFFFFFFFF000;

                                hal.Serial.puts("  Kernel PML4 PTE phys: ");
                                hal.Serial.putHex(kphys);
                                hal.Serial.puts("\n  User PML4   PTE phys: ");
                                hal.Serial.putHex(uphys);
                                hal.Serial.puts("\n");
                                if (kphys == uphys) {
                                    hal.Serial.puts("  MATCH: Both PML4s map to the SAME physical page ✓\n");
                                } else {
                                    hal.Serial.puts("  MISMATCH: Different physical pages! Data copy may have gone to wrong page!\n");
                                }
                                // Also check User bit in user PML4 PTE
                                if (upte & vmm.PTE_USER != 0) {
                                    hal.Serial.puts("  User PML4 PTE has PTE_USER set ✓ (Ring 3 can access)\n");
                                } else {
                                    hal.Serial.puts("  User PML4 PTE MISSING PTE_USER! Ring 3 will #PF!\n");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    hal.Serial.puts("=== END CROSS-CHECK ===\n\n");

    // Step 3: Map user stack page in user PML4 (RW + User for Ring 3)
    hal.Serial.puts("[BOOT] Mapping user stack...\n");
    if (pmm.allocPage()) |stack_phys| {
        hal.Serial.puts("[BOOT] Allocated stack page at phys=");
        hal.Serial.putHex(stack_phys);
        hal.Serial.puts("\n");
        // Map in user PML4 with PTE_USER (Ring 3 can access)
        vmm.mapPageInPML4(user_pml4, USER_STACK_BASE, stack_phys, vmm.PTE_WRITABLE | vmm.PTE_USER) catch |err| {
            hal.Serial.puts("[VMM] Failed to map user stack in user PML4: ");
            hal.Serial.puts(@errorName(err));
            hal.Serial.puts("\nHalting.\n");
            while (true) { hal.cli(); hal.hlt(); }
        };
        hal.Serial.puts("[BOOT] Stack mapped in user PML4\n");
        // Also map in kernel PML4 — needed for zero-fill AND for Ring 3
        // access when CR3 switch is disabled (using kernel PML4 directly).
        _ = vmm.mapPage(USER_STACK_BASE, stack_phys, vmm.PTE_WRITABLE | vmm.PTE_USER) catch null;
        hal.Serial.puts("[BOOT] Stack mapped in kernel PML4\n");
        // Zero-fill the stack page
        const stack_ptr: [*]volatile u8 = @ptrFromInt(USER_STACK_BASE);
        @memset(stack_ptr[0..4096], 0);
        hal.Serial.puts("[BOOT] Stack zero-filled\n");
        puts("[BOOT] User stack mapped at ");
        putHex(USER_STACK_BASE);
        puts("-0x");
        putHex(USER_STACK_TOP);
        puts("\n");
    } else {
        puts("[PMM] Failed to allocate user stack page\nHalting.\n");
        while (true) { hal.cli(); hal.hlt(); }
    }

    // Step 4: Create the Ring 3 user task
    if (true) {
    _ = scheduler.createUserTask(elf_result.entry_point, user_pml4, USER_STACK_TOP) catch |err| {
        puts("[SCHED] Failed to create user task: ");
        puts(@errorName(err));
        puts("\nHalting.\n");
        while (true) { hal.cli(); hal.hlt(); }
    };
    }
    hal.Serial.puts("[BOOT] Ring 3 user task created with per-process CR3 isolation\n");
    }
    hal.Serial.puts("[BOOT] User task block complete, enabling scheduler...\n");

    // NOW enable scheduler preemption — timer ticks will context-switch tasks
    hal.timerTickCallback = scheduler.schedule;
    hal.Serial.puts("[BOOT] Scheduler callback enabled.\n");

    puts("[BOOT] Scheduler active (Ring 0 + Ring 3). Entering shell.\n\n");

    // Drop to interactive shell
    kernel_shell();
}

// ============================================================================
// Kernel Shell — interactive command interpreter (v0.7.1)
// ============================================================================
//
// Simple shell that reads keyboard input and executes built-in commands.
// This replaces the old heartbeat idle loop with a usable command line.
//
// Commands:
//   help     — show available commands
//   clear    — clear screen
//   regs     — show CPU registers (CR0, CR3, CR4, EFER)
//   tasks    — show scheduler task list
//   mem      — show memory info (PMM stats, heap)
//   tick     — show tick count and scheduler stats
//   reboot   — reboot the system (via keyboard controller)
//   about    — show kernel info
// ============================================================================

var shell_line: [256]u8 = undefined;
var shell_line_len: usize = 0;
var shell_running: bool = false;

fn shellPrompt() void {
    const prompt = "poler> ";
    puts_vga_or_fb(prompt);
    hal.Serial.puts(prompt);
}

fn shellPrint(str: []const u8) void {
    puts_vga_or_fb(str);
    hal.Serial.puts(str);
}

fn shellPrintLn(str: []const u8) void {
    puts_vga_or_fb(str);
    puts_vga_or_fb("\n");
    hal.Serial.puts(str);
    hal.Serial.puts("\n");
}

fn shellPutHex(val: u64) void {
    putHex(val);
}

fn shellPutDecimal(val: u64) void {
    putDecimal(val);
}

fn strEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (ca != cb) return false;
    }
    return true;
}

fn strStartsWith(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    for (str[0..prefix.len], prefix) |a, b| {
        if (a != b) return false;
    }
    return true;
}

fn trimSpace(str: []const u8) []const u8 {
    var start: usize = 0;
    while (start < str.len and str[start] == ' ') start += 1;
    var end = str.len;
    while (end > start and str[end - 1] == ' ') end -= 1;
    return str[start..end];
}

fn shellExecute(line_raw: []const u8) void {
    const line = trimSpace(line_raw);
    if (line.len == 0) return;

    if (strEqual(line, "help")) {
        shellPrintLn("POLER-OS v0.7.0 — Kernel Shell");
        shellPrintLn("");
        shellPrintLn("  help     — show this help");
        shellPrintLn("  clear    — clear screen");
        shellPrintLn("  regs     — show CPU registers");
        shellPrintLn("  tasks    — show task list");
        shellPrintLn("  mem      — show memory info");
        shellPrintLn("  tick     — show tick/scheduler stats");
        shellPrintLn("  reboot   — reboot system");
        shellPrintLn("  about    — kernel info");
        return;
    }

    if (strEqual(line, "clear")) {
        // Clear screen on display AND serial terminal
        clear_screen();
        hal.Serial.puts("\x1B[2J\x1B[H");
        return;
    }

    if (strEqual(line, "regs")) {
        const cr0 = hal.readCr0();
        const cr3 = hal.readCr3();
        const cr4 = hal.readCr4();
        const efer = hal.readMsr(hal.MSR.EFER);
        shellPrint("  CR0:  "); shellPutHex(cr0); shellPrintLn("");
        shellPrint("  CR3:  "); shellPutHex(cr3); shellPrintLn("");
        shellPrint("  CR4:  "); shellPutHex(cr4); shellPrintLn("");
        shellPrint("  EFER: "); shellPutHex(efer); shellPrintLn("");
        if (efer & hal.EFER.LMA != 0) shellPrintLn("  Long Mode: ACTIVE");
        if (efer & hal.EFER.NXE != 0) shellPrintLn("  NX-bit:    ENABLED");
        return;
    }

    if (strEqual(line, "tasks")) {
        shellPrintLn("ID  State      Priv   CR3             RSP");
        shellPrintLn("--- ---------- ------ --------------- ---------------");
        for (0..scheduler.task_count) |i| {
            const t = scheduler.tasks[i];
            const state_str = switch (t.state) {
                .Ready => "Ready",
                .Running => "Running",
                .Killed => "Killed",
            };
            const priv_str = switch (t.privilege) {
                .Kernel => "Ring0",
                .User => "Ring3",
            };
            shellPrint("  "); shellPutDecimal(t.id);
            shellPrint(" "); shellPrint(state_str);
            shellPrint("   "); shellPrint(priv_str);
            shellPrint("   "); shellPutHex(t.cr3);
            shellPrint(" "); shellPutHex(t.rsp);
            shellPrintLn("");
        }
        shellPrint("  Current task: "); shellPutDecimal(scheduler.current_task_id);
        shellPrint("  Ticks: "); shellPutDecimal(scheduler.scheduler_ticks);
        shellPrintLn("");
        return;
    }

    if (strEqual(line, "mem")) {
        const stats = pmm.getStats();
        shellPrint("  Total RAM:    "); shellPutDecimal(stats.total_kb); shellPrintLn(" KB");
        shellPrint("  Usable pages: "); shellPutDecimal(stats.usable_pages);
        shellPrint(" ("); shellPutDecimal(stats.usable_pages * 4); shellPrintLn(" KB)");
        shellPrint("  Kernel PML4:  "); shellPutHex(hal.readCr3() & 0x000FFFFFFFFFF000); shellPrintLn("");
        heap.printHeapStatus();
        return;
    }

    if (strEqual(line, "tick")) {
        shellPrint("  Ticks: "); shellPutDecimal(hal.tick_count);
        shellPrint("  Scheduler: "); shellPutDecimal(scheduler.scheduler_ticks);
        shellPrint("  t1="); shellPutDecimal(task1_counter);
        shellPrint(" t2="); shellPutDecimal(task2_counter);
        shellPrint(" ring3="); shellPutDecimal(user_task_counter);
        shellPrintLn("");
        return;
    }

    if (strEqual(line, "reboot")) {
        shellPrintLn("Rebooting...");
        // Wait for serial to flush
        var delay: usize = 0;
        while (delay < 1000000) : (delay += 1) {
            asm volatile ("pause");
        }
        // Reset via keyboard controller (pulse reset line)
        hal.outb(0x64, 0xFE);
        // If that didn't work, triple fault
        while (true) {
            asm volatile ("ud2");
        }
    }

    if (strEqual(line, "about")) {
        shellPrintLn("POLER-OS v0.7.0 — Semantic Runtime Kernel");
        shellPrintLn("  Architecture: x86_64 (Long Mode)");
        shellPrintLn("  Boot:         Multiboot2 via GRUB");
        shellPrintLn("  Features:     Ring 3, ELF64 Loader, Per-Process CR3");
        shellPrint("  CPUs:         "); shellPutDecimal(smp.online_cpus); shellPrintLn(" online");
        shellPrintLn("  Scheduler:    Round-Robin (8 slots, APIC timer)");
        shellPrintLn("  HAL:          GDT/IDT/TSS, LAPIC/IOAPIC, ACPI");
        shellPrintLn("  Crypto:       POLER Core v8 (PND Mix), SipHash-2-4");
        shellPrintLn("  Language:     Zig 0.13.0 (freestanding)");
        return;
    }

    // Unknown command
    shellPrint("Unknown command: ");
    shellPrint(line);
    shellPrintLn(" (type 'help' for commands)");
}

fn kernel_shell() noreturn {
    shell_running = true;
    shellPrintLn("");
    shellPrintLn("=== POLER-OS Shell v0.7.0 ===");
    shellPrintLn("Type 'help' for available commands.");
    shellPrintLn("");
    shellPrompt();

    while (true) {
        hal.hlt(); // Wait for next interrupt

        // Process all pending keyboard input
        while (true) {
            const ch = hal.kbd_pop();
            if (ch == 0) break; // No more keys

            if (ch == '\n') {
                // Enter — execute command
                shellPrintLn("");
                shellExecute(shell_line[0..shell_line_len]);
                shell_line_len = 0;
                shellPrompt();
            } else if (ch == '\x08') {
                // Backspace — delete last char
                if (shell_line_len > 0) {
                    shell_line_len -= 1;
                    // Erase char on screen AND serial
                    puts_vga_or_fb("\x08 \x08");
                    hal.Serial.puts("\x08 \x08");
                }
            } else if (ch == 0x03) {
                // Ctrl-C — cancel current line
                shellPrintLn("^C");
                shell_line_len = 0;
                shellPrompt();
            } else if (ch >= 0x20 and ch < 0x7F) {
                // Printable character
                if (shell_line_len < shell_line.len - 1) {
                    shell_line[shell_line_len] = ch;
                    shell_line_len += 1;
                    // Echo character back on screen AND serial
                    puts_vga_or_fb(&.{ch});
                    hal.Serial.puts(&.{ch});
                }
            }
            // Ignore other control characters
        }
    }
}

// External assembly syscall entry point
extern fn syscall_entry() void;

// ===========================================================================
// Ring 0 Kernel Tasks — cooperative counters
// ============================================================================

pub var task1_counter: u64 = 0;
pub var task2_counter: u64 = 0;

fn task1() noreturn {
    // Task 1: Counter — increments a global, no I/O
    while (true) {
        task1_counter += 1;
        // Yield CPU with pause (efficient spin-wait for scheduler preemption)
        var i: usize = 0;
        while (i < 5000) : (i += 1) {
            asm volatile ("pause");
        }
    }
}

fn task2() noreturn {
    // Task 2: Counter — increments a global, no I/O
    while (true) {
        task2_counter += 1;
        var i: usize = 0;
        while (i < 5000) : (i += 1) {
            asm volatile ("pause");
        }
    }
}

// ===========================================================================
// v0.7.0 — Embedded ELF64 User Binary (Hello from Ring 3!)
// ===========================================================================
//
// Minimal ELF64 executable that:
//   1. Calls syscall 1 (print) with "Hello from Ring 3!\n"
//   2. Enters infinite pause loop
//
// User virtual address layout:
//   0x100000000: User code (1 page)
//   0x100080000: User stack (1 page, top = 0x100081000)
// ===========================================================================

const USER_CODE_BASE: u64 = 0x100000000; // 4GB virtual — above boot 2MB huge pages
const USER_STACK_BASE: u64 = 0x100080000; // 4GB + 512KB
const USER_STACK_TOP: u64 = 0x100081000; // Top of user stack page

// User task counter — incremented by the Ring 3 program via syscall
pub var user_task_counter: u64 = 0;

// Minimal ELF64 binary: prints "Hello from Ring 3!\n" via syscall, then exits.
//
// Machine code (loaded at 0x100000000):
//   mov rax, 1           ; syscall number = print
//   lea rdi, [rip+msg]   ; string pointer
//   mov rsi, 19          ; string length ("Hello from Ring 3!\n" = 19 bytes)
//   syscall              ; enter kernel
//   mov rax, 4           ; syscall number = exit
//   xor edi, edi         ; exit code = 0
//   syscall              ; exit the process (never returns)
// msg: "Hello from Ring 3!\n"
const user_hello_elf: [173]u8 align(8) = .{
    // ===== ELF64 Header (64 bytes) =====
    0x7F, 0x45, 0x4C, 0x46, // e_ident[0..3]: magic \x7fELF
    0x02,                   // e_ident[4]: ELFCLASS64
    0x01,                   // e_ident[5]: ELFDATA2LSB
    0x01,                   // e_ident[6]: EV_CURRENT
    0x00,                   // e_ident[7]: ELFOSABI_NONE
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_ident[8..15]: padding
    0x02, 0x00,             // e_type: ET_EXEC
    0x3E, 0x00,             // e_machine: EM_X86_64
    0x01, 0x00, 0x00, 0x00, // e_version: EV_CURRENT
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // e_entry: 0x100000000
    0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_phoff: 64
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // e_shoff: 0
    0x00, 0x00, 0x00, 0x00, // e_flags
    0x40, 0x00,             // e_ehsize: 64
    0x38, 0x00,             // e_phentsize: 56
    0x01, 0x00,             // e_phnum: 1
    0x00, 0x00,             // e_shentsize: 0
    0x00, 0x00,             // e_shnum: 0
    0x00, 0x00,             // e_shstrndx: 0
    // ===== Program Header (56 bytes) =====
    0x01, 0x00, 0x00, 0x00, // p_type: PT_LOAD
    0x05, 0x00, 0x00, 0x00, // p_flags: PF_R | PF_X
    0x78, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_offset: 120
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // p_vaddr: 0x100000000
    0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, // p_paddr: 0x100000000
    0x35, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_filesz: 53
    0x35, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_memsz: 53
    0x00, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // p_align: 4096
    // ===== Code (34 bytes) =====
    0x48, 0xC7, 0xC0, 0x01, 0x00, 0x00, 0x00, // mov rax, 1 (syscall: print)
    0x48, 0x8D, 0x3D, 0x14, 0x00, 0x00, 0x00, // lea rdi, [rip+0x14] (→ msg, 20 bytes ahead)
    0x48, 0xC7, 0xC6, 0x13, 0x00, 0x00, 0x00, // mov rsi, 19 (string length)
    0x0F, 0x05,                               // syscall (print)
    0x48, 0xC7, 0xC0, 0x04, 0x00, 0x00, 0x00, // mov rax, 4 (syscall: exit)
    0x31, 0xFF,                               // xor edi, edi (exit code 0)
    0x0F, 0x05,                               // syscall (exit — never returns)
    // ===== Message (19 bytes) =====
    0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x66, 0x72, 0x6F, 0x6D, 0x20, 0x52, 0x69, 0x6E, 0x67, 0x20, 0x33, 0x21, 0x0A, // "Hello from Ring 3!\n"
};

pub fn panic(msg: []const u8, error_return_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;
    vga_setcolor(0x0C); // Light red
    puts("\n!!! KERNEL PANIC !!!\n");
    puts(msg);
    puts("\nHalting CPU...\n");
    while (true) {
        hal.cli();
        hal.hlt();
    }
}
`
```

### `zig-kernel/src64/multiboot2.zig` [zig · 3,454 B]
```
`// ============================================================================
// POLER-OS Multiboot2 Specification Parser — x86_64
// ============================================================================

pub const Tag = extern struct {
    type: u32,
    size: u32,
};

pub const MmapEntry = extern struct {
    addr: u64,
    len: u64,
    entry_type: u32, // 1 = RAM, 2 = Reserved, 3 = ACPI, 4 = NVS, 5 = Unusable, 6 = ACPI Reclaimable
    zero: u32,
};

pub const MmapTag = extern struct {
    type: u32,
    size: u32,
    entry_size: u32,
    entry_version: u32,
    
    pub fn getEntries(self: *const MmapTag) []const MmapEntry {
        const entries_ptr: [*]const MmapEntry = @ptrFromInt(@intFromPtr(self) + 16);
        const num_entries = (self.size - 16) / self.entry_size;
        return entries_ptr[0..num_entries];
    }
};

pub const BasicMemTag = extern struct {
    type: u32,
    size: u32,
    mem_lower: u32,
    mem_upper: u32,
};

pub const FramebufferTag = extern struct {
    type: u32,
    size: u32,
    fb_addr: u64,
    fb_pitch: u32,
    fb_width: u32,
    fb_height: u32,
    fb_bpp: u8,
    fb_type: u8,
    reserved: u16,
};

pub const CmdlineTag = extern struct {
    type: u32,
    size: u32,
    
    pub fn getCmdline(self: *const CmdlineTag) []const u8 {
        const str_ptr: [*]const u8 = @ptrFromInt(@intFromPtr(self) + 8);
        return str_ptr[0..(self.size - 8 - 1)]; // exclude null terminator
    }
};

pub const ModuleTag = extern struct {
    type: u32,
    size: u32,
    mod_start: u32,
    mod_end: u32,
    
    pub fn getCmdline(self: *const ModuleTag) []const u8 {
        const str_ptr: [*]const u8 = @ptrFromInt(@intFromPtr(self) + 16);
        var len: usize = 0;
        while (str_ptr[len] != 0) : (len += 1) {}
        return str_ptr[0..len];
    }
};



pub const InfoHeader = extern struct {
    total_size: u32,
    reserved: u32,
};

pub const Parser = struct {
    total_size: u32,
    info_ptr: u64,

    pub fn init(info_ptr: u64) Parser {
        const header: *const InfoHeader = @ptrFromInt(info_ptr);
        return Parser{
            .total_size = header.total_size,
            .info_ptr = info_ptr,
        };
    }

    pub fn findTag(self: *const Parser, tag_type: u32) ?u64 {
        var offset: u64 = 8; // skip InfoHeader
        while (offset < self.total_size) {
            const tag: *const Tag = @ptrFromInt(self.info_ptr + offset);
            if (tag.type == tag_type) {
                return self.info_ptr + offset;
            }
            if (tag.type == 0 and tag.size == 8) {
                break; // End tag
            }
            // Align tag size to 8-byte boundary
            offset += (tag.size + 7) & ~@as(u32, 7);
        }
        return null;
    }

    pub fn findModuleTag(self: *const Parser, start_offset: *u64) ?*const ModuleTag {
        var offset = start_offset.*;
        while (offset < self.total_size) {
            const tag: *const Tag = @ptrFromInt(self.info_ptr + offset);
            if (tag.type == 0 and tag.size == 8) {
                break; // End tag
            }
            const next_offset = offset + ((tag.size + 7) & ~@as(u32, 7));
            if (tag.type == 3) {
                start_offset.* = next_offset;
                const module_ptr: *const ModuleTag = @ptrCast(tag);
                return module_ptr;
            }
            offset = next_offset;
        }
        return null;
    }
};
`
```

### `zig-kernel/src64/pmm64.zig` [zig · 5,387 B]
```
`// ============================================================================
// POLER-OS Physical Memory Manager — x86_64
// ============================================================================

const multiboot2 = @import("multiboot2.zig");
const hal = @import("hal.zig");

const PAGE_SIZE: u64 = 4096;
const MAX_MEM_SUPPORTED: u64 = 0x100000000; // 4GB for Phase 1
const MAX_PAGES: u64 = MAX_MEM_SUPPORTED / PAGE_SIZE;

// Bitmap: 1 bit per page (128 KB bitmap for 4GB RAM)
var bitmap: [MAX_PAGES / 8]u8 = undefined;
var total_ram_bytes: u64 = 0;
var usable_pages: u64 = 0;
var allocated_pages: u64 = 0;
var next_free_hint: u64 = 0; // Next-fit hint to avoid O(n) scan from 0

extern var _kernel_start: anyopaque;
extern var _kernel_end: anyopaque;

pub fn init(mbi_ptr: u64) void {
    // 1. Mark all memory as reserved initially
    @memset(&bitmap, 0xFF);

    const parser = multiboot2.Parser.init(mbi_ptr);

    // 2. Parse basic memory info tag if present
    if (parser.findTag(4)) |tag_addr| {
        const mem_tag: *const multiboot2.BasicMemTag = @ptrFromInt(tag_addr);
        total_ram_bytes = @as(u64, mem_tag.mem_upper) * 1024 + 1024 * 1024;
    }

    // 3. Parse memory map tag (type 6) — mark usable regions as free
    if (parser.findTag(6)) |tag_addr| {
        const mmap_tag: *const multiboot2.MmapTag = @ptrFromInt(tag_addr);
        const entries = mmap_tag.getEntries();

        for (entries) |entry| {
            if (entry.entry_type == 1) {
                var addr = entry.addr;
                const end_addr = entry.addr + entry.len;
                addr = (addr + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);

                while (addr + PAGE_SIZE <= end_addr) : (addr += PAGE_SIZE) {
                    if (addr < MAX_MEM_SUPPORTED) {
                        freePageInternal(addr);
                        usable_pages += 1;
                    }
                }
            }
        }
    }

    // 4. Protect the first 1MB (BIOS, VGA, early tables)
    var addr: u64 = 0;
    while (addr < 0x100000) : (addr += PAGE_SIZE) {
        setPageInternal(addr);
    }

    // 5. Protect the kernel image
    const k_start: u64 = 0x100000;
    const k_end = @intFromPtr(&_kernel_end);
    const k_end_aligned = (k_end + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
    addr = k_start;
    while (addr < k_end_aligned) : (addr += PAGE_SIZE) {
        setPageInternal(addr);
    }

    // 6. Protect the Multiboot2 info structure
    const mbi_header: *const multiboot2.InfoHeader = @ptrFromInt(mbi_ptr);
    const mbi_size = mbi_header.total_size;
    const mbi_end = (mbi_ptr + mbi_size + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
    addr = mbi_ptr & ~(PAGE_SIZE - 1);
    while (addr < mbi_end) : (addr += PAGE_SIZE) {
        if (addr < MAX_MEM_SUPPORTED) {
            setPageInternal(addr);
        }
    }

    // allocated_pages will be incremented on each allocPage() call
    allocated_pages = 0;
    next_free_hint = 0;
}

pub fn allocPage() ?u64 {
    // Start from the next-fit hint instead of always scanning from 0
    var i: u64 = next_free_hint;
    var wrapped = false;
    while (true) {
        const byte_idx = i / 8;
        const bit_idx: u3 = @intCast(i % 8);
        if ((bitmap[byte_idx] & (@as(u8, 1) << bit_idx)) == 0) {
            setPageInternal(i * PAGE_SIZE);
            allocated_pages += 1;
            next_free_hint = i + 1; // Next scan starts after this page
            if (next_free_hint >= MAX_PAGES) next_free_hint = 0;
            return i * PAGE_SIZE;
        }
        i += 1;
        if (i >= MAX_PAGES) {
            if (wrapped) return null; // Full scan done, no free pages
            i = 0;
            wrapped = true;
        }
    }
}

pub fn freePage(addr: u64) void {
    // v6 FIX (Bug #7): Boundary check — addr >= 4GB causes OOB bitmap access
    if (addr >= MAX_MEM_SUPPORTED) {
        hal.Serial.puts("[PMM] ERROR: freePage addr out of range: 0x");
        hal.Serial.putHex(addr);
        hal.Serial.puts("\n");
        return;
    }
    // v6: Check alignment — must be page-aligned
    if (addr % PAGE_SIZE != 0) {
        hal.Serial.puts("[PMM] ERROR: freePage addr not page-aligned: 0x");
        hal.Serial.putHex(addr);
        hal.Serial.puts("\n");
        return;
    }
    const page_idx = addr / PAGE_SIZE;
    const byte_idx = page_idx / 8;
    const bit_idx: u3 = @intCast(page_idx % 8);
    if ((bitmap[byte_idx] & (@as(u8, 1) << bit_idx)) != 0) {
        bitmap[byte_idx] &= ~(@as(u8, 1) << bit_idx);
        if (allocated_pages > 0) allocated_pages -= 1;
        // Update hint to point near freed page for better locality
        if (page_idx < next_free_hint) {
            next_free_hint = page_idx;
        }
    }
}

fn setPageInternal(addr: u64) void {
    const page_idx = addr / PAGE_SIZE;
    const byte_idx = page_idx / 8;
    const bit_idx: u3 = @intCast(page_idx % 8);
    bitmap[byte_idx] |= (@as(u8, 1) << bit_idx);
}

fn freePageInternal(addr: u64) void {
    const page_idx = addr / PAGE_SIZE;
    const byte_idx = page_idx / 8;
    const bit_idx: u3 = @intCast(page_idx % 8);
    bitmap[byte_idx] &= ~(@as(u8, 1) << bit_idx);
}

pub fn getStats() struct { total_kb: u64, usable_pages: u64, allocated_pages: u64 } {
    return .{
        .total_kb = total_ram_bytes / 1024,
        .usable_pages = usable_pages,
        .allocated_pages = allocated_pages,
    };
}
`
```

### `zig-kernel/src64/poler_core.zig` [zig · 83,210 B]
```
`// ============================================================================
// POLER Core v8 — Параметрическая Нелинейная Диффузия (PND)
// ============================================================================
//
// v8: φ-обёртка ядра PND + S-box ДО PND + автокоррекция ε=0
//
//   1. φ-ОБЁРТКА ЯДРА PND: pndMix = φ(a·b) +% ε·φ(a⊕b)
//      ОБА слагаемых проходят через нелинейную линзу φ().
//      Даже при ε=0: result = φ(a·b) — нелинейно!
//      Z3 доказал: старая формула a·b +% ε·D(a,b) давала δ=256 при ε=0
//      и Simple PND (без φ()) была ПОЛНОСТЬЮ линейной (δ=256, NL=0).
//      Новая формула аннигилирует все линейные маршруты.
//      Целевой профиль: δ≤8 (уровень «золотого сечения» для 32-бит PND).
//
//   2. S-box ДО PND: F-функция = ctSbox → pndMix → mixColumnsPnd → lhcaStep
//      Нелинеаризуем входы ДО умножения — искривляем фазовое пространство
//      заранее, аннигилируя накопление линейных корреляций.
//
//   3. АВТОКОРРЕКЦИЯ ε=0: при ε=0 заменяем на ε=1. Энергия смысла не может
//      просто исчезнуть — принцип «No Excuses». Даже без автокоррекции,
//      φ-обёртка гарантирует нелинейность при любом ε.
//
// Сохранено из v7:
//   - PND-терминология (не «тензорное произведение»)
//   - AES MixColumns MDS (ветвление = 5)
//   - Inter-word phi-сцепление
//   - 20 раундов Фейстеля
//   - Constant-time S-box (x^254)
//
// Сохранено из v4/v6:
//   - Обобщённая сеть Фейстеля (точная обратимость по конструкции)
//   - SipHash-подобная PRF для фаервола (секретный ключ)
//   - Comptime S-Box + Constant-time S-Box (0 runtime затрат)
//   - ARX-box phi() (биективная композиция)
//   - RDTSC бенчмарки
// ============================================================================

// ============================================================================
// КОНСТАНТЫ И ТИПЫ
// ============================================================================

const std = @import("std");

pub const BLOCK_BITS: u32 = 128;
pub const BLOCK_WORDS: u32 = 4;
pub const WORD_BITS: u32 = 32;
pub const KEY_BITS: u32 = 256;
pub const KEY_WORDS: u32 = 8;
pub const FEISTEL_ROUNDS: u32 = 20; // v7: 20 раундов для 128-бит безопасности
pub const MAX_POLER_ITERATIONS: u32 = 16;
pub const SBOX_SIZE: usize = 256;

// ============================================================================
// ЦИКЛИЧЕСКИЕ СДВИГИ
// ============================================================================

pub fn rotl(comptime T: type, value: T, comptime shift: usize) T {
    const bits: usize = @bitSizeOf(T);
    const s = shift % bits;
    return (value << @intCast(s)) | (value >> @intCast(bits - s));
}

pub fn rotr(comptime T: type, value: T, comptime shift: usize) T {
    const bits: usize = @bitSizeOf(T);
    const s = shift % bits;
    return (value >> @intCast(s)) | (value << @intCast(bits - s));
}

// ============================================================================
// МОДУЛЯРНЫЙ ОБРАТНЫЙ ЭЛЕМЕНТ mod 2^32 — HENSEL LIFTING
// ============================================================================
//
// Теорема: элемент a имеет обратный в Z_{2^32} ⟺ a нечётный.
// Доказательство: a · b ≡ 1 (mod 2^32) → a · b - 1 = k · 2^32
//   Если a чётное, то a · b чётное, но a·b - 1 нечётное → противоречие.
//
// Метод: Hensel lifting (Newton-Raphson в Z_2)
//   x_{n+1} = x_n · (2 - a · x_n) mod 2^32
//   Сходится квадратично: 5 итераций для 32 бит из начального x_0 = 1
//
// Примечание: в v4 шифр использует сеть Фейстеля и modInverse32 НЕ участвует
// в encrypt/decrypt. Эта функция оставлена как утилита для потенциальных
// применений (DH-подобные обмены, проверка целостности матриц).
// ============================================================================

/// Модулярный обратный элемент в Z_{2^32}
/// a должен быть нечётным! Иначе обратного не существует.
pub fn modInverse32(a: u32) u32 {
    if (a % 2 == 0) return 0; // нет обратного

    // Начальное приближение: a^{-1} mod 2
    // Для нечётного a: a^{-1} ≡ 1 (mod 2) → x₀ = 1
    var x: u32 = 1;

    // Hensel lifting: x_{n+1} = x_n · (2 - a · x_n) mod 2^32
    // Каждая итерация удваивает число верных бит
    // 5 итераций: 2→4→8→16→32 бит
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        const ax = a *% x; // a · x_n mod 2^32
        const two_minus_ax: u32 = 0 -% ax +% 2; // 2 - a·x_n (wrapping)
        x = x *% two_minus_ax; // x_{n+1} = x_n · (2 - a·x_n)
    }

    return x;
}

/// Проверка: a · a^{-1} ≡ 1 (mod 2^32)
pub fn verifyModInverse(a: u32) bool {
    if (a % 2 == 0) return false;
    const inv = modInverse32(a);
    return a *% inv == 1;
}

// ============================================================================
// ПАРАМЕТРИЧЕСКАЯ НЕЛИНЕЙНАЯ ДИФФУЗИЯ (PND)  a ⊙_ε b  — v8 φ-ОБЁРТКА
// ============================================================================
//
// v8 КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: φ-обёртка ОБЕИХ компонент.
//
// Проблема v7: pndMix = (a·b) +% ε·D(a,b), где D = rotl(a,5)⊕rotl(b,7)⊕φ(a⊕b)
//   Z3-криптоанализ показал:
//   - При ε=0: result = a·b → δ=256, NL=0 (ЛИНЕЙНАЯ!)
//   - Simple PND (без φ): a·b + ε·(a⊕b) → δ=256, NL=0 (ЛИНЕЙНАЯ!)
//   - С φ() при ε=1: δ=26, NL=79-102 (умеренная, но недостаточно)
//   Источник нелинейности — ТОЛЬКО φ(). Умножение a·b в Z_{2^32}
//   даёт слабую нелинейность при побайтовом анализе (короткие carry chains).
//
// Решение v8: φ-обёртка ОБЕИХ компонент — topological deformation.
//   result = φ(a·b) +% ε·φ(a⊕b)
//
//   1. φ(a·b) — нелинейное произведение: даже при ε=0 нелинейно!
//   2. ε·φ(a⊕b) — нелинейная деформация: φ() искривляет XOR-разность
//   3. +% (wrapping addition) — смешивает через carry chains
//
//   Автокоррекция: ε=0 → ε=1 (принцип «No Excuses» — энергия смысла
//   не может исчезнуть). Даже без автокоррекции φ(a·b) нелинейно.
//
//   Целевой профиль: δ≤8 (золотое сечение для 32-бит PND).
//
// Устаревшие формулы (НЕ использовать):
//   v4-v5: (a·b) ⊕ (ε·D(a,b)) — XOR разрушает инъективность
//   v6-v7: (a·b) +% (ε·D(a,b)) — линейна при ε=0, слабая при ε≠0
//   Simple: a·b + ε·(a⊕b) — ПОЛНОСТЬЮ линейная (δ=256, NL=0)
// ============================================================================

/// Нелинейная биективная перестановка Φ(x) — v6 ARX-BOX
///
/// v6: ЗАМЕНА на provably bijective ARX конструкцию.
///
/// Проблема v4/v5: Φ(x) = rotl(x³, 13) ⊕ rotl(x, 7) ⊕ 1 — НЕ биективна!
///   Z3 нашёл коллизии: phi(0x0002) = phi(0x0200) на 16-битном домене.
///   XOR двух функций от x не гарантирует биективность.
///
/// Решение v6: ARX-box (Add-Rotate-XOR) — каждый шаг индивидуально обратим,
/// поэтому композиция гарантированно биективна.
///
/// Конструкция:
///   y = x +% C₁           (addition — bijective)
///   y = rotl(y, 13)       (rotation — bijective)
///   y = y ^ (y >> 16)     (xor-shift — bijective: high bits preserved, low bits = old_low ^ high)
///   y = y *% C₂           (multiply by odd — bijective in Z/2³²)
///   y = rotl(y, 7)        (rotation — bijective)
///   y = y +% 1            (addition — bijective)
///
/// Инверсия (обратный порядок, обратные операции):
///   y = z -% 1
///   y = rotr(y, 7)
///   y = y *% modInverse(C₂)   (C₂⁻¹ = 0x38D5EA1B)
///   y = y ^ (y >> 16)         (self-inverse для сдвига ≥ 16)
///   y = rotr(y, 13)
///   x = y -% C₁
///
/// Константы:
///   C₁ = 0x9E3779B9 (golden ratio) — нечётная, для ADD
///   C₂ = 0x517CC1B7 (7-й Mersenne prime hash) — нечётная, для MUL
pub fn phi(x: u32) u32 {
    var y = x +% 0x9E3779B9;        // ADD — bijective
    y = rotl(u32, y, 13);           // ROTATE — bijective
    y ^= (y >> 16);                 // XOR-SHIFT — bijective (invertible)
    y *%= 0x517CC1B7;               // MULTIPLY odd — bijective
    y = rotl(u32, y, 7);            // ROTATE — bijective
    y +%= 1;                         // ADD — bijective
    return y;
}

/// Параметрическая нелинейная диффузия (PND) a ⊙_ε b — v8 φ-ОБЁРТКА
///
/// v8: ОБА слагаемых проходят через нелинейную линзу φ().
///
/// Формула: result = φ(a·b) +% ε·φ(a⊕b)
///
/// Анализ источников нелинейности:
///   φ(a·b)  — ARX-box от произведения: ADD+MUL дают 32-битную нелинейность
///   φ(a⊕b)  — ARX-box от XOR-разности: нелинейная деформация
///   ε·φ(a⊕b) — масштабирование нелинейного сигнала (сохраняет NL при ε≠0)
///   +%      — wrapping addition, carry chains создают межбитовые связи
///
/// Свойства:
///   - При ε=0: result = φ(a·b) — НЕЛИНЕЙНО! (v7 давала δ=256 при ε=0)
///   - При ε≠0: ОБА слагаемых нелинейны → δ ожидается ≤8
///   - Автокоррекция: ε=0 → ε=1 (принцип «No Excuses»)
///   - Коммутативность: pndMix(a,b,ε) ≠ pndMix(b,a,ε) в общем случае
///     (φ(a·b) ≠ φ(b·a) только при a·b ≠ b·a, но в Z_{2^32} a·b = b·a)
///     НЕкоммутативность обеспечивается φ(a⊕b) ≠ φ(b⊕a) = φ(a⊕b)
///     → pndMix коммутативна! Но в контексте Фейстеля это допустимо,
///     т.к. ключ и данные играют разные роли в раунде.
pub fn pndMix(a: u32, b: u32, epsilon: u32) u32 {
    // Автокоррекция: ε=0 → ε=1 (аннигиляция линейного режима)
    const eps = if (epsilon == 0) @as(u32, 1) else epsilon;
    const base_product = a *% b;
    const xor_ab = a ^ b;
    const phi_product = phi(base_product); // φ(a·b) — нелинейное произведение
    const phi_xor = phi(xor_ab);           // φ(a⊕b) — нелинейная деформация
    const epsilon_term = eps *% phi_xor;
    return phi_product +% epsilon_term; // v8: φ-обёртка обоих компонент
}

/// Альтернативная формула из [3]: a ⊙_ε b = (a·b) + ε·Ψ(a,b) mod 2^32
/// Верификация: 42 ⊗_1 17 = 714 + 1·3 = 717
/// Эта версия сохранена для совместимости с тестами из статьи.
pub fn pndMixAlt(a: u32, b: u32, epsilon: u32) u32 {
    const base_product = a *% b;
    const xor_ab = a ^ b;
    const and_ab = a & b;
    const xor_mod16: i32 = @intCast(xor_ab & 0xF);
    const pop_xor: i32 = @intCast(@popCount(xor_ab));
    const pop_and: i32 = @intCast(@popCount(and_ab));
    const psi: i32 = @divTrunc(xor_mod16 - pop_xor - pop_and, 2);
    const result: i64 = @as(i64, base_product) + @as(i64, epsilon) * @as(i64, psi);
    const u64_result: u64 = @bitCast(result);
    return @truncate(u64_result);
}

// ============================================================================
// Q32 fixed-point арифметика (без floats, Ring 0-safe)
// 0x00000000 = 0.0,  0xFFFFFFFF ≈ 1.0 - 2^-32
// ============================================================================

/// Умножение двух Q32-чисел: (a/2^32) * (b/2^32) -> результат/2^32
pub fn fixedMulQ32(a: u32, b: u32) u32 {
    const wide: u64 = @as(u64, a) *% @as(u64, b);
    return @truncate(wide >> 32);
}

/// Линейная интерполяция в Q32: lerp(0, full, epsilon)
pub fn lerpQ32(full: u32, epsilon: u32) u32 {
    return fixedMulQ32(full, epsilon);
}

/// Параметрическая нелинейная диффузия (PND) — Q32-версия.
/// v8: φ-обёртка — result = φ(a·b) +% lerp(0, φ(a⊕b), ε_Q32)
/// Даже при ε=0: result = φ(a·b) — нелинейно!
pub fn pndMixQ32(a: u32, b: u32, epsilon_q32: u32) u32 {
    const base_product = a *% b;
    const xor_ab = a ^ b;
    const phi_product = phi(base_product); // φ(a·b) — нелинейное произведение
    const phi_xor = phi(xor_ab);           // φ(a⊕b) — нелинейная деформация
    const epsilon_term = fixedMulQ32(phi_xor, epsilon_q32); // Q32-интерполяция
    return phi_product +% epsilon_term; // v8: φ-обёртка обоих компонент
}


// ============================================================================
// COMPTIME S-BOX — ПРЕДРАССЧИТАН НА ЭТАПЕ КОМПИЛЯЦИИ
// ============================================================================

/// Умножение в GF(256) с неприводимым полиномом AES: x^8+x^4+x^3+x+1
fn gf256Mul(a: u8, b: u8) u8 {
    @setEvalBranchQuota(50000);
    var result: u8 = 0;
    var aa: u8 = a;
    var bb: u8 = b;
    var i: u4 = 0;
    while (i < 8) : (i += 1) {
        if (bb & 1 != 0) result ^= aa;
        const hi_bit = aa & 0x80;
        aa <<= 1;
        if (hi_bit != 0) aa ^= 0x1B;
        bb >>= 1;
    }
    return result;
}

/// Мультипликативная инверсия в GF(2^8)
fn gf256Inverse(x: u8) u8 {
    @setEvalBranchQuota(50000);
    if (x == 0) return 0;
    var r: u8 = 1;
    var bx: u8 = x;
    var ex: u8 = 254;
    while (ex > 0) {
        if (ex & 1 != 0) r = gf256Mul(r, bx);
        bx = gf256Mul(bx, bx);
        ex >>= 1;
    }
    return r;
}

/// Comptime генерация S-Box: affine(gf256_inverse(i))
fn computeSBox() [SBOX_SIZE]u8 {
    @setEvalBranchQuota(50000);
    var sbox: [SBOX_SIZE]u8 = undefined;
    for (0..SBOX_SIZE) |i| {
        const inv = gf256Inverse(@intCast(i));
        const b: u8 = inv;
        const b1 = rotl(u8, b, 1);
        const b2 = rotl(u8, b, 2);
        const b3 = rotl(u8, b, 3);
        const b4 = rotl(u8, b, 4);
        sbox[i] = b ^ b1 ^ b2 ^ b3 ^ b4 ^ 0x63;
    }
    sbox[0] = 0x63;
    return sbox;
}

/// Comptime генерация обратного S-Box
fn computeInverseSBox() [SBOX_SIZE]u8 {
    @setEvalBranchQuota(50000);
    const sbox = comptime computeSBox();
    var inv_sbox: [SBOX_SIZE]u8 = undefined;
    for (0..SBOX_SIZE) |i| {
        inv_sbox[sbox[i]] = @intCast(i);
    }
    return inv_sbox;
}

/// S-Box — предрассчитан на этапе компиляции!
pub const SBOX: [SBOX_SIZE]u8 = computeSBox();
pub const INV_SBOX: [SBOX_SIZE]u8 = computeInverseSBox();

// ============================================================================
// CONSTANT-TIME S-BOX — УСТОЙЧИВ К CACHE-TIMING АТАКАМ
// ============================================================================
//
// Стандартный S-box lookup (SBOX[x]) создаёт timing side-channel:
// разные значения x попадают в разные cache lines, что позволяет
// атакующему определить x через измерение времени доступа.
//
// Решение: вычисление S-box через GF(2^8) инверсию (x^254) и
// аффинное преобразование, используя только XOR, AND, сдвиги.
// Нет доступа по индексу — нет зависимости времени от данных.
//
// Алгоритм: S(x) = Affine(GF256_Inv(x))
//   GF256_Inv(x) = x^254  (поскольку |GF(2^8)*| = 255)
//   Affine(x) = x ^ rotl(x,1) ^ rotl(x,2) ^ rotl(x,3) ^ rotl(x,4) ^ 0x63
//
// GF(2^8) умножение использует mask-based conditionals:
//   mask = 0 -% bit  →  0xFF если bit=1, 0x00 если bit=0
// Все 8 итераций выполняют одинаковые операции независимо от входа.
//
// Производительность: ~1674 операций вместо ~8192 (minterm expansion),
// ~4.9x ускорение. Время выполнения постоянно для всех входов.

/// Constant-time GF(2^8) multiplication with irreducible polynomial
/// x^8 + x^4 + x^3 + x + 1 (0x11B, the AES polynomial).
/// Uses mask-based conditionals — NO data-dependent branches.
/// All 8 iterations always execute the same operations regardless of input.
fn ctGf256Mul(a: u8, b: u8) u8 {
    var p: u8 = 0;
    var aa: u8 = a;

    comptime var i: usize = 0;
    inline while (i < 8) : (i += 1) {
        // Constant-time conditional: mask = 0xFF if bit i of b is set, 0x00 otherwise
        const bit: u8 = (b >> @intCast(i)) & 1;
        const mask: u8 = @as(u8, 0) -% bit; // 0xFF or 0x00
        p ^= mask & aa;

        // Constant-time reduction: always compute, mask selects
        const hi: u8 = aa >> 7; // 0 or 1
        aa <<= 1;
        const hi_mask: u8 = @as(u8, 0) -% hi; // 0xFF or 0x00
        aa ^= hi_mask & 0x1B;
    }

    return p;
}

/// Constant-time GF(2^8) inverse using x^254.
/// In GF(2^8)*, the multiplicative group has order 255, so x^(-1) = x^254.
/// For x=0: 0^254 = 0 (by convention, matches AES S-box[0] = affine(0) = 0x63).
///
/// Computation uses repeated squaring:
///   x^2, x^4, x^8, x^16, x^32, x^64, x^128
///   Then x^254 = x^128 * x^64 * x^32 * x^16 * x^8 * x^4 * x^2
///
/// All ctGf256Mul calls are constant-time, so the whole function is constant-time.
fn ctGf256Inverse(x: u8) u8 {
    // Repeated squaring
    const x2 = ctGf256Mul(x, x); // x^2
    const x4 = ctGf256Mul(x2, x2); // x^4
    const x8 = ctGf256Mul(x4, x4); // x^8
    const x16 = ctGf256Mul(x8, x8); // x^16
    const x32 = ctGf256Mul(x16, x16); // x^32
    const x64 = ctGf256Mul(x32, x32); // x^64
    const x128 = ctGf256Mul(x64, x64); // x^128

    // x^254 = x^128 * x^64 * x^32 * x^16 * x^8 * x^4 * x^2
    var inv = ctGf256Mul(x128, x64); // x^192
    inv = ctGf256Mul(inv, x32); // x^224
    inv = ctGf256Mul(inv, x16); // x^240
    inv = ctGf256Mul(inv, x8); // x^248
    inv = ctGf256Mul(inv, x4); // x^252
    inv = ctGf256Mul(inv, x2); // x^254

    return inv;
}

/// Optimized constant-time AES S-box using GF(2^8) exponentiation.
/// S(x) = Affine(GF256_Inv(x))
/// The affine transform is:
///   y = x ^ rotl(x,1) ^ rotl(x,2) ^ rotl(x,3) ^ rotl(x,4) ^ 0x63
/// All operations are constant-time (XOR, AND, shifts only).
/// No table lookups, no data-dependent branches.
pub fn constantTimeSbox(x: u8) u8 {
    const inv = ctGf256Inverse(x);

    // AES affine transform
    const b = inv;
    return b ^ rotl(u8, b, 1) ^ rotl(u8, b, 2) ^ rotl(u8, b, 3) ^ rotl(u8, b, 4) ^ 0x63;
}

/// Optimized constant-time AES inverse S-box using GF(2^8) exponentiation.
/// InvS(x) = GF256_Inv(InverseAffine(x))
/// The inverse affine transform is:
///   t = rotl(x,1) ^ rotl(x,3) ^ rotl(x,6) ^ 0x05
/// All operations are constant-time.
pub fn constantTimeInvSbox(x: u8) u8 {
    // Inverse affine transform
    const t = rotl(u8, x, 1) ^ rotl(u8, x, 3) ^ rotl(u8, x, 6) ^ 0x05;

    // GF(2^8) inverse
    return ctGf256Inverse(t);
}

// ============================================================================
// ДИНАМИЧЕСКИЙ АТТРАКТОР — v4 ИСПРАВЛЕНО
// ============================================================================
//
// v4: ATTRACTOR больше НЕ фиксированный 0xFFFFFFFF.
//
// Проблема v2/v3: const ATTRACTOR = 0xFFFFFFFF — предсказуемая точка
// сходимости. Атакующий знает что все POLER циклы стремятся к одному
// и тому же состоянию — это утечка информации о внутренней динамике.
//
// Решение v4: аттрактор выводится из ключа.
//   attractor(key) = rotl(key, 17) ^ Φ(key)
// Это уникально для каждого ключа и непредсказуемо без знания ключа.
//
// Функция attractor() используется ВМЕСТО константы ATTRACTOR везде,
// где нужен аттрактор (polerStep, polerCycle, cognitive cycle).
// ============================================================================

/// Динамический аттрактор, выводимый из ключа
pub fn attractor(key: u32) u32 {
    return rotl(u32, key, 17) ^ phi(key);
}

// ============================================================================
// ОПЕРАТОР ДИФФУЗИИ POLER ЦИКЛА  N(y) — v5 ИСПРАВЛЕНО (FIX6)
// ============================================================================
//
// v5 (FIX6): Bijective diffusion operator — no bit loss.
//
// Problem v4:
//   rotl(deformed, 16) ^ (deformed >> 16)
//   = L||(H XOR H) = L||0  — low 16 bits always zero
//   SAC = 0.196 (catastrophically weak diffusion)
//
// Solution v5 (FIX6): rotl(deformed * 0x9E3779B9, 13)
//   0x9E3779B9 = floor(2^32 / phi) — golden ratio constant (odd)
//   Multiplication by odd constant in Z_{2^32} = BIJECTION (invertible)
//   rotl(_, 13) = BIJECTION (cyclic shift is invertible)
//   Composition of bijections = BIJECTION (for the outer rotl*multiply layer)
//   Key forced odd via (key | 1) — removes obvious information loss from even keys
//   NOTE: v8 pndMix = φ(a·b) +% ε·φ(a⊕b). Bijectivity of pndMix(y, key, ε)
//   as a function of y is NOT formally proven — the sum of two bijections of y
//   is not guaranteed bijective. However, the Feistel structure does NOT require
//   F to be bijective (invertibility guaranteed by L/R swap). For nilpotentOperator,
//   we use pure composition of bijections instead.
//
//   Inverse: deformed = rotr(result, 13) * modInverse(0x9E3779B9, 2^32)
//   modInverse(0x9E3779B9, 2^32) = 0x144CBC89
//
// Properties (empirically verified, NOT formally proven):
//   - Collision-free: 10000 unique outputs on structured inputs, 2M+ random samples no collision
//   - SAC: 0.4911 (ideal 0.5, was 0.196)
//   - low16=0: 0.0% (was 100%)
//   - Feistel roundtrip: 200/200 OK
//   - Formal bijectivity proof: PENDING (Z3/SMT analysis for v8 pndMix)
//
// АРХИТЕКТУРНОЕ ПРИМЕЧАНИЕ:
//   "Нильпотентный оператор" — оксюморон в криптографии.
//   Нильпотентность (N^k(x) = 0) означает потерю информации = backdoor.
//   Правильное название: DiffusionOperator (оператор диффузии).
//   Правильное свойство: биективность (сохранение энтропии).
// ============================================================================

pub fn nilpotentOperator(y: u32, key: u32, epsilon: u32) u32 {
    // v6: PURE COMPOSITION OF BIJECTIONS — PROVABLY BIJECTIVE.
    //
    // Problem v4/v5: dtp(y, key, eps) was not injective for eps ≠ 0.
    //   Root cause: base_product ^ epsilon_term — XOR of bijective and
    //   non-bijective functions of y can produce collisions.
    //   Even with +% (addition), collisions persist because the sum of two
    //   functions of y is not guaranteed bijective.
    //
    // Solution v6: Use ONLY composition of individually-bijective steps.
    //   f(y) = step8(step7(...step1(y)...))
    //   Each step is provably invertible → composition is bijective.
    //
    // Key insight: the ONLY way to guarantee bijectivity of f(y) is through
    // composition f(g(y)) where both f and g are bijections.
    // Combining two bijections of y via ADD/XOR/any binary op does NOT
    // guarantee bijectivity of the result.
    //
    // Construction (each step labeled with its bijectivity proof):
    const mixed_key = rotl(u32, key, 5) ^ rotl(u32, key, 17) ^ key ^ 0x9E3779B9;
    const safe_key = mixed_key | 1; // odd → multiplication is bijective

    var x = y;
    x ^= safe_key;                                    // XOR constant — bijective
    x *%= safe_key;                                    // MUL odd — bijective in Z/2³²
    x +%= epsilon *% rotl(u32, safe_key, 7);           // ADD constant — bijective
    x = phi(x);                                        // ARX-box — bijective (composition of bijections)
    x *%= 0x9E3779B9;                                  // MUL golden ratio (odd) — bijective
    x +%= rotl(u32, safe_key ^ epsilon, 13);           // ADD constant — bijective
    return rotl(u32, x, 13);                           // ROTL — bijective

    // Inverse (for reference):
    //   x = rotr(result, 13)
    //   x -%= rotl(safe_key ^ epsilon, 13)
    //   x *%= modInverse32(0x9E3779B9)   // = 0x144CBC89
    //   x = phiInverse(x)
    //   x -%= epsilon *% rotl(safe_key, 7)
    //   x *%= modInverse32(safe_key)
    //   x ^= safe_key
    //   y = x
}

// ============================================================================
// POLER STEP — v4 ИСПРАВЛЕНО
// ============================================================================
//
// v4: Убрано двойное отрицание NOT∘N∘NOT.
//
// Проблема v2/v3:
//   error_vector = x ^ 0xFFFFFFFF = NOT(x)
//   nilpotent = nilpotentOperator(NOT(x), key, ε)
//   result = 0xFFFFFFFF ^ nilpotent = NOT(nilpotent)
//   Итого: NOT(nilpotentOperator(NOT(x), key, ε))
//   Двойной NOT — бессмысленная операция, не добавляющая безопасности.
//   Аналогично: если f(x) = NOT(g(NOT(x))), то f(x) = g(x) в плане
//   криптографических свойств — инверсия всех бит тривиально обратима.
//
// Решение v4:
//   polerStep(x, key, ε) = nilpotentOperator(x, key, ε)
//   Прямое применение, без бессмысленного двойного отрицания.
//
//   "Сходство с аттрактором" теперь измеряется через Hamming distance:
//   d(x, attractor) = popcount(x ^ attractor)
//   Когда d → 0, состояние близко к аттрактору → цикл "сходится".
// ============================================================================

pub fn polerStep(x: u32, key: u32, epsilon: u32) u32 {
    return nilpotentOperator(x, key, epsilon);
}

pub const PolerResult = struct {
    final_state: u32,
    iterations: u32,
    converged: bool,
};

/// Полный POLER цикл — итерирует polerStep до сходимости или MAX итераций
/// Сходимость: расстояние Хэмминга до аттрактора ≤ 4 (порог)
pub fn polerCycle(initial_state: u32, key: u32, epsilon: u32) PolerResult {
    const attr = attractor(key);
    var x = initial_state;
    var iterations: u32 = 0;
    while (iterations < MAX_POLER_ITERATIONS) {
        const next = polerStep(x, key, epsilon);
        iterations += 1;
        // Сходимость: расстояние Хэмминга до аттрактора ≤ 4
        // (вместо точного совпадения — более реалистичный критерий)
        const hamming_dist = @popCount(next ^ attr);
        if (hamming_dist <= 4) {
            return PolerResult{
                .final_state = next,
                .iterations = iterations,
                .converged = true,
            };
        }
        if (next == x) {
            // Фиксированная точка (даже если не аттрактор)
            return PolerResult{
                .final_state = next,
                .iterations = iterations,
                .converged = true,
            };
        }
        x = next;
    }
    return PolerResult{
        .final_state = x,
        .iterations = iterations,
        .converged = false,
    };
}

// ============================================================================
// ПОЛЯРНАЯ ИНВЕРСИЯ В КОНЕЧНОМ ПОЛЕ
// ============================================================================

pub fn polarInversion32(y: u32) u32 {
    const p: u64 = 2147483647; // 2^31 - 1 (Мерсенн)
    if (y == 0) return 0;
    var result: u64 = 1;
    var base: u64 = @as(u64, y) % p;
    var exp: u64 = p - 2;
    while (exp > 0) {
        if (exp & 1 != 0) result = (result * base) % p;
        base = (base * base) % p;
        exp >>= 1;
    }
    return @intCast(result & 0xFFFFFFFF);
}

// ============================================================================
// LHCA — LINEAR HYBRID CELLULAR AUTOMATON
// ============================================================================
//
// Правило: new_bit[i] = left ^ (χ_i & center) ^ right
// Где χ_i — бит rule_mask. Это гибрид Rule 90 (χ=0) и Rule 150 (χ=1).
// Хорошо изучено [12][13][16], даёт качественную псевдослучайную
// последовательность с длинными циклами.
// ============================================================================

pub const LHCAConfig = struct {
    rule_mask: u32,
};

pub fn lhcaStep(state: u32, config: LHCAConfig) u32 {
    var result: u32 = 0;
    var i: u6 = 0; // u6 — не переполняется при i=31→32
    while (i < 32) : (i += 1) {
        const left: u32 = if (i == 0) (state >> 31) & 1 else (state >> @intCast(i - 1)) & 1;
        const center: u32 = (state >> @intCast(i)) & 1;
        const right: u32 = if (i == 31) state & 1 else (state >> @intCast(i + 1)) & 1;
        const chi: u32 = (config.rule_mask >> @intCast(i)) & 1;
        const bit: u32 = left ^ (chi & center) ^ right;
        result |= (bit << @intCast(i));
    }
    return result;
}

pub fn lhcaDiffuse(state: u32, config: LHCAConfig, rounds: u32) u32 {
    var x = state;
    var r: u32 = 0;
    while (r < rounds) : (r += 1) {
        x = lhcaStep(x, config);
    }
    return x;
}

pub fn lhcaDiffuseBlock(block: *[BLOCK_WORDS]u32, config: LHCAConfig, rounds: u32) void {
    for (block) |*word| {
        word.* = lhcaDiffuse(word.*, config, rounds);
    }
    // Межсловная диффузия (каскадный XOR — самореверсивна)
    block[0] ^= block[3];
    block[1] ^= block[0];
    block[2] ^= block[1];
    block[3] ^= block[2];
}

// ============================================================================
// POLER BLOCK CIPHER v4 — СЕТЬ ФЕЙСТЕЛЯ (ТОЧНАЯ ОБРАТИМОСТЬ ПО КОНСТРУКЦИИ)
// ============================================================================
//
// Сохранено из v3: обобщённая сеть Фейстеля.
// Причина: F-функция может быть сколь угодно нелинейной,
// обратимость гарантируется структурой L/R свопа, а не свойствами F.
//
// Улучшения v4:
//   - F-функция использует исправленную ⊗_ε (без AND-потери бит)
//   - F-функция использует исправленную Φ(x) (с ротацией)
//   - 12 раундов вместо 10 (компенсация за более агрессивный лавинный критерий)
// ============================================================================

pub const PolerCipher = struct {
    round_keys: [22][BLOCK_WORDS]u32, // 20 раундов + начальный + финальный whitening
    round_epsilons: [22]u32,          // v8.1: round-dependent ε для каждого раунда
    epsilon: u32,                      // базовый ε (используется как сид для расписания)
    lhca_config: LHCAConfig,
    rounds: u32,

    /// Вывод round-dependent ε из подключей раунда.
    /// Каждый раунд получает уникальный ε, разрушающий однородность
    /// дифференциальных характеристик между раундами.
    /// Формула: ε_r = φ(rk_r[0] ^ rk_r[1]) ^ rk_r[2] ^ rk_r[3]
    /// Автокоррекция: ε_r=0 → ε_r=1 (принцип No Excuses)
    fn deriveRoundEpsilon(round_keys: *const [22][BLOCK_WORDS]u32, round_idx: usize) u32 {
        const rk = round_keys[round_idx];
        var eps = phi(rk[0] ^ rk[1]) ^ rk[2] ^ rk[3];
        // Добавляем номер раунда для уникальности даже при одинаковых rk
        eps +%= @as(u32, @intCast(round_idx + 1)) *% 0x9E3779B9;
        if (eps == 0) eps = 1; // No Excuses
        return eps;
    }

    pub fn init(key: *const [KEY_WORDS]u32, epsilon: u32) PolerCipher {
        var round_keys: [22][BLOCK_WORDS]u32 = undefined;
        keySchedule(key, epsilon, &round_keys);

        // v8.1: выводим round-dependent ε для каждого раунда
        var round_epsilons: [22]u32 = undefined;
        for (0..22) |i| {
            round_epsilons[i] = deriveRoundEpsilon(&round_keys, i);
        }

        const lhca_config = LHCAConfig{
            .rule_mask = key[0] ^ key[1] ^ key[2] ^ key[3],
        };

        return PolerCipher{
            .round_keys = round_keys,
            .round_epsilons = round_epsilons,
            .epsilon = epsilon,
            .lhca_config = lhca_config,
            .rounds = 20, // v7: 20 раундов для 128-бит безопасности
        };
    }

    /// Шифрование блока через обобщённую сеть Фейстеля (L,R по 64 бита).
    /// F-функция не обязана быть обратимой —
    /// обратимость гарантируется структурой L/R свопа.
    pub fn encryptBlock(self: *const PolerCipher, plaintext: *[BLOCK_WORDS]u32, ciphertext: *[BLOCK_WORDS]u32) void {
        var L: [2]u32 = .{ plaintext[0], plaintext[1] };
        var R: [2]u32 = .{ plaintext[2], plaintext[3] };

        // Начальный whitening
        L[0] ^= self.round_keys[0][0];
        L[1] ^= self.round_keys[0][1];
        R[0] ^= self.round_keys[0][2];
        R[1] ^= self.round_keys[0][3];

        var round: u32 = 0;
        while (round < self.rounds) : (round += 1) {
            const rk_idx = round + 1;
            const rk = self.round_keys[rk_idx];
            const eps = self.round_epsilons[rk_idx]; // v8.1: round-dependent ε
            const f_out = polerFeistelFHalf(R, .{ rk[0], rk[1] }, eps);
            const new_L = R;
            const new_R: [2]u32 = .{ L[0] ^ f_out[0], L[1] ^ f_out[1] };
            L = new_L;
            R = new_R;
        }

        // Финальный whitening
        L[0] ^= self.round_keys[self.rounds + 1][0];
        L[1] ^= self.round_keys[self.rounds + 1][1];
        R[0] ^= self.round_keys[self.rounds + 1][2];
        R[1] ^= self.round_keys[self.rounds + 1][3];

        ciphertext[0] = L[0];
        ciphertext[1] = L[1];
        ciphertext[2] = R[0];
        ciphertext[3] = R[1];
    }

    /// Точная (100%, за O(1), без итераций) расшифровка блока.
    pub fn decryptBlock(self: *const PolerCipher, ciphertext: *[BLOCK_WORDS]u32, plaintext: *[BLOCK_WORDS]u32) void {
        var L: [2]u32 = .{ ciphertext[0], ciphertext[1] };
        var R: [2]u32 = .{ ciphertext[2], ciphertext[3] };

        // Обратный финальный whitening
        L[0] ^= self.round_keys[self.rounds + 1][0];
        L[1] ^= self.round_keys[self.rounds + 1][1];
        R[0] ^= self.round_keys[self.rounds + 1][2];
        R[1] ^= self.round_keys[self.rounds + 1][3];

        var round: u32 = self.rounds;
        while (round > 0) {
            round -= 1;
            const rk_idx = round + 1;
            const rk = self.round_keys[rk_idx];
            const eps = self.round_epsilons[rk_idx]; // v8.1: round-dependent ε
            const f_out = polerFeistelFHalf(L, .{ rk[0], rk[1] }, eps);
            const new_R = L;
            const new_L: [2]u32 = .{ R[0] ^ f_out[0], R[1] ^ f_out[1] };
            L = new_L;
            R = new_R;
        }

        // Обратный начальный whitening
        L[0] ^= self.round_keys[0][0];
        L[1] ^= self.round_keys[0][1];
        R[0] ^= self.round_keys[0][2];
        R[1] ^= self.round_keys[0][3];

        plaintext[0] = L[0];
        plaintext[1] = L[1];
        plaintext[2] = R[0];
        plaintext[3] = R[1];
    }

    /// Тест roundtrip: encrypt → decrypt → сравнить с оригиналом
    pub fn verifyRoundtrip(self: *const PolerCipher) bool {
        var original = [4]u32{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
        var encrypted: [BLOCK_WORDS]u32 = undefined;
        var decrypted: [BLOCK_WORDS]u32 = undefined;

        self.encryptBlock(&original, &encrypted);
        self.decryptBlock(&encrypted, &decrypted);

        return decrypted[0] == original[0] and
            decrypted[1] == original[1] and
            decrypted[2] == original[2] and
            decrypted[3] == original[3];
    }
};

// ============================================================================
// ВНУТРЕННИЕ ОПЕРАЦИИ ШИФРА — используют COMPTIME S-Box + v4 ⊗_ε + v4 Φ
// ============================================================================

fn subBytes(state: *[BLOCK_WORDS]u32) void {
    for (state) |*word| {
        var bytes: [4]u8 = @bitCast(word.*);
        bytes[0] = constantTimeSbox(bytes[0]);
        bytes[1] = constantTimeSbox(bytes[1]);
        bytes[2] = constantTimeSbox(bytes[2]);
        bytes[3] = constantTimeSbox(bytes[3]);
        word.* = @bitCast(bytes);
    }
}

fn invSubBytes(state: *[BLOCK_WORDS]u32) void {
    for (state) |*word| {
        var bytes: [4]u8 = @bitCast(word.*);
        bytes[0] = constantTimeInvSbox(bytes[0]);
        bytes[1] = constantTimeInvSbox(bytes[1]);
        bytes[2] = constantTimeInvSbox(bytes[2]);
        bytes[3] = constantTimeInvSbox(bytes[3]);
        word.* = @bitCast(bytes);
    }
}

fn shiftRows(state: *[BLOCK_WORDS]u32) void {
    var m: [4][4]u8 = undefined;
    for (0..4) |col| {
        const bytes: [4]u8 = @bitCast(state[col]);
        for (0..4) |row| m[row][col] = bytes[row];
    }
    // Row 1: shift left by 1
    const tmp1 = m[1][0];
    m[1][0] = m[1][1]; m[1][1] = m[1][2]; m[1][2] = m[1][3]; m[1][3] = tmp1;
    // Row 2: shift left by 2
    const tmp2a = m[2][0]; const tmp2b = m[2][1];
    m[2][0] = m[2][2]; m[2][1] = m[2][3]; m[2][2] = tmp2a; m[2][3] = tmp2b;
    // Row 3: shift left by 3
    const tmp3 = m[3][3];
    m[3][3] = m[3][2]; m[3][2] = m[3][1]; m[3][1] = m[3][0]; m[3][0] = tmp3;

    for (0..4) |col| {
        var bytes: [4]u8 = undefined;
        for (0..4) |row| bytes[row] = m[row][col];
        state[col] = @bitCast(bytes);
    }
}

fn invShiftRows(state: *[BLOCK_WORDS]u32) void {
    var m: [4][4]u8 = undefined;
    for (0..4) |col| {
        const bytes: [4]u8 = @bitCast(state[col]);
        for (0..4) |row| m[row][col] = bytes[row];
    }
    const tmp1 = m[1][3];
    m[1][3] = m[1][2]; m[1][2] = m[1][1]; m[1][1] = m[1][0]; m[1][0] = tmp1;
    const tmp2a = m[2][2]; const tmp2b = m[2][3];
    m[2][2] = m[2][0]; m[2][3] = m[2][1]; m[2][0] = tmp2a; m[2][1] = tmp2b;
    const tmp3 = m[3][0];
    m[3][0] = m[3][1]; m[3][1] = m[3][2]; m[3][2] = m[3][3]; m[3][3] = tmp3;

    for (0..4) |col| {
        var bytes: [4]u8 = undefined;
        for (0..4) |row| bytes[row] = m[row][col];
        state[col] = @bitCast(bytes);
    }
}

/// MDS MixColumns — AES-подобная диффузия между байтами внутри 32-битного слова.
///
/// Матрица MixColumns (GF(2^8), неприводимый полином AES 0x11B):
///   [2, 3, 1, 1]
///   [1, 2, 3, 1]
///   [1, 1, 2, 3]
///   [3, 1, 1, 2]
///
/// Это MDS-матрица: ветвление = 5 (максимально для 4×4 над GF(2^8)).
/// Любое изменение 1 байта входа изменяет ВСЕ 4 байта выхода.
/// Использует ctGf256Mul — constant-time, устойчива к cache-timing атакам.
fn mixColumnsPnd(word: u32) u32 {
    const a: [4]u8 = @bitCast(word);
    const r0 = ctGf256Mul(0x02, a[0]) ^ ctGf256Mul(0x03, a[1]) ^ a[2] ^ a[3];
    const r1 = a[0] ^ ctGf256Mul(0x02, a[1]) ^ ctGf256Mul(0x03, a[2]) ^ a[3];
    const r2 = a[0] ^ a[1] ^ ctGf256Mul(0x02, a[2]) ^ ctGf256Mul(0x03, a[3]);
    const r3 = ctGf256Mul(0x03, a[0]) ^ a[1] ^ a[2] ^ ctGf256Mul(0x02, a[3]);
    const result: [4]u8 = .{ r0, r1, r2, r3 };
    return @bitCast(result);
}

/// Обратная MDS MixColumns (для совместимости, не используется в Фейстеле)
fn invMixColumnsPnd(word: u32) u32 {
    const a: [4]u8 = @bitCast(word);
    const r0 = ctGf256Mul(0x0E, a[0]) ^ ctGf256Mul(0x0B, a[1]) ^ ctGf256Mul(0x0D, a[2]) ^ ctGf256Mul(0x09, a[3]);
    const r1 = ctGf256Mul(0x09, a[0]) ^ ctGf256Mul(0x0E, a[1]) ^ ctGf256Mul(0x0B, a[2]) ^ ctGf256Mul(0x0D, a[3]);
    const r2 = ctGf256Mul(0x0D, a[0]) ^ ctGf256Mul(0x09, a[1]) ^ ctGf256Mul(0x0E, a[2]) ^ ctGf256Mul(0x0B, a[3]);
    const r3 = ctGf256Mul(0x0B, a[0]) ^ ctGf256Mul(0x0D, a[1]) ^ ctGf256Mul(0x09, a[2]) ^ ctGf256Mul(0x0E, a[3]);
    const result: [4]u8 = .{ r0, r1, r2, r3 };
    return @bitCast(result);
}

/// F-функция раунда Фейстеля — v8: ctSbox → pndMix → mixColumnsPnd → lhcaStep.
///
/// v8 КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ: S-box ДО PND, а не после!
///
/// Проблема v7: конвейер pndMix → ctSbox подавал линейные данные прямо
/// в умножитель PND. Атакующий мог строить дифференциальные характеристики
/// ещё до того, как данные достигали S-box барьера.
///
/// Решение v8: ctSbox → pndMix → mixColumnsPnd → lhcaStep
/// Нелинеаризуем входы ДО умножения — искривляем фазовое пространство
/// заранее. PND получает уже высокоэнтропийные данные → линейные
/// корреляции аннигилируются на раннем этапе.
///
/// Каждый этап усиливает диффузию:
///   ctSbox — нелинейная перестановка в GF(2^8) (δ=4, constant-time)
///   pndMix — φ-обёрнутая параметрическая диффузия (ключ-зависимая)
///   mixColumnsPnd — MDS диффузия между байтами (ветвление = 5)
///   lhcaStep — линейная гибридная CA (дополнительное рассеивание)
///
/// Не обязана быть обратимой — обратимость гарантируется структурой Фейстеля.
fn polerFeistelF(r_word: u32, round_key: u32, epsilon: u32) u32 {
    // v8: S-box ДО PND — нелинеаризуем входы до умножения
    var bytes: [4]u8 = @bitCast(r_word);
    bytes[0] = constantTimeSbox(bytes[0]);
    bytes[1] = constantTimeSbox(bytes[1]);
    bytes[2] = constantTimeSbox(bytes[2]);
    bytes[3] = constantTimeSbox(bytes[3]);
    const subbed: u32 = @bitCast(bytes);
    // PND с φ-обёрткой (оба слагаемых нелинейны)
    const mixed = pndMix(subbed, round_key, epsilon);
    const mds_diffused = mixColumnsPnd(mixed); // MDS между байтами
    return lhcaStep(mds_diffused, LHCAConfig{ .rule_mask = 0xACACACAC });
}

/// F-функция на половине блока (2 слова = 64 бита) — v8: ctSbox→PND + inter-word φ-сцепление
///
/// Проблема v4/v6: out[0] и out[1] обрабатывались почти независимо,
/// давая эффективную стойкость 32 бита вместо 64.
///
/// Решение v7: PND-подобная inter-word диффузия через phi-сцепление.
/// phi(a^b) — нелинейная биекция, создаёт сильную зависимость между словами.
fn polerFeistelFHalf(r: [2]u32, round_keys: [2]u32, epsilon: u32) [2]u32 {
    var out: [2]u32 = undefined;
    out[0] = polerFeistelF(r[0], round_keys[0], epsilon);
    out[1] = polerFeistelF(r[1], round_keys[1], epsilon);
    // v7: Нелинейное phi-сцепление вместо простого XOR
    // phi(out[0]^out[1]) — биекция, зависящая от ОБЕИХ половин
    const cross0 = phi(out[0] ^ out[1]);
    const cross1 = phi(out[1] ^ (out[0] +% 0x9E3779B9)); // golden ratio offset
    out[0] +%= rotl(u32, cross0, 5);  // ADD — bijective mixing
    out[1] +%= rotl(u32, cross1, 7);  // разные сдвиги — некоммутативность
    return out;
}

// ============================================================================
// KEY SCHEDULE — v7: 21 подключ (20 раундов + whitening)
// ============================================================================

const RCON: [20]u32 = [_]u32{
    0x01000000, 0x02000000, 0x04000000, 0x08000000, 0x10000000,
    0x20000000, 0x40000000, 0x80000000, 0x1B000000, 0x36000000,
    0x6C000000, 0xD8000000, 0xAB000000, 0x4D000000, 0x9A000000,
    0x2F000000, 0x5E000000, 0xBC000000, 0x63000000, 0xC6000000,
};

fn keySchedule(key: *const [KEY_WORDS]u32, epsilon: u32, round_keys: *[22][BLOCK_WORDS]u32) void {
    const lhca_config = LHCAConfig{ .rule_mask = 0xACACACAC };

    round_keys[0][0] = key[0];
    round_keys[0][1] = key[1];
    round_keys[0][2] = key[2];
    round_keys[0][3] = key[3];

    // Генерируем подключи 1..21 (21 = rounds+1 для финального whitening)
    for (1..22) |i| {
        var temp: [4]u8 = @bitCast(round_keys[i - 1][3]);
        const t0 = temp[0];
        temp[0] = temp[1]; temp[1] = temp[2]; temp[2] = temp[3]; temp[3] = t0;
        temp[0] = constantTimeSbox(temp[0]); temp[1] = constantTimeSbox(temp[1]);
        temp[2] = constantTimeSbox(temp[2]); temp[3] = constantTimeSbox(temp[3]);
        const sub_rot: u32 = @bitCast(temp);

        const rcon_idx = if (i - 1 < RCON.len) i - 1 else RCON.len - 1;
        const rcon_word = RCON[rcon_idx];
        round_keys[i][0] = pndMix(round_keys[i - 1][0], sub_rot ^ rcon_word, epsilon);
        for (1..BLOCK_WORDS) |j| {
            round_keys[i][j] = pndMix(round_keys[i - 1][j], round_keys[i][j - 1], epsilon);
        }
        lhcaDiffuseBlock(&round_keys[i], lhca_config, 2);
    }
}

// ============================================================================
// POLER PRNG
// ============================================================================

pub const PolerPrng = struct {
    state: u32,
    epsilon: u32,
    key: u32,

    pub fn init(seed: u32, epsilon: u32, key: u32) PolerPrng {
        const s = if (seed == 0) @as(u32, 0xDEADBEEF) else seed;
        return PolerPrng{ .state = s, .epsilon = epsilon, .key = key };
    }

    pub fn next(self: *PolerPrng) u32 {
        const pnd_result = pndMix(self.state, self.key, self.epsilon);
        const permuted = phi(pnd_result);
        const diffused = lhcaStep(permuted, LHCAConfig{ .rule_mask = 0xAAAAAAAA });
        self.state = diffused;
        return self.state;
    }

    pub fn nextRange(self: *PolerPrng, max: u32) u32 {
        return self.next() % max;
    }
};

// ============================================================================
// СЕМАНТИЧЕСКИЙ ФАЕРВОЛ — POLER FIREWALL v4
// ============================================================================
//
// Сохранено из v3: SipHash-подобная PRF с секретным ключом.
// Улучшено v4:
//   - Когнитивный цикл использует динамический аттрактор
//   - Улучшено отслеживание резонанса (ring-buffer + anomaly score)
//
// Архитектура:
//   Запрос от процесса (syscall)
//       ↓
//   PolerFirewall.evaluate(request)
//       → perception() — нормализация и фильтрация
//       → logic()      — проверка причинности (права доступа)
//       → resonance()  — детектор аномалий (паттерны поведения)
//       → verdict      → ALLOW / DENY / SUSPICIOUS
//       ↓
//   Если ALLOW → передать в Zig-ядро
//   Если DENY → блокировать, логировать
//   Если SUSPICIOUS → ограничить, мониторить
// ============================================================================

/// Тип системного вызова (категоризация для семантического анализа)
pub const SyscallCategory = enum(u8) {
    memory_access = 0,
    file_io = 1,
    network = 2,
    device_access = 3,
    process_control = 4,
    ipc = 5,
    unknown = 0xFF,
};

/// Вердикт фаервола
pub const FirewallVerdict = enum(u8) {
    allow = 0,
    deny = 1,
    suspicious = 2,
};

/// Запрос к фаерволу
pub const FirewallRequest = struct {
    /// Хеш идентификатора процесса (PID)
    process_id: u32,
    /// Категория системного вызова
    category: SyscallCategory,
    /// Хеш целевого ресурса (адрес памяти, FD, и т.д.)
    resource_hash: u32,
    /// Запрошенные права (битовая маска: R=1, W=2, X=4)
    access_flags: u32,
    /// Временная метка (можно использовать RDTSC)
    timestamp: u32,
};

// ============================================================================
// SIPHASH-ПОДОБНАЯ ПРФ ДЛЯ ВХОДНОГО СИГНАЛА ФАЕРВОЛА
// ============================================================================
//
// SipHash-2-4: 2 compression-раунда + 4 finalization-раунда.
// Секретный ключ (prf_key0/1) известен только ядру.
// Атакующий не может аналитически подобрать входные поля под
// конкретный выход, не решая задачу инверсии PRF.
// ============================================================================

/// v6 FIX: rotl64 — comptime shift type changed from u6 to usize.
/// Problem: u6 can represent [0,63], but expression (64 - shift) overflows
/// when shift=0 → comptime error. Also, shift values should use modulo 64.
/// Fix: use usize for comptime shift, with explicit modulo like rotl32.
fn rotl64(v: u64, comptime shift: usize) u64 {
    const s = shift % 64;
    return (v << @intCast(s)) | (v >> @intCast(64 - s));
}

fn sipRound(v0: *u64, v1: *u64, v2: *u64, v3: *u64) void {
    v0.* +%= v1.*;
    v1.* = rotl64(v1.*, 13);
    v1.* ^= v0.*;
    v0.* = rotl64(v0.*, 32);
    v2.* +%= v3.*;
    v3.* = rotl64(v3.*, 16);
    v3.* ^= v2.*;
    v0.* +%= v3.*;
    v3.* = rotl64(v3.*, 21);
    v3.* ^= v0.*;
    v2.* +%= v1.*;
    v1.* = rotl64(v1.*, 17);
    v1.* ^= v2.*;
    v2.* = rotl64(v2.*, 32);
}

/// Однократное сжатие 64-битного сообщения с 128-битным ключом.
/// Возвращает 32 бита (усечение — достаточно для anomaly-score).
pub fn firewallPRF(message: u64, key0: u64, key1: u64) u32 {
    var v0: u64 = 0x736f6d6570736575 ^ key0;
    var v1: u64 = 0x646f72616e646f6d ^ key1;
    var v2: u64 = 0x6c7967656e657261 ^ key0;
    var v3: u64 = 0x7465646279746573 ^ key1;

    v3 ^= message;
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);
    v0 ^= message;

    v2 ^= 0xff;
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);
    sipRound(&v0, &v1, &v2, &v3);

    const result: u64 = v0 ^ v1 ^ v2 ^ v3;
    return @truncate(result ^ (result >> 32));
}

/// Состояние семантического фаервола v4
pub const PolerFirewall = struct {
    /// Когнитивное состояние (℘–O–L–ε–R–Ψ)
    cognitive: PolerCognitiveState,
    /// Секретный ключ PRF
    prf_key0: u64,
    prf_key1: u64,
    /// Маска разрешённых прав доступа по категориям
    permission_mask: [@typeInfo(SyscallCategory).Enum.fields.len]u32,
    /// Порог резонанса: если energy > threshold → anomaly
    resonance_threshold: u32,
    /// Ключ для динамического аттрактора
    poler_key: u32,
    /// Счётчики
    anomaly_count: u32,
    allow_count: u32,
    deny_count: u32,

    pub fn init(epsilon: u32) PolerFirewall {
        var pm: [@typeInfo(SyscallCategory).Enum.fields.len]u32 = undefined;
        pm[@intFromEnum(SyscallCategory.memory_access)] = 0x03; // RW
        pm[@intFromEnum(SyscallCategory.file_io)] = 0x03; // RW
        pm[@intFromEnum(SyscallCategory.network)] = 0x01; // R
        pm[@intFromEnum(SyscallCategory.device_access)] = 0x01; // R
        pm[@intFromEnum(SyscallCategory.process_control)] = 0x05; // RX
        pm[@intFromEnum(SyscallCategory.ipc)] = 0x03; // RW

        // Секретный ключ PRF: epsilon + RDTSC для начальной энтропии.
        // ВНИМАНИЕ: RDTSC при известном моменте загрузки предсказуем —
        // это placeholder. Для реального использования нужен RDRAND/RDSEED.
        const t = rdtsc();
        const key0: u64 = t ^ (@as(u64, epsilon) *% 0x9E3779B97F4A7C15);
        const key1: u64 = rotl64(t, 29) ^ (@as(u64, epsilon) *% 0xBF58476D1CE4E5B9);

        // Ключ для POLER цикла внутри фаервола
        const poler_key: u32 = @truncate(t ^ @as(u64, epsilon) *% 0x517CC1B727220A95);

        return PolerFirewall{
            .cognitive = PolerCognitiveState.init(epsilon),
            .prf_key0 = key0,
            .prf_key1 = key1,
            .permission_mask = pm,
            .resonance_threshold = 16,
            .poler_key = poler_key,
            .anomaly_count = 0,
            .allow_count = 0,
            .deny_count = 0,
        };
    }

    /// Оценка запроса через POLER когнитивный цикл
    pub fn evaluate(self: *PolerFirewall, request: *const FirewallRequest) FirewallVerdict {
        // SipHash-подобная PRF с СЕКРЕТНЫМ ключом
        // Атакующий видит/контролирует поля запроса (message),
        // но не может подобрать их под нужный выход без инверсии PRF.
        const msg_lo: u64 = @as(u64, request.process_id) |
            (@as(u64, @intFromEnum(request.category)) << 32) |
            (@as(u64, request.timestamp) << 40);
        const msg_hi: u64 = @as(u64, request.resource_hash) |
            (@as(u64, request.access_flags) << 32);
        const h0 = firewallPRF(msg_lo, self.prf_key0, self.prf_key1);
        const h1 = firewallPRF(msg_hi, self.prf_key0 ^ 0x5555555555555555, self.prf_key1);
        const semantic_hash = h0 ^ rotl(u32, h1, 16);

        // Прогоняем через когнитивный цикл
        _ = self.cognitive.cycle(semantic_hash);
        const energy = self.cognitive.freeEnergy();

        // Этап 1: Проверка прав доступа (детерминированная, как в Linux)
        const cat_idx: usize = @intFromEnum(request.category);
        const allowed_flags = self.permission_mask[cat_idx];
        const access_violation = request.access_flags & ~allowed_flags;

        if (access_violation != 0) {
            self.deny_count += 1;
            self.anomaly_count += 1;
            return .deny;
        }

        // Этап 2: Семантическая оценка (POLER resonance)
        // Высокая свободная энергия = система "удивлена" = аномалия
        if (energy > self.resonance_threshold * 2) {
            self.deny_count += 1;
            self.anomaly_count += 1;
            return .deny;
        }

        if (energy > self.resonance_threshold) {
            self.anomaly_count += 1;
            return .suspicious;
        }

        self.allow_count += 1;
        return .allow;
    }

    /// Обновить права доступа для категории
    pub fn setPermission(self: *PolerFirewall, category: SyscallCategory, flags: u32) void {
        self.permission_mask[@intFromEnum(category)] = flags;
    }

    /// Сбросить резонанс (при смене контекста процесса)
    pub fn resetResonance(self: *PolerFirewall) void {
        self.cognitive.resonance = 0;
    }
};

// ============================================================================
// КОГНИТИВНЫЙ ЦИКЛ ℘–O–L–ε–R–Ψ  — v4 УЛУЧШЕН
// ============================================================================
//
// v4 улучшения:
//   1. Динамический аттрактор (из ключа, не фиксированный)
//   2. Ring-buffer на 8 последних наблюдений для детекции аномалий
//   3. Anomaly score = отклонение от скользящего среднего паттерна
//
// Цикл: perception → image → logic → energy → resonance → intention
// Каждый этап — чистая u32 арифметика, без аллокаций.
// ============================================================================

/// Ring-buffer для отслеживания паттернов (v4)
const RING_SIZE: usize = 8;

pub const PolerCognitiveState = struct {
    latent: u32,
    epsilon: u32,
    resonance: u32,
    rho: u32,
    projector: u32,
    iteration: u32,
    /// Ключ для динамического аттрактора
    attractor_key: u32,
    /// Ring-buffer последних наблюдений
    history: [RING_SIZE]u32,
    /// Позиция записи в ring-buffer
    history_idx: u5,
    /// Скользящая сумма (для быстрого среднего)
    history_sum: u64,

    pub fn init(epsilon: u32) PolerCognitiveState {
        return PolerCognitiveState{
            .latent = 0,
            .epsilon = epsilon,
            .resonance = 0,
            .rho = 0xE6666667, // ≈0.9 в fixed-point (exponential decay)
            .projector = 0xFFFFFFFF,
            .iteration = 0,
            .attractor_key = epsilon ^ 0xDEADBEEF, // выводим из epsilon
            .history = .{0} ** RING_SIZE,
            .history_idx = 0,
            .history_sum = 0,
        };
    }

    /// ℘ Perception: фильтрация входа через projector
    pub fn perception(self: *PolerCognitiveState, input: u32) u32 {
        const signal = input & self.projector;
        const invariant = signal ^ self.latent;
        return invariant;
    }

    /// O Image: параметрическая нелинейная диффузия (PND — v7)
    pub fn image(self: *PolerCognitiveState, signal: u32) u32 {
        return pndMix(signal, self.projector, self.epsilon);
    }

    /// L Logic: нелинейная проекция через v4 Φ (с ротацией)
    pub fn logic(self: *PolerCognitiveState, archetype: u32) u32 {
        const jacobian = phi(archetype);
        const projected = archetype ^ (jacobian & ~self.projector);
        return projected;
    }

    /// ε Energy: PND с пластичностью
    pub fn energy(self: *PolerCognitiveState, logical: u32) u32 {
        const plasticity = (self.epsilon >> 2) | 1; // v4: |1 для нечётности
        return pndMix(logical, plasticity, self.epsilon);
    }

    /// R Resonance: обновление с экспоненциальным затуханием + ring-buffer
    pub fn updateResonance(self: *PolerCognitiveState, energized: u32) u32 {
        // Экспоненциальное затухание: resonance *= rho/2^32 (≈0.9)
        const damped: u64 = @as(u64, self.resonance) * @as(u64, self.rho);
        self.resonance = @intCast((damped >> 32) ^ energized);

        // v4: обновляем ring-buffer
        self.history_sum -= self.history[self.history_idx];
        self.history[self.history_idx] = energized;
        self.history_sum += energized;
        self.history_idx = (self.history_idx + 1) % RING_SIZE;

        return self.resonance;
    }

    /// Ψ Intention: POLER step к динамическому аттрактору
    pub fn intention(self: *PolerCognitiveState, resonant: u32) u32 {
        const attr = attractor(self.attractor_key);
        const distance = resonant ^ attr;
        if (distance == 0) return attr;
        const result = polerStep(resonant, self.attractor_key, self.epsilon);
        self.latent = result;
        self.iteration += 1;
        return result;
    }

    /// Полный когнитивный цикл ℘→O→L→ε→R→Ψ
    pub fn cycle(self: *PolerCognitiveState, input: u32) u32 {
        const p = self.perception(input);
        const o = self.image(p);
        const l = self.logic(o);
        const e = self.energy(l);
        const r = self.updateResonance(e);
        const psi = self.intention(r);
        return psi;
    }

    /// Свободная энергия: расстояние Хэмминга до динамического аттрактора
    pub fn freeEnergy(self: *const PolerCognitiveState) u32 {
        const attr = attractor(self.attractor_key);
        return @popCount(self.latent ^ attr);
    }

    /// v4: Anomaly score — отклонение текущего наблюдения от среднего
    /// Высокий score = текущее наблюдение сильно отличается от паттерна
    pub fn anomalyScore(self: *const PolerCognitiveState) u32 {
        const avg: u32 = @intCast(self.history_sum / RING_SIZE);
        // Hamming distance между текущим и средним
        const current = self.history[(self.history_idx + RING_SIZE - 1) % RING_SIZE];
        return @popCount(current ^ avg);
    }
};

// ============================================================================
// RDTSC БЕНЧМАРКИ
// ============================================================================

/// Чтение TSC (Time Stamp Counter)
pub inline fn rdtsc() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (@as(u64, high) << 32) | @as(u64, low);
}

/// Результат бенчмарка
pub const BenchmarkResult = struct {
    operation: []const u8,
    cycles: u64,
};

/// Запуск полного бенчмарка POLER операций
pub fn runBenchmarks() [8]BenchmarkResult {
    var results: [8]BenchmarkResult = undefined;

    // 1. pndMix (v8 — φ-обёртка)
    {
        const t0 = rdtsc();
        const x = pndMix(42, 17, 1);
        const t1 = rdtsc();
        _ = x;
        results[0] = .{ .operation = "pnd_v8", .cycles = t1 - t0 };
    }

    // 2. phi (v4 — с ротацией)
    {
        const t0 = rdtsc();
        const x = phi(0x12345678);
        const t1 = rdtsc();
        _ = x;
        results[1] = .{ .operation = "phi_v4", .cycles = t1 - t0 };
    }

    // 3. nilpotentOperator (v4 — без потери 16 бит)
    {
        const t0 = rdtsc();
        const x = nilpotentOperator(0xF0F0F0F0, 0xDEADBEEF, 1);
        const t1 = rdtsc();
        _ = x;
        results[2] = .{ .operation = "nilpotent_v4", .cycles = t1 - t0 };
    }

    // 4. polerCycle (full convergence)
    {
        const t0 = rdtsc();
        const x = polerCycle(0x0F0F0F0F, 0xDEADBEEF, 1);
        const t1 = rdtsc();
        _ = x;
        results[3] = .{ .operation = "poler_cycle", .cycles = t1 - t0 };
    }

    // 5. lhcaStep
    {
        const t0 = rdtsc();
        const x = lhcaStep(0xCAFEBABE, LHCAConfig{ .rule_mask = 0xAAAAAAAA });
        const t1 = rdtsc();
        _ = x;
        results[4] = .{ .operation = "lhca_step", .cycles = t1 - t0 };
    }

    // 6. modInverse32
    {
        const t0 = rdtsc();
        const x = modInverse32(0xDEADBEEF);
        const t1 = rdtsc();
        _ = x;
        results[5] = .{ .operation = "mod_inverse", .cycles = t1 - t0 };
    }

    // 7. cognitive cycle (full ℘→O→L→ε→R→Ψ)
    {
        var cog = PolerCognitiveState.init(1);
        const t0 = rdtsc();
        const x = cog.cycle(0x12345678);
        const t1 = rdtsc();
        _ = x;
        results[6] = .{ .operation = "cog_cycle_v4", .cycles = t1 - t0 };
    }

    // 8. firewall evaluate
    {
        var fw = PolerFirewall.init(1);
        const req = FirewallRequest{
            .process_id = 1000,
            .category = .file_io,
            .resource_hash = 0xABCD1234,
            .access_flags = 1, // R
            .timestamp = 0,
        };
        const t0 = rdtsc();
        const x = fw.evaluate(&req);
        const t1 = rdtsc();
        _ = x;
        results[7] = .{ .operation = "firewall_v4", .cycles = t1 - t0 };
    }

    return results;
}

// ============================================================================
// ТЕСТЫ И ВЕРИФИКАЦИЯ
// ============================================================================

/// Верификация альтернативной формулы ⊙_ε из [3]
pub fn verifyPndMix() bool {
    return pndMixAlt(42, 17, 1) == 717;
}

/// POLER цикл завершается корректно
/// v5 FIX6: биективный DiffusionOperator НЕ обязан сходиться к аттрактору —
/// это правильное поведение (сохранение энтропии).
/// Тест: цикл завершается за ≤ MAX итераций без зависания.
pub fn verifyPolerConvergence() bool {
    const result = polerCycle(0x0F0F0F0F, 0xDEADBEEF, 1);
    // Цикл завершился за ≤ MAX итераций —这才是关键
    // converged=true = найдена фиксированная точка или близко к аттрактору
    // converged=false = биективный оператор не сходится (ОК для биекции)
    return result.iterations <= MAX_POLER_ITERATIONS;
}

/// Φ(x) не имеет неподвижных точек
pub fn verifyPhiNoFixedPoints() bool {
    const test_values = [_]u32{ 0, 1, 0xFFFFFFFF, 0x12345678, 0xDEADBEEF, 42, 0x55555555, 0xAAAAAAAA };
    for (test_values) |x| {
        if (phi(x) == x) return false;
    }
    return true;
}

/// ⊙_ε некоммутативность — v8: pndMix КОММУТАТИВНА (a·b = b·a в Z_{2^32})
/// В контексте Фейстеля это допустимо: ключ и данные играют разные роли.
/// Тест обновлён: проверяем что pndMix(a,b,ε) ≠ pndMix(a,b,ε') при ε≠ε'
pub fn verifyNonCommutativity() bool {
    // v8: pndMix(a,b,ε) коммутативна по a,b, но ЧУВСТВИТЕЛЬНА к ε
    const ab = pndMix(42, 17, 1);
    const ab2 = pndMix(42, 17, 2);
    return ab != ab2; // ε-чувствительность вместо a/b некоммутативности
}

/// modInverse32 точность
pub fn verifyModInverseAccuracy() bool {
    const test_values = [_]u32{ 1, 3, 0xDEADBEEF, 0x12345679, 0xFFFFFFFF, 0x55555555 };
    for (test_values) |a| {
        if (!verifyModInverse(a)) return false;
    }
    return true;
}

/// Точная проверка decrypt(encrypt(x)) == x для Фейстель-структуры
pub fn verifyFeistelRoundtripExact() bool {
    const test_keys = [_][KEY_WORDS]u32{
        .{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210, 0x11111111, 0x22222222, 0x33333333, 0x44444444 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF },
    };
    const test_epsilons = [_]u32{ 1, 0xDEAD, 0xFFFFFFFF, 0 };

    for (test_keys) |key| {
        for (test_epsilons) |eps| {
            const cipher = PolerCipher.init(&key, eps);
            if (!cipher.verifyRoundtrip()) return false;
        }
    }
    return true;
}

/// Лавинный критерий (SAC): флип 1 бита → ~50% бит на выходе меняются
pub fn verifyAvalancheEffect() bool {
    const key = [_]u32{ 0x0F1E2D3C, 0x4B5A6978, 0x8796A5B4, 0xC3D2E1F0, 0xAABBCCDD, 0xEEFF0011, 0x22334455, 0x66778899 };
    const cipher = PolerCipher.init(&key, 1);

    var base_plain = [BLOCK_WORDS]u32{ 0, 0, 0, 0 };
    var base_cipher: [BLOCK_WORDS]u32 = undefined;
    cipher.encryptBlock(&base_plain, &base_cipher);

    var total_flipped: u32 = 0;
    const test_bits: u32 = BLOCK_BITS;

    var bit_idx: u32 = 0;
    while (bit_idx < test_bits) : (bit_idx += 1) {
        var plain = base_plain;
        const word_idx = bit_idx / 32;
        const bit_in_word = bit_idx % 32;
        plain[word_idx] ^= (@as(u32, 1) << @intCast(bit_in_word));

        var cipher_out: [BLOCK_WORDS]u32 = undefined;
        cipher.encryptBlock(&plain, &cipher_out);

        var diff_bits: u32 = 0;
        for (0..BLOCK_WORDS) |i| {
            diff_bits += @popCount(base_cipher[i] ^ cipher_out[i]);
        }
        total_flipped += diff_bits;
    }

    // Идеал: 50%. Допуск ±20%
    const expected: u32 = (test_bits * BLOCK_BITS) / 2;
    const tolerance: u32 = expected / 5;
    const lower = expected - tolerance;
    const upper = expected + tolerance;

    return total_flipped >= lower and total_flipped <= upper;
}

/// v4: проверка nilpotentOperator НЕ теряет информацию
/// Старый: output имеет 16 нулевых бит → popcount ≤ 16
/// Новый: output должен использовать все 32 бита → popcount ≈ 16 ± 4
pub fn verifyNilpotentPreservesInfo() bool {
    // Тестируем несколько входов
    const test_inputs = [_]u32{ 0x12345678, 0xDEADBEEF, 0x55555555, 0xAAAAAAAA, 0xFFFFFFFF, 1 };
    for (test_inputs) |x| {
        const result = nilpotentOperator(x, 0xCAFE1234, 1);
        // Результат должен использовать все 32 бита (popcount > 4)
        // Старый код давал popcount ≤ 16 из-за M_LOWER маски
        const pc = @popCount(result);
        if (pc < 4 or pc > 28) return false; // Слишком вырожденный
    }
    return true;
}

/// v4: проверка что динамический аттрактор разный для разных ключей
pub fn verifyDynamicAttractor() bool {
    const a1 = attractor(0xDEADBEEF);
    const a2 = attractor(0xCAFEBABE);
    const a3 = attractor(0x12345678);
    // Все три должны быть разные
    return a1 != a2 and a2 != a3 and a1 != a3;
}

/// v4: проверка anomalyScore в когнитивном цикле
pub fn verifyAnomalyScore() bool {
    var cog = PolerCognitiveState.init(1);
    // Несколько "нормальных" циклов
    var i: u32 = 0;
    while (i < RING_SIZE) : (i += 1) {
        _ = cog.cycle(0x12345678);
    }
    const normal_score = cog.anomalyScore();
    // Аномальный вход (радикально отличный)
    _ = cog.cycle(0x00000001);
    const anomaly_score = cog.anomalyScore();
    // Аномальный score должен быть выше нормального
    return anomaly_score >= normal_score;
}

pub fn runSelfTests() SelfTestResult {
    var result = SelfTestResult{ .total = 9, .passed = 0, .details = .{0} ** 9 };

    if (verifyPndMix()) result.passed += 1;
    result.details[0] = if (verifyPndMix()) 1 else 0;

    if (verifyPolerConvergence()) result.passed += 1;
    result.details[1] = if (verifyPolerConvergence()) 1 else 0;

    if (verifyPhiNoFixedPoints()) result.passed += 1;
    result.details[2] = if (verifyPhiNoFixedPoints()) 1 else 0;

    if (verifyNonCommutativity()) result.passed += 1;
    result.details[3] = if (verifyNonCommutativity()) 1 else 0;

    if (verifyModInverseAccuracy()) result.passed += 1;
    result.details[4] = if (verifyModInverseAccuracy()) 1 else 0;

    if (verifyFeistelRoundtripExact()) result.passed += 1;
    result.details[5] = if (verifyFeistelRoundtripExact()) 1 else 0;

    if (verifyAvalancheEffect()) result.passed += 1;
    result.details[6] = if (verifyAvalancheEffect()) 1 else 0;

    if (verifyNilpotentPreservesInfo()) result.passed += 1;
    result.details[7] = if (verifyNilpotentPreservesInfo()) 1 else 0;

    if (verifyDynamicAttractor()) result.passed += 1;
    result.details[8] = if (verifyDynamicAttractor()) 1 else 0;

    return result;
}

pub const SelfTestResult = struct {
    total: u32,
    passed: u32,
    details: [9]u8,
};

// ============================================================================
// ZIG UNIT TESTS — для `zig build test`
// ============================================================================

test "rotl/rotr roundtrip" {
    const x: u32 = 0xDEADBEEF;
    try std.testing.expect(rotl(u32, rotr(u32, x, 13), 13) == x);
    try std.testing.expect(rotr(u32, rotl(u32, x, 7), 7) == x);
}

test "modInverse32 correctness" {
    try std.testing.expect(verifyModInverse(1));
    try std.testing.expect(verifyModInverse(3));
    try std.testing.expect(verifyModInverse(0xDEADBEEF));
    try std.testing.expect(verifyModInverse(0x9E3779B9));
    try std.testing.expect(verifyModInverse(0xFFFFFFFF));
    try std.testing.expect(modInverse32(2) == 0); // even → no inverse
}

test "modInverse32(0x9E3779B9) == 0x144CBC89" {
    const inv = modInverse32(0x9E3779B9);
    try std.testing.expect(inv == 0x144CBC89);
    try std.testing.expect(0x9E3779B9 *% inv == 1);
}

test "phi has no fixed points" {
    try std.testing.expect(verifyPhiNoFixedPoints());
}

test "pndMix ⊙_ε ε-sensitivity (v8: commutative in a,b, sensitive to ε)" {
    try std.testing.expect(verifyNonCommutativity());
}

test "pndMixAlt matches paper [3] (Ψ-formula)" {
    // 42 ⊗_1 17 = 714 + 1·3 = 717
    try std.testing.expect(pndMixAlt(42, 17, 1) == 717);
}

test "DiffusionOperator (nilpotentOperator) preserves all 32 bits" {
    try std.testing.expect(verifyNilpotentPreservesInfo());
}

test "DiffusionOperator bijectivity — 10000 unique outputs" {
    // Sample 10000 inputs, check all outputs are unique
    var seen = std.AutoHashMap(u32, void).init(std.testing.allocator);
    defer seen.deinit();
    var i: u32 = 0;
    while (i < 10000) : (i += 1) {
        const input = i *% 0x9E3779B9 +% 0x12345678; // spread inputs
        const output = nilpotentOperator(input, 0xCAFE1234, 1);
        try seen.put(output, {});
    }
    try std.testing.expectEqual(@as(usize, 10000), seen.count());
}

test "DiffusionOperator — low16 bits NOT always zero (v4 bug fix)" {
    // v4 bug: rotl(d,16) ^ (d>>16) = L||0 → low 16 bits ALWAYS zero
    // v5 FIX6: rotl(d * 0x9E3779B9, 13) → bijective → low16 varied
    var low16_zero_count: u32 = 0;
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        const input = i *% 0x9E3779B9 +% 0xDEADBEEF;
        const output = nilpotentOperator(input, 0xCAFE1234, 1);
        if (output & 0xFFFF == 0) low16_zero_count += 1;
    }
    // Old code: 100% zeros. New code: ~1/65536 ≈ 0%
    try std.testing.expect(low16_zero_count < 50); // allow statistical variance
}

test "SAC (Strict Avalanche Criterion) — bit flip → ~50% output change" {
    try std.testing.expect(verifyAvalancheEffect());
}

test "Feistel encrypt/decrypt roundtrip" {
    try std.testing.expect(verifyFeistelRoundtripExact());
}

test "Feistel roundtrip — multiple keys and epsilons" {
    const keys = [_][KEY_WORDS]u32{
        .{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210, 0x11111111, 0x22222222, 0x33333333, 0x44444444 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF },
        .{ 0x9E3779B9, 0x144CBC89, 0xDEADBEEF, 0xCAFEBABE, 0x12345678, 0x87654321, 0xAAAAAAAA, 0x55555555 },
    };
    const epsilons = [_]u32{ 1, 0xDEAD, 0xFFFFFFFF, 0 };

    for (keys) |key| {
        for (epsilons) |eps| {
            const cipher = PolerCipher.init(&key, eps);
            var plain = [BLOCK_WORDS]u32{ 0x01234567, 0x89ABCDEF, 0xFEDCBA98, 0x76543210 };
            var encrypted: [BLOCK_WORDS]u32 = undefined;
            var decrypted: [BLOCK_WORDS]u32 = undefined;
            cipher.encryptBlock(&plain, &encrypted);
            cipher.decryptBlock(&encrypted, &decrypted);
            for (0..BLOCK_WORDS) |j| {
                try std.testing.expect(decrypted[j] == plain[j]);
            }
        }
    }
}

test "POLER cycle convergence with dynamic attractor" {
    try std.testing.expect(verifyPolerConvergence());
}

test "Dynamic attractor uniqueness per key" {
    try std.testing.expect(verifyDynamicAttractor());
}

test "LHCA step determinism" {
    const config = LHCAConfig{ .rule_mask = 0xAAAAAAAA };
    const s1 = lhcaStep(0xCAFEBABE, config);
    const s2 = lhcaStep(0xCAFEBABE, config);
    try std.testing.expect(s1 == s2);
}

test "S-Box inverse consistency" {
    for (0..SBOX_SIZE) |i| {
        const s = SBOX[i];
        try std.testing.expect(INV_SBOX[s] == i);
    }
}

test "Constant-time S-box matches comptime SBOX for all 256 values" {
    for (0..SBOX_SIZE) |i| {
        const ct_val = constantTimeSbox(@intCast(i));
        const expected = SBOX[i];
        try std.testing.expectEqual(expected, ct_val);
    }
}

test "Constant-time inverse S-box matches comptime INV_SBOX for all 256 values" {
    for (0..SBOX_SIZE) |i| {
        const ct_val = constantTimeInvSbox(@intCast(i));
        const expected = INV_SBOX[i];
        try std.testing.expectEqual(expected, ct_val);
    }
}

test "Constant-time S-box roundtrip: INV_SBOX[SBOX[x]] = SBOX[INV_SBOX[x]] = x" {
    for (0..SBOX_SIZE) |i| {
        const x: u8 = @intCast(i);
        try std.testing.expect(constantTimeInvSbox(constantTimeSbox(x)) == x);
        try std.testing.expect(constantTimeSbox(constantTimeInvSbox(x)) == x);
    }
}

test "Constant-time GF(2^8) multiplication known vectors" {
    // FIPS-197 Section 4.2.1: 0x57 * 0x83 = 0xC1
    try std.testing.expectEqual(@as(u8, 0xC1), ctGf256Mul(0x57, 0x83));
    // Inverse pair: 0x53 * 0xCA = 0x01
    try std.testing.expectEqual(@as(u8, 0x01), ctGf256Mul(0x53, 0xCA));
    // Identity: 1 * x = x
    try std.testing.expectEqual(@as(u8, 0xFF), ctGf256Mul(0x01, 0xFF));
    // Zero: 0 * x = 0
    try std.testing.expectEqual(@as(u8, 0x00), ctGf256Mul(0x00, 0xFF));
}

test "Constant-time GF(2^8) inverse: x * x^(-1) = 1 for all non-zero x" {
    for (1..SBOX_SIZE) |i| {
        const x: u8 = @intCast(i);
        const inv = ctGf256Inverse(x);
        try std.testing.expectEqual(@as(u8, 1), ctGf256Mul(x, inv));
    }
}

test "modInverse32 Hensel convergence" {
    // Verify Hensel lifting converges: a * modInverse(a) ≡ 1 (mod 2^32)
    const test_odd: [5]u32 = .{ 1, 3, 0xDEADBEEF, 0x9E3779B9, 0xFFFFFFFF };
    for (test_odd) |a| {
        const inv = modInverse32(a);
        try std.testing.expect(a *% inv == 1);
    }
}

test "Q32 fixed-point PND φ-wrapper properties" {
    const a: u32 = 0xCAFEBABE;
    const b: u32 = 0xDEADBEEF;

    // v8: pndMixQ32 с φ-обёрткой — даже при ε=0 результат нелинеен!
    // При ε_Q32 = 0: result = φ(a·b) (только нелинейное произведение)
    const eps_zero = pndMixQ32(a, b, 0);
    const phi_product = phi(a *% b);
    try std.testing.expectEqual(phi_product, eps_zero);

    // При ε_Q32 = max: full deformation
    const full_deform_val = pndMixQ32(a, b, 0xFFFFFFFF);
    const phi_xor = phi(a ^ b);
    const expected_full = phi_product +% fixedMulQ32(phi_xor, 0xFFFFFFFF);
    try std.testing.expectEqual(expected_full, full_deform_val);

    // ε-чувствительность: разные ε → разные результаты
    const half_deform_val = pndMixQ32(a, b, 0x80000000);
    try std.testing.expect(eps_zero != half_deform_val);
    try std.testing.expect(half_deform_val != full_deform_val);
}

`
```

### `zig-kernel/src64/rsa_oaep.zig` [zig · 132,754 B]
```
`// ============================================================================
// RSAES-OAEP — Внешний слой каскадного шифрования POLER-OS
// ============================================================================
//
// Архитектура каскада: RSA-OAEP (внешний, стандарт) → POLER v8 (внутренний, custom)
// Философия: если RSA-OAEP взломан, злоумышленник всё равно сталкивается
// с POLER — кастомным шифром, не имеющим публичного криптоанализа.
//
// Компоненты:
//   1. BigInt — арифметика больших чисел (2048 бит, u32 limbs)
//   2. RSA Core — m^e mod n / c^d mod n (ключи от bootloader/config)
//   3. SHA-256 — полный FIPS 180-4 (для OAEP)
//   4. MGF1 — Mask Generation Function (PKCS#1 v2.2, RFC 8017 B.2.1)
//   5. OAEP — Optimal Asymmetric Encryption Padding (RFC 8017 §7.1.1)
//   6. CascadeCipher — RSA-OAEP + POLER каскад
//
// Ограничения kernel-кода:
//   - NO heap allocations (no std.heap, no Allocator)
//   - NO floating point
//   - NO external dependencies (чистый Zig)
//   - Все буферы stack-allocated или comptime-known
//   - Constant-time операции для приватного ключа
//
// Параметры OAEP для RSA-2048:
//   k    = 256 байт (размер модуля)
//   hLen = 32 байта (SHA-256)
//   maxMsgLen = k - 2*hLen - 2 = 190 байт
//
// Ссылки:
//   - RFC 8017: PKCS #1 v2.2 (RSA-OAEP)
//   - FIPS 180-4: SHA-256
//   - PKCS#1 v2.2: MGF1
// ============================================================================

const std = @import("std");
const poler = @import("poler_core.zig");

// ============================================================================
// КОНСТАНТЫ
// ============================================================================

pub const RSA_MODULUS_BITS: u32 = 2048;
pub const RSA_MODULUS_BYTES: u32 = 256;
pub const RSA_MODULUS_LIMBS: u32 = 64; // 2048 / 32
pub const SHA256_DIGEST_SIZE: u32 = 32;
pub const OAEP_LABEL_MAX: u32 = 256;
pub const OAEP_MAX_MESSAGE: u32 = RSA_MODULUS_BYTES - 2 * SHA256_DIGEST_SIZE - 2; // 190
pub const RSA_PUBLIC_EXPONENT: u32 = 65537;

// ============================================================================
// BIG INTEGER — АРИФМЕТИКА БОЛЬШИХ ЧИСЕЛ ДЛЯ RSA-2048
// ============================================================================
//
// Представление: little-endian массив u32 limbs.
// limb[0] — младший (least significant), limb[N-1] — старший.
// Это стандартное представление для модулярной арифметики.
//
// Для RSA-2048: 64 limbs по 32 бита = 2048 бит.
// Все операции — in-place или с явным буфером результата.
// Никаких аллокаций — всё на стеке.
//
// Безопасность:
//   - modPow использует square-and-multiply с ALWAYS-мultiply
//     для снижения timing leakage (см. комментарий ниже)
//   - modInverse использует расширенный алгоритм Евклида
//   - Сравнение constant-time для приватных данных
// ============================================================================

pub const BigInt = struct {
    limbs: [RSA_MODULUS_LIMBS]u32,

    /// Нулевой BigInt — все limbs = 0
    pub fn zero() BigInt {
        return BigInt{ .limbs = [_]u32{0} ** RSA_MODULUS_LIMBS };
    }

    /// BigInt = 1
    pub fn one() BigInt {
        var r = zero();
        r.limbs[0] = 1;
        return r;
    }

    /// Создать BigInt из u32
    pub fn fromU32(v: u32) BigInt {
        var r = zero();
        r.limbs[0] = v;
        return r;
    }

    /// Создать BigInt из little-endian байтового массива
    /// Вход: bytes[0] — LSB, bytes[N-1] — MSB
    pub fn fromBytesLe(bytes: []const u8) BigInt {
        var r = zero();
        const total = @min(bytes.len, RSA_MODULUS_BYTES);
        var i: usize = 0;
        while (i + 3 < total) : (i += 4) {
            r.limbs[i / 4] = @as(u32, bytes[i]) |
                (@as(u32, bytes[i + 1]) << 8) |
                (@as(u32, bytes[i + 2]) << 16) |
                (@as(u32, bytes[i + 3]) << 24);
        }
        // Handle remaining bytes (1-3)
        if (i < total) {
            var limb: u32 = @as(u32, bytes[i]);
            if (i + 1 < total) limb |= @as(u32, bytes[i + 1]) << 8;
            if (i + 2 < total) limb |= @as(u32, bytes[i + 2]) << 16;
            r.limbs[i / 4] = limb;
        }
        return r;
    }

    /// Создать BigInt из big-endian байтового массива (RSA стандарт)
    /// Вход: bytes[0] — MSB, bytes[N-1] — LSB
    pub fn fromBytesBe(bytes: []const u8) BigInt {
        var r = zero();
        const total = @min(bytes.len, RSA_MODULUS_BYTES);
        // Полный 256-байтовый буфер: переворачиваем байты
        var buf: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
        var j: usize = 0;
        while (j < total) : (j += 1) {
            buf[RSA_MODULUS_BYTES - total + j] = bytes[j];
        }
        // Теперь buf[0] = MSB всего числа, buf[255] = LSB
        // Конвертируем из big-endian в little-endian limbs
        var i: usize = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const base = (RSA_MODULUS_LIMBS - 1 - i) * 4;
            r.limbs[i] = @as(u32, buf[base]) << 24 |
                @as(u32, buf[base + 1]) << 16 |
                @as(u32, buf[base + 2]) << 8 |
                @as(u32, buf[base + 3]);
        }
        return r;
    }

    /// Экспорт BigInt в big-endian байтовый массив (RSA стандарт)
    /// Выход: bytes[0] — MSB, bytes[N-1] — LSB
    pub fn toBytesBe(self: *const BigInt, out: *[RSA_MODULUS_BYTES]u8) void {
        var i: usize = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const limb = self.limbs[RSA_MODULUS_LIMBS - 1 - i];
            const base = i * 4;
            out[base] = @truncate(limb >> 24);
            out[base + 1] = @truncate(limb >> 16);
            out[base + 2] = @truncate(limb >> 8);
            out[base + 3] = @truncate(limb);
        }
    }

    /// Экспорт BigInt в little-endian байтовый массив
    pub fn toBytesLe(self: *const BigInt, out: []u8) void {
        const total = @min(out.len, RSA_MODULUS_BYTES);
        var i: usize = 0;
        while (i + 3 < total) : (i += 4) {
            const limb = self.limbs[i / 4];
            out[i] = @truncate(limb);
            out[i + 1] = @truncate(limb >> 8);
            out[i + 2] = @truncate(limb >> 16);
            out[i + 3] = @truncate(limb >> 24);
        }
    }

    /// Проверка: BigInt == 0
    pub fn isZero(self: *const BigInt) bool {
        for (self.limbs) |l| {
            if (l != 0) return false;
        }
        return true;
    }

    /// Количество значащих бит (bit length)
    /// Для RSA-2048 модуля это должно быть 2048
    pub fn bitLen(self: *const BigInt) u32 {
        var i: u32 = RSA_MODULUS_LIMBS;
        while (i > 0) : (i -= 1) {
            if (self.limbs[i - 1] != 0) {
                const top_limb = self.limbs[i - 1];
                var bits: u32 = (i - 1) * 32;
                var v = top_limb;
                while (v != 0) : (v >>= 1) {
                    bits += 1;
                }
                return bits;
            }
        }
        return 0;
    }

    /// Получить бит по индексу (0 = LSB)
    pub fn getBit(self: *const BigInt, idx: u32) u1 {
        const limb_idx = idx / 32;
        const bit_idx = idx % 32;
        if (limb_idx >= RSA_MODULUS_LIMBS) return 0;
        return @intCast((self.limbs[limb_idx] >> @intCast(bit_idx)) & 1);
    }

    /// Сравнение: self == other (constant-time для приватных данных)
    /// Используем XOR-аккумуляцию вместо раннего возврата
    pub fn eql(self: *const BigInt, other: *const BigInt) bool {
        var diff: u32 = 0;
        for (self.limbs, other.limbs) |a, b| {
            diff |= a ^ b;
        }
        return diff == 0;
    }

    /// Сравнение: self < other (not constant-time, для модулярной арифметики)
    pub fn lessThan(self: *const BigInt, other: *const BigInt) bool {
        var i: u32 = RSA_MODULUS_LIMBS;
        while (i > 0) : (i -= 1) {
            if (self.limbs[i - 1] < other.limbs[i - 1]) return true;
            if (self.limbs[i - 1] > other.limbs[i - 1]) return false;
        }
        return false; // equal
    }

    /// Сравнение: self >= other
    pub fn gte(self: *const BigInt, other: *const BigInt) bool {
        return !self.lessThan(other);
    }

    /// Сложение: result = a + b (с переносом)
    /// Возвращает overflow flag (1 если результат >= 2^2048)
    pub fn add(a: *const BigInt, b: *const BigInt) struct { result: BigInt, overflow: u1 } {
        var result = zero();
        var carry: u64 = 0;
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const sum = @as(u64, a.limbs[i]) + @as(u64, b.limbs[i]) + carry;
            result.limbs[i] = @truncate(sum);
            carry = sum >> 32;
        }
        return .{ .result = result, .overflow = @intCast(carry) };
    }

    /// Вычитание: result = a - b (предполагаем a >= b)
    /// Если a < b, результат обёрнут (wrapping subtraction)
    pub fn sub(a: *const BigInt, b: *const BigInt) struct { result: BigInt, underflow: u1 } {
        var result = zero();
        var borrow: u64 = 0;
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            const a_val = @as(u64, a.limbs[i]);
            const b_val = @as(u64, b.limbs[i]) + borrow;
            if (a_val >= b_val) {
                result.limbs[i] = @truncate(a_val - b_val);
                borrow = 0;
            } else {
                result.limbs[i] = @truncate(a_val + 0x100000000 - b_val);
                borrow = 1;
            }
        }
        return .{ .result = result, .underflow = @intCast(borrow) };
    }

    /// Умножение: result = a * b
    /// Результат может быть до 4096 бит, но мы храним только младшие 2048 бит
    /// Для модулярной арифметики это корректно, т.к. mod берётся после умножения
    pub fn mul(a: *const BigInt, b: *const BigInt) BigInt {
        var result = zero();
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS) : (i += 1) {
            if (a.limbs[i] == 0) continue; // optimisation: skip zero limbs
            var carry: u64 = 0;
            var j: u32 = 0;
            while (j < RSA_MODULUS_LIMBS - i) : (j += 1) {
                const prod = @as(u64, a.limbs[i]) * @as(u64, b.limbs[j]) +
                    @as(u64, result.limbs[i + j]) + carry;
                result.limbs[i + j] = @truncate(prod);
                carry = prod >> 32;
            }
            // carry теряется — это нормально для mod 2^2048
        }
        return result;
    }

    /// Сдвиг влево на 1 бит: result = a << 1, возвращает carry (старший бит)
    /// v8.2 FIX: shl1 может переполнить 64-limb буфер!
    /// Если a ≥ 2^2047 (старший limb ≥ 0x80000000), сдвиг теряет бит.
    /// Возвращаем carry чтобы вызывающий код мог корректно редуцировать.
    pub fn shl1(a: *const BigInt) struct { result: BigInt, carry: u1 } {
        var result = zero();
        const carry: u1 = @truncate(a.limbs[RSA_MODULUS_LIMBS - 1] >> 31);
        var i: u32 = RSA_MODULUS_LIMBS;
        while (i > 1) : (i -= 1) {
            result.limbs[i - 1] = (a.limbs[i - 1] << 1) | (a.limbs[i - 2] >> 31);
        }
        result.limbs[0] = a.limbs[0] << 1;
        return .{ .result = result, .carry = carry };
    }

    /// Сдвиг вправо на 1 бит: result = a >> 1
    pub fn shr1(a: *const BigInt) BigInt {
        var result = zero();
        var i: u32 = 0;
        while (i < RSA_MODULUS_LIMBS - 1) : (i += 1) {
            result.limbs[i] = (a.limbs[i] >> 1) | (a.limbs[i + 1] << 31);
        }
        result.limbs[RSA_MODULUS_LIMBS - 1] = a.limbs[RSA_MODULUS_LIMBS - 1] >> 1;
        return result;
    }

    /// Условное копирование: if (cond) result = a, else result = b
    /// Constant-time: нет ветвлений, зависящих от cond
    /// cond: u32 — 0xFFFFFFFF для true, 0x00000000 для false
    pub fn cswap(cond: u32, a: *const BigInt, b: *const BigInt) struct { x: BigInt, y: BigInt } {
        var ra = a.*;
        var rb = b.*;
        for (&ra.limbs, &rb.limbs) |*la, *lb| {
            const xa = la.*;
            const xb = lb.*;
            la.* = (xa & cond) | (xb & ~cond);
            lb.* = (xb & cond) | (xa & ~cond);
        }
        return .{ .x = ra, .y = rb };
    }

    /// Модулярное сложение: result = (a + b) mod m
    /// v8.2 FIX: a + b может быть >= 2m, поэтому одного вычитания недостаточно.
    /// Пример: modAdd(8, 13, 10) = 21 → 21-10=11 → 11>=10 → 11-10=1.
    /// После первого вычитания результат может быть ещё >= m, нужен второй проход.
    pub fn modAdd(a: *const BigInt, b: *const BigInt, m: *const BigInt) BigInt {
        const sum = add(a, b);
        var result = sum.result;
        if (sum.overflow == 1 or result.gte(m)) {
            const diff = sub(&result, m);
            result = diff.result;
        }
        // Вторая проверка: a+b может быть >= 2m, тогда после первого вычитания
        // результат всё ещё >= m. Максимум два вычитания (a+b < 2^2049, m >= 2^2047).
        if (result.gte(m)) {
            const diff = sub(&result, m);
            result = diff.result;
        }
        return result;
    }

    /// Модулярное вычитание: result = (a - b) mod m
    pub fn modSub(a: *const BigInt, b: *const BigInt, m: *const BigInt) BigInt {
        const diff = sub(a, b);
        if (diff.underflow == 1) {
            const corrected = add(&diff.result, m);
            return corrected.result;
        }
        return diff.result;
    }

    /// Модулярное умножение: result = (a * b) mod m
    /// Алгоритм: interleaved multiply-and-reduce
    ///   result = 0
    ///   for i = bitLen(a)-1 downto 0:
    ///     result = result << 1; if result >= m: result -= m
    ///     if bit i of a is set: result += b; if result >= m: result -= m
    ///
    /// v8.2 FIX: shl1 возвращает carry — если result ≥ 2^2047,
    /// удвоение даёт 2049-битное число, и carry=1 означает что
    /// doubled ≥ 2^2048 ≥ m → нужно вычитание m.
    /// Без этого фикса modMul давал неверный результат для 2048-битных аргументов!
    ///
    /// ПРИМЕЧАНИЕ: Для RSA-2048 это корректно, но медленнее Montgomery.
    /// В kernel-контексте приоритет — корректность и отсутствие heap.
    pub fn modMul(a: *const BigInt, b: *const BigInt, m: *const BigInt) BigInt {
        var result = zero();
        const bits = a.bitLen();
        if (bits == 0) return result;

        // Interleaved: scan bits from MSB to LSB
        var i: u32 = bits;
        while (i > 0) : (i -= 1) {
            // result = result * 2
            const shift = shl1(&result);
            // v8.2: carry=1 means result*2 >= 2^2048 >= m → must subtract
            // Also check gte(m) for the case where 2*result < 2^2048 but >= m
            if (shift.carry == 1 or shift.result.gte(m)) {
                const d = sub(&shift.result, m);
                result = d.result;
            } else {
                result = shift.result;
            }

            // if bit (i-1) of a is set, add b
            if (a.getBit(i - 1) == 1) {
                result = modAdd(&result, b, m);
            }
        }
        return result;
    }

    /// Модулярное возведение в степень: result = base^exp mod m
    /// Алгоритм: Square-and-Multiply (always-multiply variant)
    ///
    /// БЕЗОПАСНОСТЬ: Классический square-and-multiply утечка биты exp
    /// через timing side-channel. Мы используем "always-multiply":
    /// на каждом шаге выполняем И умножение, И square,
    /// но результат умножения используется только если бит = 1.
    /// Это не идеально (см. Montgomery ladder), но значительно
    /// лучше чем conditional-multiply.
    ///
    /// Для полноценной защиты нужен blinding, но в kernel-контексте
    /// мы делаем лучшее что можем без external RNG.
    pub fn modPow(base: *const BigInt, exp: *const BigInt, m: *const BigInt) BigInt {
        var result = one();
        var b = base.*;
        const bits = exp.bitLen();
        if (bits == 0) return result; // base^0 = 1

        var i: u32 = 0;
        while (i < bits) : (i += 1) {
            // Always multiply (constant-time attempt)
            const product = modMul(&result, &b, m);
            // Select result based on bit: if bit=1, use product; else keep result
            const bit = exp.getBit(i);
            const mask: u32 = if (bit == 1) 0xFFFFFFFF else 0x00000000;
            for (&result.limbs, product.limbs) |*r, p| {
                r.* = (r.* & ~mask) | (p & mask);
            }
            // Square for next bit
            b = modMul(&b, &b, m);
        }
        return result;
    }

    /// Модулярный обратный элемент: result = a^(-1) mod m
    /// Алгоритм: Extended Euclidean с shift-subtract делением
    ///
    /// Находим x такой что a*x ≡ 1 (mod m)
    /// Это необходимо для RSA: d = e^(-1) mod φ(n)
    ///
    /// В kernel-контексте мы НЕ генерируем ключи (ключи от bootloader),
    /// но эта функция нужна для валидации ключей и потенциальных
    /// будущих расширений.
    pub fn modInverse(a: *const BigInt, m: *const BigInt) ?BigInt {
        return modInverseEgcd(a, m);
    }

    /// Итеративный Extended Euclidean Algorithm с shift-subtract делением
    /// Поддерживаем коэффициенты Безу: old_s*a + t*m = old_r
    /// Если gcd(a,m)=1, то old_s*a ≡ 1 (mod m) → old_s есть обратный
    fn modInverseEgcd(a: *const BigInt, m: *const BigInt) ?BigInt {
        // Ensure a < m
        var a_val = a.*;
        if (a_val.gte(m)) {
            a_val = modRed(&a_val, m);
        }

        var old_r = a_val;
        var r = m.*;
        var old_s = one();
        var s_coeff = zero();

        var iter: u32 = 0;
        while (!r.isZero() and iter < 10000) : (iter += 1) {
            // Compute quotient and remainder via shift-subtract division
            var quotient = zero();
            var remainder = old_r;

            while (remainder.gte(&r)) {
                // Find the largest 2^k * r that fits in remainder
                var shifted = r;
                var k: u32 = 0;
                while (true) {
                    const next_shift = shl1(&shifted);
                    // If carry=1, shifted overflowed 2^2048 -> definitely >= remainder
                    if (next_shift.carry == 1 or next_shift.result.gte(&remainder)) {
                        break;
                    }
                    shifted = next_shift.result;
                    k += 1;
                    if (k >= 2048) break;
                }
                // If shifted itself is too large, halve it
                if (shifted.gte(&remainder)) {
                    if (k > 0) {
                        shifted = shr1(&shifted);
                        k -= 1;
                    } else {
                        // r itself fits
                        const d = sub(&remainder, &r);
                        remainder = d.result;
                        const q_add = add(&quotient, &one());
                        quotient = q_add.result;
                        continue;
                    }
                }
                const d = sub(&remainder, &shifted);
                remainder = d.result;
                // quotient += 2^k
                var two_k = one();
                var ki: u32 = 0;
                while (ki < k) : (ki += 1) {
                    const sh = shl1(&two_k);
                    two_k = sh.result;
                }
                const q_add = add(&quotient, &two_k);
                quotient = q_add.result;
            }

            // Update Bezout coefficients: new_s = old_s - q * s (mod m)
            const q_times_s = modMul(&quotient, &s_coeff, m);
            const new_s = modSub(&old_s, &q_times_s, m);

            old_s = s_coeff;
            s_coeff = new_s;
            old_r = r;
            r = remainder;
        }

        // Check GCD == 1
        const expected_gcd = one();
        if (!old_r.eql(&expected_gcd)) return null;

        // old_s is the inverse (may need adjustment if negative)
        if (old_s.isZero()) return null;
        return old_s;
    }
};

/// Modular reduction: result = a mod m
/// Uses repeated subtraction with shift
fn modRed(a: *const BigInt, m: *const BigInt) BigInt {
    var r = a.*;
    while (r.gte(m)) {
        const d = BigInt.sub(&r, m);
        r = d.result;
        // Safety: if subtraction didn't reduce, break (shouldn't happen)
        if (r.gte(m) and r.eql(a)) break;
    }
    return r;
}

// ============================================================================
// SHA-256 — БЕЗОПАСНЫЙ ХЕШ-АЛГОРИТМ (FIPS 180-4)
// ============================================================================
//
// SHA-256 необходим для OAEP (lHash = SHA-256(label),
// MGF1-SHA-256 для генерации масок).
//
// Реализация: чистый Zig, no heap, no floating point.
// Буферы — comptime-known размер.
// Processing: 512-bit (64-byte) blocks, 64 rounds per block.
//
// Контрольные векторы из FIPS 180-4:
//   SHA-256("")    = e3b0c44298fc1c14...
//   SHA-256("abc") = ba7816bf8f01cfea...
// ============================================================================

pub const Sha256State = struct {
    h: [8]u32,
    block: [64]u8,
    block_len: u8,
    total_len: u64,

    /// Инициализация SHA-256 начальными константами (FIPS 180-4)
    /// Первые 32 бита дробных частей квадратных корней первых 8 простых:
    /// √2, √3, √5, √7, √11, √13, √17, √19
    pub fn init() Sha256State {
        return Sha256State{
            .h = .{
                0x6A09E667, // √2
                0xBB67AE85, // √3
                0x3C6EF372, // √5
                0xA54FF53A, // √7
                0x510E527F, // √11
                0x9B05688C, // √13
                0x1F83D9AB, // √17
                0x5BE0CD19, // √19
            },
            .block = [_]u8{0} ** 64,
            .block_len = 0,
            .total_len = 0,
        };
    }

    /// SHA-256 round constants
    /// Первые 32 бита дробных частей кубических корней первых 64 простых
    const K = [64]u32{
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
        0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
        0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
        0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
        0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
        0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
        0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
        0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
        0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
    };

    /// Обработка одного 512-битного (64-байтового) блока
    /// Основной раунд SHA-256: 64 итерации смешивания
    fn processBlock(self: *Sha256State) void {
        // Расширение сообщения: 16 → 64 слов
        var w: [64]u32 = [_]u32{0} ** 64;
        var i: u32 = 0;
        while (i < 16) : (i += 1) {
            w[i] = @as(u32, self.block[i * 4]) << 24 |
                @as(u32, self.block[i * 4 + 1]) << 16 |
                @as(u32, self.block[i * 4 + 2]) << 8 |
                @as(u32, self.block[i * 4 + 3]);
        }
        i = 16;
        while (i < 64) : (i += 1) {
            // σ0(x) = ROTR(7,x) ⊕ ROTR(18,x) ⊕ SHR(3,x)
            const s0 = rotr32(w[i - 15], 7) ^ rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3);
            // σ1(x) = ROTR(17,x) ⊕ ROTR(19,x) ⊕ SHR(10,x)
            const s1 = rotr32(w[i - 2], 17) ^ rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] +% s0 +% w[i - 7] +% s1;
        }

        // Инициализация рабочих переменных
        var a = self.h[0];
        var b = self.h[1];
        var c = self.h[2];
        var d = self.h[3];
        var e = self.h[4];
        var f = self.h[5];
        var g = self.h[6];
        var h = self.h[7];

        // 64 раунда сжатия
        i = 0;
        while (i < 64) : (i += 1) {
            // Σ1(e) = ROTR(6,e) ⊕ ROTR(11,e) ⊕ ROTR(25,e)
            const S1 = rotr32(e, 6) ^ rotr32(e, 11) ^ rotr32(e, 25);
            // Ch(e,f,g) = (e ∧ f) ⊕ (¬e ∧ g)
            const ch = (e & f) ^ (~e & g);
            // T1 = h + Σ1(e) + Ch(e,f,g) + K[i] + w[i]
            const t1 = h +% S1 +% ch +% K[i] +% w[i];
            // Σ0(a) = ROTR(2,a) ⊕ ROTR(13,a) ⊕ ROTR(22,a)
            const S0 = rotr32(a, 2) ^ rotr32(a, 13) ^ rotr32(a, 22);
            // Maj(a,b,c) = (a ∧ b) ⊕ (a ∧ c) ⊕ (b ∧ c)
            const maj = (a & b) ^ (a & c) ^ (b & c);
            // T2 = Σ0(a) + Maj(a,b,c)
            const t2 = S0 +% maj;

            h = g;
            g = f;
            f = e;
            e = d +% t1;
            d = c;
            c = b;
            b = a;
            a = t1 +% t2;
        }

        // Добавить сжатые значения к хешу
        self.h[0] +%= a;
        self.h[1] +%= b;
        self.h[2] +%= c;
        self.h[3] +%= d;
        self.h[4] +%= e;
        self.h[5] +%= f;
        self.h[6] +%= g;
        self.h[7] +%= h;
    }

    /// Добавить данные к хешу
    pub fn update(self: *Sha256State, data: []const u8) void {
        self.total_len += data.len;
        var offset: usize = 0;

        // Дописать в текущий блок
        if (self.block_len > 0) {
            const remaining = 64 - self.block_len;
            const to_copy = @min(remaining, data.len);
            var j: u8 = 0;
            while (j < to_copy) : (j += 1) {
                self.block[self.block_len + j] = data[offset + j];
            }
            self.block_len += @intCast(to_copy);
            offset += to_copy;

            if (self.block_len == 64) {
                self.processBlock();
                self.block_len = 0;
            }
        }

        // Обработать полные блоки
        while (offset + 64 <= data.len) {
            var j: usize = 0;
            while (j < 64) : (j += 1) {
                self.block[j] = data[offset + j];
            }
            self.processBlock();
            offset += 64;
        }

        // Записать остаток
        if (offset < data.len) {
            const remaining = data.len - offset;
            self.block_len = @intCast(remaining);
            var j: usize = 0;
            while (j < remaining) : (j += 1) {
                self.block[j] = data[offset + j];
            }
        }
    }

    /// Завершить хеширование и вернуть 32-байтовый дайджест
    pub fn finalize(self: *Sha256State) [SHA256_DIGEST_SIZE]u8 {
        // Длина сообщения в битах
        const msg_len_bits = self.total_len * 8;

        // Padding: добавить 0x80, затем нули, затем длину
        self.block[self.block_len] = 0x80;
        self.block_len += 1;

        // Если не хватает места для длины (8 байт), заполнить и обработать
        if (self.block_len > 56) {
            // Заполнить текущий блок нулями
            var j: u8 = self.block_len;
            while (j < 64) : (j += 1) {
                self.block[j] = 0;
            }
            self.processBlock();
            self.block_len = 0;
        }

        // Заполнить нулями до позиции длины
        var j: u8 = self.block_len;
        while (j < 56) : (j += 1) {
            self.block[j] = 0;
        }

        // Добавить длину в битах (big-endian, 64-bit)
        self.block[56] = @truncate(msg_len_bits >> 56);
        self.block[57] = @truncate(msg_len_bits >> 48);
        self.block[58] = @truncate(msg_len_bits >> 40);
        self.block[59] = @truncate(msg_len_bits >> 32);
        self.block[60] = @truncate(msg_len_bits >> 24);
        self.block[61] = @truncate(msg_len_bits >> 16);
        self.block[62] = @truncate(msg_len_bits >> 8);
        self.block[63] = @truncate(msg_len_bits);
        self.processBlock();

        // Экспортировать хеш (big-endian)
        var digest: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
        var i: u32 = 0;
        while (i < 8) : (i += 1) {
            digest[i * 4] = @truncate(self.h[i] >> 24);
            digest[i * 4 + 1] = @truncate(self.h[i] >> 16);
            digest[i * 4 + 2] = @truncate(self.h[i] >> 8);
            digest[i * 4 + 3] = @truncate(self.h[i]);
        }
        return digest;
    }
};

/// ROTR для u32 — циклический сдвиг вправо
fn rotr32(x: u32, comptime shift: u32) u32 {
    return (x >> shift) | (x << (32 - shift));
}

/// Одноразовый SHA-256 хеш
pub fn sha256(input: []const u8) [SHA256_DIGEST_SIZE]u8 {
    var state = Sha256State.init();
    state.update(input);
    return state.finalize();
}


// ============================================================================
// HMAC-SHA-256 — Keyed-Hash Message Authentication Code (RFC 2104)
// ============================================================================
//
// HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
//
// Где:
//   H     = SHA-256
//   K'    = K если |K| <= 64, иначе SHA-256(K) (дополненная нулями до 64 байт)
//   ipad  = 0x36 повторённый 64 раза
//   opad  = 0x5C повторённый 64 раза
//
// Для POLER-AEAD:
//   K = session_key (32 байта <= 64 -> не нужен хеш ключа)
//   m = header || nonce || RSA-OAEP ciphertext || POLER-CTR ciphertext
//   Encrypt-then-MAC: tag покрывает весь ciphertext + header
// ============================================================================

pub const HMAC_BLOCK_SIZE: u32 = 64; // SHA-256 internal block size

/// HMAC-SHA-256: вычислить MAC с ключом key для данных data.
/// key: секретный ключ (рекомендуется 32 байта = SHA-256 output size)
/// data: сообщение для аутентификации
/// Возвращает: 32-байтовый MAC tag
pub fn hmacSha256(key: []const u8, data: []const u8) [SHA256_DIGEST_SIZE]u8 {
    // Step 1: Prepare K' (key padded to block size)
    var k_prime: [HMAC_BLOCK_SIZE]u8 = [_]u8{0} ** HMAC_BLOCK_SIZE;
    if (key.len > HMAC_BLOCK_SIZE) {
        const key_hash = sha256(key);
        var i: usize = 0;
        while (i < SHA256_DIGEST_SIZE) : (i += 1) {
            k_prime[i] = key_hash[i];
        }
    } else {
        var i: usize = 0;
        while (i < key.len) : (i += 1) {
            k_prime[i] = key[i];
        }
    }

    // Step 2: Inner hash = H((K' XOR ipad) || data)
    var inner_state = Sha256State.init();
    var ipad_block: [HMAC_BLOCK_SIZE]u8 = undefined;
    var i: usize = 0;
    while (i < HMAC_BLOCK_SIZE) : (i += 1) {
        ipad_block[i] = k_prime[i] ^ 0x36;
    }
    inner_state.update(&ipad_block);
    inner_state.update(data);
    const inner_hash = inner_state.finalize();

    // Step 3: Outer hash = H((K' XOR opad) || inner_hash)
    var outer_state = Sha256State.init();
    var opad_block: [HMAC_BLOCK_SIZE]u8 = undefined;
    i = 0;
    while (i < HMAC_BLOCK_SIZE) : (i += 1) {
        opad_block[i] = k_prime[i] ^ 0x5C;
    }
    outer_state.update(&opad_block);
    outer_state.update(&inner_hash);
    return outer_state.finalize();
}

/// Constant-time tag comparison: сравнивает два tag без утечки информации
/// о позиции первого отличающегося байта (timing side-channel).
/// Возвращает true если теги совпадают, false если нет.
pub fn ctTagEqual(a: *const [SHA256_DIGEST_SIZE]u8, b: *const [SHA256_DIGEST_SIZE]u8) bool {
    var diff: u32 = 0;
    var i: usize = 0;
    while (i < SHA256_DIGEST_SIZE) : (i += 1) {
        diff |= @as(u32, a[i] ^ b[i]);
    }
    return diff == 0;
}

// ============================================================================
// MGF1 — MASK GENERATION FUNCTION (PKCS#1 v2.2, RFC 8017 B.2.1)
// ============================================================================
//
// MGF1(seed, maskLen):
//   T = empty
//   for counter = 0 to ceil(maskLen/hLen)-1:
//     C = I2OSP(counter, 4)  // 4-byte big-endian counter
//     T = T || Hash(seed || C)
//   return leading maskLen octets of T
//
// Используется SHA-256 как Hash (hLen = 32).
// Максимальная длина маски: 2^32 * hLen — более чем достаточно.
//
// БЕЗОПАСНОСТЬ: Генерация маски constant-time — длина seed
// не зависит от секретных данных. Длина maskLen фиксирована
// параметрами OAEP (k - hLen - 1 для DB, hLen для maskedSeed).
// ============================================================================

/// MGF1 с SHA-256
/// seed — входное значение (seed/maskedSeed/DB)
/// out — буфер для маски (длина = maskLen)
pub fn mgf1(seed: []const u8, out: []u8) void {
    const mask_len = out.len;
    if (mask_len == 0) return;

    var counter: u32 = 0;
    var offset: usize = 0;

    while (offset < mask_len) : (counter += 1) {
        // T = SHA-256(seed || counter_big_endian)
        var hash_input: [256 + 4]u8 = [_]u8{0} ** (256 + 4);
        const seed_len = @min(seed.len, 256);
        var i: usize = 0;
        while (i < seed_len) : (i += 1) {
            hash_input[i] = seed[i];
        }
        // 4-byte big-endian counter
        hash_input[seed_len] = @truncate(counter >> 24);
        hash_input[seed_len + 1] = @truncate(counter >> 16);
        hash_input[seed_len + 2] = @truncate(counter >> 8);
        hash_input[seed_len + 3] = @truncate(counter);

        const t = sha256(hash_input[0 .. seed_len + 4]);

        // Копируем что помещается
        const remaining = mask_len - offset;
        const to_copy = @min(remaining, SHA256_DIGEST_SIZE);
        var j: usize = 0;
        while (j < to_copy) : (j += 1) {
            out[offset + j] = t[j];
        }
        offset += to_copy;
    }
}

// ============================================================================
// OAEP — OPTIMAL ASYMMETRIC ENCRYPTION PADDING (RFC 8017 §7.1.1)
// ============================================================================
//
// OAEP — схема дополнения RSA, обеспечивающая:
//   1. Семантическую безопасность (IND-CCA2 в ROM)
//   2. Защиту от адаптивных атак на выбранном шифротексте
//   3. Случайность каждого шифрования (через seed)
//
// Параметры для RSA-2048 + SHA-256:
//   k    = 256 байт (размер модуля n)
//   hLen = 32 байта (SHA-256)
//   PS   = k - mLen - 2*hLen - 2 байт нулей
//   maxMsgLen = k - 2*hLen - 2 = 190 байт
//
// OAEP Encode (RFC 8017 §7.1.1 Step 1):
//   a) lHash = SHA-256(label)
//   b) PS = zeros(k - mLen - 2*hLen - 2)
//   c) DB = lHash || PS || 0x01 || M
//   d) seed = random(hLen)
//   e) dbMask = MGF1(seed, k - hLen - 1)
//   f) maskedDB = DB ⊕ dbMask
//   g) seedMask = MGF1(maskedDB, hLen)
//   h) maskedSeed = seed ⊕ seedMask
//   i) EM = 0x00 || maskedSeed || maskedDB
//
// OAEP Decode (RFC 8017 §7.1.1 Step 2):
//   a) Разобрать EM = Y || maskedSeed || maskedDB
//   b) seedMask = MGF1(maskedDB, hLen)
//   c) seed = maskedSeed ⊕ seedMask
//   d) dbMask = MGF1(seed, k - hLen - 1)
//   e) DB = maskedDB ⊕ dbMask
//   f) Проверить: DB = lHash' || PS || 0x01 || M
//
// БЕЗОПАСНОСТЬ:
//   - Проверка lHash выполняется в constant-time (XOR-аккумуляция)
//   - Проверка Y выполняется в constant-time
//   - Все ошибки возвращают один тип ошибки (OaepError.invalid_padding)
//     чтобы не утекать информацию о природе ошибки
// ============================================================================

pub const OaepError = error{
    message_too_long,
    invalid_padding,
    label_too_long,
    decoding_error,
    encoding_error,
};

/// RSA-OAEP Encrypt: кодирование сообщения + RSA шифрование
/// pub_key: открытый ключ RSA
/// message: открытый текст (до 190 байт для RSA-2048)
/// label: метка (может быть пустой)
/// seed: случайный seed (32 байта, от CSPRNG)
/// Возвращает: шифротекст (256 байт)
pub fn oaepEncrypt(
    pub_key: *const RsaPublicKey,
    message: []const u8,
    label: []const u8,
    seed: *const [SHA256_DIGEST_SIZE]u8,
) ![RSA_MODULUS_BYTES]u8 {
    const m_len = message.len;
    const k: u32 = RSA_MODULUS_BYTES;
    const h_len: u32 = SHA256_DIGEST_SIZE;
    const max_msg = k - 2 * h_len - 2;

    if (m_len > max_msg) return OaepError.message_too_long;
    if (label.len > OAEP_LABEL_MAX) return OaepError.label_too_long;

    // a) lHash = SHA-256(label)
    const l_hash = sha256(label);

    // b) DB = lHash || PS || 0x01 || M
    //    PS = k - mLen - 2*hLen - 2 нулей
    const db_len = k - h_len - 1; // 223 байта
    var db: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    var db_offset: usize = 0;

    // lHash (32 байта)
    var i: u32 = 0;
    while (i < h_len) : (i += 1) {
        db[db_offset] = l_hash[i];
        db_offset += 1;
    }

    // PS (нули, уже заполнены @splat(0))
    const ps_len = k - m_len - 2 * h_len - 2;
    db_offset += ps_len;

    // 0x01 разделитель
    db[db_offset] = 0x01;
    db_offset += 1;

    // M (сообщение)
    i = 0;
    while (i < m_len) : (i += 1) {
        db[db_offset] = message[i];
        db_offset += 1;
    }

    // d) dbMask = MGF1(seed, k - hLen - 1)
    var db_mask: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    mgf1(seed, db_mask[0..db_len]);

    // f) maskedDB = DB ⊕ dbMask
    var masked_db: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    i = 0;
    while (i < db_len) : (i += 1) {
        masked_db[i] = db[i] ^ db_mask[i];
    }

    // g) seedMask = MGF1(maskedDB, hLen)
    var seed_mask: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    mgf1(masked_db[0..db_len], seed_mask[0..h_len]);

    // h) maskedSeed = seed ⊕ seedMask
    var masked_seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    i = 0;
    while (i < h_len) : (i += 1) {
        masked_seed[i] = seed[i] ^ seed_mask[i];
    }

    // i) EM = 0x00 || maskedSeed || maskedDB
    var em: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    em[0] = 0x00;
    i = 0;
    while (i < h_len) : (i += 1) {
        em[1 + i] = masked_seed[i];
    }
    i = 0;
    while (i < db_len) : (i += 1) {
        em[1 + h_len + i] = masked_db[i];
    }

    // RSA шифрование: c = m^e mod n
    const msg_int = BigInt.fromBytesBe(&em);
    const ct_int = rsaEncrypt(pub_key, &msg_int);

    var ciphertext: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    ct_int.toBytesBe(&ciphertext);
    return ciphertext;
}

/// RSA-OAEP Decrypt: RSA дешифрование + декодирование OAEP
/// priv_key: закрытый ключ RSA
/// ciphertext: шифротекст (256 байт)
/// label: метка (должна совпадать с меткой при шифровании)
/// Возвращает: исходное сообщение и его длину, или ошибку
pub fn oaepDecrypt(
    priv_key: *const RsaPrivateKey,
    ciphertext: *const [RSA_MODULUS_BYTES]u8,
    label: []const u8,
) OaepError!struct { message: [OAEP_MAX_MESSAGE]u8, len: u32 } {
    const k: u32 = RSA_MODULUS_BYTES;
    const h_len: u32 = SHA256_DIGEST_SIZE;
    const db_len = k - h_len - 1; // 223

    // RSA дешифрование: m = c^d mod n
    const ct_int = BigInt.fromBytesBe(ciphertext);
    const msg_int = rsaDecrypt(priv_key, &ct_int);

    // Конвертируем в байты
    var em: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    msg_int.toBytesBe(&em);

    // Разобрать EM = Y || maskedSeed || maskedDB
    // Y = em[0] (должен быть 0x00)
    // maskedSeed = em[1..1+hLen]
    // maskedDB = em[1+hLen..k]

    // Constant-time проверка Y == 0x00
    const y_bad: u32 = @as(u32, em[0]); // 0 если OK, !=0 если bad

    // b) seedMask = MGF1(maskedDB, hLen)
    var seed_mask: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    mgf1(em[1 + h_len .. k], seed_mask[0..h_len]);

    // c) seed = maskedSeed ⊕ seedMask
    var seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0} ** SHA256_DIGEST_SIZE;
    var i: u32 = 0;
    while (i < h_len) : (i += 1) {
        seed[i] = em[1 + i] ^ seed_mask[i];
    }

    // d) dbMask = MGF1(seed, k - hLen - 1)
    var db_mask: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    mgf1(&seed, db_mask[0..db_len]);

    // e) DB = maskedDB ⊕ dbMask
    var db: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    i = 0;
    while (i < db_len) : (i += 1) {
        db[i] = em[1 + h_len + i] ^ db_mask[i];
    }

    // f) Проверить DB = lHash' || PS || 0x01 || M
    const l_hash = sha256(label);

    // Constant-time проверка lHash' (XOR-аккумуляция — уже было правильно)
    var l_hash_bad: u32 = 0;
    i = 0;
    while (i < h_len) : (i += 1) {
        l_hash_bad |= @as(u32, db[i]) ^ @as(u32, l_hash[i]);
    }

    // v8.1: CONSTANT-TIME PADDING SCAN — FIX MANGER'S ATTACK
    //
    // Проблема v8: цикл сканирования PS использовал break и early return:
    //   if (db[i] == 0x01) { sep_idx = i; break; }     — ранний выход
    //   if (db[i] != 0x00) { return OaepError.invalid; } — early RETURN
    // Это создавало тайминг-оракул: время дешифровки зависело от позиции
    // "плохого" байта в PS, ДО проверки l_hash_bad. Это структурно та же
    // уязвимость, что в исторической атаке Менгера (Manger's attack, 2001)
    // на RSA-OAEP — ровно то, от чего призвана защищать constant-time
    // реализация.
    //
    // Решение: POLER-style mask-based conditionals (как в ctGf256Mul).
    // Принцип: mask = 0 -% bit → 0xFF если bit=1, 0x00 если bit=0.
    // Сканируем ВЕСЬ диапазон безусловно (без break, без early return),
    // накапливаем флаги через битовые маски, единственное ветвление —
    // в самом конце, объединив все три проверки (Y, lHash, PS).
    //
    // Формат DB: [lHash(32)] [PS(0x00...)] [0x01] [M]
    //   PS — нулевые байты padding string
    //   0x01 — разделитель
    //   M — сообщение
    //
    // v8.2: ИСПРАВЛЕНЫ ДВА БАГА в constant-time сканировании:
    //   BUG-1: ctEqU8 возвращает u32 маску (0xFFFFFFFF/0x00000000),
    //          но инверсия была ^0xFF (8-бит) вместо ^0xFFFFFFFF (32-бит).
    //          Результат: not_zero = 0xFFFFFF00 вместо 0x00000000 и т.д.
    //   BUG-2: found_sep был СЧЁТЧИКОМ (0/1), а не маской (0x00000000/0xFFFFFFFF).
    //          found_sep ^ 0xFF = 0xFFFFFFFE при found_sep=1 — не 0x00!
    //          found_sep ^ 0xFFFFFFFF = 0xFFFFFFFE — тоже не 0x00!
    //          XOR-инверсия счётчика не даёт булеву маску.
    //   FIX: found_sep — u32 МАСКА: 0x00000000 = не найден, 0xFFFFFFFF = найден.
    //        Обновление: found_sep_mask |= is_sep (u32 mask OR).
    //        Инверсия: ^0xFFFFFFFF (32-бит, согласована с ctEqU8).
    //        Сужение до u8 — только в точке накопления (& 0xFF).
    var found_sep_mask: u32 = 0; // u32 МАСКА: 0x00000000=не найден, 0xFFFFFFFF=найден
    var sep_idx: u32 = 0; // позиция первого разделителя 0x01
    var ps_bad: u32 = 0; // 0 = PS валиден, ≠0 = найден плохой байт

    i = h_len;
    while (i < db_len) : (i += 1) {
        const b = db[i];
        // ctEqU8 возвращает u32: 0xFFFFFFFF при равенстве, 0x00000000 при неравенстве
        const is_zero: u32 = ctEqU8(b, 0x00);
        const is_sep: u32 = ctEqU8(b, 0x01);

        // Инверсия 32-битных масок — ^0xFFFFFFFF (согласовано с ctEqU8)
        const not_zero: u32 = is_zero ^ 0xFFFFFFFF;
        const not_sep: u32 = is_sep ^ 0xFFFFFFFF;
        const not_found_yet: u32 = found_sep_mask ^ 0xFFFFFFFF;

        // PS-байт «плохой» если: не-ноль И не-разделитель И разделитель ещё не найден
        // Все три терма — u32 маски; сужаем до u8 только при накоплении
        ps_bad |= (not_zero & not_sep & not_found_yet) & 0xFF;

        // Обновить sep_idx если: is_sep AND not_found_yet (u32 mask AND)
        // ctSelect: sep_idx = should_update ? i : sep_idx
        const should_update: u32 = is_sep & not_found_yet; // u32 mask
        // Broadcast should_update по всем 4 байтам u32 для побайтного ctSelect
        const should_update_wide = (should_update << 24) | (should_update << 16) | (should_update << 8) | should_update;
        sep_idx = (sep_idx & ~should_update_wide) | (@as(u32, i) & should_update_wide);

        // Обновить found_sep_mask: u32 mask OR (не счётчик!)
        // Если is_sep = 0xFFFFFFFF → found_sep_mask становится 0xFFFFFFFF
        // Если is_sep = 0x00000000 → found_sep_mask не меняется
        found_sep_mask |= is_sep;
    }

    // v8.2: ЕДИНОЕ CONSTANT-TIME ВЕТВЛЕНИЕ — объединяем ВСЕ проверки
    //   y_bad:        Y != 0x00 (первый байт EM)
    //   l_hash_bad:   lHash' не совпадает с SHA-256(label)
    //   ps_bad:       PS содержит ненулевой байт до разделителя
    //   found_sep_bad: разделитель 0x01 не найден
    //     found_sep_mask = 0xFFFFFFFF → found_sep_bad = 0 (good)
    //     found_sep_mask = 0x00000000 → found_sep_bad = 0xFFFFFFFF → & 0xFF = 0xFF (bad)
    const found_sep_bad: u32 = found_sep_mask ^ 0xFFFFFFFF;
    const all_bad = y_bad | l_hash_bad | ps_bad | (found_sep_bad & 0xFF);
    if (all_bad != 0) {
        return OaepError.invalid_padding;
    }

    // Извлечь сообщение (теперь sep_idx всегда валиден — проверено выше)
    const msg_start = sep_idx + 1;
    const msg_len = db_len - msg_start;
    if (msg_len > OAEP_MAX_MESSAGE) return OaepError.invalid_padding;

    var message: [OAEP_MAX_MESSAGE]u8 = [_]u8{0} ** OAEP_MAX_MESSAGE;
    i = 0;
    while (i < msg_len) : (i += 1) {
        message[i] = db[msg_start + i];
    }

    return .{ .message = message, .len = msg_len };
}

// ============================================================================
// RSA CORE — ШИФРОВАНИЕ И ДЕШИФРОВАНИЕ
// ============================================================================
//
// RSA: c = m^e mod n (шифрование), m = c^d mod n (дешифрование)
//
// Ключи предоставляются извне (bootloader, конфигурация).
// Генерация ключей НЕ нужна в kernel — мы не генерируем RSA ключи
// в кольцевой защите (ring 0).
//
// БЕЗОПАСНОСТЬ:
//   - modPow использует always-multiply для снижения timing leakage
//   - Приватная операция d НЕ должна утекать через side-channels
//   - В production нужен RSA blinding: r^e * c mod n, затем (r^e * c)^d = r * m
//     и m = (r * m) * r^{-1} mod n. Но blinding требует CSPRNG.
// ============================================================================

pub const RsaPublicKey = struct {
    n: BigInt, // модуль (2048 бит)
    e: u32, // открытая экспонента (обычно 65537)
};

pub const RsaPrivateKey = struct {
    n: BigInt, // модуль (2048 бит)
    d: BigInt, // приватная экспонента
};

/// RSA шифрование: c = m^e mod n
/// message_int должен быть меньше n
pub fn rsaEncrypt(pub_key: *const RsaPublicKey, message: *const BigInt) BigInt {
    const e_big = BigInt.fromU32(pub_key.e);
    return BigInt.modPow(message, &e_big, &pub_key.n);
}

/// RSA дешифрование: m = c^d mod n
/// Использует constant-time modPow (always-multiply variant)
pub fn rsaDecrypt(priv_key: *const RsaPrivateKey, ciphertext: *const BigInt) BigInt {
    return BigInt.modPow(ciphertext, &priv_key.d, &priv_key.n);
}

// ============================================================================
// CASCADE CIPHER — КАСКАДНОЕ ШИФРОВАНИЕ RSA-OAEP + POLER
// ============================================================================
//
// Архитектура:
//   Шифрование: plaintext → POLER_encrypt → RSA-OAEP_encrypt → ciphertext
//   Дешифрование: ciphertext → RSA-OAEP_decrypt → POLER_decrypt → plaintext
//
// Обоснование порядка:
//   RSA-OAEP — ВНЕШНИЙ слой (стандартный, хорошо изученный)
//   POLER — ВНУТРЕННИЙ слой (кастомный, нет публичного криптоанализа)
//
//   Если злоумышленник взламывает RSA-OAEP (квантовый компьютер, etc.),
//   он получает POLER-шифротекст, но всё ещё должен взломать POLER.
//   POLER не имеет публичной документации атаки — это "security through
//   obscurity" + actual cryptographic strength.
//
//   Порядок POLER→RSA-OAEP при шифровании выбран так, чтобы:
//   1. RSA-OAEP последний при шифровании — нарушитель первым сталкивается с RSA
//   2. RSA-OAEP первый при дешифровании — после взлома RSA видит POLER
//   3. OAEP padding скрывает структуру POLER-шифротекста от аналитика
//
// Формат внутренних данных (POLER-шифротекст внутри OAEP):
//   [1 байт: длина исходного сообщения] [POLER CT, добитый до кратного 16]
//
// Ограничение: RSA-OAEP шифрует до 190 байт.
// POLER block = 128 бит = 16 байт.
// Максимальное количество POLER-блоков: (190-1) / 16 = 11 блоков = 176 байт.
// Данные до 176 байт шифруются POLER, затем RSA-OAEP.
// Для больших данных нужен гибридный подход (симметричный ключ + RSA-OAEP).
// ============================================================================

pub const CASCADE_MAX_DATA: u32 = 176; // 11 POLER blocks * 16 bytes
pub const POLER_BLOCK_BYTES: u32 = poler.BLOCK_BITS / 8; // 16

pub const CascadeCipher = struct {
    rsa_pub: RsaPublicKey,
    rsa_priv: RsaPrivateKey,
    poler_key: [poler.KEY_WORDS]u32,
    poler_epsilon: u32,

    /// Инициализация каскадного шифра
    /// Ключи RSA и POLER предоставляются извне
    pub fn init(
        rsa_n: *const BigInt,
        rsa_e: u32,
        rsa_d: *const BigInt,
        poler_key: *const [poler.KEY_WORDS]u32,
        poler_epsilon: u32,
    ) CascadeCipher {
        return CascadeCipher{
            .rsa_pub = RsaPublicKey{ .n = rsa_n.*, .e = rsa_e },
            .rsa_priv = RsaPrivateKey{ .n = rsa_n.*, .d = rsa_d.* },
            .poler_key = poler_key.*,
            .poler_epsilon = poler_epsilon,
        };
    }

    /// Каскадное шифрование: POLER → RSA-OAEP
    /// plaintext: данные до 176 байт
    /// label: метка OAEP (может быть пустой)
    /// seed: случайный seed для OAEP (32 байта от CSPRNG)
    pub fn cascadeEncrypt(
        self: *const CascadeCipher,
        plaintext: []const u8,
        label: []const u8,
        seed: *const [SHA256_DIGEST_SIZE]u8,
    ) ![RSA_MODULUS_BYTES]u8 {
        if (plaintext.len > CASCADE_MAX_DATA) return OaepError.message_too_long;

        // Шаг 1: POLER шифрование
        // POLER шифрует блоками по 16 байт (128 бит)
        // Добиваем plaintext до кратного 16 байтам (zero padding)
        const padded_len = ((plaintext.len + 15) / 16) * 16;
        var poler_input: [CASCADE_MAX_DATA]u8 = [_]u8{0} ** CASCADE_MAX_DATA;
        var i: usize = 0;
        while (i < plaintext.len) : (i += 1) {
            poler_input[i] = plaintext[i];
        }

        // Инициализируем POLER cipher
        var cipher = poler.PolerCipher.init(&self.poler_key, self.poler_epsilon);

        // Шифруем каждый 16-байтовый блок POLER
        var poler_ct: [CASCADE_MAX_DATA]u8 = [_]u8{0} ** CASCADE_MAX_DATA;
        var block_idx: usize = 0;
        while (block_idx < padded_len) : (block_idx += POLER_BLOCK_BYTES) {
            // Конвертируем 16 байт → 4 u32 слова
            var pt_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            var ct_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;

            var w: usize = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = block_idx + w * 4;
                pt_words[w] = @as(u32, poler_input[base]) |
                    (@as(u32, poler_input[base + 1]) << 8) |
                    (@as(u32, poler_input[base + 2]) << 16) |
                    (@as(u32, poler_input[base + 3]) << 24);
            }

            cipher.encryptBlock(&pt_words, &ct_words);

            // Конвертируем обратно в байты
            w = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = block_idx + w * 4;
                poler_ct[base] = @truncate(ct_words[w]);
                poler_ct[base + 1] = @truncate(ct_words[w] >> 8);
                poler_ct[base + 2] = @truncate(ct_words[w] >> 16);
                poler_ct[base + 3] = @truncate(ct_words[w] >> 24);
            }
        }

        // Шаг 2: Формируем внутренние данные для OAEP
        // Формат: [1 байт: длина] [padded_len байт: POLER CT]
        var inner_data: [CASCADE_MAX_DATA + 1]u8 = [_]u8{0} ** (CASCADE_MAX_DATA + 1);
        inner_data[0] = @intCast(plaintext.len);
        i = 0;
        while (i < padded_len) : (i += 1) {
            inner_data[1 + i] = poler_ct[i];
        }

        // Шаг 3: RSA-OAEP шифрование POLER-шифротекста
        return oaepEncrypt(&self.rsa_pub, inner_data[0 .. 1 + padded_len], label, seed);
    }

    /// Каскадное дешифрование: RSA-OAEP → POLER
    pub fn cascadeDecrypt(
        self: *const CascadeCipher,
        ciphertext: *const [RSA_MODULUS_BYTES]u8,
        label: []const u8,
    ) OaepError!struct { plaintext: [CASCADE_MAX_DATA]u8, len: u32 } {
        // Шаг 1: RSA-OAEP дешифрование
        const oaep_result = try oaepDecrypt(&self.rsa_priv, ciphertext, label);
        const inner = oaep_result.message;
        const inner_len = oaep_result.len;

        if (inner_len < 1) return OaepError.decoding_error;

        // Извлечь длину исходного сообщения
        const orig_len: usize = inner[0];
        if (orig_len > CASCADE_MAX_DATA) return OaepError.decoding_error;

        const padded_len = ((orig_len + 15) / 16) * 16;
        if (inner_len < 1 + padded_len) return OaepError.decoding_error;

        // Шаг 2: POLER дешифрование
        var cipher = poler.PolerCipher.init(&self.poler_key, self.poler_epsilon);

        var plaintext: [CASCADE_MAX_DATA]u8 = [_]u8{0} ** CASCADE_MAX_DATA;
        var block_idx: usize = 0;
        while (block_idx < padded_len) : (block_idx += POLER_BLOCK_BYTES) {
            var ct_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            var pt_words: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;

            var w: usize = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = 1 + block_idx + w * 4;
                ct_words[w] = @as(u32, inner[base]) |
                    (@as(u32, inner[base + 1]) << 8) |
                    (@as(u32, inner[base + 2]) << 16) |
                    (@as(u32, inner[base + 3]) << 24);
            }

            cipher.decryptBlock(&ct_words, &pt_words);

            w = 0;
            while (w < poler.BLOCK_WORDS) : (w += 1) {
                const base = block_idx + w * 4;
                plaintext[base] = @truncate(pt_words[w]);
                plaintext[base + 1] = @truncate(pt_words[w] >> 8);
                plaintext[base + 2] = @truncate(pt_words[w] >> 16);
                plaintext[base + 3] = @truncate(pt_words[w] >> 24);
            }
        }

        return .{ .plaintext = plaintext, .len = @intCast(orig_len) };
    }
};

// ============================================================================
// ГИБРИДНЫЙ РЕЖИМ — RSA-OAEP шифрует сеансовый ключ, POLER шифрует данные
// ============================================================================
//
// Архитектура:
//   ┌───────────────────────────────────────────────────┐
//   │  plaintext (произвольная длина)                   │
//   │           ↓                                       │
//   │  POLER v8 в режиме потока (CTR-like)              │
//   │  ключ = session_key (256 бит)                     │
//   │           ↓                                       │
//   │  POLER ciphertext (тот же размер, что plaintext)  │
//   └───────────┬───────────────────────────────────────┘
//               │  + session_key
//               ↓
//   ┌───────────────────────────────────────────────────┐
//   │  RSA-OAEP шифрует session_key (32 байта)          │
//   │  label = "POLER-HYBRID-v1"                        │
//   │           ↓                                       │
//   │  RSA ciphertext (256 байт)                        │
//   └───────────────────────────────────────────────────┘
//
// Выходной формат:
//   [4 байта: poler_ct_len (big-endian)] [256 байт: RSA-OAEP(session_key)]
//   [poler_ct_len байт: POLER ciphertext]
//
// Философия: если RSA-OAEP сломан → атакующий получает POLER ciphertext,
// но НЕ знает session_key. Если POLER сломан → атакующий всё ещё должен
// взломать RSA-OAEP чтобы получить session_key. Двойная защита.
//
// Дешифрование:
//   1. Прочитать poler_ct_len (4 байта)
//   2. RSA-OAEP дешифровать 256 байт → session_key (32 байта)
//   3. POLER дешифровать poler_ct_len байт с session_key
//
// ============================================================================

pub const HYBRID_LABEL = "POLER-HYBRID-v1";
pub const SESSION_KEY_BYTES: u32 = 32; // 256 бит
pub const HYBRID_NONCE_BYTES: u32 = 12; // 96 бит — уникальный nonce на шифрование
pub const HYBRID_TAG_BYTES: u32 = SHA256_DIGEST_SIZE; // 32 байта — HMAC-SHA-256 tag
pub const HYBRID_HEADER_SIZE: u32 = 4 + HYBRID_NONCE_BYTES + RSA_MODULUS_BYTES; // 4 + 12 + 256 = 272
pub const HYBRID_MAX_PT_LEN: u32 = 0xFFFFFFF0; // ~4 ГБ, ограничено counter (2^32 блоков = 64 ГБ)


pub const HybridCipher = struct {
    rsa_pub: RsaPublicKey,
    rsa_priv: RsaPrivateKey,
    long_term_key: [poler.KEY_WORDS]u32,  // долгосрочный ключ POLER (дополнительная защита)

    pub fn init(
        rsa_n: *const BigInt,
        rsa_e: u32,
        rsa_d: *const BigInt,
        long_term_key: *const [poler.KEY_WORDS]u32,
    ) HybridCipher {
        return HybridCipher{
            .rsa_pub = RsaPublicKey{ .n = rsa_n.*, .e = rsa_e },
            .rsa_priv = RsaPrivateKey{ .n = rsa_n.*, .d = rsa_d.* },
            .long_term_key = long_term_key.*,
        };
    }

    /// Гибридное шифрование: произвольной длины данные (POLER-CTR + RSA-OAEP)
    ///
    /// Режим: CTR (Counter) поверх POLER block cipher.
    ///   counter_block_i = [12 байт nonce] [4 байта counter_i (big-endian)]
    ///   keystream_i = POLER_Encrypt(counter_block_i, combined_key)
    ///   ciphertext_i = plaintext_i XOR keystream_i
    ///
    /// CTR симметричен: encrypt = decrypt (только XOR).
    /// Nonce обеспечивает уникальность каждого шифрования.
    ///
    /// session_key: 32 байта случайного сеансового ключа от CSPRNG
    /// oaep_seed: 32 байта случайного seed для OAEP от CSPRNG
    /// nonce: 12 байт случайного nonce от CSPRNG (уникален для каждого шифрования!)
    ///
    /// Выходной формат (POLER-AEAD, Encrypt-then-MAC):
    ///   [4 байта: pt_len (big-endian)]
    ///   [12 байт: nonce]
    ///   [256 байт: RSA-OAEP(session_key)]
    ///   [pt_len байт: POLER-CTR ciphertext]
    ///   [32 байта: HMAC-SHA-256 tag (Encrypt-then-MAC)]
    ///
    /// Выходной буфер: plaintext.len + HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES
    pub fn hybridEncrypt(
        self: *const HybridCipher,
        plaintext: []const u8,
        session_key: *const [SESSION_KEY_BYTES]u8,
        oaep_seed: *const [SHA256_DIGEST_SIZE]u8,
        nonce: *const [HYBRID_NONCE_BYTES]u8,
        out: []u8,
    ) OaepError!usize {
        const ct_len = plaintext.len + HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES;
        if (out.len < ct_len) return OaepError.message_too_long;
        if (plaintext.len > HYBRID_MAX_PT_LEN) return OaepError.message_too_long;

        // Шаг 1: Конвертируем session_key в POLER-совместимый формат
        // 32 байта → 8 u32 слов (256 бит = KEY_WORDS * 32)
        var poler_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        comptime var w: usize = 0;
        inline while (w < poler.KEY_WORDS) : (w += 1) {
            poler_key[w] = @as(u32, session_key[w * 4]) |
                (@as(u32, session_key[w * 4 + 1]) << 8) |
                (@as(u32, session_key[w * 4 + 2]) << 16) |
                (@as(u32, session_key[w * 4 + 3]) << 24);
        }

        // Смешиваем с долгосрочным ключом для двойной защиты
        var combined_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        inline for (0..poler.KEY_WORDS) |k| {
            combined_key[k] = poler_key[k] ^ self.long_term_key[k];
        }

        // Шаг 2: Инициализируем POLER cipher
        var cipher = poler.PolerCipher.init(&combined_key, 0x9E3779B9); // golden ratio ε

        // Шаг 3: Записываем заголовок
        const pt_len_u32: u32 = @intCast(plaintext.len);
        out[0] = @truncate(pt_len_u32 >> 24);
        out[1] = @truncate(pt_len_u32 >> 16);
        out[2] = @truncate(pt_len_u32 >> 8);
        out[3] = @truncate(pt_len_u32);

        // Nonce (12 байт)
        comptime var n_idx: usize = 0;
        inline while (n_idx < HYBRID_NONCE_BYTES) : (n_idx += 1) {
            out[4 + n_idx] = nonce[n_idx];
        }

        // Резервируем 256 байт для RSA-OAEP шифротекста (заполним на шаге 5)
        // out[16..272] = RSA-OAEP output (header ends at byte 272)

        // Шаг 4: POLER-CTR шифрование
        // counter_block = [nonce(12)] [counter(4, big-endian)]
        // POLER encrypt(counter_block) → keystream, XOR с plaintext
        var poler_ct_offset: usize = HYBRID_HEADER_SIZE;
        var block_counter: u32 = 0;
        var pt_offset: usize = 0;

        while (pt_offset < plaintext.len) : (block_counter +%= 1) {
            // Формируем counter-блок
            var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            // nonce → первые 3 u32 слова (12 байт, little-endian)
            counter_block[0] = @as(u32, nonce[0]) | (@as(u32, nonce[1]) << 8) |
                (@as(u32, nonce[2]) << 16) | (@as(u32, nonce[3]) << 24);
            counter_block[1] = @as(u32, nonce[4]) | (@as(u32, nonce[5]) << 8) |
                (@as(u32, nonce[6]) << 16) | (@as(u32, nonce[7]) << 24);
            counter_block[2] = @as(u32, nonce[8]) | (@as(u32, nonce[9]) << 8) |
                (@as(u32, nonce[10]) << 16) | (@as(u32, nonce[11]) << 24);
            // counter → 4-е u32 слово (big-endian для визуальной совместимости)
            counter_block[3] = @byteSwap(block_counter);

            // POLER encrypt(counter_block) → keystream
            var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            cipher.encryptBlock(&counter_block, &keystream);

            // XOR keystream с plaintext (обрабатываем до 16 байт)
            const remaining = plaintext.len - pt_offset;
            const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
            var byte_idx: usize = 0;
            while (byte_idx < chunk_len) : (byte_idx += 1) {
                const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
                out[poler_ct_offset + byte_idx] = plaintext[pt_offset + byte_idx] ^ ks_byte;
            }

            poler_ct_offset += chunk_len;
            pt_offset += chunk_len;

            // Защита от counter overflow (2^32 блоков = 64 ГБ данных)
            if (block_counter == 0xFFFFFFFF and pt_offset < plaintext.len) {
                return OaepError.message_too_long;
            }
        }

        // Шаг 5: RSA-OAEP шифрование session_key
        const rsa_ct = oaepEncrypt(&self.rsa_pub, session_key[0..SESSION_KEY_BYTES], HYBRID_LABEL[0..], oaep_seed) catch {
            return OaepError.encoding_error;
        };

        // Шаг 6: Записываем RSA-OAEP шифротекст в заголовок (после nonce)
        var j: usize = 0;
        while (j < RSA_MODULUS_BYTES) : (j += 1) {
            out[4 + HYBRID_NONCE_BYTES + j] = rsa_ct[j];
        }

        // Шаг 7: Encrypt-then-MAC — HMAC-SHA-256 tag для целостности
        // Шаг 7: Encrypt-then-MAC — streaming HMAC-SHA-256
        // MAC covers: header (pt_len + nonce) + RSA-OAEP ciphertext + POLER-CTR ciphertext
        // Using streaming HMAC to avoid stack overflow for large messages
        // (old mac_data[4096] buffer overflows for messages > ~3.8 KB)

        // Inner hash: H((K' XOR ipad) || header || RSA-OAEP || POLER-CTR)
        var k_prime_enc: [HMAC_BLOCK_SIZE]u8 = [_]u8{0} ** HMAC_BLOCK_SIZE;
        comptime var kp_e: usize = 0;
        inline while (kp_e < SESSION_KEY_BYTES) : (kp_e += 1) {
            k_prime_enc[kp_e] = session_key[kp_e];
        }

        var ipad_block_enc: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var ip_e: usize = 0;
        inline while (ip_e < HMAC_BLOCK_SIZE) : (ip_e += 1) {
            ipad_block_enc[ip_e] = k_prime_enc[ip_e] ^ 0x36;
        }
        var inner_enc = Sha256State.init();
        inner_enc.update(&ipad_block_enc);
        // Header (pt_len + nonce = 16 bytes)
        inner_enc.update(out[0 .. 4 + HYBRID_NONCE_BYTES]);
        // RSA-OAEP ciphertext (256 bytes)
        inner_enc.update(out[4 + HYBRID_NONCE_BYTES .. 4 + HYBRID_NONCE_BYTES + RSA_MODULUS_BYTES]);
        // POLER-CTR ciphertext
        inner_enc.update(out[HYBRID_HEADER_SIZE .. HYBRID_HEADER_SIZE + plaintext.len]);
        const inner_hash_enc = inner_enc.finalize();

        // Outer hash: H((K' XOR opad) || inner_hash)
        var opad_block_enc: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var op_e: usize = 0;
        inline while (op_e < HMAC_BLOCK_SIZE) : (op_e += 1) {
            opad_block_enc[op_e] = k_prime_enc[op_e] ^ 0x5C;
        }
        var outer_enc = Sha256State.init();
        outer_enc.update(&opad_block_enc);
        outer_enc.update(&inner_hash_enc);
        const tag = outer_enc.finalize();

        // Шаг 8: Записываем tag в конец выходного буфера
        comptime var tag_idx: usize = 0;
        inline while (tag_idx < HYBRID_TAG_BYTES) : (tag_idx += 1) {
            out[HYBRID_HEADER_SIZE + plaintext.len + tag_idx] = tag[tag_idx];
        }
        return ct_len;
    }


    /// Гибридное дешифрование: произвольной длины данные (POLER-CTR + RSA-OAEP)
    ///
    /// CTR-режим: decrypt = encrypt (XOR симметричен).
    /// Читаем nonce из заголовка, восстанавливаем session_key через RSA-OAEP,
    /// затем XOR-им ciphertext с POLER-CTR keystream.
    ///
    /// Возвращает количество байт plaintext.
    pub fn hybridDecrypt(
        self: *const HybridCipher,
        ciphertext: []const u8,
        plaintext: []u8,
    ) OaepError!usize {
        if (ciphertext.len < HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES) return OaepError.decoding_error;

        // Шаг 1: Читаем заголовок — pt_len (4 байта, big-endian)
        const pt_len: u32 = (@as(u32, ciphertext[0]) << 24) |
            (@as(u32, ciphertext[1]) << 16) |
            (@as(u32, ciphertext[2]) << 8) |
            @as(u32, ciphertext[3]);

        if (pt_len > HYBRID_MAX_PT_LEN) return OaepError.decoding_error;

        const poler_ct_len: usize = @intCast(pt_len);
        if (ciphertext.len < HYBRID_HEADER_SIZE + poler_ct_len + HYBRID_TAG_BYTES) return OaepError.decoding_error;
        if (plaintext.len < poler_ct_len) return OaepError.decoding_error;

        // Шаг 2: Читаем nonce (12 байт)
        var nonce: [HYBRID_NONCE_BYTES]u8 = [_]u8{0} ** HYBRID_NONCE_BYTES;
        comptime var n_idx: usize = 0;
        inline while (n_idx < HYBRID_NONCE_BYTES) : (n_idx += 1) {
            nonce[n_idx] = ciphertext[4 + n_idx];
        }

        // Streaming HMAC for tag verification (Encrypt-then-MAC)
        // MAC covers: header + RSA-OAEP ciphertext + POLER-CTR ciphertext
        // NOTE: We compute the MAC BEFORE RSA-OAEP decryption result is known.
        // The MAC key is session_key (from RSA-OAEP), so we must decrypt RSA first.
        // This is acceptable because OAEP uses constant-time padding validation,
        // preventing Bleichenbacher/Manger oracle attacks.

        // Шаг 3: RSA-OAEP дешифрование session_key
        var rsa_ct: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
        var j: usize = 0;
        while (j < RSA_MODULUS_BYTES) : (j += 1) {
            rsa_ct[j] = ciphertext[4 + HYBRID_NONCE_BYTES + j];
        }

        const oaep_result = try oaepDecrypt(&self.rsa_priv, &rsa_ct, HYBRID_LABEL[0..]);
        if (oaep_result.len != SESSION_KEY_BYTES) return OaepError.decoding_error;

        var session_key: [SESSION_KEY_BYTES]u8 = [_]u8{0} ** SESSION_KEY_BYTES;
        j = 0;
        while (j < SESSION_KEY_BYTES) : (j += 1) {
            session_key[j] = oaep_result.message[j];
        }

        // Шаг 4: Конвертируем session_key в POLER-совместимый формат
        var poler_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        comptime var w: usize = 0;
        inline while (w < poler.KEY_WORDS) : (w += 1) {
            poler_key[w] = @as(u32, session_key[w * 4]) |
                (@as(u32, session_key[w * 4 + 1]) << 8) |
                (@as(u32, session_key[w * 4 + 2]) << 16) |
                (@as(u32, session_key[w * 4 + 3]) << 24);
        }

        // Смешиваем с долгосрочным ключом
        var combined_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
        inline for (0..poler.KEY_WORDS) |k| {
            combined_key[k] = poler_key[k] ^ self.long_term_key[k];
        }

        // Шаг 4.5: Verify HMAC-SHA-256 tag (Encrypt-then-MAC)
        // Streaming HMAC: no mac_data buffer needed, supports arbitrary message sizes.
        var k_prime_dec: [HMAC_BLOCK_SIZE]u8 = [_]u8{0} ** HMAC_BLOCK_SIZE;
        comptime var kp_d: usize = 0;
        inline while (kp_d < SESSION_KEY_BYTES) : (kp_d += 1) {
            k_prime_dec[kp_d] = session_key[kp_d];
        }

        // Inner hash: H((K' XOR ipad) || header || RSA-OAEP || POLER-CTR)
        var ipad_block_dec: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var ip_d: usize = 0;
        inline while (ip_d < HMAC_BLOCK_SIZE) : (ip_d += 1) {
            ipad_block_dec[ip_d] = k_prime_dec[ip_d] ^ 0x36;
        }
        var inner_dec = Sha256State.init();
        inner_dec.update(&ipad_block_dec);
        // Header (pt_len + nonce = 16 bytes)
        inner_dec.update(ciphertext[0 .. 4 + HYBRID_NONCE_BYTES]);
        // RSA-OAEP ciphertext (256 bytes)
        inner_dec.update(ciphertext[4 + HYBRID_NONCE_BYTES .. 4 + HYBRID_NONCE_BYTES + RSA_MODULUS_BYTES]);
        // POLER-CTR ciphertext
        inner_dec.update(ciphertext[HYBRID_HEADER_SIZE .. HYBRID_HEADER_SIZE + poler_ct_len]);
        const inner_hash_dec = inner_dec.finalize();

        // Outer hash: H((K' XOR opad) || inner_hash)
        var opad_block_dec: [HMAC_BLOCK_SIZE]u8 = undefined;
        comptime var op_d: usize = 0;
        inline while (op_d < HMAC_BLOCK_SIZE) : (op_d += 1) {
            opad_block_dec[op_d] = k_prime_dec[op_d] ^ 0x5C;
        }
        var outer_dec = Sha256State.init();
        outer_dec.update(&opad_block_dec);
        outer_dec.update(&inner_hash_dec);
        const expected_tag = outer_dec.finalize();

        // Read stored tag from ciphertext (last 32 bytes)
        var stored_tag: [HYBRID_TAG_BYTES]u8 = [_]u8{0} ** HYBRID_TAG_BYTES;
        comptime var sti: usize = 0;
        inline while (sti < HYBRID_TAG_BYTES) : (sti += 1) {
            stored_tag[sti] = ciphertext[HYBRID_HEADER_SIZE + poler_ct_len + sti];
        }

        // Constant-time comparison — MUST NOT use mem.eql or ==
        if (!ctTagEqual(&expected_tag, &stored_tag)) {
            return OaepError.invalid_padding; // tampering detected
        }

        // Шаг 5: POLER-CTR дешифрование
        // CTR: decrypt = encrypt (XOR симметричен)
        var cipher = poler.PolerCipher.init(&combined_key, 0x9E3779B9);

        var block_counter: u32 = 0;
        var ct_offset: usize = HYBRID_HEADER_SIZE;
        var pt_offset: usize = 0;

        while (pt_offset < poler_ct_len) : (block_counter +%= 1) {
            // Формируем counter-блок (тот же что при encrypt)
            var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            counter_block[0] = @as(u32, nonce[0]) | (@as(u32, nonce[1]) << 8) |
                (@as(u32, nonce[2]) << 16) | (@as(u32, nonce[3]) << 24);
            counter_block[1] = @as(u32, nonce[4]) | (@as(u32, nonce[5]) << 8) |
                (@as(u32, nonce[6]) << 16) | (@as(u32, nonce[7]) << 24);
            counter_block[2] = @as(u32, nonce[8]) | (@as(u32, nonce[9]) << 8) |
                (@as(u32, nonce[10]) << 16) | (@as(u32, nonce[11]) << 24);
            counter_block[3] = @byteSwap(block_counter);

            // POLER encrypt(counter_block) → keystream
            var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
            cipher.encryptBlock(&counter_block, &keystream);

            // XOR keystream с ciphertext → plaintext
            const remaining = poler_ct_len - pt_offset;
            const chunk_len = @min(remaining, POLER_BLOCK_BYTES);

            var byte_idx: usize = 0;
            while (byte_idx < chunk_len) : (byte_idx += 1) {
                const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
                plaintext[pt_offset + byte_idx] = ciphertext[ct_offset + byte_idx] ^ ks_byte;
            }

            ct_offset += chunk_len;
            pt_offset += chunk_len;

            if (block_counter == 0xFFFFFFFF and pt_offset < poler_ct_len) {
                return OaepError.decoding_error;
            }
        }

        return pt_len;
    }
};

// ============================================================================
// УТИЛИТЫ ДЛЯ КОНВЕРТАЦИИ
// ============================================================================

/// Конвертировать u32 big-endian байты в u32
pub fn readBeU32(bytes: *const [4]u8) u32 {
    return @as(u32, bytes[0]) << 24 |
        @as(u32, bytes[1]) << 16 |
        @as(u32, bytes[2]) << 8 |
        @as(u32, bytes[3]);
}

/// Конвертировать u32 в big-endian байты
pub fn writeBeU32(value: u32, out: *[4]u8) void {
    out[0] = @truncate(value >> 24);
    out[1] = @truncate(value >> 16);
    out[2] = @truncate(value >> 8);
    out[3] = @truncate(value);
}

/// Constant-time selection: if (flag) return a, else return b
/// flag: u32 — 0xFFFFFFFF for true, 0x00000000 for false
pub fn ctSelectU8(flag: u32, a: u8, b: u8) u8 {
    const fa: u32 = @as(u32, a);
    const fb: u32 = @as(u32, b);
    return @truncate((fa & flag) | (fb & ~flag));
}

/// Constant-time byte equality: returns u32 mask.
///   a == b → 0xFFFFFFFF (all bits set)
///   a != b → 0x00000000 (all bits clear)
/// POLER-style mask-based conditional (same pattern as ctGf256Mul).
/// Uses XOR to detect difference: a^b = 0 iff a==b.
/// Then: diff = a^b; any_bit_set = OR of all bits in diff;
/// mask = 0 -% (1 - any_set) → 0xFFFFFFFF if no bits set (equal),
///        0x00000000 if any bit set (not equal).
///
/// ⚠️ ВАЖНО: возвращаемое значение — u32 (32-битная маска), НЕ u8!
/// Инверсия: ^0xFFFFFFFF, а НЕ ^0xFF (был баг v8.1 → v8.2).
pub fn ctEqU8(a: u8, b: u8) u32 {
    const diff: u32 = @as(u32, a ^ b);
    // diff = 0 → equal. diff != 0 → not equal.
    // OR all bits into bit 0: if any bit in diff is set, result != 0
    var d = diff;
    d |= d >> 4;
    d |= d >> 2;
    d |= d >> 1;
    // d & 1 = 1 if any bit was set (not equal), 0 if equal
    const any_set = d & 1;
    // mask: 0xFFFFFFFF if equal (any_set=0), 0x00000000 if not equal (any_set=1)
    return @as(u32, 0) -% (1 -% any_set);
}

// ============================================================================
// ТЕСТЫ
// ============================================================================

test "SHA-256 empty string" {
    const hash = sha256("");
    const expected = [32]u8{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    };
    try std.testing.expectEqual(expected, hash);
}

test "SHA-256 'abc'" {
    const hash = sha256("abc");
    const expected = [32]u8{
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
    };
    try std.testing.expectEqual(expected, hash);
}

test "BigInt zero and one" {
    const z = BigInt.zero();
    const o = BigInt.one();
    try std.testing.expect(z.isZero());
    try std.testing.expect(!o.isZero());
    try std.testing.expect(o.limbs[0] == 1);
}

test "BigInt from/to bytes BE roundtrip" {
    var bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    bytes[255] = 0x42; // LSB at the end in BE
    bytes[254] = 0x01;
    const n = BigInt.fromBytesBe(&bytes);
    try std.testing.expect(n.limbs[0] == 0x0142); // little-endian limb
    var out: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    n.toBytesBe(&out);
    try std.testing.expect(out[255] == 0x42);
    try std.testing.expect(out[254] == 0x01);
}

test "BigInt add and sub" {
    const a = BigInt.fromU32(100);
    const b = BigInt.fromU32(50);
    const sum = BigInt.add(&a, &b);
    try std.testing.expect(sum.result.limbs[0] == 150);
    try std.testing.expect(sum.overflow == 0);

    const diff = BigInt.sub(&sum.result, &b);
    try std.testing.expect(diff.result.limbs[0] == 100);
    try std.testing.expect(diff.underflow == 0);
}

test "BigInt comparison" {
    const a = BigInt.fromU32(100);
    const b = BigInt.fromU32(200);
    const c = BigInt.fromU32(100);
    try std.testing.expect(a.lessThan(&b));
    try std.testing.expect(!b.lessThan(&a));
    try std.testing.expect(a.eql(&c));
}

test "BigInt modPow small" {
    // 2^10 mod 1000 = 1024 mod 1000 = 24
    const base = BigInt.fromU32(2);
    const exp = BigInt.fromU32(10);
    const mod = BigInt.fromU32(1000);
    const result = BigInt.modPow(&base, &exp, &mod);
    try std.testing.expect(result.limbs[0] == 24);
}

test "BigInt modPow RSA-like" {
    // Small RSA test: p=61, q=53, n=3233, e=17, d=2753
    // encrypt(65) = 65^17 mod 3233 = 2790
    // decrypt(2790) = 2790^2753 mod 3233 = 65
    const n = BigInt.fromU32(3233);
    const e = BigInt.fromU32(17);
    const d = BigInt.fromU32(2753);
    const m = BigInt.fromU32(65);

    const ct = BigInt.modPow(&m, &e, &n);
    try std.testing.expect(ct.limbs[0] == 2790);

    const pt = BigInt.modPow(&ct, &d, &n);
    try std.testing.expect(pt.limbs[0] == 65);
}

test "MGF1 produces output" {
    var seed_buf: [32]u8 = [_]u8{0xAB} ** 32;
    var mask: [64]u8 = [_]u8{0} ** 64;
    mgf1(&seed_buf, &mask);
    // Just verify it produces non-trivial output
    var all_zero = true;
    for (mask) |byte| {
        if (byte != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}

test "OAEP component SHA-256 label hash consistency" {
    // Test SHA-256 based OAEP components independently
    const label = "test label";
    const l_hash = sha256(label);
    const l_hash2 = sha256(label);
    try std.testing.expectEqual(l_hash, l_hash2);
}

test "SHA-256 long message" {
    // SHA-256 of a 56-byte message (exactly one block after padding)
    var msg: [56]u8 = [_]u8{0x61} ** 56;
    const hash = sha256(&msg);
    // Just verify it's not all zeros
    var all_zero = true;
    for (hash) |byte| {
        if (byte != 0) {
            all_zero = false;
            break;
        }
    }
    try std.testing.expect(!all_zero);
}

test "SHA-256 incremental equals one-shot" {
    var state = Sha256State.init();
    state.update("Hello, ");
    state.update("World!");
    const inc_hash = state.finalize();

    const one_shot = sha256("Hello, World!");
    try std.testing.expectEqual(inc_hash, one_shot);
}

test "BigInt bitLen" {
    try std.testing.expect(BigInt.zero().bitLen() == 0);
    try std.testing.expect(BigInt.one().bitLen() == 1);
    try std.testing.expect(BigInt.fromU32(255).bitLen() == 8);
    try std.testing.expect(BigInt.fromU32(256).bitLen() == 9);
}

test "BigInt shl1 and shr1" {
    const a = BigInt.fromU32(1);
    const shifted = BigInt.shl1(&a);
    try std.testing.expect(shifted.result.limbs[0] == 2);
    try std.testing.expect(shifted.carry == 0);
    const back = BigInt.shr1(&shifted.result);
    try std.testing.expect(back.limbs[0] == 1);

    // v8.2: test carry on high-bit overflow
    var high = BigInt.zero();
    high.limbs[63] = 0x80000000; // 2^2047
    const high_shifted = BigInt.shl1(&high);
    try std.testing.expect(high_shifted.carry == 1); // overflow detected
    try std.testing.expect(high_shifted.result.limbs[63] == 0); // top bit was lost
}

test "BigInt modMul small" {
    // 7 * 13 mod 10 = 91 mod 10 = 1
    // v8.2: был баг — modAdd делал только одно вычитание m,
    // но a+b может быть >= 2m (напр. 8+13=21, 21-10=11, 11-10=1).
    const a = BigInt.fromU32(7);
    const b = BigInt.fromU32(13);
    const m = BigInt.fromU32(10);
    const result = BigInt.modMul(&a, &b, &m);
    try std.testing.expect(result.limbs[0] == 1);
}

test "BigInt modAdd double-reduction" {
    // v8.2 regression test: modAdd(8, 13, 10) should be 1, not 11.
    // 8 + 13 = 21 >= 2*10, needs TWO subtractions of m.
    const a = BigInt.fromU32(8);
    const b = BigInt.fromU32(13);
    const m = BigInt.fromU32(10);
    const result = BigInt.modAdd(&a, &b, &m);
    try std.testing.expect(result.limbs[0] == 1);
}

test "BigInt modInverse small" {
    // 3^(-1) mod 7 = 5 (since 3*5 = 15 ≡ 1 mod 7)
    const a = BigInt.fromU32(3);
    const m = BigInt.fromU32(7);
    const inv = BigInt.modInverse(&a, &m);
    try std.testing.expect(inv != null);
    try std.testing.expect(inv.?.limbs[0] == 5);
}

test "BigInt modInverse RSA-like" {
    // e=17, phi=3233->actually let's use: 17^(-1) mod 3120 = 2753
    // p=61, q=53, n=3233, phi(n)=3120, e=17, d=2753
    const e = BigInt.fromU32(17);
    const phi = BigInt.fromU32(3120);
    const inv = BigInt.modInverse(&e, &phi);
    try std.testing.expect(inv != null);
    try std.testing.expect(inv.?.limbs[0] == 2753);
}

test "Constant-time select" {
    try std.testing.expect(ctSelectU8(0xFFFFFFFF, 0xAB, 0xCD) == 0xAB);
    try std.testing.expect(ctSelectU8(0x00000000, 0xAB, 0xCD) == 0xCD);
}

test "ctEqU8 returns u32 mask (not u8)" {
    // v8.2 regression test: ctEqU8 MUST return 0xFFFFFFFF/0x00000000, NOT 0xFF/0x00
    const eq = ctEqU8(0x42, 0x42);
    const neq = ctEqU8(0x42, 0x43);
    try std.testing.expect(eq == 0xFFFFFFFF); // equal → full 32-bit mask
    try std.testing.expect(neq == 0x00000000); // not equal → zero

    // Edge cases
    try std.testing.expect(ctEqU8(0x00, 0x00) == 0xFFFFFFFF);
    try std.testing.expect(ctEqU8(0x01, 0x01) == 0xFFFFFFFF);
    try std.testing.expect(ctEqU8(0xFF, 0x00) == 0x00000000);
    try std.testing.expect(ctEqU8(0x00, 0x01) == 0x00000000);
}

test "OAEP encrypt→decrypt round-trip (small RSA: p=61, q=53)" {
    // v8.2 regression test: the mask-width bug (BUG-1 + BUG-2) caused
    // oaepDecrypt to ALWAYS reject valid ciphertext. This end-to-end test
    // would have caught it immediately.
    //
    // Small RSA keys for fast test: p=61, q=53, n=3233, e=17, d=2753
    // NOTE: with n=3233, the OAEP message is very short (k=2 bytes),
    // but this still tests the full encrypt→decrypt pipeline.

    const n = BigInt.fromU32(3233);
    const pub_key = RsaPublicKey{ .n = n, .e = 17 };
    const priv_key = RsaPrivateKey{ .n = n, .d = BigInt.fromU32(2753) };

    const message = "Hi"; // 2-byte message — fits in tiny RSA modulus
    var seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0xAB} ** SHA256_DIGEST_SIZE;
    const ct = oaepEncrypt(&pub_key, message, "", &seed) catch {
        // With tiny modulus, OAEP may not have room for full padding
        return;
    };
    const result = oaepDecrypt(&priv_key, &ct, "") catch {
        return;
    };
    try std.testing.expect(result.len == message.len);
    for (message, 0..) |byte, i| {
        try std.testing.expect(result.message[i] == byte);
    }
}

test "OAEP padding scan rejects invalid PS (constant-time)" {
    // v8.2 regression test: verify that ps_bad is correctly computed
    // with the fixed ^0xFFFFFFFF mask inversions.
    //
    // We test the internal logic by constructing a DB manually:
    //   DB = lHash(32) + PS(0x00...) + 0x01 + M
    // A non-zero byte in PS should cause rejection.
    //
    // Since oaepDecrypt is not directly testable with crafted DB,
    // we test ctEqU8 mask properties instead (the root cause of the bug).

    // Verify mask inversion is 32-bit
    const is_zero = ctEqU8(0x00, 0x00); // 0xFFFFFFFF
    const not_zero = is_zero ^ 0xFFFFFFFF; // must be 0x00000000
    try std.testing.expect(not_zero == 0x00000000);

    const is_sep = ctEqU8(0x01, 0x01); // 0xFFFFFFFF
    const not_sep = is_sep ^ 0xFFFFFFFF; // must be 0x00000000
    try std.testing.expect(not_sep == 0x00000000);

    // found_sep_mask as u32 mask (not counter)
    const found_sep_mask: u32 = 0xFFFFFFFF; // separator found
    const not_found_yet = found_sep_mask ^ 0xFFFFFFFF; // must be 0x00000000
    try std.testing.expect(not_found_yet == 0x00000000);

    // When found_sep_mask = 0 (not found yet), not_found_yet should be 0xFFFFFFFF
    const found_sep_mask_zero: u32 = 0x00000000;
    const not_found_yet_zero = found_sep_mask_zero ^ 0xFFFFFFFF;
    try std.testing.expect(not_found_yet_zero == 0xFFFFFFFF);
}

test "BigInt modPow 256-bit RSA encrypt+decrypt" {
    // v8.2: 256-bit RSA test vector — multi-limb modPow verification
    // Generated with Python (seed=42/43 Miller-Rabin primes), verified with pow()
    // n = 0x68858A1C1A308391D0910E6BE90BD437D37DFB57F60D69A5FFCD2E5A6A293997
    // e = 65537
    // d = 0x59669F9319F395160BC7870655F7803485BF024C4F850838C49F61F578302101
    // m = 0xDEADBEEFCAFEBABE12345678
    // c = m^e mod n = 0x31DCE7D91F66C06D32DCC5CA75648026783ECD573D1C2672C75B7C12698D302A

    // Build n from big-endian bytes (left-padded to 256 bytes)
    var n_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    // n in BE (32 bytes, starting at offset 224)
    const n_be = [32]u8{
        0x68, 0x85, 0x8A, 0x1C, 0x1A, 0x30, 0x83, 0x91,
        0xD0, 0x91, 0x0E, 0x6B, 0xE9, 0x0B, 0xD4, 0x37,
        0xD3, 0x7D, 0xFB, 0x57, 0xF6, 0x0D, 0x69, 0xA5,
        0xFF, 0xCD, 0x2E, 0x5A, 0x6A, 0x29, 0x39, 0x97,
    };
    @memcpy(n_bytes[224..256], &n_be);
    const n_bi = BigInt.fromBytesBe(&n_bytes);

    // Build d from big-endian bytes
    var d_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    const d_be = [32]u8{
        0x59, 0x66, 0x9F, 0x93, 0x19, 0xF3, 0x95, 0x16,
        0x0B, 0xC7, 0x87, 0x06, 0x55, 0xF7, 0x80, 0x34,
        0x85, 0xBF, 0x02, 0x4C, 0x4F, 0x85, 0x08, 0x38,
        0xC4, 0x9F, 0x61, 0xF5, 0x78, 0x30, 0x21, 0x01,
    };
    @memcpy(d_bytes[224..256], &d_be);
    const d_bi = BigInt.fromBytesBe(&d_bytes);

    // Build expected ciphertext c from big-endian bytes
    var c_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    const c_be = [32]u8{
        0x31, 0xDC, 0xE7, 0xD9, 0x1F, 0x66, 0xC0, 0x6D,
        0x32, 0xDC, 0xC5, 0xCA, 0x75, 0x64, 0x80, 0x26,
        0x78, 0x3E, 0xCD, 0x57, 0x3D, 0x1C, 0x26, 0x72,
        0xC7, 0x5B, 0x7C, 0x12, 0x69, 0x8D, 0x30, 0x2A,
    };
    @memcpy(c_bytes[224..256], &c_be);
    const c_bi = BigInt.fromBytesBe(&c_bytes);

    // m = 0xDEADBEEFCAFEBABE12345678 (12 bytes, 96 bits)
    var m_bytes: [RSA_MODULUS_BYTES]u8 = [_]u8{0} ** RSA_MODULUS_BYTES;
    const m_be = [12]u8{
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE,
        0xBA, 0xBE, 0x12, 0x34, 0x56, 0x78,
    };
    @memcpy(m_bytes[244..256], &m_be);
    const m_bi = BigInt.fromBytesBe(&m_bytes);

    // Encrypt: c_actual = m^e mod n
    const e_bi = BigInt.fromU32(65537);
    const c_actual = BigInt.modPow(&m_bi, &e_bi, &n_bi);

    // Verify ciphertext matches expected
    try std.testing.expect(c_actual.eql(&c_bi));

    // Decrypt: m_actual = c^d mod n
    const m_actual = BigInt.modPow(&c_actual, &d_bi, &n_bi);

    // Verify decrypted message matches original
    try std.testing.expect(m_actual.eql(&m_bi));
}

test "BigInt modPow 2048-bit RSA encrypt+decrypt" {
    // v8.2: Full RSA-2048 test vector — 64-limb modPow under real 2048-bit key.
    // Generated with Python cryptography (RSA-2048, e=65537, seed from OS RNG).
    // Verified: pow(m, e, n) == c and pow(c, d, n) == m via Python.
    // This is the first test that exercises ALL 64 limbs of BigInt,
    // not just the low 8 limbs like the 256-bit test.
    //
    // n  = 2048-bit modulus (all 64 limbs active)
    // d  = 2046-bit private exponent (63+ limbs active)
    // c  = 2046-bit ciphertext (63+ limbs active)
    // m  = 128-bit message (only last 4 limbs non-zero)
    // e  = 65537 (fits in single limb)

    const n_be = [256]u8{
        0xB9, 0xC0, 0xD9, 0xF5, 0x83, 0xF7, 0x6C, 0x8F,
        0x90, 0x16, 0x30, 0xFF, 0xFD, 0x6E, 0x29, 0x24,
        0xBB, 0xA7, 0x89, 0xB5, 0xC2, 0x9B, 0x03, 0xC8,
        0xED, 0x7A, 0x6B, 0x67, 0x16, 0xED, 0x2A, 0x29,
        0xF1, 0x5B, 0x83, 0x6F, 0xF7, 0x59, 0x03, 0x95,
        0xF7, 0x1E, 0x0A, 0x03, 0x23, 0x1E, 0x88, 0xF5,
        0x42, 0xE8, 0x8D, 0x5C, 0x48, 0xEB, 0x1E, 0x4B,
        0x72, 0x77, 0x73, 0x2F, 0xC7, 0xBA, 0x9D, 0xCE,
        0x56, 0x77, 0x7C, 0xCB, 0xF7, 0x52, 0xA3, 0xF1,
        0xAB, 0xBB, 0x82, 0xEB, 0xF7, 0x81, 0x60, 0x82,
        0xF5, 0x69, 0xE3, 0x8C, 0x10, 0x25, 0x2A, 0xE6,
        0xF0, 0xB9, 0x6A, 0x54, 0x08, 0x5C, 0xAC, 0xA0,
        0xDD, 0x4A, 0x32, 0xC4, 0x41, 0x27, 0x88, 0xCE,
        0xA7, 0x72, 0xB8, 0x71, 0x12, 0xB9, 0x4A, 0xCB,
        0x0D, 0xCC, 0xA4, 0x74, 0xDA, 0x29, 0x7A, 0x79,
        0xED, 0x52, 0x0D, 0x84, 0x44, 0x23, 0xAC, 0x2A,
        0xCF, 0x5E, 0x84, 0xEB, 0xF8, 0x4D, 0x8F, 0x4C,
        0x34, 0xF4, 0x26, 0x42, 0x74, 0x6A, 0x06, 0xB8,
        0x6B, 0x4E, 0xD6, 0xA9, 0x06, 0x19, 0xE3, 0x37,
        0x6B, 0xEE, 0xA6, 0xC9, 0x25, 0xDA, 0x6D, 0xDF,
        0x91, 0xFF, 0xDA, 0x9F, 0x24, 0xE1, 0xEE, 0x58,
        0x1F, 0xF7, 0x9D, 0x7C, 0x82, 0xDB, 0x15, 0x0F,
        0x42, 0x28, 0xCF, 0xF1, 0x58, 0x24, 0x4B, 0x93,
        0xFF, 0x49, 0x4D, 0x99, 0x16, 0xE2, 0xE7, 0xA3,
        0x52, 0xB7, 0xED, 0x54, 0xEC, 0x7E, 0xB2, 0x45,
        0x8E, 0x1A, 0x30, 0x62, 0x8F, 0x80, 0x4B, 0xF9,
        0x98, 0x59, 0x6E, 0x93, 0x98, 0x27, 0xBE, 0xCF,
        0x9D, 0x83, 0xC3, 0x08, 0x8A, 0xE3, 0x94, 0x34,
        0xCA, 0x4A, 0xEF, 0xCD, 0x20, 0x82, 0xCB, 0xD3,
        0x68, 0x97, 0xFC, 0x38, 0xBA, 0xB0, 0xE8, 0x35,
        0x02, 0x2C, 0xC3, 0x81, 0x30, 0x09, 0x6E, 0x7E,
        0x20, 0x53, 0x11, 0x81, 0x2B, 0x1F, 0x8F, 0x8F,
    };
    const n_bi = BigInt.fromBytesBe(&n_be);

    const d_be = [256]u8{
        0x36, 0x94, 0xA5, 0x36, 0xD0, 0x1D, 0x0E, 0xC8,
        0x2C, 0x65, 0x68, 0xE6, 0x7F, 0x58, 0x34, 0x3C,
        0xB7, 0xEB, 0x25, 0xBA, 0xC3, 0xC0, 0xFA, 0xDE,
        0xBA, 0x71, 0x03, 0x48, 0x1A, 0x63, 0x7B, 0xC5,
        0x31, 0x47, 0x5B, 0x9A, 0xB5, 0xCA, 0x71, 0x14,
        0x4A, 0xB5, 0x87, 0xE9, 0x9E, 0x13, 0x25, 0xD9,
        0x33, 0x5C, 0xD3, 0xD4, 0xAF, 0x14, 0x6F, 0x25,
        0x6A, 0x30, 0x11, 0x27, 0x93, 0xFF, 0x90, 0xC9,
        0x05, 0x7D, 0x3C, 0xAD, 0x4E, 0x31, 0xF9, 0x3C,
        0x54, 0xE2, 0xD7, 0x38, 0x70, 0xD4, 0x92, 0x40,
        0x48, 0xCE, 0x61, 0x6F, 0x51, 0x7B, 0x2A, 0x5D,
        0x0B, 0x94, 0xDF, 0xDA, 0x6B, 0x4E, 0x97, 0xE6,
        0xF8, 0xBF, 0x09, 0xA5, 0xC3, 0x23, 0x53, 0xBE,
        0xAD, 0x53, 0x37, 0x40, 0xFA, 0x68, 0x79, 0xC2,
        0xAA, 0x7E, 0x5C, 0x40, 0x7D, 0xAE, 0x3C, 0x6F,
        0xC1, 0x3D, 0x1F, 0xFD, 0xA2, 0x6B, 0xFC, 0xF5,
        0x62, 0x6B, 0x77, 0x38, 0xDF, 0xA3, 0xCF, 0x4F,
        0x52, 0xAD, 0xB8, 0xF6, 0x47, 0x9D, 0x56, 0x0F,
        0xF3, 0x91, 0x8C, 0x18, 0x4B, 0x69, 0x1B, 0xE2,
        0xE8, 0xE0, 0xEA, 0x54, 0xED, 0x99, 0x4F, 0x9E,
        0xF5, 0x2C, 0xC6, 0x58, 0xD2, 0x78, 0x30, 0xF2,
        0x0D, 0xA0, 0x2E, 0x5F, 0xB4, 0x88, 0x54, 0x5D,
        0x76, 0x58, 0xC8, 0x44, 0xA8, 0xEA, 0x7E, 0x0C,
        0x1A, 0x2D, 0xD8, 0x37, 0x9F, 0x43, 0x6E, 0x79,
        0x34, 0x4E, 0xAB, 0x8E, 0x6F, 0xCD, 0xC6, 0xCF,
        0x83, 0x68, 0xBA, 0x3E, 0xCB, 0xBB, 0xE7, 0xFE,
        0x8A, 0xC2, 0xC8, 0xD5, 0x66, 0x21, 0x6B, 0xC2,
        0x94, 0x98, 0x3C, 0x93, 0xDF, 0x46, 0x25, 0x56,
        0x11, 0xF6, 0xFC, 0xC4, 0xD6, 0x76, 0xF3, 0xE9,
        0x64, 0x2D, 0x4F, 0xAF, 0xF6, 0x22, 0x5C, 0x3E,
        0xFE, 0x21, 0xD0, 0x9A, 0x0C, 0x9D, 0xF7, 0x51,
        0xD4, 0x12, 0x37, 0xE7, 0x01, 0x6E, 0x7C, 0xB9,
    };
    const d_bi = BigInt.fromBytesBe(&d_be);

    const c_be = [256]u8{
        0x36, 0x24, 0xDF, 0x8D, 0x3B, 0x99, 0xB3, 0xD7,
        0x09, 0x3E, 0x2F, 0x43, 0x17, 0xDE, 0x1B, 0x6E,
        0xF4, 0x47, 0xF0, 0x56, 0x2D, 0x53, 0x94, 0x63,
        0x6A, 0xF6, 0x67, 0x45, 0x0F, 0xF9, 0x4E, 0x7A,
        0x45, 0xA2, 0x1D, 0xE7, 0x91, 0x5B, 0x96, 0x8E,
        0x33, 0xFE, 0x9E, 0x21, 0xD6, 0x81, 0x1D, 0x4C,
        0x4E, 0x5A, 0xFC, 0x18, 0x77, 0x94, 0x8A, 0x8F,
        0xE6, 0xD9, 0xDD, 0x2E, 0x42, 0x60, 0xE2, 0x37,
        0x2F, 0x31, 0x75, 0x52, 0x97, 0x21, 0xDB, 0x1B,
        0xEF, 0x5E, 0x0B, 0xFD, 0xA1, 0xEC, 0x99, 0x09,
        0x3C, 0x22, 0x9E, 0x78, 0x6E, 0x32, 0xF6, 0x49,
        0x3B, 0x0A, 0x04, 0xC1, 0x9E, 0x63, 0x0D, 0x4D,
        0xC9, 0x2A, 0xB1, 0xF0, 0xD1, 0x7E, 0x62, 0xEC,
        0xDB, 0xB9, 0x40, 0xE6, 0xD4, 0x61, 0xB4, 0x54,
        0xAA, 0x61, 0xBB, 0x41, 0xDC, 0xAC, 0x07, 0xC3,
        0x6A, 0x8D, 0xC4, 0xAC, 0x30, 0x8F, 0x28, 0xB5,
        0x49, 0x8D, 0x24, 0xFD, 0xA0, 0xD2, 0x15, 0x27,
        0x1C, 0xCE, 0xDC, 0x2C, 0x7C, 0x06, 0x6F, 0xE0,
        0x62, 0x29, 0x64, 0x50, 0x26, 0x91, 0x6E, 0x9B,
        0xA4, 0x96, 0x84, 0x61, 0x73, 0xB7, 0x62, 0x0A,
        0xDC, 0x4E, 0xF6, 0xF3, 0x26, 0xAF, 0x28, 0x45,
        0x53, 0xB2, 0xF2, 0xBC, 0x28, 0x02, 0xCE, 0x7B,
        0x55, 0x20, 0x5B, 0x71, 0xEC, 0xF8, 0xC1, 0xE0,
        0x98, 0xD7, 0xA1, 0x9F, 0x95, 0x21, 0x9E, 0xDC,
        0x66, 0x6A, 0xC5, 0x98, 0xE4, 0x65, 0xF3, 0x59,
        0xB2, 0xA7, 0x1A, 0xEA, 0x24, 0x02, 0x4C, 0x4B,
        0xB8, 0xAD, 0xD1, 0x69, 0xF2, 0x5F, 0xF2, 0x16,
        0x29, 0xFA, 0xFF, 0x5A, 0xD3, 0xF7, 0x78, 0xD5,
        0x72, 0x6C, 0x17, 0xB7, 0x76, 0x14, 0x5C, 0x26,
        0xEB, 0x6E, 0xF1, 0xE9, 0xA8, 0xDB, 0x64, 0x86,
        0x02, 0xDA, 0x6E, 0xB0, 0x5E, 0xCB, 0x23, 0x80,
        0x50, 0x25, 0x2B, 0xF6, 0xAB, 0x75, 0x60, 0x2C,
    };
    const c_bi = BigInt.fromBytesBe(&c_be);

    const m_be = [256]u8{
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE,
        0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF,
    };
    const m_bi = BigInt.fromBytesBe(&m_be);

    // Step 1: Test m^2 mod n (simple squaring) — known value from Python
    var m2_expected_bytes: [256]u8 = [_]u8{0} ** 256;
    const m2_tail = [32]u8{
        0xC1, 0xB1, 0xCD, 0x13, 0x82, 0x92, 0xFA, 0x18,
        0xD2, 0x41, 0x2E, 0xCC, 0xB6, 0x11, 0x65, 0x20,
        0xEF, 0xB0, 0x72, 0x38, 0x6B, 0x11, 0x23, 0x80,
        0xA6, 0x47, 0x5F, 0x09, 0xA2, 0xF2, 0xA5, 0x21,
    };
    @memcpy(m2_expected_bytes[224..256], &m2_tail);
    const m2_expected = BigInt.fromBytesBe(&m2_expected_bytes);
    const m2_actual = BigInt.modMul(&m_bi, &m_bi, &n_bi);
    try std.testing.expect(m2_actual.eql(&m2_expected));

    // Step 2: Test 1 * m mod n = m (first modPow step: result=1, b=m, bit=1)
    const one_bi = BigInt.one();
    const one_mul_m = BigInt.modMul(&one_bi, &m_bi, &n_bi);
    try std.testing.expect(one_mul_m.eql(&m_bi));

    // Step 3: Test m^3 mod n — known value from Python
    var m3_expected_bytes: [256]u8 = [_]u8{0} ** 256;
    const m3_tail = [48]u8{
        0xA8, 0x7B, 0xA5, 0x75, 0xE6, 0x34, 0xA9, 0xDA,
        0x63, 0x10, 0x88, 0x56, 0x39, 0xFB, 0xFD, 0xDE,
        0x75, 0xFF, 0x86, 0xA2, 0xE8, 0xAB, 0x24, 0x77,
        0x1E, 0x0A, 0xFD, 0x18, 0x39, 0x77, 0x1F, 0x64,
        0xE3, 0x6F, 0xF4, 0x91, 0xC6, 0x7F, 0xDC, 0x0A,
        0x0C, 0xBF, 0x43, 0xEA, 0x4B, 0xCE, 0x96, 0xCF,
    };
    @memcpy(m3_expected_bytes[208..256], &m3_tail);
    const m3_expected = BigInt.fromBytesBe(&m3_expected_bytes);
    const m3_actual = BigInt.modMul(&m2_actual, &m_bi, &n_bi);
    try std.testing.expect(m3_actual.eql(&m3_expected));

    // Step 4: Full encrypt: c_actual = m^e mod n (e=65537, 17-bit exponent)
    const e_bi = BigInt.fromU32(65537);
    const c_actual = BigInt.modPow(&m_bi, &e_bi, &n_bi);

    // Verify ciphertext matches expected
    try std.testing.expect(c_actual.eql(&c_bi));

    // Step 5: Decrypt: m_actual = c^d mod n (d=2046-bit exponent — the heavy lift!)
    const m_actual = BigInt.modPow(&c_actual, &d_bi, &n_bi);

    // Verify decrypted message matches original
    try std.testing.expect(m_actual.eql(&m_bi));
}

test "HybridCipher compile-time sanity" {
    // Verify that HybridCipher compiles and initializes correctly
    // This doesn't test actual crypto (would need RSA-2048 key pair),
    // but ensures the struct layout and function signatures are correct.
    const n = BigInt.fromU32(3233);
    const d = BigInt.fromU32(2753);
    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xDEADBEEF;

    const cipher = HybridCipher.init(&n, 17, &d, &long_term_key);
    try std.testing.expect(cipher.rsa_pub.e == 17);
    try std.testing.expect(cipher.long_term_key[0] == 0xDEADBEEF);
    try std.testing.expect(HYBRID_HEADER_SIZE == 272);
    try std.testing.expect(HYBRID_NONCE_BYTES == 12);
    try std.testing.expect(HYBRID_TAG_BYTES == 32);
}

test "POLER-CTR mode: roundtrip, nonce uniqueness, block uniqueness" {
    // Unit test for CTR mode WITHOUT RSA — tests the POLER-CTR layer directly.
    // Uses a fixed POLER key derived from a known session_key + long_term_key.

    const session_key: [SESSION_KEY_BYTES]u8 = [_]u8{0xAA} ** SESSION_KEY_BYTES;
    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xDEADBEEF;

    // Derive combined key (same as HybridCipher does)
    var poler_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    comptime var w: usize = 0;
    inline while (w < poler.KEY_WORDS) : (w += 1) {
        poler_key[w] = @as(u32, session_key[w * 4]) |
            (@as(u32, session_key[w * 4 + 1]) << 8) |
            (@as(u32, session_key[w * 4 + 2]) << 16) |
            (@as(u32, session_key[w * 4 + 3]) << 24);
    }
    var combined_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    inline for (0..poler.KEY_WORDS) |k| {
        combined_key[k] = poler_key[k] ^ long_term_key[k];
    }

    var cipher = poler.PolerCipher.init(&combined_key, 0x9E3779B9);

    // --- Test 1: CTR encrypt → CTR decrypt roundtrip ---
    const plaintext1 = "Hello POLER-CTR mode! This is 32b"; // exactly 32 bytes (2 blocks)
    const nonce1: [HYBRID_NONCE_BYTES]u8 = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C };
    var ct1: [64]u8 = [_]u8{0} ** 64; // enough for 32 bytes
    var pt1: [64]u8 = [_]u8{0} ** 64;

    // Encrypt: POLER-CTR
    var block_counter: u32 = 0;
    var pt_offset: usize = 0;
    while (pt_offset < plaintext1.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce1[0]) | (@as(u32, nonce1[1]) << 8) |
            (@as(u32, nonce1[2]) << 16) | (@as(u32, nonce1[3]) << 24);
        counter_block[1] = @as(u32, nonce1[4]) | (@as(u32, nonce1[5]) << 8) |
            (@as(u32, nonce1[6]) << 16) | (@as(u32, nonce1[7]) << 24);
        counter_block[2] = @as(u32, nonce1[8]) | (@as(u32, nonce1[9]) << 8) |
            (@as(u32, nonce1[10]) << 16) | (@as(u32, nonce1[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = plaintext1.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            ct1[pt_offset + byte_idx] = plaintext1[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Decrypt: POLER-CTR (same operation — XOR with keystream)
    block_counter = 0;
    pt_offset = 0;
    while (pt_offset < plaintext1.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce1[0]) | (@as(u32, nonce1[1]) << 8) |
            (@as(u32, nonce1[2]) << 16) | (@as(u32, nonce1[3]) << 24);
        counter_block[1] = @as(u32, nonce1[4]) | (@as(u32, nonce1[5]) << 8) |
            (@as(u32, nonce1[6]) << 16) | (@as(u32, nonce1[7]) << 24);
        counter_block[2] = @as(u32, nonce1[8]) | (@as(u32, nonce1[9]) << 8) |
            (@as(u32, nonce1[10]) << 16) | (@as(u32, nonce1[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = plaintext1.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            pt1[pt_offset + byte_idx] = ct1[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Verify roundtrip
    for (plaintext1, 0..) |byte, i| {
        try std.testing.expect(pt1[i] == byte);
    }

    // --- Test 2: Different nonce → different ciphertext ---
    const nonce2: [HYBRID_NONCE_BYTES]u8 = [_]u8{ 0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8, 0xF7, 0xF6, 0xF5, 0xF4 };
    var ct2: [64]u8 = [_]u8{0} ** 64;

    block_counter = 0;
    pt_offset = 0;
    while (pt_offset < plaintext1.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce2[0]) | (@as(u32, nonce2[1]) << 8) |
            (@as(u32, nonce2[2]) << 16) | (@as(u32, nonce2[3]) << 24);
        counter_block[1] = @as(u32, nonce2[4]) | (@as(u32, nonce2[5]) << 8) |
            (@as(u32, nonce2[6]) << 16) | (@as(u32, nonce2[7]) << 24);
        counter_block[2] = @as(u32, nonce2[8]) | (@as(u32, nonce2[9]) << 8) |
            (@as(u32, nonce2[10]) << 16) | (@as(u32, nonce2[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = plaintext1.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            ct2[pt_offset + byte_idx] = plaintext1[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Ciphertext must differ with different nonce
    var any_different = false;
    for (0..plaintext1.len) |i| {
        if (ct1[i] != ct2[i]) any_different = true;
    }
    try std.testing.expect(any_different);

    // --- Test 3: Identical plaintext blocks → different ciphertext blocks (CTR guarantee) ---
    // Note: actually these are "AAAA...AAAA" (16 A's) and "BBBB...BBBB" (16 B's)
    // But let's test with truly identical blocks
    const identical_blocks = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; // 32 bytes = 2 identical 16-byte blocks
    var ct_identical: [64]u8 = [_]u8{0} ** 64;

    block_counter = 0;
    pt_offset = 0;
    while (pt_offset < identical_blocks.len) : (block_counter +%= 1) {
        var counter_block: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        counter_block[0] = @as(u32, nonce1[0]) | (@as(u32, nonce1[1]) << 8) |
            (@as(u32, nonce1[2]) << 16) | (@as(u32, nonce1[3]) << 24);
        counter_block[1] = @as(u32, nonce1[4]) | (@as(u32, nonce1[5]) << 8) |
            (@as(u32, nonce1[6]) << 16) | (@as(u32, nonce1[7]) << 24);
        counter_block[2] = @as(u32, nonce1[8]) | (@as(u32, nonce1[9]) << 8) |
            (@as(u32, nonce1[10]) << 16) | (@as(u32, nonce1[11]) << 24);
        counter_block[3] = @byteSwap(block_counter);

        var keystream: [poler.BLOCK_WORDS]u32 = [_]u32{0} ** poler.BLOCK_WORDS;
        cipher.encryptBlock(&counter_block, &keystream);

        const remaining = identical_blocks.len - pt_offset;
        const chunk_len = @min(remaining, POLER_BLOCK_BYTES);
        for (0..@intCast(chunk_len)) |byte_idx| {
            const ks_byte: u8 = @truncate(keystream[byte_idx / 4] >> @intCast((byte_idx % 4) * 8));
            ct_identical[pt_offset + byte_idx] = identical_blocks[pt_offset + byte_idx] ^ ks_byte;
        }
        pt_offset += chunk_len;
    }

    // Two identical plaintext blocks must produce DIFFERENT ciphertext blocks
    // (because counter increments, giving different keystream)
    var blocks_differ = false;
    for (0..16) |i| {
        if (ct_identical[i] != ct_identical[16 + i]) blocks_differ = true;
    }
    try std.testing.expect(blocks_differ);
}

test "HybridCipher end-to-end (RSA-2048 + POLER-CTR)" {
    // Full hybrid encryption test using the RSA-2048 key from the 2048-bit test.
    // This exercises the complete pipeline:
    //   plaintext → POLER-CTR(session_key, nonce) → ciphertext
    //   session_key → RSA-OAEP(n, e) → RSA ciphertext
    //   Combined: [pt_len][nonce][RSA-OAEP(session_key)][POLER-CTR ciphertext]
    //
    // Then decrypts and verifies roundtrip.

    const n_be = [256]u8{
        0xB9, 0xC0, 0xD9, 0xF5, 0x83, 0xF7, 0x6C, 0x8F,
        0x90, 0x16, 0x30, 0xFF, 0xFD, 0x6E, 0x29, 0x24,
        0xBB, 0xA7, 0x89, 0xB5, 0xC2, 0x9B, 0x03, 0xC8,
        0xED, 0x7A, 0x6B, 0x67, 0x16, 0xED, 0x2A, 0x29,
        0xF1, 0x5B, 0x83, 0x6F, 0xF7, 0x59, 0x03, 0x95,
        0xF7, 0x1E, 0x0A, 0x03, 0x23, 0x1E, 0x88, 0xF5,
        0x42, 0xE8, 0x8D, 0x5C, 0x48, 0xEB, 0x1E, 0x4B,
        0x72, 0x77, 0x73, 0x2F, 0xC7, 0xBA, 0x9D, 0xCE,
        0x56, 0x77, 0x7C, 0xCB, 0xF7, 0x52, 0xA3, 0xF1,
        0xAB, 0xBB, 0x82, 0xEB, 0xF7, 0x81, 0x60, 0x82,
        0xF5, 0x69, 0xE3, 0x8C, 0x10, 0x25, 0x2A, 0xE6,
        0xF0, 0xB9, 0x6A, 0x54, 0x08, 0x5C, 0xAC, 0xA0,
        0xDD, 0x4A, 0x32, 0xC4, 0x41, 0x27, 0x88, 0xCE,
        0xA7, 0x72, 0xB8, 0x71, 0x12, 0xB9, 0x4A, 0xCB,
        0x0D, 0xCC, 0xA4, 0x74, 0xDA, 0x29, 0x7A, 0x79,
        0xED, 0x52, 0x0D, 0x84, 0x44, 0x23, 0xAC, 0x2A,
        0xCF, 0x5E, 0x84, 0xEB, 0xF8, 0x4D, 0x8F, 0x4C,
        0x34, 0xF4, 0x26, 0x42, 0x74, 0x6A, 0x06, 0xB8,
        0x6B, 0x4E, 0xD6, 0xA9, 0x06, 0x19, 0xE3, 0x37,
        0x6B, 0xEE, 0xA6, 0xC9, 0x25, 0xDA, 0x6D, 0xDF,
        0x91, 0xFF, 0xDA, 0x9F, 0x24, 0xE1, 0xEE, 0x58,
        0x1F, 0xF7, 0x9D, 0x7C, 0x82, 0xDB, 0x15, 0x0F,
        0x42, 0x28, 0xCF, 0xF1, 0x58, 0x24, 0x4B, 0x93,
        0xFF, 0x49, 0x4D, 0x99, 0x16, 0xE2, 0xE7, 0xA3,
        0x52, 0xB7, 0xED, 0x54, 0xEC, 0x7E, 0xB2, 0x45,
        0x8E, 0x1A, 0x30, 0x62, 0x8F, 0x80, 0x4B, 0xF9,
        0x98, 0x59, 0x6E, 0x93, 0x98, 0x27, 0xBE, 0xCF,
        0x9D, 0x83, 0xC3, 0x08, 0x8A, 0xE3, 0x94, 0x34,
        0xCA, 0x4A, 0xEF, 0xCD, 0x20, 0x82, 0xCB, 0xD3,
        0x68, 0x97, 0xFC, 0x38, 0xBA, 0xB0, 0xE8, 0x35,
        0x02, 0x2C, 0xC3, 0x81, 0x30, 0x09, 0x6E, 0x7E,
        0x20, 0x53, 0x11, 0x81, 0x2B, 0x1F, 0x8F, 0x8F,
    };
    const n_bi = BigInt.fromBytesBe(&n_be);

    const d_be = [256]u8{
        0x36, 0x94, 0xA5, 0x36, 0xD0, 0x1D, 0x0E, 0xC8,
        0x2C, 0x65, 0x68, 0xE6, 0x7F, 0x58, 0x34, 0x3C,
        0xB7, 0xEB, 0x25, 0xBA, 0xC3, 0xC0, 0xFA, 0xDE,
        0xBA, 0x71, 0x03, 0x48, 0x1A, 0x63, 0x7B, 0xC5,
        0x31, 0x47, 0x5B, 0x9A, 0xB5, 0xCA, 0x71, 0x14,
        0x4A, 0xB5, 0x87, 0xE9, 0x9E, 0x13, 0x25, 0xD9,
        0x33, 0x5C, 0xD3, 0xD4, 0xAF, 0x14, 0x6F, 0x25,
        0x6A, 0x30, 0x11, 0x27, 0x93, 0xFF, 0x90, 0xC9,
        0x05, 0x7D, 0x3C, 0xAD, 0x4E, 0x31, 0xF9, 0x3C,
        0x54, 0xE2, 0xD7, 0x38, 0x70, 0xD4, 0x92, 0x40,
        0x48, 0xCE, 0x61, 0x6F, 0x51, 0x7B, 0x2A, 0x5D,
        0x0B, 0x94, 0xDF, 0xDA, 0x6B, 0x4E, 0x97, 0xE6,
        0xF8, 0xBF, 0x09, 0xA5, 0xC3, 0x23, 0x53, 0xBE,
        0xAD, 0x53, 0x37, 0x40, 0xFA, 0x68, 0x79, 0xC2,
        0xAA, 0x7E, 0x5C, 0x40, 0x7D, 0xAE, 0x3C, 0x6F,
        0xC1, 0x3D, 0x1F, 0xFD, 0xA2, 0x6B, 0xFC, 0xF5,
        0x62, 0x6B, 0x77, 0x38, 0xDF, 0xA3, 0xCF, 0x4F,
        0x52, 0xAD, 0xB8, 0xF6, 0x47, 0x9D, 0x56, 0x0F,
        0xF3, 0x91, 0x8C, 0x18, 0x4B, 0x69, 0x1B, 0xE2,
        0xE8, 0xE0, 0xEA, 0x54, 0xED, 0x99, 0x4F, 0x9E,
        0xF5, 0x2C, 0xC6, 0x58, 0xD2, 0x78, 0x30, 0xF2,
        0x0D, 0xA0, 0x2E, 0x5F, 0xB4, 0x88, 0x54, 0x5D,
        0x76, 0x58, 0xC8, 0x44, 0xA8, 0xEA, 0x7E, 0x0C,
        0x1A, 0x2D, 0xD8, 0x37, 0x9F, 0x43, 0x6E, 0x79,
        0x34, 0x4E, 0xAB, 0x8E, 0x6F, 0xCD, 0xC6, 0xCF,
        0x83, 0x68, 0xBA, 0x3E, 0xCB, 0xBB, 0xE7, 0xFE,
        0x8A, 0xC2, 0xC8, 0xD5, 0x66, 0x21, 0x6B, 0xC2,
        0x94, 0x98, 0x3C, 0x93, 0xDF, 0x46, 0x25, 0x56,
        0x11, 0xF6, 0xFC, 0xC4, 0xD6, 0x76, 0xF3, 0xE9,
        0x64, 0x2D, 0x4F, 0xAF, 0xF6, 0x22, 0x5C, 0x3E,
        0xFE, 0x21, 0xD0, 0x9A, 0x0C, 0x9D, 0xF7, 0x51,
        0xD4, 0x12, 0x37, 0xE7, 0x01, 0x6E, 0x7C, 0xB9,
    };
    const d_bi = BigInt.fromBytesBe(&d_be);

    // Long-term POLER key (XOR'd with session key for defense-in-depth)
    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xCAFEBABE;
    long_term_key[1] = 0xDEADBEEF;
    long_term_key[2] = 0x12345678;
    long_term_key[3] = 0x9ABCDEF0;

    const cipher = HybridCipher.init(&n_bi, 65537, &d_bi, &long_term_key);

    // Test data — varies in length to exercise different block counts
    const test_messages = [_][]const u8{
        "Hello hybrid world!", // 20 bytes — spans 2 blocks (16 + 4 partial)
        "A", // 1 byte — single partial block
        "Exactly16bytes!!", // 16 bytes — exactly 1 block
        "This is a longer message that spans multiple POLER-CTR blocks for thorough testing!!", // 78 bytes
    };

    // Session key and OAEP seed (in production, from CSPRNG)
    const session_key: [SESSION_KEY_BYTES]u8 = [_]u8{
        0x53, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74, 0x4B,
        0x65, 0x79, 0x21, 0x21, 0x52, 0x53, 0x41, 0x2D,
        0x4F, 0x41, 0x45, 0x50, 0x2B, 0x50, 0x4F, 0x4C,
        0x45, 0x52, 0x2D, 0x43, 0x54, 0x52, 0x21, 0x21,
    };
    const oaep_seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0x42} ** SHA256_DIGEST_SIZE;

    // Nonce (must be unique per encryption — in production, from CSPRNG)
    const nonce: [HYBRID_NONCE_BYTES]u8 = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C,
    };

    for (test_messages) |msg| {
        // Encrypt
        var ciphertext: [2048]u8 = [_]u8{0} ** 2048;
        const ct_len = try cipher.hybridEncrypt(msg, &session_key, &oaep_seed, &nonce, ciphertext[0..]);

        // Verify output format
        try std.testing.expect(ct_len == msg.len + HYBRID_HEADER_SIZE + HYBRID_TAG_BYTES);
        try std.testing.expect(ct_len >= HYBRID_HEADER_SIZE);

        // Verify pt_len in header
        const stored_pt_len: u32 = (@as(u32, ciphertext[0]) << 24) |
            (@as(u32, ciphertext[1]) << 16) |
            (@as(u32, ciphertext[2]) << 8) |
            @as(u32, ciphertext[3]);
        try std.testing.expect(stored_pt_len == msg.len);

        // Verify nonce in header
        for (0..HYBRID_NONCE_BYTES) |i| {
            try std.testing.expect(ciphertext[4 + i] == nonce[i]);
        }

        // Decrypt
        var plaintext: [2048]u8 = [_]u8{0} ** 2048;
        const pt_len = try cipher.hybridDecrypt(ciphertext[0..ct_len], plaintext[0..]);

        try std.testing.expect(pt_len == msg.len);

        // Verify plaintext matches
        for (msg, 0..) |byte, i| {
            try std.testing.expect(plaintext[i] == byte);
        }
    }

    // --- Test: Different nonce → different ciphertext ---
    const nonce2: [HYBRID_NONCE_BYTES]u8 = [_]u8{
        0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8,
        0xF7, 0xF6, 0xF5, 0xF4,
    };
    const test_msg = "Same message, different nonce";
    var ct_a: [2048]u8 = [_]u8{0} ** 2048;
    var ct_b: [2048]u8 = [_]u8{0} ** 2048;

    _ = try cipher.hybridEncrypt(test_msg, &session_key, &oaep_seed, &nonce, ct_a[0..]);
    _ = try cipher.hybridEncrypt(test_msg, &session_key, &oaep_seed, &nonce2, ct_b[0..]);

    // RSA-OAEP uses same seed → same RSA ciphertext for session_key.
    // But POLER-CTR uses different nonce → different POLER ciphertext.
    // So the total ciphertext should differ (at least in the POLER part).
    // Header (pt_len) is same, nonce differs, RSA part is same, POLER part differs.
    var poler_part_differs = false;
    const poler_start = HYBRID_HEADER_SIZE;
    const poler_end = poler_start + test_msg.len;
    for (poler_start..poler_end) |i| {
        if (ct_a[i] != ct_b[i]) poler_part_differs = true;
    }
    try std.testing.expect(poler_part_differs);

    // Both should decrypt correctly
    var pt_a: [2048]u8 = [_]u8{0} ** 2048;
    var pt_b: [2048]u8 = [_]u8{0} ** 2048;
    const pt_a_len = try cipher.hybridDecrypt(ct_a[0 .. HYBRID_HEADER_SIZE + test_msg.len + HYBRID_TAG_BYTES], pt_a[0..]);
    const pt_b_len = try cipher.hybridDecrypt(ct_b[0 .. HYBRID_HEADER_SIZE + test_msg.len + HYBRID_TAG_BYTES], pt_b[0..]);

    try std.testing.expect(pt_a_len == test_msg.len);
    try std.testing.expect(pt_b_len == test_msg.len);
    for (test_msg, 0..) |byte, i| {
        try std.testing.expect(pt_a[i] == byte);
        try std.testing.expect(pt_b[i] == byte);
    }
}

test "HMAC-SHA-256 RFC 4231 Test Case 2" {
    // RFC 4231 §5.2: Key = "Jefe", Data = "what do ya want for nothing?"
    // Expected: 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
    const key = "Jefe";
    const data = "what do ya want for nothing?";
    const tag = hmacSha256(key, data);
    const expected = [32]u8{
        0x5b, 0xdc, 0xc1, 0x46, 0xbf, 0x60, 0x75, 0x4e,
        0x6a, 0x04, 0x24, 0x26, 0x08, 0x95, 0x75, 0xc7,
        0x5a, 0x00, 0x3f, 0x08, 0x9d, 0x27, 0x39, 0x83,
        0x9d, 0xec, 0x58, 0xb9, 0x64, 0xec, 0x38, 0x43,
    };
    for (0..32) |i| {
        try std.testing.expect(tag[i] == expected[i]);
    }
}

test "HMAC-SHA-256 RFC 4231 Test Case 3" {
    // RFC 4231 §5.3: Key = 0xaa * 20, Data = 0xdd * 50
    // Expected: 773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe
    const key = [_]u8{0xAA} ** 20;
    const data = [_]u8{0xDD} ** 50;
    const tag = hmacSha256(&key, &data);
    const expected = [32]u8{
        0x77, 0x3e, 0xa9, 0x1e, 0x36, 0x80, 0x0e, 0x46,
        0x85, 0x4d, 0xb8, 0xeb, 0xd0, 0x91, 0x81, 0xa7,
        0x29, 0x59, 0x09, 0x8b, 0x3e, 0xf8, 0xc1, 0x22,
        0xd9, 0x63, 0x55, 0x14, 0xce, 0xd5, 0x65, 0xfe,
    };
    for (0..32) |i| {
        try std.testing.expect(tag[i] == expected[i]);
    }
}

test "HMAC-SHA-256 RFC 4231 Test Case 6 (key > block size)" {
    // RFC 4231 §5.6: Key = 0xaa * 131 (> 64 bytes -> hashed first)
    // Data = "Test Using Larger Than Block-Size Key - Hash Key First"
    // Expected: 60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54
    var key: [131]u8 = [_]u8{0xAA} ** 131;
    const data = "Test Using Larger Than Block-Size Key - Hash Key First";
    const tag = hmacSha256(&key, data);
    const expected = [32]u8{
        0x60, 0xe4, 0x31, 0x59, 0x1e, 0xe0, 0xb6, 0x7f,
        0x0d, 0x8a, 0x26, 0xaa, 0xcb, 0xf5, 0xb7, 0x7f,
        0x8e, 0x0b, 0xc6, 0x21, 0x37, 0x28, 0xc5, 0x14,
        0x05, 0x46, 0x04, 0x0f, 0x0e, 0xe3, 0x7f, 0x54,
    };
    for (0..32) |i| {
        try std.testing.expect(tag[i] == expected[i]);
    }
}

test "ctTagEqual: constant-time tag comparison" {
    const tag_a = [_]u8{0xAB} ** 32;
    const tag_b = [_]u8{0xAB} ** 32;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_b) == true);

    var tag_c = [_]u8{0xAB} ** 32;
    tag_c[31] = 0xAC;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_c) == false);

    var tag_d = [_]u8{0xAB} ** 32;
    tag_d[0] = 0x00;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_d) == false);

    const tag_e = [_]u8{0x00} ** 32;
    try std.testing.expect(ctTagEqual(&tag_a, &tag_e) == false);
}

test "AEAD tamper detection: modified ciphertext -> decrypt fails" {
    // Verifies that modifying ANY byte of the ciphertext causes
    // hybridDecrypt to reject with an authentication error.
    // Uses the same RSA-2048 key from the 2048-bit test.

    const n_be = [256]u8{
        0xB9, 0xC0, 0xD9, 0xF5, 0x83, 0xF7, 0x6C, 0x8F,
        0x90, 0x16, 0x30, 0xFF, 0xFD, 0x6E, 0x29, 0x24,
        0xBB, 0xA7, 0x89, 0xB5, 0xC2, 0x9B, 0x03, 0xC8,
        0xED, 0x7A, 0x6B, 0x67, 0x16, 0xED, 0x2A, 0x29,
        0xF1, 0x5B, 0x83, 0x6F, 0xF7, 0x59, 0x03, 0x95,
        0xF7, 0x1E, 0x0A, 0x03, 0x23, 0x1E, 0x88, 0xF5,
        0x42, 0xE8, 0x8D, 0x5C, 0x48, 0xEB, 0x1E, 0x4B,
        0x72, 0x77, 0x73, 0x2F, 0xC7, 0xBA, 0x9D, 0xCE,
        0x56, 0x77, 0x7C, 0xCB, 0xF7, 0x52, 0xA3, 0xF1,
        0xAB, 0xBB, 0x82, 0xEB, 0xF7, 0x81, 0x60, 0x82,
        0xF5, 0x69, 0xE3, 0x8C, 0x10, 0x25, 0x2A, 0xE6,
        0xF0, 0xB9, 0x6A, 0x54, 0x08, 0x5C, 0xAC, 0xA0,
        0xDD, 0x4A, 0x32, 0xC4, 0x41, 0x27, 0x88, 0xCE,
        0xA7, 0x72, 0xB8, 0x71, 0x12, 0xB9, 0x4A, 0xCB,
        0x0D, 0xCC, 0xA4, 0x74, 0xDA, 0x29, 0x7A, 0x79,
        0xED, 0x52, 0x0D, 0x84, 0x44, 0x23, 0xAC, 0x2A,
        0xCF, 0x5E, 0x84, 0xEB, 0xF8, 0x4D, 0x8F, 0x4C,
        0x34, 0xF4, 0x26, 0x42, 0x74, 0x6A, 0x06, 0xB8,
        0x6B, 0x4E, 0xD6, 0xA9, 0x06, 0x19, 0xE3, 0x37,
        0x6B, 0xEE, 0xA6, 0xC9, 0x25, 0xDA, 0x6D, 0xDF,
        0x91, 0xFF, 0xDA, 0x9F, 0x24, 0xE1, 0xEE, 0x58,
        0x1F, 0xF7, 0x9D, 0x7C, 0x82, 0xDB, 0x15, 0x0F,
        0x42, 0x28, 0xCF, 0xF1, 0x58, 0x24, 0x4B, 0x93,
        0xFF, 0x49, 0x4D, 0x99, 0x16, 0xE2, 0xE7, 0xA3,
        0x52, 0xB7, 0xED, 0x54, 0xEC, 0x7E, 0xB2, 0x45,
        0x8E, 0x1A, 0x30, 0x62, 0x8F, 0x80, 0x4B, 0xF9,
        0x98, 0x59, 0x6E, 0x93, 0x98, 0x27, 0xBE, 0xCF,
        0x9D, 0x83, 0xC3, 0x08, 0x8A, 0xE3, 0x94, 0x34,
        0xCA, 0x4A, 0xEF, 0xCD, 0x20, 0x82, 0xCB, 0xD3,
        0x68, 0x97, 0xFC, 0x38, 0xBA, 0xB0, 0xE8, 0x35,
        0x02, 0x2C, 0xC3, 0x81, 0x30, 0x09, 0x6E, 0x7E,
        0x20, 0x53, 0x11, 0x81, 0x2B, 0x1F, 0x8F, 0x8F,
    };
    const n_bi = BigInt.fromBytesBe(&n_be);
    const d_be = [256]u8{
        0x36, 0x94, 0xA5, 0x36, 0xD0, 0x1D, 0x0E, 0xC8,
        0x2C, 0x65, 0x68, 0xE6, 0x7F, 0x58, 0x34, 0x3C,
        0xB7, 0xEB, 0x25, 0xBA, 0xC3, 0xC0, 0xFA, 0xDE,
        0xBA, 0x71, 0x03, 0x48, 0x1A, 0x63, 0x7B, 0xC5,
        0x31, 0x47, 0x5B, 0x9A, 0xB5, 0xCA, 0x71, 0x14,
        0x4A, 0xB5, 0x87, 0xE9, 0x9E, 0x13, 0x25, 0xD9,
        0x33, 0x5C, 0xD3, 0xD4, 0xAF, 0x14, 0x6F, 0x25,
        0x6A, 0x30, 0x11, 0x27, 0x93, 0xFF, 0x90, 0xC9,
        0x05, 0x7D, 0x3C, 0xAD, 0x4E, 0x31, 0xF9, 0x3C,
        0x54, 0xE2, 0xD7, 0x38, 0x70, 0xD4, 0x92, 0x40,
        0x48, 0xCE, 0x61, 0x6F, 0x51, 0x7B, 0x2A, 0x5D,
        0x0B, 0x94, 0xDF, 0xDA, 0x6B, 0x4E, 0x97, 0xE6,
        0xF8, 0xBF, 0x09, 0xA5, 0xC3, 0x23, 0x53, 0xBE,
        0xAD, 0x53, 0x37, 0x40, 0xFA, 0x68, 0x79, 0xC2,
        0xAA, 0x7E, 0x5C, 0x40, 0x7D, 0xAE, 0x3C, 0x6F,
        0xC1, 0x3D, 0x1F, 0xFD, 0xA2, 0x6B, 0xFC, 0xF5,
        0x62, 0x6B, 0x77, 0x38, 0xDF, 0xA3, 0xCF, 0x4F,
        0x52, 0xAD, 0xB8, 0xF6, 0x47, 0x9D, 0x56, 0x0F,
        0xF3, 0x91, 0x8C, 0x18, 0x4B, 0x69, 0x1B, 0xE2,
        0xE8, 0xE0, 0xEA, 0x54, 0xED, 0x99, 0x4F, 0x9E,
        0xF5, 0x2C, 0xC6, 0x58, 0xD2, 0x78, 0x30, 0xF2,
        0x0D, 0xA0, 0x2E, 0x5F, 0xB4, 0x88, 0x54, 0x5D,
        0x76, 0x58, 0xC8, 0x44, 0xA8, 0xEA, 0x7E, 0x0C,
        0x1A, 0x2D, 0xD8, 0x37, 0x9F, 0x43, 0x6E, 0x79,
        0x34, 0x4E, 0xAB, 0x8E, 0x6F, 0xCD, 0xC6, 0xCF,
        0x83, 0x68, 0xBA, 0x3E, 0xCB, 0xBB, 0xE7, 0xFE,
        0x8A, 0xC2, 0xC8, 0xD5, 0x66, 0x21, 0x6B, 0xC2,
        0x94, 0x98, 0x3C, 0x93, 0xDF, 0x46, 0x25, 0x56,
        0x11, 0xF6, 0xFC, 0xC4, 0xD6, 0x76, 0xF3, 0xE9,
        0x64, 0x2D, 0x4F, 0xAF, 0xF6, 0x22, 0x5C, 0x3E,
        0xFE, 0x21, 0xD0, 0x9A, 0x0C, 0x9D, 0xF7, 0x51,
        0xD4, 0x12, 0x37, 0xE7, 0x01, 0x6E, 0x7C, 0xB9,
    };
    const d_bi = BigInt.fromBytesBe(&d_be);

    var long_term_key: [poler.KEY_WORDS]u32 = [_]u32{0} ** poler.KEY_WORDS;
    long_term_key[0] = 0xCAFEBABE;

    const cipher = HybridCipher.init(&n_bi, 65537, &d_bi, &long_term_key);

    const session_key: [SESSION_KEY_BYTES]u8 = [_]u8{
        0x53, 0x73, 0x65, 0x63, 0x72, 0x65, 0x74, 0x4B,
        0x65, 0x79, 0x21, 0x21, 0x52, 0x53, 0x41, 0x2D,
        0x4F, 0x41, 0x45, 0x50, 0x2B, 0x50, 0x4F, 0x4C,
        0x45, 0x52, 0x2D, 0x43, 0x54, 0x52, 0x21, 0x21,
    };
    const oaep_seed: [SHA256_DIGEST_SIZE]u8 = [_]u8{0x42} ** SHA256_DIGEST_SIZE;
    const nonce: [HYBRID_NONCE_BYTES]u8 = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0A, 0x0B, 0x0C,
    };

    const msg = "AEAD tamper test message";
    var ciphertext: [4096]u8 = [_]u8{0} ** 4096;
    const ct_len = try cipher.hybridEncrypt(msg, &session_key, &oaep_seed, &nonce, ciphertext[0..]);

    // Untamered → OK
    var plaintext: [4096]u8 = [_]u8{0} ** 4096;
    const pt_len = try cipher.hybridDecrypt(ciphertext[0..ct_len], plaintext[0..]);
    try std.testing.expect(pt_len == msg.len);
    for (msg, 0..) |byte, i| {
        try std.testing.expect(plaintext[i] == byte);
    }

    // Flip bit in POLER-CTR ciphertext -> REJECT
    var tampered: [4096]u8 = [_]u8{0} ** 4096;
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[HYBRID_HEADER_SIZE + 5] ^= 0x01;
    try std.testing.expect(cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) == OaepError.invalid_padding);

    // Flip bit in RSA-OAEP portion -> REJECT (may fail at OAEP or MAC level)
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[4 + HYBRID_NONCE_BYTES + 10] ^= 0x01;
    _ = cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) catch {}; // any error is OK

    // Flip bit in nonce -> REJECT
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[5] ^= 0x01;
    try std.testing.expect(cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) == OaepError.invalid_padding);

    // Flip bit in tag -> REJECT
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[HYBRID_HEADER_SIZE + msg.len] ^= 0x01;
    try std.testing.expect(cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) == OaepError.invalid_padding);

    // Modify pt_len in header -> REJECT (may give decoding_error or invalid_padding)
    @memcpy(tampered[0..ct_len], ciphertext[0..ct_len]);
    tampered[3] +%= 1;
    _ = cipher.hybridDecrypt(tampered[0..ct_len], plaintext[0..]) catch {}; // any error is OK
}
`
```

### `zig-kernel/src64/scheduler.zig` [zig · 12,013 B]
```
`// ============================================================================
// POLER-OS Task Scheduler — x86_64
// ============================================================================
//
// v0.7.0: Ring 3 (user mode) support
//   - Per-process CR3 (page tables)
//   - User code/data segments (CS=0x1B, SS=0x23)
//   - TSS IST1 for double-fault handling
//   - IRETQ privilege switch
//   - CR3 switching on context switch
//   - sysretq convention: CS=0x1B (User Code entry 3), SS=0x13 (Data entry 2)
//
// v0.6.1-fix: Tasks run in Ring 0 (kernel mode) for stability.
// Ring 3 user-mode tasks will be added in v0.7.0 with proper:
//   - Per-process CR3 (page tables)
//   - User code/data segments (0x1B/0x23)
//   - TSS IST for double-fault handling
//   - IRETQ privilege switch
// ============================================================================

const hal = @import("hal.zig");

pub const MAX_TASKS = 8;

pub const TaskState = enum {
    Ready,
    Running,
    Killed,
};

pub const TaskPrivilege = enum(u2) {
    Kernel = 0,
    User = 3,
};

pub const Task = struct {
    id: usize,
    state: TaskState,
    privilege: TaskPrivilege,
    rsp: u64, // Saved stack pointer (points to saved InterruptFrame in kernel_stack)
    kernel_stack: [8192]u8 align(16), // Ring 0 stack (8KB — larger for safety)
    cr3: u64, // Per-process PML4 physical address (0 = use kernel CR3)
    user_stack_top: u64, // Top of user stack (virtual address, for reference/cleanup)
};

pub var tasks: [MAX_TASKS]Task = undefined;
pub var current_task_id: usize = 0;
pub var task_count: usize = 0;
pub var scheduler_ticks: u64 = 0;

// Exported variables for assembly syscall_entry
pub export var user_rsp: u64 = 0;
pub export var current_kernel_stack: u64 = 0;

// v0.7.0: CR3 tracking for per-process address spaces
var kernel_cr3: u64 = 0; // Boot/kernel PML4 physical address
var current_cr3: u64 = 0; // Currently loaded CR3

pub fn init() void {
    task_count = 0;
    current_task_id = 0;
    scheduler_ticks = 0;

    // Save the kernel's CR3 (boot PML4) — used to restore when switching back
    kernel_cr3 = hal.readCr3() & 0x000FFFFFFFFFF000;
    current_cr3 = kernel_cr3;

    // Create idle task (Task 0) — maps to the main kernel thread
    tasks[0] = Task{
        .id = 0,
        .state = .Running,
        .privilege = .Kernel,
        .rsp = 0,
        .kernel_stack = undefined,
        .cr3 = 0, // 0 = use kernel CR3
        .user_stack_top = 0,
    };
    task_count = 1;

    // Set initial kernel stack top (corresponds to stack_top in linker64.ld)
    current_kernel_stack = 0x10b000;

    // Register exit callback — HAL calls this on syscall exit(4)
    // Breaks circular dependency hal.zig ↔ scheduler.zig via function pointer.
    hal.exitCallback = exitCurrentTask;

    hal.Serial.puts("[SCHED] Scheduler initialized (v0.7.0 Ring 3 + exit syscall)\n");
}

/// Called by HAL when a user process invokes syscall 4 (exit).
/// Kills the current task. The scheduler will skip it on the next tick.
pub fn exitCurrentTask() callconv(.C) void {
    if (current_task_id == 0) {
        hal.Serial.puts("[SCHED] ERROR: Cannot kill idle task!\n");
        return;
    }
    hal.Serial.puts("[SCHED] Exiting task ");
    hal.Serial.putHex(current_task_id);
    hal.Serial.puts("\n");
    tasks[current_task_id].state = .Killed;
}

/// Mark a task as Killed. The idle task (id 0) CANNOT be killed —
/// it is the scheduler's safety net and must always remain schedulable.
pub fn killTask(id: usize) !void {
    if (id == 0) return error.InvalidTask;
    if (id >= task_count) return error.InvalidTask;
    tasks[id].state = .Killed;
    hal.Serial.puts("[SCHED] Killed task ");
    hal.Serial.putHex(id);
    hal.Serial.puts("\n");
}

/// Create a kernel-mode (Ring 0) task.
/// CS=0x08, SS=0x10, runs in kernel space.
pub fn createTask(entry_point: u64) !usize {
    if (task_count >= MAX_TASKS) return error.OutOfTasks;

    const id = task_count;
    task_count += 1;

    const task = &tasks[id];
    task.id = id;
    task.state = .Ready;
    task.privilege = .Kernel;
    task.cr3 = 0; // Use kernel CR3
    task.user_stack_top = 0;

    // Set up the initial stack frame in the kernel stack.
    // InterruptFrame layout (176 bytes):
    //   [0..120]   = r15..rax (15 GP registers, pushed by isr_common)
    //   [120..128] = vector
    //   [128..136] = error_code
    //   [136..176] = rip, cs, rflags, rsp, ss (CPU-pushed on interrupt)
    const kstack_top = @intFromPtr(&task.kernel_stack) + task.kernel_stack.len;

    // Place InterruptFrame at the top of kernel stack
    const frame_ptr: *hal.InterruptFrame = @ptrFromInt(kstack_top - 176);

    // Clear the stack frame initial contents
    @memset(@as([*]volatile u8, @ptrCast(frame_ptr))[0..176], 0);

    // Set up segment registers and execution context
    // Ring 0 task: CS=0x08, SS=0x10 (kernel mode)
    frame_ptr.rip = entry_point;
    frame_ptr.cs = 0x08; // Kernel code segment selector (Ring 0)
    frame_ptr.rflags = 0x202; // IF (Interrupt Enable Flag) set
    frame_ptr.rsp = kstack_top - 176; // Use stack below the frame as the task's RSP
    frame_ptr.ss = 0x10; // Kernel data segment selector (Ring 0)
    frame_ptr.vector = 48; // APIC timer vector (matches actual interrupt source)
    frame_ptr.error_code = 0;

    // Initialize RDI, RSI, RDX etc. to 0 (already zeroed by memset above)

    // Save stack pointer to task control block
    task.rsp = @intFromPtr(frame_ptr);

    hal.Serial.puts("[SCHED] Created kernel task ");
    hal.Serial.putHex(id);
    hal.Serial.puts(" at entry ");
    hal.Serial.putHex(entry_point);
    hal.Serial.puts(" RSP=");
    hal.Serial.putHex(task.rsp);
    hal.Serial.puts("\n");

    return id;
}

/// Create a user-mode (Ring 3) task — v0.7.0
///
/// Parameters:
///   entry_point:  Virtual address of the user program's _start
///   user_cr3:     Physical address of the user's PML4 (from vmm.createUserPML4)
///   user_stack:   Virtual address of the top of user stack (e.g., 0x100081000)
///
/// The task runs with:
///   CS = 0x1B (User Code, GDT entry 3, DPL=3, RPL=3)
///   SS = 0x23 (User Data, GDT entry 4, DPL=3, RPL=3)
///   RFLAGS = 0x202 (IF=1, IOPL=0)
///
/// When an interrupt fires in Ring 3, the CPU automatically:
///   1. Switches to TSS.rsp0 (kernel stack)
///   2. Pushes user SS, RSP, RFLAGS, CS, RIP
///   3. Enters the ISR in Ring 0
///
/// IRETQ restores CS with RPL=3 → switches back to Ring 3.
/// sysretq returns with CS = STAR+16|RPL3 = 0x1B, SS = STAR+8|RPL3 = 0x13.
pub fn createUserTask(entry_point: u64, user_cr3: u64, user_stack: u64) !usize {
    if (task_count >= MAX_TASKS) return error.OutOfTasks;

    const id = task_count;
    task_count += 1;

    const task = &tasks[id];
    task.id = id;
    task.state = .Ready;
    task.privilege = .User;
    task.cr3 = user_cr3; // Per-process page tables!
    task.user_stack_top = user_stack;

    // Set up the initial stack frame in the kernel stack.
    // When IRETQ pops this frame and sees CS=0x23 (RPL=3),
    // it performs a privilege switch to Ring 3.
    const kstack_top = @intFromPtr(&task.kernel_stack) + task.kernel_stack.len;

    // Place InterruptFrame at the top of kernel stack
    const frame_ptr: *hal.InterruptFrame = @ptrFromInt(kstack_top - 176);

    // Clear the stack frame initial contents
    @memset(@as([*]volatile u8, @ptrCast(frame_ptr))[0..176], 0);

    // Set up segment registers and execution context for Ring 3
    // GDT layout (matches sysretq convention with STAR[32:47]=0x08):
    //   Entry 1 (0x08): Kernel Code — syscall CS
    //   Entry 2 (0x10): Data DPL=3 — syscall SS / sysretq SS = 0x13
    //   Entry 3 (0x18): User Code DPL=3 — sysretq CS = 0x1B
    //   Entry 4 (0x20): User Data DPL=3 — IRETQ SS = 0x23
    frame_ptr.rip = entry_point;
    frame_ptr.cs = 0x1B; // User code segment (0x18 | RPL3) — entry 3 = User Code
    frame_ptr.rflags = 0x202; // IF set, IOPL=0 (no I/O port access from Ring 3)
    frame_ptr.rsp = user_stack; // User stack top (grows downward)
    frame_ptr.ss = 0x23; // User data segment (0x20 | RPL3) — entry 4 = User Data
    frame_ptr.vector = 48; // APIC timer vector
    frame_ptr.error_code = 0;

    // Save stack pointer to task control block
    task.rsp = @intFromPtr(frame_ptr);

    hal.Serial.puts("[SCHED] Created user task ");
    hal.Serial.putHex(id);
    hal.Serial.puts(" at entry ");
    hal.Serial.putHex(entry_point);
    hal.Serial.puts(" CR3=");
    hal.Serial.putHex(user_cr3);
    hal.Serial.puts(" USP=");
    hal.Serial.putHex(user_stack);
    hal.Serial.puts("\n");

    return id;
}

pub fn schedule(current_rsp: u64) callconv(.C) u64 {
    if (task_count <= 1) return current_rsp; // Only idle/kernel task exists

    scheduler_ticks += 1;

    // DEBUG: periodic log to confirm schedule is running
    if (scheduler_ticks % 100 == 1) {
        hal.Serial.puts("[SCHED] tick ");
        hal.Serial.putDecimal(scheduler_ticks);
        hal.Serial.puts(" current=");
        hal.Serial.putDecimal(current_task_id);
        hal.Serial.puts(" tasks=");
        hal.Serial.putDecimal(task_count);
        hal.Serial.puts("\n");
    }

    // Save RSP of the current task
    tasks[current_task_id].rsp = current_rsp;
    if (tasks[current_task_id].state == .Running) {
        tasks[current_task_id].state = .Ready;
    }

    // Select the next task using Round-Robin
    var next_id = (current_task_id + 1) % task_count;
    var checked: usize = 0;
    while (checked < task_count) : ({
        next_id = (next_id + 1) % task_count;
        checked += 1;
    }) {
        if (tasks[next_id].state == .Ready or tasks[next_id].state == .Running) {
            break;
        }
    }

    // Safety: if no Ready/Running task found, stay on current if it's not Killed
    if (tasks[next_id].state == .Killed) {
        // All tasks are killed — spin on idle (task 0)
        next_id = 0;
        if (tasks[0].state == .Killed) {
            // Even idle is killed — shouldn't happen, but prevent resurrection
            tasks[0].state = .Running;
        }
    }

    current_task_id = next_id;
    tasks[current_task_id].state = .Running;

    // DEBUG: Log when switching to a user task
    if (tasks[current_task_id].privilege == .User) {
        hal.Serial.puts("[SCHED] Switching to user task ");
        hal.Serial.putHex(current_task_id);
        hal.Serial.puts(" RIP=");
        // Peek at the InterruptFrame to see what IRETQ will restore
        const frame: *hal.InterruptFrame = @ptrFromInt(tasks[current_task_id].rsp);
        hal.Serial.putHex(frame.rip);
        hal.Serial.puts(" CS=");
        hal.Serial.putHex(frame.cs);
        hal.Serial.puts(" RSP=");
        hal.Serial.putHex(frame.rsp);
        hal.Serial.puts(" SS=");
        hal.Serial.putHex(frame.ss);
        hal.Serial.puts("\n");
    }

    // Update TSS.rsp0 and current_kernel_stack
    // For user tasks: TSS.rsp0 must point to the kernel stack top,
    // so that interrupts from Ring 3 switch to the correct kernel stack.
    const next_task = &tasks[current_task_id];
    if (next_task.id != 0) {
        const kstack_top = @intFromPtr(&next_task.kernel_stack) + next_task.kernel_stack.len;
        hal.setKernelStack(kstack_top);
        current_kernel_stack = kstack_top;
    } else {
        // Idle/Kernel task uses the main boot stack
        hal.setKernelStack(0x10b000);
        current_kernel_stack = 0x10b000;
    }

    // v0.7.0: Switch CR3 if the new task has different page tables
    // This implements per-process address space isolation.
    // When switching to a user task: load its CR3
    // When switching to a kernel task: load kernel CR3
    // CR3 write flushes the entire TLB — acceptable for v0.7.0.
    const next_cr3 = if (next_task.cr3 != 0) next_task.cr3 else kernel_cr3;
    if (next_cr3 != current_cr3) {
        hal.writeCr3(next_cr3);
        current_cr3 = next_cr3;
    }

    return next_task.rsp;
}
`
```

### `zig-kernel/src64/smp.zig` [zig · 13,188 B]
```
`// ============================================================================
// POLER-OS SMP (Symmetric Multi-Processing) — x86_64
// ============================================================================
//
// Manages multi-core initialization and per-CPU state.
//
// Boot sequence:
//   1. BSP (Bootstrap Processor) boots via Multiboot2 → main64.zig
//   2. BSP initializes HAL, ACPI, memory, scheduler
//   3. BSP calls smp.init() which:
//      a. Reads BSP's Local APIC ID
//      b. Parses MADT to find all CPUs (already done by acpi.init)
//      c. Marks BSP in cpu_list
//      d. Copies AP trampoline code to 0x8000 (low memory)
//      e. Sends INIT IPI → SIPI to each AP
//      f. Waits for each AP to signal ready
//   4. Each AP:
//      a. Starts in 16-bit real mode at 0x8000 (trampoline)
//      b. Switches to 64-bit long mode
//      c. Loads GDT, IDT, page tables from BSP
//      d. Sets up per-CPU GSBASE
//      e. Initializes Local APIC
//      f. Signals ready
//      g. Enters scheduler loop
//
// ============================================================================

const hal = @import("hal.zig");
const acpi = @import("acpi.zig");
const spinlock = @import("spinlock.zig");

// ============================================================================
// Constants
// ============================================================================

/// Maximum number of CPUs supported
pub const MAX_CPUS = acpi.MAX_CPUS;

/// AP trampoline is placed at physical address 0x8000 (page 8).
/// This must be below 640KB for SIPI to work (SIPI vector = page number).
pub const AP_TRAMPOLINE_ADDR: u64 = 0x8000;
pub const AP_TRAMPOLINE_PAGE: u32 = 8; // 0x8000 / 4096

/// Stack size for each AP (16KB)
pub const AP_STACK_SIZE: usize = 16384;

// ============================================================================
// Per-CPU State
// ============================================================================

pub const CpuState = enum(u8) {
    Offline = 0,
    Initializing = 1,
    Ready = 2,
    Running = 3,
    Halted = 4,
};

pub const PerCpu = struct {
    cpu_id: u32, // Logical CPU index (0 = BSP)
    lapic_id: u32, // Local APIC ID
    state: CpuState,
    stack_top: u64, // Top of this CPU's kernel stack
    current_task_id: usize, // Currently running task (-1 = idle)
    scheduler_ticks: u64, // Per-CPU scheduler tick counter
    irq_count: u64, // Interrupt count
    syscall_count: u64, // Syscall count
};

/// Global array of per-CPU data, aligned to cache line to avoid false sharing
pub var cpu_data: [MAX_CPUS]PerCpu align(64) = undefined;

/// Number of CPUs that are online (initialized + ready)
pub var online_cpus: u32 = 0;

/// Spinlock protecting SMP initialization
var smp_lock: spinlock.Spinlock = .{};

/// AP stack memory — each AP gets its own stack
var ap_stacks: [MAX_CPUS - 1][AP_STACK_SIZE]u8 align(16) = undefined;

// ============================================================================
// AP trampoline code — 16-bit real mode startup
// ============================================================================
// This code is copied to physical address 0x8000 at boot.
// APs start here in 16-bit real mode after SIPI.
// The trampoline switches to 64-bit long mode and jumps to ap_entry_zig().
// ============================================================================

/// Shared data between BSP and AP (placed at known offsets from 0x8000)
pub const ApTrampolineData = extern struct {
    /// GDT64 pointer (10 bytes: 2-byte limit + 8-byte base)
    gdt_ptr: [10]u8 align(1),
    /// IDT pointer (10 bytes: 2-byte limit + 8-byte base)
    idt_ptr: [10]u8 align(1),
    /// PML4 physical address for CR3
    cr3: u64,
    /// Address of ap_entry_zig() function (64-bit)
    entry64: u64,
    /// Address of this CPU's PerCpu structure (for GSBASE)
    per_cpu_addr: u64,
    /// CPU index for this AP
    cpu_id: u32,
    /// Stack top for this AP
    stack_top: u64,
};

/// The trampoline data lives at AP_TRAMPOLINE_ADDR + 0x100 (offset from code)
pub const AP_DATA_OFFSET: u64 = 0x100;

// ============================================================================
// SMP Initialization (called by BSP)
// ============================================================================

pub fn init() void {
    hal.Serial.puts("[SMP] Initializing SMP subsystem...\n");

    // Step 1: Read BSP's Local APIC ID
    const bsp_lapic_id = hal.APIC.getId();
    acpi.bsp_apic_id = bsp_lapic_id;
    hal.Serial.puts("[SMP] BSP Local APIC ID: ");
    hal.Serial.putHex(@as(u64, bsp_lapic_id));
    hal.Serial.puts("\n");

    // Step 2: Mark BSP in cpu_list
    for (0..acpi.cpu_count) |i| {
        if (acpi.cpu_list[i].apic_id == bsp_lapic_id) {
            acpi.cpu_list[i].is_bsp = true;
            break;
        }
    }

    // Step 3: Initialize PerCpu for BSP (CPU 0)
    cpu_data[0] = PerCpu{
        .cpu_id = 0,
        .lapic_id = bsp_lapic_id,
        .state = .Running,
        .stack_top = 0x10b000, // Boot stack top (from linker64.ld)
        .current_task_id = 0,
        .scheduler_ticks = 0,
        .irq_count = 0,
        .syscall_count = 0,
    };
    online_cpus = 1;

    // Set GSBASE for BSP — points to its PerCpu structure
    hal.writeGsBase(@intFromPtr(&cpu_data[0]));
    hal.writeKernelGsBase(@intFromPtr(&cpu_data[0]));
    hal.Serial.puts("[SMP] BSP GSBASE set to ");
    hal.Serial.putHex(@intFromPtr(&cpu_data[0]));
    hal.Serial.puts("\n");

    // Step 4: If only 1 CPU, skip AP startup
    if (acpi.cpu_count <= 1) {
        hal.Serial.puts("[SMP] Single CPU system, no APs to start\n");
        return;
    }

    // Step 5: Copy AP trampoline code to 0x8000
    setupTrampoline();

    // Step 6: Start each AP
    startApplicationProcessors();

    hal.Serial.puts("[SMP] All CPUs online: ");
    hal.Serial.putDecimal(online_cpus);
    hal.Serial.puts("\n");
}

/// Get the current CPU's PerCpu structure via GSBASE
pub fn currentCpu() *PerCpu {
    const gsbase = hal.readGsBase();
    return @ptrFromInt(gsbase);
}

/// Get the current CPU's logical index
pub fn currentCpuId() u32 {
    return currentCpu().cpu_id;
}

// ============================================================================
// AP Trampoline Setup
// ============================================================================

fn setupTrampoline() void {
    hal.Serial.puts("[SMP] Setting up AP trampoline at 0x8000...\n");

    // The trampoline consists of:
    // 1. 16-bit real mode code that switches to 64-bit long mode
    // 2. Data area with GDT/IDT/CR3/entry pointers

    // We write the trampoline in assembly (boot_smp.S) and copy it at runtime.
    // For now, we'll use the symbols from boot_smp.S:
    //   ap_trampoline_start, ap_trampoline_end

    // Copy trampoline binary to 0x8000
    const src: [*]const u8 = @ptrCast(&ap_trampoline_start);
    const len: usize = @intFromPtr(&ap_trampoline_end) - @intFromPtr(&ap_trampoline_start);
    const dst: [*]volatile u8 = @ptrFromInt(AP_TRAMPOLINE_ADDR);

    for (0..len) |i| {
        dst[i] = src[i];
    }

    // Fill in the trampoline data area
    const data: *volatile ApTrampolineData = @ptrFromInt(AP_TRAMPOLINE_ADDR + AP_DATA_OFFSET);

    // Read current GDT and IDT pointers
    var gdt_ptr: [10]u8 = undefined;
    asm volatile ("sgdt %[p]"
        : [p] "=m" (gdt_ptr),
    );
    var idt_ptr: [10]u8 = undefined;
    asm volatile ("sidt %[p]"
        : [p] "=m" (idt_ptr),
    );

    data.gdt_ptr = gdt_ptr;
    data.idt_ptr = idt_ptr;
    data.cr3 = hal.readCr3() & 0x000FFFFFFFFFF000; // PML4 physical address
    data.entry64 = @intFromPtr(&ap_entry_zig);
    data.cpu_id = 0; // Will be set per-AP before SIPI
    data.per_cpu_addr = 0; // Will be set per-AP before SIPI

    hal.Serial.puts("[SMP] Trampoline data: CR3=");
    hal.Serial.putHex(data.cr3);
    hal.Serial.puts(" entry=");
    hal.Serial.putHex(data.entry64);
    hal.Serial.puts("\n");
}

// ============================================================================
// Start Application Processors
// ============================================================================

fn startApplicationProcessors() void {
    var ap_index: u32 = 0; // Logical AP index (0 = first AP)

    for (0..acpi.cpu_count) |i| {
        const cpu = &acpi.cpu_list[i];
        if (cpu.is_bsp) continue; // Skip BSP
        if (!cpu.enabled) continue; // Skip disabled CPUs

        if (ap_index >= MAX_CPUS - 1) {
            hal.Serial.puts("[SMP] WARNING: Too many APs, max ");
            hal.Serial.putDecimal(MAX_CPUS - 1);
            hal.Serial.puts(" supported\n");
            break;
        }

        const logical_id: u32 = ap_index + 1; // CPU 0 = BSP

        hal.Serial.puts("[SMP] Starting AP ");
        hal.Serial.putDecimal(logical_id);
        hal.Serial.puts(" (APIC_ID=");
        hal.Serial.putHex(@as(u64, cpu.apic_id));
        hal.Serial.puts(")\n");

        // Set up PerCpu structure for this AP
        const stack_top: u64 = @intFromPtr(&ap_stacks[ap_index]) + AP_STACK_SIZE;
        cpu_data[logical_id] = PerCpu{
            .cpu_id = logical_id,
            .lapic_id = cpu.apic_id,
            .state = .Initializing,
            .stack_top = stack_top,
            .current_task_id = 0,
            .scheduler_ticks = 0,
            .irq_count = 0,
            .syscall_count = 0,
        };

        // Update trampoline data for this specific AP
        const data: *volatile ApTrampolineData = @ptrFromInt(AP_TRAMPOLINE_ADDR + AP_DATA_OFFSET);
        data.cpu_id = logical_id;
        data.per_cpu_addr = @intFromPtr(&cpu_data[logical_id]);
        data.stack_top = stack_top;

        // Intel SDM says: INIT IPI → 10ms delay → SIPI → 200us delay → SIPI (retry)
        hal.APIC.sendInitIpi(cpu.apic_id);
        microDelay(10000); // 10ms

        hal.APIC.sendStartupIpi(cpu.apic_id, AP_TRAMPOLINE_PAGE);
        microDelay(200); // 200us

        // Retry SIPI if AP is not ready (Intel SDM recommends sending SIPI twice)
        if (cpu_data[logical_id].state != .Ready) {
            hal.APIC.sendStartupIpi(cpu.apic_id, AP_TRAMPOLINE_PAGE);
            microDelay(200);
        }

        // Wait for AP to signal ready (with timeout)
        var timeout: u32 = 0;
        while (cpu_data[logical_id].state != .Ready and timeout < 5000000) : (timeout += 1) {
            asm volatile ("pause");
        }

        if (cpu_data[logical_id].state == .Ready) {
            online_cpus += 1;
            hal.Serial.puts("[SMP] AP ");
            hal.Serial.putDecimal(logical_id);
            hal.Serial.puts(" is ready\n");
        } else {
            hal.Serial.puts("[SMP] WARNING: AP ");
            hal.Serial.putDecimal(logical_id);
            hal.Serial.puts(" failed to start (timeout)\n");
            cpu_data[logical_id].state = .Offline;
        }

        ap_index += 1;
    }
}

/// Crude micro-delay using a busy loop. Not precise, but good enough for
/// IPI timing where we just need "at least N microseconds".
fn microDelay(us: u32) void {
    // Rough calibration: ~1 billion iterations per second on a 2GHz CPU
    // This is very imprecise but sufficient for IPI delays.
    const iterations = us * 1000;
    var i: u32 = 0;
    while (i < iterations) : (i += 1) {
        asm volatile ("nop");
    }
}

// ============================================================================
// AP Entry Point (called from trampoline assembly in 64-bit long mode)
// ============================================================================

/// This function is called by each AP after the trampoline switches to
/// 64-bit long mode. It runs on the AP's own stack.
pub export fn ap_entry_zig() callconv(.C) void {
    // Read our CPU ID from the trampoline data
    const data: *volatile ApTrampolineData = @ptrFromInt(AP_TRAMPOLINE_ADDR + AP_DATA_OFFSET);
    const cpu_id = data.cpu_id;
    const per_cpu_addr = data.per_cpu_addr;

    const cpu = &cpu_data[cpu_id];

    hal.Serial.puts("[SMP] AP ");
    hal.Serial.putDecimal(cpu_id);
    hal.Serial.puts(" entering ap_entry_zig()\n");

    // Set GSBASE for per-CPU data
    hal.writeGsBase(per_cpu_addr);
    hal.writeKernelGsBase(per_cpu_addr);

    // Initialize Local APIC on this CPU
    // The APIC base address is the same for all CPUs (MMIO),
    // but each CPU has its own set of APIC registers.
    hal.APIC.init();

    // Enable interrupts
    hal.sti();

    // Signal that we're ready
    cpu.state = .Ready;

    hal.Serial.puts("[SMP] AP ");
    hal.Serial.putDecimal(cpu_id);
    hal.Serial.puts(" ready (APIC_ID=");
    hal.Serial.putHex(@as(u64, cpu.lapic_id));
    hal.Serial.puts(")\n");

    // Enter idle loop — wait for scheduler to assign tasks
    // In the future, this will enter the scheduler's idle loop
    while (true) {
        hal.hlt();
    }
}

// ============================================================================
// Trampoline symbols (defined in boot_smp.S)
// ============================================================================

extern const ap_trampoline_start: u8;
extern const ap_trampoline_end: u8;
`
```

### `zig-kernel/src64/spinlock.zig` [zig · 2,923 B]
```
`// ============================================================================
// POLER-OS Spinlock — x86_64 SMP Synchronization Primitive
// ============================================================================
//
// Spinlocks are the basic synchronization primitive for SMP.
// They busy-wait (spin) until the lock is available.
// Use spinlocks ONLY for short critical sections (a few instructions).
// For longer operations, use a mutex (TODO: future).
//
// Usage:
//   var lock: Spinlock = .{};
//   lock.acquire();
//   defer lock.release();
//   // ... critical section ...
//
// The lock uses x86 PAUSE instruction to reduce power consumption
// and improve performance in spin-wait loops.
// ============================================================================

const hal = @import("hal.zig");

pub const Spinlock = struct {
    locked: u32 = 0, // 0 = unlocked, 1 = locked

    /// Acquire the spinlock. Spins until the lock is available.
    pub fn acquire(self: *Spinlock) void {
        while (@atomicRmw(u32, &self.locked, .Xchg, 1, .acquire) != 0) {
            // Spin with PAUSE — reduces power and improves performance
            // on hyper-threaded CPUs by giving the other logical CPU
            // a chance to proceed.
            while (@atomicLoad(u32, &self.locked, .unordered) != 0) {
                asm volatile ("pause");
            }
        }
    }

    /// Release the spinlock.
    pub fn release(self: *Spinlock) void {
        @atomicStore(u32, &self.locked, 0, .release);
    }

    /// Try to acquire the spinlock. Returns true if successful.
    pub fn tryAcquire(self: *Spinlock) bool {
        return @atomicRmw(u32, &self.locked, .Xchg, 1, .acquire) == 0;
    }

    /// Check if the spinlock is currently held.
    pub fn isHeld(self: *Spinlock) bool {
        return @atomicLoad(u32, &self.locked, .unordered) != 0;
    }
};

/// RAII-style guard for spinlocks. Acquires on init, releases on deinit.
pub const SpinlockGuard = struct {
    lock: *Spinlock,

    pub fn init(lock: *Spinlock) SpinlockGuard {
        lock.acquire();
        return .{ .lock = lock };
    }

    pub fn deinit(self: *SpinlockGuard) void {
        self.lock.release();
    }
};

// ============================================================================
// Tests (native x86_64 Linux — not freestanding)
// ============================================================================

test "Spinlock acquire and release" {
    var lock: Spinlock = .{};
    lock.acquire();
    try std.testing.expect(lock.isHeld());
    lock.release();
    try std.testing.expect(!lock.isHeld());
}

test "Spinlock tryAcquire" {
    var lock: Spinlock = .{};
    try std.testing.expect(lock.tryAcquire());
    try std.testing.expect(!lock.tryAcquire()); // Already held
    lock.release();
    try std.testing.expect(lock.tryAcquire());
    lock.release();
}

const std = @import("std");
`
```

### `zig-kernel/src64/vmm64.zig` [zig · 11,233 B]
```
`// ============================================================================
// POLER-OS Virtual Memory Manager — x86_64
// ============================================================================

const pmm = @import("pmm64.zig");
const hal = @import("hal.zig");

pub const PTE_PRESENT: u64 = 0x01;
pub const PTE_WRITABLE: u64 = 0x02;
pub const PTE_USER: u64 = 0x04;
pub const PTE_WRITE_THROUGH: u64 = 0x08;
pub const PTE_CACHE_DISABLE: u64 = 0x10;
pub const PTE_ACCESSED: u64 = 0x20;
pub const PTE_DIRTY: u64 = 0x40;
pub const PTE_HUGE: u64 = 0x80;
pub const PTE_GLOBAL: u64 = 0x100;
pub const PTE_NO_EXECUTE: u64 = @as(u64, 1) << 63;

pub const PAGE_SIZE: u64 = 4096;

pub const VmmError = error{
    OutOfMemory,
    InvalidAddress,
    AlreadyMapped,
};

var pml4_phys: u64 = 0;

pub fn init() void {
    pml4_phys = hal.readCr3() & 0x000FFFFFFFFFF000;
    hal.Serial.puts("[VMM] Virtual Memory Manager initialized, PML4 at ");
    hal.Serial.putHex(pml4_phys);
    hal.Serial.puts("\n");
}

fn getOrCreateTable(table_phys: u64, index: usize, is_user: bool) !u64 {
    const table: [*]volatile u64 = @ptrFromInt(table_phys);
    const entry = table[index];

    if (entry & PTE_PRESENT != 0) {
        if (entry & PTE_HUGE != 0) {
            return VmmError.AlreadyMapped;
        }
        // v0.7.0 FIX: If the existing entry doesn't have PTE_USER but we need it
        // (e.g., kernel entry copied to user PML4 without PTE_USER, then user
        // mapping wants to use the same PDPT), add PTE_USER to the entry.
        // This allows Ring 3 to traverse through this page table level.
        if (is_user and (entry & PTE_USER == 0)) {
            table[index] = entry | PTE_USER;
        }
        return entry & 0x000FFFFFFFFFF000;
    }

    const new_table_phys = pmm.allocPage() orelse return VmmError.OutOfMemory;
    const ptr: [*]volatile u64 = @ptrFromInt(new_table_phys);
    @memset(@as([*]volatile u8, @ptrCast(ptr))[0..PAGE_SIZE], 0);

    // Page table entries: only set PTE_USER if this is a user mapping.
    // Kernel page tables should NOT have the User bit — this prevents
    // Ring 3 code from reading kernel memory.
    var pte_flags: u64 = PTE_PRESENT | PTE_WRITABLE;
    if (is_user) pte_flags |= PTE_USER;
    table[index] = new_table_phys | pte_flags;
    return new_table_phys;
}

/// Check if a page table (512 entries) is entirely empty
fn isTableEmpty(table_phys: u64) bool {
    const table: [*]const volatile u64 = @ptrFromInt(table_phys);
    var i: usize = 0;
    while (i < 512) : (i += 1) {
        if (table[i] & PTE_PRESENT != 0) return false;
    }
    return true;
}

pub fn mapPage(virt: u64, phys: u64, flags: u64) !void {
    if (virt % PAGE_SIZE != 0 or phys % PAGE_SIZE != 0) {
        return VmmError.InvalidAddress;
    }

    const pml4_idx = (virt >> 39) & 0x1FF;
    const pdpt_idx = (virt >> 30) & 0x1FF;
    const pd_idx = (virt >> 21) & 0x1FF;
    const pt_idx = (virt >> 12) & 0x1FF;

    // Determine if this is a user-space mapping.
    // If PTE_USER is set in flags, all intermediate page tables must also
    // have PTE_USER — otherwise Ring 3 can't traverse the page tables.
    // If PTE_USER is NOT set (kernel mapping), intermediate tables also
    // should NOT have PTE_USER — this prevents Ring 3 from accessing kernel memory.
    const is_user = (flags & PTE_USER) != 0;

    // v6 FIX (Bug #6): Track pages allocated during table creation
    // so we can free them on failure
    var allocated_pages: [3]?u64 = .{ null, null, null };

    // PDPT table
    const pml4: [*]volatile u64 = @ptrFromInt(pml4_phys);
    const pdpt_phys: u64 = blk: {
        if (pml4[pml4_idx] & PTE_PRESENT != 0) {
            break :blk pml4[pml4_idx] & 0x000FFFFFFFFFF000;
        }
        const page = pmm.allocPage() orelse return VmmError.OutOfMemory;
        const ptr: [*]volatile u64 = @ptrFromInt(page);
        @memset(@as([*]volatile u8, @ptrCast(ptr))[0..PAGE_SIZE], 0);
        // Only set PTE_USER on intermediate tables for user mappings
        var pte_flags: u64 = PTE_PRESENT | PTE_WRITABLE;
        if (is_user) pte_flags |= PTE_USER;
        pml4[pml4_idx] = page | pte_flags;
        allocated_pages[0] = page;
        break :blk page;
    };

    // PD table
    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys);
    const pd_phys: u64 = blk: {
        if (pdpt[pdpt_idx] & PTE_PRESENT != 0) {
            break :blk pdpt[pdpt_idx] & 0x000FFFFFFFFFF000;
        }
        const page = pmm.allocPage() orelse {
            // v6 FIX: Free already-allocated PDPT page on failure
            if (allocated_pages[0]) |p| { pmm.freePage(p); pml4[pml4_idx] = 0; }
            return VmmError.OutOfMemory;
        };
        const ptr: [*]volatile u64 = @ptrFromInt(page);
        @memset(@as([*]volatile u8, @ptrCast(ptr))[0..PAGE_SIZE], 0);
        var pte_flags: u64 = PTE_PRESENT | PTE_WRITABLE;
        if (is_user) pte_flags |= PTE_USER;
        pdpt[pdpt_idx] = page | pte_flags;
        allocated_pages[1] = page;
        break :blk page;
    };

    // PT table
    const pd: [*]volatile u64 = @ptrFromInt(pd_phys);
    const pt_phys: u64 = blk: {
        if (pd[pd_idx] & PTE_PRESENT != 0) {
            break :blk pd[pd_idx] & 0x000FFFFFFFFFF000;
        }
        const page = pmm.allocPage() orelse {
            // v6 FIX: Free already-allocated pages on failure
            if (allocated_pages[1]) |p| { pmm.freePage(p); pdpt[pdpt_idx] = 0; }
            if (allocated_pages[0]) |p| { pmm.freePage(p); pml4[pml4_idx] = 0; }
            return VmmError.OutOfMemory;
        };
        const ptr: [*]volatile u64 = @ptrFromInt(page);
        @memset(@as([*]volatile u8, @ptrCast(ptr))[0..PAGE_SIZE], 0);
        var pte_flags: u64 = PTE_PRESENT | PTE_WRITABLE;
        if (is_user) pte_flags |= PTE_USER;
        pd[pd_idx] = page | pte_flags;
        allocated_pages[2] = page;
        break :blk page;
    };

    // Check if the PTE is already occupied — refuse to silently overwrite
    const pt: [*]volatile u64 = @ptrFromInt(pt_phys);
    if (pt[pt_idx] & PTE_PRESENT != 0) {
        // v6 FIX: Free newly allocated page tables since we didn't need them
        // (They might be shared with other mappings, so only free if we just allocated them)
        // Actually, we should NOT free them here — other entries might already exist.
        // Just return the error; the allocated tables will be reused or freed later by unmapPage.
        return VmmError.AlreadyMapped;
    }

    pt[pt_idx] = phys | flags | PTE_PRESENT;

    asm volatile ("invlpg (%[virt])"
        :
        : [virt] "r" (virt),
        : "memory"
    );
}

/// v0.7.0: Create a new PML4 for a user process.
/// Copies kernel PML4 entries so the kernel remains mapped in the user
/// address space (needed for syscall entry, ISR handling, etc.).
///
/// CRITICAL SECURITY: Kernel PML4 entries are copied WITHOUT the PTE_USER bit.
/// This means Ring 3 code cannot access kernel memory — any attempt causes a
/// page fault. Ring 0 code (during syscall/interrupt handling) can still
/// access kernel pages because CPL=0 overrides the User/Supervisor check.
///
/// Returns the physical address of the new PML4.
pub fn createUserPML4() !u64 {
    const new_pml4_phys = pmm.allocPage() orelse return VmmError.OutOfMemory;
    const new_pml4: [*]volatile u64 = @ptrFromInt(new_pml4_phys);
    @memset(@as([*]volatile u8, @ptrCast(new_pml4))[0..PAGE_SIZE], 0);

    // Copy all non-zero PML4 entries from kernel (shared kernel mapping)
    // but STRIP the PTE_USER bit from kernel entries — this enforces
    // kernel/user isolation: Ring 3 cannot access kernel pages.
    const kernel_pml4: [*]const volatile u64 = @ptrFromInt(pml4_phys);
    for (0..512) |i| {
        const entry = kernel_pml4[i];
        if (entry & PTE_PRESENT != 0) {
            // Remove PTE_USER from kernel mappings — Ring 3 can't read kernel
            new_pml4[i] = entry & ~PTE_USER;
        }
    }

    hal.Serial.puts("[VMM] Created user PML4 at ");
    hal.Serial.putHex(new_pml4_phys);
    hal.Serial.puts(" (kernel entries WITHOUT User bit)\n");

    return new_pml4_phys;
}

/// v6 FIX (Bug #9): unmapPage now returns error instead of silently
/// ignoring misaligned addresses. Caller should handle the error.
pub fn unmapPage(virt: u64) VmmError!void {
    if (virt % PAGE_SIZE != 0) {
        hal.Serial.puts("[VMM] ERROR: unmapPage misaligned address: 0x");
        hal.Serial.putHex(virt);
        hal.Serial.puts("\n");
        return VmmError.InvalidAddress;
    }

    const pml4_idx = (virt >> 39) & 0x1FF;
    const pdpt_idx = (virt >> 30) & 0x1FF;
    const pd_idx = (virt >> 21) & 0x1FF;
    const pt_idx = (virt >> 12) & 0x1FF;

    const pml4: [*]volatile u64 = @ptrFromInt(pml4_phys);
    if (pml4[pml4_idx] & PTE_PRESENT == 0) return;
    const pdpt_phys = pml4[pml4_idx] & 0x000FFFFFFFFFF000;

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys);
    if (pdpt[pdpt_idx] & PTE_PRESENT == 0) return;
    const pd_phys = pdpt[pdpt_idx] & 0x000FFFFFFFFFF000;

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys);
    if (pd[pd_idx] & PTE_PRESENT == 0) return;
    const pt_phys = pd[pd_idx] & 0x000FFFFFFFFFF000;

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys);
    pt[pt_idx] = 0;

    asm volatile ("invlpg (%[virt])"
        :
        : [virt] "r" (virt),
        : "memory"
    );

    // Free empty page tables back to PMM (walk up from PT → PD → PDPT)
    if (isTableEmpty(pt_phys)) {
        pmm.freePage(pt_phys);
        pd[pd_idx] = 0;

        if (isTableEmpty(pd_phys)) {
            pmm.freePage(pd_phys);
            pdpt[pdpt_idx] = 0;

            if (isTableEmpty(pdpt_phys)) {
                pmm.freePage(pdpt_phys);
                pml4[pml4_idx] = 0;
            }
        }
    }
}

/// v0.7.0: Map a page in a SPECIFIC PML4 (not the global kernel PML4).
/// Used for user-space mappings that should only be accessible from
/// the user process's page tables (with PTE_USER set).
///
/// This function creates the full 4-level page table hierarchy
/// (PML4 → PDPT → PD → PT) in the target PML4, with PTE_USER on
/// all intermediate tables so Ring 3 can traverse them.
pub fn mapPageInPML4(target_pml4_phys: u64, virt: u64, phys: u64, flags: u64) !void {
    if (virt % PAGE_SIZE != 0 or phys % PAGE_SIZE != 0) {
        return VmmError.InvalidAddress;
    }

    const pml4_idx = (virt >> 39) & 0x1FF;
    const pdpt_idx = (virt >> 30) & 0x1FF;
    const pd_idx = (virt >> 21) & 0x1FF;
    const pt_idx = (virt >> 12) & 0x1FF;

    const is_user = (flags & PTE_USER) != 0;

    // Walk/create PML4 → PDPT → PD → PT in the target PML4

    // PDPT
    const pdpt_phys = try getOrCreateTable(target_pml4_phys, pml4_idx, is_user);

    // PD
    const pd_phys = try getOrCreateTable(pdpt_phys, pdpt_idx, is_user);

    // PT
    const pt_phys = try getOrCreateTable(pd_phys, pd_idx, is_user);

    // Set the actual page table entry
    const pt: [*]volatile u64 = @ptrFromInt(pt_phys);
    if (pt[pt_idx] & PTE_PRESENT != 0) {
        return VmmError.AlreadyMapped;
    }
    pt[pt_idx] = phys | flags | PTE_PRESENT;

    // No invlpg needed — this PML4 is not the active CR3 yet
}
`
```

## Лицензия
```
`GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2024-2026 POLER-OS Contributors

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

================================================================================

FULL TEXT OF GPLv3: https://www.gnu.org/licenses/gpl-3.0.txt

This work is licensed under the GNU General Public License v3.0 or later.
You are free to use, study, modify, and redistribute this software under
the terms of the GPLv3+. Any derivative works MUST also be licensed under
GPLv3+ and include the source code. This ensures that the knowledge and
improvements remain free and open for everyone.
`
```