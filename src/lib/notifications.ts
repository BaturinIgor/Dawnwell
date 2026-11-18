import * as Notifications from 'expo-notifications';
import { AndroidImportance } from 'expo-notifications';
import { Platform } from 'react-native';

import { APP_NAME } from '@/constants/theme';

import { Settings } from './types';

const CHANNEL = 'reminders';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function ensurePermission(): Promise<boolean> {
  if (Platform.OS === 'web') return false;
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync(CHANNEL, {
      name: 'Reminders',
      importance: AndroidImportance.HIGH,
    });
  }
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  const asked = await Notifications.requestPermissionsAsync({
    ios: { allowAlert: true, allowSound: true, allowBadge: false },
  });
  return asked.granted;
}

const TAG = { tablet: 'tablet-daily', tabletFollowUp: 'tablet-followup', protein: 'protein-daily', wait: 'wait-over' };

async function cancelTagged(tag: string) {
  const all = await Notifications.getAllScheduledNotificationsAsync();
  await Promise.all(
    all
      .filter((n) => n.content.data?.tag === tag)
      .map((n) => Notifications.cancelScheduledNotificationAsync(n.identifier)),
  );
}

/** Re-create the repeating reminders from settings. Safe to call often. */
export async function syncDailyReminders(s: Settings): Promise<void> {
  if (Platform.OS === 'web') return;
  await Promise.all([cancelTagged(TAG.tablet), cancelTagged(TAG.tabletFollowUp), cancelTagged(TAG.protein)]);
  if (!(await ensurePermission())) return;

  if (s.reminders.tablet) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: 'Time for your tablet',
        body: 'Take it on an empty stomach with a small sip of water.',
        data: { tag: TAG.tablet },
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DAILY,
        hour: s.doseHour,
        minute: s.doseMinute,
        channelId: CHANNEL,
      },
    });
  }
  if (s.reminders.protein) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: 'Protein check',
        body: `Open ${APP_NAME} to see how close you are to ${s.proteinTarget} g today.`,
        data: { tag: TAG.protein },
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DAILY, hour: 15, minute: 0, channelId: CHANNEL },
    });
  }
}

/** One-off alert when the empty-stomach wait ends. */
export async function scheduleWaitOver(takenAt: number, waitMinutes: number, enabled: boolean): Promise<void> {
  if (Platform.OS === 'web') return;
  await cancelTagged(TAG.wait);
  if (!enabled) return;
  const date = new Date(takenAt + waitMinutes * 60_000);
  if (date.getTime() <= Date.now()) return;
  if (!(await ensurePermission())) return;
  await Notifications.scheduleNotificationAsync({
    content: {
      title: "You're clear to eat",
      body: 'Start with protein. Coffee and other medicines are fine now too.',
      data: { tag: TAG.wait },
    },
    trigger: { type: Notifications.SchedulableTriggerInputTypes.DATE, date, channelId: CHANNEL },
  });
}

export async function cancelWaitOver(): Promise<void> {
  if (Platform.OS === 'web') return;
  await cancelTagged(TAG.wait);
}
