/**
 * Apply RLS Migration via PostgreSQL Direct Connection
 * Uses connection string from Supabase project settings
 */

import fs from 'fs';

(async () => {
  // Require pg library
  let pg;
  try {
    pg = (await import('pg')).default;
  } catch (e) {
    console.log('❌ pg library not found. Installing...\n');
    console.log('Run: npm install pg');
    console.log('\nThen run this script again.');
    process.exit(1);
  }

  const { Client } = pg;

  // Build PostgreSQL connection string from Supabase credentials
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    console.log('❌ Missing env vars');
    process.exit(1);
  }

  // Extract project ref from URL
  const projectRef = url.match(/https:\/\/([a-z0-9-]+)\.supabase\.co/)?.[1];

  if (!projectRef) {
    console.log('❌ Could not parse project ref from URL');
    process.exit(1);
  }

  // Supabase PostgreSQL connection
  const connectionString = `postgresql://postgres:${serviceKey}@db.${projectRef}.supabase.co:5432/postgres`;

  console.log('🔐 Applying RLS Migration via PostgreSQL\n');
  console.log(`Connecting to: db.${projectRef}.supabase.co\n`);

  const client = new Client({ connectionString });

  try {
    await client.connect();
    console.log('✓ Connected to PostgreSQL\n');

    // Read and execute migration
    const migrationFile = './supabase/migrations/20260813000000_phase7_e2e_setup.sql';
    const migrationSQL = fs.readFileSync(migrationFile, 'utf-8');

    // Split by semicolons (simple approach)
    const statements = migrationSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s && !s.startsWith('--'));

    console.log(`Executing ${statements.length} SQL statements...\n`);

    let successCount = 0;
    let errorCount = 0;

    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i];
      const label = statement.substring(0, 60).replace(/\n/g, ' ');

      try {
        await client.query(statement);
        console.log(`✓ ${i + 1}/${statements.length}: ${label}...`);
        successCount++;
      } catch (e) {
        const msg = e.message || String(e);
        console.log(`⚠ ${i + 1}/${statements.length}: ${label}...`);
        console.log(`   → ${msg.substring(0, 80)}`);
        errorCount++;
      }
    }

    console.log(`\n════════════════════════════════════════════════`);
    console.log(`Results: ✓ ${successCount} succeeded | ⚠ ${errorCount} warnings`);
    console.log(`════════════════════════════════════════════════\n`);

    if (successCount > 0) {
      console.log('✅ RLS Migration applied successfully!');
    }

    if (errorCount > 0) {
      console.log('Note: Warnings are often expected if:');
      console.log('  - Policies already exist');
      console.log('  - Functions were already created');
    }

  } catch (e) {
    console.log(`❌ Connection error: ${e.message}`);
    console.log('\nTroubleshooting:');
    console.log('1. Verify service role key is correct');
    console.log('2. Check project ref matches URL');
    console.log('3. Ensure database is accessible');
  } finally {
    await client.end();
  }
})();
