# Платформа: Linux и macOS

`g-tools` собирается только на POSIX-системах, и это осознанное ограничение, а не недоделка:

| Что | Почему нельзя на Windows |
|---|---|
| ingest (`core/include/gcore/mmap_ingest.h`) | `mmap(PROT_READ, MAP_SHARED)` + `madvise(MADV_WILLNEED \| MADV_SEQUENTIAL)`; Windows-аналог (`CreateFileMapping` / `MapViewOfFile`) не даёт тех же подсказок ядру |
| raw-syscall путь | на Linux вызовы идут через `syscall(SYS_openat/SYS_mmap/...)` намеренно: иначе `LD_PRELOAD`-shim перехватывает собственный ingest и двойной `mmap/munmap` уничтожает кэш слайсов. На Windows понятия `LD_PRELOAD` нет, и это преимущество не переносится |
| `-Wl,--wrap` / `-rdynamic` | линковка специфична для ELF |

## Что нужно, чтобы появился Windows-порт

1. Реализовать `MmapFile` через `CreateFileMapping` + `MapViewOfFile` (отображение read-only
   разделяемое, закрытие через `UnmapViewOfFile`), сохранив тот же интерфейс `open/size/data/close`.
2. Заменить raw-syscall ветку на обычные CRT-вызовы: на Windows она не нужна, но и
   «zero-copy поверх shim» там не проверяется — это надо честно написать в README.
3. Прогнать `ctest` под MSVC (в коде есть `__attribute__`-места, потребуется `__declspec`-ветка).
4. Пересчитать бенчмарк: числа с Linux нельзя переносить на Windows.

Пока этого нет, `mmap_ingest.h` выдаёт `#error` с этой ссылкой вместо непонятной ошибки
«sys/mman.h: No such file or directory».
