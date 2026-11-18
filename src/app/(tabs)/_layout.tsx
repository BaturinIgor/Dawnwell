import { Redirect } from 'expo-router';
import { NativeTabs } from 'expo-router/native-tabs';

import { C } from '@/constants/theme';
import { StorageProblem } from '@/components/storage-problem';
import { useStore } from '@/lib/store';

export default function TabsLayout() {
  const { ready, status, data } = useStore();
  if (!ready) return null;
  // Never send someone to onboarding when their data exists but can't be opened.
  if (status === 'failed' || status === 'newer') return <StorageProblem newer={status === 'newer'} />;
  if (!data.settings.onboarded) return <Redirect href="/onboarding" />;

  return (
    <NativeTabs tintColor={C.accent} labelStyle={{ color: C.inkSoft }} backgroundColor={C.card}>
      <NativeTabs.Trigger name="index">
        <NativeTabs.Trigger.Label>Today</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'sun.max', selected: 'sun.max.fill' }} md="wb_sunny" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="progress">
        <NativeTabs.Trigger.Label>Progress</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="chart.line.uptrend.xyaxis" md="trending_up" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="report">
        <NativeTabs.Trigger.Label>Report</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'doc.text', selected: 'doc.text.fill' }} md="description" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="learn">
        <NativeTabs.Trigger.Label>Learn</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'book', selected: 'book.fill' }} md="menu_book" />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}
