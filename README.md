# customization-figma-mcp-bridge

Локальное окружение для проверки сайтов по макетам Figma с помощью Codex, Figma MCP Bridge и Playwright. Цель — проверять все адаптивы и состояния из макетов, находить подтверждённые расхождения и сохранять понятный HTML-отчёт с изображениями и измерениями.

Основа — [Figma MCP Bridge от gethopp](https://github.com/gethopp/figma-mcp-bridge), исходники в `figma-mcp-bridge/`. Сохранены авторство и [лицензия MIT](figma-mcp-bridge/LICENSE.md). Предыдущий форк: [StupnikovAleksandr/figma-mcp-bridge](https://github.com/StupnikovAleksandr/figma-mcp-bridge). Этот проект: [customization-figma-mcp-bridge](https://github.com/StupnikovAleksandr/customization-figma-mcp-bridge).

## Что добавлено

- PowerShell-установка и проверка локальных MCP-подключений.
- Подключение Playwright к dev-стендам с HTTP Basic Auth, ограниченным origin сайта.
- Проектный skill для сравнения всех выбранных адаптивов и состояний.
- Стандарт отчёта и самостоятельный HTML-шаблон: снимки рядом, наложение, прозрачность, масштаб 1:1, замечания и измерения.
- Правило: разница до **3 CSS px включительно** не считается ошибкой; сравниваются значения до округления.

Bridge читает макет и экспортирует изображения. Playwright открывает сайт, измеряет DOM/CSS и делает снимки. Codex сопоставляет результаты и готовит отчёт. Сам Bridge сайт не проверяет; аналогичный процесс возможен с официальным Figma MCP. [Сравнение подходов](FIGMA-BRIDGE-ADVANTAGES.md).

## Быстрый старт

Нужны Windows PowerShell, Node.js 20+, npm, установленный и авторизованный Codex CLI и Figma Desktop.

```powershell
git clone https://github.com/StupnikovAleksandr/customization-figma-mcp-bridge.git
cd customization-figma-mcp-bridge
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-figma.ps1
```

Импортируй `figma-mcp-bridge/plugin/manifest.json` как development plugin в Figma Desktop, запусти его в нужном файле и оставь открытым. Перезапусти Codex и выдели фреймы. [Подробная установка и диагностика](FIGMA-START.md).

Для закрытого стенда настрой [HTTP Basic Auth](browser-tools/BASIC-AUTH.md). Адрес, логин и пароль хранятся локально; реальные доступы в репозиторий не входят.

Пример запроса: «Сравни выделенные в Figma фреймы с указанным сайтом на всех адаптивах и состояниях. Подготовь отчёт по стандарту проекта».

## Документация

| Файл | Назначение |
| --- | --- |
| [FIGMA-START.md](FIGMA-START.md) | Установка, manifest и диагностика |
| [FIGMA-BRIDGE-ADVANTAGES.md](FIGMA-BRIDGE-ADVANTAGES.md) | Сравнение с официальным Figma MCP |
| [BASIC-AUTH.md](browser-tools/BASIC-AUTH.md) | URL, логин, пароль и Windows DPAPI |
| [AUDIT-REPORT-STANDARD.md](AUDIT-REPORT-STANDARD.md) | Результаты, доказательства, допуск 3 px |
| [SKILL.md](skills/figma-site-audit/SKILL.md) | Инструкции аудита для агента |
| [Шаблон HTML](skills/figma-site-audit/assets/compare.html) | Заготовка просмотрщика |
| [AGENTS.md](AGENTS.md) | Предпочтения проекта для Codex |
| [README Bridge](figma-mcp-bridge/README.md) | Сервер, плагин и MCP-инструменты |

`setup-figma.ps1` настраивает окружение; `verify-figma.mjs` проверяет соединения; `browser-tools/` содержит обёртку браузера; `skills/` — инструкции и шаблон.

## Результаты и текущие возможности

Каждый аудит создаёт `audit-<проект>-<блок>/` с `compare.html`, `REPORT.md`, `measurements.json` и PNG. Открой HTML в браузере; для передачи результата передавай всю папку с изображениями. Для просмотра MCP и Figma не нужны.

Реализованы локальный процесс аудита и просмотрщик готовых результатов. Публичный веб-сервис с формой URL/доступов, индикаторами MCP и чатом Codex пока не реализован.

`.gitignore` исключает отчёты, зависимости, сборки, кэши, локальные настройки и секреты. Исходники, lock-файлы и шаблон сохраняются. Вложенные исходники Bridge включены в этот проект обычными файлами; их локальная Git-история не переносится. Перед публикацией проверяй добавленные файлы: исключения не удаляют уже отслеживаемые секреты из истории.



Скрипт создаёт Git-репозиторий при необходимости, выбирает main, настраивает указанный выше origin, добавляет исходники и документацию, проверяет исключения, создаёт первый коммит `first commit` и выполняет `git push -u origin main`. Вложенный checkout Bridge добавляется обычными исходниками, без gitlink. Существующий origin другого проекта не перезаписывается; force push не используется. Нужны настроенные имя/email Git и авторизация GitHub. Скрипт не обходит ограничения среды: запускай его там, где разрешена запись в `.git`.
