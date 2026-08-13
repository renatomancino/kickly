import { NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth';
import { createClient } from '@/lib/supabase/server';

const webpush = require('web-push');

export async function POST(request: Request) {
  try {
    const user = await getCurrentUser();
    if (!user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const { title, body, url } = await request.json();

    const supabase = await createClient();

    // Fetch user's subscriptions
    const { data: subscriptions, error: subError } = await supabase
      .from('push_subscriptions')
      .select('*')
      .eq('user_id', user.id);

    if (subError || !subscriptions || subscriptions.length === 0) {
      return NextResponse.json(
        { error: 'NO_ACTIVE_IOS_SUBSCRIPTION', status: 'NO_ACTIVE_IOS_SUBSCRIPTION' },
        { status: 404 }
      );
    }

    // Get VAPID keys from Vault
    const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;
    const vapidSubject = process.env.VAPID_SUBJECT;

    if (!vapidPublicKey || !vapidPrivateKey || !vapidSubject) {
      return NextResponse.json(
        { error: 'VAPID_CONFIGURATION_ERROR', status: 'VAPID_CONFIGURATION_ERROR' },
        { status: 500 }
      );
    }

    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

    const tag = `test-${Date.now()}`;
    const payload = JSON.stringify({
      title,
      body,
      icon: '/icons/icon-192x192.png',
      badge: '/icons/badge-72x72.png',
      data: { url },
      tag,
    });

    // Send to each subscription and log results
    let successCount = 0;
    let lastStatus = 'UNKNOWN';
    let lastError = null;

    for (const subscription of subscriptions) {
      try {
        const subscriptionObj = {
          endpoint: subscription.endpoint,
          keys: {
            p256dh: subscription.p256dh,
            auth: subscription.auth,
          },
        };

        const response = await webpush.sendNotification(subscriptionObj, payload);

        lastStatus = 'PROVIDER_SENT_AWAITING_DEVICE_CONFIRMATION';
        successCount++;

        // Log delivery attempt
        await supabase.from('push_delivery_logs').insert({
          user_id: user.id,
          subscription_id: subscription.endpoint,
          notification_type: 'test_push',
          status: 'sent',
          provider_status: response.status,
          created_at: new Date().toISOString(),
        });
      } catch (error: any) {
        lastError = error;
        console.error('Error sending to subscription:', error);

        // Handle specific HTTP status codes
        if (error.statusCode === 404 || error.statusCode === 410) {
          // Subscription expired or invalid
          await supabase
            .from('push_subscriptions')
            .delete()
            .eq('endpoint', subscription.endpoint);
          lastStatus = 'NO_ACTIVE_IOS_SUBSCRIPTION';
        } else if (error.statusCode === 401 || error.statusCode === 403) {
          lastStatus = 'VAPID_CONFIGURATION_ERROR';
        } else if (error.statusCode === 429 || error.statusCode >= 500) {
          lastStatus = 'PROVIDER_FAILED';
        }

        // Log failed attempt
        await supabase.from('push_delivery_logs').insert({
          user_id: user.id,
          subscription_id: subscription.endpoint,
          notification_type: 'test_push',
          status: 'failed',
          provider_status: error.statusCode || 0,
          error: error.message,
          created_at: new Date().toISOString(),
        });
      }
    }

    if (successCount === 0) {
      return NextResponse.json(
        { error: lastStatus, status: lastStatus },
        { status: 400 }
      );
    }

    return NextResponse.json({
      success: true,
      status: lastStatus,
      subscriptionsProcessed: subscriptions.length,
      successCount,
    });
  } catch (err) {
    console.error('Send test push error:', err);
    return NextResponse.json(
      { error: 'PROVIDER_FAILED', status: 'PROVIDER_FAILED' },
      { status: 500 }
    );
  }
}
