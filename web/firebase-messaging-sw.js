importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: "AIzaSyAvJqMufbppiYWWGQX_NN-w13KyZpObvGc",
    authDomain: "smart-med-box-28eb7.firebaseapp.com",
    projectId: "smart-med-box-28eb7",
    storageBucket: "smart-med-box-28eb7.firebasestorage.app",
    messagingSenderId: "96250484214",
    appId: "1:96250484214:web:9ce8dc95330453967863d7"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
    const notification = payload.notification || {};
    const title = notification.title || 'Notification';
    const options = {
        body: notification.body || '',
        icon: '/icons/Icon-192.png',
        data: payload.data || {}
    };
    self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', function (event) {
    event.notification.close();
    const url = event.notification?.data?.url || '/';
    event.waitUntil(clients.openWindow(url));
});
