/**
 * Apply RLS Migration via SQL Execution
 * Uses Supabase admin API to execute raw SQL
 */

(async () => {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    console.error('Missing env vars');
    process.exit(1);
  }

  console.log('🔐 Applying RLS Migration via REST API\n');

  const sqlStatements = [
    `CREATE OR REPLACE POLICY "Users can insert league membership requests"
      ON public.league_members
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());`,

    `CREATE OR REPLACE POLICY "Users can update own league membership"
      ON public.league_members
      FOR UPDATE TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());`,

    `ALTER TABLE public.player_rating_history ENABLE ROW LEVEL SECURITY;`,

    `DROP POLICY IF EXISTS "Users insert own rating history" ON public.player_rating_history;`,

    `CREATE POLICY "Users insert own rating history"
      ON public.player_rating_history
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());`,

    `CREATE POLICY "Users read rating history"
      ON public.player_rating_history
      FOR SELECT TO authenticated
      USING (
        user_id = auth.uid() 
        OR EXISTS (
          SELECT 1 FROM public.matches
          WHERE id = match_id AND visibility = 'public'
        )
      );`,
  ];

  console.log('Executing SQL statements...\n');

  let successCount = 0;
  let errorCount = 0;

  for (let i = 0; i < sqlStatements.length; i++) {
    const sql = sqlStatements[i];
    const label = sql.substring(0, 50).replace(/\n/g, ' ');

    try {
      // Use fetch to call Supabase REST API
      const response = await fetch(`${url}/rest/v1/rpc/sql_query`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${serviceKey}`,
          'apikey': serviceKey,
        },
        body: JSON.stringify({ query: sql }),
      });

      if (response.ok) {
        console.log(`✓ ${i + 1}/${sqlStatements.length}: ${label}...`);
        successCount++;
      } else {
        const error = await response.text();
        console.log(`✗ ${i + 1}/${sqlStatements.length}: ${label}...`);
        console.log(`  Error: ${error.substring(0, 100)}`);
        errorCount++;
      }
    } catch (e) {
      console.log(`✗ ${i + 1}/${sqlStatements.length}: ${label}...`);
      console.log(`  Exception: ${e.message}`);
      errorCount++;
    }
  }

  console.log(`\n═══════════════════════════════════════════════════`);
  console.log(`Results: ✓ ${successCount} | ✗ ${errorCount}`);
  console.log(`═══════════════════════════════════════════════════\n`);

  if (errorCount > 0) {
    console.log('⚠️  Some statements failed. This may be expected if:');
    console.log('  - Policies already exist (conflicts with CREATE)');
    console.log('  - REST endpoint does not support raw SQL\n');
    
    console.log('✅ Recommended: Apply migration via CLI or Dashboard:');
    console.log('  $ supabase db push\n');
    console.log('Or manually in Dashboard → SQL Editor');
  } else {
    console.log('✅ All RLS policies applied successfully!');
  }
})();
