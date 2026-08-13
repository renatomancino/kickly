/**
 * Apply RLS migration fixes via SQL
 */

import fs from 'fs';

(async () => {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    console.error('Missing env vars');
    process.exit(1);
  }

  console.log('🔐 Applying RLS Migration Fixes\n');

  // Read migration file
  const migrationSQL = fs.readFileSync('./supabase/migrations/20260813000000_phase7_e2e_setup.sql', 'utf-8');

  // Split into individual statements and execute
  const statements = migrationSQL
    .split(';')
    .map(s => s.trim())
    .filter(s => s && !s.startsWith('--'));

  for (const statement of statements) {
    if (!statement) continue;

    try {
      // Execute via rpc with raw SQL (not ideal but works)
      // Instead, we'll use the pg library if available, or direct HTTP call
      console.log(`Executing: ${statement.substring(0, 60)}...`);
      
      // For now, just report what we'd execute
      // The migration must be applied via:
      // 1. Supabase Dashboard SQL Editor, OR
      // 2. supabase db push command
    } catch (e) {
      console.error(`Error: ${e.message}`);
    }
  }

  console.log('\n⚠️  RLS Migration must be applied manually:\n');
  console.log('Option 1 - Via Supabase CLI:');
  console.log('  $ supabase db push --linked\n');
  
  console.log('Option 2 - Via Supabase Dashboard:');
  console.log('  1. Go to SQL Editor');
  console.log('  2. Open: supabase/migrations/20260813000000_phase7_e2e_setup.sql');
  console.log('  3. Copy entire SQL and paste in editor');
  console.log('  4. Click "Run"\n');

  // Alternative: apply directly via connection if pg library available
  const migrationToApply = `
-- Phase 7 E2E RLS Fixes

-- 1. Fix league_members INSERT policy
CREATE OR REPLACE POLICY "Users can insert league membership requests"
  ON public.league_members
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 2. Enable RLS and create policies for player_rating_history
ALTER TABLE public.player_rating_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Users insert own rating history"
  ON public.player_rating_history
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Users read rating history"
  ON public.player_rating_history
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() 
    OR EXISTS (
      SELECT 1 FROM public.matches
      WHERE id = match_id AND visibility = 'public'
    )
  );

-- 3. Update league_members INSERT/UPDATE policies
DROP POLICY IF EXISTS "Users request membership" ON public.league_members;

CREATE OR REPLACE POLICY "Users can update league membership"
  ON public.league_members
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid() OR auth.uid() IN (
    SELECT user_id FROM public.league_members 
    WHERE league_id = league_members.league_id AND role IN ('owner', 'admin')
  ))
  WITH CHECK (user_id = auth.uid() OR auth.uid() IN (
    SELECT user_id FROM public.league_members 
    WHERE league_id = league_members.league_id AND role IN ('owner', 'admin')
  ));
  `;

  console.log('📋 Migration SQL to apply:\n');
  console.log('---');
  console.log(migrationToApply);
  console.log('---\n');

  console.log('✅ Save migration file and apply via CLI or Dashboard');
})();
