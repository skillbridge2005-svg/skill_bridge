importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyDqC9KNiR-rX12pUcotO-OSZa_gocdzRAY',
  appId: '1:980367306545:web:911d7553b9aaca984c8a10',
  messagingSenderId: '980367306545',
  projectId: 'skill-bridge-e8366',
  authDomain: 'skill-bridge-e8366.firebaseapp.com',
  storageBucket: 'skill-bridge-e8366.firebasestorage.app',
  measurementId: 'G-GZZXFLXY45',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || payload.data?.title || 'SkillBridge';
  const options = {
    body: notification.body || payload.data?.body || '',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});
