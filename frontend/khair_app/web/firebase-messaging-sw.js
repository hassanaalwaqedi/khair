/*
 * Firebase Cloud Messaging worker for Flutter Web.
 * This worker intentionally contains only public Firebase client settings;
 * FCM server credentials stay in the Go backend environment.
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC9ntY-ZZ2SbCYwk0tc_80ilATMjt6YmLo',
  authDomain: 'khair-it-app.firebaseapp.com',
  projectId: 'khair-it-app',
  storageBucket: 'khair-it-app.firebasestorage.app',
  messagingSenderId: '1061209811578',
  appId: '1:1061209811578:web:0a7686e93c040eb59ae9c3'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || 'Khair';
  const options = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data,
    tag: data.notification_id || data.type || 'khair-notification'
  };
  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  const eventId = data.event_id || data.entity_id;
  let route = '/notifications';
  if (data.type === 'message_received' && data.conversation_id) {
    route = '/event-messages/' + encodeURIComponent(data.conversation_id);
  } else if (eventId && [
    'event_joined', 'event_join_confirmed', 'event_reminder',
    'event_updated', 'event_participant_joined', 'organizer_announcement'
  ].includes(data.type)) {
    route = '/events/' + encodeURIComponent(eventId);
  }
  const target = new URL(route, self.location.origin).href;
  event.waitUntil(clients.matchAll({type: 'window', includeUncontrolled: true}).then((clientList) => {
    for (const client of clientList) {
      if ('focus' in client) {
        client.navigate(target);
        return client.focus();
      }
    }
    return clients.openWindow(target);
  }));
});
