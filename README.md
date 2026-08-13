# Kickly

Milestone 1 della web app per partite e leghe di calcio amatoriale.

```bash
npm install
npm run dev
```

Senza variabili ambiente l’app mostra la demo locale. Per collegare Supabase, copia `.env.example` in `.env.local` e valorizza URL e publishable key.

```bash
npm run supabase:start
npm run supabase:reset
npm run check
```

Richiede Node.js 22.13+; lo stack Supabase locale richiede Docker Desktop.
