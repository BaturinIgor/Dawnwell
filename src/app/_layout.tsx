import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';

import { C } from '@/constants/theme';
import { syncDailyReminders } from '@/lib/notifications';
import { StoreProvider, useStore } from '@/lib/store';

SplashScreen.preventAutoHideAsync();

function ReminderSync() {
  const { ready, data } = useStore();
  const s = data.settings;
  useEffect(() => {
    if (ready) SplashScreen.hideAsync();
  }, [ready]);
  useEffect(() => {
    if (!ready || !s.onboarded) return;
    syncDailyReminders(s).catch(() => {});
    // Only the fields that change what gets scheduled.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, s.onboarded, s.doseHour, s.doseMinute, s.proteinTarget, s.reminders.tablet, s.reminders.protein]);
  return null;
}

export default function RootLayout() {
  return (
    <StoreProvider>
      <StatusBar style="dark" />
      <ReminderSync />
      <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: C.bg } }}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="onboarding" options={{ gestureEnabled: false }} />
        <Stack.Screen name="log-food" options={{ presentation: 'modal' }} />
        <Stack.Screen name="symptom" options={{ presentation: 'modal' }} />
        <Stack.Screen name="medication" />
        <Stack.Screen name="data" />
      </Stack>
    </StoreProvider>
  );
}
