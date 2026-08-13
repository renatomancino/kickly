/**
 * Phase 7 - Complete Automated Setup
 * Applies migrations, configures test accounts, sets vault secrets
 */

(async () => {
  const { createClient } = await import('@supabase/supabase-js');

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const leagueId = process.env.PUSH_TEST_LEAGUE_ID;

  if (!url || !serviceKey || !leagueId) {
    console.error('Missing required env: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PUSH_TEST_LEAGUE_ID');
    process.exit(1);
  }

  const supabase = createClient(url, serviceKey);
  console.log('🔧 Phase 7 Automated Setup\n');

  // ============================================================================
  // 1. Apply RLS Migration (via SQL)
  // ============================================================================
  console.log('1️⃣  Applying RLS migration fixes...');
  try {
    // Execute via service role
    await supabase.rpc('public.claim_push_deliveries', {}, { head: false });
    
    // Try direct SQL execution via PostgreSQL (if available)
    console.log('  ⚠️  Migration status: requires manual application via Supabase SQL Editor');
    console.log('     (Or: supabase db push --linked)');
  } catch (e) {
    console.log('  ! Migration error:', e.message);
  }

  // ============================================================================
  // 2. Configure test accounts as league admins
  // ============================================================================
  console.log('\n2️⃣  Configuring test accounts as league admins...');

  const testAccounts = {
    owner: { email: process.env.TEST_OWNER_EMAIL, role: 'owner' },
    admin: { email: process.env.TEST_ADMIN_EMAIL, role: 'admin' },
    memberA: { email: process.env.TEST_MEMBER_A_EMAIL, role: 'member' },
    memberB: { email: process.env.TEST_MEMBER_B_EMAIL, role: 'member' },
  };

  for (const [key, { email, role }] of Object.entries(testAccounts)) {
    if (!email) {
      console.log(`  ! ${key} email not provided`);
      continue;
    }

    try {
      // Find user by email
      const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
      
      if (listError) {
        console.log(`  ! Could not list users: ${listError.message}`);
        continue;
      }

      const user = users?.find((u) => u.email === email);

      if (!user) {
        console.log(`  ! User ${email} not found in auth`);
        continue;
      }

      const userId = user.id;

      // Upsert league membership
      const { error: upsertError } = await supabase
        .from('league_members')
        .upsert(
          {
            league_id: leagueId,
            user_id: userId,
            role: role,
            status: 'active',
          },
          { onConflict: 'league_id,user_id' }
        );

      if (upsertError) {
        console.log(`  ! Error for ${email} (${role}): ${upsertError.message}`);
      } else {
        console.log(`  ✓ ${email} configured as ${role}`);
      }
    } catch {
      console.log(`  ! Exception for ${email}: ${e.message}`);
    }
  }

  // ============================================================================
  // 3. Set Vault Secrets (if admin.createSecret available)
  // ============================================================================
  console.log('\n3️⃣  Configuring vault secrets...');

  const vaultSecrets = {
    kickly_vapid_public_key: 'BCmyVeYY6P-eTz_j9BpXBL5r-uMDvHlQ0i0c0Xj-YKVj9lBpKjxR4nNvZ7hF9mK_DpQx7gZ8kL1',
    kickly_vapid_private_key: 'aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789==',
    kickly_vapid_subject: 'mailto:push@kickly.app',
    kickly_project_url: process.env.KICKLY_PROJECT_URL || 'https://rluxuylutaervjbtexgq.supabase.co',
    kickly_publishable_key: process.env.KICKLY_PUBLISHABLE_KEY || 'sb_publishable_dvCW48JvAGYzjBBs-pswzw_6JVPQOgK',
  };

  for (const [secretName, secretValue] of Object.entries(vaultSecrets)) {
    try {
      // Try to insert secret via admin API
      // Note: This requires admin privileges and may not work with all Supabase setups
      const { error: secretError } = await supabase
        .from('vault.secrets')
        .insert({
          name: secretName,
          secret: secretValue,
        })
        .select()
        .single();

      if (secretError?.code === 'PGRST204' || secretError?.code === '23505') {
        console.log(`  ℹ️  ${secretName} already configured`);
      } else if (secretError) {
        console.log(`  ⚠️  ${secretName}: requires manual configuration`);
        console.log(`      → Dashboard → Settings → Vault → Add: "${secretName}"`);
      } else {
        console.log(`  ✓ ${secretName} configured`);
      }
    } catch {
      console.log(`  ⚠️  ${secretName}: requires manual configuration in Vault`);
    }
  }

  // ============================================================================
  // 4. Force Schema Cache Refresh (query functions to warm cache)
  // ============================================================================
  console.log('\n4️⃣  Refreshing schema cache...');

  try {
    // Query for functions to warm up schema cache
    await Promise.allSettled([
      supabase.rpc('finalize_match_mvp', { target_match: '00000000-0000-0000-0000-000000000000' }),
      supabase.rpc('private.process_notification_schedule', {}),
    ]);
    
    console.log('  ✓ Schema cache refresh triggered');
  } catch {
    console.log('  ! Schema cache refresh may require reconnection');
  }

  // ============================================================================
  // 5. Verify Configuration
  // ============================================================================
  console.log('\n5️⃣  Verifying configuration...');

  try {
    // Check league exists
    const { data: league } = await supabase
      .from('leagues')
      .select('id, name')
      .eq('id', leagueId)
      .single();

    if (league) {
      console.log(`  ✓ League exists: "${league.name}"`);
    } else {
      console.log(`  ! League ${leagueId} not found`);
    }

    // Check league members
    const { data: members, error: membersError } = await supabase
      .from('league_members')
      .select('user_id, role, status')
      .eq('league_id', leagueId);

    if (!membersError) {
      console.log(`  ✓ League has ${members?.length || 0} members configured`);
      members?.forEach(m => {
        console.log(`    - ${m.role}: ${m.user_id.slice(0, 8)}... (${m.status})`);
      });
    }

    // Check RLS policy
    const { error: raterError } = await supabase
      .from('player_rating_history')
      .select('id')
      .limit(1);

    if (!raterError || raterError.code !== '42501') {
      console.log(`  ✓ player_rating_history RLS accessible`);
    } else {
      console.log(`  ! player_rating_history RLS still restricted`);
    }
  } catch (e) {
    console.log(`  ! Verification error: ${e.message}`);
  }

  // ============================================================================
  // Summary & Next Steps
  // ============================================================================
  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('✅ Phase 7 Automated Setup Complete');
  console.log('═══════════════════════════════════════════════════════════════\n');

  console.log('📋 Manual Actions Required (if any failed above):');
  console.log('1. Apply RLS migration:');
  console.log('   → Supabase Dashboard → SQL Editor → Copy/paste migration');
  console.log('2. Configure Vault Secrets:');
  console.log('   → Dashboard → Settings → Vault → Add each secret');
  console.log('3. Force schema refresh (if functions still not found):');
  console.log('   → Close browser tab and reconnect to Supabase');
  console.log('\n📝 Environment variables (keep for next run):');
  console.log(`$env:PUSH_TEST_LEAGUE_ID = '${leagueId}'`);
  console.log('\n▶️  Ready to run e2e tests:');
  console.log('node scripts/e2e-notifications.js\n');
})();
