/**
 * Find existing test league or use the first available league
 */

import fs from 'fs';

(async () => {
  const { createClient } = await import('@supabase/supabase-js');

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    console.error('Missing env vars');
    process.exit(1);
  }

  const supabase = createClient(url, serviceKey);

  console.log('Checking leagues in database...\n');

  try {
    // Get all leagues
    const { data: leagues, error } = await supabase
      .from('leagues')
      .select('id, name, owner_id, visibility')
      .limit(10);

    if (error) {
      console.error('Error:', error.message);
      process.exit(1);
    }

    if (!leagues || leagues.length === 0) {
      console.log('No leagues found. Need to create one first via app UI or database.');
      process.exit(1);
    }

    console.log(`Found ${leagues.length} league(s):\n`);
    leagues.forEach((league, i) => {
      console.log(`${i + 1}. ID: ${league.id}`);
      console.log(`   Name: ${league.name}`);
      console.log(`   Owner: ${league.owner_id}`);
      console.log(`   Visibility: ${league.visibility}\n`);
    });

    // Use first league as test league
    const testLeague = leagues[0];
    console.log(`\n✓ Will use league ID: ${testLeague.id} for testing`);
    console.log('\nSet this env var for e2e tests:');
    console.log(`$env:PUSH_TEST_LEAGUE_ID = '${testLeague.id}'\n`);

  } catch (e) {
    console.error('Exception:', e.message);
    process.exit(1);
  }
})();
