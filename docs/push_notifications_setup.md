# Push Notification Setup

This repo now sends app push requests through the Supabase Edge Function `send-chat-message-push`.

## What to deploy

1. Run the SQL migration in `supabase/migrations/20260423_add_push_notification_columns.sql`.
2. Run the SQL migration in `supabase/migrations/20260423_add_related_conversation_id_to_notifications.sql`.
3. Set the function secret:

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

4. Deploy the function:

```bash
supabase functions deploy send-chat-message-push
```

## Firebase requirements

- Android: `android/app/google-services.json` is already present and should match `com.secondhand.marketplace`.
- iOS: add the matching `GoogleService-Info.plist` to `ios/Runner/`.
- Firebase Cloud Messaging must be enabled for the project.
- For iOS production delivery, configure APNs in the Firebase console and enable Push Notifications in Xcode signing/capabilities.

## Runtime flow

- User enables push in Settings.
- The app stores `push_enabled` and `fcm_token` in `users`.
- Sending a chat message inserts the message and creates the notification row.
- Order, sale, review, and other app notifications also create notification rows.
- `NotificationService` invokes the edge function after notification creation.
- The edge function looks up the recipient token and sends the FCM push.
