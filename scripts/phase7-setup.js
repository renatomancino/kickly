/**
 * Phase 7 E2E Setup Script
 * Configures test environment: RLS policies, test league, account roles
 */

import fs from 'fs';

(async () => {
  const { createClient } = await import('@supabase/supabase-js');

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    console.error('Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }

  const supabase = createClient(url, serviceKey);

  console.log('Phase 7 E2E Setup\n');

  // ============================================================================
  // 1. Ensure test league exists
  // ============================================================================
  console.log('1. Setting up PUSH_TEST_LEAGUE_ID...');
  const testLeagueId = '20000000-0000-0000-0000-000000000001';

  try {
    const { data: existingLeague } = await supabase
      .from('leagues')
      .select('id')
      .eq('id', testLeagueId)
      .single();

    if (!existingLeague) {
      // League doesn't exist; create it
      const { error: createError } = await supabase
        .from('leagues')
        .insert({
          id: testLeagueId,
          created_by: '00000000-0000-0000-0000-000000000001', // System placeholder
          name: 'PUSH-TEST League',
          description: 'Dedicated test league for E2E notifications testing',
          visibility: 'private',
          status: 'active',
          max_members: 100,
          invite_code: `PUSH-TEST-${new Date().toISOString().slice(0, 10)}`,
        });

      if (createError) {
        console.log('  ! Could not create league (may already exist):', createError.message);
      } else {
        console.log('  ✓ Created PUSH_TEST_LEAGUE_ID');
      }
    } else {
      console.log('  ✓ PUSH_TEST_LEAGUE_ID exists');
    }
  } catch (e) {
    console.log('  ! League query failed:', e.message);
  }

  // ============================================================================
  // 2. Configure test accounts as league admins
  // ============================================================================
  console.log('\n2. Configuring test accounts as league admins...');

  const testAccounts = {
    owner: process.env.TEST_OWNER_EMAIL,
    admin: process.env.TEST_ADMIN_EMAIL,
    memberA: process.env.TEST_MEMBER_A_EMAIL,
    memberB: process.env.TEST_MEMBER_B_EMAIL,
  };

  for (const [role, email] of Object.entries(testAccounts)) {
    if (!email) {
      console.log(`  ! ${role} email not provided`);
      continue;
    }

    try {
      // Find user by email
      const { data: users, error: findError } = await supabase.auth.admin.listUsers();
      const user = users?.users?.find((u) => u.email === email);

      if (!user) {
        console.log(`  ! User ${email} not found in auth`);
        continue;
      }

      const userId = user.id;
      const memberRole = role === 'owner' ? 'owner' : role === 'admin' ? 'admin' : 'member';

      // Check if already member
      const { data: existing } = await supabase
        .from('league_members')
        .select('id')
        .eq('league_id', testLeagueId)
        .eq('user_id', userId)
        .single();

      if (existing) {
        // Update role
        const { error: updateError } = await supabase
          .from('league_members')
          .update({ role: memberRole, status: 'active' })
          .eq('league_id', testLeagueId)
          .eq('user_id', userId);

        if (updateError) {
          console.log(`  ! Could not update ${email}:`, updateError.message);
        } else {
          console.log(`  ✓ ${email} updated as ${memberRole}`);
        }
      } else {
        // Insert as member
        const { error: insertError } = await supabase
          .from('league_members')
          .insert({
            league_id: testLeagueId,
            user_id: userId,
            role: memberRole,
            status: 'active',
          });

        if (insertError) {
          console.log(`  ! Could not add ${email}:`, insertError.message);
        } else {
          console.log(`  ✓ ${email} added as ${memberRole}`);
        }
      }
    } catch (e) {
      console.log(`  ! Error processing ${email}:`, e.message);
    }
  }

  // ============================================================================
  // 3. Apply RLS policy fixes via raw SQL (if supported)
  // ============================================================================
  console.log('\n3. Checking RLS policies...');

  try {
    // Check if we can query player_rating_history (requires RLS policy)
    const { data: sample, error: raterError } = await supabase
      .from('player_rating_history')
      .select('id')
      .limit(0);

    if (raterError?.code === '42501') {
      console.log('  ! player_rating_history needs RLS policy fix (permission denied)');
      console.log('    → Run migration: 20260813000000_phase7_e2e_setup.sql');
    } else if (!raterError) {
      console.log('  ✓ player_rating_history accessible');
    }
  } catch (e) {
    console.log('  ! Could not check rating history:', e.message);
  }

  try {
    // Check league_members INSERT policy
    const { error: leagueError } = await supabase
      .from('league_members')
      .select('id')
      .limit(0);

    if (!leagueError) {
      console.log('  ✓ league_members accessible');
    }
  } catch (e) {
    console.log('  ! Could not check league_members:', e.message);
  }

  // ============================================================================
  // Summary
  // ============================================================================
  console.log('\n✓ Phase 7 E2E Setup Complete\n');
  console.log('Next steps:');
  console.log('1. Apply migration via Supabase CLI: supabase db push');
  console.log('2. Configure Vault secrets (Supabase Dashboard → Settings → Vault):');
  console.log('   - kickly_vapid_public_key');
  console.log('   - kickly_vapid_private_key');
  console.log('   - kickly_vapid_subject');
  console.log('   - kickly_project_url');
  console.log('   - kickly_publishable_key');
  console.log('3. Run: node scripts/e2e-notifications.js');
})();
