# База знаний для Go-интервью (E4+)

Статический сайт на [Quartz v5](https://github.com/jackyzha0/quartz) с программой подготовки к техническим интервью Go-разработчика уровня middle / E4 и выше.

## Быстрый старт

```bash
npm ci
npx quartz plugin install
npx quartz build
npx quartz build --serve
```

Готовый статический сайт появится в `public/`.

## Docker production build

```bash
docker build -t go-interview-kb .
docker run --rm -p 8080:8080 go-interview-kb
```

Откройте `http://localhost:8080`. Образ собирает Quartz в первом stage и отдаёт только `public/` через непривилегированный nginx во втором stage.

## Контент

- Главная страница: `content/index.md`.
- Программа курса: `content/course/`.
- Шаблон новой заметки: `content/templates/topic-template.md`.
- Правила ведения базы: [`AGENTS.md`](AGENTS.md).

Перед публикацией установите реальный домен в `quartz.config.yaml` → `configuration.baseUrl`.
