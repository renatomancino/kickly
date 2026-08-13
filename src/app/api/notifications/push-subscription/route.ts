import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';

export async function GET() {
  try {
    const user = await getCurrentUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = await createClient();
    
    // Query the push_subscriptions table for this user
    const { data, error } = await supabase
      .from('push_subscriptions')
      .select('endpoint, p256dh, auth, created_at')
      .eq('user_id', user.id)
      .maybeSingle();

    if (error) {
      console.error('Error fetching subscription:', error);
      return NextResponse.json({ subscription: null });
    }

    // Check last delivery status
    let lastDeliveryStatus = null;
    if (data) {
      const { data: lastDelivery } = await supabase
        .from('push_delivery_logs')
        .select('status')
        .eq('subscription_id', data.endpoint)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      lastDeliveryStatus = lastDelivery?.status || null;
    }

    return NextResponse.json({
      subscription: data ? {
        hasEndpoint: !!data.endpoint,
        hasP256dh: !!data.p256dh,
        hasAuth: !!data.auth,
        createdAt: data.created_at,
      } : null,
      lastDeliveryStatus,
    });
  } catch (err) {
    console.error('Push subscription GET error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const user = await getCurrentUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { subscription } = await request.json();

    if (!subscription || !subscription.endpoint) {
      return NextResponse.json({ error: 'Invalid subscription' }, { status: 400 });
    }

    const supabase = await createClient();

    // Upsert the subscription
    const { error } = await supabase
      .from('push_subscriptions')
      .upsert({
        user_id: user.id,
        endpoint: subscription.endpoint,
        p256dh: subscription.keys?.p256dh,
        auth: subscription.keys?.auth,
        created_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
      });

    if (error) {
      console.error('Error saving subscription:', error);
      return NextResponse.json({ error: 'Failed to save subscription' }, { status: 500 });
    }

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error('Push subscription POST error:', err);
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 });
  }
}
